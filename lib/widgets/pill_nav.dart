import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

class PillNavItem {
  const PillNavItem({required this.id, required this.label, this.badge});
  final String id;
  final String label;
  final String? badge;
}

class PillNav extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: theme.chipDecoration(filled: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in items)
            _PillItem(
              item: item,
              active: item.id == activeId,
              onTap: () => onChange(item.id),
            ),
        ],
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({required this.item, required this.active, required this.onTap});
  final PillNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? theme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: theme.label.copyWith(
                color: active ? theme.accentInk : theme.inkSoft,
              ),
            ),
            if (item.badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? theme.accentInk.withValues(alpha: 0.18) : theme.accent.withValues(alpha: 0.16),
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
    );
  }
}
