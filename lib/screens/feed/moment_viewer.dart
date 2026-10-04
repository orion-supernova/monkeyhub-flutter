import 'dart:async';

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/media_aspect_cache.dart';
import '../../models/moment.dart';
import '../../theme/interaction.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/destructive_sheet.dart';
import '../../widgets/glass_buttons.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/moment_reactor_sheet.dart';
import '../../widgets/photo_backdrop.dart';
import '../../widgets/photo_dismiss_area.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/route_landing.dart';
import '../../widgets/photo_chrome.dart' show MediaPlayDisc;
import '../../widgets/sheet_kit.dart'
    show SheetBar, SheetCloseButton, SheetHandle, SheetTrashButton;

import '../../widgets/steady_hero.dart';
import '../fullscreen_video_viewer.dart';
import '../../widgets/ios_kit.dart' show quietFill, SpringPress;
import '../../widgets/reaction_picker_sheet.dart' show showReactionPicker;
import '../../l10n/text_case.dart';
import '../../widgets/liquid_glass.dart';

/// Reactions offered on a moment.
///
/// A fixed row rather than the full emoji picker used in chat. In a transcript
/// you are replying to a person; here you are reacting to a *thing that
/// happened*, and five one-tap options land the joke where a picker would
/// interrupt it. The set is tag-aware: piling onto a JINX is a different social
/// act from applauding a FATE — but 😮 is in every set, in the third place,
/// because "no way" fits everything that happens to anyone.
List<String> quickReactionsFor(MomentTag? tag) => switch (tag) {
  MomentTag.jinx => const ['😂', '💀', '😮', '🫵', '😭'],
  MomentTag.fate => const ['🤯', '😮', '👏', '🔮', '🙌'],
  MomentTag.luck => const ['🍀', '👏', '😮', '😤', '🤝'],
  MomentTag.calledIt => const ['🔮', '👏', '😮', '🙄', '😤'],
  MomentTag.npc => const ['😂', '🤖', '😮', '🫠', '💀'],
  null => const ['❤️', '😂', '😮', '🔥', '👏'],
};

/// Opens a moment.
///
/// **Two surfaces, chosen by what the moment actually is.** A highlight is a
/// photograph — the words under it are a caption, and everything else on screen
/// is in its way. It opens FULL-SCREEN, edge to edge, with the controls
/// floating over it on glass and the whole rest of the run swipeable sideways.
/// A point is a *sentence* — "washed the car, it rained at four" — with no
/// picture at all or a small one beside the joke, and blowing a line of text up
/// to fill a phone would be absurd. It opens as a card.
///
/// That split is the whole design. The previous version put both in the same
/// 460pt card with the photograph capped at half the screen height, which meant
/// the one thing people post highlights *for* was the one thing you could not
/// look at properly.
///
/// Two optional hints, and the caller gives whichever it has:
///
///  * [siblings] — the run this moment belongs to (the rail, a day in the
///    archive). Everything in it with a picture becomes a page you can swipe
///    to. Empty means "just this one", which is what a lone point is.
///  * [origin] — the screen rect of the row that was tapped, from
///    [tapOriginRect]. The card rises out of it. Meaningless full-screen, where
///    the picture itself flies from the thumbnail's [SteadyHero].
///
/// Neither is required. Callers no longer pass a hero tag: the tag is
/// [momentMediaHeroTag] of the moment's own id at BOTH ends, which is the only
/// value that could ever have matched, and asking every caller to say so again
/// was one more chance to get it wrong. With everything omitted the card simply
/// settles in place, and under Reduce Motion the route's duration collapses to
/// zero and none of it plays at all.
Future<void> showMomentViewer(
  BuildContext context, {
  required Moment moment,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
  List<Moment> siblings = const [],
  Rect? origin,
}) {
  if (moment.thumbStorageId != null) {
    // Only the ones with something to look at. A caption-only highlight sitting
    // in the middle of the rail is a legitimate page of *nothing* full-screen,
    // and swiping onto it reads as the gallery having broken.
    final pages = [
      for (final m in siblings)
        if (m.thumbStorageId != null) m,
    ];
    final index = pages.indexWhere((m) => m.id == moment.id);
    return _openStage(
      context,
      moments: index < 0 ? [moment] : pages,
      index: index < 0 ? 0 : index,
      api: api,
      feedApi: feedApi,
      userId: userId,
    );
  }
  return _openCard(
    context,
    moment: moment,
    api: api,
    feedApi: feedApi,
    userId: userId,
    origin: origin,
  );
}

