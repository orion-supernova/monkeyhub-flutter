import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
import 'call_screen.dart';
import 'call_service.dart';

/// Full-screen UI shown when an incoming call arrives. Tap accept → spins up
/// media + answer, replaces self with [CallScreen]. Tap reject → tears down.
///
/// Phones ring via the NATIVE UI (CallKit / ConnectionService) instead —
/// this screen only shows on platforms without one (iOS simulator,
/// desktop). See `_CallOverlay._nativeRinger`.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.service, this.api});
  final CallService service;
  final ChatApi? api;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

enum _RingAction { none, accept, reject }

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  // Once the user has tapped accept/reject we lock both buttons until the
  // screen disposes. The session transitions through `connecting` (accept)
  // or terminal (reject) within a few hundred ms — locking is enough.
  _RingAction _pending = _RingAction.none;
  // CallService._teardown notifies twice (status → ended, then session →
  // null 400ms later). Without this guard both notifies would call pop()
  // and the second pop would dismiss the chatroom underneath.
  bool _popScheduled = false;
  // pushReplacement to CallScreen must run exactly once; connecting/active
  // notifies repeatedly while this route is still on top.
  bool _movedToCall = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    // The ringtone is driven by _CallOverlay from the call-state change (not
    // here), because on a backgrounded web tab this screen never mounts — see
    // _CallOverlayState._syncRingtone.
    widget.service.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    final s = widget.service.session;
    if (s == null ||
        s.status == CallStatus.ended ||
        s.status == CallStatus.failed) {
      if (_popScheduled) return;
      _popScheduled = true;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    if (!_movedToCall &&
        (s.status == CallStatus.connecting || s.status == CallStatus.active)) {
      // We've accepted — swap to the active call screen. Guarded so the
      // repeated notifies in this window can't stack CallScreen routes
      // (each of which would allocate its own pair of video renderers).
      _movedToCall = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              CallScreen(service: widget.service, api: widget.api),
        ),
      );
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_pending != _RingAction.none) return;
    setState(() => _pending = _RingAction.accept);
    await widget.service.acceptIncoming();
  }

  Future<void> _reject() async {
    if (_pending != _RingAction.none) return;
    setState(() => _pending = _RingAction.reject);
    await widget.service.reject();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final s = widget.service.session;
    final name = s?.peerName ?? 'incoming call';
    final kindLabel = s?.mediaKind == CallMediaKind.video
        ? 'incoming video call'
        : 'incoming voice call';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.accent.withValues(alpha: 0.55),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),
                // Call-type pill — the voice/video distinction must be
                // unmissable, not a faint caption.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        s?.mediaKind == CallMediaKind.video
                            ? Icons.videocam
                            : Icons.call,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        kindLabel.toUpperCase(),
                        style: theme.label.copyWith(
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final scale = 1.0 + _pulse.value * 0.06;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.45),
                          blurRadius: 44,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    // Real avatar photo when known; per-user gradient +
                    // initial otherwise.
                    child: UserAvatar(
                      user: ChatUser(
                        id: s?.peerUserId ?? '',
                        username: '',
                        name: name,
                        avatarStorageId: s?.peerAvatarStorageId,
                      ),
                      api: widget.api,
                      size: 148,
                      showStatus: false,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  style: theme.displayMedium.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RingButton(
                        icon: Icons.call_end,
                        background: theme.danger,
                        label: _pending == _RingAction.reject
                            ? 'declining…'
                            : 'decline',
                        enabled: _pending == _RingAction.none,
                        onTap: _reject,
                      ),
                      _RingButton(
                        // Video calls accept with the camera glyph so the
                        // user knows what they're walking into.
                        icon: s?.mediaKind == CallMediaKind.video
                            ? Icons.videocam
                            : Icons.call,
                        background: theme.success,
                        label: _pending == _RingAction.accept
                            ? 'connecting…'
                            : 'accept',
                        enabled: _pending == _RingAction.none,
                        onTap: _accept,
                      ),
                    ],
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

class _RingButton extends StatelessWidget {
  const _RingButton({
    required this.icon,
    required this.background,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final Color background;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? background : background.withValues(alpha: 0.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: 76,
              height: 76,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.6),
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
