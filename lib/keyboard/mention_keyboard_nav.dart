import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/mention_session.dart';

/// Lets Up/Down/Enter/Tab/Escape drive the `@`-picker while it is open.
///
/// ## Why this is its own node rather than more branches in `SubmitOnEnter`
///
/// The two guard different things and are gated differently. `SubmitOnEnter`
/// only exists where there is a physical keyboard, because reinterpreting the
/// return key on a soft keyboard would take away the only way to type a
/// newline. This has no such problem — a soft keyboard never emits ArrowDown,
/// Tab or Escape at all — and gating it would deny a tablet with a Bluetooth
/// keyboard the whole feature, so it ships ungated.
///
/// ## Why it must sit INSIDE `SubmitOnEnter`
///
/// Key events dispatch from the primary focus node upward, so the innermost
/// node sees them first: field → this → `SubmitOnEnter` → … →
/// `DefaultTextEditingShortcuts` at the root. Two things fall out of that
/// ordering for free:
///
///  * Enter reaches here before `SubmitOnEnter`. With the picker open we return
///    [KeyEventResult.handled] and the send never fires; with it closed we
///    return [KeyEventResult.ignored] and today's behaviour is untouched, to
///    the keystroke.
///  * The arrows reach here before the framework's caret-movement actions,
///    which live above us — the same mechanism that already lets
///    `SubmitOnEnter` beat Enter-inserts-a-newline.
///
/// Inside the thread overlay there is a third beneficiary: `OverlayModalScope`
/// binds Escape to dismissal, and it is an ancestor, so Escape closes the
/// picker first and only closes the overlay on a second press. That is the
/// right precedence and nothing had to ask for it.
class MentionKeyboardNav extends StatelessWidget {
  const MentionKeyboardNav({
    super.key,
    required this.session,
    required this.child,
  });

  /// Null in every composer that has no picker wired up — the thread overlay
  /// before its roster arrives, a test, a preview. The widget then adds no node
  /// at all, so it cannot change how keys are routed.
  final MentionSession? session;

  final Widget child;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final s = session;
    if (s == null || !s.isOpen) return KeyEventResult.ignored;

    // Same three filters `SubmitOnEnter` applies, for the same reasons:
    // KeyRepeatEvent is a distinct subclass so holding a key doesn't fire
    // repeatedly, `synthesized` events are focus-change bookkeeping, and a
    // chord belongs to somebody else.
    if (event is! KeyDownEvent || event.synthesized) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed || keys.isAltPressed || keys.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        s.moveActive(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        s.moveActive(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        s.dismiss();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab:
        // Must be handled rather than ignored: left alone, traversal would
        // move focus out of the field the user is still typing in.
        if (keys.isShiftPressed) return KeyEventResult.ignored;
        return s.accept() ? KeyEventResult.handled : KeyEventResult.ignored;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        // Shift+Enter is the newline, and stays one even with the list open.
        if (keys.isShiftPressed) return KeyEventResult.ignored;
        // An Enter that commits an IME candidate is not an Enter that picks a
        // name. Deferring here lets it fall through to `SubmitOnEnter`, which
        // reads the same flag and declines it too.
        if (s.controller.value.composing.isValid) {
          return KeyEventResult.ignored;
        }
        return s.accept() ? KeyEventResult.handled : KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (session == null) return child;
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
