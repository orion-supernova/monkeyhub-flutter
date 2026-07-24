import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../platform.dart';

/// Makes a bare Enter submit a multi-line [TextField], while Shift+Enter keeps
/// its normal "insert a newline" meaning.
///
/// ## Why this exists rather than `onSubmitted`
///
/// A multi-line field never fires `onSubmitted` — Flutter routes Enter to a
/// newline instead. Every composer in this app had `onSubmitted: (_) =>
/// onSend()` wired up and it was dead code for exactly that reason. Setting
/// `textInputAction` instead would be worse: it replaces the soft keyboard's
/// return key on mobile, so phone users would lose the ability to type a
/// newline at all.
///
/// So the key has to be intercepted. Key events dispatch from the primary focus
/// node *upward*, and this node sits directly above the field, so it sees Enter
/// before the newline is inserted; returning [KeyEventResult.handled]
/// suppresses it, [KeyEventResult.ignored] lets it through untouched.
///
/// A `Focus(onKeyEvent:)` is used rather than `CallbackShortcuts` or
/// `Shortcuts`+`Actions` because those report `handled` unconditionally once
/// they match — there is no way to say "actually, pass this one through", which
/// is precisely what the IME guard below needs to do.
///
/// ## Why it's desktop-only
///
/// On a soft keyboard the return key is the only way to type a newline, so
/// reinterpreting it would strip functionality. The composing-range guard below
/// also can't be trusted on Android, where Gboard keeps a composing range for
/// ordinary autocorrect.
class SubmitOnEnter extends StatelessWidget {
  const SubmitOnEnter({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.child,
    this.enabled = true,
  });

  /// Must be the same controller the wrapped field uses — it's read for its
  /// composing range, which is the IME guard.
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final Widget child;

  /// Seam for a future "Enter sends / Cmd+Enter sends" preference.
  final bool enabled;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // KeyRepeatEvent is a distinct subclass, not a KeyDownEvent — so holding
    // Enter sends exactly once. `synthesized` events are engine bookkeeping
    // emitted to reconcile state after a focus change, not real presses.
    if (event is! KeyDownEvent || event.synthesized) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }

    final keys = HardwareKeyboard.instance;
    // Shift+Enter is the newline. Ctrl/Alt/Meta+Enter belong to someone else,
    // or to nobody — either way, not to us.
    if (keys.isShiftPressed ||
        keys.isControlPressed ||
        keys.isAltPressed ||
        keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    // An IME is mid-composition (a Japanese/Chinese/Korean candidate window is
    // open): this Enter commits the candidate, it is not a send. The composing
    // range is the only signal the framework surfaces at this layer.
    if (controller.value.composing.isValid) return KeyEventResult.ignored;

    onSubmit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled || !isPhysicalKeyboardPlatform) return child;
    return Focus(
      // Not a focus stop of its own — the field below owns the focus, this node
      // only listens on the way up.
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }
}
