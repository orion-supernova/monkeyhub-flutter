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
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
import 'call_options_sheet.dart';
import 'call_service.dart';
import 'call_stats_monitor.dart';

/// Full-screen UI for the active call. Listens to [CallService] and pops
/// itself once the session transitions to a terminal state.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.service, this.api});
  final CallService service;

  /// Used to load the peer's avatar image; falls back to the per-user
  /// gradient + initial when absent.
  final ChatApi? api;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  // Voice calls never touch the renderers — no GPU textures allocated and
  // nothing to dispose. A call's media kind can't change mid-call.
  bool _renderersUsed = false;
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
    if (widget.service.session?.mediaKind == CallMediaKind.video) {
      _renderersUsed = true;
      _setupRenderers();
    }
    widget.service.addListener(_onChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _setupRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
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
  }

  int _buildKey() {
    final svc = widget.service;
    final s = svc.session;
    return Object.hash(
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
      s?.errorMessage,
      svc.localStream,
      svc.remoteStream,
      svc.remoteStreamTick,
      _renderersReady,
      _pipIsLocal,
      _controlsVisible,
    );
  }

  /// Both feeds are up: the remote video is actually on screen (as opposed
  /// to the pre-connect "your own camera fills the screen" state). This is
  /// the only state where a PiP tile — and therefore a swap target — exists.
  bool _remoteVisible(CallSession? s) {
    final svc = widget.service;
    return s != null &&
        s.mediaKind == CallMediaKind.video &&
        svc.remoteStream != null &&
        !s.peerState.videoOff;
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
    _syncStreams();
    // A swap only makes sense while both feeds are on screen. If the peer's
    // video drops or the user turns their own camera off, un-swap so no one
    // gets stuck staring at a frozen/disabled feed full-screen.
    if (_pipIsLocal && (!_remoteVisible(s) || (s?.localVideoOff ?? false))) {
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
    if (_renderersUsed) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
      return _ElapsedLabel(start: start, style: style);
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
    final isVideo = s.mediaKind == CallMediaKind.video;
    final remoteVisible = _remoteVisible(s);
    // WhatsApp-style pre-answer/pre-connect view for video calls: your own
    // camera fills the screen until the peer's video arrives (then the
    // local view shrinks into the PiP tile).
    final localFullscreen = isVideo &&
        !remoteVisible &&
        !s.localVideoOff &&
        widget.service.localStream != null &&
        _renderersReady;

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
              if (remoteVisible)
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
                _AudioBackdrop(
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
              if (isVideo && !s.localVideoOff && remoteVisible)
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
                            _pipIsLocal ? _remoteRenderer : _localRenderer,
                            mirror: !_pipIsLocal,
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
                  child: _ControlsFade(
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
                child: _ControlsFade(
                  visible: _controlsVisible,
                  child: s.status == CallStatus.switching
                      ? _OverlayChip(
                          label: AppLocalizations.of(
                            context,
                          ).callScreenStatusSwitching,
                        )
                      : s.reconnecting
                      ? _OverlayChip(
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
                                  return _NetworkStatsPanel(snapshot: q);
                                }
                                if (q.quality == CallQuality.good) {
                                  return const SizedBox.shrink();
                                }
                                return _OverlayChip(
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
                left: 16,
                right: 16,
                bottom: 0,
                child: _ControlsFade(
                  visible: _controlsVisible,
                  slide: const Offset(0, 0.3),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 14,
                              ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
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
                                      child: _ControlButton(
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
                                    if (isVideo)
                                      Expanded(
                                        child: _ControlButton(
                                          icon: s.localVideoOff
                                              ? Icons.videocam_off
                                              : Icons.videocam,
                                          active: s.localVideoOff,
                                          onTap: widget.service.toggleVideo,
                                          label: s.localVideoOff
                                              ? AppLocalizations.of(
                                                  context,
                                                ).callScreenControlCamOn
                                              : AppLocalizations.of(
                                                  context,
                                                ).callScreenControlCamOff,
                                        ),
                                      ),
                                    if (isVideo)
                                      Expanded(
                                        child: _ControlButton(
                                          icon: Icons.cameraswitch_outlined,
                                          onTap: widget.service.switchCamera,
                                          label: AppLocalizations.of(
                                            context,
                                          ).callScreenControlFlip,
                                          enabled: !s.localVideoOff,
                                        ),
                                      ),
                                    Expanded(
                                      child: _ControlButton(
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
                                      child: _ControlButton(
                                        icon: Icons.tune,
                                        onTap: () => showAdaptiveSheet(
                                          context,
                                          builder: (_) => CallOptionsSheet(
                                            service: widget.service,
                                            showVideoQuality: isVideo,
                                          ),
                                        ),
                                        label: AppLocalizations.of(
                                          context,
                                        ).callScreenControlOptions,
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
                          _ControlButton(
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
            ],
          ),
        ),
      ),
    );
  }
}


/// Fades (and optionally slides) an overlay region for the call screen's
/// tap-to-hide-controls gesture. [IgnorePointer] while hidden so faded-out
/// chrome can't be tapped through mid-animation or while fully hidden.
class _ControlsFade extends StatelessWidget {
  const _ControlsFade({required this.visible, required this.child, this.slide});

  final bool visible;
  final Widget child;

  /// Fractional offset (of the child's own size) to slide toward when
  /// hidden — e.g. (0, -0.3) drifts upward as it fades out.
  final Offset? slide;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    Widget result = AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: _duration,
      curve: _curve,
      child: child,
    );
    if (slide != null) {
      result = AnimatedSlide(
        offset: visible ? Offset.zero : slide!,
        duration: _duration,
        curve: _curve,
        child: result,
      );
    }
    return IgnorePointer(ignoring: !visible, child: result);
  }
}

class _AudioBackdrop extends StatefulWidget {
  const _AudioBackdrop({
    required this.name,
    required this.status,
    required this.theme,
    required this.user,
    this.api,
    this.peerMuted = false,
  });
  final String name;
  final Widget status;
  final bool peerMuted;
  final dynamic theme;
  final ChatUser user;
  final ChatApi? api;

  @override
  State<_AudioBackdrop> createState() => _AudioBackdropState();
}

class _AudioBackdropState extends State<_AudioBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = theme.accent as Color;
    return Container(
      decoration: BoxDecoration(
        // Soft ambient wash centered just behind the avatar; the focal glow
        // is the avatar's own boxShadow so the two always line up.
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.0,
          colors: [
            accent.withValues(alpha: 0.32),
            Colors.black,
          ],
          stops: const [0.0, 0.85],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar + concentric pulse rings.
              SizedBox(
                width: 260,
                height: 260,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final phase in const [0.0, 0.5])
                          _pulseRing(accent, (_pulse.value + phase) % 1.0),
                        child!,
                      ],
                    );
                  },
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    // Real avatar photo when available; per-user gradient +
                    // initial otherwise (UserAvatar handles both).
                    child: UserAvatar(
                      user: widget.user,
                      api: widget.api,
                      size: 130,
                      showStatus: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                widget.name,
                style: theme.displayMedium.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.peerMuted) ...[
                    const Icon(Icons.mic_off, size: 14, color: Colors.white70),
                    const SizedBox(width: 8),
                  ],
                  widget.status,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pulseRing(Color accent, double t) {
    final size = 132.0 + t * 120.0;
    return Opacity(
      opacity: (1.0 - t) * 0.35,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.label,
    this.active = false,
    this.background,
    this.iconColor,
    this.large = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool active;
  final Color? background;
  final Color? iconColor;
  final bool large;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Sized from whatever width the Row's Expanded slot actually gives us —
    // never exceeding today's diameter, never shrinking below a usable
    // floor — so a narrow phone or a large accessibility text scale can
    // never overflow the tray (see call_screen control-row layout).
    return LayoutBuilder(
      builder: (context, constraints) {
        // The end-call button (large: true) now sits alone on its own row
        // (see the control-bar layout in call_screen's build()), so it gets
        // a bigger ceiling/floor than the toolbar row's shared-width toggles.
        final maxDiameter = large ? 72.0 : 56.0;
        final minDiameter = large ? 56.0 : 40.0;
        final size = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(minDiameter, maxDiameter).toDouble()
            : maxDiameter;
        final iconSize = size * (large ? 32 / 72 : 24 / 56);
        final labelScaler = MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 1.3);
        if (!enabled) {
          // Unavailable control (e.g. flip while the camera is off):
          // dimmed and non-tappable.
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.08),
                shape: const CircleBorder(),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.30),
                    size: iconSize,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textScaler: labelScaler,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 10,
                ),
              ),
            ],
          );
        }
        final bg =
            background ??
            (active
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.18));
        final fg = iconColor ?? (active ? Colors.black : Colors.white);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FocusableTap(
              onTap: onTap,
              semanticLabel: label,
              shape: FocusRingShape.circle,
              // FocusableTap adds keyboard focus/activation only — the
              // child GestureDetector is what makes this tappable.
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    // Only the standalone hero button (end call) needs to
                    // read as "floating" above the video — the toolbar row's
                    // buttons already sit inside their own glass tray.
                    boxShadow: large
                        ? [
                            BoxShadow(
                              color: bg.withValues(alpha: 0.45),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(icon, color: fg, size: iconSize),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: labelScaler,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        );
      },
    );
  }
}

