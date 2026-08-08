import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/moment.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/glass_close_button.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/moment_reactor_sheet.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/steady_hero.dart';

/// Reactions offered on a moment.
///
/// A fixed row rather than the full emoji picker used in chat. In a transcript
/// you are replying to a person; here you are reacting to a *thing that
/// happened*, and four one-tap options land the joke where a picker would
/// interrupt it. The set is tag-aware: piling onto a JINX is a different social
/// act from applauding a FATE.
List<String> quickReactionsFor(MomentTag? tag) => switch (tag) {
  MomentTag.jinx => const ['😂', '💀', '🫵', '😭'],
  MomentTag.fate => const ['🤯', '👏', '😮', '🔮'],
  MomentTag.luck => const ['🍀', '👏', '😤', '🤝'],
  MomentTag.calledIt => const ['🔮', '👏', '🙄', '😤'],
  MomentTag.npc => const ['😂', '🤖', '🫠', '💀'],
  null => const ['❤️', '😂', '🔥', '👏'],
};

/// Opens a moment full-screen.
///
/// Two ways in, and the caller picks by what it has on screen to give:
///
///  * [heroTag] — the tag of the [SteadyHero] around the thumbnail that was
///    tapped, when there *is* one. The picture flies; the card materializes
///    around it and is left deliberately still, because a card that also moves
///    drags the flight's destination around underneath it.
///  * [origin] — the screen rect of a row with no picture in it, from
///    [tapOriginRect]. The card rises out of that rect instead.
///
/// Neither is required. With both omitted the card simply settles in place, and
/// under Reduce Motion the route's duration collapses to zero and none of this
/// plays at all.
Future<void> showMomentViewer(
  BuildContext context, {
  required Moment moment,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
  Object? heroTag,
  Rect? origin,
}) {
  final theme = ThemeScope.of(context);
  final motion = MotionScope.of(context);
  return Navigator.of(context).push(
    PageRouteBuilder(
      // Translucent so the board stays visible behind the scrim — the moment
      // lifts off the rail rather than replacing the screen.
      opaque: false,
      barrierColor: null,
      transitionDuration: motion.d(theme.motionMed),
      reverseTransitionDuration: motion.d(theme.motionMed),
      pageBuilder: (_, _, _) => _MomentViewer(
        moment: moment,
        api: api,
        feedApi: feedApi,
        userId: userId,
        heroTag: heroTag,
        origin: origin,
      ),
      // No transition here on purpose. The scrim, the card and the dismiss drag
      // all read the route's animation themselves — a page-wide FadeTransition
      // would fade the scrim and the card as one, and there is no drag offset it
      // could ever know about.
      transitionsBuilder: (_, _, _, child) => child,
    ),
  );
}

class _MomentViewer extends StatefulWidget {
  const _MomentViewer({
    required this.moment,
    required this.api,
    required this.feedApi,
    required this.userId,
    this.heroTag,
    this.origin,
  });

  final Moment moment;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  /// See [showMomentViewer].
  final Object? heroTag;
  final Rect? origin;

  @override
  State<_MomentViewer> createState() => _MomentViewerState();
}

