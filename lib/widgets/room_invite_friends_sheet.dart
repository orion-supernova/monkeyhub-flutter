import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../invites/room_admin_errors.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'sheet_surface.dart';
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

    return SheetSurface(
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.roomInviteFriendsTitle, style: theme.displaySmall),
                ),
                FocusableTap(
                  onTap: () => Navigator.of(context).pop(_anySent),
                  semanticLabel: l10n.roomInviteFriendsDone,
                  radius: theme.radiusSm,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(_anySent),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        l10n.roomInviteFriendsDone,
                        style: theme.label.copyWith(color: theme.accent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.roomInviteFriendsBlurb, style: theme.bodySoft),
            const SizedBox(height: 14),
            if (_friends.length > 6) ...[
              SearchField(
                controller: _search,
                hintText: l10n.roomInviteFriendsSearchHint,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
            ],
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.accent,
                    ),
                  ),
                ),
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
              // A plain Column, not a capped ListView. [SheetSurface] scrolls
              // the whole sheet now, and a scroller inside a scroller means
              // whichever one the finger happens to be over wins — the list
              // moving while the sheet stays put, or the reverse.
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          UserAvatar(user: user, size: 36, api: api),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: theme.body),
                Text('@${user.username}', style: theme.monoTiny),
              ],
            ),
          ),
          if (sent)
            // Stays on screen rather than disappearing. A row that vanished on
            // success would leave no record of who you just invited, and this
            // list is exactly where someone double-checks that.
            Text(
              l10n.roomInviteFriendsSent,
              style: theme.monoTiny.copyWith(color: theme.success),
            )
          else if (sending)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent),
            )
          else
            FocusableTap(
              onTap: onInvite,
              semanticLabel: l10n.roomInviteFriendsInviteButton,
              radius: theme.radiusSm,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onInvite,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.accent, width: 1.2),
                    borderRadius: BorderRadius.circular(theme.radiusSm),
                  ),
                  child: Text(
                    l10n.roomInviteFriendsInviteButton,
                    style: theme.monoTiny.copyWith(color: theme.accent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
