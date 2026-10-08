import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'glass_reveal.dart';
import 'glass_surface.dart';
import 'ios_kit.dart';
import 'teardown_safe.dart';

/// One choice in a [showPullDownMenu].
class PullDownItem<T> {
  const PullDownItem({
    required this.value,
    required this.label,
    this.icon,
    this.checked = false,
    this.destructive = false,
    this.startsGroup = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// Draws the leading checkmark: the current choice of a picker.
  final bool checked;
  final bool destructive;

  /// Opens a new section: a thick gap above it, iOS's group separator.
  final bool startsGroup;
}

/// UIKit's pull-down menu: a glass panel that grows out of the control that
/// opened it, a checkmark on the current choice, sections split by a thick
/// gap. Resolves to the picked value, or null when dismissed.
///
/// The app's long-press menus (`showMessageActionMenu`,
/// `showChatRowActionMenu`) lift a preview over a dimmed screen; this is the
/// lighter sibling for a control that just wants a value picked — a settings
/// row's "Never ⌃⌄", a toolbar's sort button. Same glass, same row, same
/// entrance, no scrim.
///
/// Anchored to [anchorKey]'s box: trailing edges aligned, below it when there
/// is room and above it when there is not, and pinned inside the safe area
/// whatever the anchor's position.
Future<T?> showPullDownMenu<T>({
  required BuildContext context,
  required GlobalKey anchorKey,
  required List<PullDownItem<T>> items,
}) {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.attached) return Future.value();
  final anchor = box.localToGlobal(Offset.zero) & box.size;
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<T?>();
  HapticFeedback.selectionClick();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _PullDownOverlay<T>(
      anchor: anchor,
      items: items,
      onResolve: (v) {
        if (!completer.isCompleted) completer.complete(v);
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _PullDownOverlay<T> extends StatefulWidget {
  const _PullDownOverlay({
    required this.anchor,
    required this.items,
    required this.onResolve,
  });

  final Rect anchor;
  final List<PullDownItem<T>> items;
  final ValueChanged<T?> onResolve;

  @override
  State<_PullDownOverlay<T>> createState() => _PullDownOverlayState<T>();
}

class _PullDownOverlayState<T> extends State<_PullDownOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 160),
  )..forward();
  bool _closing = false;

  static const _width = 250.0;
  static const _rowH = 46.0;
  static const _groupGap = 8.0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _close([T? value]) async {
    if (_closing) return;
    _closing = true;
    await _c.reverse();
    widget.onResolve(value);
  }

  double get _height {
    var h = 12.0; // vertical padding
    for (var i = 0; i < widget.items.length; i++) {
      h += _rowH;
      if (i > 0 && widget.items[i].startsGroup) h += _groupGap;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final safe = mq.padding;
    final screen = mq.size;
    final h = _height;
    final below = widget.anchor.bottom + 6 + h <= screen.height - safe.bottom - 8;
    final top = below
        ? widget.anchor.bottom + 6
        : math.max(safe.top + 8, widget.anchor.top - 6 - h);
    final right = (screen.width - widget.anchor.right)
        .clamp(12.0, screen.width - _width - 12.0);
    final origin = below ? Alignment.topRight : Alignment.bottomRight;

    return OverlayModalScope(
      onDismiss: _close,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            top: top,
            right: right,
            width: _width,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, child) => GlassReveal(
                // Unfolds out of the row that opened it, never faded: see
                // [GlassReveal] for the flicker a fade puts on glass.
                t: Curves.easeOutCubic.transform(_c.value),
                alignment: origin,
                child: child!,
              ),
              child: _panel(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final theme = ThemeScope.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (i > 0) {
        rows.add(item.startsGroup
            ? Container(height: _groupGap, color: theme.ink.withValues(alpha: 0.06))
            : Container(
                height: 1 / MediaQuery.devicePixelRatioOf(context),
                color: theme.ink.withValues(alpha: 0.10),
              ));
      }
      rows.add(_PullDownRow<T>(item: item, onTap: () {
        HapticFeedback.selectionClick();
        _close(item.value);
      }));
    }
    return Material(
      type: MaterialType.transparency,
      child: GlassSurface(
        radius: theme.radiusLg + 6,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

class _PullDownRow<T> extends StatefulWidget {
  const _PullDownRow({required this.item, required this.onTap});
  final PullDownItem<T> item;
  final VoidCallback onTap;

  @override
  State<_PullDownRow<T>> createState() => _PullDownRowState<T>();
}

class _PullDownRowState<T> extends State<_PullDownRow<T>>
    with TeardownSafe<_PullDownRow<T>> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final item = widget.item;
    final color = item.destructive ? theme.danger : theme.ink;
    final label = sentenceCaseOf(context, item.label);
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
          height: _PullDownOverlayState._rowH - 1,
          padding: const EdgeInsets.only(left: 12, right: 16),
          color: _pressed ? theme.ink.withValues(alpha: 0.08) : Colors.transparent,
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: item.checked
                    ? Icon(CupertinoIcons.checkmark_alt, size: 18, color: color)
                    : null,
              ),
              Expanded(
                child: Text(
                  label,
                  style: groupedTitleStyle(theme)
                      .copyWith(color: color, letterSpacing: -0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.icon != null) ...[
                const SizedBox(width: 12),
                Icon(item.icon, size: 19, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row whose value is picked from a [showPullDownMenu]: the value
/// in muted ink with UIKit's up-down chevron, the menu opening from the row's
/// trailing edge. The "Never ⌃⌄" of Telegram's auto-remove rows.
class PullDownRow<T> extends StatefulWidget implements GroupedInsetRow {
  const PullDownRow({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    this.icon,
    this.tone = TileTone.accent,
    this.subtitle,
  });

  final String title;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? icon;
  final TileTone tone;
  final String? subtitle;

  @override
  double get groupedInset => icon == null ? 16 : 60;

  @override
  State<PullDownRow<T>> createState() => _PullDownRowWidgetState<T>();
}

class _PullDownRowWidgetState<T> extends State<PullDownRow<T>> {
  final _anchor = GlobalKey();

  Future<void> _open() async {
    final picked = await showPullDownMenu<T>(
      context: context,
      anchorKey: _anchor,
      items: [
        for (final o in widget.options)
          PullDownItem(
            value: o,
            label: widget.labelOf(o),
            checked: o == widget.value,
          ),
      ],
    );
    if (picked != null && picked != widget.value) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GroupedRow(
      title: widget.title,
      icon: widget.icon,
      tone: widget.tone,
      subtitle: widget.subtitle,
      chevron: false,
      onTap: _open,
      trailing: Row(
        key: _anchor,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: theme.motionFast,
            child: Text(
              widget.labelOf(widget.value),
              key: ValueKey(widget.value),
              style: groupedValueStyle(theme),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_up_chevron_down,
            size: 13,
            color: theme.inkMuted.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}
