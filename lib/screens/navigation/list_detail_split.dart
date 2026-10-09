import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/settings_store.dart';
import '../../theme/layout.dart';
import '../../theme/theme_scope.dart';

/// The split shell's master/detail row: a list column on the left, a hairline,
/// and the detail filling the rest.
///
/// The list's width is the one number here that is not fixed. It defaults to
/// [defaultExpanded] in a wide window and [defaultMedium] in a medium one, and
/// with [resizable] the user can drag the divider to anywhere in
/// [minWidth]–[maxWidth] (double-click puts it back), which is remembered in
/// [SettingsStore.chatListWidth]. Whatever the preference, the detail is never
/// squeezed under [minDetail]: the list gives way first. See [resolve].
///
/// ## What a drag costs
///
/// Only the list's [SizedBox] width changes per frame. [master] and [detail]
/// are built once by the caller and handed through identical, so a drag (or a
/// window resize) reruns this widget's small builder and re-lays out the two
/// sides — the transcript reflows the way it does for any window resize, and
/// [ChatMetrics] quantizes that — but neither side REBUILDS. The width lives
/// in a [ValueNotifier] here, not in [SettingsStore], because the shell
/// rebuilds on every notification from that store; it is written there once,
/// on release, by a setter that does not notify.
class ListDetailSplit extends StatefulWidget {
  const ListDetailSplit({
    super.key,
    required this.master,
    required this.detail,
    this.resizable = false,
  });

  final Widget master;
  final Widget detail;

  /// Show the drag handle on the divider and remember the dragged width.
  final bool resizable;

  static const double minWidth = 280;
  static const double maxWidth = 440;
  static const double defaultExpanded = 360;
  static const double defaultMedium = 300;

  /// The narrowest the detail side may get before the list stops growing.
  /// About a phone's width: a chat or a settings page narrower than that
  /// starts wrapping every line.
  static const double minDetail = 360;

  /// The list width actually laid out: [preferred] (or the class default when
  /// there is none), kept in [minWidth]–[maxWidth] and short enough to leave
  /// [minDetail] of [available].
  @visibleForTesting
  static double resolve({
    required double? preferred,
    required double available,
    required bool expanded,
  }) {
    final want = preferred ?? (expanded ? defaultExpanded : defaultMedium);
    final ceiling = math.max(minWidth, math.min(maxWidth, available - minDetail));
    return want.clamp(minWidth, ceiling).toDouble();
  }

  @override
  State<ListDetailSplit> createState() => _ListDetailSplitState();
}

class _ListDetailSplitState extends State<ListDetailSplit> {
  late final ValueNotifier<double?> _preferred = ValueNotifier<double?>(
    widget.resizable ? SettingsStore.instance.chatListWidth : null,
  );

  /// Width this row had at its last layout, so a drag can clamp to what the
  /// window allows rather than store a width it could never show.
  double _available = 0;

  double _dragStartWidth = 0;
  double _dragStartX = 0;

  @override
  void dispose() {
    _preferred.dispose();
    super.dispose();
  }

  double _ceiling() => math.max(
        ListDetailSplit.minWidth,
        math.min(
          ListDetailSplit.maxWidth,
          _available - ListDetailSplit.minDetail,
        ),
      );

  void _dragStart(DragStartDetails d, double current) {
    _dragStartWidth = current;
    _dragStartX = d.globalPosition.dx;
  }

  void _dragUpdate(DragUpdateDetails d) {
    _preferred.value = (_dragStartWidth + d.globalPosition.dx - _dragStartX)
        .clamp(ListDetailSplit.minWidth, _ceiling())
        .toDouble();
  }

  void _dragEnd() {
    final v = _preferred.value;
    if (v != null) SettingsStore.instance.setChatListWidth(v.roundToDouble());
  }

  void _reset() {
    _preferred.value = null;
    SettingsStore.instance.setChatListWidth(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final expanded = context.isExpanded;
    return LayoutBuilder(
      builder: (context, constraints) {
        _available = constraints.maxWidth;
        return ValueListenableBuilder<double?>(
          valueListenable: _preferred,
          builder: (context, preferred, _) {
            final width = ListDetailSplit.resolve(
              preferred: preferred,
              available: constraints.maxWidth,
              expanded: expanded,
            );
            final row = Row(
              children: [
                SizedBox(width: width, child: widget.master),
                VerticalDivider(
                  width: 0.5,
                  thickness: 0.5,
                  color: theme.divider,
                ),
                Expanded(child: RepaintBoundary(child: widget.detail)),
              ],
            );
            if (!widget.resizable) return row;
            return Stack(
              children: [
                Positioned.fill(child: row),
                // Straddles the hairline, mostly on the detail side: the
                // list's own scrollbar lives along its right edge and must
                // stay grabbable.
                Positioned(
                  left: width - 2,
                  top: 0,
                  bottom: 0,
                  width: 8,
                  child: _SplitHandle(
                    onDragStart: (d) => _dragStart(d, width),
                    onDragUpdate: _dragUpdate,
                    onDragEnd: _dragEnd,
                    onReset: _reset,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// The grabbable strip over the split's divider. Shows the column-resize
/// cursor, and thickens the hairline under the pointer so the target is
/// visible before it is grabbed — the way Finder's and Mail's dividers do.
///
/// Its hover state is its own: entering or leaving rebuilds this strip and
/// nothing else.
class _SplitHandle extends StatefulWidget {
  const _SplitHandle({
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onReset,
  });

  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onReset;

  @override
  State<_SplitHandle> createState() => _SplitHandleState();
}

class _SplitHandleState extends State<_SplitHandle> {
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final active = _hover || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          setState(() => _dragging = true);
          widget.onDragStart(d);
        },
        onHorizontalDragUpdate: widget.onDragUpdate,
        onHorizontalDragEnd: (_) {
          setState(() => _dragging = false);
          widget.onDragEnd();
        },
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        onDoubleTap: widget.onReset,
        child: Align(
          // The hairline sits 2px in from this strip's left edge.
          alignment: const Alignment(-0.7, 0),
          child: AnimatedContainer(
            duration: theme.motionFast,
            curve: Curves.easeOutCubic,
            width: active ? 3 : 0,
            color: theme.inkMuted.withValues(alpha: _dragging ? 0.6 : 0.4),
          ),
        ),
      ),
    );
  }
}
