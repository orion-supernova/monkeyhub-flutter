import 'dart:async';
import 'dart:ui' show ImageFilter;

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
import 'call_media.dart';
import 'call_models.dart';
import 'call_options_sheet.dart';
import 'call_service.dart';
import 'call_stats_monitor.dart';
import 'draw/draw_canvas.dart';
import 'draw/draw_model.dart';
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

class _CallScreenState extends State<CallScreen> {
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

  @override
  void initState() {
    super.initState();
    if (widget.service.session?.mediaKind == CallMediaKind.video ||
        _anyVideo) {
      _ensureRenderers();
    }
    widget.service.addListener(_onChanged);
    widget.service.drawArmed.addListener(_onChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    unawaited(ScreenShare.supported().then((ok) {
      if (mounted && ok != _shareSupported) setState(() => _shareSupported = ok);
    }));
  }

  /// Whether there is anything to render — ours or theirs, camera or screen.
  bool get _anyVideo {
    final svc = widget.service;
    return svc.hasAnyVideo ||
        svc.remoteScreenStream != null ||
        svc.localScreenSharing;
  }

  void _ensureRenderers() {
    if (_renderersUsed || _settingUp) return;
    _settingUp = true;
    _renderersUsed = true;
    unawaited(_setupRenderers());
  }

  Future<void> _setupRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      await _remoteScreenRenderer.initialize();
      await _localScreenRenderer.initialize();
    } catch (e) {
      debugPrint('CallScreen: renderer init failed: $e');
    }
    _settingUp = false;
    if (!mounted) return;
    _renderersReady = true;
    _syncStreams();
    setState(() {});
  }

  void _syncStreams() {
    if (!_renderersReady) return;
    final svc = widget.service;
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
  }

  int _buildKey() {
    final svc = widget.service;
    final s = svc.session;
    return Object.hashAll([
      s?.callId,
      s?.status,
      s?.peerName,
      s?.peerAvatarStorageId,
      s?.localMuted,
      s?.localVideoOff,
      s?.speakerOn,
      s?.reconnecting,
      s?.peerState.audioMuted,
      s?.peerState.videoOff,
      s?.peerState.screenSharing,
      s?.localScreenSharing,
      s?.errorMessage,
      svc.localStream,
      svc.localStreamTick,
      svc.localCamActive,
      svc.remoteStream,
      svc.remoteStreamTick,
      svc.remoteScreenStream,
      svc.remoteScreenStreamTick,
      svc.localScreenStreamTick,
      svc.drawArmed.value,
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

  void _onChanged() {
    if (!mounted) return;
    final s = widget.service.session;
    if (_anyVideo) _ensureRenderers();
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
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
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
    if (_renderersUsed) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _remoteScreenRenderer.srcObject = null;
      _localScreenRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
      _remoteScreenRenderer.dispose();
      _localScreenRenderer.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _hide() {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

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
        return loc.callScreenStatusRinging(_kindLabel(s));
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final s = widget.service.session;
    if (s == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(),
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
    final myInk = drawColorFor(svc.userId ?? 'me', theme);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Remote video / local camera preview / audio avatar. No tap
              // handler here on purpose — a tap on this area falls through to
              // the outer GestureDetector's show/hide toggle. Only the small
              // PiP tile below is the swap target.
              if (stage)
                _ShareStage(
                  service: svc,
                  session: s,
                  remoteRenderer: _remoteScreenRenderer,
                  localRenderer: _localScreenRenderer,
                  ink: myInk,
                  theme: theme,
                )
              else if (remoteVisible)
                RTCVideoView(
                  _pipIsLocal ? _localRenderer : _remoteRenderer,
                  mirror: _pipIsLocal,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else if (localFullscreen) ...[
                RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
                // Soft darkening so the overlaid name/status/controls read
                // over any camera image.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ] else
                AudioBackdrop(
                  name: s.peerName,
                  status: _statusWidget(
                    s,
                    theme.monoTiny.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  peerMuted: s.peerState.audioMuted,
                  theme: theme,
                  user: _peerAsUser(s),
                  api: widget.api,
                ),

              // Top scrim so the name/status stay legible over video.
              if (remoteVisible || localFullscreen)
                Positioned(
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
                  top: MediaQuery.of(context).padding.top + 16,
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
              if (svc.localCamActive && (remoteVisible || stage))
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
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

              // Top overlay: name + status (video only — voice calls show the
              // name + timer centered under the avatar instead).
              if (isVideo)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 18,
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
                              theme.monoTiny.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                            if (s.peerState.audioMuted) ...[
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.mic_off,
                                size: 14,
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
                top: MediaQuery.of(context).padding.top + 80,
                left: 0,
                right: 0,
                child: ControlsFade(
                  visible: _controlsVisible,
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

              // Bottom controls, two tiers (WhatsApp/FaceTime-style) instead
              // of one crowded row: a glass toolbar for the everyday
              // toggles, and the end-call button standing alone beneath it
              // as the one unmistakably "primary" action. The speaker
              // toggle is ALWAYS present (video defaults to loudspeaker,
              // voice to earpiece, both switchable).
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ControlsFade(
                  visible: _controlsVisible,
                  slide: const Offset(0, 0.3),
                  child: SafeArea(
                    top: false,
                    // Capped and centered so the tray reads as one grouped
                    // control on a wide desktop window instead of stretching
                    // edge to edge — on a phone this ceiling is never reached,
                    // so nothing changes there.
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 20,
                                    sigmaY: 20,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: CallControlButton(
                                            icon: s.localMuted
                                                ? Icons.mic_off
                                                : Icons.mic,
                                            active: s.localMuted,
                                            onTap: widget.service.toggleMute,
                                            label: s.localMuted
                                                ? AppLocalizations.of(
                                                    context,
                                                  ).callScreenControlUnmute
                                                : AppLocalizations.of(
                                                    context,
                                                  ).callScreenControlMute,
                                          ),
                                        ),
                                        Expanded(
                                          child: CallControlButton(
                                            icon: svc.localCamActive
                                                ? Icons.videocam
                                                : Icons.videocam_off,
                                            active: !svc.localCamActive,
                                            onTap: () => unawaited(
                                              widget.service.toggleVideo(),
                                            ),
                                            label: svc.localCamActive
                                                ? AppLocalizations.of(
                                                    context,
                                                  ).callScreenControlCamOff
                                                : AppLocalizations.of(
                                                    context,
                                                  ).callScreenControlCamOn,
                                          ),
                                        ),
                                        if (svc.localCamActive &&
                                            isMobileCallPlatform)
                                          Expanded(
                                            child: CallControlButton(
                                              icon: Icons.cameraswitch_outlined,
                                              onTap:
                                                  widget.service.switchCamera,
                                              label: AppLocalizations.of(
                                                context,
                                              ).callScreenControlFlip,
                                            ),
                                          ),
                                        if (_shareSupported)
                                          Expanded(
                                            child: CallControlButton(
                                              icon: ownScreen
                                                  ? Icons
                                                      .stop_screen_share_outlined
                                                  : Icons.screen_share_outlined,
                                              active: ownScreen,
                                              enabled: ownScreen ||
                                                  !s.peerState.screenSharing,
                                              onTap: () =>
                                                  unawaited(_onShareTap()),
                                              label: ownScreen
                                                  ? AppLocalizations.of(
                                                      context,
                                                    ).callScreenControlStopShare
                                                  : AppLocalizations.of(
                                                      context,
                                                    ).callScreenControlShare,
                                            ),
                                          ),
                                        if (stage)
                                          Expanded(
                                            child: CallControlButton(
                                              icon: Icons.draw_outlined,
                                              active: svc.drawArmed.value,
                                              onTap: () => svc.drawArmed.value =
                                                  !svc.drawArmed.value,
                                              label: AppLocalizations.of(
                                                context,
                                              ).callScreenControlDraw,
                                            ),
                                          ),
                                        Expanded(
                                          child: CallControlButton(
                                            icon: s.speakerOn
                                                ? Icons.volume_up
                                                : Icons.phone_in_talk,
                                            active: s.speakerOn,
                                            onTap: widget.service.toggleSpeaker,
                                            label: AppLocalizations.of(
                                              context,
                                            ).callScreenControlSpeaker,
                                          ),
                                        ),
                                        Expanded(
                                          child: CallControlButton(
                                            icon: Icons.tune,
                                            onTap: () => showAdaptiveSheet(
                                              context,
                                              builder: (_) => CallOptionsSheet(
                                                service: widget.service,
                                                showVideoQuality:
                                                    svc.localCamActive,
                                              ),
                                            ),
                                            label: AppLocalizations.of(
                                              context,
                                            ).callScreenControlOptions,
                                          ),
                                        ),
                                        Expanded(
                                          child: CallControlButton(
                                            icon: Icons
                                                .keyboard_arrow_down_rounded,
                                            onTap: _hide,
                                            label: AppLocalizations.of(
                                              context,
                                            ).callScreenControlMinimize,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              // The hero action: alone on its own row so it
                              // never competes for space with the toggles above
                              // it, at a size that reads as unmistakably primary.
                              CallControlButton(
                                icon: Icons.call_end,
                                background: theme.danger,
                                iconColor: Colors.white,
                                large: true,
                                onTap: () => widget.service.endCall(),
                                label: AppLocalizations.of(
                                  context,
                                ).callScreenControlEnd,
                              ),
                            ],
                          ),
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
    );
  }
}

/// A shared screen on a 1:1 call — the peer's, with the drawing layer over
/// it, or our own (a live preview on a desktop; on a phone a placeholder,
/// because a screen showing itself showing itself is a tunnel).
class _ShareStage extends StatelessWidget {
  const _ShareStage({
    required this.service,
    required this.session,
    required this.remoteRenderer,
    required this.localRenderer,
    required this.ink,
    required this.theme,
  });

  final CallService service;
  final CallSession session;
  final RTCVideoRenderer remoteRenderer;
  final RTCVideoRenderer localRenderer;
  final Color ink;
  final AppTheme theme;

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
        Positioned(
          left: 16,
          bottom: 200,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Text(
                caption,
                style: theme.monoTiny.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
