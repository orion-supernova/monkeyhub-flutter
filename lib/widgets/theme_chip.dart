import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show groupedMetaStyle;
import 'spring_press.dart';

class ThemeChip extends StatefulWidget {
  const ThemeChip({super.key});

  @override
  State<ThemeChip> createState() => _ThemeChipState();
}

class _ThemeChipState extends State<ThemeChip> {
  final GlobalKey _anchorKey = GlobalKey();
  bool _expanded = false;
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  void _toggle() {
    if (_expanded) {
      _close();
    } else {
      _open();
    }
  }

  void _close() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _expanded = false);
  }

  void _open() {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final overlay = Overlay.of(context, rootOverlay: true);
    _overlay = OverlayEntry(builder: (ctx) {
      final theme = ThemeScope.of(context);
      final controller = ThemeScope.controllerOf(context);
      // Esc closes the popover, same as tapping outside it.
      return OverlayModalScope(
        onDismiss: _close,
        child: Stack(
        children: [
          // Tap-outside dismiss layer.
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _close),
          ),
          Positioned(
            top: origin.dy + size.height + 6,
            right: MediaQuery.of(ctx).size.width - (origin.dx + size.width),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: theme.chipDecoration(filled: true),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in ThemeController.all)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SpringPress(
                          onTap: () {
                            controller.theme = t;
                            _close();
                          },
                          semanticLabel: t.name,
                          child: _SwatchDot(
                            colors: t.swatch,
                            size: 20,
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
    });
    overlay.insert(_overlay!);
    setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = sentenceCaseOf(
      context,
      AppLocalizations.of(context).roomGridTileThemeChipLabel,
    );
    return SpringPress(
      onTap: _toggle,
      semanticLabel: label,
      child: AnimatedContainer(
        key: _anchorKey,
        duration: theme.motionMed,
        curve: theme.motionCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: theme.chipDecoration(filled: false),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SwatchDot(colors: theme.swatch, size: 14, active: true),
            const SizedBox(width: 8),
            Text(
              label,
              style: groupedMetaStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
                color: theme.inkSoft,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0.0,
              duration: theme.motionFast,
              child: Icon(
                CupertinoIcons.chevron_down,
                size: 12,
                color: theme.inkMuted,
              ),
            ),
          ],
        ),
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
