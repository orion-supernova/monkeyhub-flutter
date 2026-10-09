import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

/// Scrolling that behaves like the platform it runs on.
///
/// Three pieces, deliberately separate because each is right in a different
/// number of places:
///
///  * [DesktopScrollBehavior] — app-wide, via `MaterialApp.scrollBehavior`.
///    Thin overlay scrollbars on a desktop, nothing at all on a phone.
///  * [HorizontalWheelScroll] — opt-in, per strip. A vertical mouse wheel
///    scrolls a horizontal list.
///  * [PagerMouseDrag] — opt-in, per pager. A mouse can drag a page across.

/// The app's [ScrollBehavior]: Material's, with the desktop scrollbar redrawn
/// as the thin, auto-hiding overlay a Mac draws.
///
/// Material already puts a [Scrollbar] on every vertical scrollable on
/// macOS/Windows/Linux (and on a desktop browser, whose user agent reports one
/// of those). What it draws there is a fixed, fairly heavy bar that reads as
/// Android-on-a-monitor. This keeps the same placement and the same rules —
/// vertical only, desktop only, nothing on a phone — and changes only the
/// look: a slim pill with no track that fades out shortly after scrolling
/// stops, and widens under the pointer so it is still easy to grab.
///
/// Phones are untouched on purpose: [buildScrollbar] defers to Material there,
/// which returns the list unwrapped, exactly as before.
///
/// Mouse DRAG is deliberately not added here. A drag that scrolls everything
/// would steal the drag that selects text and the drag that sweeps a selection
/// across messages. Only pagers want it; see [PagerMouseDrag].
class DesktopScrollBehavior extends MaterialScrollBehavior {
  const DesktopScrollBehavior();

  /// Idle and under-the-pointer thickness. A Mac's overlay bar is ~7pt and
  /// grows to ~11pt on hover; these sit a touch under that because the thumb
  /// is drawn with a margin of its own.
  static const double thickness = 6;
  static const double hoverThickness = 9;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    if (axisDirectionToAxis(details.direction) == Axis.horizontal ||
        !_isDesktop(getPlatform(context))) {
      return super.buildScrollbar(context, child, details);
    }
    return ScrollbarTheme(
      data: _thinTheme(context),
      child: Scrollbar(controller: details.controller, child: child),
    );
  }

  static bool _isDesktop(TargetPlatform p) =>
      p == TargetPlatform.macOS ||
      p == TargetPlatform.windows ||
      p == TargetPlatform.linux;

  static ScrollbarThemeData _thinTheme(BuildContext context) {
    // Read through the inherited widget rather than `ThemeScope.of`, which
    // asserts: a scrollable built in a test harness (or anywhere above the
    // app's scope) still gets a sensible thumb from Material's own scheme.
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    final ink = scope?.notifier?.theme.ink ??
        Theme.of(context).colorScheme.onSurface;
    bool active(Set<WidgetState> s) =>
        s.contains(WidgetState.hovered) || s.contains(WidgetState.dragged);
    return ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(false),
      trackVisibility: const WidgetStatePropertyAll(false),
      interactive: true,
      radius: const Radius.circular(hoverThickness / 2),
      crossAxisMargin: 2,
      mainAxisMargin: 4,
      minThumbLength: 36,
      thickness: WidgetStateProperty.resolveWith(
        (s) => active(s) ? hoverThickness : thickness,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => ink.withValues(alpha: active(s) ? 0.5 : 0.32),
      ),
    );
  }
}

/// Lets a plain vertical mouse wheel scroll the horizontal list inside
/// [child].
///
/// A Mac trackpad, a Magic Mouse and a tilt wheel all scroll sideways on their
/// own. A Windows or Linux mouse has one wheel and it only goes up and down,
/// so without this a horizontal strip is unreachable past its first screenful
/// unless the user knows to hold Shift.
///
/// ## How it gets the wheel
///
/// A wheel tick is offered to every scrollable under the pointer, innermost
/// first, and the first to register with the [PointerSignalResolver] takes it.
/// The strip's own [Scrollable] passes on a purely vertical tick (it has no
/// horizontal component to apply), so this — sitting just above it — is next
/// in line, ahead of the vertical page the strip lives in.
///
/// It takes the tick only when the strip can actually move that way. At either
/// end it steps aside and the page scrolls on, so a strip in the middle of a
/// feed pauses the page's scroll rather than trapping it.
///
/// Opt-in per strip rather than app-wide: a horizontal scroller that sits
/// inside every row of a long list (a tile's chip row, say) would otherwise
/// catch the wheel each time the pointer crossed one, and the list would stall
/// under it.
///
/// Finds the strip by walking down to the first horizontal [Scrollable] below
/// it, so no controller has to be threaded through — wrap the list and that is
/// all. The walk runs on the first wheel tick, not per frame, and its answer is
/// kept while it stays mounted.
class HorizontalWheelScroll extends StatefulWidget {
  const HorizontalWheelScroll({super.key, required this.child});

  final Widget child;

  @override
  State<HorizontalWheelScroll> createState() => _HorizontalWheelScrollState();
}

class _HorizontalWheelScrollState extends State<HorizontalWheelScroll> {
  ScrollableState? _strip;

  @override
  void didUpdateWidget(HorizontalWheelScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The child may now build a different scrollable; find it afresh.
    _strip = null;
  }

  ScrollableState? _findStrip() {
    final cached = _strip;
    if (cached != null && cached.mounted) return cached;
    ScrollableState? found;
    void visit(Element e) {
      if (found != null) return;
      if (e is StatefulElement && e.state is ScrollableState) {
        final s = e.state as ScrollableState;
        if (axisDirectionToAxis(s.axisDirection) == Axis.horizontal) {
          found = s;
          return;
        }
      }
      e.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return _strip = found;
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        event.scrollDelta.dx != 0 ||
        event.scrollDelta.dy == 0) {
      return;
    }
    final strip = _findStrip();
    if (strip == null) return;
    final position = strip.position;
    // Wheel down moves toward the END of the strip, whichever way it reads.
    final delta = strip.axisDirection == AxisDirection.left
        ? -event.scrollDelta.dy
        : event.scrollDelta.dy;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (_) => position.pointerScroll(delta),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Listener(onPointerSignal: _onSignal, child: widget.child);
}

/// Lets a mouse drag the pager inside [child] from page to page, the way a
/// finger does.
///
/// Only for pagers and carousels. Flutter leaves mouse drag off app-wide for
/// good reason — on a list it would fight text selection and drag-select —
/// but a pager has neither, and without it a mouse has no way to turn the page
/// short of whatever arrows the screen remembers to draw.
class PagerMouseDrag extends StatelessWidget {
  const PagerMouseDrag({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: behavior.copyWith(
        dragDevices: {
          ...behavior.dragDevices,
          PointerDeviceKind.mouse,
        },
      ),
      child: child,
    );
  }
}