/// The full-screen route.
///
/// Timings and flags match `MediaPagerScreen` deliberately: a photograph opened
/// from the Feed and a photograph opened from a chat are the same gesture on
/// the same kind of object, and two different-feeling flights for that would be
/// a difference nobody reports and everybody notices.
Future<void> _openStage(
  BuildContext context, {
  required List<Moment> moments,
  required int index,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      // Transparent rather than a colour: the scrim is painted inside so it can
      // fade with the dismiss drag, leaving the board visible while the picture
      // flies home. A real barrierColor would black out the return.
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (_, _, _) => _MomentStage(
        moments: moments,
        initialIndex: index,
        api: api,
        feedApi: feedApi,
        userId: userId,
      ),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

Future<void> _openCard(
  BuildContext context, {
  required Moment moment,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
  Rect? origin,
}) {
  final theme = ThemeScope.of(context);
  final motion = MotionScope.of(context);
  return Navigator.of(context).push(
    PageRouteBuilder(
      // Translucent so the board stays visible behind the scrim — the point
      // lifts off the row rather than replacing the screen.
      opaque: false,
      barrierColor: null,
      transitionDuration: motion.d(theme.motionMed),
      reverseTransitionDuration: motion.d(theme.motionMed),
      pageBuilder: (_, _, _) => _MomentCardViewer(
        moment: moment,
        api: api,
        feedApi: feedApi,
        userId: userId,
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

// ---------------------------------------------------------------------------
// Reactions
// ---------------------------------------------------------------------------

/// One reactor's identity, as the moment already carries it — no live lookup,
/// see `MomentReactor`.
class _ReactorEntry {
  const _ReactorEntry(this.userId, this.name);
  final String userId;
  final String name;
}

/// The optimistic local overlay on one moment's reaction state.
///
/// The board is live, so the truth arrives on its own within a round trip — but
/// a reaction that takes 200ms to appear feels broken, and this is the one
/// interaction where latency IS the experience.
///
/// Held per moment id rather than per screen, because the full-screen viewer
/// pages across a whole run and swiping back to a photo you reacted to must
/// show the reaction you added, not the state the board was in when the route
/// opened.
class _Reactions {
  _Reactions(Moment m)
      : mine = {...m.myReactions},
        counts = {...m.reactionCounts},
        reactors = _group(m.reactors);

  final Set<String> mine;
  final Map<String, int> counts;
  final Map<String, List<_ReactorEntry>> reactors;

  int get total => counts.values.fold(0, (a, b) => a + b);

  static Map<String, List<_ReactorEntry>> _group(List<MomentReactor> rs) {
    final out = <String, List<_ReactorEntry>>{};
    for (final r in rs) {
      out.putIfAbsent(r.emoji, () => []).add(_ReactorEntry(r.userId, r.name));
    }
    return out;
  }
}

/// Owns every moment's reaction state for one route, and the round trips that
/// change it.
///
/// A plain object rather than a mixin so both surfaces — the full-screen stage
/// and the card — share one implementation of an optimistic edit that has to
/// keep three collections in step and roll all three back together.
class _ReactionBook {
  _ReactionBook({
    required this.feedApi,
    required this.userId,
    required this.onChanged,
  });

  final FeedApi feedApi;
  final String userId;
  final VoidCallback onChanged;

  final _byMoment = <String, _Reactions>{};

  _Reactions of(Moment m) => _byMoment.putIfAbsent(m.id, () => _Reactions(m));

  /// Applies (or reverses) one local edit across all three collections
  /// together, so they never drift out of step.
  void _apply(_Reactions r, String emoji, bool reacted) {
    if (reacted) {
      r.mine.add(emoji);
      r.counts[emoji] = (r.counts[emoji] ?? 0) + 1;
      // Name left blank: the sheet substitutes the localized "you" for this
      // user's own id, same as the puzzle scoreboard and leaderboard do.
      r.reactors.putIfAbsent(emoji, () => []).add(_ReactorEntry(userId, ''));
    } else {
      r.mine.remove(emoji);
      final n = (r.counts[emoji] ?? 1) - 1;
      if (n <= 0) {
        r.counts.remove(emoji);
      } else {
        r.counts[emoji] = n;
      }
      r.reactors[emoji]?.removeWhere((e) => e.userId == userId);
    }
  }

  Future<void> toggle(Moment m, String emoji) async {
    final r = of(m);
    final had = r.mine.contains(emoji);
    _apply(r, emoji, !had);
    onChanged();
    // Haptic on the commitment, not on the animation — the house rule.
    HapticFeedback.selectionClick();
    try {
      if (had) {
        await feedApi.unreact(userId: userId, momentId: m.id, emoji: emoji);
      } else {
        await feedApi.react(userId: userId, momentId: m.id, emoji: emoji);
      }
    } catch (_) {
      // Roll the optimistic edit back rather than leaving a reaction that does
      // not exist on the server — the next board payload would silently
      // contradict it and the count would appear to flicker on its own.
      _apply(r, emoji, had);
      onChanged();
    }
  }

  /// The localized names behind one pill, or an empty list when nobody is
  /// recorded — which is not the same as nobody having reacted, see
  /// [Moment.reactors].
  List<String> namesFor(BuildContext context, Moment m, String emoji) {
    final l10n = AppLocalizations.of(context);
    return (of(m).reactors[emoji] ?? const <_ReactorEntry>[])
        .map((r) => r.userId == userId ? l10n.momentRailYouLabel : r.name)
        .toList();
  }
}

/// Reacts to [m] with any emoji from the full picker — the same sheet chat
/// uses. The quick row is four one-tap shortcuts; this is the way past them.
Future<void> _reactWithAny(
  BuildContext context,
  _ReactionBook book,
  Moment m,
) async {
  final emoji = await showReactionPicker(context);
  if (emoji == null || emoji.isEmpty) return;
  // Picking one you already sent would otherwise take it back, which is not
  // what choosing it from a picker means.
  if (book.of(m).mine.contains(emoji)) return;
  await book.toggle(m, emoji);
}

/// The last pill in a reaction row: a smiley-plus that opens the picker.
class _MoreReactionsPill extends StatelessWidget {
  const _MoreReactionsPill({required this.onTap, required this.overPhoto});
  final VoidCallback onTap;

  /// Glass over a photograph; the card's quiet pill otherwise.
  final bool overPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = AppLocalizations.of(context).stickerMakerMoreEmoji;
    // Sized to the emoji pills' content box, so every pill in the row is the
    // same height.
    final glyph = SizedBox(
      height: _kPillContent,
      child: Icon(
        CupertinoIcons.smiley,
        size: 17,
        color: overPhoto ? MediaGlass.ink : theme.inkSoft,
      ),
    );
    if (overPhoto) {
      return Semantics(
        button: true,
        label: label,
        child: LiquidGlass(
          tone: GlassTone.media,
          shape: LiquidGlassShape.capsule,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: glyph,
          ),
        ),
      );
    }
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: quietFill(theme),
          borderRadius: BorderRadius.circular(999),
        ),
        child: glyph,
      ),
    );
  }
}

/// The height of every reaction pill's content (emoji + count, or the
/// smiley), so the emoji pills and the add-reaction pill line up exactly.
const double _kPillContent = 20;

/// The emoji this surface offers for [m]: its tag's quick set, plus anything
/// anyone actually reacted with that is outside it.
///
/// The second half matters. A newer client can ship a different row, and a
/// moment's tag can change after the fact; dropping those would make somebody's
/// reaction vanish from under them.
List<String> _emojisFor(Moment m, _Reactions r) {
  final quick = quickReactionsFor(m.tag);
  return [...quick, ...r.counts.keys.where((k) => !quick.contains(k))];
}

// ---------------------------------------------------------------------------
// Full-screen stage — stories
// ---------------------------------------------------------------------------

/// How long a photograph stays up before the stories advance on their own.
///
/// Ten seconds, the Instagram/iOS rhythm: long enough to read a caption and
/// look at the picture, short enough that a run of a friend's day plays
/// through without a thumb.
const kStoryPhotoDuration = Duration(seconds: 10);

/// How long a finger has to stay down before it is a hold (pause) rather than
/// a tap (next/previous).
const _kStoryHold = Duration(milliseconds: 200);

/// How long an item must be on screen before it counts as seen — so a fast
/// tap-through does not clear rings on pictures nobody looked at.
const _kStorySeenAfter = Duration(seconds: 1);

/// The share of the width, from the leading edge, that a tap goes BACK in.
/// The rest goes forward — the stories convention, which favours the more
/// common direction with the bigger target.
const _kStoryBackZone = 0.30;

/// Starts a story's clock as soon as the page mounts, without waiting for
/// the picture to decode. Widget tests have no network, so a real photo
/// never "loads" there; nothing else should ever set this.
@visibleForTesting
bool debugStoryAssumeLoaded = false;

/// One person's moments in a stories run, in the order the run had them.
class _StoryRun {
  _StoryRun(this.userId, this.items);
  final String userId;
  final List<Moment> items;
}

/// Groups [moments] into one run per author, authors ordered by their first
/// appearance — so swiping sideways moves between PEOPLE and a tap moves
/// through one person's pictures, the shape every stories viewer has.
List<_StoryRun> _runsOf(List<Moment> moments) {
  final byAuthor = <String, _StoryRun>{};
  for (final m in moments) {
    byAuthor.putIfAbsent(m.userId, () => _StoryRun(m.userId, [])).items.add(m);
  }
  return byAuthor.values.toList();
}

/// Highlights, full-screen, as stories: one person per page, their pictures
/// played in turn with a progress bar across the top.
///
/// **Timing.** A photograph runs [kStoryPhotoDuration] and then moves on —
/// to the person's next picture, then the next person, then out. The clock
/// waits for the picture to decode, and stops whenever the picture is not
/// really being watched: a finger held down, a drag in either direction, a
/// zoom, a sheet over the viewer, the keyboard, the app in the background, or
/// a screen reader (which never auto-advances at all — it gets "Next" and
/// "Previous" actions instead). A video is a poster and a play disc: the app
/// never mounts an inline player, so a video item waits for its tap.
///
/// **Gestures.** Tap the leading 30% to go back, anywhere else to go forward;
/// hold to pause and clear the furniture off the picture; swipe sideways for
/// the next or previous person; drag down to put it away; pinch to zoom.
/// Double-tap zoom is gone here — it would collide with tap-next, and a
/// story is looked at, not inspected.
class _MomentStage extends StatefulWidget {
  const _MomentStage({
    required this.moments,
    required this.initialIndex,
    required this.api,
    required this.feedApi,
    required this.userId,
  });

  final List<Moment> moments;
  final int initialIndex;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  @override
  State<_MomentStage> createState() => _MomentStageState();
}

class _MomentStageState extends State<_MomentStage>
    with RouteLanding, SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final List<_StoryRun> _runs;
  late final PageController _pager;

  /// The person on screen, an index into [_runs].
  late int _run;

  /// Where each person's run is up to. A person you swipe back to resumes
  /// where you left them, which is what the stories apps do.
  final Map<int, int> _itemOf = {};

  late final _ReactionBook _book = _ReactionBook(
    feedApi: widget.feedApi,
    userId: widget.userId,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// The current photograph's clock, 0 → 1 over [kStoryPhotoDuration]. One
  /// controller for the whole stage; the progress bar repaints from it alone.
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: kStoryPhotoDuration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _next();
        });

  /// Live dismiss-drag offset, written by whichever page is under a finger and
  /// painted here. Shared across the pages on purpose — only one of them can be
  /// dragged at a time, and the thing that moves is the whole gallery.
  final ValueNotifier<Offset> _drag = ValueNotifier(Offset.zero);

  /// Whether the picture FILLS the screen or is shown whole inside it.
  ///
  /// On by default, which is the whole answer to "it's not really fullscreen".
  /// A phone-camera portrait shot on a tall phone letterboxes to about 60% of
  /// the display, and the 40% left over is exactly where this screen puts its
  /// chrome. Filling crops, so it is a preference and not a rule: the top bar
  /// carries a toggle whenever the current picture is actually losing
  /// something to it, and [photoFillsScreen] refuses to fill at all when what
  /// would survive is a slice rather than a photograph. Per route, not per
  /// page: a run that changed shape as it played would be worse than either.
  bool _fill = true;

  // ── Why the clock might be stopped. One getter, [_paused], reads them all.
  bool _holding = false;
  bool _paging = false;
  bool _dragging = false;
  bool _zoomed = false;
  bool _routeCurrent = true;
  bool _keyboard = false;
  bool _appActive = true;
  bool _screenReader = false;

  /// Whether the current item's picture has decoded — the clock does not
  /// start on a spinner.
  bool _ready = false;

  bool _closing = false;

  Timer? _seenTimer;
  Timer? _loadFallback;
  Timer? _afterVideo;

  /// Ids already reported, so paging back and forth does not fire the same
  /// mutation once per swipe.
  final _seenSent = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runs = _runsOf(widget.moments);
    final start = widget.moments[
        widget.initialIndex.clamp(0, widget.moments.length - 1)];
    _run = _runs.indexWhere((r) => r.userId == start.userId).clamp(0, _runs.length - 1);
    _itemOf[_run] =
        _runs[_run].items.indexWhere((m) => m.id == start.id).clamp(0, _runs[_run].items.length - 1);
    _pager = PageController(initialPage: _run);
    _drag.addListener(_onDrag);
    _arrive();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Each of these is an inherited dependency, so this runs again whenever
    // one of them changes: a sheet pushed over the viewer, the keyboard, a
    // screen reader switching on.
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    _screenReader = MediaQuery.accessibleNavigationOf(context);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _seenTimer?.cancel();
    _loadFallback?.cancel();
    _afterVideo?.cancel();
    _clock.dispose();
    _pager.dispose();
    _drag.removeListener(_onDrag);
    _drag.dispose();
    super.dispose();
  }

  int get _item => _itemOf[_run] ?? 0;
  Moment get _current => _runs[_run].items[_item];

  bool _isVideo(Moment m) => m.mediaKind == MomentMedia.video;

  bool get _paused =>
      _holding ||
      _paging ||
      _dragging ||
      _zoomed ||
      !_routeCurrent ||
      _keyboard ||
      !_appActive ||
      _screenReader ||
      _closing;

  /// Runs or stops the clock to match [_paused]. Cheap and idempotent — it
  /// is called from every place a reason can change.
  void _sync() {
    final run = _ready && !_isVideo(_current) && !_paused;
    if (run) {
      if (!_clock.isAnimating && _clock.value < 1) _clock.forward();
    } else if (_clock.isAnimating) {
      _clock.stop();
    }
  }

  void _onDrag() {
    final now = _drag.value != Offset.zero;
    if (now == _dragging) return;
    _dragging = now;
    _sync();
  }

  /// A new item is on screen: reset the clock, wait for its picture, and
  /// count it as seen once it has been looked at for a second.
  void _arrive() {
    _clock.value = 0;
    _ready = false;
    _seenTimer?.cancel();
    _loadFallback?.cancel();
    final m = _current;
    _seenTimer = Timer(_kStorySeenAfter, () => _markSeen(m));
    // A picture that never decodes (deleted since the board loaded, a dead
    // link) must not trap the run on a spinner: after a while it plays on.
    _loadFallback = Timer(const Duration(seconds: 8), () => _onReady(m.id));
    if (debugStoryAssumeLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onReady(m.id));
    }
  }

  /// The picture for [id] has decoded. Only the current item's counts.
  void _onReady(String id) {
    if (!mounted || id != _current.id || _ready) return;
    _loadFallback?.cancel();
    _ready = true;
    _sync();
  }

  void _markSeen(Moment m) {
    if (m.mine || m.seen || !_seenSent.add(m.id)) return;
    widget.feedApi
        .markSeen(userId: widget.userId, momentIds: [m.id])
        .catchError((_) {});
  }

  void _setItem(int item) {
    setState(() => _itemOf[_run] = item);
    _arrive();
  }

  /// Forward one item — into the next person at the end of a run, and out of
  /// the viewer at the end of the last one.
  void _next() {
    if (_closing) return;
    final items = _runs[_run].items;
    if (_item < items.length - 1) {
      _setItem(_item + 1);
      return;
    }
    if (_run < _runs.length - 1) {
      _toRun(_run + 1);
      return;
    }
    _close();
  }

  /// Back one item — into the previous person at the start of a run. At the
  /// very first item it restarts that item, the stories convention.
  void _previous() {
    if (_closing) return;
    if (_item > 0) {
      _setItem(_item - 1);
      return;
    }
    if (_run > 0) {
      _toRun(_run - 1);
      return;
    }
    _arrive();
    setState(() {});
  }

  void _toRun(int run) {
    if (MotionScope.of(context).calm) {
      _pager.jumpToPage(run);
    } else {
      _pager.animateToPage(
        run,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onPageChanged(int run) {
    setState(() {
      _run = run;
      // A zoomed page cannot be swiped away, so this should already be false
      // — but a stuck `true` would leave the run paused with nothing on
      // screen to explain why.
      _zoomed = false;
    });
    _arrive();
  }

  /// A tap on the picture, at [dx] across a page [width] wide.
  void _onTap(double dx, double width) {
    final m = _current;
    final at = width <= 0 ? 0.5 : dx / width;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final back = rtl ? at > 1 - _kStoryBackZone : at < _kStoryBackZone;
    if (back) {
      _previous();
      return;
    }
    // A video waits for its own tap: the middle plays it, the far edge skips.
    if (_isVideo(m) && m.mediaStorageId != null && (at - 0.5).abs() < 0.2) {
      _playVideo(m);
      return;
    }
    _next();
  }

  void _onHold(bool down) {
    if (down == _holding) return;
    if (down) HapticFeedback.selectionClick();
    setState(() => _holding = down);
    _sync();
  }

  /// Hands a clip to the OS player, exactly as a video tapped in a chat does
  /// — scrubbing, AirPlay, Picture-in-Picture all live there already. The run
  /// moves on a beat after the player closes.
  Future<void> _playVideo(Moment m) async {
    final id = m.mediaStorageId;
    if (id == null) return;
    await FullscreenVideoViewer.open(
      context,
      storageId: id,
      api: widget.api,
      posterStorageId: m.posterStorageId,
    );
    if (!mounted || _current.id != m.id) return;
    _afterVideo?.cancel();
    _afterVideo = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _current.id == m.id) _next();
    });
  }

  /// Guarded because a committed dismiss drag, the end of the last story and
  /// a tap on the close button can all land in the same frame.
  void _close() {
    if (_closing) return;
    _closing = true;
    _sync();
    Navigator.of(context).maybePop();
  }

  Future<void> _delete(Moment m) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final toast = AppToast.of(context);
    // Confirmed, because this is irreversible and the button sits over a
    // photograph you are tapping through with your thumb.
    final go = await showConfirmSheet(
      context,
      headline: l10n.momentViewerDeleteConfirmHeadline,
      body: l10n.momentViewerDeleteConfirmBody,
      confirmLabel: l10n.momentViewerDelete,
    );
    if (!go || !mounted) return;
    try {
      await widget.feedApi.remove(userId: widget.userId, momentId: m.id);
    } catch (_) {
      toast.show(l10n.momentViewerDeleteFailed, tone: ToastTone.danger);
      return;
    }
    navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    if (widget.moments.isEmpty) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context);
    final current = _current;
    final chrome = !_holding;

    return Material(
      type: MaterialType.transparency,
      // Every media `LiquidGlass` under here calls `BackdropFilter.grouped`,
      // which shares ONE full-screen rasterization with its siblings — but only
      // when a group is actually in scope. Without this the top-bar buttons
      // and the whole reaction rail each cost their own blur pass over a
      // fullscreen photograph, every frame.
      child: BackdropGroup(
        child: DefaultTextStyle(
          style: theme.body.copyWith(color: MediaGlass.ink),
          child: Semantics(
            // A screen reader never auto-advances; these are its way through.
            customSemanticsActions: {
              CustomSemanticsAction(label: l10n.momentStoryNext): _next,
              CustomSemanticsAction(label: l10n.momentStoryPrevious): _previous,
            },
            child: Stack(
              children: [
                // Painted inside the route rather than left to the barrier, so
                // it can fade to nothing as the drag commits — that is what
                // makes the Hero return read as the picture going back where
                // it came from rather than as a cut.
                ValueListenableBuilder<Offset>(
                  valueListenable: _drag,
                  builder: (context, drag, _) => Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 0.95 * (1 - photoDismissProgress(drag, screen)),
                        ),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<Offset>(
                  valueListenable: _drag,
                  builder: (context, drag, pages) {
                    final t = photoDismissProgress(drag, screen);
                    return Positioned.fill(
                      child: Transform.translate(
                        offset: drag,
                        child: Transform.scale(
                          scale: 1 - t * kPhotoDismissShrink,
                          child: pages,
                        ),
                      ),
                    );
                  },
                  // Built once and passed through the builder: the pages are
                  // the expensive part and none of them depend on the drag.
                  child: _pages(),
                ),
                // The progress bar stays through a hold — it is how you know
                // the picture is paused rather than gone.
                _FadingChrome(
                  drag: _drag,
                  visible: true,
                  child: RepaintBoundary(
                    child: _StoryProgress(
                      count: _runs[_run].items.length,
                      index: _item,
                      clock: _clock,
                      video: _isVideo(current),
                    ),
                  ),
                ),
                // The chrome is handed to `_FadingChrome` as a pre-built child
                // so a drag repaints one opacity rather than rebuilding a dozen
                // blurred glass surfaces sixty times a second.
                _FadingChrome(
                  drag: _drag,
                  visible: chrome,
                  child: _StageTopBar(
                    moment: current,
                    api: widget.api,
                    onClose: _close,
                    onDelete: current.mine ? () => _delete(current) : null,
                    // Offered only when it would change something: a landscape
                    // or square picture is shown whole either way.
                    onToggleFill: photoFillsScreen(
                          MediaAspectCache.instance.peek(
                            current.thumbStorageId ?? '',
                          ),
                          screen,
                        )
                        ? () => setState(() => _fill = !_fill)
                        : null,
                    filled: _fill,
                  ),
                ),
                _FadingChrome(
                  drag: _drag,
                  visible: chrome,
                  alignBottom: true,
                  child: _StageFooter(
                    moment: current,
                    reactions: _book.of(current),
                    onReact: (e) => _book.toggle(current, e),
                    onMore: () => _reactWithAny(context, _book, current),
                    onShowReactors: (e) => _showReactors(current, e),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pages() {
    return NotificationListener<ScrollNotification>(
      // A sideways drag between people pauses the clock until it settles.
      onNotification: (n) {
        if (n.depth != 0) return false;
        final paging = n is ScrollStartNotification
            ? n.dragDetails != null
            : n is ScrollEndNotification
            ? false
            : _paging;
        if (paging != _paging) {
          _paging = paging;
          _sync();
        }
        return false;
      },
      child: PageView.builder(
        controller: _pager,
        physics: _zoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: _runs.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (_, i) {
          final run = _runs[i];
          final m = run.items[(_itemOf[i] ?? 0).clamp(0, run.items.length - 1)];
          return HeroMode(
            // `Hero` collects every hero in both routes' trees, visible or
            // not, and a `PageView`'s neighbours carry the same tags their
            // rail cards do — so opening one photo would launch three flights.
            // This limits the flight to the picture on screen.
            enabled: i == _run,
            child: _StagePage(
              key: ValueKey(m.id),
              moment: m,
              api: widget.api,
              // Only the picture the flight opened on, while it flies.
              deferDecode: m.id == widget.moments[widget.initialIndex.clamp(0, widget.moments.length - 1)].id &&
                  !landed,
              fill: _fill,
              drag: _drag,
              onDismiss: _close,
              onTap: _onTap,
              onHold: _onHold,
              onReady: () => _onReady(m.id),
              onZoomChanged: (z) {
                if (i != _run || z == _zoomed) return;
                setState(() => _zoomed = z);
                _sync();
              },
            ),
          );
        },
      ),
    );
  }

  void _showReactors(Moment m, String emoji) {
    final names = _book.namesFor(context, m, emoji);
    if (names.isEmpty) return;
    HapticFeedback.mediumImpact();
    showMomentReactorSheet(context, emoji: emoji, names: names);
  }
}

/// One photograph, filling the screen: tap zones, hold, pinch, drag away.
class _StagePage extends StatefulWidget {
  const _StagePage({
    super.key,
    required this.moment,
    required this.api,
    required this.deferDecode,
    required this.fill,
    required this.drag,
    required this.onDismiss,
    required this.onTap,
    required this.onHold,
    required this.onReady,
    required this.onZoomChanged,
  });

  final Moment moment;
  final ChatApi api;

  /// Hold the full-resolution decode back while the opening flight is in the
  /// air — see [RemoteImage.decodeWidth].
  final bool deferDecode;

  /// The route's fill preference. Whether it is honoured for THIS picture is
  /// [photoFillsScreen]'s call — see `_MomentStageState._fill`.
  final bool fill;

  final ValueNotifier<Offset> drag;
  final VoidCallback onDismiss;

  /// A tap at x = the first argument on a page the second argument wide.
  final void Function(double dx, double width) onTap;

  /// The finger went down and stayed (true), or lifted (false).
  final ValueChanged<bool> onHold;

  /// The picture on screen has decoded — the story's clock may start.
  final VoidCallback onReady;
  final void Function(bool zoomed) onZoomChanged;

  @override
  State<_StagePage> createState() => _StagePageState();
}

class _StagePageState extends State<_StagePage>
    with SingleTickerProviderStateMixin {
  /// The picture's width÷height, when it is known before the picture is.
  ///
  /// **This is what stops the two-step jump.** A `contain` image that has not
  /// decoded yet measures as the whole screen — the rect a Hero flight is
  /// given as its destination — and snaps into its letterbox a frame later.
  /// Pinning the box to the ratio settles the flight where the decoded picture
  /// is going to be. [MediaAspectCache] usually already knows.
  double? _aspect;

  /// Pinch zoom. Double-tap zoom is deliberately absent: in a stories viewer a
  /// second tap is "next" again.
  final TransformationController _xform = TransformationController();
  bool _wasZoomed = false;

  /// Springs a released, uncommitted dismiss drag back home.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..addListener(_onSettle);
  Offset _settleFrom = Offset.zero;
  bool _dismissing = false;

  /// Fraction of screen height that commits a slow drag to a dismiss — the
  /// same as `PhotoDismissArea`, so the two viewers let go alike.
  static const _dismissFraction = 0.16;
  static const _dismissVelocity = 700.0;

  @override
  void initState() {
    super.initState();
    final id = widget.moment.thumbStorageId;
    if (id != null) _aspect = MediaAspectCache.instance.peek(id);
    _xform.addListener(_reportZoom);
  }

  @override
  void dispose() {
    _xform.removeListener(_reportZoom);
    _xform.dispose();
    _settle.dispose();
    super.dispose();
  }

  bool get _zoomed => _xform.value.getMaxScaleOnAxis() > 1.05;

  void _reportZoom() {
    final now = _zoomed;
    if (now == _wasZoomed) return;
    _wasZoomed = now;
    widget.onZoomChanged(now);
  }

  /// Fires once the displayed decode exists: [RemoteImage] reports the
  /// picture's ratio from the very decode it paints, which makes it the
  /// "loaded" signal as well.
  void _decoded(String id, double aspect) {
    MediaAspectCache.instance.remember(id, aspect);
    if (mounted && _aspect == null) setState(() => _aspect = aspect);
    widget.onReady();
  }

  void _onSettle() {
    widget.drag.value =
        _settleFrom * (1 - Curves.easeOutCubic.transform(_settle.value));
  }

  void _onDragStart(DragStartDetails _) => _settle.stop();

  void _onDragUpdate(DragUpdateDetails d) {
    // While zoomed the same gesture is panning the image.
    if (_zoomed || _dismissing) return;
    widget.drag.value += Offset(0, d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final dy = widget.drag.value.dy;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final threshold = MediaQuery.sizeOf(context).height * _dismissFraction;
    // Velocity has to agree with the direction of travel, or a fast *upward*
    // correction at the end of a downward drag would read as a dismiss.
    final flung = velocity.abs() > _dismissVelocity && velocity.sign == dy.sign;
    if (dy != 0 && (flung || dy.abs() > threshold)) {
      _dismissing = true;
      widget.onDismiss();
      return;
    }
    if (dy == 0) return;
    _settleFrom = widget.drag.value;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.moment.thumbStorageId;
    if (id == null) return const SizedBox.shrink();

    final video = widget.moment.mediaKind == MomentMedia.video;
    final playable = video && widget.moment.mediaStorageId != null;
    final fills =
        widget.fill && photoFillsScreen(_aspect, MediaQuery.sizeOf(context));

    final image = RemoteImage(
      storageId: id,
      api: widget.api,
      fit: BoxFit.contain,
      // The decode the rail is already holding, used as the arrival backdrop.
      placeholderDecodeWidth: momentThumbDecodeWidth,
      decodeWidth: widget.deferDecode ? momentThumbDecodeWidth : null,
      onAspectRatio: (a) => _decoded(id, a),
    );

    return LayoutBuilder(
      builder: (context, box) => Stack(
        fit: StackFit.expand,
        children: [
          // Only when the picture is NOT filling: behind a `cover` fit it is
          // invisible, and an invisible blurred layer still costs a pass.
          if (!fills)
            PhotoBackdrop(
              image: RemoteImage(
                storageId: id,
                api: widget.api,
                fit: BoxFit.cover,
                decodeWidth: momentThumbDecodeWidth,
                borderRadius: BorderRadius.zero,
              ),
            ),
          // The stories' own gesture set: `PhotoDismissArea` (the chat
          // gallery's) answers a tap with "toggle the chrome" and a double tap
          // with a zoom, and both of those are wrong here.
          RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    () => TapGestureRecognizer(),
                    (r) => r.onTapUp =
                        (d) => widget.onTap(d.localPosition.dx, box.maxWidth),
                  ),
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(duration: _kStoryHold),
                    (r) => r
                      ..onLongPressStart = ((_) => widget.onHold(true))
                      ..onLongPressEnd = ((_) => widget.onHold(false))
                      ..onLongPressCancel = () => widget.onHold(false),
                  ),
              VerticalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    VerticalDragGestureRecognizer
                  >(
                    () => VerticalDragGestureRecognizer(),
                    (r) => r
                      ..onStart = _onDragStart
                      ..onUpdate = _onDragUpdate
                      ..onEnd = _onDragEnd,
                  ),
            },
            child: Center(
              child: InteractiveViewer(
                transformationController: _xform,
                minScale: 1,
                // A poster is not a photograph to examine.
                maxScale: video ? 1 : 4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // `SteadyHero` rather than `Hero`: a plain one tears the
                    // child out of the tree at both ends of a flight.
                    SteadyHero(
                      tag: momentMediaHeroTag(widget.moment.id),
                      child: fills
                          ? SizedBox.expand(child: _fillImage(id))
                          : (_aspect == null
                                ? image
                                : AspectRatio(aspectRatio: _aspect!, child: image)),
                    ),
                    if (playable)
                      // Drawn only: the tap is the page's (the middle of a
                      // video plays it — see `_MomentStageState._onTap`).
                      const IgnorePointer(child: MediaPlayDisc(size: 64)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The picture at `cover`, for when it is filling the screen. A separate
  /// widget because the two fits want different decode hints.
  Widget _fillImage(String id) => RemoteImage(
    storageId: id,
    api: widget.api,
    fit: BoxFit.cover,
    borderRadius: BorderRadius.zero,
    placeholderDecodeWidth: momentThumbDecodeWidth,
    decodeWidth: widget.deferDecode ? momentThumbDecodeWidth : null,
    onAspectRatio: (a) => _decoded(id, a),
  );
}

/// Holds a piece of chrome against an edge of the screen and fades it with
/// the dismiss drag.
///
/// **Subscribes to the drag itself, and takes [child] pre-built.** The chrome
/// is a dozen blurred glass surfaces; rebuilding it from inside the drag's own
/// builder meant reconstructing all of them on every frame of a gesture.
///
/// [visible] (the hold) is a cut, not a fade: the chrome is glass, and a
/// glass surface is never animated — an opacity tween over a BackdropFilter
/// re-blurs the whole photograph every frame of it.
class _FadingChrome extends StatelessWidget {
  const _FadingChrome({
    required this.drag,
    required this.visible,
    required this.child,
    this.alignBottom = false,
  });

  final ValueNotifier<Offset> drag;

  /// False hides the chrome regardless of the drag (a held finger).
  final bool visible;

  final Widget child;
  final bool alignBottom;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Positioned(
      left: 0,
      right: 0,
      top: alignBottom ? null : 0,
      bottom: alignBottom ? 0 : null,
      child: Offstage(
        offstage: !visible,
        child: ValueListenableBuilder<Offset>(
          valueListenable: drag,
          builder: (context, value, child) {
            // The chrome leaves twice as fast as the picture does, so it is
            // gone before the photograph is halfway home.
            final t = photoDismissProgress(value, screen);
            final opacity = (1 - t * 2).clamp(0.0, 1.0);
            return IgnorePointer(
              ignoring: opacity < 0.05,
              child: opacity >= 1 ? child : Opacity(opacity: opacity, child: child),
            );
          },
          child: child,
        ),
      ),
    );
  }
}

/// The stories progress bar: one segment per picture in this person's run.
/// Seen ones full, the current one filling with the clock, the rest empty.
class _StoryProgress extends StatelessWidget {
  const _StoryProgress({
    required this.count,
    required this.index,
    required this.clock,
    required this.video,
  });

  final int count;
  final int index;
  final Animation<double> clock;

  /// A video does not run on the clock; its segment stays a plain track.
  final bool video;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          // White on white is not a colour scheme, and the top of a photograph
          // is as likely to be sky as anything else. Lighter than
          // `MediaScrim`, and spread over more of the frame, so it reads as a
          // vignette rather than a bar.
          Container(
            height: pad.top + 96,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C000000), Color(0x00000000)],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, pad.top + 8, 10, 0),
            child: SizedBox(
              height: 2.5,
              width: double.infinity,
              child: CustomPaint(
                painter: _StoryProgressPainter(
                  count: count,
                  index: index,
                  progress: video ? null : clock,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints every segment in one pass, repainting from [progress] alone — a
/// widget per segment would rebuild the row sixty times a second.
class _StoryProgressPainter extends CustomPainter {
  _StoryProgressPainter({
    required this.count,
    required this.index,
    required this.progress,
  }) : super(repaint: progress);

  final int count;
  final int index;
  final Animation<double>? progress;

  static const _gap = 4.0;
  static const _track = Color(0x59FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0) return;
    final w = (size.width - _gap * (count - 1)) / count;
    final r = Radius.circular(size.height / 2);
    final track = Paint()..color = _track;
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final shadow = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final p = progress?.value ?? 0;
    for (var i = 0; i < count; i++) {
      final x = i * (w + _gap);
      final seg = RRect.fromLTRBR(x, 0, x + w, size.height, r);
      // A soft shadow under each segment, for bright skies.
      canvas.drawRRect(seg.shift(const Offset(0, 0.5)), shadow);
      canvas.drawRRect(seg, track);
      final done = i < index ? 1.0 : (i == index ? p : 0.0);
      if (done <= 0) continue;
      canvas.save();
      canvas.clipRRect(seg);
      canvas.drawRect(Rect.fromLTWH(x, 0, w * done, size.height), fill);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StoryProgressPainter old) =>
      old.count != count || old.index != index || old.progress != progress;
}

/// Who posted it and when — and, on the trailing edge, the trash (yours
/// only), the fill toggle and the way out.
///
/// **The × is TRAILING here, deliberately** — the one exception to "× leads".
/// It is the stories convention (Instagram, iOS), and it leaves the leading
/// edge to the person, which is what a stories bar is about. Order, trailing:
/// trash, fill, ×; all 40pt media glass.
class _StageTopBar extends StatelessWidget {
  const _StageTopBar({
    required this.moment,
    required this.api,
    required this.onClose,
    required this.onDelete,
    required this.onToggleFill,
    required this.filled,
  });

  final Moment moment;
  final ChatApi api;
  final VoidCallback onClose;

  /// Null unless the moment is the viewer's own.
  final VoidCallback? onDelete;

  /// Switches between filling the screen and showing the whole frame. Null when
  /// this picture is shown whole either way — see `_MomentStageState._fill`.
  final VoidCallback? onToggleFill;

  /// Which of the two states the picture is in now, for the glyph.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final pad = MediaQuery.paddingOf(context);
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 6)];

    // 8 below the 2.5pt progress bar, which sits 8 below the safe area.
    return Padding(
      padding: EdgeInsets.fromLTRB(12, pad.top + 18, 10, 12),
      child: Row(
        children: [
          _AuthorDot(moment: moment, api: api),
          const SizedBox(width: 10),
          // Name and time take what the buttons leave, as one group — a
          // loose name beside a Spacer would split the free space with it
          // and strand the × short of the edge.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    moment.mine
                        ? sentenceCaseOf(context, l10n.momentRailYouLabel)
                        : moment.authorName,
                    style: theme.bodyEmph.copyWith(
                      fontSize: 17,
                      color: MediaGlass.ink,
                      // Over an arbitrary photograph a shadow is what keeps
                      // a name legible where the vignette has thinned out.
                      shadows: shadow,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _ago(l10n, moment.createdAt),
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    color: MediaGlass.inkDim,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: shadow,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onDelete != null) ...[
            GlassIconButton(
              tone: GlassTone.media,
              icon: CupertinoIcons.trash,
              semanticLabel: l10n.momentViewerDelete,
              onTap: onDelete,
              iconSize: 18,
            ),
            const SizedBox(width: 8),
          ],
          if (onToggleFill != null) ...[
            GlassIconButton(
              tone: GlassTone.media,
              // The glyph names what the tap DOES, not the current state: a
              // filled picture offers to shrink back to the whole frame.
              icon: filled
                  ? CupertinoIcons.arrow_down_right_arrow_up_left
                  : CupertinoIcons.arrow_up_left_arrow_down_right,
              semanticLabel: l10n.photoChromeFillToggleSemanticLabel,
              onTap: onToggleFill,
            ),
            const SizedBox(width: 8),
          ],
          GlassCloseButton(
            tone: GlassTone.media,
            semanticLabel: l10n.photoChromeCloseSemanticLabel,
            onTap: onClose,
          ),
        ],
      ),
    );
  }

  /// Compact relative time, matching the activity river's — everything on this
  /// board is from today, so it never needs a date.
  static String _ago(AppLocalizations l10n, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.momentActivityJustNow;
    if (d.inHours < 1) return l10n.momentActivityMinutesAgo(d.inMinutes);
    return l10n.momentActivityHoursAgo(d.inHours);
  }
}

/// The author's avatar as a small ringed circle, or their initial when there is
/// no picture.
///
/// Not [UserAvatar]: that takes a `ChatUser` and this board deliberately never
/// resolves one — the author projection rides denormalized on every moment
/// precisely so no Feed surface has to. It also paints in theme colours, which
/// is right on a themed surface and wrong on top of somebody's photograph.
class _AuthorDot extends StatelessWidget {
  const _AuthorDot({required this.moment, required this.api});

  final Moment moment;
  final ChatApi api;

  static const _size = 32.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final id = moment.authorAvatarStorageId;
    final initial = moment.authorName.isEmpty
        ? '?'
        : moment.authorName.characters.first.toUpperCase();

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: MediaGlass.stroke, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: id == null
          ? Text(
              initial,
              style: theme.bodyEmph.copyWith(
                color: MediaGlass.ink,
                fontSize: 13,
              ),
            )
          : RemoteImage(
              storageId: id,
              api: api,
              fit: BoxFit.cover,
              // A 30pt circle has no business decoding at the screen cap, which
              // is what `decodeSizeFor` falls back to with neither axis given.
              width: _size,
              height: _size,
              borderRadius: BorderRadius.zero,
            ),
    );
  }
}

/// The words and the reactions, on glass along the bottom edge.
class _StageFooter extends StatelessWidget {
  const _StageFooter({
    required this.moment,
    required this.reactions,
    required this.onReact,
    required this.onMore,
    required this.onShowReactors,
  });

  final Moment moment;
  final _Reactions reactions;
  final void Function(String emoji) onReact;
  final VoidCallback onMore;
  final void Function(String emoji) onShowReactors;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final caption = moment.caption;
    final emojis = _emojisFor(moment, reactions);

    // The gradient wraps the content rather than being a fixed-height band
    // behind it: this column is one line tall on a bare photograph and six with
    // a tag and a paragraph, and a 210pt scrim is either far too much furniture
    // for the first or leaves the top of the caption sitting on unscrimmed sky
    // in the second.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xD9000000), Color(0x00000000)],
        ),
      ),
      child: Padding(
        // Generous at the top so the fade has somewhere to happen before it
        // reaches the words.
        padding: EdgeInsets.fromLTRB(16, 56, 16, bottom + 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (moment.tag != null) ...[
              MomentTagChip(tag: moment.tag!),
              const SizedBox(height: 10),
            ],
            if (caption != null && caption.isNotEmpty) ...[
              Text(
                caption,
                style: theme.body.copyWith(
                  color: MediaGlass.ink,
                  shadows: const [
                    Shadow(color: Color(0x99000000), blurRadius: 8),
                  ],
                ),
                // Enough for a paragraph, capped so a wall of text cannot
                // swallow the photograph it is about.
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
            ],
            _GlassReactionRail(
              emojis: emojis,
              reactions: reactions,
              onTap: onReact,
              onLongPress: onShowReactors,
              onMore: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// The reaction row over a photograph.
///
/// Scrolls horizontally rather than wrapping: the quick set is five, but a
/// moment can carry any number of extras from other clients, and a second row
/// of pills growing upward would push the caption off a screen it shares.
class _GlassReactionRail extends StatelessWidget {
  const _GlassReactionRail({
    required this.emojis,
    required this.reactions,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  final List<String> emojis;
  final _Reactions reactions;
  final void Function(String emoji) onTap;
  final void Function(String emoji) onLongPress;

  /// Opens the full emoji picker: the quick set is a shortcut, not a limit.
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    // No grand total at the end of the row: an orphan number beside the pills
    // read as noise. Each pill carries its own count; a long-press says who.
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // Vertical room for FocusableTap's ring, which paints outside the
            // child's bounds and would otherwise be clipped by this scroller.
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (final e in emojis)
                  Padding(
                    key: ValueKey(e),
                    padding: const EdgeInsets.only(right: 8),
                    child: _GlassReactionPill(
                      emoji: e,
                      count: reactions.counts[e] ?? 0,
                      active: reactions.mine.contains(e),
                      accent: theme.accent,
                      accentInk: theme.accentInk,
                      onTap: () => onTap(e),
                      onLongPress: () => onLongPress(e),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MoreReactionsPill(onTap: onMore, overPhoto: true),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassReactionPill extends StatelessWidget {
  const _GlassReactionPill({
    required this.emoji,
    required this.count,
    required this.active,
    required this.accent,
    required this.accentInk,
    required this.onTap,
    required this.onLongPress,
  });

  final String emoji;
  final int count;
  final bool active;
  final Color accent;
  final Color accentInk;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
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
                () => LongPressGestureRecognizer(duration: kReactorsLongPress),
                (instance) => instance.onLongPress = onLongPress,
              ),
        },
        child: LiquidGlass(
          tone: GlassTone.media,
          shape: LiquidGlassShape.capsule,
          // Solid accent when it is yours, so a reaction you added is legible
          // as *yours* over any photograph — glass-on-glass is not.
          tint: active ? accent : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SizedBox(
              height: _kPillContent,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.1,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: TextStyle(
                      // accentInk on an accent fill, never white — NeonNight's
                      // accent is pure yellow and Graphite's is near-white.
                      color: active ? accentInk : MediaGlass.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      decoration: TextDecoration.none,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card viewer — points and caption-only moments
// ---------------------------------------------------------------------------

/// A point, opened.
///
/// Still a card, and deliberately so: a point is a sentence, and there is
/// nothing here that wants a whole screen. What it gets instead of size is
/// weight — the category, the line, who and when — and the same drag-away
/// gesture the stage has, so the two dismissals feel like one gesture.
class _MomentCardViewer extends StatefulWidget {
  const _MomentCardViewer({
    required this.moment,
    required this.api,
    required this.feedApi,
    required this.userId,
    this.origin,
  });

  final Moment moment;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  /// See [showMomentViewer].
  final Rect? origin;

  @override
  State<_MomentCardViewer> createState() => _MomentCardViewerState();
}

class _MomentCardViewerState extends State<_MomentCardViewer>
    with SingleTickerProviderStateMixin {
  late final _ReactionBook _book = _ReactionBook(
    feedApi: widget.feedApi,
    userId: widget.userId,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// Fraction of screen height that commits a slow drag to a dismiss.
  static const _dismissFraction = 0.16;

  /// A flick faster than this dismisses regardless of distance — the gesture
  /// people actually make is a short fast flick, not a long slow drag.
  static const _dismissVelocity = 700.0;

  /// How far the card shrinks at a full drag. Shallower than the full-screen
  /// stage's, because this thing is already a small card and 28% of it reads as
  /// the card falling away rather than being carried.
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
  /// It normally is not. When it *is*, the inner scroll view claims vertical
  /// drags and the card cannot be pulled away; the scrim still can be, and the
  /// close button is still there. Left as the rare fallback rather than fought
  /// over in the gesture arena, where the two would only ever half-work.
  bool _canScroll = false;

  @override
  void initState() {
    super.initState();
    // Fixed rather than read off the theme: this is the release of a gesture,
    // not decoration, and it matches the full-screen stage's settle so the two
    // dismissals feel like the same gesture.
    _settleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        final t = _settleTween;
        if (t != null) _drag.value = t.value;
      });
    if (!widget.moment.mine && !widget.moment.seen) {
      widget.feedApi
          .markSeen(userId: widget.userId, momentIds: [widget.moment.id])
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
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

  void _showReactors(String emoji) {
    final names = _book.namesFor(context, widget.moment, emoji);
    if (names.isEmpty) return;
    HapticFeedback.mediumImpact();
    showMomentReactorSheet(context, emoji: emoji, names: names);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final toast = AppToast.of(context);
    final go = await showConfirmSheet(
      context,
      headline: l10n.momentViewerDeleteConfirmHeadline,
      body: l10n.momentViewerDeleteConfirmBody,
      confirmLabel: l10n.momentViewerDelete,
    );
    if (!go || !mounted) return;
    try {
      await widget.feedApi.remove(
        userId: widget.userId,
        momentId: widget.moment.id,
      );
    } catch (_) {
      toast.show(l10n.momentViewerDeleteFailed, tone: ToastTone.danger);
      return;
    }
    navigator.maybePop();
  }

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
  /// Opacity always; movement out of the row that was tapped when there is one.
  /// Most of the way, not all of it: the card is a different shape from a
  /// one-line row, and travelling the exact distance reads as a slide from an
  /// arbitrary place rather than as the row opening up.
  Widget _entrance(double v, Widget card) {
    final faded = Opacity(opacity: v.clamp(0.0, 1.0), child: card);
    final origin = widget.origin;
    if (origin == null) {
      return Transform.scale(scale: 0.96 + 0.04 * v, child: faded);
    }
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
    final reactions = _book.of(m);

    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.only(bottom: 16),
      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The only thing on the card that says the card can be pulled away.
          // Decorative to a screen reader, which has the close button and the
          // route's own dismiss action already.
          const ExcludeSemantics(child: SheetHandle()),
          // The sheet bar every other card and sheet wears: the app's one ×
          // leading (the still chrome disc), who posted it centred, when
          // under it — and, on your own point, the trash trailing. One delete
          // pattern for everything of yours: a trash at the top-trailing
          // edge, then a confirm — the same as the photo viewer's.
          SheetBar(
            title: m.mine ? sentenceCaseOf(context, l10n.momentRailYouLabel) : m.authorName,
            subtitle: _StageTopBar._ago(l10n, m.createdAt),
            leading: SheetCloseButton(
              onTap: () => Navigator.of(context).maybePop(),
            ),
            trailing: m.mine
                ? SheetTrashButton(
                    onTap: _delete,
                    semanticLabel: l10n.momentViewerDelete,
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (m.tag != null) ...[
                  const SizedBox(height: 6),
                  MomentTagChip(tag: m.tag!),
                ],
                if (m.caption?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  // The line of text IS the point, so it gets the readable
                  // style and the room. Everything above it is metadata.
                  Text(m.caption!, style: theme.body),
                ],
                const SizedBox(height: 16),
                _CardReactionRow(
                  emojis: _emojisFor(m, reactions),
                  reactions: reactions,
                  onTap: (e) => _book.toggle(m, e),
                  onLongPress: _showReactors,
                  onMore: () => _reactWithAny(context, _book, m),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardReactionRow extends StatelessWidget {
  const _CardReactionRow({
    required this.emojis,
    required this.reactions,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  final List<String> emojis;
  final _Reactions reactions;
  final void Function(String emoji) onTap;

  /// Long-press a pill to see who's behind it.
  final void Function(String emoji) onLongPress;

  /// Opens the full emoji picker: the quick set is a shortcut, not a limit.
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // Vertical room for FocusableTap's ring, which paints outside the
            // child's bounds and would otherwise be clipped by this scroller.
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (final e in emojis)
                  Padding(
                    key: ValueKey(e),
                    padding: const EdgeInsets.only(right: 8),
                    child: _CardReactionPill(
                      emoji: e,
                      count: reactions.counts[e] ?? 0,
                      active: reactions.mine.contains(e),
                      onTap: () => onTap(e),
                      onLongPress: () => onLongPress(e),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _MoreReactionsPill(onTap: onMore, overPhoto: false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CardReactionPill extends StatelessWidget {
  const _CardReactionPill({
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
                () => LongPressGestureRecognizer(duration: kReactorsLongPress),
                (instance) => instance.onLongPress = onLongPress,
              ),
        },
        // No outline either way — the same flat capsule as the add-reaction
        // pill beside it; yours is the accent wash with an accent count. The
        // passive spring is the press feedback the custom recognizers above
        // cannot give on their own (a flat fill, so scaling it is cheap).
        child: SpringPress.passive(
          child: AnimatedContainer(
          duration: theme.motionFast,
          height: _kPillContent + 14,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: active
                ? theme.accent.withValues(alpha: 0.18)
                : quietFill(theme),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: theme.body.copyWith(fontSize: 15, height: 1.1)),
              if (count > 0) ...[
                const SizedBox(width: 5),
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
                    style: theme.bodySoft.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? theme.accent : theme.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
