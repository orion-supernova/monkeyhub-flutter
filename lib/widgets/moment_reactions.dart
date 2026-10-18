import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_user.dart';
import '../models/moment.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'filter_capsule.dart';
import 'react_toggle.dart';
import 'sheet_kit.dart';
import 'user_avatar.dart';
import 'desktop_scroll.dart';

/// One person's reactions to one thing: who, and every emoji they left,
/// newest first.
///
/// A person, not a reaction, is the unit everything here draws: Instagram's
/// avatar row shows faces, and someone who left three emoji is one face with
/// three emoji, not three faces.
class MomentReactorGroup {
  MomentReactorGroup({
    required this.userId,
    required this.name,
    this.username,
    this.avatarStorageId,
  });

  final String userId;
  String name;
  String? username;
  String? avatarStorageId;
  final List<String> emojis = [];
  DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);

  ChatUser asUser() => ChatUser(
        id: userId,
        username: username ?? name,
        name: name,
        avatarStorageId: avatarStorageId,
      );
}

/// Folds [reactors] into one entry per person, the most recent reactor first.
List<MomentReactorGroup> groupReactors(Iterable<MomentReactor> reactors) {
  final byUser = <String, MomentReactorGroup>{};
  // Oldest first, so each person's emoji list ends newest first once reversed.
  final sorted = [...reactors]
    ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
  for (final r in sorted) {
    final g = byUser.putIfAbsent(
      r.userId,
      () => MomentReactorGroup(userId: r.userId, name: r.name),
    );
    // The richest identity any of their rows carries wins; an optimistic
    // row of the viewer's own has none.
    if (r.name.isNotEmpty) g.name = r.name;
    g.username = r.username ?? g.username;
    g.avatarStorageId = r.avatarStorageId ?? g.avatarStorageId;
    g.emojis
      ..remove(r.emoji)
      ..insert(0, r.emoji);
    final at = r.createdAt;
    if (at != null && at.isAfter(g.latest)) g.latest = at;
  }
  final out = byUser.values.toList()
    ..sort((a, b) => b.latest.compareTo(a.latest));
  return out;
}

/// The avatar row that says who reacted to a highlight, Instagram's way: up
/// to three faces overlapping, each wearing the emoji that person left last,
/// and a line naming the newest of them. A tap opens [showMomentReactions].
///
/// Drawn over the bottom of a photograph, so it is white on a shadow and the
/// faces are ringed in black to sit as cut-outs.
class MomentReactorStack extends StatelessWidget {
  const MomentReactorStack({
    super.key,
    required this.groups,
    required this.api,
    required this.viewerId,
    required this.onTap,
  });

  final List<MomentReactorGroup> groups;
  final ChatApi api;
  final String viewerId;
  final VoidCallback onTap;

