import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/media_aspect_cache.dart';
import '../models/moment.dart';
import '../models/moment_group.dart';
import '../theme/motion.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'meta_text.dart';
import 'photo_chrome.dart' show MediaPlayDisc;
import 'remote_image.dart';
import 'steady_hero.dart';
import 'user_avatar.dart';

import 'ios_kit.dart' show SpringPress, TileTone, ToneTile, groupedFill, tileColor;
import 'chat_list_row.dart' show monogramGradient;
import '../l10n/text_case.dart';

/// Hero tag for a moment's picture, shared by every surface that renders one.
///
/// Lives here beside [MomentTagChip] rather than in the viewer, because the
/// *sources* of the flight — this rail, the archive grid — are widgets, and
/// having them reach into a screen for a tag is how an import cycle starts. A
/// tag is only ever live in one route at a time (the rail carries untagged
/// highlights, the standings board carries tagged points, and the archive is its
/// own route), so two heroes can never claim the same one.
Object momentMediaHeroTag(String momentId) => 'moment_media_$momentId';

/// The decode width, in device pixels, every moment thumbnail in the app asks
/// for.
///
/// One constant because the viewer passes it back as its
/// `placeholderDecodeWidth`: hand it a different number and that is a different
/// `ImageCache` entry, which always misses, which lands the flight on a shimmer.
const int momentThumbDecodeWidth = 248;

/// The on-screen rect of [context]'s own box.
///
/// For rows that have no picture to fly — a point, an activity line — the
/// viewer grows out of this instead, so the card still comes from the thing that
/// was tapped. Null when there is no laid-out box to measure, which the caller
/// is expected to treat as "no origin, just fade in".
Rect? tapOriginRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The horizontal rail of today's highlights, capture tile first, then one
/// card per person (see [MomentGroup]).
///
/// Three things this widget is careful about, each of which is a real bug in
/// this codebase's history:
///
///  * **A horizontal ListView imposes its cross-axis height as a hard
///    constraint, not a floor.** A flat `SizedBox(height: 168)` clips captions
///    at accessibility text sizes, and nothing in this app clamps
///    `textScaler`. The height is scaled and clamped the way `RoomFilterBar`
///    does it.
///  * **`FocusableTap`'s ring paints outside the child's bounds**, so inside a
///    horizontal scroll view it gets clipped. The rail carries vertical
///    padding for it, as `reaction_details_sheet.dart` does.
///  * **Cards are keyed by person, never by index.** The rail reorders as
///    moments arrive and as people are seen through, and an index key hands
///    a tile someone else's photo — which then reloads, briefly showing the
///    wrong face.
class MomentRail extends StatelessWidget {
  const MomentRail({
    super.key,
    required this.groups,
    required this.api,
    required this.serverNow,
    required this.onCapture,
    required this.onOpen,
    this.canCapture = true,
    this.inset = 0,
  });

  /// The page's side margin, laid INSIDE the scroll view: the row runs to
  /// the screen's edges and cards scroll off them, while at rest the first
  /// one still lines up with the band's header.
  final double inset;

  final List<MomentGroup> groups;
  final ChatApi api;

  /// The server's clock, not the device's — see [FeedStore.serverNow].
  final DateTime serverNow;

  final VoidCallback onCapture;

  /// A card's tap, with the item to begin on ([MomentGroup.start]).
  final void Function(Moment moment) onOpen;

  /// False for a supervised account whose guardian has switched media off. The
  /// tile stays visible but inert, so the child can see what the board is
  /// rather than finding a hole where everyone else has a button.
  final bool canCapture;

