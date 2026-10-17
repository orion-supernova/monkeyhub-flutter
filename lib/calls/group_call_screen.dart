import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../privacy/capture_protection.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/route_landing.dart';
import '../widgets/user_avatar.dart';
import 'audio_level_monitor.dart';
import 'call_audio_devices.dart';
import 'call_audio_sheet.dart';
import 'call_media.dart';
import 'call_options_sheet.dart';
import 'call_stats_monitor.dart';
import 'draw/draw_canvas.dart';
import 'draw/draw_model.dart';
import 'draw/overlay_permission_hint.dart';
import 'group_call_service.dart';
import 'screen_share.dart';
import 'share_picker_sheet.dart';
import 'widgets/call_chrome.dart';
import 'widgets/call_tile_layout.dart';
import '../widgets/desktop_scroll.dart';

/// Full-screen UI for an active mesh group call.
///
/// Three layouts, picked by what there is to look at, not by what kind of
/// call was placed:
///
///  * **Voice** — nobody is sending video. The room's ambient ground, the
///    people on the line as a constellation of faces with a ring that
///    lights when they talk, the ones still ringing dimmed beside them, a
///    timer. No tiles, no black rectangles: a voice call looks like a voice
///    call.
///  * **Grid** — somebody's camera is on. The tile grid, every tile with a
///    face in it (a camera that is off shows the person, not a dark box).
///  * **Stage** — somebody is sharing a screen. The screen fills the top
///    with the drawing layer over it; everyone else in a strip beneath.
///
/// It switches between them live: a camera coming on in a voice call turns
/// it into a video call for everyone, and the last camera going off turns it
/// back. The switch is a cross-fade, so nothing snaps.
///
/// Pops itself when the service leaves the call; "hide" pops it while the
/// call goes on, and the in-call pill brings it back.
class GroupCallScreen extends StatefulWidget {
  const GroupCallScreen({super.key, required this.service, this.api});
  final GroupCallService service;
  final ChatApi? api;

