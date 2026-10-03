import 'package:flutter/widgets.dart';

/// Makes a press-animated widget safe to tear down mid-press.
///
/// When a screen closes while a finger is still on one of its buttons, the
/// framework unmounts the button's GestureDetector and the recognizer fires
/// `onTapCancel` from inside that unmount — while the tree is locked. A
/// `setState(() => _pressed = false)` there throws "setState() called when
/// widget tree was locked".
///
/// From [deactivate] (which always runs before the unmount) until [activate],
/// [setState] still applies the change to the fields but does not ask for a
/// rebuild. A widget that is torn down never needed one; one that is
/// re-inserted (a GlobalKey move) is rebuilt by [activate] anyway, with the
/// fields already right.
mixin TeardownSafe<T extends StatefulWidget> on State<T> {
  bool _leaving = false;

  @override
  void deactivate() {
    _leaving = true;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _leaving = false;
  }

  @override
  void setState(VoidCallback fn) {
    if (_leaving || !mounted) {
      fn();
      return;
    }
    super.setState(fn);
  }
}
