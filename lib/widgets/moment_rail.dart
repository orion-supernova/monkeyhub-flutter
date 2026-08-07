import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/moment.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';

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

    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.momentRailCaptureLabel,
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          // Matches ProfileVisibilityScreen's read-only treatment: show the
          // control dimmed rather than hiding it, so the surface still makes
          // sense to someone who cannot use it.
          opacity: enabled ? 1 : 0.45,
          child: Container(
            width: 108,
            padding: const EdgeInsets.all(12),
            decoration: theme.roomCardDecoration(ephemeral: false, active: false),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.accentSoft,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add, size: 18, color: theme.accent),
                ),
                const Spacer(),
                Text(
                  l10n.momentRailCaptureLabel,
                  style: theme.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
      duration: motion.stagger(theme.motionMed, index, strideMs: 45),
      // motionEntrance, not motionCurve: the latter is easeOutBack in
      // Risograph and Cyberpunk, which overshoots and would throw the card
      // past the rail's edge before settling back.
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 14),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: moment.caption?.isNotEmpty == true
            ? l10n.momentRailCardSemanticLabel(
                moment.authorName,
                moment.caption!,
              )
            : moment.authorName,
        radius: theme.radiusLg,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 124,
            // NOT wrapped in ClipRRect. `roomCardDecoration` carries
            // Risograph's hard offset shadow and three themes' neon glows, and
            // clipping the card amputates all of them.
            decoration: theme.roomCardDecoration(
              ephemeral: unseen,
              active: false,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Thumb(moment: moment, api: api, unseen: unseen)),
                const SizedBox(height: 8),
                Text(
                  moment.mine ? l10n.momentRailYouLabel : moment.authorName,
                  style: theme.monoTiny,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The picture, or a caption-only card when the moment carries no media.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.moment, required this.api, required this.unseen});

  final Moment moment;
  final ChatApi api;
  final bool unseen;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final storageId = moment.mediaStorageId;
    // A video's poster frame, when one exists. Poster extraction is mobile-only
    // (video_thumbnail wraps MediaMetadataRetriever / AVAssetImageGenerator and
    // has no web or desktop implementation), so a video composed on the web
    // keeps the glyph permanently — a designed state, not a placeholder.
    final thumbId = moment.mediaKind == MomentMedia.video
        ? moment.posterStorageId
        : storageId;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbId != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusMd),
            child: RemoteImage(
              storageId: thumbId,
              api: api,
              fit: BoxFit.cover,
              // One axis only. Passing both width and height here squashes the
              // bitmap before `fit` runs — ResizeImagePolicy.exact behaves like
              // BoxFit.fill — which is what stretched every non-square tile in
              // an earlier build.
              decodeWidth: 248,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: theme.surfaceSunken,
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            padding: const EdgeInsets.all(8),
            alignment: Alignment.topLeft,
            child: Text(
              moment.caption ?? '',
              style: theme.bodySoft,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (moment.mediaKind == MomentMedia.video)
          Center(
            child: Icon(
              Icons.play_circle_outline,
              size: 26,
              color: theme.ink.withValues(alpha: 0.85),
            ),
          ),
        if (moment.tag != null)
          Positioned(
            left: 4,
            top: 4,
            child: MomentTagChip(tag: moment.tag!, dense: true),
          ),
        if (unseen)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
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
