import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../swipe_fork.dart';

/// A one-finger upward drag that decides EARLY, so it beats the transcript's
/// own scroll recognizer to a drag that starts at the newest message.
///
/// It only ever enters the gesture arena when [canStart] says yes at
/// pointer-down (the options and every gate are evaluated there, once), so in
/// every other state the list scrolls exactly as before. Once in, it rejects
/// itself on a downward or sideways-dominant start (the list, a swipe-to-reply
/// row, or a tap gets the pointer) and accepts on a few points of clear upward
/// travel. A second finger ends the gesture without committing.
class ForkGestureRecognizer extends OneSequenceGestureRecognizer {
  ForkGestureRecognizer({super.debugOwner, super.supportedDevices});

  bool Function(Offset global)? canStart;
  VoidCallback? onStart;
  void Function(Offset global)? onUpdate;
  void Function(double vx)? onEnd;
  VoidCallback? onCancel;

  /// Upward points before the drag claims the pointer.
  static const double acceptSlop = 8;

  /// Downward points that hand the pointer back to the list.
  static const double rejectSlop = 6;

  int? _pointer;
  Offset _down = Offset.zero;
  Offset _pos = Offset.zero;
  VelocityTracker? _velocity;
  bool _accepted = false;
  bool _dead = false;

  @override
  String get debugDescription => 'swipe-up fork';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) {
      // A second finger: no commit, whatever state we are in.
      if (!_dead) {
        _dead = true;
        if (_accepted) {
          onCancel?.call();
        } else {
          resolve(GestureDisposition.rejected);
        }
      }
      return;
    }
    if (canStart?.call(event.position) != true) return;
    _pointer = event.pointer;
    _down = event.position;
    _pos = event.position;
    _accepted = false;
    _dead = false;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      _pos = event.position;
      _velocity?.addPosition(event.timeStamp, event.position);
      if (_dead) return;
      if (_accepted) {
        onUpdate?.call(_pos);
        return;
      }
      final up = _down.dy - _pos.dy;
      final side = (_pos.dx - _down.dx).abs();
      if (-up > rejectSlop || (side > 12 && side > up)) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        _clear();
      } else if (up >= acceptSlop && up > side * 1.2) {
        resolve(GestureDisposition.accepted);
      }
    } else if (event is PointerUpEvent) {
      final wasLive = _accepted && !_dead;
      final vx = _velocity?.getVelocity().pixelsPerSecond.dx ?? 0;
      if (!_accepted) resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
      _clear();
      if (wasLive) onEnd?.call(vx);
    } else if (event is PointerCancelEvent) {
      final wasLive = _accepted && !_dead;
      if (!_accepted) resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
      _clear();
      if (wasLive) onCancel?.call();
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer || _dead) return;
    _accepted = true;
    onStart?.call();
    onUpdate?.call(_pos);
  }

  @override
  void rejectGesture(int pointer) {
    if (pointer != _pointer) return;
    stopTrackingPointer(pointer);
    _clear();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  void _clear() {
    _pointer = null;
    _accepted = false;
    _dead = false;
    _velocity = null;
  }
}

/// Mounts the fork's drag over [child] (the transcript) and cancels it when the
/// app leaves the foreground.
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
    if (state != AppLifecycleState.resumed) widget.controller.cancelGesture();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        ForkGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<ForkGestureRecognizer>(
          ForkGestureRecognizer.new,
          (r) {
            r
              ..canStart = c.prepare
              ..onStart = c.start
              ..onUpdate = c.move
              ..onEnd = c.release
              ..onCancel = c.cancelGesture;
          },
        ),
      },
      child: widget.child,
    );
  }
}