class _MomentViewerState extends State<_MomentViewer>
    with SingleTickerProviderStateMixin {
  /// Optimistic local overlay on top of the subscription's reaction state.
  ///
  /// The board is live, so the truth arrives on its own within a round trip —
  /// but a reaction that takes 200ms to appear feels broken, and this is the
  /// one interaction where latency is the whole experience.
  late final Set<String> _mine = {...widget.moment.myReactions};
  late final Map<String, int> _counts = {...widget.moment.reactionCounts};

  /// Same optimistic-overlay reasoning as [_mine]/[_counts], for the names
  /// behind each count.
  late final Map<String, List<_ReactorEntry>> _reactors = _groupReactors(
    widget.moment.reactors,
  );

  static Map<String, List<_ReactorEntry>> _groupReactors(
    List<MomentReactor> reactors,
  ) {
    final out = <String, List<_ReactorEntry>>{};
    for (final r in reactors) {
      out.putIfAbsent(r.emoji, () => []).add(_ReactorEntry(r.userId, r.name));
    }
    return out;
  }

  /// Fraction of screen height that commits a slow drag to a dismiss.
  static const _dismissFraction = 0.16;

  /// A flick faster than this dismisses regardless of distance — the gesture
  /// people actually make is a short fast flick, not a long slow drag.
  static const _dismissVelocity = 700.0;

  /// How far the card shrinks at a full drag. Shallower than the fullscreen
  /// image viewer's, because this thing is already a small card and 28% of it
  /// reads as the card falling away rather than being carried.
  static const _dragShrink = 0.16;

  /// Fraction of screen height over which the drag takes the scrim all the way
  /// out. Shorter than the dismiss threshold is long, so the board underneath is
  /// already showing through by the time the gesture commits.
  static const _fadeSpan = 0.55;

  /// Live drag offset. A notifier rather than `setState` so a drag repaints one
  /// transform instead of rebuilding the whole route every frame.
  final ValueNotifier<double> _drag = ValueNotifier(0);

  /// Drives the spring back when a drag is released without committing.
  late final AnimationController _settleCtrl;
  Animation<double>? _settleTween;

  bool _dismissing = false;

  /// Whether the card is currently taller than the screen.
  ///
  /// It normally is not — the picture is capped at [_imageFraction] precisely so
  /// the whole card fits. When it *is*, the inner scroll view claims vertical
  /// drags and the card cannot be pulled away; the scrim still can be, and the
  /// close button is still there. Left as the rare fallback rather than fought
  /// over in the gesture arena, where the two would only ever half-work.
  bool _canScroll = false;

  /// True once the opening animation has finished.
  ///
  /// Until then the picture is painted from the thumbnail's decode, which is
  /// already resident, so the flight has nothing to wait for and nothing to
  /// compete with. Same reasoning as the fullscreen image viewer's.
  bool _landed = false;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    // Fixed rather than read off the theme: this is the release of a gesture,
    // not decoration, and it matches the fullscreen image viewer's settle so the
    // two dismissals feel like the same gesture.
    _settleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        final t = _settleTween;
        if (t != null) _drag.value = t.value;
      });
    // Clearing the unseen ring is a side effect of looking, so it fires on
    // open rather than on any deliberate action. Failure is silent: the ring
    // simply stays, which is a far better outcome than an error over a photo.
    if (!widget.moment.mine && !widget.moment.seen) {
      widget.feedApi
          .markSeen(userId: widget.userId, momentIds: [widget.moment.id])
          .catchError((_) {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _routeAnimation = animation;
    // No route animation to wait on, or already past it: nothing to defer.
    if (animation == null || animation.isCompleted) {
      _landed = true;
      return;
    }
    animation.addStatusListener(_handleRouteStatus);
  }

  void _handleRouteStatus(AnimationStatus status) {
    if (_landed || !status.isCompleted || !mounted) return;
    setState(() => _landed = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteStatus);
    _settleCtrl.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) => _settleCtrl.stop();

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    _drag.value += d.delta.dy;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final dy = _drag.value;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final threshold = MediaQuery.sizeOf(context).height * _dismissFraction;

    // Velocity has to agree with the direction of travel, or a fast *upward*
    // correction at the end of a downward drag would read as a dismiss.
    final flung = velocity.abs() > _dismissVelocity && velocity.sign == dy.sign;
    if (dy != 0 && (flung || dy.abs() > threshold)) {
      _dismissing = true;
      Navigator.of(context).maybePop();
      return;
    }
    _settleTween = Tween(begin: _drag.value, end: 0.0).animate(
      CurvedAnimation(parent: _settleCtrl, curve: Curves.easeOutCubic),
    );
    _settleCtrl
      ..value = 0
      ..forward();
  }

  /// 0 at rest, 1 once the drag has carried the card [_fadeSpan] of the way down
  /// the screen.
  double _progress(double drag, Size screen) =>
      (drag.abs() / (screen.height * _fadeSpan)).clamp(0.0, 1.0);

  /// Applies (or reverses) one local reaction edit across [_mine], [_counts]
  /// and [_reactors] together, so the three never drift out of step.
  void _applyLocal(String emoji, bool reacted) {
    if (reacted) {
      _mine.add(emoji);
      _counts[emoji] = (_counts[emoji] ?? 0) + 1;
      // Name left blank: the sheet substitutes the localized "you" for this
      // user's own id, same as the puzzle scoreboard and leaderboard do.
      _reactors
          .putIfAbsent(emoji, () => [])
          .add(_ReactorEntry(widget.userId, ''));
    } else {
      _mine.remove(emoji);
      final n = (_counts[emoji] ?? 1) - 1;
      if (n <= 0) {
        _counts.remove(emoji);
      } else {
        _counts[emoji] = n;
      }
      _reactors[emoji]?.removeWhere((r) => r.userId == widget.userId);
    }
  }

  Future<void> _toggle(String emoji) async {
    final had = _mine.contains(emoji);
    setState(() => _applyLocal(emoji, !had));
    // Haptic on the commitment, not on the animation — the house rule.
    HapticFeedback.selectionClick();
    try {
      if (had) {
        await widget.feedApi.unreact(
          userId: widget.userId,
          momentId: widget.moment.id,
          emoji: emoji,
        );
      } else {
        await widget.feedApi.react(
          userId: widget.userId,
          momentId: widget.moment.id,
          emoji: emoji,
        );
      }
    } catch (_) {
      // Roll the optimistic edit back rather than leaving a reaction that does
      // not exist on the server — the next board payload would silently
      // contradict it and the count would appear to flicker on its own.
      if (!mounted) return;
      setState(() => _applyLocal(emoji, had));
    }
  }

  void _showReactors(BuildContext context, String emoji) {
    final l10n = AppLocalizations.of(context);
    final names = (_reactors[emoji] ?? const <_ReactorEntry>[])
        .map(
          (r) =>
              r.userId == widget.userId ? l10n.momentRailYouLabel : r.name,
        )
        .toList();
    if (names.isEmpty) return;
    HapticFeedback.mediumImpact();
    showMomentReactorSheet(context, emoji: emoji, names: names);
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    try {
      await widget.feedApi.remove(
        userId: widget.userId,
        momentId: widget.moment.id,
      );
    } catch (_) {
      /* the row is either gone or it isn't; the board will say which */
    }
    if (mounted) navigator.maybePop();
  }

  /// How much of the screen's height the picture may take.
  ///
  /// The cap is what keeps the whole card on screen, and that is not a cosmetic
  /// preference: a card taller than the viewport has to scroll, and a scroll
  /// view claims every vertical drag over it — which would silently kill the
  /// dismiss gesture on exactly the tall portrait photos people post most.
  static const _imageFraction = 0.52;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final screen = MediaQuery.sizeOf(context);
    final anim = ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final curve = motion.c(theme.motionEntrance);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        // Two independent sources of movement: the route opening or closing,
        // and the finger. Merged rather than nested so the card's transform is
        // composed once per frame from both.
        animation: Listenable.merge([anim, _drag]),
        builder: (context, child) {
          final t = _progress(_drag.value, screen);
          final entered = curve.transform(anim.value.clamp(0.0, 1.0));
          return Stack(
            children: [
              // A tap anywhere off the card dismisses, and a drag anywhere off
              // it pulls the card away — reaching the card is the whole problem
              // this gesture exists to solve. Behind the card in the stack so it
              // never steals the reaction row's taps.
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  onVerticalDragStart: _onDragStart,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  behavior: HitTestBehavior.opaque,
                  child: ColoredBox(
                    color: theme.background.withValues(
                      alpha: 0.92 * entered * (1 - t),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(0, _drag.value),
                    child: Transform.scale(
                      scale: 1 - t * _dragShrink,
                      child: _entrance(entered, child!),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        // Built once and passed through the builder: none of the card depends on
        // the drag offset or the route's animation.
        child: GestureDetector(
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: _onMetrics,
            child: SingleChildScrollView(
              // Inert until the card genuinely overflows, so the drag-to-dismiss
              // gesture reaches this widget instead of being swallowed by a
              // scroll view with nowhere to scroll. See [_canScroll].
              physics: _canScroll
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: _card(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Latches whether the card overflows its viewport, one frame after layout
  /// says so. Deferred because this notification arrives mid-layout, where a
  /// `setState` is illegal.
  bool _onMetrics(ScrollMetricsNotification n) {
    final can = n.metrics.maxScrollExtent > 0;
    if (can == _canScroll) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && can != _canScroll) setState(() => _canScroll = can);
    });
    return false;
  }

  /// How the card arrives.
  ///
  /// Opacity in every case; movement only when nothing else is already moving.
  /// A picture in flight lands on this card's own image, and Flutter measures
  /// that destination through whatever transforms sit above it — so a card that
  /// scales or slides while a hero is in the air is a card that drags the
  /// landing site around, and the photo arrives somewhere the photo is not.
  Widget _entrance(double v, Widget card) {
    final faded = Opacity(opacity: v.clamp(0.0, 1.0), child: card);
    if (widget.heroTag != null) return faded;

    final origin = widget.origin;
    if (origin == null) {
      return Transform.scale(scale: 0.96 + 0.04 * v, child: faded);
    }
    // Rise out of the row that was tapped. Most of the way, not all of it: the
    // card is a different shape from a one-line row, and travelling the exact
    // distance reads as a slide from an arbitrary place rather than as the row
    // opening up.
    final screen = MediaQuery.sizeOf(context);
    final away = 1 - v;
    return Transform.translate(
      offset: Offset(
        (origin.center.dx - screen.width / 2) * away * 0.7,
        (origin.center.dy - screen.height / 2) * away * 0.7,
      ),
      child: Transform.scale(scale: 0.88 + 0.12 * v, child: faded),
    );
  }

  Widget _card(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = widget.moment;
    final storageId = m.thumbStorageId;

    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(14),
      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The only thing on the card that says the card can be pulled away.
          // Decorative to a screen reader, which has the close button and the
          // route's own dismiss action already.
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 34,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: theme.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  m.mine ? l10n.momentRailYouLabel : m.authorName,
                  style: theme.displaySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (m.tag != null) ...[
                MomentTagChip(tag: m.tag!),
                const SizedBox(width: 8),
              ],
              // Pinned to the card rather than floating in the outer Stack: the
              // card is vertically centred and its height follows the photo, so
              // a fixed top-right Positioned would sometimes land on the image
              // and sometimes in empty space. Kept now that the card can be
              // swiped away, because a gesture is not an affordance — this is
              // still the only *visible* way out.
              GlassCloseButton(
                onTap: () => Navigator.of(context).maybePop(),
                semanticLabel: l10n.photoChromeCloseSemanticLabel,
                size: 34,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (storageId != null) _image(context, storageId),
          if (m.caption?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(m.caption!, style: theme.body),
          ],
          const SizedBox(height: 14),
          _ReactionRow(
            emojis: quickReactionsFor(m.tag),
            counts: _counts,
            mine: _mine,
            onTap: _toggle,
            onLongPress: (e) => _showReactors(context, e),
          ),
          if (m.mine) ...[
            const SizedBox(height: 12),
            FocusableTap(
              onTap: _delete,
              semanticLabel: l10n.momentViewerDelete,
              radius: theme.radiusMd,
              child: GestureDetector(
                onTap: _delete,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 14, color: theme.danger),
                    const SizedBox(width: 6),
                    Text(
                      l10n.momentViewerDelete,
                      style: theme.monoTiny.copyWith(color: theme.danger),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The decode to paint right now: the thumbnail's while the picture is still
  /// flying, and the full one once it has landed. Null all the way through when
  /// there was no thumbnail to defer to.
  int? get _deferredDecodeWidth =>
      _landed || widget.heroTag == null ? null : momentThumbDecodeWidth;

  Widget _image(BuildContext context, String storageId) {
    final theme = ThemeScope.of(context);
    final screen = MediaQuery.sizeOf(context);
    final image = RemoteImage(
      storageId: storageId,
      api: widget.api,
      fit: BoxFit.contain,
      // The decode the rail is already holding, used as the arrival backdrop —
      // without it the flight lands on a shimmer even though the bytes are local
      // and the picture was on screen a moment ago.
      placeholderDecodeWidth:
          widget.heroTag == null ? null : momentThumbDecodeWidth,
      decodeWidth: _deferredDecodeWidth,
    );
    // Capped, and centred inside the cap — a portrait photo at card width is
    // taller than the phone. See [_imageFraction].
    final box = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screen.height * _imageFraction),
      child: image,
    );
    final tag = widget.heroTag;
    if (tag == null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          child: box,
        ),
      );
    }
    return Center(
      child: SteadyHero(
        tag: tag,
        // `cover`, never `contain`, for the length of the flight. The thumbnail
        // crops to fill its square and this end shows the whole frame, so the
        // two disagree about the crop; a `contain` shuttle letterboxes the
        // picture inside the small end and then snaps to the thumbnail's fill on
        // touchdown. At this end the box already has the picture's own ratio,
        // where `cover` and `contain` are the same thing — so `cover` animates
        // the crop instead of cutting it.
        flightShuttleBuilder: (_, _, _, _, _) => RemoteImage(
          storageId: storageId,
          api: widget.api,
          fit: BoxFit.cover,
          placeholderDecodeWidth: momentThumbDecodeWidth,
          decodeWidth: _deferredDecodeWidth,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusMd),
          child: box,
        ),
      ),
    );
  }
}

/// One reactor's identity, as the moment already carries it — no live lookup,
/// see `MomentReactor`.
class _ReactorEntry {
  const _ReactorEntry(this.userId, this.name);
  final String userId;
  final String name;
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.emojis,
    required this.counts,
    required this.mine,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> emojis;
  final Map<String, int> counts;
  final Set<String> mine;
  final void Function(String emoji) onTap;

  /// Long-press a pill to see who's behind it.
  final void Function(String emoji) onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        for (final e in emojis)
          Padding(
            key: ValueKey(e),
            padding: const EdgeInsets.only(right: 8),
            child: _ReactionPill(
              emoji: e,
              count: counts[e] ?? 0,
              active: mine.contains(e),
              onTap: () => onTap(e),
              onLongPress: () => onLongPress(e),
            ),
          ),
        // Reactions anyone added that are outside this moment's quick set —
        // possible when a newer client ships a different row, or when the tag
        // changed. Dropping them would make someone's reaction vanish.
        for (final e in counts.keys.where((k) => !emojis.contains(k)))
          Padding(
            key: ValueKey('extra_$e'),
            padding: const EdgeInsets.only(right: 8),
            child: _ReactionPill(
              emoji: e,
              count: counts[e] ?? 0,
              active: mine.contains(e),
              onTap: () => onTap(e),
              onLongPress: () => onLongPress(e),
            ),
          ),
        const Spacer(),
        Text(
          '${counts.values.fold(0, (a, b) => a + b)}',
          style: theme.monoTiny,
        ),
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final String emoji;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: emoji,
      selected: active,
      shape: FocusRingShape.capsule,
      child: RawGestureDetector(
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (instance) => instance
                  ..onTap = onTap
                  // Desktop/trackpad right-click reaches the same sheet, same
                  // as the chat reaction chip's own long-press stand-in.
                  ..onSecondaryTap = onLongPress,
              ),
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                  duration: const Duration(milliseconds: 200),
                ),
                (instance) => instance.onLongPress = onLongPress,
              ),
        },
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? theme.accentSoft : theme.surfaceSunken,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? theme.accent : theme.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: theme.monoTiny.copyWith(fontSize: 13)),
              if (count > 0) ...[
                const SizedBox(width: 4),
                // AnimatedSwitcher keyed on the value so the number rolls
                // rather than swapping — the board's odometer idiom in
                // miniature.
                AnimatedSwitcher(
                  duration: theme.motionFast,
                  switchInCurve: theme.motionEntrance,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => ClipRect(
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$count',
                    key: ValueKey(count),
                    style: theme.monoTiny,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
