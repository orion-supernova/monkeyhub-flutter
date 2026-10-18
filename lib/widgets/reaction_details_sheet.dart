import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/message_reaction.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'filter_capsule.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import 'message_stamp.dart' show formatClockTime;
import 'user_avatar.dart';
import 'teardown_safe.dart';
import '../l10n/text_case.dart';
import 'desktop_scroll.dart';

/// Tap or long-press a reaction chip and this names the people behind it.
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

  /// Which of the message's two reaction sets to show when it heads an
  /// album: true the album's, false that photo's own. Null shows them all,
  /// which is every message that is not an album's first.
  bool? album,

  /// Adds or takes back the viewer's own reaction with that emoji. A chip tap
  /// opens this sheet instead of toggling, so this is where toggling lives.
  /// Null (no right to react) hides the control.
  Future<void> Function(String emoji)? onToggle,
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
      album: album,
      onToggle: onToggle,
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
    this.album,
    this.onToggle,
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

  /// See [showReactionDetailsSheet]'s `album`.
  final bool? album;

  /// See [showReactionDetailsSheet]'s `onToggle`.
  final Future<void> Function(String emoji)? onToggle;

  @override
  State<ReactionDetailsSheet> createState() => _ReactionDetailsSheetState();
}

class _ReactionDetailsSheetState extends State<ReactionDetailsSheet> {
  /// Selected filter; null means ALL.
  String? _emoji;

  /// The pill for [ReactionDetailsSheet.initialEmoji], so a message carrying
  /// more emoji than fit across the sheet still opens with the chip you
  /// long-pressed in view rather than somewhere off the right edge.
  final GlobalKey _initialPillKey = GlobalKey();
  bool _revealedInitialPill = false;

