import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'sheet_kit.dart' show sheetFill;

/// The route behind every centred glass overlay (progress dialog, HUD): a
/// scale 1.12 -> 1 + fade arrival (300 ms), 1 -> 0.92 + fade departure
/// (180 ms), on a black scrim. Under [MotionScope.calm] it is a plain
/// instant cut. The scrim ignores taps ([barrierDismissible] is false).
class GlassOverlayRoute<T> extends PopupRoute<T> {
  GlassOverlayRoute({
    required this.builder,
    required this.calm,
    this.scrim = 0.35,
  });

  final WidgetBuilder builder;
  final bool calm;
  final double scrim;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: scrim);

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration =>
      calm ? Duration.zero : const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration =>
      calm ? Duration.zero : const Duration(milliseconds: 180);

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> s) =>
      Center(child: builder(context));

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (calm) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final reversing = animation.status == AnimationStatus.reverse;
        final double scale;
        final double opacity;
        if (reversing) {
          final e = Curves.easeIn.transform(t);
          scale = 0.92 + 0.08 * e;
          opacity = e;
        } else {
          scale = 1 + 0.12 * (1 - const Cubic(0.2, 0.9, 0.1, 1.0).transform(t));
          opacity = Curves.easeOut.transform(t);
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

/// The solid card both overlays sit on (same fill as `showIosAlert`).
class GlassOverlayCard extends StatelessWidget {
  const GlassOverlayCard({
    super.key,
    required this.radius,
    required this.child,
    this.width,
    this.height,
  });

  final double radius;
  final double? width;
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: sheetFill(theme),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: theme.ink.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Shows a 160x160 HUD (icon + label), dismisses itself after [duration]
/// (counted from when it is shown) and completes the returned future once it
/// has left. With [success] the [icon] is replaced by an animated
/// circle-and-checkmark draw-in, like the Face ID success frame.
Future<void> showGlassHud(
  BuildContext context, {
  required IconData icon,
  required String label,
  Duration duration = const Duration(milliseconds: 1200),
  bool success = false,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final calm = MotionScope.of(context).calm;
  late final GlassOverlayRoute<void> route;
  Timer? timer;
  route = GlassOverlayRoute<void>(
    calm: calm,
    scrim: 0.12,
    builder: (_) => _GlassHud(icon: icon, label: label, success: success),
  );
  timer = Timer(duration, () {
    if (route.isCurrent) {
      navigator.pop();
    } else if (route.isActive) {
      navigator.removeRoute(route);
    }
  });
  final done = navigator.push<void>(route);
  return done.whenComplete(() => timer?.cancel());
}

class _GlassHud extends StatelessWidget {
  const _GlassHud({
    required this.icon,
    required this.label,
    required this.success,
  });

  final IconData icon;
  final String label;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Semantics(
      liveRegion: true,
      label: label,
      child: GlassOverlayCard(
        width: 160,
        height: 160,
        radius: 22,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: success
                  ? GlassHudCheck(size: 64, color: theme.ink)
                  : Icon(icon, size: 64, color: theme.ink),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.body.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A circle that strokes itself, then a checkmark (the Face ID success
/// frame). Fully drawn immediately under calm motion.
class GlassHudCheck extends StatefulWidget {
  const GlassHudCheck({
    super.key,
    this.size = 64,
    this.color,
    this.strokeWidth = 3.5,
  });

  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  State<GlassHudCheck> createState() => _GlassHudCheckState();
}

class _GlassHudCheckState extends State<GlassHudCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionScope.of(context).calm) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? ThemeScope.of(context).ink;
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _CheckPainter(_c, color, widget.strokeWidth),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color, this.stroke) : super(repaint: t);

  final Animation<double> t;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final v = t.value;
    final circleT = Curves.easeInOut.transform((v / 0.6).clamp(0.0, 1.0));
    final checkT = Curves.easeOut.transform(((v - 0.5) / 0.5).clamp(0.0, 1.0));
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    if (circleT > 0) {
      canvas.drawArc(r, -math.pi / 2, 2 * math.pi * circleT, false, p);
    }
    if (checkT > 0) {
      final a = Offset(size.width * 0.29, size.height * 0.52);
      final b = Offset(size.width * 0.44, size.height * 0.66);
      final c = Offset(size.width * 0.72, size.height * 0.36);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy);
      final m = path.computeMetrics().first;
      canvas.drawPath(m.extractPath(0, m.length * checkT), p);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.color != color || old.stroke != stroke || old.t != t;
}
