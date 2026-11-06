import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'glass_hud.dart';
import 'progress_ring.dart';

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
                ProgressRing.spinner(value: state.progress),
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
