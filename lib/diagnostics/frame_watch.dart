import 'package:flutter/scheduler.dart';

import 'diag_event.dart';
import 'diag_log.dart';

/// Aggregates frame timings into one event per second.
///
/// A visible strobe is, by definition, something going wrong in rendering, so
/// measuring rendering directly beats inferring it from lifecycle events. The
/// distribution is the tell: a steady 60/120 fps with occasional jank looks
/// completely different from a device redrawing the world every frame, and
/// different again from one dropping frames in bursts.
///
/// **Never one event per frame.** At 120 Hz that is 120 events per second,
/// which would evict the entire buffer in half a minute and drown every other
/// category — the diagnostic would destroy the diagnosis. One row per second
/// carrying count, worst build, worst raster and jank count keeps the shape and
/// costs nothing.
class FrameWatch {
  FrameWatch._();
  static final FrameWatch instance = FrameWatch._();

  /// Frames slower than this are counted as jank. 16 ms is the 60 Hz budget;
  /// on a 120 Hz panel it is generous, which is the right way round — we want
  /// this to mean "definitely bad", not "technically late".
  static const int _jankMicros = 16000;

  bool _installed = false;
  int _windowStartMs = 0;
  int _frames = 0;
  int _jank = 0;
  int _worstBuild = 0;
  int _worstRaster = 0;

  void install() {
    if (_installed) return;
    _installed = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!DiagLog.enabled) return;

    for (final t in timings) {
      _frames++;
      final build = t.buildDuration.inMicroseconds;
      final raster = t.rasterDuration.inMicroseconds;
      if (build > _worstBuild) _worstBuild = build;
      if (raster > _worstRaster) _worstRaster = raster;
      if (build + raster > _jankMicros) _jank++;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_windowStartMs == 0) {
      _windowStartMs = now;
      return;
    }
    if (now - _windowStartMs < 1000) return;

    final elapsed = now - _windowStartMs;
    final fps = (_frames * 1000 / elapsed).round();
    final jank = _jank;
    final worstBuildMs = _worstBuild / 1000;
    final worstRasterMs = _worstRaster / 1000;

    // Only interesting frames get logged. A quiet app produces no frames at
    // all, and a second of perfectly healthy rendering is not worth a row.
    final noteworthy = jank > 0 || _frames > 0;
    if (noteworthy) {
      DiagLog.add(
        cat: DiagCat.frame,
        // Sustained jank is the signature we are hunting, so it gets a severity
        // that survives the default filter floor.
        sev: jank > 10 ? DiagSev.warn : DiagSev.trace,
        event: 'frames',
        detail:
            '${_frames}f ~${fps}fps · jank $jank · '
            'build ${worstBuildMs.toStringAsFixed(1)}ms · '
            'raster ${worstRasterMs.toStringAsFixed(1)}ms',
      );
    }

    _windowStartMs = now;
    _frames = 0;
    _jank = 0;
    _worstBuild = 0;
    _worstRaster = 0;
  }
}
