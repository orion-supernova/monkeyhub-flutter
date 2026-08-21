import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/room_admin.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'sheet_surface.dart';
import 'user_avatar.dart';

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
    final theme = ThemeScope.of(context);
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

    return SheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            member: member,
            memberRole: memberRole,
            api: api,
            isSelf: isSelf,
          ),
          const SizedBox(height: 18),
          if (contactable) ...[
            _ActionRow(
              icon: Icons.chat_bubble_outline,
              label: l10n.roomAdminActionMessage,
              onTap: () => Navigator.of(context).pop(RoomMemberAction.message),
            ),
            _ActionRow(
              icon: Icons.call_outlined,
              label: l10n.roomAdminActionVoiceCall,
              onTap: () => Navigator.of(context).pop(RoomMemberAction.voiceCall),
            ),
            _ActionRow(
              icon: Icons.videocam_outlined,
              label: l10n.roomAdminActionVideoCall,
              onTap: () => Navigator.of(context).pop(RoomMemberAction.videoCall),
            ),
          ],
          if (!isSelf)
            _ActionRow(
              icon: Icons.person_outline,
              label: l10n.roomAdminActionViewProfile,
              onTap: () =>
                  Navigator.of(context).pop(RoomMemberAction.openProfile),
            ),
          // The rule below the everyday rows. Promoting and removing are the
          // two things in here somebody can regret, and putting them a
          // thumb-width from "voice call" is how that happens.
          if (hasModeration) ...[
            const SizedBox(height: 6),
            Divider(height: 17, thickness: 1, color: theme.divider),
            const SizedBox(height: 6),
            if (canPromote)
              _ActionRow(
                icon: Icons.shield_outlined,
                label: l10n.roomAdminActionPromote,
                sub: l10n.roomAdminActionPromoteSub,
                onTap: () => Navigator.of(context).pop(RoomMemberAction.promote),
              ),
            if (canDemote)
              _ActionRow(
                icon: Icons.remove_moderator_outlined,
                label: l10n.roomAdminActionDemote,
                sub: l10n.roomAdminActionDemoteSub,
                onTap: () => Navigator.of(context).pop(RoomMemberAction.demote),
              ),
            if (canTransfer)
              _ActionRow(
                icon: Icons.workspace_premium_outlined,
                label: l10n.roomAdminActionTransfer,
                sub: l10n.roomAdminActionTransferSub,
                onTap: () => Navigator.of(context)
                    .pop(RoomMemberAction.transferOwnership),
              ),
            if (canRemove)
              _ActionRow(
                icon: Icons.person_remove_outlined,
                label: l10n.roomAdminActionRemove,
                danger: true,
                onTap: () => Navigator.of(context).pop(RoomMemberAction.remove),
              ),
          ],
        ],
      ),
    );
  }
}

/// Who this sheet is about, stated once and large.
///
/// The avatar is deliberately bigger than the list row's — the sheet is a
/// close-up of one person, and repeating the row's 32px would read as the list
/// having simply grown a menu rather than focused on someone.
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
    return Row(
      children: [
        UserAvatar(user: member, size: 52, api: api),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      member.displayName,
                      style: theme.displaySmall.copyWith(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelf) ...[
                    const SizedBox(width: 6),
                    Text(l10n.roomAdminYouSuffix, style: theme.monoTiny),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '@${member.username}',
                style: theme.mono.copyWith(color: theme.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (memberRole != RoomRole.member) ...[
          const SizedBox(width: 8),
          RoleChip(role: memberRole),
        ],
      ],
    );
  }
}

/// The owner/admin label, shared by the sheet header and the member row so the
/// two cannot style the same fact differently.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role, this.dense = false});

  final RoomRole role;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isOwner = role == RoomRole.owner;
    final color = isOwner ? theme.accentInk : theme.inkSoft;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 3 : 4,
      ),
      // Filled for the owner, outlined for an admin. One room has exactly one
      // owner and can have many admins, so the rarer fact gets the louder
      // treatment and a roster of admins does not turn into a wall of colour.
      //
      // Both read "ADMIN" — an owner is one, plus this badge. A separate word
      // ("OWNER") read as property law once translated (SAHİP, PROPRIÉTAIRE,
      // DONO); the medal — the same icon `roomAdminActionTransfer` uses — is
      // what actually says "started this room now", and the footer under the
      // roster spells that out once instead of leaning on the word.
      decoration: theme.chipDecoration(filled: isOwner),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner) ...[
            Icon(
              Icons.workspace_premium_outlined,
              size: dense ? 11 : 12,
              color: color,
            ),
            const SizedBox(width: 3),
          ],
          Text(l10n.roomAdminRoleAdmin, style: theme.monoTiny.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// One tappable row, with a press state.
///
/// Stateful purely for that. A row that does not visibly react between
/// finger-down and the sheet closing reads as dead — it is the single cheapest
/// thing that separates a native-feeling list from a web page, and its absence
/// is most of what "looks too Android" means on a surface like this.
///
/// A tinted fill rather than the [AnimatedScale] the action menu's icon pills
/// use: those are discrete circular targets that can grow without disturbing
/// anything, where a full-width row scaling up would nudge its neighbours.
class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sub,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final icon = widget.icon;
    final label = widget.label;
    final sub = widget.sub;
    final danger = widget.danger;
    final onTap = widget.onTap;
    final tint = danger ? theme.danger : theme.ink;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: sub == null ? label : '$label. $sub',
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: theme.motionFast,
          decoration: BoxDecoration(
            color: _pressed
                ? tint.withValues(alpha: danger ? 0.14 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          // No negative margin. `AnimatedContainer` asserts
          // `margin.isNonNegative`, and the first cut used one to bleed the
          // highlight past the text column — which threw on every row of the
          // sheet the moment it opened. The highlight spanning the row's
          // natural width reads the same and is legal.
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 21, color: tint),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: theme.body.copyWith(color: tint)),
                    if (sub != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(sub, style: theme.monoTiny),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
