import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'teardown_safe.dart';

/// THE row of a context menu: the hold menu on a message, the long-press menu
/// on a chat row, the pull-down menu, the pointer menu on a desk. One widget
/// owns the label, the glyph, the destructive ink, the keyboard stop, the
/// semantics and the pressed tint; each menu passes its own metrics.
///
/// Two modes, because the two input families answer "which row is lit"
/// differently:
///
///  * the default, a TOUCH row: a neutral wash under the finger while it is
///    down, the label leading and the glyph trailing, a keyboard focus stop;
///  * [MenuRow.pointer], a DESK row: the parent decides which row is
///    [highlighted] (hover and arrow keys share one cursor), the lit row
///    fills with the accent and turns its ink to match.
///
/// Rows are tap-only by design (the hold menu's slide-to-react belongs to its
/// emoji pill, not to these), and none of them fires a haptic itself: the
/// menu that owns the selection decides when the selection ticks.
class MenuRow extends StatefulWidget {
  const MenuRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
    this.height = 47,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.leading,
    this.divider = false,
    this.fontSize = 17,
    this.lineHeight,
    this.iconSize = 19,
  })  : highlighted = null,
        onHover = null,
        iconFirst = false;

  /// A desk menu's row: 28pt-class, glyph leading, filled-capsule highlight.
  const MenuRow.pointer({
    super.key,
    required this.label,
    required this.onTap,
    required bool this.highlighted,
    required ValueChanged<bool> this.onHover,
    this.icon,
    this.destructive = false,
    this.height = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.fontSize = 14,
    this.lineHeight = 1.2,
    this.iconSize = 15,
  })  : leading = null,
        divider = false,
        iconFirst = true;

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool destructive;
  final double height;
  final EdgeInsetsGeometry padding;

  /// A fixed slot before the label (a pull-down menu's check column).
  final Widget? leading;

  /// A hairline under the row, drawn inside its height (a chat-row menu's
  /// separators, which the overlay's placement maths already counts).
  final bool divider;
  final double fontSize;

  /// Null leaves the theme's own line height.
  final double? lineHeight;
  final double iconSize;

  /// Null on a touch row; the parent's cursor on a pointer row.
  final bool? highlighted;
  final ValueChanged<bool>? onHover;
  final bool iconFirst;

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> with TeardownSafe<MenuRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = sentenceCaseOf(context, widget.label);
    final lit = widget.highlighted;
    final pointer = lit != null;

    final Color ink;
    if (pointer && lit) {
      ink = widget.destructive ? Colors.white : theme.accentInk;
    } else {
      ink = widget.destructive ? theme.danger : theme.ink;
    }

    final text = Expanded(
      child: Text(
        label,
        style: theme.body.copyWith(
          fontSize: widget.fontSize,
          height: widget.lineHeight,
          color: ink,
          letterSpacing: pointer ? -0.1 : -0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final glyph = widget.icon == null
        ? null
        : Icon(widget.icon, size: widget.iconSize, color: ink);
    final row = Row(
      children: [
        ?widget.leading,
        if (widget.iconFirst && glyph != null) ...[glyph, const SizedBox(width: 9)],
        text,
        if (!widget.iconFirst && glyph != null) ...[
          const SizedBox(width: 12),
          glyph,
        ],
      ],
    );

    if (pointer) {
      return MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => widget.onHover!(true),
        onExit: (_) => widget.onHover!(false),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: lit
                    ? (widget.destructive ? theme.danger : theme.accent)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: row,
            ),
          ),
        ),
      );
    }

    // FocusableTap so a keyboard can reach it; the pointer keeps the flat
    // wash below.
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: label,
      radius: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : const Duration(milliseconds: 200),
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _pressed ? theme.ink.withValues(alpha: 0.08) : null,
            border: widget.divider
                ? Border(
                    bottom: BorderSide(
                      color: theme.ink.withValues(alpha: 0.10),
                      width: 1 / MediaQuery.devicePixelRatioOf(context),
                    ),
                  )
                : null,
          ),
          child: row,
        ),
      ),
    );
  }
}
