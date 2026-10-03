import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/media_aspect_cache.dart';
import '../models/moment.dart';
import '../theme/motion.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';
import 'steady_hero.dart';

import 'ios_kit.dart' show SpringPress, groupedFill;
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

/// The horizontal rail of today's moments, capture tile first.
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
///  * **Cards are keyed by moment id, never by index.** The rail reorders as
///    moments arrive, and an index key hands a tile someone else's photo —
///    which then reloads, briefly showing the wrong face.
class MomentRail extends StatelessWidget {
  const MomentRail({
    super.key,
    required this.moments,
    required this.api,
    required this.serverNow,
    required this.onCapture,
    required this.onOpen,
    this.canCapture = true,
  });

  final List<Moment> moments;
  final ChatApi api;

  /// The server's clock, not the device's — see [FeedStore.serverNow].
  final DateTime serverNow;

  final VoidCallback onCapture;
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

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // Vertical room for FocusableTap's ring, which paints outside the
        // child's bounds and would otherwise be clipped by this scroll view.
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          _CaptureTile(onTap: canCapture ? onCapture : null),
          for (var i = 0; i < moments.length; i++)
            Padding(
              key: ValueKey(moments[i].id),
              padding: const EdgeInsets.only(left: 10),
              child: _MomentCard(
                moment: moments[i],
                api: api,
                serverNow: serverNow,
                index: i,
                onTap: () => onOpen(moments[i]),
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
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: l10n.momentRailCaptureLabel,
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
                style: theme.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.api,
    required this.serverNow,
    required this.index,
    required this.onTap,
  });

  final Moment moment;
  final ChatApi api;
  final DateTime serverNow;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final unseen = !moment.mine && !moment.seen;

    return TweenAnimationBuilder<double>(
      // Identity key, never index — see the class doc.
      key: ValueKey('rail_${moment.id}'),
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
      child: SpringPress(
        onTap: onTap,
        haptic: false,
        semanticLabel: moment.caption?.isNotEmpty == true
            ? l10n.momentRailCardSemanticLabel(
                moment.authorName,
                moment.caption!,
              )
            : moment.authorName,
        // An unseen story wears a ring in the theme's colours, set off from
        // the picture by a hairline of page — the universal "new" mark.
        child: Container(
          width: _storyWidth,
          padding: EdgeInsets.all(unseen ? 2.5 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_storyRadius + 2.5),
            gradient: unseen
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.accent,
                      Color.lerp(theme.accent, const Color(0xFFFF2D55), 0.65)!,
                    ],
                  )
                : null,
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
                  // The name over a fade at the foot of the picture.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x99000000)],
                          ),
                        ),
                        child: Text(
                          moment.mine
                              ? l10n.momentRailYouLabel
                              : moment.authorName,
                          style: theme.caption.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
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
          Center(
            child: Icon(
              CupertinoIcons.play_circle_fill,
              size: 30,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
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
  /// Material icons rather than emoji on purpose: emoji render in the system
  /// font at a size and colour this app cannot control, which breaks against
  /// thirteen palettes — four of them light — and looks pasted-on next to the
  /// theme's own drawn marks.
  static IconData iconFor(MomentTag tag) => switch (tag) {
    MomentTag.fate => Icons.auto_awesome_outlined,
    MomentTag.jinx => Icons.bolt_outlined,
    MomentTag.luck => Icons.workspace_premium_outlined,
    MomentTag.calledIt => Icons.visibility_outlined,
    MomentTag.npc => Icons.smart_toy_outlined,
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
            size: dense ? 10 : 12,
            // accentInk, never a literal white: NeonNight's accent is pure
            // #FFFF00 and Graphite's is near-white, so white-on-accent is
            // unreadable in both.
            color: theme.accentInk,
          ),
          if (!dense) ...[
            const SizedBox(width: 6),
            Text(
              labelFor(l10n, tag),
              style: theme.monoTiny.copyWith(color: theme.accentInk),
            ),
          ],
        ],
      ),
    );
  }
}
