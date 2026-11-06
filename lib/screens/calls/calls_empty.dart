import 'dart:ui' show PathMetric;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/action_buttons.dart';
import '../../widgets/chrome_motion.dart';

/// The empty Calls list. A small line glyph plays once as it appears: the
/// handset rocks like a phone ringing on a table (nothing yet), or a check
/// draws itself (nothing missed). It never loops.
class CallsEmpty extends StatefulWidget {
  const CallsEmpty({super.key, required this.missedOnly, this.onNewCall});

  final bool missedOnly;
  final VoidCallback? onNewCall;

  @override
  State<CallsEmpty> createState() => _CallsEmptyState();
}

class _CallsEmptyState extends State<CallsEmpty>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  int _kick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MotionScope.of(context).calm) {
        _draw.value = 1;
      } else {
        _draw.forward();
        setState(() => _kick = 1);
      }
    });
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final missed = widget.missedOnly;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 24),
      child: Column(
        children: [
          SizedBox.square(
            dimension: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GlyphPainter(
                        progress: _draw,
                        color: theme.inkMuted.withValues(alpha: 0.55),
                        check: missed,
                        checkColor: theme.accent,
                      ),
                    ),
                  ),
                ),
                if (!missed)
                  KickGlyph(
                    kick: GlyphKick.rock,
                    trigger: _kick,
                    amplitude: 1.6,
                    child: Icon(
                      CupertinoIcons.phone,
                      size: 34,
                      color: theme.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            missed ? l10n.callsTabEmptyMissedTitle : l10n.callsTabEmptyTitle,
            textAlign: TextAlign.center,
            style: theme.displaySmall.copyWith(color: theme.ink),
          ),
          const SizedBox(height: 6),
          Text(
            missed ? l10n.callsTabEmptyMissedMessage : l10n.callsTabEmptyMessage,
            textAlign: TextAlign.center,
            style: theme.bodySoft.copyWith(fontSize: 15, color: theme.inkMuted),
          ),
          if (!missed && widget.onNewCall != null) ...[
            const SizedBox(height: 20),
            SheetActionButton(
              label: l10n.callsTabNewCall,
              onTap: widget.onNewCall,
              tonal: true,
              expand: false,
              minHeight: 44,
            ),
          ],
        ],
      ),
    );
  }
}

/// A circle that draws itself and, for the "all caught up" state, a check
/// inside it.
class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.progress,
    required this.color,
    required this.check,
    required this.checkColor,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final bool check;
  final Color checkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(progress.value);
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final ring = Path()..addOval(rect.deflate(2));
    _drawPartial(canvas, ring, stroke, t.clamp(0.0, 1.0));
    if (check) {
      final c = rect.center;
      final path = Path()
        ..moveTo(c.dx - size.width * 0.16, c.dy + 1)
        ..lineTo(c.dx - size.width * 0.04, c.dy + size.height * 0.12)
        ..lineTo(c.dx + size.width * 0.18, c.dy - size.height * 0.12);
      final tc = ((progress.value - 0.35) / 0.65).clamp(0.0, 1.0);
      _drawPartial(
        canvas,
        path,
        stroke
          ..color = checkColor
          ..strokeWidth = 3.5,
        Curves.easeOutBack.transform(tc).clamp(0.0, 1.0),
      );
    }
  }

  static void _drawPartial(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    for (final PathMetric m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.check != check || old.checkColor != checkColor;
}
