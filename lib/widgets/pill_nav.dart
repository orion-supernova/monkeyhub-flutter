import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

class PillNavItem {
  const PillNavItem({required this.id, required this.label, this.badge});
  final String id;
  final String label;
  final String? badge;
}

class PillNav extends StatefulWidget {
  const PillNav({
    super.key,
    required this.items,
    required this.activeId,
    required this.onChange,
  });

  final List<PillNavItem> items;
  final String activeId;
  final ValueChanged<String> onChange;

  @override
  State<PillNav> createState() => _PillNavState();
}

class _PillNavState extends State<PillNav> {
  final GlobalKey _rowKey = GlobalKey();
  late List<GlobalKey> _keys;
  Rect? _activeRect;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.items.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant PillNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _keys = List.generate(widget.items.length, (_) => GlobalKey());
      _settled = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final idx = widget.items.indexWhere((i) => i.id == widget.activeId);
    if (idx < 0 || idx >= _keys.length) return;
    final itemCtx = _keys[idx].currentContext;
    final rowCtx = _rowKey.currentContext;
    if (itemCtx == null || rowCtx == null) return;
    final itemBox = itemCtx.findRenderObject() as RenderBox?;
    final rowBox = rowCtx.findRenderObject() as RenderBox?;
    if (itemBox == null || rowBox == null) return;
    if (!itemBox.hasSize || !rowBox.hasSize) return;
    final offset = itemBox.localToGlobal(Offset.zero, ancestor: rowBox);
    final rect = offset & itemBox.size;
    if (rect != _activeRect || !_settled) {
      setState(() {
        _activeRect = rect;
        _settled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: theme.chipDecoration(filled: false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_activeRect != null)
            AnimatedPositioned(
              duration: _settled ? theme.motionFast : Duration.zero,
              curve: Curves.easeOutCubic,
              left: _activeRect!.left,
              top: _activeRect!.top,
              width: _activeRect!.width,
              height: _activeRect!.height,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          Row(
            key: _rowKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                _PillItem(
                  key: _keys[i],
                  item: widget.items[i],
                  active: widget.items[i].id == widget.activeId,
                  onTap: () => widget.onChange(widget.items[i].id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({super.key, required this.item, required this.active, required this.onTap});
  final PillNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: AnimatedDefaultTextStyle(
          duration: theme.motionFast,
          curve: Curves.easeOutCubic,
          style: theme.label.copyWith(
            color: active ? theme.accentInk : theme.inkSoft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.label),
              if (item.badge != null) ...[
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: theme.motionFast,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? theme.accentInk.withValues(alpha: 0.18)
                        : theme.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.badge!,
                    style: theme.monoTiny.copyWith(color: active ? theme.accentInk : theme.accent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
