import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/room_admin.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import 'user_avatar.dart';
import '../l10n/text_case.dart';

/// What the caller picked. The sheet decides what to OFFER; the screen that
/// opened it decides what to DO, so the confirmations, the error copy and the
/// "did the list change" bookkeeping all stay in one place instead of being
/// split across a sheet that would need the repository anyway.
enum RoomMemberAction {
  message,
  voiceCall,
  videoCall,
  openProfile,
  promote,
  demote,
  transferOwnership,
  remove,
}

/// The sheet behind a tapped member row.
///
/// **Opens for everyone, not just admins.** An earlier cut showed it only to
/// people who could moderate and sent everyone else straight to the profile
/// screen, which meant a plain member tapping a face got a jarring full-screen
/// push and no way to just message them. Every mainstream chat app puts the
/// same sheet under that tap and simply varies the rows — the person is the
/// subject, and "what can I do with this person" starts at "talk to them", not
/// at "moderate them".
///
/// So the rows come in two blocks:
///
///   contact     message, voice, video, view profile — everyone, always
///   moderation  promote / demote / transfer / remove — gated, and separated
///               by a divider so the destructive half is never a mis-tap away
///               from the everyday half
///
/// Nothing here is an authorization boundary: `roomAdmin.ts` re-derives the
/// caller's role on every mutation. Hiding a row it would refuse is a
/// legibility decision — an admin sheet full of greyed-out options invites
/// people to tap them and be told no.
///
/// Returns null when dismissed.
Future<RoomMemberAction?> showRoomMemberActions(
  BuildContext context, {
  required ChatUser member,
  required RoomRole memberRole,
  required RoomPermissions permissions,
  required ChatApi api,
  required bool isSelf,
}) {
  // The sheet is reachable by long-press as well as tap, and a long-press with
  // no physical answer feels broken on iOS.
  HapticFeedback.selectionClick();
  return showAdaptiveSheet<RoomMemberAction>(
    context,
    // Bounded by the top safe area. `ModalBottomSheetRoute` strips the top
    // inset from everything inside it, so a `SafeArea` in the content is a
    // silent no-op — this flag is the only hook that applies it, from the
    // route, where the padding still exists. Without it a tall sheet runs
    // under the notch.
    useSafeArea: true,
    builder: (_) => _MemberActionsSheet(
      member: member,
      memberRole: memberRole,
      permissions: permissions,
      api: api,
      isSelf: isSelf,
    ),
  );
}

class _MemberActionsSheet extends StatelessWidget {
  const _MemberActionsSheet({
    required this.member,
    required this.memberRole,
    required this.permissions,
    required this.api,
    required this.isSelf,
  });

  final ChatUser member;
  final RoomRole memberRole;
  final RoomPermissions permissions;
  final ChatApi api;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The owner's row is the one nobody edits. Their seat moves through
    // `transferOwnership` and nowhere else — without this an admin could
    // demote the owner and take the room, which is the single worst thing a
    // flat-powers admin tier can get wrong.
    final targetIsOwner = memberRole == RoomRole.owner;
    final targetIsAdmin = memberRole == RoomRole.admin;

    // Your own row gets the identity header and nothing else. "Message
    // yourself" and "remove yourself" are both wrong answers, and Saved
    // Messages already exists for the first.
    final contactable = !isSelf && !member.isSystem;

    final canPromote =
        !isSelf && permissions.canAssignAdmins && !targetIsOwner && !targetIsAdmin;
    final canDemote = !isSelf && permissions.canAssignAdmins && targetIsAdmin;
    final canTransfer = !isSelf && permissions.isOwner && !targetIsOwner;
    // An admin cannot remove another admin: that would make every promotion a
    // race over who taps first. Demote, then remove — or be the owner.
    final canRemove = !isSelf &&
        permissions.canRemoveMembers &&
        !targetIsOwner &&
        (!targetIsAdmin || permissions.isOwner);

    final hasModeration = canPromote || canDemote || canTransfer || canRemove;
    void pick(RoomMemberAction a) => Navigator.of(context).pop(a);