/// Small centered pill shown over the call view during a transient state —
/// device-switch renegotiation, ICE-restart recovery, or a degraded
/// connection. Subtle by design; the call audio/video continues behind it.
class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.label, this.spinner = true, this.tint});
  final String label;
  final bool spinner;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final fg = tint ?? Colors.white;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: fg.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              ),
              const SizedBox(width: 10),
            ] else ...[
              Icon(Icons.network_check, size: 14, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.monoTiny.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed live numeric readout — opt-in replacement for [_OverlayChip]'s
/// plain "poor/weak connection" label, driven by the same
/// [CallQualitySnapshot] the chip already reads. Shown whenever
/// [SettingsStore.showNetworkStats] is on, at every quality tier, not just
/// when degraded.
class _NetworkStatsPanel extends StatelessWidget {
  const _NetworkStatsPanel({required this.snapshot});
  final CallQualitySnapshot snapshot;

  String _fmtKbps(double? v) => v == null ? '—' : '${v.round()} kbps';
  String _fmtMs(double? v) => v == null ? '—' : '${v.round()} ms';

  IconData _qualityIcon(CallQuality q) => switch (q) {
    CallQuality.good => Icons.signal_cellular_alt,
    CallQuality.fair => Icons.signal_cellular_alt_2_bar,
    CallQuality.poor => Icons.signal_cellular_alt_1_bar,
  };

  Widget _metric(TextStyle style, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Text(text, style: style.copyWith(color: color.withValues(alpha: 0.95))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final q = snapshot;
    final res = (q.frameWidth != null && q.frameHeight != null)
        ? '${q.frameWidth}×${q.frameHeight}'
              '${q.fps != null ? '@${q.fps!.round()}' : ''}'
        : null;
    final tint = switch (q.quality) {
      CallQuality.poor => const Color(0xFFFF6B6B),
      CallQuality.fair => const Color(0xFFFFB74D),
      CallQuality.good => Colors.white,
    };
    final style = theme.monoTiny;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(color: tint.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                // Resolution leads — it's what a user actually notices when
                // they wonder "why does the video look bad," so it shouldn't
                // read as an afterthought next to the more technical
                // quality/path metric.
                if (res != null)
                  _metric(style, Icons.aspect_ratio, res, Colors.white),
                _metric(
                  style,
                  _qualityIcon(q.quality),
                  q.candidateType ?? '—',
                  tint,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _metric(
                  style,
                  Icons.arrow_downward_rounded,
                  _fmtKbps(q.inKbps),
                  Colors.white,
                ),
                _metric(
                  style,
                  Icons.arrow_upward_rounded,
                  _fmtKbps(q.outKbps),
                  Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _metric(
                  style,
                  Icons.timer_outlined,
                  '${l10n.callScreenStatsRttLabel} ${_fmtMs(q.rttMs)}',
                  Colors.white,
                ),
                if (q.jitterMs != null)
                  _metric(
                    style,
                    Icons.graphic_eq,
                    '${l10n.callScreenStatsJitterLabel} ${_fmtMs(q.jitterMs)}',
                    Colors.white,
                  ),
                if (q.lossPercent != null)
                  _metric(
                    style,
                    Icons.error_outline,
                    '${l10n.callScreenStatsLossLabel} '
                    '${q.lossPercent!.toStringAsFixed(1)}%',
                    Colors.white,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-ticking call-duration label. Owning the 1 Hz timer here confines the
/// per-second rebuild to this one Text widget.
class _ElapsedLabel extends StatefulWidget {
  const _ElapsedLabel({required this.start, required this.style});
  final DateTime start;
  final TextStyle style;

  @override
  State<_ElapsedLabel> createState() => _ElapsedLabelState();
}

class _ElapsedLabelState extends State<_ElapsedLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.start);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final label = d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
    return Text(label, style: widget.style);
  }
}