  @override
  void initState() {
    super.initState();
    _emoji = widget.initialEmoji;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealInitialPill());
  }

  /// Only ever the pill that opened the sheet, and only until it has been
  /// scrolled to. A [GlobalKey] that followed the *selected* pill would carry
  /// its element along on every tap, and the [AnimatedContainer] under it would
  /// arrive at the new pill already wearing the selected decoration — no
  /// crossfade on the way in, none on the way out of the old one either.
  Key? _pillKeyFor(String? emoji) =>
      _revealedInitialPill || emoji != widget.initialEmoji
          ? null
          : _initialPillKey;

  void _revealInitialPill() {
    if (_revealedInitialPill || !mounted) return;
    _revealedInitialPill = true;
    final pill = _initialPillKey.currentContext;
    // Absent whenever the pill row isn't rendered at all — a single-emoji
    // message, or one whose reactions were all taken back before we got here.
    if (pill == null) return;
    final theme = ThemeScope.of(context);
    Scrollable.ensureVisible(
      pill,
      alignment: 0.5,
      duration: theme.motionMed,
      curve: theme.motionCurve,
    );
  }

  /// Read through to the repository on every build rather than snapshotting, so
  /// a reaction that lands (or is taken back) while the sheet is open shows up.
  /// [ChatRepository] is a [ChangeNotifier] and reactions ride along with every
  /// message list query, so this costs one list scan per notification.
  List<MessageReaction> get _reactions {
    final all =
        widget.repo.findMessageInRoom(widget.roomId, widget.messageId)?.reactions ??
            widget.fallback;
    final album = widget.album;
    return album == null ? all : [for (final r in all) if (r.album == album) r];
  }

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
    final l10n = AppLocalizations.of(context);
    final reactions = _reactions;
    final groups = _groupsOf(reactions);
    // The filter survives everything except its own emoji being taken back by
    // the last person holding it.
    final selected = groups.any((g) => g.emoji == _emoji) ? _emoji : null;
    final people = reactions.map((r) => r.userId).toSet().length;

    final rows = (selected == null
        ? [...reactions]
        : [...groups.firstWhere((g) => g.emoji == selected).rows])
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // What the control adds or takes back: the filter you're looking at, or
    // under ALL the chip you tapped. Kept even once nobody holds it, so taking
    // back the last one can be undone from the same place.
    final target = selected ?? _emoji ?? widget.initialEmoji;
    final mine = reactions.any(
        (r) => r.emoji == target && r.userId == widget.currentUserId);
    final onToggle = widget.onToggle;

    return SheetFrame(
      title: sentenceCaseOf(context, l10n.reactionDetailsSheetTitle),
      // How many people, under the title — the bar's quiet line.
      subtitle: reactions.isEmpty
          ? null
          : l10n.reactionDetailsSheetPeopleCount(people),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reactions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
              child: EmptyState(
                icon: CupertinoIcons.smiley,
                title: l10n.reactionDetailsSheetEmptyState,
                compact: true,
              ),
            )
          else ...[
            const SizedBox(height: 6),
            // One emoji needs no filter — every row would be in every bucket.
            // It still gets a chip, because the chip is what was long-pressed
            // to get here and echoing it is what makes the sheet feel like it
            // belongs to that chip rather than to the message at large.
            if (groups.length == 1)
              _SoloSummary(group: groups.single)
            else
              HorizontalWheelScroll(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // Breathing room so FocusableTap's ring, which paints outside
                  // its child's bounds, isn't clipped by the scroll view. The
                  // horizontal 8 is also what lines the first pill's edge up
                  // with the avatars below it, which carry the same inset for
                  // their press highlight.
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    children: [
                      // THE filter chip — the chat list's facets and these are
                      // one control. The emoji rides as the label.
                      FilterCapsule(
                        key: _pillKeyFor(null),
                        label: l10n.reactionDetailsSheetFilterAll,
                        count: reactions.length,
                        active: selected == null,
                        onTap: () => _select(null),
                      ),
                      for (final g in groups) ...[
                        const SizedBox(width: 6),
                        FilterCapsule(
                          key: _pillKeyFor(g.emoji),
                          label: g.emoji,
                          count: g.rows.length,
                          active: selected == g.emoji,
                          onTap: () => _select(g.emoji),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              // [AnimatedSwitcher] stacks the outgoing list on the incoming
              // one, so the sheet stands at the taller of the two for the
              // length of the crossfade and then snaps. Filters routinely
              // halve the row count, which made that snap the most visible
              // thing about changing one. Anchored top so the rows that stay
              // don't drift upward as the sheet closes around them.
              child: AnimatedSize(
                duration: theme.motionFast,
                curve: theme.motionCurve,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: theme.motionFast,
                  switchInCurve: theme.motionEntrance,
                  child: ListView.builder(
                    key: ValueKey(selected ?? '*'),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      return _ReactorRow(
                        // Rebuilt from scratch when the filter changes, so the
                        // entrance animation replays for the incoming list.
                        key: ValueKey(
                            '${selected ?? '*'}/${r.userId}/${r.emoji}'),
                        index: i,
                        user: _userFor(r.userId),
                        api: widget.api,
                        time: formatClockTime(r.createdAt),
                        emoji: r.emoji,
                        isMe: r.userId == widget.currentUserId,
                        onOpenProfile: _openProfile,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          if (onToggle != null) ...[
            const SizedBox(height: 12),
            _ReactToggle(
              emoji: target,
              mine: mine,
              onTap: () => onToggle(target),
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

/// Emoji render at whatever the platform font decides, and several of them —
/// flags, ZWJ families — are taller than a Latin glyph at the same point size.
/// A fixed [height] and a centred box keep every one of them on the same
/// baseline instead of nudging its row taller than its neighbours.
class _Emoji extends StatelessWidget {
  const _Emoji(this.emoji, {super.key, required this.size});
  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        emoji,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, height: 1.15),
      );
}

/// The header chip for a message carrying exactly one emoji.
///
/// Reads as a statement rather than a control, because there is nothing to
/// filter: no border-as-affordance, no focus ring, not in the tab order.
class _SoloSummary extends StatelessWidget {
  const _SoloSummary({required this.group});
  final _Group group;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: Semantics(
        label: '${group.emoji} ${group.rows.length}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: quietFill(theme),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Emoji(group.emoji, size: 18),
              const SizedBox(width: 8),
              Text(
                '${group.rows.length}',
                style: _count(theme).copyWith(color: theme.accent),
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
///
/// What it adds here is the emoji, badged onto the avatar rather than parked at
/// the end of the row. On the avatar it survives the single-emoji case — where
/// there are no filter pills to carry it and the sheet used to name the emoji
/// precisely nowhere — and it reads as "this person, this reaction" instead of
/// as another column.
class _ReactorRow extends StatefulWidget {
  const _ReactorRow({
    super.key,
    required this.index,
    required this.user,
    required this.api,
    required this.time,
    required this.emoji,
    required this.isMe,
    required this.onOpenProfile,
  });

  final int index;
  final ChatUser user;
  final ChatApi api;
  final String time;
  final String emoji;
  final bool isMe;
  final void Function(ChatUser user) onOpenProfile;

  @override
  State<_ReactorRow> createState() => _ReactorRowState();
}

class _ReactorRowState extends State<_ReactorRow>
    with TeardownSafe<_ReactorRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Your own row goes nowhere: the profile behind it is the one you're
    // already signed into.
    final open = widget.isMe ? null : () => widget.onOpenProfile(widget.user);

    final row = Row(
      children: [
        _BadgedAvatar(
          user: widget.user,
          api: widget.api,
          emoji: widget.emoji,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.user.displayName,
                      style: groupedTitleStyle(theme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: quietFill(theme),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        sentenceCaseOf(
                          context,
                          AppLocalizations.of(context)
                              .reactionDetailsSheetYouBadge,
                        ),
                        style: groupedMetaStyle(theme).copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '@${widget.user.username}',
                style: groupedSubtitleStyle(theme),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          widget.time,
          style: _count(theme).copyWith(color: theme.inkMuted),
        ),
        // Nothing to open on your own row, so nothing points at one. The gap
        // is held either way so the times stay in a column.
        SizedBox(
          width: 18,
          child: open == null
              ? null
              : Icon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: theme.inkMuted.withValues(alpha: 0.7),
                ),
        ),
      ],
    );

    return _RowEntrance(
      index: widget.index,
      child: FocusableTap(
        onTap: open,
        radius: theme.radiusMd,
        semanticLabel:
            '${widget.user.displayName} ${widget.emoji} ${widget.time}',
        child: GestureDetector(
          onTap: open,
          onTapDown: open == null ? null : (_) => setState(() => _pressed = true),
          onTapUp: open == null ? null : (_) => setState(() => _pressed = false),
          onTapCancel: open == null ? null : () => setState(() => _pressed = false),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: theme.motionFast,
            curve: theme.motionCurve,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: _pressed ? theme.surfaceRaised : Colors.transparent,
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: row,
          ),
        ),
      ),
    );
  }
}

/// A short rise-and-fade as a list arrives, offset a little further per row.
///
/// Staggered by lengthening the duration rather than delaying the start, so
/// there is no frame where a row is laid out but invisible — and capped, so a
/// message with forty reactors doesn't have its last row still easing in
/// seconds after the sheet settled.
class _RowEntrance extends StatelessWidget {
  const _RowEntrance({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motionMed +
          Duration(milliseconds: 26 * (index > 6 ? 6 : index)),
      curve: theme.motionEntrance,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// The reactor's face with their emoji tucked into the corner of it.
class _BadgedAvatar extends StatelessWidget {
  const _BadgedAvatar({
    required this.user,
    required this.api,
    required this.emoji,
  });

  final ChatUser user;
  final ChatApi api;
  final String emoji;

  static const double _avatar = 40;
  static const double _badge = 20;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      // The badge hangs off the bottom-right corner; sizing the box to the
      // avatar alone would let the row's Flex clip it.
      width: _avatar + 4,
      height: _avatar + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(user: user, api: api, size: _avatar, showStatus: false),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: _badge,
              height: _badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // Raised rather than punched out of the sheet colour: one
                // theme paints its sheet translucent, and a hole cut in that
                // shape would show the transcript through the badge.
                color: theme.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: theme.divider, width: 0.8),
              ),
              child: _Emoji(emoji, size: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add or take back your own reaction with [emoji], under the list.
///
/// One capsule for both states, no accent fill: the glyph carries it. Off, a
/// line "+" and the label in accent invite you in; on, the "+" turns a
/// quarter and its crossbar folds away into a "−", and the ink dims. Adding
/// also bursts a ring of rays off the emoji and pops it; taking back sinks it.
/// The motion follows the reaction itself rather than the tap, so a refused
/// add (over the per-person cap) never celebrates.
class _ReactToggle extends StatefulWidget {
  const _ReactToggle({
    required this.emoji,
    required this.mine,
    required this.onTap,
  });

  final String emoji;
  final bool mine;
  final VoidCallback onTap;

  @override
  State<_ReactToggle> createState() => _ReactToggleState();
}

class _ReactToggleState extends State<_ReactToggle>
    with TickerProviderStateMixin {
  /// 1 yours, 0 not: the "+" to "−" fold and the ink.
  late final AnimationController _state = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.mine ? 1 : 0,
  );

  /// The one-off celebration when yours lands.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// The one-off sink when yours is taken back.
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MotionScope.of(context).calm;
  }

  @override
  void didUpdateWidget(_ReactToggle old) {
    super.didUpdateWidget(old);
    if (old.mine == widget.mine) return;
    // A filter change can flip [mine] too, and that is not something you
    // did: it switches state without a kick.
    if (_calm || old.emoji != widget.emoji) {
      _state.value = widget.mine ? 1 : 0;
      return;
    }
    _state.animateTo(widget.mine ? 1 : 0, curve: Curves.easeOutCubic);
    if (widget.mine) {
      HapticFeedback.lightImpact();
      _burst.forward(from: 0);
    } else {
      _drop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _state.dispose();
    _burst.dispose();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final label = widget.mine
        ? l10n.reactionDetailsSheetRemoveYours
        : l10n.reactionDetailsSheetAddYours;

    final emoji = AnimatedBuilder(
      animation: Listenable.merge([_burst, _drop]),
      child: AnimatedSwitcher(
        // A new filter swaps the emoji with a small pop rather than a cut.
        duration: motion.d(theme.motionFast),
        switchInCurve: motion.c(Curves.easeOutBack),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: _Emoji(widget.emoji,
            key: ValueKey(widget.emoji), size: 20),
      ),
      builder: (context, child) {
        final b = _burst.value;
        final d = _drop.value;
        final pop = b == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(b));
        final sink = d == 0 ? 0.0 : math.sin(math.pi * d);
        return Transform.translate(
          offset: Offset(0, 3 * sink - 2 * pop),
          child: Transform.rotate(
            angle: -0.18 * pop,
            child: Transform.scale(
              scale: 1 + 0.38 * pop - 0.14 * sink,
              child: child,
            ),
          ),
        );
      },
    );

    return SpringPress(
      onTap: widget.onTap,
      haptic: true,
      semanticLabel: '$label ${widget.emoji}',
      focusShape: FocusRingShape.capsule,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          final ink =
              Color.lerp(theme.accent, theme.inkSoft, _state.value)!;
          return Container(
            height: 48,
            decoration: BoxDecoration(
              color: quietFill(theme),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(14, 14),
                    painter: _PlusMinusPainter(ink: ink, state: _state),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CustomPaint(
                    // Over the emoji, so the rays read as thrown off it.
                    foregroundPainter: _BurstPainter(
                      color: theme.accent,
                      burst: _burst,
                    ),
                    child: Center(child: emoji),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSize(
                  duration: motion.d(theme.motionFast),
                  curve: theme.motionCurve,
                  child: AnimatedSwitcher(
                    duration: motion.d(theme.motionFast),
                    switchInCurve: motion.c(theme.motionEntrance),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.35),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      label,
                      key: ValueKey(widget.mine),
                      style: theme.bodyEmph.copyWith(color: ink),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A line "+" that becomes a "−". The whole glyph turns a quarter, which lays
/// its upright bar flat as the minus, while the crossbar shrinks to nothing
/// about its centre: one glyph folding, not two icons swapping.
class _PlusMinusPainter extends CustomPainter {
  _PlusMinusPainter({required this.ink, required this.state})
      : super(repaint: state);

  final Color ink;
  final Animation<double> state;

  @override
  void paint(Canvas canvas, Size size) {
    final t = state.value;
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2 - 1;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(t * math.pi / 2);
    canvas.drawLine(Offset(0, -half), Offset(0, half), stroke);
    final bar = half * (1 - t);
    if (bar > 0.2) {
      canvas.drawLine(Offset(-bar, 0), Offset(bar, 0), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlusMinusPainter old) => old.ink != ink;
}

/// Eight short line rays thrown off the emoji as yours lands, alternating
/// long and short, flying out and shrinking as they fade.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.color, required this.burst})
      : super(repaint: burst);

  final Color color;
  final Animation<double> burst;

  @override
  void paint(Canvas canvas, Size size) {
    final t = burst.value;
    if (t == 0 || t == 1) return;
    final e = Curves.easeOutCubic.transform(t);
    final c = size.center(Offset.zero);
    final stroke = Paint()
      ..color = color.withValues(alpha: color.a * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = math.pi / 8 + i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      final inner = 12 + 8 * e;
      final len = (i.isEven ? 6.0 : 3.5) * (1 - e);
      if (len < 0.3) continue;
      canvas.drawLine(c + dir * inner, c + dir * (inner + len), stroke);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}

/// Counts and clock times: the body face at caption size with tabular
/// figures, so a column of them lines up.
TextStyle _count(AppTheme theme) => theme.bodySoft.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
