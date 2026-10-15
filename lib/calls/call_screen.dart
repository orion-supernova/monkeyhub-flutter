import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../privacy/capture_protection.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/route_landing.dart';
import '../theme/motion.dart';
import 'audio_level_monitor.dart';
import 'call_audio_devices.dart';
import 'call_audio_sheet.dart';
import 'call_media.dart';
import 'call_models.dart';
import 'call_options_sheet.dart';
import 'call_service.dart';
import 'call_stats_monitor.dart';
import 'draw/draw_canvas.dart';
import 'draw/draw_model.dart';
import 'draw/overlay_permission_hint.dart';
import 'screen_share.dart';
import 'share_picker_sheet.dart';
import 'widgets/call_chrome.dart';

/// Full-screen UI for the active call. Listens to [CallService] and pops
/// itself once the session transitions to a terminal state.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.service, this.api});
  final CallService service;

  /// Used to load the peer's avatar image; falls back to the per-user
  /// gradient + initial when absent.
  final ChatApi? api;

  /// Seam for tests: the renderer behind every video view. The real one
  /// needs the plugin's texture channel, which a widget test does not have.
  @visibleForTesting
  static RTCVideoRenderer Function() rendererFactory = RTCVideoRenderer.new;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with RouteLanding<CallScreen> {
  final _localRenderer = CallScreen.rendererFactory();
  final _remoteRenderer = CallScreen.rendererFactory();
  final _remoteScreenRenderer = CallScreen.rendererFactory();
  final _localScreenRenderer = CallScreen.rendererFactory();
  bool _renderersReady = false;
  // A voice call touches no renderer — no GPU textures allocated, nothing to
  // dispose — until the first video appears on it: a camera coming on, a
  // screen shared. Then the renderers are set up, once, and kept.
  bool _renderersUsed = false;
  bool _settingUp = false;
  int _boundRemoteScreenTick = -1;
  int _boundLocalScreenTick = -1;
  bool _shareSupported = false;
  // Mirrors CallService.remoteStreamTick — we re-bind the remote renderer
  // whenever the tick advances, even if the stream reference is unchanged,
  // because audio + video tracks arrive as separate onTrack events on the
  // same MediaStream and the renderer otherwise won't pick up the video.
  int _boundRemoteTick = -1;
  // Mirrors CallService.localStreamTick — same rationale as _boundRemoteTick,
  // but for switchVideoQuality's in-place track swap on the LOCAL stream
  // (replaceTrack + addTrack/removeTrack on the same MediaStream object).
  int _boundLocalTick = -1;
  // CallService._teardown fires notifyListeners twice during shutdown
  // (status → ended, then session → null 400ms later). Without this guard
  // each notify would schedule its own delayed pop and the second would
  // dismiss the chatroom beneath this screen.
  bool _popScheduled = false;
  // Which feed renders full-bleed vs. the small PiP tile. false = remote
  // full-bleed / local PiP (today's default). Only meaningful once both
  // feeds are up (remoteVisible) — reset in _onChanged whenever that's no
  // longer true, so a later reconnect never resumes a stale swap.
  bool _pipIsLocal = false;
  // Whether the name/status overlay, status chip, and bottom control tray
  // are shown. Tapping empty call-screen background toggles this.
  bool _controlsVisible = true;
  // Fingerprint of everything build() consumes — CallService notifies far
  // more often than this screen visually changes, and a rebuild here means
  // re-compositing two video views under a blur tray.
  int? _lastBuiltKey;

  /// The peer's voice, for the rings around their face once a voice call is
  /// up. Polls only while that is what is on screen; see [_syncLevels].
  final AudioLevelMonitor _levels = AudioLevelMonitor();
  bool _levelsOn = false;

  static const _peerLevelId = 'peer';

  void _syncLevels(bool want) {
    if (want == _levelsOn) return;
    _levelsOn = want;
    want ? _levels.start() : _levels.stop();
  }

  @override
  void initState() {
    super.initState();
    _levels.sources = () {
      final svc = widget.service;
      final pc = svc.peerConnection;
      final s = svc.session;
      if (pc == null || s == null) return const [];
      final audio = svc.remoteStream?.getAudioTracks() ?? const [];
      // No track, no poll: without one the monitor falls back to the
      // whole connection's stats, built and decoded three times a second
      // on the platform thread (iOS draws frames on it) for one number.
      if (audio.isEmpty) return const [];
      return [
        AudioLevelSource(
          id: _peerLevelId,
          pc: pc,
          track: audio.first,
          muted: s.peerState.audioMuted,
        ),
      ];
    };
    if (_shown?.mediaKind == CallMediaKind.video ||
        _anyVideo) {
      _wantRenderers();
    }
    widget.service.addListener(_onChanged);
    widget.service.drawArmed.addListener(_onChanged);
    CallAudioDevices.instance
      ..attach()
      ..registerWebSinks(_renderers)
      ..addListener(_onChanged);
    // Known on the first frame wherever it can be: an answer that came a
    // frame later grew the tray a share button mid-slide, and on a phone
    // that sixth control wrapped it onto a second row, so the whole tray
    // and the face above it jumped as the screen came up. Every call.
    final share = ScreenShare.knownSupported;
    if (share != null) {
      _shareSupported = share;
    } else {
      unawaited(ScreenShare.supported().then((ok) {
        if (!mounted) return;
        // Still sliding: the button lands once the screen stands still.
        if (!_settled) {
          _pendingShareSupported = ok;
          return;
        }
        if (ok != _shareSupported) setState(() => _shareSupported = ok);
      }));
    }
  }

  bool _landedOnce = false;

  /// The route has finished sliding in (or there is no route to slide).
  /// [RouteLanding]'s answer, never the route animation read during a
  /// build: for the first frame of a push the navigator holds the page
  /// offstage, where its animation reads as complete. Read that way (as
  /// this screen did), "after the slide" was the slide's first frame, and
  /// the bars went away and the renderers were made right on top of it.
  bool get _settled => landed;

  /// Video arrived, or was due, while the route was still sliding:
  /// the renderers are made once it stands still. See [_wantRenderers].
  bool _renderersWanted = false;

  /// [ScreenShare.supported]'s answer when it came mid-slide.
  bool? _pendingShareSupported;

  /// The video renderers and a late share button wait until the screen has
  /// finished sliding up, see [_wantRenderers]. The status bar stays, as in
  /// WhatsApp and Telegram: hiding it changed the window's insets, which
  /// relaid out every screen in the app, and took the clock and signal away
  /// for the whole call.
  @override
  void onRouteLandingChanged() {
    if (!landed || _landedOnce) return;
    _landedOnce = true;
    if (_renderersWanted) _ensureRenderers();
    final share = _pendingShareSupported;
    _pendingShareSupported = null;
    if (share != null && share != _shareSupported) {
      setState(() => _shareSupported = share);
    }
  }

  /// The call on screen: the session, or before it exists the tap's dial
  /// ([CallService.dialing]), so the screen is up while the backend row is
  /// still being reserved.
  CallSession? get _shown => widget.service.session ?? widget.service.dialing;

  /// Whether there is anything to render — ours or theirs, camera or screen.
  bool get _anyVideo {
    final svc = widget.service;
    return svc.hasAnyVideo ||
        svc.remoteScreenStream != null ||
        svc.localScreenSharing;
  }

  /// Video is (or is about to be) on this call: make the renderers, but
  /// not while the screen is still sliding up. Each one is a texture and
  /// an event channel registered on the platform thread, which on iOS is
  /// the thread that presents Flutter's frames, and four of them in a row
  /// at the start of a video call's slide competed with it. The wait
  /// is at most the slide's own transition (500 ms on iOS's Cupertino
  /// route), and the camera is not up before then anyway (a dial's media
  /// waits for the same moment).
  void _wantRenderers() {
    if (_settled) {
      _ensureRenderers();
    } else {
      _renderersWanted = true;
    }
  }

  void _ensureRenderers() {
    if (_renderersUsed || _settingUp) return;
    _settingUp = true;
    _renderersUsed = true;
    unawaited(_setupRenderers());
  }

  /// The renderers whose initialize() has completed.
  final Set<RTCVideoRenderer> _initialized = {};

  List<RTCVideoRenderer> get _renderers => [
    _localRenderer,
    _remoteRenderer,
    _remoteScreenRenderer,
    _localScreenRenderer,
  ];

  Future<void> _setupRenderers() async {
    try {
      for (final r in _renderers) {
        await r.initialize();
        _initialized.add(r);
      }
    } catch (e) {
      debugPrint('CallScreen: renderer init failed: $e');
    }
    _settingUp = false;
    if (!mounted) {
      // The screen went while the textures were still being made. dispose()
      // left them to us: a renderer disposed mid-initialize has no texture
      // id yet, so the plugin skips the native release, and the texture and
      // its event channel it creates a moment later live on for good, one
      // set per call that ended (or was hidden) inside that window.
      _releaseRenderers();
      return;
    }
    // Only a full set: a renderer whose initialize threw has no texture,
    // and binding a stream to it throws.
    if (_initialized.length != _renderers.length) return;
    _renderersReady = true;
    _syncStreams();
    setState(() {});
  }

  /// Frees every renderer, unbinding first the ones that initialized, so
  /// the native track lets go of a renderer before its texture is
  /// unregistered. Setting a stream on one that never initialized throws,
  /// which in dispose() used to abort the rest of the teardown.
  void _releaseRenderers() {
    for (final r in _renderers) {
      if (_initialized.contains(r)) {
        try {
          r.srcObject = null;
        } catch (e) {
          debugPrint('CallScreen: renderer unbind failed: $e');
        }
      }
      unawaited(r.dispose().catchError((Object e) {
        debugPrint('CallScreen: renderer dispose failed: $e');
      }));
    }
  }

  void _syncStreams() {
    if (!_renderersReady) return;
    final svc = widget.service;
    final remoteBefore = (_boundRemoteTick, _boundRemoteScreenTick);
    if (_localRenderer.srcObject != svc.localStream ||
        _boundLocalTick != svc.localStreamTick) {
      _localRenderer.srcObject = svc.localStream;
      _boundLocalTick = svc.localStreamTick;
    }
    if (_remoteRenderer.srcObject != svc.remoteStream ||
        _boundRemoteTick != svc.remoteStreamTick) {
      _remoteRenderer.srcObject = svc.remoteStream;
      _boundRemoteTick = svc.remoteStreamTick;
    }
    if (_remoteScreenRenderer.srcObject != svc.remoteScreenStream ||
        _boundRemoteScreenTick != svc.remoteScreenStreamTick) {
      _remoteScreenRenderer.srcObject = svc.remoteScreenStream;
      _boundRemoteScreenTick = svc.remoteScreenStreamTick;
    }
    // Our own share, previewed only where the preview is not a mirror
    // tunnel — a desktop window, not the whole phone screen.
    final ownScreen =
        svc.localScreenSharing && !isMobileCallPlatform ? svc.screenStream : null;
    if (_localScreenRenderer.srcObject != ownScreen ||
        _boundLocalScreenTick != svc.localScreenStreamTick) {
      _localScreenRenderer.srcObject = ownScreen;
      _boundLocalScreenTick = svc.localScreenStreamTick;
    }
    // Web: a freshly bound renderer made a new <audio> element, which
    // plays on the default speaker until pointed at the chosen one.
    if (remoteBefore != (_boundRemoteTick, _boundRemoteScreenTick)) {
      unawaited(CallAudioDevices.instance.reapplyWebSink());
    }
  }

  int _buildKey() {
    final svc = widget.service;
    final s = _shown;
    return Object.hashAll([
      s?.callId,
      s?.status,
      s?.peerName,
      s?.peerAvatarStorageId,
      s?.localMuted,
      s?.localVideoOff,
      s?.speakerOn,
      s?.reconnecting,
      s?.peerRinging,
      s?.peerState.audioMuted,
      s?.peerState.videoOff,
      s?.peerState.screenSharing,
      s?.localScreenSharing,
      s?.errorMessage,
      svc.localStream,
      svc.localStreamTick,
      svc.localCamActive,
      svc.cameraButtonOn,
      svc.remoteStream,
      svc.remoteStreamTick,
      svc.remoteScreenStream,
      svc.remoteScreenStreamTick,
      svc.localScreenStreamTick,
      svc.drawArmed.value,
      CallAudioDevices.instance.revision,
      _renderersReady,
      _pipIsLocal,
      _controlsVisible,
      _shareSupported,
    ]);
  }

  /// Both feeds are up: the remote video is actually on screen (as opposed
  /// to the pre-connect "your own camera fills the screen" state). This is
  /// the only state where a PiP tile — and therefore a swap target — exists.
  bool _remoteVisible(CallSession? s) {
    final svc = widget.service;
    final rs = svc.remoteStream;
    return s != null &&
        rs != null &&
        rs.getVideoTracks().isNotEmpty &&
        !s.peerState.videoOff &&
        _renderersReady;
  }

  /// The peer's screen is on the way in and has a picture.
  bool _remoteScreenVisible(CallSession? s) {
    final svc = widget.service;
    return s != null &&
        s.peerState.screenSharing &&
        svc.remoteScreenStream != null &&
        _renderersReady;
  }

  void _swapPip() {
    if (!mounted) return;
    setState(() => _pipIsLocal = !_pipIsLocal);
  }

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

  void _onChanged() {
    if (!mounted) return;
    final s = _shown;
    if (_anyVideo) _wantRenderers();
    _syncStreams();
    // A swap only makes sense while both feeds are on screen. If the peer's
    // video drops or the user turns their own camera off, un-swap so no one
    // gets stuck staring at a frozen/disabled feed full-screen.
    if (_pipIsLocal && (!_remoteVisible(s) || !widget.service.localCamActive)) {
      _pipIsLocal = false;
    }
    if (s == null ||
        s.status == CallStatus.ended ||
        s.status == CallStatus.failed ||
        s.status == CallStatus.handedOff) {
      // Show the terminal state briefly, then pop — but only once.
      // handedOff pops immediately and silently (no error toast); the
      // call moved to another of my devices.
      if (!_popScheduled) {
        _popScheduled = true;
        final delay = (s != null && s.status == CallStatus.handedOff)
            ? const Duration(milliseconds: 80)
            : const Duration(milliseconds: 500);
        Future.delayed(delay, () {
          if (mounted) dismissCallRoute(context);
        });
      }
    }
    final key = _buildKey();
    if (key == _lastBuiltKey) return;
    _lastBuiltKey = key;
    setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    widget.service.drawArmed.removeListener(_onChanged);
    CallAudioDevices.instance
      ..removeListener(_onChanged)
      ..unregisterWebSinks(_renderers)
      ..detach();
    // Still initializing: _setupRenderers frees them once it finishes, see
    // there.
    if (_renderersUsed && !_settingUp) _releaseRenderers();
    _levels.dispose();
    super.dispose();
  }

  void _hide() => dismissCallRoute(context);

  Future<void> _onShareTap() async {
    final svc = widget.service;
    final s = svc.session;
    if (s == null) return;
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    if (svc.localScreenSharing) {
      await svc.stopScreenShare();
      return;
    }
    if (s.peerState.screenSharing) {
      toast.show(l10n.screenShareSomeoneElsePresenting(s.peerName));
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

  /// "Video call" / "Voice call" — prefixed to pre-active statuses so the
  /// two call kinds are never ambiguous (the active state shows the timer
  /// alone, WhatsApp-style).
  String _kindLabel(CallSession s) {
    final loc = AppLocalizations.of(context);
    return s.mediaKind == CallMediaKind.video
        ? loc.callScreenVideoCallLabel
        : loc.callScreenVoiceCallLabel;
  }

  String _statusLabel(CallSession s) {
    final loc = AppLocalizations.of(context);
    switch (s.status) {
      case CallStatus.outgoingRinging:
        // "Calling" until a device of theirs reports its ringer is up.
        return s.peerRinging
            ? loc.callScreenStatusRinging(_kindLabel(s))
            : loc.callScreenStatusCalling(_kindLabel(s));
      case CallStatus.incomingRinging:
        return loc.callScreenStatusIncoming(_kindLabel(s));
      case CallStatus.connecting:
        return loc.callScreenStatusConnecting(_kindLabel(s));
      case CallStatus.active:
        return loc.callScreenStatusConnected;
      case CallStatus.ended:
        return s.errorMessage ?? loc.callScreenStatusEnded;
      case CallStatus.failed:
        return s.errorMessage ?? loc.callScreenStatusFailed;
      case CallStatus.switching:
        return loc.callScreenStatusSwitching;
      case CallStatus.handedOff:
        return loc.callScreenStatusMoved;
      case CallStatus.idle:
        return '';
    }
  }

  /// Status line for the top overlay / audio backdrop. The active state
  /// renders [_ElapsedLabel], which owns its own 1 Hz ticker — so the
  /// per-second repaint is one Text, not this whole screen (which carries
  /// two video views under a BackdropFilter).
  Widget _statusWidget(CallSession s, TextStyle style) {
    final start = s.connectedAt ?? s.startedAt;
    if (s.status == CallStatus.active && start != null) {
      return ElapsedLabel(start: start, style: style);
    }
    return Text(_statusLabel(s), style: style);
  }

  /// The peer as a [ChatUser] so avatar widgets can render a real photo
  /// (via api + storage id) with the per-user gradient fallback.
  ChatUser _peerAsUser(CallSession s) => ChatUser(
    id: s.peerUserId,
    username: '',
    name: s.peerName,
    avatarStorageId: s.peerAvatarStorageId,
  );

  /// The tray's controls, in the order they keep the first row: the
  /// everyday toggles first, the occasional ones last. The audio control
  /// is ALWAYS present (on a phone video defaults to loudspeaker, voice to
  /// earpiece, both switchable; see [callAudioTrayAction]).
  List<CallTrayAction> _trayActions(
    AppLocalizations l10n,
    CallSession s,
    CallService svc, {
    required bool stage,
    required bool ownScreen,
  }) {
    final pending = svc.screenSharePending;
    return [
      CallTrayAction(
        icon: s.localMuted ? CallGlyphs.micOff : CallGlyphs.mic,
        active: s.localMuted,
        onTap: widget.service.toggleMute,
        label: s.localMuted
            ? l10n.callScreenControlUnmute
            : l10n.callScreenControlMute,
      ),
      CallTrayAction(
        // The wish while it is carried out, else the camera's real state.
        icon: svc.cameraButtonOn ? CallGlyphs.camera : CallGlyphs.cameraOff,
        active: !svc.cameraButtonOn,
        onTap: () => unawaited(widget.service.toggleVideo()),
        label: svc.cameraButtonOn
            ? l10n.callScreenControlCamOff
            : l10n.callScreenControlCamOn,
      ),
      // The real route on a phone (a toggle, or the route sheet once a
      // headset is a choice); the device picker on desktop and web.
      callAudioTrayAction(
        context,
        speakerOn: s.speakerOn,
        onToggleSpeaker: widget.service.toggleSpeaker,
        selectSpeaker: widget.service.selectSpeaker,
        switchWebMic: (id) => switchWebMicrophone(
          deviceId: id,
          localStream: svc.localStream,
          peerConnections: [?svc.peerConnection],
        ),
      ),
      if (_shareSupported)
        CallTrayAction(
          icon: ownScreen ? CallGlyphs.stopShare : CallGlyphs.share,
          active: ownScreen,
          // Disabled while the peer holds the stage, and while our own
          // share is being set up (the picker, the countdown) — a second
          // tap then would start a second capture.
          enabled: ownScreen || (!s.peerState.screenSharing && !pending),
          onTap: () => unawaited(_onShareTap()),
          label: ownScreen
              ? l10n.callScreenControlStopShare
              : pending
                  ? l10n.callScreenControlShareStarting
                  : l10n.callScreenControlShare,
        ),
      if (stage)
        CallTrayAction(
          icon: CallGlyphs.draw,
          active: svc.drawArmed.value,
          onTap: () => svc.drawArmed.value = !svc.drawArmed.value,
          label: l10n.callScreenControlDraw,
        ),
      if (svc.localCamActive && isMobileCallPlatform)
        CallTrayAction(
          icon: CallGlyphs.flip,
          onTap: widget.service.switchCamera,
          label: l10n.callScreenControlFlip,
        ),
      CallTrayAction(
        icon: CallGlyphs.more,
        onTap: () => showAdaptiveSheet(
          context,
          builder: (_) => CallOptionsSheet(
            service: widget.service,
            showVideoQuality: svc.localCamActive,
          ),
        ),
        label: l10n.callScreenControlOptions,
      ),
      CallTrayAction(
        icon: CallGlyphs.hide,
        onTap: _hide,
        label: l10n.callScreenControlMinimize,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final s = _shown;
    if (s == null) {
      return const AnnotatedRegion<SystemUiOverlayStyle>(
        value: kCallStatusBarStyle,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(),
        ),
      );
    }
    final svc = widget.service;
    final remoteVisible = _remoteVisible(s);
    final remoteScreenVisible = _remoteScreenVisible(s);
    final ownScreen = svc.localScreenSharing;
    final stage = remoteScreenVisible || ownScreen;
    // WhatsApp-style pre-answer/pre-connect view for video calls: your own
    // camera fills the screen until the peer's video arrives (then the
    // local view shrinks into the PiP tile).
    final localFullscreen =
        !stage &&
        !remoteVisible &&
        svc.localCamActive &&
        svc.localStream != null &&
        _renderersReady;
    // Anything on screen that is not the voice backdrop: the top overlay and
    // the tap-to-hide chrome apply.
    final isVideo = stage || remoteVisible || localFullscreen;
    // Voice levels are polled only for what shows them: a connected voice
    // call, with decorative motion allowed. Started after the frame, not
    // from inside build.
    final wantLevels = !isVideo &&
        s.status == CallStatus.active &&
        !MotionScope.of(context).calm;
    if (wantLevels != _levelsOn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncLevels(wantLevels);
      });
    }
    final myInk = drawColorFor(svc.userId ?? 'me', theme);
    final l10n = AppLocalizations.of(context);
    final trayActions = _trayActions(
      l10n,
      s,
      svc,
      stage: stage,
      ownScreen: ownScreen,
    );
    // What the tray covers, so the voice backdrop and the stage caption
    // keep clear of it however many rows it needs.
    final trayInset = CallTray.estimateHeight(
      actionCount: trayActions.length,
      width: MediaQuery.sizeOf(context).width,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kCallStatusBarStyle,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onVerticalDragEnd: _onVerticalSwipe,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Remote video / local camera preview / audio avatar. No tap
                // handler here on purpose — a tap on this area falls through to
                // the outer GestureDetector's show/hide toggle. Only the small
                // PiP tile below is the swap target.
                //
                // Every layer is keyed. They are mostly Positioned, and an
                // unkeyed Stack matches children by type and slot: a layer
                // coming or going (the self-view as the peer's video lands,
                // the scrim, the stage) handed one layer's element to
                // another and rebuilt both subtrees from scratch, the
                // self-view's corner and drag state with them.
                if (stage)
                  _ShareStage(
                    key: const ValueKey('stage'),
                    service: svc,
                    session: s,
                    remoteRenderer: _remoteScreenRenderer,
                    localRenderer: _localScreenRenderer,
                    ink: myInk,
                    theme: theme,
                    // Under the name and status block at the top; the tray
                    // is where it used to sit, and with two rows of controls
                    // that put the caption in the middle of the picture.
                    topInset: MediaQuery.paddingOf(context).top + 76,
                  )
                else if (remoteVisible)
                  RTCVideoView(
                    key: const ValueKey('feed'),
                    _pipIsLocal ? _localRenderer : _remoteRenderer,
                    mirror: _pipIsLocal,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                else if (localFullscreen) ...[
                  RTCVideoView(
                    key: const ValueKey('feed'),
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                  // Soft darkening so the overlaid name/status/controls read
                  // over any camera image.
                  IgnorePointer(
                    key: const ValueKey('feed-dim'),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ] else
                  AudioBackdrop(
                    key: const ValueKey('voice'),
                    name: s.peerName,
                    status: _statusWidget(
                      s,
                      callStatusStyle(theme),
                    ),
                    peerMuted: s.peerState.audioMuted,
                    theme: theme,
                    user: _peerAsUser(s),
                    api: widget.api,
                    bottomInset: trayInset,
                    waiting: s.status != CallStatus.active,
                    voiceLevel: _levels.levelOf(_peerLevelId),
                  ),

                // Top scrim so the name/status stay legible over video.
                if (remoteVisible || localFullscreen)
                  Positioned(
                    key: const ValueKey('scrim'),
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
                  ),

                // Local PiP — only once the remote video is on screen (before
                // that the local camera IS the fullscreen view). Tapping it
                // swaps which feed is full-bleed vs. tiled.
                if (stage && remoteVisible)
                  Positioned(
                    key: const ValueKey('stage-peer'),
                    top: MediaQuery.paddingOf(context).top + 16,
                    right: svc.localCamActive ? 132 : 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      child: Container(
                        width: 100,
                        height: 140,
                        color: Colors.black,
                        child: RTCVideoView(
                          _remoteRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
                if (svc.localCamActive && stage)
                  Positioned(
                    key: const ValueKey('stage-self'),
                    top: MediaQuery.paddingOf(context).top + 16,
                    right: 16,
                    child: FocusableTap(
                      onTap: _swapPip,
                      semanticLabel: AppLocalizations.of(
                        context,
                      ).callScreenSwapPreviewSemanticLabel,
                      shape: FocusRingShape.rounded,
                      radius: theme.radiusMd,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _swapPip,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(theme.radiusMd),
                          child: Container(
                            width: 100,
                            height: 140,
                            color: Colors.black,
                            child: RTCVideoView(
                              _pipIsLocal && !stage
                                  ? _remoteRenderer
                                  : _localRenderer,
                              mirror: !_pipIsLocal || stage,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Outside a shared screen the self-view floats: drag it to any
                // corner, FaceTime-style. A tap still swaps the feeds.
                if (svc.localCamActive && remoteVisible && !stage)
                  Positioned.fill(
                    key: const ValueKey('self-view'),
                    child: DraggablePip(
                      top: MediaQuery.paddingOf(context).top + 16,
                      bottom: trayInset + MediaQuery.paddingOf(context).bottom,
                      child: FocusableTap(
                        onTap: _swapPip,
                        semanticLabel: AppLocalizations.of(
                          context,
                        ).callScreenSwapPreviewSemanticLabel,
                        shape: FocusRingShape.rounded,
                        radius: 18,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _swapPip,
                          child: ColoredBox(
                            color: Colors.black,
                            child: RTCVideoView(
                              _pipIsLocal ? _remoteRenderer : _localRenderer,
                              mirror: !_pipIsLocal,
                              objectFit:
                                  RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Top overlay: name + status (video only — voice calls show the
                // name + timer centered under the avatar instead).
                if (isVideo)
                  Positioned(
                    key: const ValueKey('title'),
                    top: MediaQuery.paddingOf(context).top + 18,
                    left: 24,
                    right: 132,
                    child: ControlsFade(
                      visible: _controlsVisible,
                      slide: const Offset(0, -0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.peerName,
                            style: theme.displaySmall.copyWith(
                              color: Colors.white,
                              shadows: const [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _statusWidget(
                                s,
                                callStatusStyle(theme),
                              ),
                              if (s.peerState.audioMuted) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  CallGlyphs.micOff,
                                  size: 15,
                                  color: Colors.white70,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Status chip row: device-switching renegotiation, ICE-restart
                // recovery, or (via its own listenable, so no screen rebuild)
                // a degraded-connection warning.
                Positioned(
                  key: const ValueKey('chip'),
                  top: MediaQuery.paddingOf(context).top + 80,
                  left: 0,
                  right: 0,
                  child: ControlsFade(
                    visible: _controlsVisible,
                    // Its own layer: the stats panel redraws on every stats
                    // tick, and that should repaint a few numbers, not the
                    // screen (and the glass tray) they float over.
                    child: RepaintBoundary(
                      child: s.status == CallStatus.switching
                          ? OverlayChip(
                              label: AppLocalizations.of(
                                context,
                              ).callScreenStatusSwitching,
                            )
                          : s.reconnecting
                          ? OverlayChip(
                              label: AppLocalizations.of(
                                context,
                              ).callScreenStatusReconnecting,
                            )
                          : AnimatedBuilder(
                              animation: SettingsStore.instance,
                              builder: (context, _) {
                                final showStats =
                                    SettingsStore.instance.showNetworkStats;
                                return ValueListenableBuilder<CallQualitySnapshot?>(
                                  valueListenable: widget.service.callQuality,
                                  builder: (context, q, _) {
                                    if (q == null) {
                                      return const SizedBox.shrink();
                                    }
                                    // Opted in via Settings or the in-call
                                    // toggle: full numeric panel regardless of
                                    // quality tier, not just when degraded.
                                    if (showStats) {
                                      return NetworkStatsPanel(snapshot: q);
                                    }
                                    if (q.quality == CallQuality.good) {
                                      return const SizedBox.shrink();
                                    }
                                    return OverlayChip(
                                      label: q.quality == CallQuality.poor
                                          ? AppLocalizations.of(
                                              context,
                                            ).callScreenPoorConnectionLabel
                                          : AppLocalizations.of(
                                              context,
                                            ).callScreenWeakConnectionLabel,
                                      spinner: false,
                                      tint: const Color(0xFFFFB74D),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                ),

                // Bottom controls: the shared tray — a glass capsule of
                // fixed-size toggles that wraps onto a second row rather than
                // squeezing, and the end-call button standing alone beneath
                // it as the one unmistakably "primary" action. See CallTray
                // for the layout rules; _trayActions for the order.
                Positioned(
                  key: const ValueKey('tray'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ControlsFade(
                    visible: _controlsVisible,
                    slide: const Offset(0, 0.3),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        // Its own layer: a toggle's fill and press spring
                        // run for a beat on every tap (speaker, mute), and
                        // each of those frames should repaint the tray, not
                        // re-record the whole screen behind it.
                        child: RepaintBoundary(
                          child: CallTray(
                            actions: trayActions,
                            glass: isVideo,
                            endIcon: CallGlyphs.end,
                            endLabel: l10n.callScreenControlEnd,
                            endColor: theme.danger,
                            onEnd: () => widget.service.endCall(),
                          ),
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
}

/// Takes the call screen (or ringer) [context] sits in off the navigator —
/// that route, not whichever happens to be on top.
///
/// A bare `pop()` took the top route: with the options sheet or the share
/// picker open when the call ended, it closed the sheet and left the dead
/// call screen mounted, still listening to [CallService] and still holding
/// its renderers, under the next call's screen; and the delayed pop of an
/// ending call, or a second tap on Minimize, landing while the screen was
/// already sliding away, popped the chat underneath it. The popups the call
/// left open over itself go with it.
void dismissCallRoute(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  final nav = Navigator.of(context);
  if (!route.isCurrent) {
    // Sheets and dialogs only: a full page above this one (the next call's
    // screen) is not ours to close.
    nav.popUntil((r) => r == route || r is! PopupRoute);
  }
  if (route.isCurrent) {
    nav.pop();
  } else {
    nav.removeRoute(route);
  }
}

/// A shared screen on a 1:1 call — the peer's, with the drawing layer over
/// it, or our own (a live preview on a desktop; on a phone a placeholder,
/// because a screen showing itself showing itself is a tunnel).
class _ShareStage extends StatelessWidget {
  const _ShareStage({
    super.key,
    required this.service,
    required this.session,
    required this.remoteRenderer,
    required this.localRenderer,
    required this.ink,
    required this.theme,
    required this.topInset,
  });

  final CallService service;
  final CallSession session;
  final RTCVideoRenderer remoteRenderer;
  final RTCVideoRenderer localRenderer;
  final Color ink;
  final AppTheme theme;

  /// Where the caption pill sits — below the top overlay.
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine = service.localScreenSharing;
    final caption = mine
        ? l10n.groupCallScreenYouAreSharing
        : l10n.groupCallScreenSharingBy(session.peerName);
    final Widget surface;
    if (mine && isMobileCallPlatform) {
      surface = Center(
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
            OverlayPermissionHint(mirror: service.drawMirror),
          ],
        ),
      );
    } else {
      surface = ValueListenableBuilder<bool>(
        valueListenable: service.drawArmed,
        builder: (context, armed, _) => ShareSurface(
          renderer: mine ? localRenderer : remoteRenderer,
          model: service.drawModel,
          // The presenter draws through the app-wide overlay, which is
          // what maps to the screen being captured.
          armed: armed && !mine,
          inkColor: ink,
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0E0F12)),
        surface,
        // The presenter's own placeholder already says so; only the viewer
        // needs telling whose screen this is.
        if (!mine || !isMobileCallPlatform)
          Positioned(
            left: 16,
            top: topInset,
            right: 16,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IgnorePointer(child: CallCaptionPill(text: caption)),
            ),
          ),
      ],
    );
  }
}
