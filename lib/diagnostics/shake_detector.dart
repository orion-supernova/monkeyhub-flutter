import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, VoidCallback;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:sensors_plus/sensors_plus.dart';

/// Watches the accelerometer for a deliberate shake.
///
/// This is how a user who has hit a problem finds the report screen without
/// anybody having to talk them through Settings. That convenience is also the
/// risk: the people holding these phones are children, and a phone gets waved
/// around, dropped into a bag, and taken running. So the bar for "that was a
/// shake" is set high and deliberately:
///
///  * a single jolt is ignored. Real shaking is REPEATED, so it takes
///    [_shakesRequired] separate spikes inside [_window] — one bump on a bus
///    cannot reach that.
///  * after firing, the detector goes quiet for [_cooldown], which BOUNDS THE
///    RATE rather than the total — shaking for ten seconds crosses several
///    cooldowns and fires several times. Making that one prompt is the caller's
///    job, via its single-sheet guard; this layer only stops a stampede.
///  * and the caller still shows a confirm sheet. Nothing here opens a form on
///    its own.
///
/// Sensor events arrive at whatever rate the platform chooses (tens per second),
/// so the hot path is a subtract, a multiply and a compare — no allocation.
class ShakeDetector {
  ShakeDetector._();
  static final ShakeDetector instance = ShakeDetector._();

  /// Total acceleration, in multiples of gravity, that counts as a spike.
  ///
  /// 1.0 is the phone sitting still. 2.7 is a firm, intentional shake — walking
  /// with a phone in hand peaks around 1.5, and setting it down hits ~2.0.
  static const double _threshold = 2.7;

  /// Spikes needed, and the window they must land in.
  static const int _shakesRequired = 3;
  static const Duration _window = Duration(milliseconds: 1200);

  /// Quiet period after a successful detection.
  static const Duration _cooldown = Duration(seconds: 3);

  /// Ignore spikes closer together than this — one physical jolt registers
  /// across several sensor samples and would otherwise count three times on
  /// its own.
  static const Duration _minSpikeGap = Duration(milliseconds: 180);

  static const double _gravity = 9.80665;

  StreamSubscription<AccelerometerEvent>? _sub;
  final List<DateTime> _spikes = [];
  DateTime? _firedAt;
  VoidCallback? _onShake;

  /// Whether the detector is listening. Callers can flip this off (a call
  /// screen, a camera) without tearing the subscription down.
  bool enabled = true;

  bool get isListening => _sub != null;

  /// The plugin's own method channel, which we probe before using its stream.
  static const MethodChannel _sensorChannel = MethodChannel(
    'dev.fluttercommunity.plus/sensors/method',
  );

  /// How often to sample. The package default is 200 ms, which is too coarse to
  /// reliably catch the PEAK of a shake; 66 ms is fast enough to see it without
  /// paying for the 20 ms game rate.
  static const int _samplingMicros = 66667;

  /// Starts listening. Safe to call more than once.
  ///
  /// Probes before subscribing, and that probe is load-bearing rather than
  /// belt-and-braces. `sensors_plus` fires `setAccelerationSamplingPeriod`
  /// WITHOUT awaiting it (method_channel_sensors.dart:54), so on any platform
  /// where the plugin is not registered that future rejects straight into the
  /// zone as an unhandled exception — one that no try/catch around the call
  /// site can catch, because the call site never holds the future. Asking the
  /// same channel ourselves first turns "unhandled crash spam at every launch"
  /// into a boolean we can branch on.
  ///
  /// That is not a hypothetical: the plugin ships Android, iOS and web only, so
  /// every desktop build would have done exactly this on startup.
  Future<void> start(VoidCallback onShake) async {
    _onShake = onShake;
    if (_sub != null || kIsWeb) return;

    if (!await _sensorsAvailable()) return;

    try {
      _sub =
          accelerometerEventStream(
            samplingPeriod: const Duration(microseconds: _samplingMicros),
          ).listen(
            _onEvent,
            onError: (Object e) {
              // The stream itself giving up — a sensor that stops responding.
              // Shake is a convenience and Settings is the real route, so this
              // is not worth surfacing to anybody.
              debugPrint('ShakeDetector: sensor stream error: $e');
              stop();
            },
            cancelOnError: true,
          );
    } catch (e) {
      debugPrint('ShakeDetector.start: $e');
    }
  }

  /// True when the accelerometer plugin is actually present on this platform.
  ///
  /// Doubles as the sampling-period set, so the package's own un-awaited call
  /// a moment later is a no-op that repeats a value we already know works.
  Future<bool> _sensorsAvailable() async {
    try {
      await _sensorChannel.invokeMethod(
        'setAccelerationSamplingPeriod',
        _samplingMicros,
      );
      return true;
    } catch (e) {
      debugPrint('ShakeDetector: accelerometer unavailable ($e)');
      return false;
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _spikes.clear();
  }

  void _onEvent(AccelerometerEvent e) {
    if (!enabled) return;

    // Magnitude of the whole vector, so orientation does not matter.
    final g = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / _gravity;
    if (g < _threshold) return;

    final now = DateTime.now();

    final firedAt = _firedAt;
    if (firedAt != null && now.difference(firedAt) < _cooldown) return;

    // One jolt spans several samples; count it once.
    if (_spikes.isNotEmpty && now.difference(_spikes.last) < _minSpikeGap) {
      return;
    }

    _spikes.add(now);
    _spikes.removeWhere((t) => now.difference(t) > _window);

    if (_spikes.length >= _shakesRequired) {
      _spikes.clear();
      _firedAt = now;
      _onShake?.call();
    }
  }

  /// Test seam.
  void debugFeed(double magnitudeG, DateTime at) {
    if (magnitudeG < _threshold) return;
    final firedAt = _firedAt;
    if (firedAt != null && at.difference(firedAt) < _cooldown) return;
    if (_spikes.isNotEmpty && at.difference(_spikes.last) < _minSpikeGap) {
      return;
    }
    _spikes.add(at);
    _spikes.removeWhere((t) => at.difference(t) > _window);
    if (_spikes.length >= _shakesRequired) {
      _spikes.clear();
      _firedAt = at;
      _onShake?.call();
    }
  }

  void resetForTest() {
    _spikes.clear();
    _firedAt = null;
    _onShake = null;
    enabled = true;
  }

  /// Test seam for wiring a handler without a live sensor.
  void setHandlerForTest(VoidCallback onShake) => _onShake = onShake;
}
