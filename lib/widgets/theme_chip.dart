import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

class ThemeChip extends StatefulWidget {
  const ThemeChip({super.key});

  @override
  State<ThemeChip> createState() => _ThemeChipState();
}

class _ThemeChipState extends State<ThemeChip> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final controller = ThemeScope.controllerOf(context);
    return AnimatedContainer(
      duration: theme.motionMed,
      curve: theme.motionCurve,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: theme.chipDecoration(filled: false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SwatchDot(colors: theme.swatch, size: 14, active: true),
                  const SizedBox(width: 8),
                  Text('THEME', style: theme.monoTiny),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: theme.motionFast,
                    child: Icon(Icons.expand_more, size: 14, color: theme.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.centerLeft,
              widthFactor: _expanded ? 1 : 0,
              duration: theme.motionFast,
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in ThemeController.all)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => controller.theme = t,
                          child: _SwatchDot(
                            colors: t.swatch,
                            size: 18,
                            active: t.id == theme.id,
                            borderColor: theme.inkSoft,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.colors,
    required this.size,
    required this.active,
    this.borderColor,
  });
  final List<Color> colors;
  final double size;
  final bool active;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [...colors, colors.first]),
        border: active
            ? Border.all(color: borderColor ?? colors.last, width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
    );
  }
}
