import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import '../keyboard/focusable_tap.dart';
import 'discover_rows.dart';
import 'labeled_field.dart';
import 'password_field.dart';
import 'remote_image.dart';
import 'visibility_badge.dart';

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

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              l10n.groupCallBannerJoinRoomSheetTitle,
              style: theme.label.copyWith(
                color: theme.accent,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxStory),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasAvatar)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                            child: RemoteImage(
                              storageId: room.avatarStorageId!,
                              api: widget.api,
                              width: 52,
                              height: 52,
                            ),
                          )
                        else
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.surface,
                              borderRadius: BorderRadius.circular(
                                theme.radiusMd,
                              ),
                              border: Border.all(color: theme.divider),
                            ),
                            child: room.isEphemeral
                                ? theme.hourglassIcon(
                                    size: 22,
                                    color: theme.accent,
                                  )
                                : Icon(
                                    Icons.tag,
                                    size: 22,
                                    color: theme.inkSoft,
                                  ),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // No maxLines and no ellipsis anywhere in this
                              // sheet: a name too long for the rows is exactly
                              // the name someone came here to read.
                              Text(room.name, style: theme.displayLarge),
                              const SizedBox(height: 4),
                              Text(
                                l10n.groupCallBannerMemberCount(
                                  room.memberCount,
                                ),
                                style: theme.monoTiny,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      description.isEmpty
                          ? l10n.roomInfoSheetNoDescription
                          : description,
                      style: description.isEmpty
                          ? theme.bodySoft.copyWith(color: theme.inkMuted)
                          : theme.body,
                    ),
                    const SizedBox(height: 20),
                    DiscoverSectionHeader(
                      label: l10n.roomInfoSheetDetailsLabel,
                      count: '',
                    ),
                    const SizedBox(height: 12),
                    _DetailLine(
                      icon: theme.visibilityIcon(
                        isPublic: room.isPublic,
                        size: 16,
                      ),
                      title: room.isPublic
                          ? l10n.enterPublicRoomVisibilityPublicLabel
                          : l10n.enterPublicRoomVisibilityPrivateLabel,
                      body: room.isPublic
                          ? l10n.roomBadgePublicTooltip
                          : l10n.roomBadgePrivateTooltip,
                    ),
                    if (room.hasPassword)
                      _DetailLine(
                        icon: Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: theme.inkSoft,
                        ),
                        title: l10n.roomCardLockedBadge,
                        body: l10n.roomBadgeLockedTooltip,
                      ),
                    if (room.isEphemeral && room.messageLifetime != null)
                      _DetailLine(
                        icon: theme.hourglassIcon(
                          size: 16,
                          color: theme.accent,
                        ),
                        title: l10n.enterPublicRoomEphemeralBadgeLabel(
                          ephemeralShort(l10n, room.messageLifetime!),
                        ),
                        body: l10n.roomBadgeEphemeralTooltip(
                          ephemeralShort(l10n, room.messageLifetime!),
                        ),
                      ),
                    _DetailLine(
                      icon: Icon(
                        Icons.schedule,
                        size: 16,
                        color: theme.inkSoft,
                      ),
                      title: l10n.roomInfoSheetCreatedLabel,
                      // Flutter's own localizations format the date, so this
                      // reads natively in all twelve languages without a
                      // twelve-language month table of our own. Short form: the
                      // weekday a room was made on is the one part of this
                      // nobody came here for.
                      body: MaterialLocalizations.of(
                        context,
                      ).formatShortDate(room.createdAt.toLocal()),
                    ),
                  ],
                ),
              ),
            ),
            if (room.hasPassword) ...[
              const SizedBox(height: 20),
              FieldLabel(l10n.groupCallBannerPasswordFieldLabel),
              PasswordField(
                controller: _password,
                hint: l10n.groupCallBannerPasswordHint,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                // Enter must not do what the dimmed JOIN button says it can't.
                onSubmitted: (_) => _canJoin ? _join() : null,
              ),
            ],
            const SizedBox(height: 20),
            FocusableTap(
              onTap: _canJoin ? _join : null,
              enabled: _canJoin,
              autofocus: !room.hasPassword,
              semanticLabel: l10n.groupCallBannerJoinRoomButtonSemanticLabel,
              radius: theme.radiusMd,
              child: Opacity(
                opacity: _canJoin ? 1 : 0.4,
                child: GestureDetector(
                  onTap: _join,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Text(
                      l10n.groupCallBannerJoinRoomButtonLabel,
                      style: theme.label.copyWith(
                        color: theme.accentInk,
                        letterSpacing: 2.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            FocusableTap(
              onTap: () => Navigator.of(context).pop(),
              semanticLabel: l10n.groupCallBannerCancelButtonSemanticLabel,
              radius: theme.radiusMd,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  child: Text(
                    l10n.groupCallBannerCancelButtonLabel,
                    style: theme.bodySoft.copyWith(color: theme.inkMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One fact about the room: the glyph the rows use for it, the short label the
/// pill would have carried, and the sentence the pill's tooltip was hiding.
///
/// The sentence is the point. A padlock on a row tells you there's something to
/// know; only "you'll need the room password to join" tells you what to do about
/// it — so it wraps to as many lines as it takes and is never abbreviated.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.title,
    required this.body,
  });
  final Widget icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 22, child: Center(child: icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.monoTiny.copyWith(color: theme.inkSoft),
                ),
                const SizedBox(height: 3),
                Text(body, style: theme.bodySoft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
