import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';

/// The call chrome (name, status, tray) puts itself away over a video
/// call after a few quiet seconds, the way FaceTime and Telegram do, and
/// comes back on any touch, any mouse movement, or a tap on the picture.
///
/// Only over a picture worth uncovering ([syncAutoHide] says when); never
/// while a sheet or menu is up over the call, never with a screen reader
/// on (the controls must stay where VoiceOver found them), and never on
/// a voice call, where the chrome is the screen.
///
/// The fade itself is [ControlsFade]'s; this only decides when.
mixin CallChromeAutoHide<T extends StatefulWidget> on State<T> {
  /// Whether the chrome is showing.
  bool controlsVisible = true;

  /// How long the chrome waits, untouched, before it goes.
  static const Duration after = Duration(seconds: 5);

  Timer? _autoHide;
  bool _eligible = false;
  DateTime _lastPoke = DateTime.fromMillisecondsSinceEpoch(0);

  /// Call from build with whether the screen is a picture worth
  /// uncovering. Turning ineligible brings the chrome back.
  void syncAutoHide(bool eligible) {
    if (eligible == _eligible) return;
    _eligible = eligible;
    if (eligible) {
      _arm();
    } else {
      _autoHide?.cancel();
      // Read by the build that called this, so no setState.
      controlsVisible = true;
    }
  }

  /// Shows or hides the chrome; showing it restarts the wait.
  void setControlsVisible(bool visible) {
    if (!mounted) return;
    if (visible != controlsVisible) {
      setState(() => controlsVisible = visible);
    }
    visible ? _arm() : _autoHide?.cancel();
  }

  /// The tap on the picture.
  void toggleControls() => setControlsVisible(!controlsVisible);

  /// Any touch restarts the wait.
  void pokeControls() {
    _lastPoke = DateTime.now();
    _arm();
  }

  void _arm() {
    _autoHide?.cancel();
    if (!_eligible || !controlsVisible) return;
    _autoHide = Timer(after, _fire);
  }

  void _fire() {
    if (!mounted || !_eligible || !controlsVisible) return;
    final route = ModalRoute.of(context);
    final covered = route != null && !route.isCurrent;
    if (covered || MediaQuery.accessibleNavigationOf(context)) {
      _arm();
      return;
    }
    setState(() => controlsVisible = false);
  }

  /// Wraps the call screen's body: every pointer down restarts the wait,
  /// and a mouse moving over a hidden chrome brings it back. Translucent,
  /// so it takes nothing from the gestures under it.
  Widget autoHideScope({required Widget child}) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => pokeControls(),
        onPointerHover: (e) {
          if (e.kind != PointerDeviceKind.mouse) return;
          if (!controlsVisible && _eligible) {
            setControlsVisible(true);
            return;
          }
          // A moving mouse restarts the wait, at most a few times a second.
          final now = DateTime.now();
          if (now.difference(_lastPoke) > const Duration(milliseconds: 400)) {
            pokeControls();
          }
        },
        child: child,
      );

  /// Call from dispose.
  void disposeAutoHide() => _autoHide?.cancel();
}
