import 'package:flutter/gestures.dart';
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
import '../../widgets/glass_close_button.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/moment_reactor_sheet.dart';
import '../../widgets/photo_backdrop.dart';
import '../../widgets/photo_chrome.dart';
import '../../widgets/photo_dismiss_area.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/route_landing.dart';
import '../../widgets/steady_hero.dart';
import '../fullscreen_video_viewer.dart';

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
// Full-screen stage
// ---------------------------------------------------------------------------

/// A highlight, full-screen, with the rest of the run one swipe away.
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

class _MomentStageState extends State<_MomentStage> with RouteLanding {
  late final PageController _pager;
  late int _index;
  late final _ReactionBook _book = _ReactionBook(
    feedApi: widget.feedApi,
    userId: widget.userId,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// Live dismiss-drag offset, written by whichever page is under a finger and
  /// painted here. Shared across the pages on purpose — only one of them can be
  /// dragged at a time, and the thing that moves is the whole gallery.
  final ValueNotifier<Offset> _drag = ValueNotifier(Offset.zero);

  /// Whether the chrome is showing. A tap on the picture toggles it: this
  /// screen's entire content is a photograph, and the furniture over it should
  /// get out of the way for the same reason a gallery's does everywhere else.
  bool _chrome = true;

  /// Whether the picture FILLS the screen or is shown whole inside it.
  ///
  /// On by default, which is the whole answer to "it's not really fullscreen".
  /// A phone-camera portrait shot on a tall phone letterboxes to about 60% of
  /// the display, and the 40% left over is exactly where this screen puts its
  /// chrome — so the close button and the author's name ended up on two black
  /// bands with a photograph wedged between them.
  ///
  /// Filling crops, so it is a preference and not a rule: the top bar carries a
  /// toggle whenever the current picture is actually losing something to it,
  /// and [photoFillsScreen] refuses to fill at all when what would survive is a
  /// slice rather than a photograph. The preference is per route, not per page,
  /// because a gallery that changed shape as you swiped would be worse than
  /// either setting.
  bool _fill = true;

  /// True while the current page is pinch- or double-tap-zoomed. The `PageView`
  /// stops scrolling for the duration, or a sideways drag meant to move around
  /// inside one photograph would flick to the next one instead.
  bool _zoomed = false;

  bool _closing = false;

  /// Ids already reported, so paging back and forth does not fire the same
  /// mutation once per swipe.
  final _seenSent = <String>{};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.moments.length - 1);
    _pager = PageController(initialPage: _index);
    _markSeen(widget.moments[_index]);
  }

  @override
  void dispose() {
    _pager.dispose();
    _drag.dispose();
    super.dispose();
  }

  Moment get _current => widget.moments[_index];

  /// Clearing the unseen ring is a side effect of *looking*, so it fires on
  /// arrival rather than on any deliberate action — including on arrival by
  /// swipe, which is just as much looking as opening was. Failure is silent:
  /// the ring simply stays, which is a far better outcome than an error over a
  /// photo.
  void _markSeen(Moment m) {
    if (m.mine || m.seen || !_seenSent.add(m.id)) return;
    widget.feedApi
        .markSeen(userId: widget.userId, momentIds: [m.id])
        .catchError((_) {});
  }

  /// Guarded because a committed dismiss drag and a tap on the close button can
  /// land in the same frame.
  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _delete(Moment m) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final toast = AppToast.of(context);
    // Confirmed, because this is irreversible and the button is 38pt of glass
    // sitting over a photograph you are dragging around with your thumb. The
    // previous version deleted on the first tap.
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
    if (widget.moments.isEmpty) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context);
    final many = widget.moments.length > 1;

    return Material(
      type: MaterialType.transparency,
      // Every `PhotoGlassSurface` under here calls `BackdropFilter.grouped`,
      // which shares ONE full-screen rasterization with its siblings — but only
      // when a group is actually in scope. Without this the two top-bar buttons
      // and the whole reaction rail each cost their own blur pass over a
      // fullscreen photograph, every frame, which is precisely the stutter you
      // feel while the picture is still flying in.
      child: BackdropGroup(
        child: DefaultTextStyle(
          style: theme.body.copyWith(color: PhotoChrome.ink),
          child: Stack(
            children: [
              // Painted inside the route rather than left to the barrier, so it
              // can fade to nothing as the drag commits — that is what makes
              // the Hero return read as the picture going back where it came
              // from rather than as a cut.
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
                // Built once and passed through the builder: the pages are the
                // expensive part and none of them depend on the drag offset.
                child: _pages(),
              ),
              // The chrome is handed to `_FadingChrome` as a pre-built child so
              // a drag repaints one opacity rather than rebuilding a dozen
              // blurred glass surfaces sixty times a second. It was inside the
              // drag builder, and that is the other half of the stutter.
              _FadingChrome(
                drag: _drag,
                visible: _chrome,
                child: _StageTopBar(
                  moment: _current,
                  api: widget.api,
                  position: many
                      ? AppLocalizations.of(context)
                            .photoChromeMediaPositionLabel(
                              _index + 1,
                              widget.moments.length,
                            )
                      : null,
                  onClose: _close,
                  onDelete: _current.mine ? () => _delete(_current) : null,
                  // Offered only when it would change something: a landscape or
                  // square picture is shown whole either way, and a button that
                  // does nothing is worse than no button.
                  onToggleFill: photoFillsScreen(
                        MediaAspectCache.instance.peek(
                          _current.thumbStorageId ?? '',
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
                visible: _chrome,
                alignBottom: true,
                child: _StageFooter(
                  moment: _current,
                  reactions: _book.of(_current),
                  onReact: (e) => _book.toggle(_current, e),
                  onShowReactors: (e) => _showReactors(_current, e),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pages() {
    return PageView.builder(
      controller: _pager,
      physics: _zoomed
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemCount: widget.moments.length,
      onPageChanged: (i) {
        setState(() {
          _index = i;
          // Belt and braces. A zoomed page cannot be swiped away, so this
          // should already be false — but a stuck `true` would leave the
          // gallery unswipeable with nothing on screen to explain why.
          _zoomed = false;
        });
        _markSeen(widget.moments[i]);
      },
      itemBuilder: (_, i) => HeroMode(
        // `Hero` collects every hero in both routes' trees, visible or not, and
        // a `PageView`'s neighbours are built with the same tags their rail
        // cards carry — so opening one photo would launch three flights, two of
        // them dragging thumbnails off the side of the screen. This limits the
        // flight to the picture that was actually tapped.
        enabled: i == _index,
        child: _StagePage(
          moment: widget.moments[i],
          api: widget.api,
          // Only the page the flight opened on. The rest were never a thumbnail
          // on the route below, so there is no warm decode of theirs to defer
          // to, and offering one would only pin them to a resolution they never
          // had.
          deferDecode: i == widget.initialIndex && !landed,
          fill: _fill,
          drag: _drag,
          onDismiss: _close,
          onToggleChrome: () => setState(() => _chrome = !_chrome),
          onZoomChanged: (z) {
            if (i == _index && z != _zoomed) setState(() => _zoomed = z);
          },
        ),
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

/// One photograph, filling the screen, zoomable and draggable away.
class _StagePage extends StatefulWidget {
  const _StagePage({
    required this.moment,
    required this.api,
    required this.deferDecode,
    required this.fill,
    required this.drag,
    required this.onDismiss,
    required this.onToggleChrome,
    required this.onZoomChanged,
  });

  final Moment moment;
  final ChatApi api;

  /// Hold the full-resolution decode back while the opening flight is in the
  /// air — see [RemoteImage.decodeWidth]. Megabytes to allocate and megabytes
  /// to hand the GPU, spent in direct competition with the one moment the
  /// picture is moving.
  final bool deferDecode;

  /// The route's fill preference. Whether it is honoured for THIS picture is
  /// [photoFillsScreen]'s call — see `_MomentStageState._fill`.
  final bool fill;

  final ValueNotifier<Offset> drag;
  final VoidCallback onDismiss;
  final VoidCallback onToggleChrome;
  final void Function(bool zoomed) onZoomChanged;

  @override
  State<_StagePage> createState() => _StagePageState();
}

class _StagePageState extends State<_StagePage> {
  /// The picture's width÷height, when it is known before the picture is.
  ///
  /// **This is what stops the two-step jump.** A `contain` image that has not
  /// decoded yet has no intrinsic size, so it measures as the whole screen —
  /// and that is the rect a Hero flight is given as its destination. The
  /// thumbnail therefore blows up to the full frame, and one frame later, when
  /// the bytes arrive and the picture claims its real box, it snaps down into
  /// its letterbox. Two movements for one tap, and the second one is a cut.
  ///
  /// Pinning the box to the ratio settles the flight exactly where the decoded
  /// picture is going to be, one frame earlier and without the jump.
  /// [MediaAspectCache] usually already knows — the rail records it the first
  /// time a thumbnail decodes — and when it does not, the first decode fills it
  /// in for every later open.
  double? _aspect;

  @override
  void initState() {
    super.initState();
    final id = widget.moment.thumbStorageId;
    if (id != null) _aspect = MediaAspectCache.instance.peek(id);
  }

  void _learn(String id, double aspect) {
    MediaAspectCache.instance.remember(id, aspect);
    if (mounted && _aspect == null) setState(() => _aspect = aspect);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.moment.thumbStorageId;
    if (id == null) return const SizedBox.shrink();

    final image = RemoteImage(
      storageId: id,
      api: widget.api,
      fit: BoxFit.contain,
      // The decode the rail is already holding, used as the arrival backdrop —
      // without it the flight lands on a shimmer even though the bytes are
      // local and the picture was on screen a moment ago.
      placeholderDecodeWidth: momentThumbDecodeWidth,
      decodeWidth: widget.deferDecode ? momentThumbDecodeWidth : null,
      onAspectRatio: _aspect == null ? (a) => _learn(id, a) : null,
    );

    final video = widget.moment.mediaKind == MomentMedia.video;
    final playable = video && widget.moment.mediaStorageId != null;
    final fills =
        widget.fill &&
        photoFillsScreen(_aspect, MediaQuery.sizeOf(context));

    return Stack(
      fit: StackFit.expand,
      children: [
        // Only when the picture is NOT filling. Behind a `cover` fit it is
        // invisible by definition, and an invisible blurred layer is still a
        // filtered layer the compositor pays for on every frame.
        //
        // When it IS visible it fills the space a `contain` fit leaves above
        // and below the picture with the picture's own colour, so the chrome
        // floats over the photograph rather than over dead black. Reuses the
        // thumbnail decode — already resident, and about to be blurred past
        // recognition anyway.
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
        PhotoDismissArea(
          drag: widget.drag,
          onDismiss: widget.onDismiss,
          // A tap on a video means play. On a photograph it means "get the
          // furniture out of the way", which is what a tap means in every
          // gallery anyone has used.
          onTap: playable ? _play : widget.onToggleChrome,
          onZoomChanged: widget.onZoomChanged,
          // A poster is not a photograph to examine: zooming one would enlarge
          // a still of something the OS player is one tap away from playing
          // properly.
          maxScale: video ? 1 : 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // `SteadyHero` rather than `Hero`: a plain one tears the child out
              // of the tree at both ends of a flight, so the picture arrives as
              // a hole and fills in a frame later.
              SteadyHero(
                tag: momentMediaHeroTag(widget.moment.id),
                // Filling needs no box of its own: the picture takes the whole
                // page, which is a Hero destination that is correct on the
                // FIRST frame — and it is the same crop the rail thumbnail was
                // already showing, so the flight is a pure scale with nothing
                // to reframe. Letterboxed, the box has to be pinned to the
                // ratio instead; see [_aspect].
                child: fills
                    ? SizedBox.expand(child: _fillImage(id))
                    : (_aspect == null
                          ? image
                          : AspectRatio(aspectRatio: _aspect!, child: image)),
              ),
              if (playable)
                // The disc is the same action with a smaller target and a focus
                // ring on it — the whole poster is tappable above.
                PhotoGlassButton(
                  icon: Icons.play_arrow_rounded,
                  semanticLabel: AppLocalizations.of(
                    context,
                  ).bubbleStyleScreenMediaTileVideoSemanticLabel,
                  onTap: _play,
                  size: 64,
                  iconSize: 34,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The picture at `cover`, for when it is filling the screen.
  ///
  /// A separate widget rather than a `fit:` on the one above, because the two
  /// want different decode hints: a `contain` picture is bounded by the screen's
  /// short edge, a `cover` one by its long edge, and handing the same
  /// `decodeWidth` to both would leave the filled version upscaled and soft on
  /// the biggest view of it in the app.
  Widget _fillImage(String id) => RemoteImage(
    storageId: id,
    api: widget.api,
    fit: BoxFit.cover,
    borderRadius: BorderRadius.zero,
    placeholderDecodeWidth: momentThumbDecodeWidth,
    decodeWidth: widget.deferDecode ? momentThumbDecodeWidth : null,
  );

  /// Hands the clip to the OS player, exactly as a video tapped in a chat does.
  ///
  /// No player of our own, and no hero tag: scrubbing, speed, AirPlay/Cast,
  /// Picture-in-Picture and the lock-screen transport controls all already live
  /// there, in the user's own language. See `MediaPagerScreen`'s video page,
  /// which makes the same argument at length.
  void _play() {
    final id = widget.moment.mediaStorageId;
    if (id == null) return;
    FullscreenVideoViewer.open(
      context,
      storageId: id,
      api: widget.api,
      posterStorageId: widget.moment.posterStorageId,
    );
  }
}

/// Holds a piece of chrome against an edge of the screen and fades it.
///
/// [AnimatedOpacity] rather than a plain [Opacity] so the tap-to-hide toggle is
/// a fade and not a cut. It is driven by the dismiss drag as well, and at 90ms
/// that follows a finger closely enough to still read as continuous.
///
/// **Subscribes to the drag itself, and takes [child] pre-built.** The chrome
/// is a dozen blurred glass surfaces; rebuilding it from inside the drag's own
/// builder meant reconstructing all of them on every frame of a gesture, over a
/// full-screen photograph. This way a drag repaints one opacity and nothing
/// else.
class _FadingChrome extends StatelessWidget {
  const _FadingChrome({
    required this.drag,
    required this.visible,
    required this.child,
    this.alignBottom = false,
  });

  final ValueNotifier<Offset> drag;

  /// The tap-to-hide state. False keeps the chrome down regardless of the drag.
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
      child: ValueListenableBuilder<Offset>(
        valueListenable: drag,
        builder: (context, value, child) {
          // The chrome leaves twice as fast as the picture does, so it is gone
          // before the photograph is halfway home rather than riding out over
          // the board behind it.
          final t = photoDismissProgress(value, screen);
          final opacity = visible ? (1 - t * 2).clamp(0.0, 1.0) : 0.0;
          return IgnorePointer(
            // Not merely invisible: hidden chrome that still swallowed taps
            // would make the gesture that hid it impossible to undo.
            ignoring: opacity < 0.05,
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 90),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Who posted it, when, where you are in the run — and the way out.
class _StageTopBar extends StatelessWidget {
  const _StageTopBar({
    required this.moment,
    required this.api,
    required this.position,
    required this.onClose,
    required this.onDelete,
    required this.onToggleFill,
    required this.filled,
  });

  final Moment moment;
  final ChatApi api;

  /// "3 / 8", or null for a run of one.
  final String? position;

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

    return Stack(
      children: [
        // White on white is not a colour scheme, and the top of a photograph is
        // as likely to be sky as anything else.
        //
        // Its own gradient rather than `MediaScrim`, which starts at 70% black:
        // that is right over a chat gallery's furniture and too heavy here,
        // where the picture now fills the screen and the scrim is the only
        // thing between the reader and it. Lighter, and spread over more of the
        // frame, so it reads as a vignette rather than as a bar — the glass
        // buttons and the text shadows below carry the legibility.
        IgnorePointer(
          child: Container(
            height: pad.top + 96,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(10, pad.top + 8, 10, 12),
          child: Row(
            children: [
              PhotoGlassButton(
                icon: Icons.close,
                semanticLabel: l10n.photoChromeCloseSemanticLabel,
                onTap: onClose,
                size: 38,
                iconSize: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    _AuthorDot(moment: moment, api: api),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            moment.mine
                                ? l10n.momentRailYouLabel
                                : moment.authorName,
                            style: theme.bodyEmph.copyWith(
                              color: PhotoChrome.ink,
                              // Over an arbitrary photograph a shadow is what
                              // keeps a name legible where the scrim above has
                              // already thinned out.
                              shadows: const [
                                Shadow(color: Color(0x99000000), blurRadius: 6),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              _ago(l10n, moment.createdAt),
                              ?position,
                            ].join('  ·  '),
                            style: theme.monoTiny.copyWith(
                              color: PhotoChrome.inkDim,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (onToggleFill != null) ...[
                const SizedBox(width: 8),
                PhotoGlassButton(
                  // The glyph names what the tap DOES, not the current state:
                  // a filled picture offers to shrink back to the whole frame.
                  icon: filled
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  semanticLabel: l10n.photoChromeFillToggleSemanticLabel,
                  onTap: onToggleFill,
                  size: 38,
                  iconSize: 19,
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 8),
                PhotoGlassButton(
                  icon: Icons.delete_outline,
                  semanticLabel: l10n.momentViewerDelete,
                  onTap: onDelete,
                  size: 38,
                  iconSize: 17,
                ),
              ],
            ],
          ),
        ),
      ],
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

  static const _size = 30.0;

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
        border: Border.all(color: PhotoChrome.stroke, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: id == null
          ? Text(
              initial,
              style: theme.monoTiny.copyWith(
                color: PhotoChrome.ink,
                fontSize: 12,
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
    required this.onShowReactors,
  });

  final Moment moment;
  final _Reactions reactions;
  final void Function(String emoji) onReact;
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
                  color: PhotoChrome.ink,
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
            ),
          ],
        ),
      ),
    );
  }
}

/// The reaction row over a photograph.
///
/// Scrolls horizontally rather than wrapping: the quick set is four, but a
/// moment can carry any number of extras from other clients, and a second row
/// of pills growing upward would push the caption off a screen it shares.
class _GlassReactionRail extends StatelessWidget {
  const _GlassReactionRail({
    required this.emojis,
    required this.reactions,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> emojis;
  final _Reactions reactions;
  final void Function(String emoji) onTap;
  final void Function(String emoji) onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final total = reactions.total;

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
              ],
            ),
          ),
        ),
        if (total > 0) ...[
          const SizedBox(width: 10),
          Text(
            '$total',
            style: theme.monoTiny.copyWith(color: PhotoChrome.inkDim),
          ),
        ],
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
        child: PhotoGlassSurface(
          // Solid accent when it is yours, so a reaction you added is legible
          // as *yours* over any photograph — glass-on-glass is not.
          tint: active ? accent : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      color: active ? accentInk : PhotoChrome.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      decoration: TextDecoration.none,
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
      padding: const EdgeInsets.all(16),
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
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      m.mine ? l10n.momentRailYouLabel : m.authorName,
                      style: theme.displaySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _StageTopBar._ago(l10n, m.createdAt),
                      style: theme.monoTiny.copyWith(color: theme.inkMuted),
                    ),
                  ],
                ),
              ),
              // Pinned to the card rather than floating in the outer Stack: the
              // card is vertically centred and its height follows its content,
              // so a fixed top-right Positioned would sometimes land on the
              // text and sometimes in empty space. Kept now that the card can
              // be swiped away, because a gesture is not an affordance — this
              // is still the only *visible* way out.
              GlassCloseButton(
                onTap: () => Navigator.of(context).maybePop(),
                semanticLabel: l10n.photoChromeCloseSemanticLabel,
                size: 34,
              ),
            ],
          ),
          if (m.tag != null) ...[
            const SizedBox(height: 14),
            MomentTagChip(tag: m.tag!),
          ],
          if (m.caption?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            // The line of text IS the point, so it gets the readable style and
            // the room. Everything above it is metadata.
            Text(m.caption!, style: theme.body),
          ],
          const SizedBox(height: 16),
          _CardReactionRow(
            emojis: _emojisFor(m, reactions),
            reactions: reactions,
            onTap: (e) => _book.toggle(m, e),
            onLongPress: _showReactors,
          ),
          if (m.mine) ...[
            const SizedBox(height: 14),
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
}

class _CardReactionRow extends StatelessWidget {
  const _CardReactionRow({
    required this.emojis,
    required this.reactions,
    required this.onTap,
    required this.onLongPress,
  });

  final List<String> emojis;
  final _Reactions reactions;
  final void Function(String emoji) onTap;

  /// Long-press a pill to see who's behind it.
  final void Function(String emoji) onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final total = reactions.total;
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
              ],
            ),
          ),
        ),
        if (total > 0) ...[
          const SizedBox(width: 8),
          Text('$total', style: theme.monoTiny),
        ],
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
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: active ? theme.accentSoft : theme.surfaceSunken,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? theme.accent : theme.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: theme.monoTiny.copyWith(fontSize: 14)),
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
