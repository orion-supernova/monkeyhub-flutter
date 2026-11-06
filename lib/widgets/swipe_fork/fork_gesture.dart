import 'package:flutter/widgets.dart';

import '../swipe_fork.dart';

/// Mounts the fork over [child] (the transcript): the list's physics gets the
/// pull in front of it (see [ForkPull]), a passive [Listener] feeds it the
/// finger, and it cancels when the app leaves the foreground. Nothing here
/// joins the gesture arena, so the list scrolls exactly as before until it
/// runs out of list at the newest message.
class SwipeForkGesture extends StatefulWidget {
  const SwipeForkGesture({
    super.key,
    required this.controller,
    required this.child,
  });

  final SwipeForkController controller;
  final Widget child;

  @override
  State<SwipeForkGesture> createState() => _SwipeForkGestureState();
}

class _SwipeForkGestureState extends State<SwipeForkGesture>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.controller.pull.reset();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final base = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: base.copyWith(
        physics: ForkScrollPhysics(
          controller: c,
          parent: base.getScrollPhysics(context),
        ),
      ),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: c.pull.pointerDown,
        onPointerMove: c.pull.pointerMove,
        onPointerUp: c.pull.pointerUp,
        onPointerCancel: c.pull.pointerCancel,
        child: widget.child,
      ),
    );
  }
}
