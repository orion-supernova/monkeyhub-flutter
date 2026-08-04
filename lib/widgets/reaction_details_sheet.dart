import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/message_reaction.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'message_stamp.dart' show formatClockTime;
import 'user_avatar.dart';

/// Long-press a reaction chip and this names the people behind it.
///
/// A chip only ever says `😂 3`, which is the one thing about a reaction nobody
/// needs help with. Who sent it is already on the client — [MessageReaction] is
/// one row per (person, emoji), so the chip has been collapsing a list it
/// already holds. This un-collapses it, for every reaction on the message
/// rather than just the one that was pressed: the chip you long-pressed selects
/// its own filter, and the others are one tap away.
Future<void> showReactionDetailsSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  required String roomId,
  required String messageId,

  /// The reactions as the pressed bubble knows them. Used only if the message
  /// itself can't be found in the live caches — a message paged out of the
  /// window still has a bubble on screen that can be long-pressed.
  required List<MessageReaction> fallback,
  required String currentUserId,
  required String initialEmoji,

  /// Room members, which is the only source that covers people who aren't
  /// friends. Null for someone who has since left.
  required ChatUser? Function(String userId) resolveUser,
  required void Function(ChatUser user) onOpenProfile,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => ReactionDetailsSheet(
      repo: repo,
      api: api,
      roomId: roomId,
      messageId: messageId,
      fallback: fallback,
      currentUserId: currentUserId,
      initialEmoji: initialEmoji,
      resolveUser: resolveUser,
      onOpenProfile: onOpenProfile,
    ),
  );
}

class ReactionDetailsSheet extends StatefulWidget {
  const ReactionDetailsSheet({
    super.key,
    required this.repo,
    required this.api,
    required this.roomId,
    required this.messageId,
    required this.fallback,
    required this.currentUserId,
    required this.initialEmoji,
    required this.resolveUser,
    required this.onOpenProfile,
  });

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;
  final String messageId;
  final List<MessageReaction> fallback;
  final String currentUserId;
  final String initialEmoji;
  final ChatUser? Function(String userId) resolveUser;
  final void Function(ChatUser user) onOpenProfile;

  @override
  State<ReactionDetailsSheet> createState() => _ReactionDetailsSheetState();
}

class _ReactionDetailsSheetState extends State<ReactionDetailsSheet> {
  /// Selected filter; null means ALL.
  String? _emoji;

  @override
  void initState() {
    super.initState();
    _emoji = widget.initialEmoji;
  }

  /// Read through to the repository on every build rather than snapshotting, so
  /// a reaction that lands (or is taken back) while the sheet is open shows up.
  /// [ChatRepository] is a [ChangeNotifier] and reactions ride along with every
  /// message list query, so this costs one list scan per notification.
  List<MessageReaction> get _reactions =>
      widget.repo.findMessageInRoom(widget.roomId, widget.messageId)?.reactions ??
      widget.fallback;

  ChatUser _userFor(String id) =>
      widget.resolveUser(id) ??
      widget.repo.userById(id) ??
      // Reacted, then left the room, and never was a friend. The id still
      // seeds a stable avatar gradient, so the row doesn't look broken.
      ChatUser(id: id, username: 'someone', name: '');

  void _select(String? emoji) {
    if (_emoji == emoji) return;
    HapticFeedback.selectionClick();
    setState(() => _emoji = emoji);
  }