  /// Base card height. Scaled by the text scaler and clamped, because the
  /// caption underneath must not clip at large accessibility sizes.
  static const _baseHeight = 168.0;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(
      context,
    ).scale(_baseHeight).clamp(_baseHeight, 232.0);
    // Your own card carries the "+", so the capture tile only stands in
    // while you have nothing up today: one slot for you, as on Instagram.
    final hasOwn = groups.any((g) => g.mine);

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // Vertical room for FocusableTap's ring, which paints outside the
        // child's bounds and would otherwise be clipped by this scroll view.
        padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
        // A fan swings past its card's slot; it may pass the viewport's
        // edge too, rather than being sliced off by it.
        clipBehavior: Clip.none,
        children: [
          if (!hasOwn) _CaptureTile(onTap: canCapture ? onCapture : null),
          for (var i = 0; i < groups.length; i++)
            Padding(
              key: ValueKey('rail_person_${groups[i].userId}'),
              padding: EdgeInsets.only(
                left: i == 0 && hasOwn ? 0 : _cardGap,
                // The room this card's fan swings into, so the space to the
                // next card reads the same as everywhere else.
                right: _fanOverhang(
                  (groups[i].items.length - 1).clamp(0, _deckMax),
                  height - 8,
                ),
              ),
              child: _MomentCard(
                group: groups[i],
                api: api,
                serverNow: serverNow,
                index: i,
                onTap: () => onOpen(groups[i].start),
                onAdd: groups[i].mine && canCapture ? onCapture : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// The leading "add something" tile.
class _CaptureTile extends StatelessWidget {
  const _CaptureTile({required this.onTap});

  /// Null disables it — the supervised-account case.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final enabled = onTap != null;

    // A story card of its own: the soft grouped fill, a filled "+" in the
    // middle, the label under it — "add yours" at the head of the row, the
    // Instagram / Telegram slot. Dimmed rather than hidden when disabled,
    // matching ProfileVisibilityScreen's read-only treatment.
    return Padding(
      // Level with the cards' faces, under the room their stacks rise into.
      padding: const EdgeInsets.only(top: _stackRise),
      child: Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: l10n.momentRailCaptureLabel,
        // The label says it once; the visible text under the "+" would
        // merge in and have it read twice.
        child: ExcludeSemantics(
        child: Container(
          width: _storyWidth,
          decoration: BoxDecoration(
            color: groupedFill(theme),
            borderRadius: BorderRadius.circular(_storyRadius),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.bubbleFill(isMine: true),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.plus,
                  size: 22,
                  color: theme.accentInk,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sentenceCaseOf(context, l10n.momentRailCaptureLabel),
                textAlign: TextAlign.center,
                // The body face at meta size — never the theme's caption, which
                // is tracked monospace on character themes. Wraps, then
                // shrinks: a tile label never ellipsizes.
                style: metaText(theme, color: theme.ink).copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        ),
      ),
      ),
    );
  }
}

/// A story card's width and corner — shared by the capture slot and every
/// moment so the row is one rhythm.
const double _storyWidth = 104;
const double _storyRadius = 18;

/// The room every tile keeps at its top so the faces of the row line up,
/// and the cards behind have somewhere to rise into.
const double _stackRise = 14;

/// The most cards a deck shows behind its cover: three cards in all. Past
/// that, the back card carries how many more there are (see [_DeckMore]).
const int _deckMax = 2;

/// How high each card behind sits above the cover, by depth (index 0 is the
/// cover). The second step lifts less than the first, the way a held hand
/// of cards fans. The back one rises a touch past the tile's own top, into
/// the rail's padding.
const List<double> _sheetLift = [0, 8, 14];

/// The inward step of each card behind, per side.
const double _sheetInset = 3;

/// Where the cards behind stop short of the card's foot, so their pivot
/// stays hidden behind the face.
const double _sheetFoot = 24;

/// How far each card behind is turned clockwise, in radians, by depth:
/// about 8°, then 6° more, easing off the way a hand of cards fans.
const List<double> _fanTurn = [0, 0.14, 0.245];

/// Space between cards on the rail, the same between any two neighbours: a
/// card with a fan adds exactly what its fan swings out (see
/// [_fanOverhang]), so the gap is measured from the fan, not the face.
const double _cardGap = 10;

/// How far a card's fan reaches past its right edge, for a card [height]
/// tall with [behind] cards behind it. The furthest point of a turned card
/// is on its top-right corner's arc: that arc's centre, turned about the
/// card's foot, plus the radius.
double _fanOverhang(int behind, double height) {
  var most = 0.0;
  for (var k = 1; k <= behind; k++) {
    final top = _stackRise - _sheetLift[k];
    final w = _storyWidth - 2 * k * _sheetInset;
    final h = height - top - _sheetFoot;
    final r = _storyRadius - k;
    final turn = _fanTurn[k];
    final x = (w / 2 - r) * math.cos(turn) + (h - r) * math.sin(turn) + r;
    most = math.max(most, x - _storyWidth / 2);
  }
  return most;
}

/// One person's card, drawn as the stack it opens: their picture on top
/// (the one a tap begins on), and when there is more than one, up to two
/// cards fanned up behind it. How many is felt rather than counted; the
/// exact number is read out to a screen reader. Their face and name sit at
/// the foot. Yours wears a "+" for adding another.
class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.group,
    required this.api,
    required this.serverNow,
    required this.index,
    required this.onTap,
    this.onAdd,
  });

