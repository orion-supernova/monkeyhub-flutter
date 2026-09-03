import 'package:flutter/widgets.dart';

import '../platform.dart';

/// Drops the soft keyboard when the user taps a part of the screen that isn't
/// itself interactive.
///
/// Forms with no "done" affordance — every auth screen — otherwise trap the
/// keyboard over the very buttons the user is trying to reach: `TextField`
/// keeps focus until something else takes it, and on iOS/Android nothing ever
/// does. Flutter's own `onTapOutside` default only unfocuses on desktop, which
/// is exactly the platform that doesn't need it.
///
/// Two deliberate properties, both matching the transcript tap in
/// `room_screen.dart` that has done this for a while:
///
///  * **Desktop and web are excluded.** There is no soft keyboard to dismiss
///    there, and clearing focus on every background click would silently break
///    Enter-to-submit after any stray click on the form.
///  * **[HitTestBehavior.translucent], not opaque.** The tap is claimed only
///    where nothing else claims it — a deeper recognizer (a field, a button,
///    a scroll drag) wins the arena as it did before, so wrapping a subtree
///    changes nothing about how its own controls behave.
///
/// Tapping straight from one field into another still works: the second field
/// wins the arena and takes focus in the same frame, so the keyboard never
/// leaves the screen.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (isPhysicalKeyboardPlatform) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Not a control, and announcing one here would put a full-screen
      // unlabelled tap target in front of every field for VoiceOver.
      excludeFromSemantics: true,
      // Default disposition hands focus back to the enclosing scope rather
      // than nulling it, so Tab traversal still has somewhere to resume from
      // on a tablet with a keyboard attached.
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
