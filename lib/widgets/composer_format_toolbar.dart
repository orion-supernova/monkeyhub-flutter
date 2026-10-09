import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../keyboard/app_shortcuts.dart' show AppShortcuts, ShortcutDef;
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/message_formatting.dart';
import '../theme/theme_scope.dart';
import 'hover_hint.dart';
import 'ios_kit.dart' show quietFill;
import 'link_input_sheet.dart';
import 'mention_text_controller.dart';

/// The composer's `contextMenuBuilder`: one FORMAT item that swaps the
/// toolbar's content for a row of style chips, ahead of the platform's own
/// selection toolbar (copy/cut/paste/select-all, untouched and in the
/// platform's own order) — Telegram's arrangement, chosen for the same reason
/// Telegram chose it: seven formatting actions crammed beside the native items
/// would overflow into the "…" menu on every phone, which buries the feature
/// it exists to surface.
///
/// FORMAT comes FIRST for the same reason it isn't a chip row: the Cupertino
/// toolbar paginates behind a chevron and the Material one behind a "⋮", and
/// on a narrow phone with a selection live (Cut/Copy/Paste/Select All/Look
/// Up/Search Web/Share) a trailing item is exactly the one that gets pushed
/// off page one. Index 0 is the only position that can't be paginated away.
///
/// A plain function rather than a widget so `chat_composer.dart`'s two
/// deliberately-duplicated variants can each pass it inline. Degrades to the
/// stock toolbar when the controller isn't a [MentionTextController] (a bare
/// test) or when nothing is selected — formatting is selection-applied only.
Widget buildComposerContextMenu(
  BuildContext context,
  EditableTextState state,
) {
  final controller = state.widget.controller;
  final c = controller;
  if (c is! MentionTextController) {
    return AdaptiveTextSelectionToolbar.editableText(editableTextState: state);
  }
  return _ComposerContextMenu(state: state, controller: c);
}

class _ComposerContextMenu extends StatefulWidget {
  const _ComposerContextMenu({required this.state, required this.controller});

  final EditableTextState state;
  final MentionTextController controller;

  @override
  State<_ComposerContextMenu> createState() => _ComposerContextMenuState();
}

class _ComposerContextMenuState extends State<_ComposerContextMenu> {
  /// Whether the toolbar is showing the chip row instead of the native items.
  /// Local state on purpose: dismissing the toolbar resets it, so the NEXT
  /// long-press starts from the native items again.
  bool _formatMode = false;

  TextSelection get _selection => widget.controller.selection;

  void _toggle(FormattingType type) {
    widget.controller.toggleFormat(type, _selection);
    widget.state.hideToolbar();
  }

  Future<void> _editLink() async {
    final controller = widget.controller;
    // Captured BEFORE the toolbar goes away — hiding it can normalize the
    // selection out from under a later read.
    final selection = _selection;
    // The sheet outlives this toolbar (hideToolbar unmounts it), so
    // navigation happens from the FIELD's context, which stays mounted.
    final host = widget.state.context;
    widget.state.hideToolbar();
    final result = await showLinkInputSheet(
      host,
      initialUrl: controller.linkAt(selection),
    );
    if (result == null) return;
    if (result.removed) {
      controller.removeLink(selection);
    } else if (result.url != null) {
      controller.applyLink(selection, result.url!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final l10n = AppLocalizations.of(context);
    final selection = _selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    if (!_formatMode) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: state.contextMenuAnchors,
        buttonItems: [
          if (hasSelection)
            ContextMenuButtonItem(
              label: l10n.formatToolbarFormatLabel,
              onPressed: () => setState(() => _formatMode = true),
            ),
          ...state.contextMenuButtonItems,
        ],
      );
    }

    final theme = ThemeScope.of(context);
    final c = widget.controller;
    // Each chip DRAWS its own format — B in bold, S struck through — so the
    // row needs no legend; the semantic labels carry the words.
    TextStyle chipStyle([TextStyle? extra]) =>
        theme.bodyEmph.copyWith(color: theme.ink).merge(extra);

    Widget chip({
      required Widget child,
      required String label,
      required bool active,
      required VoidCallback onTap,
      // The composer's own ⌘B/⌘I/⌘U (see ComposerKeys), printed beside the
      // name so the chip teaches the faster way.
      ShortcutDef? shortcut,
    }) =>
        // A glyph is all a chip shows, so a mouse gets its name on hover.
        // FocusableTap carries the button semantics, the cursor and the
        // hover fill; it never takes focus on click, so the selection in the
        // field survives.
        HoverHint(
          label: label,
          shortcut: shortcut,
          child: FocusableTap(
            onTap: onTap,
            semanticLabel: label,
            selected: active,
            radius: theme.radiusSm,
            hover: HoverEffect.tint,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? quietFill(theme) : Colors.transparent,
                  borderRadius: BorderRadius.circular(theme.radiusSm),
                ),
                child: child,
              ),
            ),
          ),
        );

    return AdaptiveTextSelectionToolbar(
      anchors: state.contextMenuAnchors,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              chip(
                child: Text('B',
                    style: chipStyle(
                        const TextStyle(fontWeight: FontWeight.w800))),
                label: l10n.formatToolbarBoldLabel,
                shortcut: AppShortcuts.bold,
                active: c.selectionHas(FormattingType.bold, selection),
                onTap: () => _toggle(FormattingType.bold),
              ),
              chip(
                child: Text('I',
                    style:
                        chipStyle(const TextStyle(fontStyle: FontStyle.italic))),
                label: l10n.formatToolbarItalicLabel,
                shortcut: AppShortcuts.italic,
                active: c.selectionHas(FormattingType.italic, selection),
                onTap: () => _toggle(FormattingType.italic),
              ),
              chip(
                child: Text('S',
                    style: chipStyle(const TextStyle(
                        decoration: TextDecoration.lineThrough))),
                label: l10n.formatToolbarStrikethroughLabel,
                active:
                    c.selectionHas(FormattingType.strikethrough, selection),
                onTap: () => _toggle(FormattingType.strikethrough),
              ),
              chip(
                child: Text('U',
                    style: chipStyle(
                        const TextStyle(decoration: TextDecoration.underline))),
                label: l10n.formatToolbarUnderlineLabel,
                shortcut: AppShortcuts.underline,
                active: c.selectionHas(FormattingType.underline, selection),
                onTap: () => _toggle(FormattingType.underline),
              ),
              chip(
                child: Icon(CupertinoIcons.eye_slash,
                    size: 18, color: theme.ink),
                label: l10n.formatToolbarSpoilerLabel,
                active: c.selectionHas(FormattingType.spoiler, selection),
                onTap: () => _toggle(FormattingType.spoiler),
              ),
              chip(
                child: Icon(CupertinoIcons.link, size: 18, color: theme.ink),
                label: l10n.formatToolbarLinkLabel,
                active: c.linkAt(selection) != null,
                onTap: _editLink,
              ),
              chip(
                child: Icon(CupertinoIcons.chevron_left_slash_chevron_right,
                    size: 16, color: theme.ink),
                label: l10n.formatToolbarCodeLabel,
                active: c.selectionHas(FormattingType.code, selection),
                onTap: () => _toggle(FormattingType.code),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
