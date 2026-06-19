import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'call_models.dart';
import 'call_screen.dart';
import 'call_service.dart';

/// Full-screen UI shown when an incoming call arrives. Tap accept → spins up
/// media + answer, replaces self with [CallScreen]. Tap reject → tears down.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.service});
  final CallService service;

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

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
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
    if (s.status == CallStatus.connecting || s.status == CallStatus.active) {
      // We've accepted — swap to the active call screen.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CallScreen(service: widget.service)),
      );
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      s?.mediaKind == CallMediaKind.video
                          ? Icons.videocam
                          : Icons.call,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      kindLabel,
                      style: theme.monoTiny.copyWith(color: Colors.white70),
                    ),
                  ],
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
                      color: Colors.white.withValues(alpha: 0.08),
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
                    child: Center(
                      child: Text(
                        name.isNotEmpty
                            ? name.characters.first.toUpperCase()
                            : '?',
                        style: theme.displayHero
                            .copyWith(color: Colors.white, fontSize: 56),
                      ),
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
                        icon: Icons.call,
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