  final MomentGroup group;
  final ChatApi api;
  final DateTime serverNow;
  final int index;
  final VoidCallback onTap;

  /// The "+" on your own card; null hides it.
  final VoidCallback? onAdd;

  /// The item on the [depth]th card behind: the ones that play after the
  /// cover, in order, so the stack shows what comes next.
  Moment _behindAt(int depth) {
    final items = group.items;
    final at = items.indexWhere((m) => m.id == group.start.id);
    return items[(at + depth) % items.length];
  }

  String _semantics(AppLocalizations l10n) {
    final fresh = group.items.where((m) => !m.mine && !m.seen).length;
    return [
      group.mine ? l10n.momentRailYouLabel : group.latest.authorName,
      l10n.momentRailPersonCount(group.items.length),
      if (fresh > 0) l10n.momentRailPersonNewCount(fresh),
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    // The cover is where a tap begins, so the picture on the card is the
    // one the viewer opens on, and the flight leaves from it.
    final moment = group.start;
    final unseen = group.unseen;
    final behind = (group.items.length - 1).clamp(0, _deckMax);
    // What the deck cannot hold, counted on its back card.
    final more = group.items.length - 1 - behind;
    final add = onAdd;

    final face = Container(
      padding: EdgeInsets.all(unseen ? 2.5 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_storyRadius + 2.5),
        // An unseen story wears a ring in the theme's colours, set off from
        // the picture by a hairline of page: the universal "new" mark.
        gradient: unseen ? _ringGradient(theme) : null,
      ),
      child: Container(
        padding: EdgeInsets.all(unseen ? 2 : 0),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(_storyRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            unseen ? _storyRadius - 2 : _storyRadius,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Thumb(moment: moment, api: api, unseen: unseen),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _Byline(
                  group: group,
                  api: api,
                  name: group.mine
                      ? l10n.momentRailYouLabel
                      : group.latest.authorName,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      // Identity key, never index — see the class doc.
      key: ValueKey('rail_${group.userId}'),
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(
        const Duration(milliseconds: 520),
        index,
        strideMs: 55,
      ),
      // Pops in on a spring — a scale past 1 and back, the Telegram story
      // arrival. Scale rather than a slide, so nothing overshoots the rail's
      // edge and gets clipped.
      curve: motion.c(const ElasticOutCurve(0.75)),
      builder: (context, v, child) => Transform.scale(
        scale: 0.86 + 0.14 * v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: SizedBox(
        width: _storyWidth,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: SpringPress(
                onTap: onTap,
                haptic: false,
                semanticLabel: _semantics(l10n),
                focusRadius: _storyRadius,
                child: ExcludeSemantics(
                  child: Stack(
                    fit: StackFit.expand,
                    // The back card rises past the tile's top: a Stack that
                    // overflows clips by default, and would slice it flat.
                    clipBehavior: Clip.none,
                    children: [
                      // Back to front, each a step narrower and higher.
                      for (var k = behind; k >= 1; k--)
                        Positioned(
                          top: _stackRise - _sheetLift[k],
                          left: k * _sheetInset,
                          right: k * _sheetInset,
                          bottom: _sheetFoot,
                          // Fanned clockwise from the foot, a hand of
                          // cards: the corners swing out top-right, into
                          // the gap before the next card.
                          child: Transform.rotate(
                            angle: _fanTurn[k],
                            alignment: Alignment.bottomCenter,
                            child: _BehindCard(
                              moment: _behindAt(k),
                              api: api,
                              depth: k,
                              fill: _sheetColor(theme, unseen, k),
                            ),
                          ),
                        ),
                      // The back card's "+N", over the whole deck. Drawn
                      // with the card, the cards in front painted over it
                      // and cut the "+" off. Same frame and turn as the
                      // back card, so it still sits on that card's corner,
                      // the part of it the deck leaves showing.
                      if (more > 0)
                        Positioned(
                          top: _stackRise - _sheetLift[behind],
                          left: behind * _sheetInset,
                          right: behind * _sheetInset,
                          bottom: _sheetFoot,
                          child: Transform.rotate(
                            angle: _fanTurn[behind],
                            alignment: Alignment.bottomCenter,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  top: -6,
                                  right: -2,
                                  child: _DeckMore(count: more),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned.fill(top: _stackRise, child: face),
                    ],
                  ),
                ),
              ),
            ),
            if (add != null)
              Positioned(
                top: _stackRise - 6,
                right: -6,
                child: _AddBadge(onTap: add),
              ),
          ],
        ),
      ),
    );
  }

  static LinearGradient _ringGradient(AppTheme theme) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.accent,
          Color.lerp(theme.accent, const Color(0xFFFF2D55), 0.65)!,
        ],
      );

  /// The cards fanned behind: in the ring's colour while something is new,
  /// quiet ink once all of it is seen; fainter the further back.
  static Color _sheetColor(AppTheme theme, bool unseen, int depth) {
    final base = unseen ? theme.accent : theme.ink;
    final alpha = unseen
        ? const [0.0, 0.7, 0.46][depth]
        : const [0.0, 0.3, 0.2][depth];
    return Color.alphaBlend(base.withValues(alpha: alpha), theme.background);
  }
}

/// A card behind a person's cover: that item's own picture, dimmed deeper
/// the further back it sits so the cover stays in charge. A words-only item,
/// or one still loading, shows [fill] alone.
///
/// The decode is the rail's own thumbnail size, so the viewer finds these
/// already in memory when the person is opened.
class _BehindCard extends StatelessWidget {
  const _BehindCard({
    required this.moment,
    required this.api,
    required this.depth,
    required this.fill,
  });

