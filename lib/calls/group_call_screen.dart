import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../privacy/capture_protection.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/user_avatar.dart';
import 'audio_level_monitor.dart';
import 'call_media.dart';
import 'draw/draw_canvas.dart';
import 'draw/draw_model.dart';
import 'group_call_service.dart';
import 'screen_share.dart';
import 'share_picker_sheet.dart';
import 'widgets/call_chrome.dart';

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

class _GroupCallScreenState extends State<GroupCallScreen> {
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
  ChatUser? _me;

  final AudioLevelMonitor _levels = AudioLevelMonitor();

  GroupCallService get svc => widget.service;

  @override
  void initState() {
    super.initState();
    svc.addListener(_onChanged);
    svc.drawArmed.addListener(_onChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _levels.sources = () => [
          for (final p in svc.peers.values)
            if (p.pc != null)
              AudioLevelSource(
                id: p.userId,
                pc: p.pc!,
                track: _firstAudio(p.remoteStream),
                muted: p.mediaState.audioMuted || !p.connected,
              ),
        ];
    _levels.localPc = () {
      for (final p in svc.peers.values) {
        if (p.pc != null) return p.pc;
      }
      return null;
    };
    _levels.start();
    unawaited(_syncRenderers());
    unawaited(ScreenShare.supported().then((ok) {
      if (mounted && ok != _shareSupported) setState(() => _shareSupported = ok);
    }));
    unawaited(_loadMe());
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
      if (mounted && me != null) setState(() => _me = me);
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
    }
  }

