import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../keyboard/app_shortcuts.dart';
import '../../keyboard/focusable_tap.dart';
import '../../keyboard/viewer_keys.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/media_aspect_cache.dart';
import '../../models/chat_user.dart';
import '../../models/expression_item.dart';
import '../../models/family.dart';
import '../../models/moment.dart';
import '../../theme/interaction.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/desktop_scroll.dart';
import '../../widgets/destructive_sheet.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/moment_reactions.dart';
import '../../widgets/photo_backdrop.dart' show photoFillsScreen;
import '../../widgets/photo_dismiss_area.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/route_landing.dart';
import '../../widgets/photo_chrome.dart' show MediaPlayDisc;
import '../../widgets/sheet_kit.dart'
    show
        SheetBar,
        SheetCloseButton,
        SheetHandle,
        SheetTrashButton,
        IosSheetAction,
        showIosActionSheet;

import '../../widgets/steady_hero.dart';
import '../fullscreen_video_viewer.dart';
import '../../widgets/ios_kit.dart' show quietFill, SpringPress;
import '../../widgets/reaction_picker_sheet.dart' show pickReaction;
import '../../widgets/reaction_limit_notice.dart';
import '../../widgets/moment_comments_sheet.dart';
import '../../models/reaction_limits.dart';
import '../../platform.dart';
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
  bool openComments = false,

  /// Opens someone's profile from the reactions or the comments. The viewer
  /// has no repository of its own to build one with, so the host lends this.
  void Function(ChatUser user)? onOpenProfile,

  /// The viewer's own face and a lookup over the people the host already
  /// holds (friends), to fill in reactors whose reaction carries no face:
  /// the viewer's own, drawn before the server echoes it, and any left before
  /// faces were stored with reactions.
  String? viewerAvatarStorageId,
  ChatUser? Function(String userId)? resolveUser,
}) {
  final faces = _Faces(viewerId: userId, viewerAvatar: viewerAvatarStorageId, resolve: resolveUser);
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
      openComments: openComments,
      onOpenProfile: onOpenProfile,
      faces: faces,
    );
  }
  return _openCard(
    context,
    moment: moment,
    api: api,
    feedApi: feedApi,
    userId: userId,
    origin: origin,
    openComments: openComments,
    onOpenProfile: onOpenProfile,
    faces: faces,
  );
}

/// Fills in the faces (and handles) a reactor row arrived without, from what
/// the host already knows. A reaction's own stored face always wins: it
/// carries the reactor's avatar setting as the server applied it.
class _Faces {
  const _Faces({required this.viewerId, this.viewerAvatar, this.resolve});

  final String viewerId;
  final String? viewerAvatar;
  final ChatUser? Function(String userId)? resolve;

  static const none = _Faces(viewerId: '');

  List<MomentReactor> fill(List<MomentReactor> reactors) => [
        for (final r in reactors)
          r.avatarStorageId != null && r.username != null ? r : _filled(r),
      ];

  MomentReactor _filled(MomentReactor r) {
    final known = r.userId == viewerId ? null : resolve?.call(r.userId);
    final face = r.avatarStorageId ??
        (r.userId == viewerId ? viewerAvatar : known?.avatarStorageId);
    return MomentReactor(
      emoji: r.emoji,
      userId: r.userId,
      name: r.name.isNotEmpty ? r.name : (known?.name ?? ''),
      username: r.username ?? known?.username,
      avatarStorageId: face,
      createdAt: r.createdAt,
    );
  }
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
  bool openComments = false,
  void Function(ChatUser user)? onOpenProfile,
  _Faces faces = _Faces.none,
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
        openComments: openComments,
        onOpenProfile: onOpenProfile,
        faces: faces,
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
  bool openComments = false,
  void Function(ChatUser user)? onOpenProfile,
  _Faces faces = _Faces.none,
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
        openComments: openComments,
        onOpenProfile: onOpenProfile,
        faces: faces,
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
        reactors = [...m.reactors];

  final Set<String> mine;
  final Map<String, int> counts;

  /// Every reaction with who left it, as the moment carries them (name,
  /// handle and face denormalized on the server; see `MomentReactor`).
  final List<MomentReactor> reactors;

  int get total => counts.values.fold(0, (a, b) => a + b);
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
    required this.onLimit,
  });

  final FeedApi feedApi;
  final String userId;
  final VoidCallback onChanged;

  /// Says "you've reached the reaction limit" — before sending when the
  /// local state already shows the cap, and after a server refusal when it
  /// did not (another device of theirs got there first).
  final VoidCallback onLimit;

  /// Comment counts the open comments sheet has reported, which run ahead of
  /// the board snapshot this route was opened with.
  final _commentCounts = <String, int>{};

  int commentsOf(Moment m) => _commentCounts[m.id] ?? m.commentCount;

  void noteComments(Moment m, int count) {
    if (_commentCounts[m.id] == count) return;
    _commentCounts[m.id] = count;
    onChanged();
  }

  final _byMoment = <String, _Reactions>{};

  _Reactions of(Moment m) => _byMoment.putIfAbsent(m.id, () => _Reactions(m));

  /// Applies (or reverses) one local edit across all three collections
  /// together, so they never drift out of step.
  void _apply(_Reactions r, String emoji, bool reacted) {
    if (reacted) {
      r.mine.add(emoji);
      r.counts[emoji] = (r.counts[emoji] ?? 0) + 1;
      // Name left blank: the sheet substitutes the localized "you" for this
      // user's own id. Their face and handle ride along when one of their own
      // earlier reactions already carries them.
      MomentReactor? me;
      for (final x in r.reactors) {
        if (x.userId == userId) me = x;
      }
      r.reactors.add(MomentReactor(
        emoji: emoji,
        userId: userId,
        name: me?.name ?? '',
        username: me?.username,
        avatarStorageId: me?.avatarStorageId,
        createdAt: DateTime.now(),
      ));
    } else {
      r.mine.remove(emoji);
      final n = (r.counts[emoji] ?? 1) - 1;
      if (n <= 0) {
        r.counts.remove(emoji);
      } else {
        r.counts[emoji] = n;
      }
      r.reactors.removeWhere((e) => e.userId == userId && e.emoji == emoji);
    }
  }

  Future<void> toggle(Moment m, String emoji) async {
    final r = of(m);
    final had = r.mine.contains(emoji);
    // The cap, said before anything is sent — see reaction_limits.dart.
    if (!had && r.mine.length >= kMaxMomentReactionsPerPerson) {
      onLimit();
      return;
    }
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
    } catch (e) {
      // Roll the optimistic edit back rather than leaving a reaction that does
      // not exist on the server — the next board payload would silently
      // contradict it and the count would appear to flicker on its own.
      _apply(r, emoji, had);
      onChanged();
      if (e.toString().contains(kReactionLimitError)) onLimit();
    }
  }

}