  /// Seam for tests: the renderer behind every video view. The real one
  /// needs the plugin's texture channel, which a widget test does not have.
  @visibleForTesting
  static RTCVideoRenderer Function() rendererFactory = RTCVideoRenderer.new;

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

enum _Layout { voice, grid, stage }

class _GroupCallScreenState extends State<GroupCallScreen>
    with RouteLanding<GroupCallScreen> {
  /// Keyed by userId for a camera, `'$userId:screen'` for a screen.
  final Map<String, RTCVideoRenderer> _renderers = {};
  final Map<String, int> _boundTicks = {};
  RTCVideoRenderer? _localRenderer;
  int _boundLocalTick = -1;
  RTCVideoRenderer? _localScreenRenderer;
  int _boundLocalScreenTick = -1;
  bool _popScheduled = false;
  bool _controlsVisible = true;
  int? _lastBuiltKey;
  bool _shareSupported = false;
  /// Your own profile, for your face. Kept across call screens: fetched
  /// fresh on every open, the first frames showed a monogram that turned
  /// into your photo a moment later.
  late ChatUser? _me = _meCache[svc.userId];
  static final Map<String?, ChatUser> _meCache = {};

  /// The room's name, kept once known: leaving clears the service's a
  /// frame before this screen goes, and the header flashed the generic
  /// "Group voice call" on the way out.
  String? _roomName;

  final AudioLevelMonitor _levels = AudioLevelMonitor();

  /// Live link stats, one monitor per peer connection, keyed by userId —
  /// only while [SettingsStore.showNetworkStats] is on. A mesh call is one
  /// link per person, so unlike the 1:1 call's single readout each tile
  /// gets its own, and nothing polls `getStats` when nobody asked to see it.
  final Map<String, CallStatsMonitor> _stats = {};
  final Map<String, ValueNotifier<CallQualitySnapshot?>> _statsOf = {};

  /// Which connection each monitor is reading, so a link rebuilt after a
  /// drop gets a fresh monitor instead of polling the dead one.
  final Map<String, RTCPeerConnection> _statsPc = {};

  GroupCallService get svc => widget.service;

  @override
  void initState() {
    super.initState();
    svc.addListener(_onChanged);
    svc.drawArmed.addListener(_onChanged);
    SettingsStore.instance.addListener(_onSettings);
    CallAudioDevices.instance
      ..attach()
      ..addListener(_onChanged);
    _levels.sources = () sync* {
      for (final p in svc.peers.values) {
        final pc = p.pc;
        // No track, no poll: without one the monitor falls back to the
        // whole connection's stats, per peer, three times a second on the
        // platform thread (iOS draws frames on it), for audio that has not
        // even arrived. The 1:1 screen skips it the same way.
        final track = _firstAudio(p.remoteStream);
        if (pc == null || track == null) continue;
        yield AudioLevelSource(
          id: p.userId,
          pc: pc,
          track: track,
          muted: p.mediaState.audioMuted || !p.connected,
        );
      }
    };
    _levels.localPc = () {
      for (final p in svc.peers.values) {
        if (p.pc != null) return p.pc;
      }
      return null;
    };
    // Scoped to our mic's sender, not the whole connection's report.
    _levels.localTrack = () => _firstAudio(svc.localStream);
    _levels.start();
    // Known on the first frame wherever it can be, as on the 1:1 screen: a
    // share button that arrived mid-slide regrew the tray under it.
    final share = ScreenShare.knownSupported;
    _shareSupported = ScreenShare.likelySupported;
    if (share == null) {
      unawaited(ScreenShare.supported().then((ok) {
        if (!mounted) return;
        // Still sliding: the button lands once the screen stands still.
        if (!landed) {
          _pendingShareSupported = ok;
          return;
        }
        if (ok != _shareSupported) setState(() => _shareSupported = ok);
      }));
    }
    unawaited(_loadMe());
    _syncStats();
  }

  // --------------------------------------------------------------- landing

  bool _landedOnce = false;

  /// [ScreenShare.supported]'s answer when it came mid-slide.
  bool? _pendingShareSupported;

  /// The 1:1 screen's rule (see `CallScreen.onRouteLandingChanged`): the
  /// renderers are made and a late share button lands once the screen has
  /// finished sliding up, never during it. Each renderer is a texture and an
  /// event channel registered on the platform thread, which on iOS presents
  /// the frames. The status bar stays up throughout.
  @override
  void onRouteLandingChanged() {
    if (!landed || _landedOnce) return;
    _landedOnce = true;
    if (svc.inCall) unawaited(_syncRenderers());
    final share = _pendingShareSupported;
    _pendingShareSupported = null;
    if (share != null && share != _shareSupported) {
      setState(() => _shareSupported = share);
    }
  }

  // ---------------------------------------------------------------- stats

  bool _statsOn = false;

  void _onSettings() {
    if (!mounted) return;
    final on = SettingsStore.instance.showNetworkStats;
    if (on == _statsOn) return;
    _syncStats();
    setState(() {});
  }

  /// Starts a monitor for every connected peer and stops the ones whose
  /// peer (or connection) has gone — or all of them when the toggle is off.
  void _syncStats() {
    _statsOn = SettingsStore.instance.showNetworkStats;
    final wanted = <String, RTCPeerConnection>{
      if (_statsOn)
        for (final p in svc.peers.values)
          if (p.pc != null) p.userId: p.pc!,
    };
    for (final id in _stats.keys.toList(growable: false)) {
      if (!identical(wanted[id], _statsPc[id])) {
        _stats.remove(id)?.dispose();
        _statsPc.remove(id);
      }
    }
    for (final e in wanted.entries) {
      if (_stats.containsKey(e.key)) continue;
      final target = _statsOf.putIfAbsent(e.key, () => ValueNotifier(null));
      _statsPc[e.key] = e.value;
      _stats[e.key] = CallStatsMonitor(pc: e.value, target: target)..start();
    }
  }

  /// The readout for a peer's tile, or null when stats are off.
  ValueListenable<CallQualitySnapshot?>? _statsFor(String userId) =>
      _statsOn ? _statsOf.putIfAbsent(userId, () => ValueNotifier(null)) : null;

  /// What this phone is sending, summed over every link — the local tile's
  /// "↑". Null when stats are off.
  Listenable? get _uploadStats =>
      _statsOn ? Listenable.merge(_statsOf.values.toList()) : null;

  double? _uploadKbps() {
    double? sum;
    for (final n in _statsOf.values) {
      final out = n.value?.outKbps;
      if (out != null) sum = (sum ?? 0) + out;
    }
    return sum;
  }

  /// A peer's live readout for their tile or face; null when stats are off.
  Widget? _peerStats(String userId) {
    final n = _statsFor(userId);
    if (n == null) return null;
    return _StatsCaption(listenable: n, text: () => statsDownLine(n.value));
  }

  /// This phone's upload, for the "you" tile; null when stats are off.
  Widget? _localStats() {
    final l = _uploadStats;
    if (l == null) return null;
    return _StatsCaption(listenable: l, text: () => statsUpLine(_uploadKbps()));
  }

  static MediaStreamTrack? _firstAudio(MediaStream? s) {
    if (s == null) return null;
    final t = s.getAudioTracks();
    return t.isEmpty ? null : t.first;
  }

  Future<void> _loadMe() async {
    final api = widget.api;
    final id = svc.userId;
    if (api == null || id == null) return;
    try {
      final me = await api.getProfile(id);
      if (me == null) return;
      _meCache[id] = me;
      if (mounted) setState(() => _me = me);
    } catch (_) {}
  }

  // ------------------------------------------------------------ renderers

  Future<RTCVideoRenderer> _renderer(String key) async {
    var r = _renderers[key];
    if (r == null) {
      r = GroupCallScreen.rendererFactory();
      _renderers[key] = r;
      try {
        await r.initialize();
      } catch (e) {
        debugPrint('GroupCallScreen: renderer init failed: $e');
      }
    }
    return r;
  }

  Future<void> _bind(String key, MediaStream stream, int tick) async {
    final r = await _renderer(key);
    if (!mounted) return;
    if (_boundTicks[key] != tick || r.srcObject != stream) {
      r.srcObject = stream;
      _boundTicks[key] = tick;
      // Web: the new <audio> element starts on the default speaker.
      CallAudioDevices.instance.registerWebSinks([r]);
      unawaited(CallAudioDevices.instance.reapplyWebSink());
    }
  }

  void _drop(String key) {
    final r = _renderers.remove(key);
    _boundTicks.remove(key);
    if (r != null) {
      CallAudioDevices.instance.unregisterWebSinks([r]);
      r.srcObject = null;
      r.dispose();
    }
  }

  Future<void> _syncRenderers() async {
    final wanted = <String>{};
    for (final peer in svc.peers.values) {
      final cam = peer.remoteStream;
      if (cam != null) {
        wanted.add(peer.userId);
        unawaited(_bind(peer.userId, cam, peer.remoteStreamTick));
      }
      final screen = peer.screenStream;
      if (screen != null) {
        final key = '${peer.userId}:screen';
        wanted.add(key);
        unawaited(_bind(key, screen, peer.screenStreamTick));
      }
    }
    for (final key in _renderers.keys.toList(growable: false)) {
      if (!wanted.contains(key)) _drop(key);
    }
    // Our own camera: a renderer only once there is something to render —
    // a voice call allocates no GPU texture until a camera comes on.
    final ls = svc.localStream;
    if (svc.localCamActive && ls != null) {
      var r = _localRenderer;
      if (r == null) {
        r = GroupCallScreen.rendererFactory();
        _localRenderer = r;
        try {
          await r.initialize();
        } catch (e) {
          debugPrint('GroupCallScreen: local renderer init failed: $e');
        }
        if (!mounted) return;
      }
      if (r.srcObject != ls || _boundLocalTick != svc.localStreamTick) {
        r.srcObject = ls;
        _boundLocalTick = svc.localStreamTick;
      }
    }
    // Our own share, previewed only where the preview is not a mirror
    // tunnel — a desktop window, not the whole phone screen.
    final ss = svc.screenStream;
    if (svc.localScreenSharing && ss != null && !isMobileCallPlatform) {
      var r = _localScreenRenderer;
      if (r == null) {
        r = GroupCallScreen.rendererFactory();
        _localScreenRenderer = r;
        try {
          await r.initialize();
        } catch (e) {
          debugPrint('GroupCallScreen: screen renderer init failed: $e');
        }
        if (!mounted) return;
      }
      if (r.srcObject != ss || _boundLocalScreenTick != svc.localScreenStreamTick) {
        r.srcObject = ss;
        _boundLocalScreenTick = svc.localScreenStreamTick;
      }
    } else if (_localScreenRenderer != null && !svc.localScreenSharing) {
      _localScreenRenderer!.srcObject = null;
      _localScreenRenderer!.dispose();
      _localScreenRenderer = null;
      _boundLocalScreenTick = -1;
    }
  }

  // ------------------------------------------------------------- rebuilds

  int _buildKey() {
    final parts = <Object?>[
      svc.inCall,
      svc.roomName,
      svc.localMuted,
      svc.localVideoOff,
      svc.localCamActive,
      svc.cameraButtonOn,
      svc.localScreenSharing,
      svc.localStreamTick,
      svc.localScreenStreamTick,
      svc.speakerOn,
      CallAudioDevices.instance.revision,
      svc.hasAnyVideo,
      svc.drawArmed.value,
      _controlsVisible,
      _shareSupported,
      _me?.id,
      _renderers.length,
      _localRenderer != null,
    ];
    for (final p in svc.peers.values) {
      parts.addAll([
        p.userId,
        p.name,
        p.avatarStorageId,
        p.connected,
        p.reconnecting,
        p.mediaState.audioMuted,
        p.mediaState.videoOff,
        p.mediaState.screenSharing,
        p.remoteStreamTick,
        p.screenStreamTick,
        p.remoteStream != null,
        p.screenStream != null,
        identityHashCode(p.pc),
      ]);
    }
    for (final r in svc.rosterRows) {
      parts.addAll([r['userId'], r['status']]);
    }
    return Object.hashAll(parts);
  }

  void _onChanged() {
    if (!mounted) return;
    if (!svc.inCall) {
      if (!_popScheduled) {
        _popScheduled = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
      setState(() {});
      return;
    }
    // Mid-slide, the landing makes them. See [onRouteLandingChanged].
    if (landed) unawaited(_syncRenderers());
    _syncStats();
    final key = _buildKey();
    if (key == _lastBuiltKey) return;
    _lastBuiltKey = key;
    setState(() {});
  }

  @override
  void dispose() {
    svc.removeListener(_onChanged);
    svc.drawArmed.removeListener(_onChanged);
    SettingsStore.instance.removeListener(_onSettings);
    CallAudioDevices.instance
      ..removeListener(_onChanged)
      ..detach();
    for (final m in _stats.values) {
      m.dispose();
    }
    for (final n in _statsOf.values) {
      n.dispose();
    }
    _levels
      ..stop()
      ..dispose();
    for (final r in _renderers.values) {
      r.srcObject = null;
      r.dispose();
    }
    _localRenderer?.srcObject = null;
    _localRenderer?.dispose();
    _localScreenRenderer?.srcObject = null;
    _localScreenRenderer?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------- actions

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = !_controlsVisible);
  }

  /// A flick down puts the chrome away and a flick up brings it back — the
  /// gesture people reach for on a full-screen picture, beside the tap.
  void _onVerticalSwipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 300) return;
    final show = v < 0;
    if (!mounted || show == _controlsVisible) return;
    setState(() => _controlsVisible = show);
  }

  void _hide() {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  Future<void> _onShareTap() async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    if (svc.localScreenSharing) {
      await svc.stopScreenShare();
      return;
    }
    final presenter = svc.presentingPeer;
    if (presenter != null) {
      toast.show(l10n.screenShareSomeoneElsePresenting(presenter.name));
      return;
    }
    if (!_shareSupported) {
      toast.show(l10n.screenShareUnsupported);
      return;
    }
    ScreenShareSource? source;
    if (!isMobileCallPlatform) {
      source = await showSharePickerSheet(context);
      if (source == null || !mounted) return;
    }
    final protectedRoom = CaptureProtection.instance.scopeActive;
    try {
      await svc.startScreenShare(
        source: source,
        notification: (
          title: l10n.screenShareNotificationTitle,
          body: l10n.screenShareNotificationBody,
          stop: l10n.screenShareNotificationStop,
        ),
        drawBoardIdleText: l10n.screenShareDrawBoardIdle,
      );
    } catch (e) {
      toast.show(l10n.screenShareFailed, tone: ToastTone.danger);
      return;
    }
    if (svc.localScreenSharing && protectedRoom) {
      toast.show(l10n.screenShareEphemeralWarning);
    }
  }

  // ---------------------------------------------------------------- build

  _Layout _layoutFor() {
    final anyScreen = svc.localScreenSharing ||
        svc.peers.values.any(
          (p) => p.mediaState.screenSharing && p.screenStream != null,
        );
    if (anyScreen) return _Layout.stage;
    if (svc.hasAnyVideo) return _Layout.grid;
    return _Layout.voice;
  }

  ChatUser _asUser(String id, String name, String? avatarStorageId) => ChatUser(
        id: id,
        username: '',
        name: name,
        avatarStorageId: avatarStorageId,
      );

  ChatUser get _meUser =>
      _me ??
      _asUser(svc.userId ?? 'me', AppLocalizations.of(context).groupCallScreenYouLabel, null);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final layout = _layoutFor();
    final peers = svc.peers.values.toList(growable: false);
    final anyReconnecting = peers.any((p) => p.reconnecting);
    _roomName = svc.roomName ?? _roomName;
    // In the voice layout the chrome is the screen; only over video does a
    // tap put it away.
    final chromeVisible = layout == _Layout.voice || _controlsVisible;
    final trayActions = _trayActions(l10n, layout);
    // What the tray covers, so every stage keeps clear of it however many
    // rows it needs.
    final trayInset = CallTray.estimateHeight(
      actionCount: trayActions.length,
      width: MediaQuery.sizeOf(context).width,
    );

    final Widget stage = switch (layout) {
      _Layout.voice => _VoiceStage(
          key: const ValueKey('voice'),
          service: svc,
          api: widget.api,
          levels: _levels,
          me: _meUser,
          theme: theme,
          bottomInset: trayInset,
          statsFor: _peerStats,
          localStats: _localStats(),
        ),
      _Layout.grid => _VideoGrid(
          key: const ValueKey('grid'),
          service: svc,
          api: widget.api,
          levels: _levels,
          me: _meUser,
          renderers: _renderers,
          localRenderer: _localRenderer,
          theme: theme,
          bottomInset: trayInset,
          statsFor: _peerStats,
          localStats: _localStats(),
        ),
      _Layout.stage => _ShareStage(
          key: const ValueKey('stage'),
          service: svc,
          api: widget.api,
          levels: _levels,
          me: _meUser,
          renderers: _renderers,
          localRenderer: _localRenderer,
          localScreenRenderer: _localScreenRenderer,
          theme: theme,
          bottomInset: trayInset,
        ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kCallStatusBarStyle,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: layout == _Layout.voice ? null : _toggleControls,
            onVerticalDragEnd:
                layout == _Layout.voice ? null : _onVerticalSwipe,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: motion.d(const Duration(milliseconds: 280)),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  child: stage,
                ),

                // Header: the room, the timer, how many are here.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ControlsFade(
                    visible: chromeVisible,
                    slide: const Offset(0, -0.3),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _roomName ??
                                        (svc.hasAnyVideo
                                            ? l10n.groupCallScreenTitleVideo
                                            : l10n.groupCallScreenTitleVoice),
                                    style: theme.displaySmall.copyWith(
                                      color: Colors.white,
                                      shadows: const [
                                        Shadow(blurRadius: 8, color: Colors.black54),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          svc.hasAnyVideo
                                              ? l10n.groupCallScreenTitleVideo
                                              : l10n.groupCallScreenTitleVoice,
                                          style: callCaptionStyle(theme),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (svc.joinedAt != null) ...[
                                        Text(
                                          '  ·  ',
                                          style: callCaptionStyle(theme)
                                              .copyWith(color: Colors.white38),
                                        ),
                                        ElapsedLabel(
                                          start: svc.joinedAt!,
                                          style: callCaptionStyle(theme),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Flexible, up to two fifths of the row: "3 in call · 1
                            // ringing" in Turkish at 1.3× is wider than the
                            // room left beside a long group name, and the chip
                            // goes to two lines — never cut — before it
                            // squeezes the name out of its row. Aligned right:
                            // a short "Just you" chip otherwise floated in the
                            // middle of its loose slot.
                            Flexible(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.topRight,
                                child: _CountChip(
                                  counts: _counts(l10n, peers.length),
                                  style: callCaptionStyle(theme).copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (anyReconnecting)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 76,
                    left: 0,
                    right: 0,
                    child: OverlayChip(label: l10n.groupCallScreenReconnecting),
                  ),

                // The tray.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ControlsFade(
                    visible: chromeVisible,
                    slide: const Offset(0, 0.3),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CallTray(
                          actions: trayActions,
                          endIcon: CallGlyphs.end,
                          endLabel: l10n.groupCallScreenLeaveLabel,
                          endColor: theme.danger,
                          onEnd: () => unawaited(svc.leaveCall()),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tray's controls, in the order they keep the first row: the
  /// everyday toggles first, the occasional ones last. CallTray wraps
  /// whatever does not fit onto a second row.
  List<CallTrayAction> _trayActions(AppLocalizations l10n, _Layout layout) {
    final sharing = svc.localScreenSharing;
    final pending = svc.screenSharePending;
    final someoneElseSharing = !sharing && svc.presentingPeer != null;
    return [
      CallTrayAction(
        icon: svc.localMuted ? CallGlyphs.micOff : CallGlyphs.mic,
        // Lit while live; a headset badge while a headset's mic hears you.
        glyph: CallTrayGlyph.mic(
          on: !svc.localMuted,
          headset: isMobileCallPlatform &&
              CallAudioDevices.instance.micOnHeadset,
          route: callHeadsetGlyphRoute(
            CallAudioDevices.instance.output,
            CallAudioDevices.instance.outputName,
          ),
        ),
        active: !svc.localMuted,
        onTap: svc.toggleMute,
        label: svc.localMuted
            ? l10n.groupCallScreenUnmuteLabel
            : l10n.groupCallScreenMuteLabel,
      ),
      CallTrayAction(
        // The wish while it is carried out, else the camera's real state.
        icon: svc.cameraButtonOn ? CallGlyphs.camera : CallGlyphs.cameraOff,
        glyph: CallTrayGlyph.camera(on: svc.cameraButtonOn),
        active: svc.cameraButtonOn,
        onTap: () => unawaited(svc.toggleVideo()),
        label: svc.cameraButtonOn
            ? l10n.groupCallScreenCamOffLabel
            : l10n.groupCallScreenCamOnLabel,
      ),
      // The real route on a phone (a toggle, or the route sheet once a
      // headset is a choice); the device picker on desktop and web.
      callAudioTrayAction(
        context,
        speakerOn: svc.speakerOn,
        onToggleSpeaker: () => unawaited(svc.toggleSpeaker()),
        selectSpeaker: svc.selectSpeaker,
        switchWebMic: (id) => switchWebMicrophone(
          deviceId: id,
          localStream: svc.localStream,
          peerConnections: [
            for (final p in svc.peers.values) ?p.pc,
          ],
        ),
      ),
      if (_shareSupported)
        CallTrayAction(
          icon: sharing ? CallGlyphs.stopShare : CallGlyphs.share,
          glyph: CallTrayGlyph.share(on: sharing),
          active: sharing,
          // Disabled while someone else holds the stage, and while our own
          // share is being set up (the picker, the countdown) — a second
          // tap then would start a second capture.
          enabled: !someoneElseSharing && !pending,
          onTap: () => unawaited(_onShareTap()),
          label: sharing
              ? l10n.groupCallScreenStopShareLabel
              : pending
                  ? l10n.groupCallScreenShareStartingLabel
                  : l10n.groupCallScreenShareLabel,
        ),
      if (layout == _Layout.stage)
        CallTrayAction(
          icon: CallGlyphs.draw,
          active: svc.drawArmed.value,
          onTap: () => svc.drawArmed.value = !svc.drawArmed.value,
          label: l10n.groupCallScreenDrawLabel,
        ),
      if (svc.localCamActive && isMobileCallPlatform)
        CallTrayAction(
          icon: CallGlyphs.flip,
          glyph: const CallTrayGlyph(CallGlyphKind.flip),
          onTap: () => unawaited(svc.switchCamera()),
          label: l10n.groupCallScreenFlipLabel,
        ),
      // The 1:1 tray's "More", in the same place under the same name: the
      // stats readout and, with a camera on, the quality tier.
      CallTrayAction(
        icon: CallGlyphs.more,
        glyph: const CallTrayGlyph(CallGlyphKind.more),
        onTap: () => showAdaptiveSheet(
          context,
          builder: (_) => CallOptionsSheet(
            service: svc,
            showVideoQuality: svc.localCamActive,
          ),
        ),
        label: l10n.callScreenControlOptions,
      ),
      CallTrayAction(
        icon: CallGlyphs.hide,
        glyph: const CallTrayGlyph(CallGlyphKind.hide),
        onTap: _hide,
        label: l10n.groupCallScreenMinimizeLabel,
      ),
    ];
  }

  /// The header chip: who is on the call, and who is still being rung.
  ///
  /// Counted from the roster, not from the live links. A link that drops and
  /// comes back used to take its person out of the count for the seconds it
  /// was reconnecting, so "3 in call" blinked to "2" and back while nobody had
  /// left; the roster still says `joined` for them throughout. The live links
  /// are only the fallback for the moment before the roster has arrived.
  ({String joined, String? ringing}) _counts(
    AppLocalizations l10n,
    int livePeers,
  ) {
    final me = svc.userId;
    final rows = svc.rosterRows;
    var joined = livePeers + 1;
    var ringing = 0;
    if (rows.isNotEmpty) {
      joined = 1;
      for (final r in rows) {
        if (r['userId']?.toString() == me) continue;
        switch (r['status']) {
          case 'joined':
            joined++;
          case 'invited':
            ringing++;
        }
      }
    }
    return (
      joined: l10n.groupCallScreenParticipantCount(joined),
      ringing: ringing == 0 ? null : l10n.groupCallScreenRingingCount(ringing),
    );
  }
}

/// The header's count chip: "3 in call · 1 ringing" on one line when it fits,
/// otherwise the two halves stacked, right-aligned, with no dot. Wrapping the
/// one string instead broke it wherever the width ran out — in Turkish at 1.3×
/// that was three centred lines with the dot dangling at the end of one.
class _CountChip extends StatelessWidget {
  const _CountChip({required this.counts, required this.style});

  final ({String joined, String? ringing}) counts;
  final TextStyle style;

  static const _padH = 10.0;

  @override
  Widget build(BuildContext context) {
    final ringing = counts.ringing;
    Widget body;
    if (ringing == null) {
      body = Text(counts.joined, textAlign: TextAlign.right, style: style);
    } else {
      final line = '${counts.joined} · $ringing';
      body = LayoutBuilder(
        builder: (context, box) {
          final p = TextPainter(
            text: TextSpan(text: line, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final fits = p.width <= box.maxWidth;
          p.dispose();
          if (fits) return Text(line, maxLines: 1, style: style);
          // One line each, shrunk a touch if a half is still too wide
          // ("3 kişi görüşmede" at 1.3×) rather than wrapped into a third
          // line taller than the title block beside it.
          Widget half(String text) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(text, maxLines: 1, style: style),
              );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [half(counts.joined), half(ringing)],
          );
        },
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: body,
    );
  }
}

// ---------------------------------------------------------------------------
// Voice
// ---------------------------------------------------------------------------

/// Everyone on the line, as faces. Alone, the pulse rings breathe around
/// your own face; invited people who have not picked up yet stand beside
/// the others, dimmed, with "Ringing…" under them.
class _VoiceStage extends StatelessWidget {
  const _VoiceStage({
    super.key,
    required this.service,
    required this.api,
    required this.levels,
    required this.me,
    required this.theme,
    required this.bottomInset,
    required this.statsFor,
    required this.localStats,
  });

  final GroupCallService service;
  final ChatApi? api;
  final AudioLevelMonitor levels;
  final ChatUser me;
  final AppTheme theme;

  /// What the tray covers at the bottom; the faces centre above it.
  final double bottomInset;

  /// Live link stats under each face — see `_GroupCallScreenState._stats`.
  final Widget? Function(String userId) statsFor;
  final Widget? localStats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final peers = service.peers.values.toList(growable: false);
    final ghosts = [
      for (final r in service.rosterRows)
        if (r['status'] == 'invited' && r['userId']?.toString() != service.userId)
          r,
    ];
    final n = 1 + peers.length + ghosts.length;
    return CallBackdrop(
      accent: theme.accent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = n <= 1
                ? 1
                : n <= 3
                    ? n
                    : n <= 8
                        ? 3
                        : 4;
            final rows = (n / cols).ceil();
            final byWidth = (c.maxWidth - 40) / cols - 24;
            final byHeight = (c.maxHeight - 110 - bottomInset) / rows - 44;
            final orb = math.min(byWidth, byHeight).clamp(56.0, 128.0);
            Widget orbFor(ChatUser u, String label, {bool isMe = false,
                bool muted = false, bool dimmed = false, bool ghost = false,
                String? caption}) {
              return ParticipantOrb(
                user: u,
                api: api,
                size: orb,
                level: levels.levelOf(isMe ? AudioLevelMonitor.me : u.id),
                accent: theme.accent,
                label: label,
                muted: muted,
                dimmed: dimmed,
                ghost: ghost,
                caption: caption,
              );
            }

            // The face, and under it the link's readout when stats are on.
            Widget withStats(Widget orb, Widget? stats) => stats == null
                ? orb
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      orb,
                      const SizedBox(height: 4),
                      stats,
                    ],
                  );

            final mine = orbFor(
              me,
              l10n.groupCallScreenYouLabel,
              isMe: true,
              muted: service.localMuted,
            );
            return Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 96, 20, bottomInset),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  spacing: 18,
                  runSpacing: 22,
                  children: [
                    if (n == 1)
                      PulseRings(
                        accent: theme.accent,
                        diameter: orb,
                        reach: orb,
                        animate: !motion.calm,
                        child: mine,
                      )
                    else
                      withStats(mine, localStats),
                    for (final p in peers)
                      withStats(
                        orbFor(
                          ChatUser(
                            id: p.userId,
                            username: '',
                            name: p.name,
                            avatarStorageId: p.avatarStorageId,
                          ),
                          p.name,
                          muted: p.mediaState.audioMuted,
                          dimmed: !p.connected || p.reconnecting,
                        ),
                        statsFor(p.userId),
                      ),
                    for (final g in ghosts)
                      orbFor(
                        ChatUser(
                          id: g['userId'].toString(),
                          username: '',
                          name: g['name']?.toString() ?? '',
                          avatarStorageId: g['avatarStorageId'] as String?,
                        ),
                        g['name']?.toString() ?? '',
                        ghost: true,
                        caption: l10n.groupCallScreenRingingLabel,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

/// Somebody's camera is on. Laid out by how many are here, not as a
/// one-size grid of cards:
///
///  * **Two of you**: a 1:1 call. The other person fills the screen and
///    your own camera floats in a corner you can drag it to; a tap on it
///    swaps the two.
///  * **Three**: the other two share the screen, stacked (side by side on a
///    wide window), your camera floating over them.
///  * **Four and more**: everyone in [CallTileLayout]'s balanced tiles, you
///    last, every tile filled.
///
/// With your camera off you are not a tile in the first two: a corner
/// showing your own initials says nothing the tray does not.
class _VideoGrid extends StatefulWidget {
  const _VideoGrid({
    super.key,
    required this.service,
    required this.api,
    required this.levels,
    required this.me,
    required this.renderers,
    required this.localRenderer,
    required this.theme,
    required this.bottomInset,
    required this.statsFor,
    required this.localStats,
  });

  final GroupCallService service;
  final ChatApi? api;
  final AudioLevelMonitor levels;
  final ChatUser me;
  final Map<String, RTCVideoRenderer> renderers;
  final RTCVideoRenderer? localRenderer;
  final AppTheme theme;

  /// What the tray covers at the bottom; the tiles stay clear of it.
  final double bottomInset;

  /// Live link stats in each tile's corner — see `_GroupCallScreenState._stats`.
  final Widget? Function(String userId) statsFor;
  final Widget? localStats;

  /// Up to this many on the call, you float instead of taking a tile.
  static const floatSelfUpTo = 3;

  @override
  State<_VideoGrid> createState() => _VideoGridState();
}

class _VideoGridState extends State<_VideoGrid> {
  /// Two of you: your camera full-screen and the other person in the
  /// corner, after a tap on the corner.
  bool _swapped = false;

  GroupCallService get service => widget.service;

  Widget _selfTile({bool bleed = false, double footer = 0, bool tag = true}) {
    final l10n = AppLocalizations.of(context);
    final showLocal = service.localCamActive && widget.localRenderer != null;
    return _Tile(
      key: const ValueKey('tile-me'),
      label: l10n.groupCallScreenYouLabel,
      muted: service.localMuted,
      level: widget.levels.levelOf(AudioLevelMonitor.me),
      accent: widget.theme.accent,
      user: widget.me,
      api: widget.api,
      stats: widget.localStats,
      bleed: bleed,
      footer: footer,
      tag: tag,
      video: showLocal
          ? RTCVideoView(
              widget.localRenderer!,
              mirror: !service.localCamFacingBack,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          : null,
    );
  }

  Widget _peerTile(
    GroupPeer peer, {
    bool bleed = false,
    double footer = 0,
    bool tag = true,
  }) {
    final renderer = widget.renderers[peer.userId];
    return _Tile(
      key: ValueKey('tile-${peer.userId}'),
      label: peer.name,
      muted: peer.mediaState.audioMuted,
      dimmed: !peer.connected || peer.reconnecting,
      level: widget.levels.levelOf(peer.userId),
      accent: widget.theme.accent,
      user: ChatUser(
        id: peer.userId,
        username: '',
        name: peer.name,
        avatarStorageId: peer.avatarStorageId,
      ),
      api: widget.api,
      stats: widget.statsFor(peer.userId),
      bleed: bleed,
      footer: footer,
      tag: tag,
      video: (!peer.mediaState.videoOff &&
              peer.remoteStream != null &&
              peer.remoteStream!.getVideoTracks().isNotEmpty &&
              renderer != null)
          ? RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final peers = service.peers.values.toList(growable: false);
    final pad = MediaQuery.paddingOf(context);
    final camOn = service.localCamActive && widget.localRenderer != null;
    final total = peers.length + 1;
    final float = peers.isNotEmpty && total <= _VideoGrid.floatSelfUpTo;
    if (!float || !camOn) _swapped = false;

    // The corner tile, for the layouts where you float.
    Widget pip(Widget child) => Positioned.fill(
          key: const ValueKey('pip'),
          child: DraggablePip(
            // Under the header (title, count chip), above the tray.
            top: pad.top + 76,
            bottom: widget.bottomInset + pad.bottom,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: peers.length == 1
                  ? () => setState(() => _swapped = !_swapped)
                  : null,
              child: child,
            ),
          ),
        );

    if (float && peers.length == 1) {
      // A 1:1 call in a group room: one picture, full bleed, like the 1:1
      // screen. Its name tag sits above the tray.
      final footer = widget.bottomInset + pad.bottom;
      final big = _swapped
          ? _selfTile(bleed: true, footer: footer)
          : _peerTile(peers.first, bleed: true, footer: footer);
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(key: const ValueKey('big'), child: big),
          // The header reads over any picture.
          const _TopScrim(key: ValueKey('scrim')),
          if (camOn)
            pip(_swapped
                ? _peerTile(peers.first, bleed: true, tag: false)
                : _selfTile(bleed: true, tag: false)),
        ],
      );
    }

    final tiles = [
      for (final p in peers) _peerTile(p),
      if (!float || !camOn) _selfTile(),
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(
          key: const ValueKey('tiles'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 76, 8, widget.bottomInset + 12),
            child: CallTileLayout(children: tiles),
          ),
        ),
        if (float && camOn) pip(_selfTile(bleed: true, tag: false)),
      ],
    );
  }
}

/// The dark fade under the header over a full-bleed picture.
class _TopScrim extends StatelessWidget {
  const _TopScrim({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 200,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      );
}

/// One grid tile: the video, or the person when there is none; the name
/// and mic state in the corner; a border that lights when they talk.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.level,
    required this.accent,
    required this.user,
    this.api,
    this.video,
    this.stats,
    this.muted = false,
    this.dimmed = false,
    this.bleed = false,
    this.footer = 0,
    this.tag = true,
  });

  final String label;
  final ValueNotifier<double> level;
  final Color accent;
  final ChatUser user;
  final ChatApi? api;
  final Widget? video;

  /// The link readout, over the name in the bottom-left corner.
  final Widget? stats;
  final bool muted;
  final bool dimmed;

  /// Square-cornered and borderless: the full-screen picture, or the corner
  /// tile (whose own frame [DraggablePip] draws).
  final bool bleed;

  /// What covers the tile's bottom edge (the tray, over a full-bleed one),
  /// so the name tag sits above it.
  final double footer;

  /// The name tag; off in the small corner tile.
  final bool tag;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: level,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF17181C)),
          ?video,
          if (video == null)
            Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final size =
                      (math.min(c.maxWidth, c.maxHeight) * 0.42)
                          .clamp(48.0, bleed ? 140.0 : 96.0);
                  return SpeakingRing(
                    level: level,
                    accent: accent,
                    size: size,
                    child: ClipOval(
                      child: UserAvatar(
                        user: user,
                        api: api,
                        size: size - 6,
                        showStatus: false,
                      ),
                    ),
                  );
                },
              ),
            ),
          if (dimmed) Container(color: Colors.black.withValues(alpha: 0.45)),
          if (tag)
            Positioned(
              left: bleed ? 20 : 8,
              right: bleed ? 20 : 8,
              bottom: 8 + footer,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats != null) ...[stats!, const SizedBox(height: 2)],
                  Row(
                    children: [
                      if (muted) ...[
                        const Icon(
                          CallGlyphs.micOff,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          label,
                          // The call caption face, like every other name over a
                          // call — not a raw 11pt style of its own.
                          style: callCaptionStyle(ThemeScope.of(context))
                              .copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black87),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      builder: (context, l, child) {
        if (bleed) return child!;
        final on = video != null && l > 0.04;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Stage
// ---------------------------------------------------------------------------

/// A shared screen, with the drawing layer over it and everyone else in a
/// strip below. The presenter's own phone shows a placeholder instead of
/// its own screen — a screen showing itself showing itself is a tunnel.
class _ShareStage extends StatelessWidget {
  const _ShareStage({
    super.key,
    required this.service,
    required this.api,
    required this.levels,
    required this.me,
    required this.renderers,
    required this.localRenderer,
    required this.localScreenRenderer,
    required this.theme,
    required this.bottomInset,
  });

  final GroupCallService service;
  final ChatApi? api;
  final AudioLevelMonitor levels;
  final ChatUser me;
  final Map<String, RTCVideoRenderer> renderers;
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? localScreenRenderer;
  final AppTheme theme;

  /// What the tray covers at the bottom; the strip ends above it.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final peers = service.peers.values.toList(growable: false);
    final presenter = service.presentingPeer;
    final mine = service.localScreenSharing;
    final screenRenderer = mine
        ? localScreenRenderer
        : (presenter == null ? null : renderers['${presenter.userId}:screen']);
    final ink = drawColorFor(service.userId ?? 'me', theme);
    final caption = mine
        ? l10n.groupCallScreenYouAreSharing
        : l10n.groupCallScreenSharingBy(presenter?.name ?? '');

    // Below the header text and above the tray — same landmarks the 1:1
    // stage floats its own caption and controls over.
    final topInset = MediaQuery.paddingOf(context).top + 76;
    final stripBottom = MediaQuery.paddingOf(context).bottom + bottomInset + 8;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed, like the 1:1 stage: the header, caption and strip
        // float over the picture instead of boxing it into a card, so a
        // group call's shared screen reads as large as a DM's.
        Container(
          color: const Color(0xFF0E0F12),
          child: screenRenderer != null
              ? ValueListenableBuilder<bool>(
                  valueListenable: service.drawArmed,
                  builder: (context, armed, _) => ShareSurface(
                    renderer: screenRenderer,
                    model: service.drawModel,
                    // The presenter draws through the app-wide overlay,
                    // which is what maps to the screen being captured;
                    // here it would draw twice.
                    armed: armed && !mine,
                    inkColor: ink,
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CallGlyphs.share,
                        size: 40,
                        color: theme.accent.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        caption,
                        style: theme.body.copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      if (mine) OverlayPermissionHint(mirror: service.drawMirror),
                    ],
                  ),
                ),
        ),
        // The placeholder already carries the caption when there is no
        // picture to put it over.
        if (screenRenderer != null)
          Positioned(
            left: 16,
            top: topInset,
            right: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: CallCaptionPill(text: caption),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: stripBottom,
          child: SizedBox(
            height: 92,
            child: HorizontalWheelScroll(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _StripTile(
                    label: l10n.groupCallScreenYouLabel,
                    muted: service.localMuted,
                    level: levels.levelOf(AudioLevelMonitor.me),
                    accent: theme.accent,
                    user: me,
                    api: api,
                    presenting: mine,
                    video: service.localCamActive && localRenderer != null
                        ? RTCVideoView(
                            localRenderer!,
                            mirror: !service.localCamFacingBack,
                            objectFit:
                                RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          )
                        : null,
                  ),
                  for (final p in peers)
                    _StripTile(
                      label: p.name,
                      muted: p.mediaState.audioMuted,
                      dimmed: !p.connected || p.reconnecting,
                      level: levels.levelOf(p.userId),
                      accent: theme.accent,
                      user: ChatUser(
                        id: p.userId,
                        username: '',
                        name: p.name,
                        avatarStorageId: p.avatarStorageId,
                      ),
                      api: api,
                      presenting: identical(p, presenter),
                      video: (!p.mediaState.videoOff &&
                              p.remoteStream != null &&
                              p.remoteStream!.getVideoTracks().isNotEmpty &&
                              renderers[p.userId] != null)
                          ? RTCVideoView(
                              renderers[p.userId]!,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A participant in the strip under a shared screen: a small tile with
/// their camera or their face, the presenter marked with the accent.
class _StripTile extends StatelessWidget {
  const _StripTile({
    required this.label,
    required this.level,
    required this.accent,
    required this.user,
    this.api,
    this.video,
    this.muted = false,
    this.dimmed = false,
    this.presenting = false,
  });

  final String label;
  final ValueNotifier<double> level;
  final Color accent;
  final ChatUser user;
  final ChatApi? api;
  final Widget? video;
  final bool muted;
  final bool dimmed;
  final bool presenting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 76,
        child: _Tile(
          label: label,
          level: level,
          accent: accent,
          user: user,
          api: api,
          video: video,
          muted: muted,
          dimmed: dimmed,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// One line of live link stats over a tile or under a face, redrawn on each
/// two-second sample and on nothing else.
class _StatsCaption extends StatelessWidget {
  const _StatsCaption({required this.listenable, required this.text});

  final Listenable listenable;
  final String? Function() text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final line = text();
        if (line == null) return const SizedBox.shrink();
        return Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: callCaptionStyle(theme).copyWith(
            shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
          ),
        );
      },
    );
  }
}

/// "↓ 1.2 Mb/s · 48 ms · 0.3%" — what a peer's link is delivering, how long
/// a round trip takes and how much is lost. Parts the sample has no number
/// for are left out rather than shown as dashes; null when it has none.
@visibleForTesting
String? statsDownLine(CallQualitySnapshot? s) {
  if (s == null) return null;
  final parts = <String>[
    if (s.inKbps != null) '↓ ${_mbps(s.inKbps!)} Mb/s',
    if (s.rttMs != null) '${s.rttMs!.round()} ms',
    if (s.lossPercent != null) '${s.lossPercent!.toStringAsFixed(1)}%',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "↑ 2.4 Mb/s" — everything this phone is sending, over every link.
@visibleForTesting
String? statsUpLine(double? outKbps) =>
    outKbps == null ? null : '↑ ${_mbps(outKbps)} Mb/s';

String _mbps(double kbps) => (kbps / 1000).toStringAsFixed(1);
