import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../theme/theme_scope.dart';
import 'call_models.dart';
import 'call_service.dart';

/// Full-screen UI for the active call. Listens to [CallService] and pops
/// itself once the session transitions to a terminal state.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.service});
  final CallService service;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    _setupRenderers();
    widget.service.addListener(_onChanged);
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _setupRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _localRenderer.srcObject = widget.service.localStream;
    _remoteRenderer.srcObject = widget.service.remoteStream;
    if (mounted) setState(() {});
  }

  void _onChanged() {
    if (!mounted) return;
    final s = widget.service.session;
    if (_localRenderer.srcObject != widget.service.localStream) {
      _localRenderer.srcObject = widget.service.localStream;
    }
    if (_remoteRenderer.srcObject != widget.service.remoteStream) {
      _remoteRenderer.srcObject = widget.service.remoteStream;
    }
    if (s == null ||
        s.status == CallStatus.ended ||
        s.status == CallStatus.failed) {
      // Show the terminal state briefly, then pop.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    _elapsedTicker?.cancel();
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _statusLabel(CallSession s) {
    switch (s.status) {
      case CallStatus.outgoingRinging:
        return 'ringing…';
      case CallStatus.incomingRinging:
        return 'incoming';
      case CallStatus.connecting:
        return 'connecting…';
      case CallStatus.active:
        final start = s.connectedAt ?? s.startedAt;
        if (start == null) return 'connected';
        final d = DateTime.now().difference(start);
        final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
        final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
        return d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
      case CallStatus.ended:
        return s.errorMessage ?? 'call ended';
      case CallStatus.failed:
        return s.errorMessage ?? 'call failed';
      case CallStatus.idle:
        return '';
    }
  }

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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Remote video / audio avatar
            if (remoteVisible)
              RTCVideoView(
                _remoteRenderer,
                objectFit:
                    RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              _AudioBackdrop(name: s.peerName, theme: theme),

            // Local PiP (video only)
            if (isVideo && !s.localVideoOff)
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

            // Top overlay: name + status
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 24,
              right: isVideo ? 132 : 24,
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
                      Text(
                        _statusLabel(s),
                        style: theme.monoTiny.copyWith(
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

            // Bottom control bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                        ),
                      if (!isVideo)
                        _ControlButton(
                          icon: s.speakerOn
                              ? Icons.volume_up
                              : Icons.volume_down,
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
          ],
        ),
      ),
    );
  }
}

class _AudioBackdrop extends StatelessWidget {
  const _AudioBackdrop({required this.name, required this.theme});
  final String name;
  final dynamic theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (theme.accent as Color).withValues(alpha: 0.6),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                  style: theme.displayHero.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool active;
  final Color? background;
  final Color? iconColor;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 64.0 : 56.0;
    final bg = background ??
        (active
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.18));
    final fg = iconColor ?? (active ? Colors.black : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: fg, size: large ? 30 : 24),
            ),
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
