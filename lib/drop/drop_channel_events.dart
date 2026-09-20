import 'dart:ui' show Offset;

import 'drop_item.dart';

/// What a [DropChannel] implementation calls as a drag moves over the window.
///
/// A record of callbacks rather than an interface, because the only subscriber
/// there will ever be is `DropController` and the only implementers are the
/// two platform files — an abstract class here would be three declarations of
/// the same four lines.
class DropChannelHandlers {
  const DropChannelHandlers({
    required this.onEnter,
    required this.onMove,
    required this.onLeave,
    required this.onPerform,
  });

  /// A drag has come over the window. [at] is in Flutter's own global
  /// (logical-pixel, top-left origin) space — both platform files do the
  /// conversion, so nothing downstream has to know that AppKit measures from
  /// the bottom.
  final void Function(DropSnapshot snapshot, Offset at) onEnter;

  /// The pointer moved while still over the window. Throttled on the platform
  /// side; see each implementation for the threshold.
  final void Function(Offset at) onMove;

  /// The drag left the window, or was cancelled.
  final void Function() onLeave;

  /// The user let go. The future completes when the bundle has been consumed,
  /// which is what the platform waits on before releasing anything it staged.
  final Future<void> Function(DropBundle bundle, Offset at) onPerform;
}
