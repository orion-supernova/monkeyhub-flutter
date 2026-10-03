import 'package:flutter/cupertino.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/message_preview.dart';
import '../models/room_pin.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';
import 'teardown_safe.dart';

/// Height of the banner's content row, excluding the divider.
///
/// Exported because the liquid chat style floats its chrome OVER the transcript
/// and has to grow the list's top padding by exactly this much. The widget
/// renders a [SizedBox] of this height rather than sizing to its content, so
/// the constant and the render cannot drift apart.
const double kPinnedBannerHeight = 44.0;

/// Where the tick marker stops drawing one segment per pin and switches to a
/// proportional thumb. Past this, segments are thinner than the gaps between
/// them and the whole marker reads as a dashed smear.
const int _kMaxTickSegments = 5;

const double _kTickWidth = 2.0;
const double _kTickHeight = 26.0;
const double _kTickGap = 2.0;

/// Compact-style insets and corner. The 16pt gutter is the one the liquid
/// header and composer already use, and 22 is the composer field's radius —
/// half of the 44pt chrome height, so the strip reads as the same pill family
/// as the round buttons flanking it rather than a full-bleed ribbon.
///
/// Horizontal only: the height has to stay exactly [kPinnedBannerHeight] or the
/// transcript's reserved top padding drifts. The gap above comes from the
/// header's own 8pt bottom padding.
const double _kGlassGutter = 16.0;
const double _kGlassRadius = 22.0;

/// Advances the pin cursor, wrapping at the end.
///
/// A free function so the wrap can be tested without a widget tree — and
/// because the cursor lives in the room screen, not in this widget: the sheet
/// has to be able to set it too.
int nextPinCursor(int cursor, int length) {
  if (length <= 0) return 0;
  return (cursor + 1) % length;
}

/// Geometry of the segmented marker down the banner's left edge, top to bottom.
///
/// Returns one rect per pin while that stays legible, and a two-rect
/// [track, thumb] pair beyond it. Extracted from the painter so the maths is
/// testable without a canvas.
///
/// [activeIndex] is clamped rather than asserted: a pinned message can expire
/// out from under the banner between one subscription frame and the next, and
/// the cursor is allowed to be briefly stale.
List<Rect> pinTickRects({
  required int count,
  required int activeIndex,
  required Size size,
}) {
  if (count <= 0) return const [];
  final active = activeIndex.clamp(0, count - 1);

  if (count > _kMaxTickSegments) {
    // One continuous track with a thumb sliding down it. The thumb keeps a
    // floor so a room at the 50-pin cap still shows something grabbable.
    final thumbH = (size.height / count).clamp(6.0, size.height);
    final free = size.height - thumbH;
    final top = count == 1 ? 0.0 : free * (active / (count - 1));
    return [
      Rect.fromLTWH(0, 0, size.width, size.height),
      Rect.fromLTWH(0, top, size.width, thumbH),
    ];
  }

  final totalGap = _kTickGap * (count - 1);
  final segH = (size.height - totalGap) / count;
  return [
    for (var i = 0; i < count; i++)
      Rect.fromLTWH(0, i * (segH + _kTickGap), size.width, segH),
  ];
}

class _PinTicksPainter extends CustomPainter {
  const _PinTicksPainter({
    required this.count,
    required this.activeIndex,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int activeIndex;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = pinTickRects(
      count: count,
      activeIndex: activeIndex,
      size: size,
    );
    if (rects.isEmpty) return;
    final radius = Radius.circular(size.width / 2);
    final active = activeIndex.clamp(0, count - 1);

    if (count > _kMaxTickSegments) {
      // [track, thumb] — the track is always inactive, the thumb always active.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[0], radius),
        Paint()..color = inactiveColor,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[1], radius),
        Paint()..color = activeColor,
      );
      return;
    }

    for (var i = 0; i < rects.length; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rects[i], radius),
        Paint()..color = i == active ? activeColor : inactiveColor,
      );
    }
  }

  @override
  bool shouldRepaint(_PinTicksPainter old) =>
      old.count != count ||
      old.activeIndex != activeIndex ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}

/// The pinned-message strip that sits under the room header.
///
/// Zero height with no pins, so it can live permanently in the room layout —
/// the same contract [GroupCallBanner] has, and the reason neither needs a
/// conditional at its call site.
///
/// Stateless apart from press feedback. [activeIndex] and the cycling live in
/// the room screen: tapping this jumps the transcript, which is the screen's
/// job, and the pin-list sheet has to be able to drive the same cursor.
class PinnedMessageBanner extends StatelessWidget {
  const PinnedMessageBanner({
    super.key,
    required this.pins,
    required this.activeIndex,
    required this.onTap,
    required this.onOpenList,
    this.glass = false,
  });

  /// Chronological, oldest message first — the order `pins:listForRoom`
  /// returns, which is also the order the transcript shows them in.
  final List<RoomPin> pins;

  /// Which pin the row is describing. Clamped on read, never asserted.
  final int activeIndex;

  /// Jump to the active pin. The caller advances the cursor afterwards.
  final VoidCallback onTap;

  /// Open the full list of pins.
  final VoidCallback onOpenList;

  /// A frosted, rounded, gutter-inset pill instead of an opaque full-bleed
  /// strip. For the compact style, where this floats over the transcript
  /// alongside the header capsule and the composer rather than sitting in a
  /// column above it — square corners there were the one piece of chrome not
  /// speaking the style's language.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // AnimatedSize wraps the empty case too, so the first pin in a room grows
    // the strip open instead of snapping it in.
    return AnimatedSize(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      alignment: Alignment.topCenter,
      child: pins.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : _Strip(
              pins: pins,
              activeIndex: activeIndex,
              onTap: onTap,
              onOpenList: onOpenList,
              glass: glass,
            ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.pins,
    required this.activeIndex,
    required this.onTap,
    required this.onOpenList,
    required this.glass,
  });

