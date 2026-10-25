import 'package:flutter/material.dart';

import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';

/// A laptop with a phone leaning on it, both talking in chat bubbles: the
/// hero of the Devices screen. Drawn, not an asset, so it follows the theme's
/// accent (soft lavender tones on Signal-blue themes) in dark and light.
class LinkedDevicesIllustration extends StatelessWidget {
  const LinkedDevicesIllustration({super.key, this.width = 168});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final accent = theme.accent;
    // A lavender pulled toward the accent: reads as "the accent, but quiet".
    final lav = Color.lerp(const Color(0xFFB9B4F7), accent, 0.35)!;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(width, width * 0.62),
        painter: _Painter(
          accent: accent,
          screen: lav,
          outline: Color.lerp(lav, theme.isLight ? Colors.black : Colors.white, 0.25)!,
          bubble: theme.isLight ? Colors.white : const Color(0xFFF2F1FF),
          bubbleInk: Color.lerp(accent, Colors.white, 0.3)!,
        ),
      ),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter({
    required this.accent,
    required this.screen,
    required this.outline,
    required this.bubble,
    required this.bubbleInk,
  });

  final Color accent, screen, outline, bubble, bubbleInk;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = outline;

    // Laptop lid.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.04, w * 0.74, h * 0.72),
      Radius.circular(w * 0.045),
    );
    canvas.drawRRect(
      lid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [screen.withValues(alpha: 0.95), screen.withValues(alpha: 0.55)],
        ).createShader(lid.outerRect),
    );
    canvas.drawRRect(lid, stroke);

    // Laptop base.
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.78, w * 0.82, h * 0.09),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(base, Paint()..color = screen);
    canvas.drawRRect(base, stroke);

    // Chat bubbles on the laptop screen.
    void pill(double x, double y, double bw, Color c, {bool filled = true}) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * x, h * y, w * bw, h * 0.1),
        Radius.circular(h * 0.05),
      );
      canvas.drawRRect(r, Paint()..color = c);
      if (!filled) canvas.drawRRect(r, stroke);
    }

    pill(0.12, 0.17, 0.34, bubble);
    pill(0.30, 0.33, 0.38, accent.withValues(alpha: 0.9));
    pill(0.12, 0.49, 0.28, bubble);

    // Phone, in front of the laptop's right edge.
    final phone = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.66, h * 0.30, w * 0.30, h * 0.66),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(
      phone.shift(Offset(0, h * 0.01)),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawRRect(phone, Paint()..color = Color.lerp(screen, Colors.white, 0.35)!);
    canvas.drawRRect(phone, stroke);
    final inner = phone.deflate(w * 0.018);
    canvas.drawRRect(inner, Paint()..color = screen.withValues(alpha: 0.5));

    void pPill(double y, double bw, Color c, {bool right = false}) {
      final pw = phone.width;
      final x = right ? phone.left + pw * (0.86 - bw) : phone.left + pw * 0.14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, phone.top + phone.height * y, pw * bw, h * 0.075),
          Radius.circular(h * 0.04),
        ),
        Paint()..color = c,
      );
    }

    pPill(0.2, 0.62, bubble);
    pPill(0.4, 0.55, accent.withValues(alpha: 0.9), right: true);
    pPill(0.6, 0.45, bubble);

    // A little sparkle of "link": two dots between the devices.
    final dot = Paint()..color = bubbleInk;
    canvas.drawCircle(Offset(w * 0.60, h * 0.90), w * 0.012, dot);
    canvas.drawCircle(Offset(w * 0.55, h * 0.90), w * 0.008, dot..color = bubbleInk.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_Painter o) =>
      o.accent != accent || o.screen != screen || o.bubble != bubble || o.outline != outline;
}
