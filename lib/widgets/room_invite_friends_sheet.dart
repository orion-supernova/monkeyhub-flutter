import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../invites/room_admin_errors.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import 'search_field.dart';
import 'user_avatar.dart';

/// "Add a friend to this group" — the picker, and the invites it sends.
///
/// An invite here is a REQUEST, not an addition. The person named gets to say
/// yes or no exactly the way they would to a friend request, and until they do
/// they are not in the room and cannot see a word of it. Adding people to
/// group chats without asking is the single most-complained-about behaviour in
/// every messenger that does it, and there is no version of this screen that
/// silently drops someone into a conversation.
///
/// Sends one at a time and marks each row as it lands, rather than collecting
/// a selection and firing a batch at the end. Invites can fail individually —
/// somebody blocked somebody, a child needs a guardian, the room's invite
/// switch flipped a second ago — and a batch would have to report "3 of 5
/// worked" with no way to say which two.
Future<bool> showRoomInviteFriendsSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  required String roomId,
}) async {
  final sent = await showAdaptiveSheet<bool>(
    context,
    // Bounded by the top safe area. `ModalBottomSheetRoute` strips the top
    // inset from everything inside it, so a `SafeArea` in the content is a
    // silent no-op — this flag is the only hook that applies it, from the
    // route, where the padding still exists. Without it a tall sheet runs
    // under the notch.
    useSafeArea: true,
    builder: (_) => _InviteFriendsSheet(repo: repo, api: api, roomId: roomId),
  );
  return sent ?? false;
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({
    required this.repo,
    required this.api,
    required this.roomId,
  });

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  final _search = TextEditingController();
  List<ChatUser> _friends = const [];
  bool _loading = true;

  /// Rows mid-flight, and rows that landed. Two sets rather than one enum map
  /// because a row can only ever be in one of them and the checks read better.
  final _sending = <String>{};
  final _sent = <String>{};
  bool _anySent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.repo.invitableFriends(widget.roomId);
      if (!mounted) return;
      setState(() {
        _friends = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<ChatUser> get _visible {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends
        .where((u) =>
            u.displayName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _invite(ChatUser user) async {
    if (_sending.contains(user.id) || _sent.contains(user.id)) return;
    setState(() => _sending.add(user.id));
    try {
      await widget.repo.inviteToRoom(roomId: widget.roomId, inviteeId: user.id);
      if (!mounted) return;
      setState(() {
        _sending.remove(user.id);
        _sent.add(user.id);
        _anySent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending.remove(user.id));
      final l10n = AppLocalizations.of(context);
      showAppToast(
        context,
        humanizeAuthError(
          e,
          l10n,
          fallback: l10n.roomAdminGenericError,
          overrides: roomAdminErrorMessages(l10n),
        ),
        tone: ToastTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final visible = _visible;

    return SheetFrame(
      title: l10n.roomInviteFriendsTitle,
      leading: SheetCloseButton(
        onTap: () => Navigator.of(context).pop(_anySent),
      ),
      trailing: SheetConfirmButton(
        label: l10n.roomInviteFriendsDone,
        onTap: () => Navigator.of(context).pop(_anySent),
      ),
      // One scroller for the whole sheet: the frame itself does not scroll,
      // and a long friend list must never overflow it.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
              child: Text(
                l10n.roomInviteFriendsBlurb,
                style: theme.bodySoft.copyWith(color: theme.inkMuted),
                textAlign: TextAlign.center,
              ),
            ),
            if (_friends.length > 6) ...[
              SearchField(
                controller: _search,
                hintText: l10n.roomInviteFriendsSearchHint,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  // Two different empties. "No friends left to invite" is a
                  // finished state and reads as success; "nothing matches
                  // that" is a search result. Showing the first while someone
                  // is typing would be a lie.
                  _search.text.trim().isEmpty
                      ? l10n.roomInviteFriendsEmpty
                      : l10n.roomInviteFriendsNoMatch,
                  style: theme.bodySoft,
                  textAlign: TextAlign.center,
                ),
              )
            else
              SheetRise(
                child: SheetGroup(
                  children: [
                    for (final u in visible)
                      _FriendRow(
                        key: ValueKey(u.id),
                        user: u,
                        api: widget.api,
                        sending: _sending.contains(u.id),
                        sent: _sent.contains(u.id),
                        onInvite: () => _invite(u),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    super.key,
    required this.user,
    required this.api,
    required this.sending,
    required this.sent,
    required this.onInvite,
  });

  final ChatUser user;
  final ChatApi api;
  final bool sending;
  final bool sent;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final Widget trailing;
    if (sent) {
      // Stays on screen rather than disappearing. A row that vanished on
      // success would leave no record of who you just invited, and this list
      // is exactly where someone double-checks that. The check springs in.
      trailing = Row(
        key: const ValueKey('sent'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.roomInviteFriendsSent,
            style: theme.bodySoft.copyWith(
              fontSize: 14,
              color: theme.inkMuted,
            ),
          ),
          const SizedBox(width: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MotionScope.of(context)
                .d(const Duration(milliseconds: 460)),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Icon(
              CupertinoIcons.checkmark_circle_fill,
              size: 24,
              color: theme.success,
            ),
          ),
        ],
      );
    } else if (sending) {
      trailing = const SizedBox(
        key: ValueKey('sending'),
        width: 44,
        child: Center(child: CupertinoActivityIndicator()),
      );
    } else {
      trailing = SpringPress(
        key: const ValueKey('invite'),
        onTap: onInvite,
        semanticLabel: l10n.roomInviteFriendsInviteButton,
        scale: 0.93,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.ink.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            sentenceCaseOf(context, l10n.roomInviteFriendsInviteButton),
            style: theme.bodySoft.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: theme.accent,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
      child: Row(
        children: [
          UserAvatar(user: user, size: 40, api: api),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: theme.body.copyWith(fontSize: 17, color: theme.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${user.username}',
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    color: theme.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: MotionScope.of(context)
                .d(const Duration(milliseconds: 200)),
            child: trailing,
          ),
        ],
      ),
    );
  }
}