/// Reacts to [m] with any emoji from the full picker — the same sheet chat
/// uses. The quick row is four one-tap shortcuts; this is the way past them.
Future<void> _reactWithAny(
  BuildContext context,
  _ReactionBook book,
  Moment m,
) async {
  final pick = await pickReaction(context, selected: {...book.of(m).mine});
  if (pick == null || pick.emoji.isEmpty) return;
  // A grid pick of one you already sent changes nothing — choosing it from a
  // picker does not mean "take it back". The "Your reactions" strip over the
  // grid is where one is taken back, and says so with `remove`.
  if (pick.remove != book.of(m).mine.contains(pick.emoji)) return;
  await book.toggle(m, pick.emoji);
}

/// Opens [m]'s comments over whichever viewer surface is up, keeping the
/// pill's count in step with the conversation while it is open.
Future<void> _openComments(
  BuildContext context,
  _ReactionBook book, {
  required Moment m,
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
  void Function(ChatUser user)? onOpenProfile,
}) {
  HapticFeedback.selectionClick();
  return showMomentComments(
    context,
    moment: m,
    api: api,
    feedApi: feedApi,
    userId: userId,
    onCount: (n) => book.noteComments(m, n),
    onOpenProfile: onOpenProfile,
  );
}

/// The comment pill at the end of a reaction row: a speech bubble and how many.
class _CommentsPill extends StatelessWidget {
  const _CommentsPill({
    required this.count,
    required this.onTap,
    required this.overPhoto,
  });

  final int count;
  final VoidCallback onTap;

  /// Glass over a photograph; the card's quiet pill otherwise.
  final bool overPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = AppLocalizations.of(context).momentCommentsCount(count);
    final ink = overPhoto ? MediaGlass.ink : theme.inkSoft;
    final glyph = SizedBox(
      height: _kPillContent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.chat_bubble, size: 16, color: ink),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: ink,
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
    );
    if (overPhoto) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: LiquidGlass(
          tone: GlassTone.media,
          shape: LiquidGlassShape.capsule,
          onTap: onTap,
          // 44pt tall, the comment field's own height, so the bar's three
          // controls stand on one line.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

/// How long arrivals collect before they go to the server as one `markSeen`.
/// An item counts as seen the moment it is on screen (a tap to the next one
/// is "seen it, next", the stories convention); this only batches a quick
/// tap-through into one write instead of one per picture.
const _kStorySeenFlush = Duration(milliseconds: 600);

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
    this.openComments = false,
    this.onOpenProfile,
    this.faces = _Faces.none,
  });

  /// See [_Faces].
  final _Faces faces;

  /// Opens the first moment's comments once the stage is up — a comment
  /// notification's tap.
  final bool openComments;

  /// See [showMomentViewer].
  final void Function(ChatUser user)? onOpenProfile;

  final List<Moment> moments;
  final int initialIndex;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  @override
  State<_MomentStage> createState() => _MomentStageState();
}

