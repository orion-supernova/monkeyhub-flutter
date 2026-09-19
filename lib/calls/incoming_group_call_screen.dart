import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/user_avatar.dart';
import 'group_call_service.dart';

/// In-app ringer for a group-call invite. Shown by the app overlay while
/// [GroupCallService.pendingInvite] is fresh; pops itself when the invite
/// clears (joined elsewhere, declined, call ended, or ring window expired).
class IncomingGroupCallScreen extends StatefulWidget {
  const IncomingGroupCallScreen({super.key, required this.service, this.api});
  final GroupCallService service;

  /// Resolves the starter's photo. Without it [UserAvatar] draws the
  /// per-user gradient and initial, which is still a who.
  final ChatApi? api;

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
    HapticFeedback.mediumImpact();
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
    HapticFeedback.lightImpact();
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
              // Whoever started the call, the way the 1:1 ringer draws its
              // caller (incoming_call_screen.dart): the same widget at the
              // same size, breathing the same way. A phone icon used to sit
              // here, which said what kind of call this was and nothing about
              // who was making it — the Join button already says the kind.
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
                        color: accent.withValues(alpha: 0.45),
                        blurRadius: 44,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  // Their photo when this person may see it — the storage id
                  // is null otherwise, lensed server-side — else the per-user
                  // gradient and initial.
                  child: UserAvatar(
                    user: ChatUser(
                      id: inv?['starterUserId']?.toString() ?? '',
                      username: '',
                      name: starter,
                      avatarStorageId:
                          inv?['starterAvatarStorageId'] as String?,
                    ),
                    api: widget.api,
                    size: 148,
                    showStatus: false,
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
