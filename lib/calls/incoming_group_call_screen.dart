import 'dart:async';

import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import 'group_call_service.dart';

/// In-app ringer for a group-call invite. Shown by the app overlay while
/// [GroupCallService.pendingInvite] is fresh; pops itself when the invite
/// clears (joined elsewhere, declined, call ended, or ring window expired).
class IncomingGroupCallScreen extends StatefulWidget {
  const IncomingGroupCallScreen({super.key, required this.service});
  final GroupCallService service;

  @override
  State<IncomingGroupCallScreen> createState() =>
      _IncomingGroupCallScreenState();
}

class _IncomingGroupCallScreenState extends State<IncomingGroupCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  bool _popScheduled = false;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    final svc = widget.service;
    if (svc.inCall) {
      // Joined (from here or another surface) — the overlay pushes the call
      // screen; this ringer just leaves.
      _popOnce();
      return;
    }
    if (svc.pendingInvite == null) {
      _popOnce();
      return;
    }
    setState(() {});
  }

  void _popOnce() {
    if (_popScheduled) return;
    _popScheduled = true;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_acting) return;
    setState(() => _acting = true);
    final inv = widget.service.pendingInvite;
    if (inv == null) return;
    try {
      await widget.service.joinCall(inv['groupCallId'].toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      final l10n = AppLocalizations.of(context);
      final msg = e.toString().contains('CALL_FULL')
          ? l10n.incomingGroupCallScreenCallFullError
          : l10n.incomingGroupCallScreenJoinFailedError;
      showAppToast(context, msg);
    }
  }

  Future<void> _dismiss() async {
    if (_acting) return;
    setState(() => _acting = true);
    await widget.service.declineInvite();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final inv = widget.service.pendingInvite;
    final roomName =
        inv?['roomName']?.toString() ??
        l10n.incomingGroupCallScreenDefaultRoomName;
    final starter =
        inv?['starterName']?.toString() ??
        l10n.incomingGroupCallScreenDefaultStarterName;
    final isVideo = inv?['type'] == 'video';
    final joined = (inv?['joinedCount'] as num?)?.toInt() ?? 1;
    final accent = theme.accent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.1,
            colors: [accent.withValues(alpha: 0.30), Colors.black],
            stops: const [0.0, 0.85],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              FadeTransition(
                opacity: Tween(begin: 0.55, end: 1.0).animate(_pulse),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 44,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isVideo ? Icons.videocam : Icons.call,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  roomName,
                  style: theme.displayMedium.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${isVideo ? l10n.incomingGroupCallScreenStartedVideoCall(starter) : l10n.incomingGroupCallScreenStartedVoiceCall(starter)}'
                '${joined > 1 ? ' · ${l10n.incomingGroupCallScreenAlreadyJoinedCount(joined)}' : ''}',
                style: theme.monoTiny.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 42),
                // Capped and centered so the two buttons stay a matched pair
                // on a wide desktop window instead of spaceEvenly pushing
                // them out to the far edges — inert on a phone, where this
                // ceiling is never reached.
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _bigAction(
                          icon: Icons.close,
                          label: l10n.incomingGroupCallScreenDismissButton,
                          background: Colors.white.withValues(alpha: 0.16),
                          onTap: _dismiss,
                        ),
                        _bigAction(
                          icon: isVideo ? Icons.videocam : Icons.call,
                          label: l10n.incomingGroupCallScreenJoinButton,
                          background: const Color(0xFF17C964),
                          iconColor: Colors.black,
                          onTap: _join,
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

  Widget _bigAction({
    required IconData icon,
    required String label,
    required Color background,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusableTap(
          onTap: _acting ? null : onTap,
          enabled: !_acting,
          semanticLabel: label,
          shape: FocusRingShape.circle,
          child: GestureDetector(
            onTap: _acting ? null : onTap,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