class _MomentStageState extends State<_MomentStage>
    with RouteLanding, TickerProviderStateMixin, WidgetsBindingObserver {
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
    onLimit: () {
      if (mounted) {
        showReactionLimitNotice(context, surface: ReactionLimitSurface.moment);
      }
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

  /// Space on a desk: the hold, for a reader whose hands are on a keyboard.
  /// Unlike the hold the chrome stays, since nothing is being pressed on the
  /// picture; the stopped progress bar says it is paused. Cleared by moving
  /// to another story, which is a reader carrying on.
  bool _keyPaused = false;
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

  /// Ids seen but not yet sent; flushed by [_seenTimer] or on dispose.
  final _seenPending = <String>[];

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
    _panel.addListener(_onPanel);
    if (widget.openComments) {
      // After the route's own flight, so the panel rises over a settled stage
      // rather than racing it.
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _comments(_current);
      });
    }
  }

  // ── The swipe-up panel ──────────────────────────────────────────────────
  //
  // Instagram's: swipe up on a story (or tap its comment bar) and a panel
  // rises over it with the reactions drawn big, the conversation, and the
  // composer. It follows the finger both ways, and pulling it down from
  // anywhere, the list included, puts it away and lets the story play on.

  /// 0 closed, 1 open. Driven by the finger while dragging.
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  /// Whether any of the panel is showing: the conversation is mounted (and
  /// subscribed) only then, and the story's clock holds still.
  bool _panelUp = false;

  /// The comment composer's focus, held here so tapping the bar can open the
  /// panel and raise the keyboard in one gesture.
  final FocusNode _commentFocus = FocusNode(debugLabel: 'moment-comment');

  /// How far a finger travels to open the reply mode all the way; the drag
  /// is mapped onto [_panel] over this distance.
  double get _panelHeight => MediaQuery.sizeOf(context).height * 0.4;

  /// The full conversation, in a sheet over the stage (the clock pauses while
  /// it is up: the route stops being current).
  Future<void> _comments(Moment m) => _openComments(
        context,
        _book,
        m: m,
        api: widget.api,
        feedApi: widget.feedApi,
        userId: widget.userId,
        onOpenProfile: widget.onOpenProfile,
      );

  /// Posts a comment from the reply mode, then puts the reply mode away.
  Future<bool> _submitReply(Moment m, {String? text, ExpressionItem? item}) async {
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    try {
      await widget.feedApi.comment(
        userId: widget.userId,
        momentId: m.id,
        text: text,
        expression: item,
      );
    } catch (e) {
      // The language filter is a refusal, not a failure: say why.
      if (isFilterBlockedError(e)) {
        toast.show(l10n.messageFilterBlocked);
      } else {
        toast.show(l10n.momentCommentFailed, tone: ToastTone.danger);
      }
      return false;
    }
    _book.noteComments(m, _book.commentsOf(m) + 1);
    toast.show(l10n.momentCommentPosted, tone: ToastTone.success);
    if (mounted) _closePanel();
    return true;
  }

  /// A reaction from the big grid: leave it (or take it back) and get out of
  /// the way, Instagram's way. At the cap the alert says so and the grid
  /// stays, so another one can be taken back.
  void _reactFromGrid(Moment m, String emoji, Offset origin) {
    final r = _book.of(m);
    final adding = !r.mine.contains(emoji);
    final atCap = adding && r.mine.length >= kMaxMomentReactionsPerPerson;
    _book.toggle(m, emoji);
    if (atCap) return;
    // The send, seen: copies of the emoji float up from where it was tapped
    // as the reply mode gets out of the way. Only for a reaction left, not
    // one taken back, and never under Reduce Motion.
    if (adding && !MotionScope.of(context).calm) {
      setState(() => _bursts.add((UniqueKey(), emoji, origin)));
    }
    _closePanel();
  }

  /// Reactions in flight, drawn over everything until they finish.
  final _bursts = <(Key, String, Offset)>[];

  void _onPanel() {
    // Opening counts as up from its first tick, which can still read 0: going
    // by the value alone flipped the panel back down for a frame, and the
    // composer's focus request landed in exactly that frame.
    final up = _panel.value > 0 || _panel.status == AnimationStatus.forward;
    if (up == _panelUp) return;
    setState(() => _panelUp = up);
    _sync();
  }

  /// A drag of [dy] logical pixels, positive downward (closing).
  void _panelDrag(double dy) {
    _panel.value = (_panel.value - dy / _panelHeight).clamp(0.0, 1.0);
  }

  /// The finger let go at [velocity] (pixels per second, positive downward).
  void _panelRelease(double velocity) {
    final open = velocity < -350
        ? true
        : velocity > 350
            ? false
            : _panel.value > 0.5;
    open ? _openPanel() : _closePanel();
  }

  /// Opens the reply mode with the keyboard coming up WITH it, not after:
  /// the composer mounts on the panel's first frame, and the field takes
  /// focus on the frame after that, so the keyboard and the reactions rise
  /// together.
  Future<void> _openPanel({bool keyboard = true}) async {
    if (_panel.value == 0) HapticFeedback.selectionClick();
    // Mounted NOW, not when the animation's first tick lands: the composer
    // (and its focus node) has to be in the tree for the focus below to have
    // anything to take. Waiting for the controller left the post-frame focus
    // finding no field, and the keyboard needed a second tap.
    if (!_panelUp) {
      setState(() => _panelUp = true);
      _sync();
    }
    if (keyboard) _focusComposerSoon();
    final calm = MotionScope.of(context).calm;
    if (calm) {
      _panel.value = 1;
    } else {
      await _panel.animateTo(1, curve: Curves.easeOutCubic);
    }
  }

  /// Focuses the composer as soon as its field exists.
  ///
  /// Retried frame by frame: the field mounts a frame or two after the panel
  /// does (it sits under the reply mode's own builders), and a focus request
  /// on a node not yet in the tree is simply dropped. That drop was the
  /// "tap the field, get emojis but no keyboard" bug.
  void _focusComposerSoon([int tries = 8]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_panelUp || _commentFocus.hasFocus) return;
      if (_commentFocus.context == null) {
        if (tries > 0) _focusComposerSoon(tries - 1);
        return;
      }
      _commentFocus.requestFocus();
    });
    // A post-frame callback only runs if a frame is coming.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _closePanel() {
    // On a desk, focus goes back to the stage's key handler (see
    // [ViewerKeys]) rather than up to the route, where ← → would no
    // longer reach it.
    _commentFocus.unfocus(
      disposition: isWebOrDesktop
          ? UnfocusDisposition.previouslyFocusedChild
          : UnfocusDisposition.scope,
    );
    final calm = MotionScope.of(context).calm;
    if (calm) {
      _panel.value = 0;
    } else {
      _panel.animateBack(0, curve: Curves.easeOutCubic);
    }
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
    _flushSeen();
    _loadFallback?.cancel();
    _afterVideo?.cancel();
    _clock.dispose();
    _panel.removeListener(_onPanel);
    _panel.dispose();
    _commentFocus.dispose();
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
      _keyPaused ||
      _paging ||
      _dragging ||
      _zoomed ||
      !_routeCurrent ||
      _keyboard ||
      !_appActive ||
      _screenReader ||
      _panelUp ||
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
  /// count it as seen.
  void _arrive() {
    _keyPaused = false;
    _clock.value = 0;
    _ready = false;
    _loadFallback?.cancel();
    final m = _current;
    _markSeen(m);
    // A picture that never decodes (deleted since the board loaded, a dead
    // link) must not trap the run on a spinner: after a while it plays on.
    _loadFallback = Timer(const Duration(seconds: 8), () => _onReady(m.id));
    if (debugStoryAssumeLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onReady(m.id));
    }
    // Already decoded: start now. A picture reports "decoded" once per
    // mount, and two arrivals never get a second report: the next person's
    // page, which the pager builds while it is still the neighbour (so its
    // report came in before it was current, and was set aside), and a tap
    // back on the very first story, which restarts the same picture. Both
    // used to sit on an empty bar until the eight second fallback.
    if (_decodedIds.contains(m.id)) {
      _loadFallback?.cancel();
      _ready = true;
      _sync();
    }
  }

  /// Every picture that has reported decoded on this route, current or not.
  final _decodedIds = <String>{};

  /// The picture for [id] has decoded. Remembered whichever item it is; only
  /// the current item's starts the clock.
  void _onReady(String id) {
    _decodedIds.add(id);
    if (!mounted || id != _current.id || _ready) return;
    _loadFallback?.cancel();
    _ready = true;
    _sync();
  }

  void _markSeen(Moment m) {
    if (m.mine || m.seen || !_seenSent.add(m.id)) return;
    _seenPending.add(m.id);
    _seenTimer?.cancel();
    _seenTimer = Timer(_kStorySeenFlush, _flushSeen);
  }

  void _flushSeen() {
    if (_seenPending.isEmpty) return;
    final ids = List.of(_seenPending);
    _seenPending.clear();
    widget.feedApi
        .markSeen(userId: widget.userId, momentIds: ids)
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

  void _toggleKeyPause() {
    if (_closing || _isVideo(_current)) return;
    setState(() => _keyPaused = !_keyPaused);
    _sync();
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
    final bar = _kCommentBar + MediaQuery.paddingOf(context).bottom;
    final top = MediaQuery.paddingOf(context).top;

    final stage = PopScope(
      // Back (or Escape) puts the panel away first, as a swipe down would.
      canPop: !_panelUp,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closePanel();
        } else if (!_closing) {
          // Popped from outside (Esc, system back) rather than by [_close]:
          // stop the story clock all the same, or the last story can run out
          // during the exit transition and call [_close] on whatever route is
          // underneath.
          _closing = true;
          _sync();
        }
      },
      child: Material(
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
                // Solid black, like every other photo viewer in the app: no
                // blurred copy of the picture behind it. Painted inside the
                // route rather than left to the barrier, so it can fade to
                // nothing as the drag commits and the Hero return reads as
                // the picture going back where it came from.
                ValueListenableBuilder<Offset>(
                  valueListenable: _drag,
                  builder: (context, drag, _) => Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 1 - photoDismissProgress(drag, screen),
                        ),
                      ),
                    ),
                  ),
                ),
                // The story is a card, Instagram's: from just under the
                // status bar to the comment bar, rounded at all four corners,
                // with the progress bar and the author riding on its top
                // edge. Never under the bar: the bar is the floor it stands
                // on. One clip around the whole pager, not one per page.
                ValueListenableBuilder<Offset>(
                  valueListenable: _drag,
                  builder: (context, drag, pages) {
                    final t = photoDismissProgress(drag, screen);
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: top,
                      bottom: bar,
                      child: Transform.translate(
                        offset: drag,
                        child: Transform.scale(
                          scale: 1 - t * kPhotoDismissShrink,
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(_kStoryCardRadius),
                            child: pages,
                          ),
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
                    onOpenAuthor: current.mine || widget.onOpenProfile == null
                        ? null
                        : () => widget.onOpenProfile!(
                              ChatUser(
                                id: current.userId,
                                username: current.authorUsername,
                                name: current.authorName,
                                avatarStorageId: current.authorAvatarStorageId,
                              ),
                            ),
                  ),
                ),
                _FadingChrome(
                  drag: _drag,
                  // Gone under the reply mode: its own composer takes this
                  // place, and the bar's outline would peek out beside it.
                  visible: chrome && !_panelUp,
                  alignBottom: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StageCaption(moment: current),
                      // Who reacted: faces wearing their emoji, newest first.
                      if (_book.of(current).reactors.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: MomentReactorStack(
                              groups: groupReactors(
                                widget.faces.fill(_book.of(current).reactors),
                              ),
                              api: widget.api,
                              viewerId: widget.userId,
                              onTap: () => _showReactors(current),
                            ),
                          ),
                        ),
                      _StageCommentBar(
                        height: _kCommentBar,
                        count: _book.commentsOf(current),
                        onField: _openPanel,
                        onComments: () => _comments(current),
                      ),
                    ],
                  ),
                ),
                if (_panelUp) _panelLayer(current),
                for (final (key, emoji, origin) in _bursts)
                  Positioned.fill(
                    child: _EmojiBurst(
                      key: key,
                      emoji: emoji,
                      origin: origin,
                      onDone: () {
                        if (!mounted) return;
                        setState(() => _bursts.removeWhere((b) => b.$1 == key));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
    if (!isWebOrDesktop) return stage;
    // A desk's keys: ← → a story back and on, Space to hold one still. Not
    // while the reply panel is up: its field has the focus and the arrows
    // move its caret (Space it types, and the registry already knows that).
    // Esc stays the route's, through the `PopScope` above, which puts the
    // panel away first.
    return ShortcutBindings(
      bindings: {
        if (!_panelUp && !_isVideo(current))
          AppShortcuts.playPause: _toggleKeyPause,
      },
      child: ViewerKeys(
        onPrevious: _panelUp ? null : _previous,
        onNext: _panelUp ? null : _next,
        child: stage,
      ),
    );
  }

  /// The reply mode, following [_panel]: the story dims, the preset
  /// reactions float big over it, and the composer sits above the keyboard.
  /// Instagram's reply overlay, down to the swipe down that puts it away.
  Widget _panelLayer(Moment m) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final reactions = _book.of(m);
    final count = _book.commentsOf(m);
    void drag(DragUpdateDetails d) => _panelDrag(d.delta.dy);
    void release(DragEndDetails d) =>
        _panelRelease(d.velocity.pixelsPerSecond.dy);
    return AnimatedBuilder(
      animation: _panel,
      builder: (context, composer) {
        final v = _panel.value;
        final eased = Curves.easeOutCubic.transform(v);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
                onVerticalDragUpdate: drag,
                onVerticalDragEnd: release,
                child: ColoredBox(
                  // Deep enough that the reactions and the composer, not the
                  // photograph, are what the eye lands on.
                  color: Colors.black.withValues(alpha: 0.78 * v),
                ),
              ),
            ),
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: media.padding.top + _kTopBand),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: v < 0.5,
                      child: Opacity(
                        opacity: eased,
                        child: Transform.translate(
                          offset: Offset(0, 48 * (1 - eased)),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ReplyEmojiGrid(
                                    emojis: quickReactionsFor(m.tag),
                                    reactions: reactions,
                                    onTap: (e, origin) =>
                                        _reactFromGrid(m, e, origin),
                                    onLongPress: (e) => _showReactors(m, e),
                                    onMore: () async {
                                      await _reactWithAny(context, _book, m);
                                      if (mounted) _closePanel();
                                    },
                                  ),
                                  if (count > 0) ...[
                                    const SizedBox(height: 28),
                                    _ViewCommentsLink(
                                      label: l10n.momentCommentsViewAll(count),
                                      onTap: () => _comments(m),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Opacity(opacity: eased, child: composer),
                ],
              ),
            ),
          ],
        );
      },
      child: Theme(
        // The composer is the app's own, drawn on the dimmed story.
        data: Theme.of(context),
        child: DefaultTextStyle(
          style: theme.body.copyWith(color: theme.ink),
          child: MomentCommentComposer(
            key: ValueKey(m.id),
            focus: _commentFocus,
            hint: l10n.momentCommentHint,
            maxPanel: media.size.height * 0.5,
            // The stage's own black: the composer stands on the floor the
            // story stands on, never as glass over the photograph.
            floor: Colors.black,
            onSubmit: ({text, item}) =>
                _submitReply(m, text: text, item: item),
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
              onPanelDrag: _panelDrag,
              onPanelEnd: _panelRelease,
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

  /// Who reacted, as a list; [emoji] narrows it to one reaction.
  void _showReactors(Moment m, [String? emoji]) {
    final reactors = widget.faces.fill(_book.of(m).reactors);
    if (reactors.isEmpty) return;
    HapticFeedback.mediumImpact();
    showMomentReactions(
      context,
      reactors: reactors,
      api: widget.api,
      viewerId: widget.userId,
      initialEmoji: emoji,
      onOpenProfile: widget.onOpenProfile,
    );
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
    required this.onPanelDrag,
    required this.onPanelEnd,
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

  /// A drag that started UPWARD: it opens the panel instead of dismissing.
  /// Logical pixels, positive downward, as the panel reads them.
  final ValueChanged<double> onPanelDrag;

  /// That drag let go, with its vertical velocity.
  final ValueChanged<double> onPanelEnd;

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

  /// Which way this drag went first: up opens the panel (Instagram), down
  /// dismisses. Decided on the first movement and kept for the whole drag.
  bool? _toPanel;

  void _onDragStart(DragStartDetails _) {
    _settle.stop();
    _toPanel = null;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // While zoomed the same gesture is panning the image.
    if (_zoomed || _dismissing) return;
    _toPanel ??= d.delta.dy < 0 && widget.drag.value == Offset.zero;
    if (_toPanel!) {
      widget.onPanelDrag(d.delta.dy);
      return;
    }
    widget.drag.value += Offset(0, d.delta.dy);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_toPanel == true) {
      _toPanel = null;
      widget.onPanelEnd(d.velocity.pixelsPerSecond.dy);
      return;
    }
    _toPanel = null;
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
              // Always wrapped (Opacity at 1 paints straight through): adding
              // the wrapper as a dismiss drag starts and dropping it as the
              // photo snaps back remounted the chrome, its state and all.
              child: Opacity(opacity: opacity, child: child),
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
    // Plain segments, not glass: glass is for the things you press, and these
    // are read. A short, light shade at the card's top edge keeps them (and
    // the name under them) legible on a bright sky, and fades out well before
    // the photo's subject.
    return IgnorePointer(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: pad.top),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_kStoryCardRadius),
              ),
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x52000000),
                      Color(0x26000000),
                      Color(0x00000000),
                    ],
                    stops: [0, 0.45, 1],
                  ),
                ),
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

  // Tight gaps and a quiet track, so the one bright segment (where you are)
  // leads and the rest read as a single thin rule.
  static const _gap = 3.0;
  static const _track = Color(0x4DFFFFFF);

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

