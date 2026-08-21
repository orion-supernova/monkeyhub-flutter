import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../platform.dart';

/// Rebinds Tab / Shift+Tab so desktop focus traversal reports the key as
/// *handled* even when it moves focus out of a text field.
///
/// ## The bug this fixes
///
/// `WidgetsApp` already binds Tab to `NextFocusIntent`, and traversal does move
/// the focus. But `NextFocusAction.toKeyEventResult` reports `handled` only when
/// `FocusNode.nextFocus()` returns true, and on macOS that call reports false
/// while still moving focus whenever the node it moved *away from* is a text
/// field. The framework therefore tells the engine "nobody wanted this key", the
/// macOS embedder falls back to `NSTextInputClient`, and AppKit's `insertTab:`
/// types a tab character into whichever field now holds focus. The user sees
/// focus land in the next field with a blob of whitespace already in it, which
/// reads as "Tab is broken and inserts a space".
///
/// Reproducible with two bare `TextField`s and nothing else — this is framework
/// behaviour, not something this app's widgets cause. `TargetPlatform.iOS`
/// reports `handled` for the same key, which is why the same screen behaves
/// correctly when the iOS build runs on an Apple silicon Mac.
///
/// `CallbackShortcuts` is what makes the difference: it returns
/// `KeyEventResult.handled` the moment a binding matches, unconditionally, so
/// the key never reaches the engine no matter what traversal reports.
///
/// ## Where it has to sit
///
/// Inside `MaterialApp.builder`. `WidgetsApp` nests its own `Shortcuts` and
/// `DefaultTextEditingShortcuts` *above* the builder's output, and shortcut
/// resolution walks up from the focused node, so a binding installed here is
/// consulted before either of them. Anything closer to a field still wins over
/// this — `MentionKeyboardNav` keeps its Tab-accepts-a-mention behaviour, since
/// its `Focus` node sits directly on the composer.
///
/// ## Why it is gated
///
/// Not on web: there Flutter maps Tab to `DoNothingAndStopPropagationTextIntent`
/// on purpose so the *browser* can move focus out of the Flutter canvas and into
/// page chrome, and `TraversalEdgeBehavior.leaveFlutterView` depends on the key
/// staying unhandled. Taking it over there would trap Tab inside the app.
///
/// Not on mobile: no Tab key, nothing to fix, and an iPad with a Bluetooth
/// keyboard already gets correct traversal from the iOS path above.
class DesktopTabTraversal extends StatelessWidget {
  const DesktopTabTraversal({super.key, required this.child});

  final Widget child;

  /// Same call `NextFocusAction` makes — only the reported result differs.
  static void _next() => primaryFocus?.nextFocus();

  static void _previous() => primaryFocus?.previousFocus();

  @override
  Widget build(BuildContext context) {
    // `isPhysicalKeyboardPlatform` deliberately does not short-circuit on web
    // (see platform.dart), so the `kIsWeb` guard here is doing real work: it is
    // what keeps Flutter-web-on-a-Mac out.
    if (kIsWeb || !isPhysicalKeyboardPlatform) return child;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Bare Tab only. `SingleActivator` requires the unlisted modifiers to
        // be up, so Cmd+Tab and Ctrl+Tab still belong to the OS.
        const SingleActivator(LogicalKeyboardKey.tab): _next,
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): _previous,
      },
      child: child,
    );
  }
}
