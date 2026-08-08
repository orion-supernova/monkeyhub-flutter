import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';

enum ChatRowAction { pin, unpin, archive, unarchive }

/// Long-press context menu for a chat-list row.
///
/// Modeled on `message_action_menu.dart`'s `showMessageActionMenu` — same
/// anchor-then-root-overlay technique — but deliberately smaller: no lifted-
/// bubble animation, no reaction pill, just a scrim and a 1-2 row menu
/// anchored below (or above, near the bottom edge) the tapped row. Kept
/// self-contained rather than sharing that file's private row widgets, since
/// this menu's action set and positioning are both much simpler.
///
/// [isArchived] alone decides the row set: an archived room only offers
/// Unarchive — pinning something that's simultaneously archived-and-hidden
/// from the main list is a confusing combination not worth exposing, whether
/// this is opened from the main list or from the Archived Chats sheet.
Future<ChatRowAction?> showChatRowActionMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required bool isPinned,
  required bool isArchived,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final anchorCtx = anchorKey.currentContext;
  if (anchorCtx == null) return null;
  final rb = anchorCtx.findRenderObject() as RenderBox?;
  if (rb == null || !rb.attached) return null;

  final topLeft = rb.localToGlobal(Offset.zero);
  final anchorRect = topLeft & rb.size;
  final screenSize = MediaQuery.sizeOf(context);
  final safeInsets = MediaQuery.paddingOf(context);

  final completer = Completer<ChatRowAction?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ChatRowActionMenuOverlay(
      anchorRect: anchorRect,
      screenSize: screenSize,
      safeInsets: safeInsets,
      isPinned: isPinned,
      isArchived: isArchived,
      onResolve: (result) {
        if (!completer.isCompleted) completer.complete(result);
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _ChatRowActionMenuOverlay extends StatefulWidget {
  const _ChatRowActionMenuOverlay({
    required this.anchorRect,
    required this.screenSize,
    required this.safeInsets,
    required this.isPinned,
    required this.isArchived,
    required this.onResolve,
  });

  final Rect anchorRect;
  final Size screenSize;
  final EdgeInsets safeInsets;
  final bool isPinned;
  final bool isArchived;
  final ValueChanged<ChatRowAction?> onResolve;

  @override
  State<_ChatRowActionMenuOverlay> createState() =>
      _ChatRowActionMenuOverlayState();
}

class _ChatRowActionMenuOverlayState extends State<_ChatRowActionMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _closing = false;

  static const double _menuWidth = 220;
  static const double _rowHeight = 48;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resolve(ChatRowAction? result) async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onResolve(result);
  }

  List<ChatRowAction> get _actions => widget.isArchived
      ? const [ChatRowAction.unarchive]
      : [
          widget.isPinned ? ChatRowAction.unpin : ChatRowAction.pin,
          ChatRowAction.archive,
        ];

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    final menuHeight = actions.length * _rowHeight + 12;

    // Prefer opening below the row; flip above it when there isn't room
    // before the bottom safe inset.
    final spaceBelow =
        widget.screenSize.height -
        widget.safeInsets.bottom -
        widget.anchorRect.bottom;
    final openBelow = spaceBelow >= menuHeight + 12;
    final top = openBelow
        ? widget.anchorRect.bottom + 6
        : (widget.anchorRect.top - menuHeight - 6).clamp(
            widget.safeInsets.top + 6,
            widget.screenSize.height,
          );

    var left = widget.anchorRect.left;
    if (left + _menuWidth > widget.screenSize.width - 12) {
      left = widget.screenSize.width - _menuWidth - 12;
    }
    left = left.clamp(12.0, widget.screenSize.width - _menuWidth - 12);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _resolve(null),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.08 * _ctrl.value),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: _menuWidth,
              child: Opacity(
                opacity: _ctrl.value,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    (openBelow ? -1 : 1) * 8 * (1 - _ctrl.value),
                  ),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * _ctrl.value,
                    alignment: openBelow
                        ? Alignment.topLeft
                        : Alignment.bottomLeft,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: GlassSurface(
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in actions)
              _ChatRowActionRow(action: action, onTap: () => _resolve(action)),
          ],
        ),
      ),
    );
  }
}

class _ChatRowActionRow extends StatefulWidget {
  const _ChatRowActionRow({required this.action, required this.onTap});
  final ChatRowAction action;
  final VoidCallback onTap;

  @override
  State<_ChatRowActionRow> createState() => _ChatRowActionRowState();
}

class _ChatRowActionRowState extends State<_ChatRowActionRow> {
  bool _pressed = false;

  (IconData, String) _spec(AppLocalizations l10n) => switch (widget.action) {
    ChatRowAction.pin => (CupertinoIcons.pin, l10n.chatRowActionMenuPinLabel),
    ChatRowAction.unpin => (
      CupertinoIcons.pin_slash,
      l10n.chatRowActionMenuUnpinLabel,
    ),
    ChatRowAction.archive => (
      CupertinoIcons.archivebox,
      l10n.chatRowActionMenuArchiveLabel,
    ),
    ChatRowAction.unarchive => (
      CupertinoIcons.tray_arrow_up,
      l10n.chatRowActionMenuUnarchiveLabel,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final (icon, label) = _spec(AppLocalizations.of(context));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: _pressed ? theme.accentSoft : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: theme.label.copyWith(color: theme.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