/// Who posted it and when, and the two ways out of the picture: a menu and
/// the close.
///
/// The story's chrome is all plain: white type and white glyphs on a soft
/// shadow, one language with the progress bar above and the comment field
/// below, so nothing on top competes with the photograph. Two controls: ⋯
/// (fit or fill, delete; gone when it would hold nothing) and ×.
///
/// The leading edge is the person, as one tap target: ringed face, name over
/// time, opening their profile when the host lends a route to it.
///
/// **The × is TRAILING here, deliberately**: the one exception to "× leads",
/// the stories convention (Instagram, iOS).
class _StageTopBar extends StatelessWidget {
  const _StageTopBar({
    required this.moment,
    required this.api,
    required this.onClose,
    required this.onDelete,
    required this.onToggleFill,
    required this.filled,
    required this.onOpenAuthor,
  });

  final Moment moment;
  final ChatApi api;
  final VoidCallback onClose;

  /// Null unless the moment is the viewer's own.
  final VoidCallback? onDelete;

  /// Switches between filling the screen and showing the whole frame. Null when
  /// this picture is shown whole either way; see `_MomentStageState._fill`.
  final VoidCallback? onToggleFill;

  /// Which of the two states the picture is in now, for the menu's glyph.
  final bool filled;

  /// Opens the author's profile; null for your own or with no route lent.
  final VoidCallback? onOpenAuthor;

