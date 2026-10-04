import 'package:flutter/material.dart';

import 'filter_capsule.dart';

class PillNavItem {
  const PillNavItem({required this.id, required this.label, this.badge});
  final String id;
  final String label;

  /// A count already formatted for display ("12", "99+"). A plain number
  /// rides as the capsule's tabular count; anything else is appended to the
  /// label.
  final String? badge;
}

/// A row of mutually-exclusive tabs — the shared-content screen's Media /
/// Files / Voice / Links / Saved strip.
///
/// Drawn as THE filter chips ([FilterCapsule]) rather than a private pill
/// with its own sliding thumb: it is the same control as the chat list's
/// facets, and the private copy set its labels in the theme's tracked
/// `label` slot (monospace on a character theme) with no keyboard focus.
/// The picked tab is scrolled into view whenever it changes, so a strip
/// wider than the phone never hides the tab you are on.
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
  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.items.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(covariant PillNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _keys = List.generate(widget.items.length, (_) => GlobalKey());
    }
    if (oldWidget.activeId != widget.activeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    if (!mounted) return;
    final idx = widget.items.indexWhere((i) => i.id == widget.activeId);
    if (idx < 0 || idx >= _keys.length) return;
    final ctx = _keys[idx].currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.items.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          _chip(i),
        ],
      ],
    );
  }

  Widget _chip(int i) {
    final item = widget.items[i];
    final badge = item.badge;
    final n = badge == null ? null : int.tryParse(badge);
    return FilterCapsule(
      key: _keys[i],
      label: badge != null && n == null ? '${item.label} $badge' : item.label,
      count: n,
      active: item.id == widget.activeId,
      onTap: () => widget.onChange(item.id),
    );
  }
}
