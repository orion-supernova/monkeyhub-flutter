import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
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
  // CallService._teardown fires notifyListeners twice during shutdown
  // (status → ended, then session → null 400ms later). Without this guard
  // each notify would schedule its own delayed pop and the second would
  // dismiss the chatroom beneath this screen.
  bool _popScheduled = false;
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
    if (_localRenderer.srcObject != svc.localStream) {
      _localRenderer.srcObject = svc.localStream;
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
    );
  }

  void _onChanged() {
    if (!mounted) return;
    final s = widget.service.session;
    _syncStreams();
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
  String _kindLabel(CallSession s) =>
      s.mediaKind == CallMediaKind.video ? 'Video call' : 'Voice call';

  String _statusLabel(CallSession s) {
    switch (s.status) {
      case CallStatus.outgoingRinging:
        return '${_kindLabel(s)} · ringing…';
      case CallStatus.incomingRinging:
        return '${_kindLabel(s)} · incoming';
      case CallStatus.connecting:
        return '${_kindLabel(s)} · connecting…';
      case CallStatus.active:
        return 'connected';
      case CallStatus.ended:
        return s.errorMessage ?? 'call ended';
      case CallStatus.failed:
        return s.errorMessage ?? 'call failed';
      case CallStatus.switching:
        return 'switching device…';
      case CallStatus.handedOff:
        return 'moved';
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
    final remoteVisible = isVideo &&
        widget.service.remoteStream != null &&
        !s.peerState.videoOff;
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
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Remote video / local camera preview / audio avatar
            if (remoteVisible)
              RTCVideoView(
                _remoteRenderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else if (localFullscreen) ...[
              RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
            // that the local camera IS the fullscreen view).
            if (isVideo && !s.localVideoOff && remoteVisible)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                  child: Container(
                    width: 100,
                    height: 140,
                    color: Colors.black,
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit
                          .RTCVideoViewObjectFitCover,
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
                          const Icon(Icons.mic_off,
                              size: 14, color: Colors.white70),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

            // Status chip row: device-switching renegotiation, ICE-restart
            // recovery, or (via its own listenable, so no screen rebuild)
            // a degraded-connection warning.
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: s.status == CallStatus.switching
                  ? const _OverlayChip(label: 'switching device…')
                  : s.reconnecting
                      ? const _OverlayChip(label: 'reconnecting…')
                      : ValueListenableBuilder<CallQualitySnapshot?>(
                          valueListenable: widget.service.callQuality,
                          builder: (context, q, _) {
                            if (q == null ||
                                q.quality == CallQuality.good) {
                              return const SizedBox.shrink();
                            }
                            return _OverlayChip(
                              label: q.quality == CallQuality.poor
                                  ? 'poor connection'
                                  : 'weak connection',
                              spinner: false,
                              tint: const Color(0xFFFFB74D),
                            );
                          },
                        ),
            ),

            // Bottom control bar — floating glass tray. The speaker toggle is
            // ALWAYS present (video defaults to loudspeaker, voice to earpiece,
            // both switchable).
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ControlButton(
                              icon: s.localMuted ? Icons.mic_off : Icons.mic,
                              active: s.localMuted,
                              onTap: widget.service.toggleMute,
                              label: s.localMuted ? 'unmute' : 'mute',
                            ),
                            if (isVideo)
                              _ControlButton(
                                icon: s.localVideoOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                active: s.localVideoOff,
                                onTap: widget.service.toggleVideo,
                                label: s.localVideoOff ? 'cam on' : 'cam off',
                              ),
                            if (isVideo)
                              _ControlButton(
                                icon: Icons.cameraswitch_outlined,
                                onTap: widget.service.switchCamera,
                                label: 'flip',
                                enabled: !s.localVideoOff,
                              ),
                            _ControlButton(
                              icon: s.speakerOn
                                  ? Icons.volume_up
                                  : Icons.phone_in_talk,
                              active: s.speakerOn,
                              onTap: widget.service.toggleSpeaker,
                              label: 'speaker',
                            ),
                            _ControlButton(
                              icon: Icons.call_end,
                              background: theme.danger,
                              iconColor: Colors.white,
                              large: true,
                              onTap: () => widget.service.endCall(),
                              label: 'end',
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
    );
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
    final size = large ? 64.0 : 56.0;
    if (!enabled) {
      // Unavailable control (e.g. flip while the camera is off): dimmed and
      // non-tappable.
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
                size: large ? 30 : 24,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 10,
            ),
          ),
        ],
      );
    }
    final bg = background ??
        (active
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.18));
    final fg = iconColor ?? (active ? Colors.black : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusableTap(
          onTap: onTap,
          radius: size / 2,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: fg, size: large ? 30 : 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
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