  static const double _face = 30;
  static const double _overlap = 10;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final shown = groups.take(3).toList();
    final first = groups.first;
    final firstName = first.userId == viewerId
        ? sentenceCaseOf(context, l10n.reactionDetailsSheetYouBadge)
        : first.name;
    final label = groups.length == 1
        ? firstName
        : l10n.momentReactorsSummary(groups.length - 1, firstName);
    final width = _face + (shown.length - 1) * (_face - _overlap) + 6;
    // Read, not pressed (though it opens the list): plain faces and a line
    // of type on a shadow, no glass. Glass on the story is for controls.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: _face + 4,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Back to front, so the newest face sits on top at left.
                    for (var i = shown.length - 1; i >= 0; i--)
                      Positioned(
                        left: i * (_face - _overlap),
                        top: 0,
                        child: _BadgedFace(
                          group: shown[i],
                          api: api,
                          size: _face,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                    shadows: const [
                      Shadow(color: Color(0xCC000000), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A face ringed in black with the person's latest emoji pinned to its lower
/// right, the way Instagram marks a story reaction.
class _BadgedFace extends StatelessWidget {
  const _BadgedFace({
    required this.group,
    required this.api,
    required this.size,
  });

  final MomentReactorGroup group;
  final ChatApi api;
  final double size;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.56;
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: UserAvatar(
              user: group.asUser(),
              api: api,
              size: size - 3,
              showStatus: false,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badge,
              height: badge,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Text(
                group.emojis.first,
                style: TextStyle(
                  fontSize: badge * 0.62,
                  height: 1.1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Who reacted, as a list: face, name, @handle and every emoji they left, with
/// a capsule per emoji to narrow it down. The same filter capsules the chat's
/// reaction sheet uses, so the two read as one feature.
Future<void> showMomentReactions(
  BuildContext context, {
  required List<MomentReactor> reactors,
  required ChatApi api,
  required String viewerId,
  String? initialEmoji,

  /// Opens someone's profile; the sheet closes first. Null leaves the rows
  /// inert (and the viewer's own row is always inert).
  void Function(ChatUser user)? onOpenProfile,

  /// The reactors as they change while the sheet is open, in place of the
  /// [reactors] snapshot. Needed with [onToggle], or yours would never land.
  ValueListenable<List<MomentReactor>>? live,

  /// Adds or takes back the viewer's own reaction with that emoji, for the
  /// surfaces where a chip tap opens this sheet instead of toggling. Null
  /// hides the control.
  Future<void> Function(String emoji)? onToggle,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) {
      Widget sheet(List<MomentReactor> now) => _MomentReactionsSheet(
            reactors: now,
            api: api,
            viewerId: viewerId,
            initialEmoji: initialEmoji,
            onOpenProfile: onOpenProfile,
            onToggle: onToggle,
          );
      return live == null
          ? sheet(reactors)
          : ValueListenableBuilder<List<MomentReactor>>(
              valueListenable: live,
              builder: (_, now, _) => sheet(now),
            );
    },
  );
}

class _MomentReactionsSheet extends StatefulWidget {
  const _MomentReactionsSheet({
    required this.reactors,
    required this.api,
    required this.viewerId,
    required this.initialEmoji,
    required this.onOpenProfile,
    required this.onToggle,
  });

  final List<MomentReactor> reactors;
  final ChatApi api;
  final String viewerId;
  final String? initialEmoji;
  final void Function(ChatUser user)? onOpenProfile;
  final Future<void> Function(String emoji)? onToggle;

  @override
  State<_MomentReactionsSheet> createState() => _MomentReactionsSheetState();
}

class _MomentReactionsSheetState extends State<_MomentReactionsSheet>
    with ClosesWhenEmptied<_MomentReactionsSheet> {
  late String? _filter = widget.initialEmoji;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final reactors = heldUnlessEmptied(widget.reactors);
    final all = groupReactors(reactors);
    // Each emoji with how many people left it, most used first.
    final tally = <String, int>{};
    for (final r in reactors) {
      tally[r.emoji] = (tally[r.emoji] ?? 0) + 1;
    }
    final emojis = tally.keys.toList()
      ..sort((a, b) => tally[b]!.compareTo(tally[a]!));
    // Once the last one is taken back the list widens to ALL.
    final filter = tally.containsKey(_filter) ? _filter : null;
    final rows = filter == null
        ? all
        : [for (final g in all) if (g.emojis.contains(filter)) g];
    // What the control adds or takes back: the filter you're looking at, or
    // under ALL the chip you tapped. Only while someone still holds it.
    final wanted = _filter ?? widget.initialEmoji;
    final target = tally.containsKey(wanted) ? wanted : null;
    final onToggle = widget.onToggle;

    return SheetFrame(
      title: sentenceCaseOf(context, l10n.reactionDetailsSheetTitle),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HorizontalWheelScroll(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  FilterCapsule(
                    label: l10n.reactionDetailsSheetFilterAll,
                    count: all.length,
                    active: filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final e in emojis) ...[
                    const SizedBox(width: 6),
                    FilterCapsule(
                      label: e,
                      count: tally[e],
                      active: filter == e,
                      onTap: () => setState(() => _filter = e),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Flexible(
            // Bounded like the chat's reaction sheet: a long list scrolls
            // inside half the screen rather than pushing the sheet past it.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: SingleChildScrollView(
              child: SheetGroup(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    SheetRise(
                      index: i.clamp(0, 8),
                      child: _ReactorRow(
                        group: rows[i],
                        api: widget.api,
                        you: rows[i].userId == widget.viewerId,
                        highlight: filter,
                        onTap: widget.onOpenProfile == null ||
                                rows[i].userId == widget.viewerId
                            ? null
                            : () {
                                final user = rows[i].asUser();
                                Navigator.of(context).pop();
                                widget.onOpenProfile!(user);
                              },
                      ),
                    ),
                ],
              ),
            ),
            ),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                sentenceCaseOf(context, l10n.reactionDetailsSheetEmptyState),
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
            ),
          if (onToggle != null)
            ReactToggleSlot(
              emoji: target,
              mine: reactors.any(
                  (r) => r.emoji == target && r.userId == widget.viewerId),
              onTap: onToggle,
            ),
        ],
      ),
    );
  }
}

class _ReactorRow extends StatelessWidget {
  const _ReactorRow({
    required this.group,
    required this.api,
    required this.you,
    required this.highlight,
    required this.onTap,
  });

  final MomentReactorGroup group;
  final ChatApi api;
  final bool you;

  /// Opens their profile; null for the viewer's own row.
  final VoidCallback? onTap;

  /// The emoji the sheet is narrowed to, drawn first; null shows them all.
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final emojis = highlight == null
        ? group.emojis
        : [highlight!, ...group.emojis.where((e) => e != highlight)];
    final handle = group.username;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          UserAvatar(user: group.asUser(), api: api, size: 40, showStatus: false),
          const SizedBox(width: 12),
          // The name takes everything the emoji do not need: they are at
          // most five (the per-person cap), the name is the thing to read.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  you
                      ? sentenceCaseOf(context, l10n.reactionDetailsSheetYouBadge)
                      : group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(fontSize: 16, color: theme.ink),
                ),
                if (handle != null && handle.isNotEmpty)
                  Text(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.caption.copyWith(color: theme.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Every emoji they left, newest first; the filtered one leads.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in emojis)
                // Opacity, not a text colour: an emoji glyph ignores colour.
                Opacity(
                  opacity: highlight == null || e == highlight ? 1 : 0.4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      e,
                      style: const TextStyle(fontSize: 22, height: 1.2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return row;
    return FocusableTap(
      onTap: tap,
      semanticLabel: group.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: row,
      ),
    );
  }
}
