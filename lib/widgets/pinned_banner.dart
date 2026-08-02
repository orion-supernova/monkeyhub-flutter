import 'package:flutter/cupertino.dart';

import '../keyboard/focusable_tap.dart';
import '../models/message_preview.dart';
import '../models/room_pin.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';

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
          Expanded(
            child: _TapTarget(
              onTap: onTap,
              semanticLabel: 'Jump to pinned message',
              radius: theme.radiusSm,
              child: _Label(pin: pin, count: pins.length, index: active),
            ),
          ),
          const SizedBox(width: 8),
          _TapTarget(
            onTap: onOpenList,
            semanticLabel: 'All pinned messages',
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

/// The two-line label, swapped with a slide when the cursor moves.
class _Label extends StatelessWidget {
  const _Label({required this.pin, required this.count, required this.index});

  final RoomPin pin;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final m = pin.message;
    // No thumbnail in this strip, so an uncaptioned photo needs the word.
    final preview = messagePreviewLine(m, hasThumbnail: false);
    final title = count > 1
        ? 'Pinned message  ${index + 1}/$count'
        : 'Pinned message';

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
      child: Column(
        // Keyed on the message, not the index: two pins removed at once can
        // leave the index pointing at a different message without changing, and
        // the strip would then swap text with no transition.
        key: ValueKey(m.id),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.label.copyWith(color: theme.accent),
          ),
          const SizedBox(height: 1),
          Text(
            preview.isEmpty ? m.senderName : '${m.senderName}  $preview',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySoft.copyWith(color: theme.inkSoft),
          ),
        ],
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

class _TapTargetState extends State<_TapTarget> {
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
