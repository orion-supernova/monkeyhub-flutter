import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'glass_hud.dart';

/// A running progress dialog. Obtain from [showGlassProgress].
class GlassProgressHandle {
  GlassProgressHandle._(this._state, this._route, this._navigator);

  final ValueNotifier<_ProgressState> _state;
  final GlassOverlayRoute<void> _route;
  final NavigatorState _navigator;
  bool _closed = false;

  /// Changes whatever is non-null. [progress] is 0..1; the ring animates to it.
  void update({String? title, String? message, double? progress}) {
    if (_closed) return;
    final s = _state.value;
    _state.value = _ProgressState(
      title ?? s.title,
      message ?? s.message,
      progress == null ? s.progress : progress.clamp(0.0, 1.0),
    );
  }

  /// Dismisses the dialog (safe to call twice).
  void close() {
    if (_closed) return;
    _closed = true;
    if (_route.isCurrent) {
      _navigator.pop();
    } else if (_route.isActive) {
      _navigator.removeRoute(_route);
    }
  }
}

class _ProgressState {
  const _ProgressState(this.title, this.message, this.progress);
  final String title;
  final String? message;
  final double? progress;
}

/// Signal-style centred progress dialog: ring, title, message, Cancel.
/// Starts indeterminate; call [GlassProgressHandle.update] with `progress`
/// to make the ring determinate. Cancel is hidden when [onCancel] is null;
/// it looks disabled at 100%. [cancelLabel] defaults to the platform's own.
GlassProgressHandle showGlassProgress(
  BuildContext context, {
  required String title,
  String? message,
  VoidCallback? onCancel,
  String? cancelLabel,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final calm = MotionScope.of(context).calm;
  final label = cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel;
  final state = ValueNotifier(_ProgressState(title, message, null));
  final route = GlassOverlayRoute<void>(
    calm: calm,
    builder: (_) => ValueListenableBuilder<_ProgressState>(
      valueListenable: state,
      builder: (context, s, _) => _GlassProgressCard(
        state: s,
        onCancel: onCancel,
        cancelLabel: label,
      ),
    ),
  );
  navigator.push<void>(route);
  final handle = GlassProgressHandle._(state, route, navigator);
  route.popped.whenComplete(() {
    handle._closed = true;
    state.dispose();
  });
  return handle;
}

class _GlassProgressCard extends StatelessWidget {
  const _GlassProgressCard({
    required this.state,
    required this.onCancel,
    required this.cancelLabel,
  });

  final _ProgressState state;
  final VoidCallback? onCancel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final done = (state.progress ?? 0) >= 1;
    final enabled = onCancel != null && !done;
    return GlassOverlayCard(
      width: 270,
      radius: (theme.radiusXl * 1.4).clamp(10.0, 30.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(value: state.progress),
                const SizedBox(height: 16),
                Text(
                  state.title,
                  textAlign: TextAlign.center,
                  style: theme.body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                  ),
                ),
                if (state.message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    state.message!,
                    textAlign: TextAlign.center,
                    style: theme.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: theme.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCancel != null) ...[
            Container(height: 0.5, color: theme.ink.withValues(alpha: 0.16)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? onCancel : null,
              child: Container(
                height: 46,
                alignment: Alignment.center,
                child: Text(
                  cancelLabel,
                  style: theme.body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: enabled
                        ? theme.accent
                        : theme.inkMuted.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A thin circular progress ring. [value] null spins (a static quarter arc
/// under calm motion); otherwise the arc animates smoothly to [value].
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    this.value,
    this.size = 44,
    this.strokeWidth = 3,
    this.color,
  });

  final double? value;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  void _sync(bool calm) {
    if (widget.value == null && !calm) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(MotionScope.of(context).calm);
  }

  @override
  void didUpdateWidget(ProgressRing old) {
    super.didUpdateWidget(old);
    _sync(MotionScope.of(context).calm);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = widget.color ?? theme.accent;
    final track = theme.ink.withValues(alpha: 0.14);
    final calm = MotionScope.of(context).calm;
    final v = widget.value;
    Widget paint(double sweep, double rotation) => CustomPaint(
          size: Size.square(widget.size),
          painter: _RingPainter(
            sweep: sweep,
            rotation: rotation,
            color: color,
            track: track,
            stroke: widget.strokeWidth,
          ),
        );
    if (v == null) {
      return AnimatedBuilder(
        animation: _spin,
        builder: (_, _) => paint(0.28, _spin.value * 2 * math.pi),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: v),
      duration: calm ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) => paint(value, 0),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.sweep,
    required this.rotation,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double sweep;
  final double rotation;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, p..color = track);
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + rotation,
        2 * math.pi * sweep.clamp(0.0, 1.0),
        false,
        p..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.sweep != sweep ||
      o.rotation != rotation ||
      o.color != color ||
      o.track != track ||
      o.stroke != stroke;
}