  static const _shadow = [Shadow(color: Color(0x80000000), blurRadius: 8)];

  Future<void> _menu(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    final choice = await showIosActionSheet<String>(
      context,
      actions: [
        if (onToggleFill != null)
          IosSheetAction(
            label: l10n.photoChromeFillToggleSemanticLabel,
            value: 'fill',
            icon: filled
                ? CupertinoIcons.arrow_down_right_arrow_up_left
                : CupertinoIcons.arrow_up_left_arrow_down_right,
          ),
        if (onDelete != null)
          IosSheetAction(
            label: l10n.momentViewerDelete,
            value: 'delete',
            destructive: true,
            icon: CupertinoIcons.trash,
          ),
      ],
    );
    switch (choice) {
      case 'fill':
        onToggleFill?.call();
      case 'delete':
        onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final pad = MediaQuery.paddingOf(context);
    final hasMenu = onToggleFill != null || onDelete != null;
    final name = moment.mine
        ? sentenceCaseOf(context, l10n.momentRailYouLabel)
        : moment.authorName;

    final author = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AuthorDot(moment: moment, api: api),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.bodyEmph.copyWith(
                  fontSize: 15,
                  height: 1.15,
                  color: MediaGlass.ink,
                  shadows: _shadow,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _ago(l10n, moment.createdAt),
                style: theme.caption.copyWith(
                  fontSize: 12,
                  height: 1.2,
                  color: MediaGlass.ink.withValues(alpha: 0.82),
                  fontFeatures: const [FontFeature.tabularFigures()],
                  shadows: _shadow,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
    final open = onOpenAuthor;

    // Just under the progress bar, which sits 8 below the card's top edge.
    return Padding(
      // Just under the progress bar, which sits 8 below the card's top edge.
      padding: EdgeInsets.fromLTRB(12, pad.top + 18, 4, 8),
      child: Row(
        children: [
          // The person, as type: read, not pressed, so no glass. Still one
          // tap target to their profile.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: open == null
                  ? author
                  : FocusableTap(
                      onTap: open,
                      semanticLabel: name,
                      shape: FocusRingShape.capsule,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: open,
                        child: author,
                      ),
                    ),
            ),
          ),
          if (hasMenu)
            _ChromeGlyph(
              icon: CupertinoIcons.ellipsis,
              semanticLabel: MaterialLocalizations.of(context).moreButtonTooltip,
              onTap: () => _menu(context),
            ),
          _ChromeGlyph(
            icon: CupertinoIcons.xmark,
            semanticLabel: l10n.photoChromeCloseSemanticLabel,
            onTap: onClose,
          ),
        ],
      ),
    );
  }

