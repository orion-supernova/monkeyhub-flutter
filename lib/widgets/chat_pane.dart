import 'package:flutter/widgets.dart';

import '../theme/layout.dart';

/// Measures the surface a chat is given and publishes [ChatMetrics] to it.
///
/// Put exactly ONE of these at the top of each chat surface: `RoomScreen`
/// (which measures the detail pane in the two-pane shell, or the window on a
/// pushed compact route) and the thread overlay (which measures the window,
/// because an overlay has no pane). Neither needs to know which it is — that
/// is the point of measuring the box instead of asking the shell.
///
/// [child] is captured OUTSIDE the builder closure. A resize, or every frame
/// of a keyboard animation, then re-runs only this builder and swaps the cheap
/// scope wrapper; `Element.updateChild` short-circuits on the identical child
/// widget so the subtree is not rebuilt. Dependents are gated a second time by
/// [ChatMetricsScope.updateShouldNotify], which compares quantized values —
/// together these are what keep a drag-resize from rebuilding every bubble on
/// every frame. Both are load-bearing; do not remove either.
class ChatPane extends StatelessWidget {
  const ChatPane({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final windowClass = context.windowClass;
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.maxWidth.isFinite,
          'ChatPane needs a bounded width — it is measuring the surface the '
          'chat occupies. An unbounded parent (a Row/ListView without an '
          'Expanded/SizedBox) would silently yield Infinity.',
        );
        return ChatMetricsScope(
          metrics: ChatMetrics.forPane(constraints.maxWidth, windowClass),
          child: child,
        );
      },
    );
  }
}

/// Centres its child in the chat column.
///
/// A pure passthrough whenever the column already fills the pane — every
/// phone, and every desktop pane narrower than [ChatMetrics.surfaceMax] — so
/// the common case pays for nothing and the chat genuinely fills the space it
/// was given.
///
/// Note the deliberate difference from `AdaptivePageBody`, which is a
/// passthrough on the *compact window class*: that makes the widget type in
/// its slot change when a window crosses 600px, which rebuilds the whole
/// subtree from scratch (a transcript loses its scroll offset and any playing
/// audio/video). This keys off a value instead, and only elides the wrapper
/// where it would have had no effect anyway.
///
/// Alignment is centre and must stay centre: the room's floating date chip is
/// a full-pane `Positioned` sibling of the transcript that relies on the
/// column being centred to land over it.
class ChatColumn extends StatelessWidget {
  const ChatColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = ChatMetricsScope.of(context);
    if (metrics.columnFillsPane) return child;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: metrics.columnWidth),
        child: child,
      ),
    );
  }
}
