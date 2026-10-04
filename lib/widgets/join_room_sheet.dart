import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'labeled_field.dart';
import 'password_field.dart';
import 'remote_image.dart';
import 'visibility_badge.dart';
import 'sheet_kit.dart';
import 'ios_kit.dart';
import 'chat_list_row.dart' show monogramGradient;
import '../l10n/text_case.dart';

/// Confirmation gate shown before joining a public room — and the one place the
/// room describes itself in full.
///
/// The rows that lead here are lists: a name and a description have two lines
/// each and a handful of pills carry the rest, so a long name or a real
/// paragraph still ends in an ellipsis out there. This sheet is the opposite of
/// a list — one room, all of it. Nothing here is capped to a line count or
/// abbreviated to a glyph: the name wraps, the description is printed whole, and
/// every state the row could only show as a pill (public/private, locked,
/// self-destructing) gets its own labelled line and a sentence saying what it
/// means for you.
///
/// For a locked room the password field lives inline here, so this one sheet is
/// the whole gate — there's no separate password prompt afterwards.
///
/// Resolves to:
///   * `null` when the user cancels/dismisses.
///   * `(password: null)` when they confirm joining an unlocked room.
///   * `(password: <entered>)` when they confirm joining a locked room.
Future<({String? password})?> showJoinRoomSheet(
  BuildContext context,
  ChatRoom room,
  ChatApi api,
) {
  return showAdaptiveSheet<({String? password})>(
    context,
    builder: (_) => _JoinRoomSheet(room: room, api: api),
  );
}

class _JoinRoomSheet extends StatefulWidget {
  const _JoinRoomSheet({required this.room, required this.api});
  final ChatRoom room;
  final ChatApi api;

  @override
  State<_JoinRoomSheet> createState() => _JoinRoomSheetState();
}

class _JoinRoomSheetState extends State<_JoinRoomSheet> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canJoin => !widget.room.hasPassword || _password.text.isNotEmpty;

  void _join() {
    if (!_canJoin) return;
    Navigator.of(
      context,
    ).pop((password: widget.room.hasPassword ? _password.text : null));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final room = widget.room;
    final media = MediaQuery.of(context);
    final hasAvatar =
        room.avatarStorageId != null && room.avatarStorageId!.isNotEmpty;
    final description = room.description?.trim() ?? '';

    // The room's own account of itself scrolls; the join button never does, so a
    // room with a lot to say can't push the only action off the bottom. Measured
    // against the space the keyboard leaves, and bounded either way — the
    // desktop form of the sheet hands its content unbounded height, where an
    // unconstrained scroll view would throw.
    final maxStory = (media.size.height - media.viewInsets.bottom) * 0.45;

    // The App Store product sheet: the room's face centred and large, its
    // name and size under it, what it is about, the facts as a grouped block
    // of iOS rows, and one button. The × in the bar is the way out.
    final facts = <Widget>[
      GroupedRow(
        icon: room.isPublic
            ? CupertinoIcons.globe
            : CupertinoIcons.eye_slash_fill,
        tone: room.isPublic ? TileTone.blue : TileTone.gray,
        title: sentenceCaseOf(
          context,
          room.isPublic
              ? l10n.enterPublicRoomVisibilityPublicLabel
              : l10n.enterPublicRoomVisibilityPrivateLabel,
        ),
        subtitle: room.isPublic
            ? l10n.roomBadgePublicTooltip
            : l10n.roomBadgePrivateTooltip,
      ),
      if (room.hasPassword)
        GroupedRow(
          icon: CupertinoIcons.lock_fill,
          tone: TileTone.orange,
          title: sentenceCaseOf(context, l10n.roomCardLockedBadge),
          subtitle: l10n.roomBadgeLockedTooltip,
        ),
      if (room.isEphemeral && room.messageLifetime != null)
        GroupedRow(
          icon: CupertinoIcons.hourglass,
          tone: TileTone.purple,
          title: sentenceCaseOf(
            context,
            l10n.enterPublicRoomEphemeralBadgeLabel(
              ephemeralShort(l10n, room.messageLifetime!),
            ),
          ),
          subtitle: l10n.roomBadgeEphemeralTooltip(
            ephemeralShort(l10n, room.messageLifetime!),
          ),
        ),
      GroupedRow(
        icon: CupertinoIcons.calendar,
        tone: TileTone.red,
        title: sentenceCaseOf(context, l10n.roomInfoSheetCreatedLabel),
        // Flutter's own localizations format the date, so it reads natively
        // in all twelve languages.
        value: MaterialLocalizations.of(
          context,
        ).formatShortDate(room.createdAt.toLocal()),
      ),
    ];

    final trimmedName = room.name.trim();
    // SheetFrame adds the keyboard inset itself; padding for it here as well
    // lifted the Join button twice the keyboard's height.
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.groupCallBannerJoinRoomSheetTitle),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The room's own account of itself scrolls; the join button never
          // does, so a room with a lot to say can't push the only action off
          // the bottom.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxStory + 120),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Center(
                    child: SheetRise(
                      child: hasAvatar
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: RemoteImage(
                                storageId: room.avatarStorageId!,
                                api: widget.api,
                                width: 84,
                                height: 84,
                              ),
                            )
                          : Container(
                              width: 84,
                              height: 84,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: monogramGradient(
                                  theme,
                                  room.id.hashCode,
                                ),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: room.isEphemeral
                                  ? theme.hourglassIcon(
                                      size: 34,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      trimmedName.isEmpty
                                          ? '#'
                                          : trimmedName.characters.first
                                              .toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'CupertinoSystemDisplay',
                                        fontSize: 38,
                                        fontWeight: FontWeight.w600,
                                        height: 1,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // No maxLines anywhere in this sheet: a name too long for
                  // the rows is exactly the name someone came here to read.
                  Text(
                    room.name,
                    textAlign: TextAlign.center,
                    // The theme's own display size, not a literal 24: the
                    // name is this sheet's hero.
                    style: theme.displayMedium.copyWith(color: theme.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.groupCallBannerMemberCount(room.memberCount),
                    textAlign: TextAlign.center,
                    style: groupedSubtitleStyle(theme),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description.isEmpty
                        ? l10n.roomInfoSheetNoDescription
                        : description,
                    textAlign: TextAlign.center,
                    style: groupedFooterStyle(theme).copyWith(
                      color: description.isEmpty
                          ? theme.inkMuted
                          : theme.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SheetRise(
                    index: 1,
                    child: SheetGroup(children: facts),
                  ),
                ],
              ),
            ),
          ),
          if (room.hasPassword) ...[
            const SizedBox(height: 18),
            FieldLabel(l10n.groupCallBannerPasswordFieldLabel),
            PasswordField(
              controller: _password,
              hint: l10n.groupCallBannerPasswordHint,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              // Enter must not do what the dimmed Join button says it can't.
              onSubmitted: (_) => _canJoin ? _join() : null,
            ),
          ],
          const SizedBox(height: 18),
          Semantics(
            label: l10n.groupCallBannerJoinRoomButtonSemanticLabel,
            child: SheetActionButton(
              label: l10n.groupCallBannerJoinRoomButtonLabel,
              onTap: _canJoin ? _join : null,
            ),
          ),
        ],
      ),
    );
  }
}