  final Moment moment;
  final ChatApi api;
  final int depth;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final thumb = moment.thumbStorageId;
    final radius = BorderRadius.circular(_storyRadius - depth);
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: fill),
          if (thumb != null) ...[
            RemoteImage(
              storageId: thumb,
              api: api,
              fit: BoxFit.cover,
              decodeWidth: momentThumbDecodeWidth,
              borderRadius: radius,
              quiet: true,
            ),
            ColoredBox(
              color: Colors.black.withValues(
                alpha: const [0.0, 0.26, 0.46][depth],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "+N" on a deck's back card: the items the deck has no card for. A small
/// dark tag in the app's chrome family (the photo viewer's discs), so it
/// holds over any picture. The exact count is in the card's spoken label;
/// this is for the eye.
class _DeckMore extends StatelessWidget {
  const _DeckMore({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        '+$count',
        style: metaText(theme, color: Colors.white).copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 11,
          height: 1.1,
        ),
      ),
    );
  }
}

/// The foot of a card: the person's face and name over a fade.
class _Byline extends StatelessWidget {
  const _Byline({required this.group, required this.api, required this.name});

  final MomentGroup group;
  final ChatApi api;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final author = group.latest;
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 22, 8, 7),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0xA6000000)],
          ),
        ),
        child: Row(
          children: [
            // Ringed in white, like the name beside it: the face has to
            // hold against any photograph.
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: UserAvatar(
                user: ChatUser(
                  id: group.userId,
                  username: author.authorUsername,
                  name: author.authorName,
                  avatarStorageId: author.authorAvatarStorageId,
                ),
                api: api,
                size: 22,
                showStatus: false,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: metaText(theme, color: Colors.white).copyWith(
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(color: Color(0x66000000), blurRadius: 4),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "+" on your own card: add another highlight without hunting for the
/// capture tile, which steps aside once you have a card (Instagram's "your
/// story" plus). A 26pt disc in a 40pt target.
class _AddBadge extends StatelessWidget {
  const _AddBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.momentRailAddHighlight,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.accent,
              shape: BoxShape.circle,
              border: Border.all(color: theme.background, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.plus,
              size: 14,
              color: theme.accentInk,
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.moment, required this.api, required this.unseen});

  final Moment moment;
  final ChatApi api;
  final bool unseen;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Null for a video with no poster frame, which keeps the glyph permanently
    // — a designed state, not a placeholder. See [Moment.thumbStorageId].
    final thumbId = moment.thumbStorageId;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbId != null)
          // The picture itself flies to the viewer — not the card around it.
          // Wrapping the card would hand the flight a rect whose contents differ
          // at the two ends, and the shuttle would have to invent something to
          // paint in between. The photograph is the one thing both ends agree on.
          SteadyHero(
            tag: momentMediaHeroTag(moment.id),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_storyRadius - 2),
              child: RemoteImage(
                storageId: thumbId,
                api: api,
                fit: BoxFit.cover,
                // One axis only. Passing both width and height here squashes the
                // bitmap before `fit` runs — ResizeImagePolicy.exact behaves like
                // BoxFit.fill — which is what stretched every non-square tile in
                // an earlier build.
                decodeWidth: momentThumbDecodeWidth,
                // Recorded while this decode is happening anyway, for the
                // fullscreen viewer's benefit rather than this tile's — the
                // tile crops to a fixed box and does not care. Without it, the
                // FIRST time a picture is opened the viewer has no ratio to pin
                // its box to and the Hero flight lands on a full-screen rect
                // before snapping down into the photograph's real one: the
                // two-step jump. See `_StagePageState._aspect`.
                onAspectRatio: (a) =>
                    MediaAspectCache.instance.remember(thumbId, a),
              ),
            ),
          )
        else
          // A words-only moment: a text story, the caption set large on its
          // author's own colour.
          Container(
            decoration: BoxDecoration(
              gradient: monogramGradient(theme, moment.authorName.hashCode),
            ),
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 30),
            alignment: Alignment.center,
            child: Text(
              moment.caption ?? '',
              textAlign: TextAlign.center,
              style: theme.bodyEmph.copyWith(
                fontSize: 15,
                height: 1.25,
                color: Colors.white,
                fontStyle: FontStyle.normal,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (moment.mediaKind == MomentMedia.video)
          const Center(child: MediaPlayDisc(size: 36)),
        if (moment.tag != null)
          Positioned(
            left: 4,
            top: 4,
            child: MomentTagChip(tag: moment.tag!, dense: true),
          ),
      ],
    );
  }
}

