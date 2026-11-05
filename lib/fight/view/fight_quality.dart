import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'art/quality.dart';

export 'art/quality.dart';

/// Watches real frame times while a fight is on screen and lowers
/// [fightQuality] when the device cannot keep up, so a slow phone gets a
/// slightly plainer fight instead of a stuttering one.
///
/// It looks at windows of [window] frames: when more than [jankShare] of a
/// window's frames blew the budget (the frame interval the display is
/// running at, plus a little slack), that is a strike; two strikes in a row
/// step the quality down one level. It never steps back up during a fight
/// (a fight that flickers between looks is worse than either); the next fight
/// starts at full again.
///
/// Two signals, because the platforms report differently: the engine's
/// [FrameTiming]s (build + raster, all native platforms) and the gap between
/// ticks the fight loop itself sees (the web, where raster time is not
/// reported separately and a janky frame shows up as a late tick).
class FightQualityGovernor {
  FightQualityGovernor({this.window = 90, this.jankShare = .15});

  final int window;
  final double jankShare;

  int _frames = 0, _janky = 0, _strikes = 0;
  bool _attached = false;
  Duration _budget = const Duration(microseconds: 18500); // 60 Hz plus slack

  void start() {
    fightQuality.value = FightQuality.full;
    _frames = _janky = _strikes = 0;
    if (!_attached) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _attached = true;
    }
  }

  void stop() {
    if (_attached) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _attached = false;
    }
  }

  /// The display's frame interval, e.g. 8.3 ms at 120 Hz. Budgets are a bit
  /// over one interval, but never tighter than 60 Hz needs.
  void setRefreshInterval(Duration interval) {
    final us = (interval.inMicroseconds * 1.1).round();
    _budget = Duration(microseconds: us < 18500 ? 18500 : us);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final cost = t.buildDuration > t.rasterDuration ? t.buildDuration : t.rasterDuration;
      _sample(cost > _budget);
    }
  }

  /// One tick of the fight loop, [gap] after the previous one.
  void onTick(Duration gap) {
    if (!kIsWeb) return; // native platforms have FrameTiming
    _sample(gap > _budget * 1.4);
  }

  /// One frame's verdict (exposed for tests).
  @visibleForTesting
  void sample(bool janky) => _sample(janky);

  void _sample(bool janky) {
    _frames++;
    if (janky) _janky++;
    if (_frames < window) return;
    final bad = _janky > window * jankShare;
    _frames = _janky = 0;
    _strikes = bad ? _strikes + 1 : 0;
    if (_strikes >= 2 && fightQuality.value != FightQuality.minimal) {
      fightQuality.value = FightQuality.values[fightQuality.value.index + 1];
      _strikes = 0;
      debugPrint('FightQualityGovernor: lowered to ${fightQuality.value.name}');
    }
  }
}