  /// Compact relative time, matching the activity river's: everything on this
  /// board is from today, so it never needs a date.
  static String _ago(AppLocalizations l10n, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return l10n.momentActivityJustNow;
    if (d.inHours < 1) return l10n.momentActivityMinutesAgo(d.inMinutes);
    return l10n.momentActivityHoursAgo(d.inHours);
  }
}

/// A plain white glyph over the story on a soft shadow: the top bar's
/// buttons. 44pt to hit, springy to press.
class _ChromeGlyph extends StatelessWidget {
  const _ChromeGlyph({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      semanticLabel: semanticLabel,
      focusShape: FocusRingShape.circle,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          icon,
          size: 24,
          color: MediaGlass.ink,
          shadows: const [Shadow(color: Color(0x80000000), blurRadius: 8)],
        ),
      ),
    );
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
        // A crisp white ring, the stories mark for "a person", and what keeps
        // the face separate from whatever photo it sits on.
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
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

/// The height of the black comment bar under a story, before the safe area.
const double _kCommentBar = 60;

/// How far the progress bar and the author row reach down into the story
/// card, below the safe area. The reply mode keeps its content clear of it.
const double _kTopBand = 62;

/// The story card's corner radius: Instagram's, enough to read as a card on
/// the black, not so much that it eats the corners of the photo.
const double _kStoryCardRadius = 14;