  final List<RoomPin> pins;
  final int activeIndex;
  final VoidCallback onTap;
  final VoidCallback onOpenList;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final active = activeIndex.clamp(0, pins.length - 1);
    final pin = pins[active];
    final l10n = AppLocalizations.of(context);

    // Used to head the strip as its own line of accent text. It says nothing
    // the glyph beside it and the message next to that don't already say, so it
    // now lives only in the semantics tree — see [_Label] and the icon below.
    final title = pins.length > 1
        ? l10n.pinnedBannerTitleWithIndex(pins.length, active + 1)
        : l10n.pinnedBannerTitleSingle;

    final row = SizedBox(
      height: kPinnedBannerHeight,
      child: Row(
        children: [
          const SizedBox(width: 12),
          CustomPaint(
            size: const Size(_kTickWidth, _kTickHeight),
            painter: _PinTicksPainter(
              count: pins.length,
              activeIndex: active,
              activeColor: theme.accent,
              inactiveColor: theme.accent.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 10),
          // What the words "Pinned message" used to do, in 14pt. Deliberately
          // OUTSIDE the tap target beside it: it identifies the whole strip
          // rather than the row's text, and as a sibling of the button its
          // semantics node stands on its own instead of competing with the
          // button's label for the screen reader's attention.
          Icon(
            CupertinoIcons.pin_fill,
            size: 14,
            color: theme.accent,
            semanticLabel: title,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TapTarget(
              onTap: onTap,
              semanticLabel: l10n.pinnedBannerJumpToPinnedSemanticLabel,
              radius: theme.radiusSm,
              child: _Label(pin: pin),
            ),
          ),
          const SizedBox(width: 8),
          _TapTarget(
            onTap: onOpenList,
            semanticLabel: l10n.pinnedBannerAllPinnedSemanticLabel,
            radius: theme.radiusSm,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(
                CupertinoIcons.list_bullet,
                size: 18,
                color: theme.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );

    // [LiquidGlass] rather than [GlassSurface]: this is the same chrome as the
    // header capsule and the composer field, so it should share their rounded
    // shape, the user's glass dials, and — because the blur goes through
    // `BackdropFilter.grouped` — their single rasterization pass.
    if (glass) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kGlassGutter),
        child: LiquidGlass(
          shape: LiquidGlassShape.rounded,
          radius: _kGlassRadius,
          child: row,
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: row,
    );
  }
}

/// The pinned message itself — sender and preview on one line, swapped with a
/// slide when the cursor moves.
///
/// There is no "Pinned message" heading above it. The strip sits directly under
/// the room header with the transcript below, wears an accent pin glyph a few
/// points to its left, and the only thing it ever shows is a pinned message —
/// so the words were naming a thing already named three ways over. They are not
/// lost: the same localized string is the glyph's [Icon.semanticLabel], which
/// is where a screen reader picks up both the word "pinned" and, with more than
/// one pin, which of them this row is describing.
///
/// Dropping the heading turns a cramped two-line block into a single line
/// centred in the strip's 44pt, which is the proportion the header capsule and
/// the composer field already use — so the space the title vacated reads as
/// breathing room rather than as a gap. The line is promoted to the theme's
/// primary ink for the same reason: left soft, it would go on reading as a
/// subtitle to a heading that is no longer there.
///
/// Sized to fill rather than shrink-wrapped, for two reasons that both bite:
/// [AnimatedSwitcher] lays its children out in a centre-aligned [Stack], so a
/// short pin would drift to the middle of the strip, and the caller's opaque
/// [GestureDetector] only covers what this returns — shrink-wrapped, the tap
/// target would be the height of one line of text inside a 44pt strip.
class _Label extends StatelessWidget {
  const _Label({required this.pin});

  final RoomPin pin;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = pin.message;
    // No thumbnail in this strip, so an uncaptioned photo needs the word.
    final preview = messagePreviewLine(m, hasThumbnail: false);

    return AnimatedSwitcher(
      duration: theme.motionFast,
      switchInCurve: theme.motionEntrance,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: SizedBox(
        // Keyed on the message, not the index: two pins removed at once can
        // leave the index pointing at a different message without changing, and
        // the strip would then swap text with no transition.
        key: ValueKey(m.id),
        width: double.infinity,
        height: kPinnedBannerHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            preview.isEmpty ? m.senderName : '${m.senderName}  $preview',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySoft.copyWith(color: theme.ink),
          ),
        ),
      ),
    );
  }
}

/// A tappable region, with the pairing this codebase requires.
///
/// [FocusableTap] registers NO gesture recognizer of its own — it only adds the
/// focus node, the Enter/Space binding and the semantics. The inner
/// [GestureDetector] is what actually receives the pointer, and omitting it
/// produces a control that looks right and does nothing. That exact mistake has
/// shipped here before; `pinned_banner_tap_test.dart` pins it.
///
/// Never an InkWell: this app renders no ink and no ripple anywhere.
class _TapTarget extends StatefulWidget {
  const _TapTarget({
    required this.onTap,
    required this.semanticLabel,
    required this.radius,
    required this.child,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final double radius;
  final Widget child;

  @override
  State<_TapTarget> createState() => _TapTargetState();
}

class _TapTargetState extends State<_TapTarget>
    with TeardownSafe<_TapTarget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: widget.onTap,
      radius: widget.radius,
      semanticLabel: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: theme.motionFast,
          curve: theme.motionCurve,
          child: widget.child,
        ),
      ),
    );
  }
}
