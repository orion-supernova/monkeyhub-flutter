import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import 'liquid_glass.dart' show SpecularRim;

/// The shared transcript frame for interactive attachments and map cards.
/// Neutral glass lighting and its specular edge are painted without a backdrop
/// pass: a transcript can contain many cards beneath the floating glass chrome.
class AttachmentBubbleFrame extends StatelessWidget {
  const AttachmentBubbleFrame({
    super.key,
    required this.theme,
    required this.radius,
    required this.child,
    this.width,
    this.padding = EdgeInsets.zero,
    this.clipBehavior = Clip.none,
  });

  final AppTheme theme;
  final BorderRadius radius;
  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final dark = theme.background.computeLuminance() < 0.4;
    final base = const Color(0xFFFFFFFF).withValues(alpha: dark ? 0.07 : 0.72);
    return Container(
      width: width,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              const Color(0xFFFFFFFF).withValues(alpha: dark ? 0.055 : 0.25),
              base,
            ),
            base,
          ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: dark ? const Color(0x0AFFFFFF) : const Color(0x08000000),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF000000,
            ).withValues(alpha: dark ? 0.14 : 0.025),
            blurRadius: 16,
            offset: Offset.zero,
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: SpecularRim(
          shape: RoundedRectangleBorder(borderRadius: radius),
          light: !dark,
          width: 0.8,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

Color attachmentBubbleFill(AppTheme theme) => Color.alphaBlend(
  const Color(
    0xFFFFFFFF,
  ).withValues(alpha: theme.background.computeLuminance() < 0.4 ? 0.07 : 0.72),
  theme.background,
);

Color attachmentRowFill(AppTheme theme) {
  final fill = attachmentBubbleFill(theme);
  final dark = fill.computeLuminance() < 0.4;
  return Color.lerp(
    fill,
    dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    dark ? 0.035 : 0.025,
  )!;
}

Color attachmentEdge(AppTheme theme) => Color.alphaBlend(
  theme.ink.withValues(alpha: 0.07),
  attachmentBubbleFill(theme),
);

final _inkCache = Expando<({Color secondary, Color action})>('attachment inks');

({Color secondary, Color action}) _attachmentInks(AppTheme theme) =>
    _inkCache[theme] ??= (
      secondary: _readableInk(theme.inkMuted, theme),
      action: _readableInk(theme.accent, theme),
    );

Color attachmentSecondaryInk(AppTheme theme) =>
    _attachmentInks(theme).secondary;

Color attachmentActionInk(AppTheme theme) => _attachmentInks(theme).action;

final _preferredInkCache = Expando<Map<Color, Color>>('attachment accent inks');

Color attachmentReadableInk(AppTheme theme, Color preferred) =>
    (_preferredInkCache[theme] ??= <Color, Color>{}).putIfAbsent(
      preferred,
      () => _readableInk(preferred, theme),
    );

Color _readableInk(Color preferred, AppTheme theme) {
  final fill = attachmentBubbleFill(theme);
  final top = Color.lerp(
    fill,
    const Color(0xFFFFFFFF),
    fill.computeLuminance() < 0.4 ? 0.055 : 0.25,
  )!;
  final grounds = [fill, top, attachmentRowFill(theme)];
  bool readable(Color ink) => grounds.every((ground) {
    final a = ink.computeLuminance();
    final b = ground.computeLuminance();
    return (a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05)) >= 4.5;
  });
  if (readable(preferred)) return preferred;
  for (var step = 1; step <= 32; step++) {
    final ink = Color.lerp(preferred, theme.ink, step / 32)!;
    if (readable(ink)) return ink;
  }
  return fill.computeLuminance() < 0.179
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
}

TextStyle attachmentMetaStyle(AppTheme theme) => theme.bodySoft.copyWith(
  fontSize: 13,
  letterSpacing: 0,
  fontFeatures: const [FontFeature.tabularFigures()],
  color: attachmentSecondaryInk(theme),
);

/// A quiet type indicator; color belongs to the small icon, not a filled tile.
class AttachmentKindLabel extends StatelessWidget {
  const AttachmentKindLabel({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    this.color,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: color ?? attachmentActionInk(theme)),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          label,
          style: attachmentMetaStyle(theme).copyWith(
            color: attachmentSecondaryInk(theme),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