/// The tag and the words, over the bottom of the picture just above the bar.
///
/// No gradient and no glass under them: the stage is black, and a shadow is
/// enough to keep white text legible where a photograph runs bright.
class _StageCaption extends StatelessWidget {
  const _StageCaption({required this.moment});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final caption = moment.caption;
    final hasCaption = caption != null && caption.isNotEmpty;
    if (moment.tag == null && !hasCaption) return const SizedBox.shrink();
    // Read, not pressed: plain type on a soft shadow, no card.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (moment.tag != null) ...[
            MomentTagChip(tag: moment.tag!),
            if (hasCaption) const SizedBox(height: 10),
          ],
          if (hasCaption)
            Text(
              caption,
              style: theme.body.copyWith(
                color: MediaGlass.ink,
                decoration: TextDecoration.none,
                shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 10),
                ],
              ),
              // Enough for a paragraph, capped so a wall of text cannot
              // swallow the photograph it is about.
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// The black floor of a story: a comment field and the reactions door.
///
/// Instagram's reply bar. The field is the door rather than a live text
/// field: a tap opens the panel with the real composer focused in it, so
/// typing always happens where the conversation is visible. The smiley opens
/// the same panel without the keyboard, on the reactions.
class _StageCommentBar extends StatelessWidget {
  const _StageCommentBar({
    required this.height,
    required this.count,
    required this.onField,
    required this.onComments,
  });

  final double height;
  final int count;

  /// Opens the reply mode with the keyboard up, to write.
  final VoidCallback onField;