  void _openProfile(ChatUser user) {
    Navigator.of(context).pop();
    widget.onOpenProfile(user);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: widget.repo,
      builder: (context, _) => _body(context, theme),
    );
  }

  Widget _body(BuildContext context, AppTheme theme) {
    final reactions = _reactions;
    final groups = _groupsOf(reactions);
    // The filter survives everything except its own emoji being taken back by
    // the last person holding it.
    final selected =
        groups.any((g) => g.emoji == _emoji) ? _emoji : null;
    final people = reactions.map((r) => r.userId).toSet().length;

    final rows = (selected == null
        ? [...reactions]
        : [...groups.firstWhere((g) => g.emoji == selected).rows])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      decoration: theme.sheetDecoration(),
      padding: EdgeInsets.fromLTRB(
          22, 14, 22, 22 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          Text(
            AppLocalizations.of(context).reactionDetailsSheetTitle,
            textAlign: TextAlign.center,
            style: theme.label.copyWith(letterSpacing: 2.4),
          ),
          if (reactions.isEmpty) ...[
            const SizedBox(height: 14),
            Text(
              AppLocalizations.of(context).reactionDetailsSheetEmptyState,
              textAlign: TextAlign.center,
              style: theme.bodySoft,
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)
                  .reactionDetailsSheetPeopleCount(people),
              textAlign: TextAlign.center,
              style: theme.monoTiny,
            ),
            const SizedBox(height: 14),
            if (groups.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Vertical breathing room so FocusableTap's ring, which paints
                // outside its child's bounds, isn't clipped by the scroll view.
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    _FilterPill(
                      label: AppLocalizations.of(context)
                          .reactionDetailsSheetFilterAll,
                      count: reactions.length,
                      selected: selected == null,
                      onTap: () => _select(null),
                    ),
                    for (final g in groups) ...[
                      const SizedBox(width: 6),
                      _FilterPill(
                        emoji: g.emoji,
                        count: g.rows.length,
                        selected: selected == g.emoji,
                        onTap: () => _select(g.emoji),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: AnimatedSwitcher(
                  duration: theme.motionFast,
                  switchInCurve: theme.motionEntrance,
                  child: ListView.builder(
                    key: ValueKey(selected ?? '*'),
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      return _ReactorRow(
                        user: _userFor(r.userId),
                        api: widget.api,
                        time: formatClockTime(r.createdAt),
                        // Redundant inside a single-emoji filter — every row
                        // there carries the emoji already named by the pill.
                        emoji: selected == null ? r.emoji : null,
                        isMe: r.userId == widget.currentUserId,
                        onOpenProfile: _openProfile,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Busiest reaction first; ties broken by whichever emoji showed up first, so
  /// the pill order doesn't shuffle as counts change under the sheet.
  static List<_Group> _groupsOf(List<MessageReaction> reactions) {
    final byEmoji = <String, List<MessageReaction>>{};
    for (final r in reactions) {
      byEmoji.putIfAbsent(r.emoji, () => []).add(r);
    }
    final groups = [
      for (final e in byEmoji.entries) _Group(e.key, e.value),
    ];
    groups.sort((a, b) {
      final byCount = b.rows.length.compareTo(a.rows.length);
      if (byCount != 0) return byCount;
      return a.firstAt.compareTo(b.firstAt);
    });
    return groups;
  }
}

class _Group {
  _Group(this.emoji, this.rows);
  final String emoji;
  final List<MessageReaction> rows;

  DateTime get firstAt => rows.fold<DateTime>(
        rows.first.createdAt,
        (earliest, r) => r.createdAt.isBefore(earliest) ? r.createdAt : earliest,
      );
}

/// Deliberately the same pill language as the reaction chip under the bubble —
/// accent-tinted when it's the one in play, plain surface otherwise — so the
/// chip you long-pressed is recognisable as the filter that opened selected.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    this.emoji,
    this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String? emoji;
  final String? label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.capsule,
      radius: 999,
      semanticLabel: '${emoji ?? label} $count',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? theme.accent.withValues(alpha: 0.18)
                : theme.surfaceRaised,
            border: Border.all(
              color: selected
                  ? theme.accent.withValues(alpha: 0.6)
                  : theme.divider,
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 14))
              else
                Text(
                  label!,
                  style: theme.monoTiny.copyWith(
                    color: selected ? theme.accent : theme.inkSoft,
                  ),
                ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: theme.monoTiny.copyWith(
                  color: selected ? theme.accent : theme.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's person row, as the room-info member list and the call-invite sheet
/// already write it: face, name over handle, then whatever this particular list
/// has to add on the right.
class _ReactorRow extends StatelessWidget {
  const _ReactorRow({
    required this.user,
    required this.api,
    required this.time,
    required this.emoji,
    required this.isMe,
    required this.onOpenProfile,
  });

  final ChatUser user;
  final ChatApi api;
  final String time;
  final String? emoji;
  final bool isMe;
  final void Function(ChatUser user) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final open = isMe ? null : () => onOpenProfile(user);
    return FocusableTap(
      onTap: open,
      radius: 12,
      semanticLabel: user.displayName,
      child: GestureDetector(
        onTap: open,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              UserAvatar(user: user, api: api, size: 36, showStatus: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: theme.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: theme.chipDecoration(filled: true),
                            child: Text(
                              AppLocalizations.of(context)
                                  .reactionDetailsSheetYouBadge,
                              style: theme.monoTiny
                                  .copyWith(color: theme.accentInk),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text('@${user.username}', style: theme.monoTiny),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(time, style: theme.monoTiny),
              if (emoji != null) ...[
                const SizedBox(width: 10),
                Text(emoji!, style: const TextStyle(fontSize: 16)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
