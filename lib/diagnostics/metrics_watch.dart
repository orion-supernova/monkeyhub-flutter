import 'dart:ui' as ui;

import 'diag_buffer.dart';
import 'diag_event.dart';
import 'diag_log.dart';

/// Watches window metrics — the padding, insets and scale that decide where
/// every `SafeArea` in the app puts its child.
///
/// This is the most targeted detector in the whole feature. The bug it was
/// built for shows up as the entire UI strobing, taps landing on nothing, and
/// the keyboard closing the frame after it opens — and the one mechanism that
/// produces all three at once is a window whose insets keep changing, because
/// every layout in the app moves with them and a gesture that starts on one
/// frame finishes somewhere else.
///
/// Two behaviours matter here:
///
///  * **Emit only on actual change.** `didChangeMetrics` fires for plenty of
///    no-ops, and a timeline full of identical rows hides the signal.
///  * **Collapse a storm into one warning.** If the insets really are
///    oscillating, the honest capture is hundreds of events per second, which
///    would evict everything else in the buffer within seconds — the log would
///    prove a storm happened and lose all the context explaining why. So past
///    [_stormThreshold] changes in a second we emit one `warn` naming the field
///    that is flapping and the values it flaps between, then stay quiet for the
///    rest of that second.
class MetricsWatch {
  MetricsWatch._();
  static final MetricsWatch instance = MetricsWatch._();

  /// Changes within one second past which we stop emitting individually.
  static const int _stormThreshold = 20;

  _Sample? _last;
  int _windowStartMs = 0;
  int _changesThisWindow = 0;
  bool _stormReported = false;

  /// Values seen for the field that changed most, so the storm line can say
  /// what it is oscillating between rather than just how often.
  final Map<String, Set<double>> _flapping = {};

  void onMetricsChanged() {
    if (!DiagLog.enabled) return;
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) return;

    final dpr = view.devicePixelRatio;
    final next = _Sample(
      dpr: dpr,
      width: view.physicalSize.width,
      height: view.physicalSize.height,
      padTop: view.viewPadding.top / dpr,
      padBottom: view.viewPadding.bottom / dpr,
      insetBottom: view.viewInsets.bottom / dpr,
      insetTop: view.viewInsets.top / dpr,
    );

    final prev = _last;
    _last = next;
    if (prev == null) {
      DiagLog.add(
        cat: DiagCat.layout,
        sev: DiagSev.info,
        event: 'metrics',
        detail: 'initial ${next.describe()}',
      );
      return;
    }

    final changed = next.diff(prev);
    if (changed.isEmpty) return; // genuine no-op callback

    final now = DiagBuffer.instance.uptimeMs;
    if (now - _windowStartMs > 1000) {
      // New second. If the previous one was a storm, say how it ended.
      _windowStartMs = now;
      _changesThisWindow = 0;
      _stormReported = false;
      _flapping.clear();
    }
    _changesThisWindow++;
    for (final e in changed.entries) {
      _flapping.putIfAbsent(e.key, () => <double>{}).add(e.value);
    }

    if (_changesThisWindow > _stormThreshold) {
      if (_stormReported) return; // stay quiet for the rest of this second
      _stormReported = true;
      final worst = _flapping.entries.reduce(
        (a, b) => a.value.length >= b.value.length ? a : b,
      );
      final values = worst.value.toList()..sort();
      DiagLog.add(
        cat: DiagCat.layout,
        sev: DiagSev.warn,
        event: 'storm',
        detail:
            'metrics storm: $_changesThisWindow changes in 1s · '
            '${worst.key} oscillating ${values.join('↔')}',
      );
      return;
    }

    DiagLog.add(
      cat: DiagCat.layout,
      sev: DiagSev.debug,
      event: 'metrics',
      detail: changed.entries
          .map((e) => '${e.key}=${e.value.toStringAsFixed(1)}')
          .join(' '),
    );
  }

  void resetForTest() {
    _last = null;
    _windowStartMs = 0;
    _changesThisWindow = 0;
    _stormReported = false;
    _flapping.clear();
  }
}

class _Sample {
  const _Sample({
    required this.dpr,
    required this.width,
    required this.height,
    required this.padTop,
    required this.padBottom,
    required this.insetBottom,
    required this.insetTop,
  });

  final double dpr;
  final double width;
  final double height;
  final double padTop;
  final double padBottom;
  final double insetBottom;
  final double insetTop;

  /// Fields whose value differs from [other], with the NEW value.
  Map<String, double> diff(_Sample other) {
    final out = <String, double>{};
    void cmp(String k, double a, double b) {
      // Sub-pixel jitter is noise, not a layout change.
      if ((a - b).abs() > 0.5) out[k] = a;
    }

    cmp('dpr', dpr, other.dpr);
    cmp('w', width, other.width);
    cmp('h', height, other.height);
    cmp('padTop', padTop, other.padTop);
    cmp('padBottom', padBottom, other.padBottom);
    cmp('insetBottom', insetBottom, other.insetBottom);
    cmp('insetTop', insetTop, other.insetTop);
    return out;
  }

  String describe() =>
      'w=${width.toStringAsFixed(0)} h=${height.toStringAsFixed(0)} '
      'dpr=${dpr.toStringAsFixed(2)} padTop=${padTop.toStringAsFixed(1)} '
      'padBottom=${padBottom.toStringAsFixed(1)} '
      'insetBottom=${insetBottom.toStringAsFixed(1)}';
}