/// The mark for "you have not looked at this yet".
///
/// One widget because it now appears in three places that must agree — the
/// highlights rail's thumbnails, the standings lines and the activity river —
/// and three hand-drawn circles is how three circles end up three different
/// sizes. It was only on the rail before, and at 8pt over a photograph it was
/// small enough to miss entirely.
///
/// The ring is doing real work: the dot lands on an arbitrary photograph as
/// often as on a flat surface, and an accent circle on a photograph of the same
/// colour is invisible without one.
class MomentUnseenDot extends StatelessWidget {
  const MomentUnseenDot({super.key, this.size = 13});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.accent,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.background,
          width: (size * 0.17).clamp(1.2, 2.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

/// The little badge naming a moment's scoring category.
///
/// Public because the viewer, the composer and the standings board all render
/// it, and three copies of a chip is how three chips drift apart.
class MomentTagChip extends StatelessWidget {
  const MomentTagChip({super.key, required this.tag, this.dense = false});

  final MomentTag tag;
  final bool dense;

  /// The glyph for each category.
  ///
  /// Drawn glyphs rather than emoji on purpose: emoji render in the system
  /// font at a size and colour this app cannot control, which breaks against
  /// thirteen palettes — four of them light — and looks pasted-on next to the
  /// theme's own drawn marks. Cupertino, like every other glyph in the app.
  static IconData iconFor(MomentTag tag) => switch (tag) {
    MomentTag.fate => CupertinoIcons.sparkles,
    MomentTag.jinx => CupertinoIcons.bolt_fill,
    MomentTag.luck => CupertinoIcons.rosette,
    MomentTag.calledIt => CupertinoIcons.eye,
    // "Brain fully off."
    MomentTag.npc => CupertinoIcons.zzz,
  };

  /// Each category's own colour, a fixed tile tone: the explainer's tiles,
  /// the composer's picker and every mark on the board share it, so Jinx is
  /// orange wherever it is.
  static TileTone toneFor(MomentTag tag) => switch (tag) {
    MomentTag.fate => TileTone.purple,
    MomentTag.jinx => TileTone.orange,
    MomentTag.luck => TileTone.green,
    MomentTag.calledIt => TileTone.blue,
    MomentTag.npc => TileTone.gray,
  };

  /// The localized name of a category.
  static String labelFor(AppLocalizations l10n, MomentTag tag) => switch (tag) {
    MomentTag.fate => l10n.momentTagFate,
    MomentTag.jinx => l10n.momentTagJinx,
    MomentTag.luck => l10n.momentTagLuck,
    MomentTag.calledIt => l10n.momentTagCalledIt,
    MomentTag.npc => l10n.momentTagNpc,
  };

  /// The one-line explanation shown in the composer's picker.
  static String hintFor(AppLocalizations l10n, MomentTag tag) => switch (tag) {
    MomentTag.fate => l10n.momentTagFateHint,
    MomentTag.jinx => l10n.momentTagJinxHint,
    MomentTag.luck => l10n.momentTagLuckHint,
    MomentTag.calledIt => l10n.momentTagCalledItHint,
    MomentTag.npc => l10n.momentTagNpcHint,
  };

  /// A concrete example — the part that actually teaches the category.
  ///
  /// Doubles as the composer's placeholder once a category is picked, so the
  /// field itself shows you the shape of the sentence it wants.
  static String exampleFor(AppLocalizations l10n, MomentTag tag) =>
      switch (tag) {
        MomentTag.fate => l10n.momentTagFateExample,
        MomentTag.jinx => l10n.momentTagJinxExample,
        MomentTag.luck => l10n.momentTagLuckExample,
        MomentTag.calledIt => l10n.momentTagCalledItExample,
        MomentTag.npc => l10n.momentTagNpcExample,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconFor(tag),
            size: dense ? 11 : 13,
            // accentInk, never a literal white: NeonNight's accent is pure
            // #FFFF00 and Graphite's is near-white, so white-on-accent is
            // unreadable in both.
            color: theme.accentInk,
          ),
          if (!dense) ...[
            const SizedBox(width: 6),
            Text(
              labelFor(l10n, tag),
              // Body face at meta size: the theme's mono read as a terminal
              // stamp on every character theme.
              style: metaText(theme, color: theme.accentInk).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A category's colour; see [MomentTagChip.toneFor].
Color momentTagColor(AppTheme theme, MomentTag tag) =>
    tileColor(theme, MomentTagChip.toneFor(tag));

/// THE mark of a point category: its glyph on its colour, a [ToneTile].
class MomentTagTile extends StatelessWidget {
  const MomentTagTile(this.tag, {super.key, this.size = 30});

  final MomentTag tag;
  final double size;

  @override
  Widget build(BuildContext context) => ToneTile(
        icon: MomentTagChip.iconFor(tag),
        tone: MomentTagChip.toneFor(tag),
        size: size,
      );
}
