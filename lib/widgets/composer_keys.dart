import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../keyboard/app_shortcuts.dart' show KeyCombo;
import '../models/message_formatting.dart';
import '../platform.dart';
import 'mention_text_controller.dart';

/// The composer's own keyboard: the keys that only mean something while the
/// cursor is in the message field, listed in the catalog as ambient
/// (`AppShortcuts.bold`, `.italic`, `.underline`, `.editLast`, `.pasteMedia`).
///
///  * **⌘B / ⌘I / ⌘U** toggle bold, italic and underline over the selection,
///    through the same [MentionTextController.toggleFormat] the format chips
///    use. Formatting is selection-applied in this app, so with nothing
///    selected the keys do nothing and fall through.
///  * **↑ in an empty field** edits your last message, the Slack/Telegram
///    habit. Only when empty: with text in the field ↑ moves the caret, and
///    stealing it would make a multi-line draft impossible to navigate.
///  * **⌘V** first offers the clipboard to [onPasteMedia]: a copied file,
///    or a screenshot, attaches through the same intake a drop takes. When it
///    declines, the ordinary text paste runs exactly as it would have.
///
/// Like [SubmitOnEnter], a `Focus(onKeyEvent:)` above the field rather than
/// `Shortcuts`, because each of these has to be able to say "not mine" and let
/// the key carry on. And every one of them stands down while an IME is
/// composing: there ↑ walks the candidate list and ⌘V is the IME's.
class ComposerKeys extends StatelessWidget {
  const ComposerKeys({
    super.key,
    required this.controller,
    required this.child,
    this.onEditLast,
    this.onPasteMedia,
  });

  final TextEditingController controller;
  final Widget child;

  /// Arms an edit of the viewer's last editable message. False when there is
  /// none, which lets ↑ through.
  final bool Function()? onEditLast;

  /// Looks at the clipboard and, if it holds files or an image, sends them
  /// and answers true. False runs the plain text paste. Null leaves ⌘V
  /// entirely to the field (web, where the browser's own paste event is
  /// listened to instead).
  final Future<bool> Function()? onPasteMedia;

  static bool get _primary {
    final keys = HardwareKeyboard.instance;
    return KeyCombo.appleModifiers ? keys.isMetaPressed : keys.isControlPressed;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.synthesized) {
      return KeyEventResult.ignored;
    }
    if (controller.value.composing.isValid) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    final primary = _primary;
    final other = keys.isAltPressed ||
        keys.isShiftPressed ||
        (KeyCombo.appleModifiers
            ? keys.isControlPressed
            : keys.isMetaPressed);

    if (primary && !other) {
      final type = switch (key) {
        LogicalKeyboardKey.keyB => FormattingType.bold,
        LogicalKeyboardKey.keyI => FormattingType.italic,
        LogicalKeyboardKey.keyU => FormattingType.underline,
        _ => null,
      };
      if (type != null) {
        final c = controller;
        final sel = c.selection;
        if (c is! MentionTextController || !sel.isValid || sel.isCollapsed) {
          return KeyEventResult.ignored;
        }
        c.toggleFormat(type, sel);
        return KeyEventResult.handled;
      }
      final paste = onPasteMedia;
      if (key == LogicalKeyboardKey.keyV && paste != null) {
        // Taken from the field now, before the await: the text fallback has
        // to be invoked from inside the field's own Actions.
        final field = FocusManager.instance.primaryFocus?.context;
        _paste(paste, field);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp &&
        !primary &&
        !other &&
        !keys.isControlPressed &&
        !keys.isMetaPressed &&
        controller.text.isEmpty) {
      final edit = onEditLast;
      if (edit != null && edit()) return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static Future<void> _paste(
    Future<bool> Function() paste,
    BuildContext? field,
  ) async {
    var took = false;
    try {
      took = await paste();
    } catch (_) {
      took = false;
    }
    if (took || field == null || !field.mounted) return;
    Actions.maybeInvoke<PasteTextIntent>(
      field,
      const PasteTextIntent(SelectionChangedCause.keyboard),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isPhysicalKeyboardPlatform) return child;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }
}