  /// Opens the whole conversation.
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hint = l10n.momentCommentHint;
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottom),
        child: SizedBox(
          height: height - 8,
          child: Row(
            children: [
              Expanded(
                // A plain outlined field, the same language as the type above
                // it, with the conversation's size at its trailing end. The
                // field opens the reply mode (keyboard and the big reactions
                // together); the count opens the conversation.
                child: Semantics(
                  button: true,
                  label: hint,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onField,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: MediaGlass.ink.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(start: 18),
                              child: Text(
                                hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.body.copyWith(
                                  fontSize: 16,
                                  color: MediaGlass.inkDim,
                                ),
                              ),
                            ),
                          ),
                          if (count > 0)
                            FocusableTap(
                              onTap: onComments,
                              semanticLabel: l10n.momentCommentsCount(count),
                              shape: FocusRingShape.capsule,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onComments,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: SizedBox(
                                    height: 44,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          CupertinoIcons.chat_bubble,
                                          size: 18,
                                          color: MediaGlass.ink,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$count',
                                          style: theme.body.copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: MediaGlass.ink,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 14),
                        ],
                      ),
                    ),
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

/// The preset reactions, big, in Instagram's three by two grid over the
/// dimmed story, with a + for any emoji at all.
///
/// One tap leaves a reaction (or takes yours back) and closes the reply mode;
/// a long press says who is behind one. Yours sit on an accent disc, and a
/// small count under each says how many people chose it.
class _ReplyEmojiGrid extends StatelessWidget {
  const _ReplyEmojiGrid({
    required this.emojis,
    required this.reactions,
    required this.onTap,
    required this.onLongPress,
    required this.onMore,
  });

  final List<String> emojis;
  final _Reactions reactions;

  /// [origin] is the tapped emoji's centre on screen, where its burst starts.
  final void Function(String emoji, Offset origin) onTap;
  final void Function(String emoji) onLongPress;
  final VoidCallback onMore;

  static const double _cell = 96;

  @override
  Widget build(BuildContext context) {
    final more = AppLocalizations.of(context).stickerMakerMoreEmoji;
    final cells = <Widget>[
      for (final (i, e) in emojis.indexed)
        _GridPop(
          index: i,
          child: _ReplyEmoji(
            key: ValueKey(e),
            emoji: e,
            count: reactions.counts[e] ?? 0,
            active: reactions.mine.contains(e),
            onTap: (origin) => onTap(e, origin),
            onLongPress: () => onLongPress(e),
          ),
        ),
      _GridPop(
        index: emojis.length,
        child: SizedBox(
        width: _cell,
        height: _cell + 18,
        child: Align(
          alignment: Alignment.topCenter,
          child: SpringPress(
            onTap: onMore,
            semanticLabel: more,
            focusShape: FocusRingShape.circle,
            child: Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.only(top: 12),
              // An outline, not a fill: a filled disc is what "yours" looks
              // like in this grid, and the + must never read as chosen.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.38),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                CupertinoIcons.add,
                size: 34,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
      ),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: cells,
    );
  }
}

class _ReplyEmoji extends StatelessWidget {
  const _ReplyEmoji({
    super.key,
    required this.emoji,
    required this.count,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  final String emoji;
  final int count;
  final bool active;
  final ValueChanged<Offset> onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    void tap() {
      final box = context.findRenderObject() as RenderBox?;
      final center = box == null || !box.attached
          ? Offset.zero
          : box.localToGlobal(
              const Offset(_ReplyEmojiGrid._cell / 2, _ReplyEmojiGrid._cell / 2),
            );
      onTap(center);
    }

    return SizedBox(
      width: _ReplyEmojiGrid._cell,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusableTap(
            onTap: tap,
            semanticLabel: emoji,
            selected: active,
            shape: FocusRingShape.circle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tap,
              onLongPress: count > 0 ? onLongPress : null,
              onSecondaryTap: count > 0 ? onLongPress : null,
              // Yours sits on a soft frosted disc: the selected state of the
              // reaction trays people already know (WhatsApp, iMessage),
              // a filled background and nothing else. No outline, no accent
              // tint: a ring read as a focus border, and a lone dot under the
              // emoji did not read as "yours" at all.
              child: SpringPress.passive(
                child: SizedBox(
                  width: _ReplyEmojiGrid._cell,
                  height: _ReplyEmojiGrid._cell,
                  child: Center(
                    child: AnimatedContainer(
                      duration: theme.motionFast,
                      curve: Curves.easeOutCubic,
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: active ? 0.24 : 0,
                        ),
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(
                          fontSize: 58,
                          height: 1.1,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 18,
            child: count > 0
                ? Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? MediaGlass.ink : MediaGlass.inkDim,
                      decoration: TextDecoration.none,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// One cell of the reply grid arriving: a springy pop with a little twist,
/// staggered across the grid, every time the reply mode opens (the grid is
/// built fresh each time). Nothing under Reduce Motion.
class _GridPop extends StatefulWidget {
  const _GridPop({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_GridPop> createState() => _GridPopState();
}

class _GridPopState extends State<_GridPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 620 + widget.index * 55),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(
      (widget.index * 55) / (620 + widget.index * 55),
      1,
      curve: Curves.elasticOut,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MotionScope.of(context).calm) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Alternate cells twist opposite ways, so the grid lands with some life
    // rather than as one block scaling up.
    final twist = widget.index.isEven ? -0.35 : 0.35;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        if (v >= 1 && _c.isCompleted) return child!;
        return Opacity(
          opacity: (v * 3).clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: twist * (1 - v.clamp(0.0, 1.0)),
            child: Transform.scale(scale: 0.2 + 0.8 * v, child: child),
          ),
        );
      },
    );
  }
}

/// The reaction you just sent, rising: a handful of copies of the emoji
/// floating up from where you tapped it and fading, Instagram's send.
///
/// One controller drives every copy; their paths are fixed per burst from a
/// seeded random so a burst never jitters as it plays. Purely decorative and
/// out of the hit test; it removes itself when done.
class _EmojiBurst extends StatefulWidget {
  const _EmojiBurst({
    super.key,
    required this.emoji,
    required this.origin,
    required this.onDone,
  });

  final String emoji;
  final Offset origin;
  final VoidCallback onDone;

  @override
  State<_EmojiBurst> createState() => _EmojiBurstState();
}

class _EmojiBurstState extends State<_EmojiBurst>
    with SingleTickerProviderStateMixin {
  static const _copies = 9;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  /// Per copy: sideways drift, rise, size, start delay (0..1 of the run), sway.
  late final List<(double, double, double, double, double)> _paths = () {
    final rnd = math.Random(widget.origin.hashCode ^ widget.emoji.hashCode);
    return [
      for (var i = 0; i < _copies; i++)
        (
          (rnd.nextDouble() * 2 - 1) * 110,
          260 + rnd.nextDouble() * 260,
          0.55 + rnd.nextDouble() * 0.7,
          rnd.nextDouble() * 0.28,
          (rnd.nextDouble() * 2 - 1) * 18,
        ),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final (dx, rise, size, delay, sway) in _paths)
                _copy(t, dx, rise, size, delay, sway),
            ],
          );
        },
      ),
    );
  }

  Widget _copy(
    double t,
    double dx,
    double rise,
    double size,
    double delay,
    double sway,
  ) {
    final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    if (local <= 0) return const SizedBox.shrink();
    final up = Curves.easeOutCubic.transform(local);
    final fade = local < 0.6 ? 1.0 : 1 - (local - 0.6) / 0.4;
    final grow = Curves.easeOutBack.transform((local * 2.5).clamp(0.0, 1.0));
    const glyph = 46.0;
    return Positioned(
      left: widget.origin.dx + dx * up + math.sin(local * math.pi * 2) * sway -
          glyph / 2,
      top: widget.origin.dy - rise * up - glyph / 2,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: size * grow,
          child: Text(
            widget.emoji,
            style: const TextStyle(
              fontSize: glyph,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// "View all 12 comments" under the reply grid: the way from the quick reply
/// to the whole conversation.
class _ViewCommentsLink extends StatelessWidget {
  const _ViewCommentsLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      focusShape: FocusRingShape.capsule,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.chat_bubble_2, size: 17, color: MediaGlass.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.bodyEmph.copyWith(
                fontSize: 15,
                color: MediaGlass.ink,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card viewer: points and caption-only moments
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
    this.openComments = false,
    this.onOpenProfile,
    this.faces = _Faces.none,
  });

  /// See [_Faces].
  final _Faces faces;

  final Moment moment;
  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  /// See [showMomentViewer].
  final Rect? origin;

  /// See [showMomentViewer].
  final void Function(ChatUser user)? onOpenProfile;

  /// Opens the comments once the card has risen — a comment notification.
  final bool openComments;

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
    onLimit: () {
      if (mounted) {
        showReactionLimitNotice(context, surface: ReactionLimitSurface.moment);
      }
    },
  );

  Future<void> _comments() => _openComments(
        context,
        _book,
        m: widget.moment,
        api: widget.api,
        feedApi: widget.feedApi,
        userId: widget.userId,
        onOpenProfile: widget.onOpenProfile,
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
    if (widget.openComments) {
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _comments();
      });
    }
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
    final reactors = widget.faces.fill(_book.of(widget.moment).reactors);
    if (reactors.isEmpty) return;
    HapticFeedback.mediumImpact();
    showMomentReactions(
      context,
      reactors: reactors,
      api: widget.api,
      viewerId: widget.userId,
      initialEmoji: emoji,
      onOpenProfile: widget.onOpenProfile,
    );
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
                  commentCount: _book.commentsOf(m),
                  onComments: _comments,
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
    required this.commentCount,
    required this.onComments,
  });

  final List<String> emojis;
  final _Reactions reactions;
  final void Function(String emoji) onTap;

  /// Long-press a pill to see who's behind it.
  final void Function(String emoji) onLongPress;

  /// Opens the full emoji picker: the quick set is a shortcut, not a limit.
  final VoidCallback onMore;

  final int commentCount;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          // A desk mouse's one wheel reaches the end of the row too.
          child: HorizontalWheelScroll(
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
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: _CommentsPill(
            count: commentCount,
            onTap: onComments,
            overPhoto: false,
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
