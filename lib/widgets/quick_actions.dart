import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'fit_label.dart';
import 'ios_kit.dart' show groupedFill, groupedMetaStyle, groupedRadius;
import 'sheet_kit.dart' show sheetGroupFill;
import 'spring_press.dart';

/// One tile of a [SheetQuickActions] row.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.busy = false,
    this.semanticLabel,
  });

  /// A FILLED Cupertino glyph — one style across the row (the profile row
  /// mixed outlined and filled glyphs).
  final IconData icon;
  final String label;

  /// Null greys the tile out.
  final VoidCallback? onTap;

  /// Red — Block, Report. iOS Contacts keeps these out of the row; prefer a
  /// destructive section below and use this only where the row IS the menu.
  final bool destructive;
  final bool busy;
  final String? semanticLabel;
}

/// THE row of icon-over-label tiles — Message / Call / Mute / Search on a
/// profile, Copy link / Share code on an invite. Equal widths, one tint rule
/// (accent glyph and label; red for [QuickAction.destructive]).
///
/// Labels are 13pt, wrap to two lines, then shrink — never an ellipsis
/// ("Mesaj g…", "Bağlantıyı …" in Turkish at 1.3× were the reason this
/// exists). When the row is too narrow for every tile to stay a usable
/// width, it breaks into two rows of equal tiles.
///
/// [onSheet] picks the grouped fill a sheet uses; the default is the page's.
class SheetQuickActions extends StatelessWidget {
  const SheetQuickActions({
    super.key,
    required this.actions,
    this.onSheet = false,
  });

  final List<QuickAction> actions;
  final bool onSheet;

  static const _gap = 8.0;

  /// Narrowest a tile may get before the row wraps, at 1× text.
  static const _minTile = 68.0;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, box) {
        final n = actions.length;
        final each = (box.maxWidth - _gap * (n - 1)) / n;
        final perRow = each >= _minTile * scale.clamp(1.0, 1.6) || n <= 2
            ? n
            : (n / 2).ceil();
        final rows = <List<QuickAction>>[
          for (var i = 0; i < n; i += perRow)
            actions.sublist(i, (i + perRow).clamp(0, n)),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: _gap),
              QuickTileRow(
                tiles: [
                  for (final a in rows[r])
                    QuickActionTile(
                      icon: a.icon,
                      label: a.label,
                      onTap: a.onTap,
                      destructive: a.destructive,
                      busy: a.busy,
                      onSheet: onSheet,
                      semanticLabel: a.semanticLabel,
                    ),
                ],
                // A short last row keeps the tile width of the rows above.
                slots: perRow,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Equal-width tiles in a row, all as tall as the tallest (a two-line label
/// stretches its neighbours too, so the row stays one band). Measured, not
/// `IntrinsicHeight`: the labels lay themselves out with a [LayoutBuilder],
/// which has no intrinsic size to report.
///
/// Public for a caller with its own tiles ([ProfileActionBar]); [slots]
/// defaults to one per tile.
class QuickTileRow extends StatelessWidget {
  const QuickTileRow({super.key, required this.tiles, this.slots});
  final List<Widget> tiles;
  final int? slots;

  @override
  Widget build(BuildContext context) => _EqualHeightRow(
        gap: SheetQuickActions._gap,
        slots: slots ?? tiles.length,
        children: tiles,
      );
}

class _EqualHeightRow extends MultiChildRenderObjectWidget {
  const _EqualHeightRow({
    required super.children,
    required this.gap,
    required this.slots,
  });

  final double gap;
  final int slots;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightRow(gap: gap, slots: slots);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightRow renderObject,
  ) {
    renderObject
      ..gap = gap
      ..slots = slots;
  }
}

class _RowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _RowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _RowParentData> {
  _RenderEqualHeightRow({required double gap, required int slots})
      : _gap = gap,
        _slots = slots;

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  int _slots;
  set slots(int v) {
    if (v == _slots) return;
    _slots = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowParentData) {
      child.parentData = _RowParentData();
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final slots = _slots < 1 ? 1 : _slots;
    final each = (width - _gap * (slots - 1)) / slots;
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      final h = child.getDryLayout(BoxConstraints.tightFor(width: each)).height;
      if (h > tallest) tallest = h;
      child = childAfter(child);
    }
    return constraints.constrain(Size(width, tallest));
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final slots = _slots < 1 ? 1 : _slots;
    final each = (width - _gap * (slots - 1)) / slots;
    // Pass 1: natural heights at the slot width.
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: each), parentUsesSize: true);
      if (child.size.height > tallest) tallest = child.size.height;
      child = childAfter(child);
    }
    // Pass 2: everyone at the tallest.
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: each, height: tallest));
      (child.parentData! as _RowParentData).offset = Offset(x, 0);
      x += each + _gap;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, tallest));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// One icon-over-label tile, for a caller laying tiles out itself (a grid).
/// Most callers want [SheetQuickActions].
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.busy = false,
    this.onSheet = false,
    this.tint,
    this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool busy;
  final bool onSheet;

  /// Overrides the accent (rare — a legacy ink-tinted tile).
  final Color? tint;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null && !busy;
    final tone = destructive ? theme.danger : (tint ?? theme.accent);
    final ink = onTap != null ? tone : theme.inkMuted.withValues(alpha: 0.6);
    final text = sentenceCaseOf(context, label);
    return SpringPress(
      onTap: enabled ? onTap : null,
      semanticLabel: semanticLabel ?? text,
      scale: PressSpec.scaleSmall,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: onSheet ? sheetGroupFill(theme) : groupedFill(theme),
          borderRadius: BorderRadius.circular(
            (groupedRadius(theme) * 0.7).clamp(6.0, 16.0),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 9),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 22,
              child: Center(
                child: busy
                    ? CupertinoActivityIndicator(color: tone, radius: 9)
                    : Icon(icon, size: 22, color: ink),
              ),
            ),
            const SizedBox(height: 5),
            FitLabel(
              text,
              maxLines: 2,
              minFontSize: 10,
              style: groupedMetaStyle(theme).copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
                height: 1.15,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
