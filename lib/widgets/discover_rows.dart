import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'chat_list_row.dart' show monogramGradient;
import 'ios_kit.dart' show groupedFill, groupedRadius;

import 'approval_gate.dart';
import 'remote_image.dart';
import 'user_avatar.dart';
import '../l10n/text_case.dart';

/// Someone you already know. Tapping opens (or starts) the DM.
///
/// Shared between Discover's preview and the full people list, so a row can't
/// come to mean two different things depending on where you found it.
class FriendRow extends StatelessWidget {
  const FriendRow({
    super.key,
    required this.user,
    required this.api,
    required this.onTap,
  });
  final ChatUser user;
  final ChatApi api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.childSetupScreenFriendRowMessageSemanticLabel(
          user.displayName),
      radius: theme.radiusXl,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: discoverCardDecoration(theme),
          child: Row(
            children: [
              UserAvatar(user: user, size: 44, api: api),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _name(theme),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _meta(theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chat_bubble_fill,
                size: 18,
                color: theme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The block every Discover row sits on: the grouped fill, generously
/// rounded, no border and no shadow — an iOS inset row standing alone.
BoxDecoration discoverCardDecoration(AppTheme theme) => BoxDecoration(
      color: groupedFill(theme),
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
    );

TextStyle _name(AppTheme theme) => theme.bodyEmph.copyWith(
      color: theme.ink,
      fontSize: 17,
      fontStyle: FontStyle.normal,
    );

TextStyle _meta(AppTheme theme) => theme.caption.copyWith(
      fontSize: 13,
      color: theme.inkMuted,
    );

class PublicRoomTile extends StatelessWidget {
  const PublicRoomTile({
    super.key,
    required this.room,
    required this.onTap,
    this.api,
    this.awaiting = false,
    this.joined = false,
  });
  final ChatRoom room;
  final VoidCallback onTap;

  /// Only needed to fetch a room's own avatar; without it the row falls back to
  /// the glyph, which is also what a room with no avatar set gets.
  final ChatApi? api;

  /// This child has already asked a grown-up about this room.
  final bool awaiting;

  /// The viewer is already a member, so tapping opens it rather than joining.
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final hasDescription =
        room.description != null && room.description!.trim().isNotEmpty;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: room.name,
      radius: theme.radiusXl,
      child: GestureDetector(
        onTap: onTap,
        // One block: the room's face, its name, two lines of what it is
        // about, and a quiet meta line. The old tile spelled visibility,
        // lifetime and lock out as labelled pills; here they are glyphs in
        // muted ink, and only "joined" / "waiting" keep a word, because those
        // are about YOU rather than about the room.
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: discoverCardDecoration(theme),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoomGlyph(room: room, api: api),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _name(theme),
                    ),
                    if (hasDescription) ...[
                      const SizedBox(height: 2),
                      // Left in the case the owner typed it.
                      Text(
                        room.description!.trim(),
                        style: theme.bodySoft.copyWith(
                          fontSize: 15,
                          height: 1.3,
                          color: theme.inkMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.person_2_fill,
                          size: 13,
                          color: theme.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.groupCallBannerMemberCount(room.memberCount),
                          style: _meta(theme).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (room.isEphemeral) ...[
                          const SizedBox(width: 10),
                          theme.hourglassIcon(size: 12, color: theme.inkMuted),
                        ],
                        if (room.hasPassword) ...[
                          const SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.lock_fill,
                            size: 12,
                            color: theme.inkMuted,
                          ),
                        ],
                        const Spacer(),
                        // A quiet tick and the word, in the success
                        // colour — the App Store's "Open" state, not a pill.
                        if (joined)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                size: 14,
                                color: theme.success,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                sentenceCaseOf(
                                  context,
                                  l10n.enterPublicRoomJoinedBadgeLabel,
                                ),
                                style: _meta(theme).copyWith(
                                  color: theme.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        else if (awaiting)
                          WaitingPill(
                            label: l10n.childSetupScreenWaitingPillAskedLabel,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 15,
                  color: theme.inkMuted.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomGlyph extends StatelessWidget {
  const _RoomGlyph({required this.room, required this.api});
  final ChatRoom room;
  final ChatApi? api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final storageId = room.avatarStorageId;
    if (storageId != null && storageId.isNotEmpty && api != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: RemoteImage(
          storageId: storageId,
          api: api!,
          width: 48,
          height: 48,
        ),
      );
    }
    // A lettered squircle in the room's own hue — the face a room wears in
    // the chat list, squared off so rooms and people stay apart at a glance.
    final trimmed = room.name.trim();
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: monogramGradient(theme, room.id.hashCode),
        borderRadius: BorderRadius.circular(13),
      ),
      child: room.isEphemeral
          ? theme.hourglassIcon(size: 20, color: Colors.white)
          : Text(
              trimmed.isEmpty
                  ? '#'
                  : trimmed.characters.first.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'CupertinoSystemDisplay',
                fontSize: 21,
                fontWeight: FontWeight.w600,
                height: 1,
                color: Colors.white,
              ),
            ),
    );
  }
}

class DiscoverSectionHeader extends StatelessWidget {
  const DiscoverSectionHeader({
    super.key,
    required this.label,
    required this.count,
  });
  final String label;

  /// Empty string hides the number — used while a fetch is in flight, so a `0`
  /// only ever means "looked, found nothing".
  final String count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The App Store / Music section title: bold, sentence case, the count
    // trailing in muted ink. No rule — the space above does the separating.
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              sentenceCaseOf(context, label),
              style: theme.displaySmall.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.35,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              count,
              style: theme.body.copyWith(
                fontSize: 17,
                color: theme.inkMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SeeAllRow extends StatelessWidget {
  const SeeAllRow({super.key, required this.total, required this.onTap});
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.childSetupScreenSeeAllSemanticLabel(total),
      radius: theme.radiusXl,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // A text link in the accent, the iOS "See All".
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sentenceCaseOf(context, l10n.childSetupScreenSeeAllLabel(total)),
                style: theme.body.copyWith(
                  fontSize: 17,
                  color: theme.accent,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 15,
                color: theme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverEmptyLine extends StatelessWidget {
  const DiscoverEmptyLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Text(text, style: theme.bodySoft),
    );
  }
}