  void _drop(String key) {
    final r = _renderers.remove(key);
    _boundTicks.remove(key);
    if (r != null) {
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
      svc.localScreenSharing,
      svc.localStreamTick,
      svc.localScreenStreamTick,
      svc.speakerOn,
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
    unawaited(_syncRenderers());
    final key = _buildKey();
    if (key == _lastBuiltKey) return;
    _lastBuiltKey = key;
    setState(() {});
  }

  @override
  void dispose() {
    svc.removeListener(_onChanged);
    svc.drawArmed.removeListener(_onChanged);
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // -------------------------------------------------------------- actions

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = !_controlsVisible);
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
    // In the voice layout the chrome is the screen; only over video does a
    // tap put it away.
    final chromeVisible = layout == _Layout.voice || _controlsVisible;

    final Widget stage = switch (layout) {
      _Layout.voice => _VoiceStage(
          key: const ValueKey('voice'),
          service: svc,
          api: widget.api,
          levels: _levels,
          me: _meUser,
          theme: theme,
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
        ),
    };

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: layout == _Layout.voice ? null : _toggleControls,
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  svc.roomName ??
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
                                        style: theme.monoTiny.copyWith(
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (svc.joinedAt != null) ...[
                                      Text(
                                        '  ·  ',
                                        style: theme.monoTiny.copyWith(
                                          color: Colors.white38,
                                        ),
                                      ),
                                      ElapsedLabel(
                                        start: svc.joinedAt!,
                                        style: theme.monoTiny.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.groupCallScreenParticipantCount(
                                peers.length + 1,
                              ),
                              style: theme.monoTiny.copyWith(
                                color: Colors.white70,
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlassTray(
                            maxWidth: 480,
                            child: _tray(theme, l10n, layout),
                          ),
                          const SizedBox(height: 16),
                          CallControlButton(
                            icon: Icons.call_end,
                            background: theme.danger,
                            iconColor: Colors.white,
                            large: true,
                            onTap: () => unawaited(svc.leaveCall()),
                            label: l10n.groupCallScreenLeaveLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tray(AppTheme theme, AppLocalizations l10n, _Layout layout) {
    final sharing = svc.localScreenSharing;
    final someoneElseSharing = !sharing && svc.presentingPeer != null;
    return ValueListenableBuilder<bool>(
      valueListenable: svc.drawArmed,
      builder: (context, armed, _) => Row(
        children: [
          Expanded(
            child: CallControlButton(
              icon: svc.localMuted ? Icons.mic_off : Icons.mic,
              active: svc.localMuted,
              onTap: svc.toggleMute,
              label: svc.localMuted
                  ? l10n.groupCallScreenUnmuteLabel
                  : l10n.groupCallScreenMuteLabel,
            ),
          ),
          Expanded(
            child: CallControlButton(
              icon: svc.localCamActive ? Icons.videocam : Icons.videocam_off,
              active: !svc.localCamActive,
              onTap: () => unawaited(svc.toggleVideo()),
              label: svc.localCamActive
                  ? l10n.groupCallScreenCamOffLabel
                  : l10n.groupCallScreenCamOnLabel,
            ),
          ),
          if (svc.localCamActive && isMobileCallPlatform)
            Expanded(
              child: CallControlButton(
                icon: Icons.cameraswitch_outlined,
                onTap: () => unawaited(svc.switchCamera()),
                label: l10n.groupCallScreenFlipLabel,
              ),
            ),
          Expanded(
            child: CallControlButton(
              icon: svc.speakerOn ? Icons.volume_up : Icons.phone_in_talk,
              active: svc.speakerOn,
              onTap: () => unawaited(svc.toggleSpeaker()),
              label: l10n.groupCallScreenSpeakerLabel,
            ),
          ),
          if (_shareSupported)
            Expanded(
              child: CallControlButton(
                icon: sharing
                    ? Icons.stop_screen_share_outlined
                    : Icons.screen_share_outlined,
                active: sharing,
                enabled: !someoneElseSharing,
                onTap: () => unawaited(_onShareTap()),
                label: sharing
                    ? l10n.groupCallScreenStopShareLabel
                    : l10n.groupCallScreenShareLabel,
              ),
            ),
          if (layout == _Layout.stage)
            Expanded(
              child: CallControlButton(
                icon: Icons.draw_outlined,
                active: armed,
                onTap: () => svc.drawArmed.value = !armed,
                label: l10n.groupCallScreenDrawLabel,
              ),
            ),
          Expanded(
            child: CallControlButton(
              icon: Icons.keyboard_arrow_down_rounded,
              onTap: _hide,
              label: l10n.groupCallScreenMinimizeLabel,
            ),
          ),
        ],
      ),
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
  });

  final GroupCallService service;
  final ChatApi? api;
  final AudioLevelMonitor levels;
  final ChatUser me;
  final AppTheme theme;

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
            final byHeight = (c.maxHeight - 300) / rows - 44;
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

            final mine = orbFor(
              me,
              l10n.groupCallScreenYouLabel,
              isMe: true,
              muted: service.localMuted,
            );
            return Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 96, 20, 190),
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
                      mine,
                    for (final p in peers)
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

class _VideoGrid extends StatelessWidget {
  const _VideoGrid({
    super.key,
    required this.service,
    required this.api,
    required this.levels,
    required this.me,
    required this.renderers,
    required this.localRenderer,
    required this.theme,
  });

  final GroupCallService service;
  final ChatApi? api;
  final AudioLevelMonitor levels;
  final ChatUser me;
  final Map<String, RTCVideoRenderer> renderers;
  final RTCVideoRenderer? localRenderer;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final peers = service.peers.values.toList(growable: false);
    final tileCount = peers.length + 1;
    final baselineColumns = tileCount <= 1
        ? 1
        : tileCount <= 4
            ? 2
            : 3;
    final columns = (MediaQuery.sizeOf(context).width / 220).floor().clamp(
          baselineColumns,
          tileCount,
        );
    final showLocal =
        service.localCamActive && localRenderer != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 76, 10, 236),
        child: GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3 / 4,
          children: [
            _Tile(
              label: l10n.groupCallScreenYouLabel,
              muted: service.localMuted,
              level: levels.levelOf(AudioLevelMonitor.me),
              accent: theme.accent,
              user: me,
              api: api,
              video: showLocal
                  ? RTCVideoView(
                      localRenderer!,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : null,
            ),
            for (final peer in peers)
              _Tile(
                label: peer.name,
                muted: peer.mediaState.audioMuted,
                dimmed: !peer.connected || peer.reconnecting,
                level: levels.levelOf(peer.userId),
                accent: theme.accent,
                user: ChatUser(
                  id: peer.userId,
                  username: '',
                  name: peer.name,
                  avatarStorageId: peer.avatarStorageId,
                ),
                api: api,
                video: (!peer.mediaState.videoOff &&
                        peer.remoteStream != null &&
                        peer.remoteStream!.getVideoTracks().isNotEmpty &&
                        renderers[peer.userId] != null)
                    ? RTCVideoView(
                        renderers[peer.userId]!,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// One grid tile: the video, or the person when there is none; the name
/// and mic state in the corner; a border that lights when they talk.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.level,
    required this.accent,
    required this.user,
    this.api,
    this.video,
    this.muted = false,
    this.dimmed = false,
  });

  final String label;
  final ValueNotifier<double> level;
  final Color accent;
  final ChatUser user;
  final ChatApi? api;
  final Widget? video;
  final bool muted;
  final bool dimmed;

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
                      (math.min(c.maxWidth, c.maxHeight) * 0.42).clamp(48.0, 96.0);
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
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                if (muted) ...[
                  const Icon(Icons.mic_off, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      builder: (context, l, child) {
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
  });

  final GroupCallService service;
  final ChatApi? api;
  final AudioLevelMonitor levels;
  final ChatUser me;
  final Map<String, RTCVideoRenderer> renderers;
  final RTCVideoRenderer? localRenderer;
  final RTCVideoRenderer? localScreenRenderer;
  final AppTheme theme;

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

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 72),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: const Color(0xFF0E0F12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (screenRenderer != null)
                        ValueListenableBuilder<bool>(
                          valueListenable: service.drawArmed,
                          builder: (context, armed, _) => ShareSurface(
                            renderer: screenRenderer,
                            model: service.drawModel,
                            // The presenter draws through the app-wide
                            // overlay, which is what maps to the screen
                            // being captured; here it would draw twice.
                            armed: armed && !mine,
                            inkColor: ink,
                          ),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.screen_share_outlined,
                                size: 40,
                                color: theme.accent.withValues(alpha: 0.9),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                caption,
                                style: theme.body.copyWith(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _CaptionPill(text: caption, theme: theme),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _Chip(
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
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : null,
                ),
                for (final p in peers)
                  _Chip(
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
          const SizedBox(height: 228),
        ],
      ),
    );
  }
}

class _CaptionPill extends StatelessWidget {
  const _CaptionPill({required this.text, required this.theme});
  final String text;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: theme.monoTiny.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A participant in the strip under a shared screen: a small tile with
/// their camera or their face, the presenter marked with the accent.
class _Chip extends StatelessWidget {
  const _Chip({
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
