import 'package:flutter/widgets.dart';

import '../data/vanish_controller.dart';
import '../models/chat_message.dart';
import '../privacy/capture_protection.dart';

/// What the open room tells its bubbles about vanish mode, without any of them
/// being rebuilt per frame: the scope itself changes only when vanish flips on
/// or off, and each countdown ring listens to [controller] for itself.
///
/// Absent outside a room (the lifted copy in the action menu, previews): every
/// reader treats "no scope" as "nothing is vanishing here".
class VanishScope extends InheritedWidget {
  const VanishScope({
    super.key,
    required this.controller,
    required this.roomVanishOn,
    required this.onChangeTimer,
    this.canChange = false,
    this.currentSeconds = 10,
    this.sealsOverride,
    required super.child,
  });

  final VanishController controller;

  /// `room.vanishMode`.
  final bool roomVanishOn;

  /// Whether this viewer may change the timer (anyone in a DM; admins in a
  /// group): the system line offers "Change" only then.
  final bool canChange;

  /// The room's current timer, `room.vanishAfterSeen`.
  final int currentSeconds;

  /// "Change" on the system line: opens the timer picker.
  final void Function(BuildContext context, int currentSeconds) onChangeTimer;

  /// Tests stand a browser in for the host.
  final bool? sealsOverride;

  /// Whether vanish messages from others are sealed on this device: where
  /// screenshots cannot be blocked (web, Linux) a vanishing message is shown
  /// as the "Opens in the app" panel and never counts as seen.
  bool get seals => sealsOverride ?? !CaptureProtection.platformProtects;

  static VanishScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VanishScope>();

  /// Whether [m] is drawn sealed here.
  bool sealsMessage(ChatMessage m, {required bool isMine}) =>
      seals && m.vanishUntil != null && !isMine;

  @override
  bool updateShouldNotify(VanishScope old) =>
      old.roomVanishOn != roomVanishOn ||
      old.canChange != canChange ||
      old.currentSeconds != currentSeconds ||
      old.controller != controller ||
      old.sealsOverride != sealsOverride;
}

/// Set around a message whose reply quote points at a parent that has since
/// vanished, so the quote can say "Vanished" instead of "Message removed".
class VanishedParentScope extends InheritedWidget {
  const VanishedParentScope({
    super.key,
    required this.vanished,
    required super.child,
  });

  final bool vanished;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VanishedParentScope>()
          ?.vanished ??
      false;

  @override
  bool updateShouldNotify(VanishedParentScope old) => old.vanished != vanished;
}
