import 'package:flutter/widgets.dart';

/// Stub. Off the web the app draws Google's button itself and calls
/// `authenticate()`, so nothing asks for this.
Widget renderGoogleWebButton({
  required bool onDark,
  required double width,
  required String locale,
}) =>
    throw UnsupportedError("Google's rendered button exists on the web only.");