    // A contact card, the iOS shape: the person large and centred, the
    // everyday things you do with them as a row of quick-action tiles, and
    // moderation in its own grouped block below — the destructive half never
    // a thumb-width from "voice call".
    return SheetFrame(
      leading: const SheetCloseButton(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetRise(
            child: _Header(
              member: member,
              memberRole: memberRole,
              api: api,
              isSelf: isSelf,
            ),
          ),
          if (contactable || !isSelf) ...[
            const SizedBox(height: 20),
            SheetRise(
              index: 1,
              child: Row(
                children: [
                  if (contactable) ...[
                    _QuickAction(
                      icon: CupertinoIcons.chat_bubble_fill,
                      label: l10n.roomAdminActionMessage,
                      onTap: () => pick(RoomMemberAction.message),
                    ),
                    _QuickAction(
                      icon: CupertinoIcons.phone_fill,
                      label: l10n.roomAdminActionVoiceCall,
                      onTap: () => pick(RoomMemberAction.voiceCall),
                    ),
                    _QuickAction(
                      icon: CupertinoIcons.video_camera_solid,
                      label: l10n.roomAdminActionVideoCall,
                      onTap: () => pick(RoomMemberAction.videoCall),
                    ),
                  ],
                  if (!isSelf)
                    _QuickAction(
                      icon: CupertinoIcons.person_crop_circle_fill,
                      label: l10n.roomAdminActionViewProfile,
                      onTap: () => pick(RoomMemberAction.openProfile),
                    ),
                ],
              ),
            ),
          ],
          if (hasModeration) ...[
            const SizedBox(height: 20),
            SheetRise(
              index: 2,
              child: SheetGroup(
                children: [
                  if (canPromote)
                    GroupedRow(
                      icon: CupertinoIcons.shield_lefthalf_fill,
                      tone: TileTone.blue,
                      title: l10n.roomAdminActionPromote,
                      subtitle: l10n.roomAdminActionPromoteSub,
                      chevron: false,
                      onTap: () => pick(RoomMemberAction.promote),
                    ),
                  if (canDemote)
                    GroupedRow(
                      icon: CupertinoIcons.shield_slash_fill,
                      tone: TileTone.gray,
                      title: l10n.roomAdminActionDemote,
                      subtitle: l10n.roomAdminActionDemoteSub,
                      chevron: false,
                      onTap: () => pick(RoomMemberAction.demote),
                    ),
                  if (canTransfer)
                    GroupedRow(
                      icon: CupertinoIcons.rosette,
                      tone: TileTone.orange,
                      title: l10n.roomAdminActionTransfer,
                      subtitle: l10n.roomAdminActionTransferSub,
                      chevron: false,
                      onTap: () => pick(RoomMemberAction.transferOwnership),
                    ),
                  if (canRemove)
                    GroupedRow(
                      icon: CupertinoIcons.person_badge_minus_fill,
                      title: l10n.roomAdminActionRemove,
                      destructive: true,
                      onTap: () => pick(RoomMemberAction.remove),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Who this sheet is about, stated once and large: the contact card's face,
/// name and handle, centred, with the role beneath.
class _Header extends StatelessWidget {
  const _Header({
    required this.member,
    required this.memberRole,
    required this.api,
    required this.isSelf,
  });

  final ChatUser member;
  final RoomRole memberRole;
  final ChatApi api;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(user: member, size: 76, api: api),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                member.displayName,
                style: theme.displaySmall.copyWith(
                  fontSize: 22,
                  color: theme.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelf) ...[
              const SizedBox(width: 6),
              Text(
                '(${l10n.roomAdminYouSuffix})',
                style: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '@${member.username}',
          style: theme.bodySoft.copyWith(fontSize: 15, color: theme.inkMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (memberRole != RoomRole.member) ...[
          const SizedBox(height: 10),
          RoleChip(role: memberRole),
        ],
      ],
    );
  }
}

/// The owner/admin label, shared by the sheet header and the member row so the
/// two cannot style the same fact differently.
///
/// A neutral capsule for both, with the owner marked by the medal — the same
/// glyph `roomAdminActionTransfer` uses — in the accent. Accent FILLS are kept
/// for primary actions: an accent wash on a dark page reads as navy.
///
/// Both read "Admin" — an owner is one, plus the medal. A separate word
/// ("OWNER") read as property law once translated (SAHİP, PROPRIÉTAIRE, DONO).
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role, this.dense = false});

  final RoomRole role;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isOwner = role == RoomRole.owner;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: theme.ink.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner) ...[
            Icon(
              CupertinoIcons.rosette,
              size: dense ? 12 : 13,
              color: theme.accent,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            sentenceCaseOf(context, l10n.roomAdminRoleAdmin),
            style: theme.bodySoft.copyWith(
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: theme.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the contact card's quick actions: a glyph over a word on a soft
/// tile, equal widths across the row — iOS Contacts' Message / Call / Video.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SpringPress(
          onTap: onTap,
          scale: 0.92,
          semanticLabel: label,
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: sheetGroupFill(theme),
              borderRadius: BorderRadius.circular(
                (groupedRadius(theme) * 0.7).clamp(6.0, 16.0),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: theme.accent),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.bodySoft.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    color: theme.accent,
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
