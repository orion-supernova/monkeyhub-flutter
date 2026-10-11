import 'package:flutter/gestures.dart';

/// Claims a mouse's secondary button on the way DOWN and reports where.
///
/// Shared by the message row and an album's cards: the card is deeper, so
/// with the same eager recognizer it claims the click first, and a
/// right-click on a card opens the menu for that card rather than for the
/// row (which is drawn as the album's last item).
///
/// Eager on purpose. A recognizer that waits for the arena to sweep loses to
/// any deeper one, and a [SelectionArea] inside a text bubble is deeper and
/// wants the same button. Accepting at once also means it fires before the
/// 100ms tap deadline, so the selection's own "right-click selects the word"
/// never runs underneath the menu.
class SecondaryClickRecognizer extends OneSequenceGestureRecognizer {
  SecondaryClickRecognizer()
      : super(supportedDevices: const {PointerDeviceKind.mouse});

  void Function(Offset globalPosition)? onClick;
  Offset? _down;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.buttons == kSecondaryMouseButton && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _down = event.position;
    resolve(GestureDisposition.accepted);
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    final at = _down;
    _down = null;
    if (at != null) onClick?.call(at);
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    _down = null;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'secondary click';
}
