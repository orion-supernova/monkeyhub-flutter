import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/user_avatar.dart';
import 'group_call_service.dart';
import 'widgets/call_chrome.dart'
    show
        CallGlyphs,
        RingActionButton,
        RingerLayout,
        callStatusStyle,
        kCallAcceptGreen;

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

    final started = isVideo
        ? l10n.incomingGroupCallScreenStartedVideoCall(starter)
        : l10n.incomingGroupCallScreenStartedVoiceCall(starter);

    // The 1:1 ringer's layout exactly (RingerLayout): the room as the
    // title, who started it under it, the starter's face — a phone icon
    // used to sit there, which said nothing about who was calling — and
    // the same pair of answers.
    return Scaffold(
      backgroundColor: Colors.black,
      body: RingerLayout(
        title: roomName,
        // Who started it, and — on its own line, so a translation never
        // breaks "3 / kişi" across the two — how many are already in.
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              started,
              style: callStatusStyle(theme),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (joined > 1)
              Text(
                l10n.incomingGroupCallScreenAlreadyJoinedCount(joined),
                style: callStatusStyle(theme).copyWith(fontSize: 15),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        pulse: _pulse,
        // Their photo when this person may see it — the storage id is null
        // otherwise, lensed server-side — else the per-user gradient and
        // initial.
        avatar: UserAvatar(
          user: ChatUser(
            id: inv?['starterUserId']?.toString() ?? '',
            username: '',
            name: starter,
            avatarStorageId: inv?['starterAvatarStorageId'] as String?,
          ),
          api: widget.api,
          size: 150,
          showStatus: false,
        ),
        actions: [
          RingActionButton(
            icon: CallGlyphs.dismiss,
            label: l10n.incomingGroupCallScreenDismissButton,
            background: Colors.white.withValues(alpha: 0.18),
            enabled: !_acting,
            onTap: _dismiss,
          ),
          RingActionButton(
            icon: isVideo ? CallGlyphs.camera : CallGlyphs.voice,
            label: l10n.incomingGroupCallScreenJoinButton,
            background: kCallAcceptGreen,
            enabled: !_acting,
            onTap: _join,
          ),
        ],
      ),
    );
  }
}
