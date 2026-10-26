import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'chat_list_row.dart' show monogramGradient;
import 'ios_kit.dart';
import 'sunlit_surface.dart' show sunlitShadows;

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
    // The shared person row — callers set these inside one GroupedSection,
    // the iOS contacts list, rather than each on a floating card.
    return PersonRow(
      avatar: UserAvatar(user: user, size: 40, api: api),
      title: user.displayName,
      subtitle: '@${user.username}',
      semanticLabel:
          l10n.childSetupScreenFriendRowMessageSemanticLabel(user.displayName),
      onTap: onTap,
      trailing: Icon(
        CupertinoIcons.chat_bubble_fill,
        size: 18,
        color: theme.accent,
      ),
    );
  }
}

/// The block every Discover row sits on: the grouped fill, generously
/// rounded, no border — an iOS inset row standing alone. On a light theme it
/// carries the sunlit shadow so it lifts off the page like a grouped card.
BoxDecoration discoverCardDecoration(AppTheme theme) => BoxDecoration(
      color: groupedFill(theme),
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      boxShadow: theme.isLight ? sunlitShadows(theme) : null,
    );

TextStyle _name(AppTheme theme) => theme.bodyEmph.copyWith(
      color: theme.ink,
      fontSize: 17,
      fontStyle: FontStyle.normal,
    );

/// The body face at meta size — never the theme's caption, which is tracked
/// monospace on the character themes ("248  members").
TextStyle _meta(AppTheme theme) => groupedMetaStyle(theme);

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
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: PressSpec.scaleSmall,
      semanticLabel: room.name,
      focusRadius: groupedRadius(theme),
      // One row: the room's face, its name, two lines of what it is about,
      // and a quiet meta line. The old tile spelled visibility, lifetime and
      // lock out as labelled pills; here they are glyphs in muted ink, and
      // only "joined" / "waiting" keep a word, because those are about YOU
      // rather than about the room. Callers set rows inside one
      // GroupedSection rather than each on its own card.
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          // Centred on the cross axis, as iOS does: top-aligned, the chevron
          // sat level with the title in the top corner of a three-line row.
          child: Row(
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
                        style: groupedSubtitleStyle(theme),
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
              Icon(
                CupertinoIcons.chevron_forward,
                size: 15,
                color: theme.inkMuted.withValues(alpha: 0.7),
              ),
            ],
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
              // The theme's own emphasis face, not a hard-coded system
              // family: a character theme's letters stay its own.
              style: theme.bodyEmph.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
                height: 1,
                color: Colors.white,
              ),
            ),
    );
  }
}

/// A section with nothing in it: the shared one-line empty note.
///
/// Air above only. Whatever follows a section owns the gap after it (32 to
/// the next heading on Discover), and a bottom pad here stacked on top of
/// that, leaving Discover's rhythm 12pt looser than every other tab's.
class DiscoverEmptyLine extends StatelessWidget {
  const DiscoverEmptyLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      EmptyLine(text, padding: const EdgeInsets.only(top: 12));
}
