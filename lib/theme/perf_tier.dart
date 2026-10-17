import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../companions/device_capability.dart';

/// How much effect this machine is asked to carry.
///
/// Read off the RAM figure [DeviceCapability] already takes at boot (one
/// plugin call, made in `main.dart` before anything animates). A phone with
/// under [lowRamMb] is the iPhone 8 / XR / SE 2 class, or a 3 GB Android:
/// the same particle effects run there, with fewer grains and smaller
/// captures, so they cost about half and look the same at arm's length.
///
/// Unknown (web, Linux, or a probe that has not finished) is [PerfTier.normal]:
/// the opposite of the companion's rule, on purpose. Wrong this way costs a
/// few frames on a slow machine; wrong the other way would thin the effects
/// on every desktop for nothing.
enum PerfTier { normal, low }

abstract final class Perf {
  /// Below this much physical RAM a phone is the low tier. iOS reports a
  /// 3 GB XR as about 2850 MB and a 4 GB iPhone 11 as about 3850.
  static const int lowRamMb = 3600;

  static PerfTier? _override;

  static PerfTier get tier {
    final forced = _override;
    if (forced != null) return forced;
    final ram = DeviceCapability.instance.ramMb;
    return ram != null && ram < lowRamMb ? PerfTier.low : PerfTier.normal;
  }

  static bool get low => tier == PerfTier.low;

  /// [n] particles, scaled for this machine.
  static int particles(int n) => low ? (n * 0.55).round() : n;

  /// The pixel ratio to rasterise a capture at, for a screen of [dpr]: the
  /// grains are a couple of logical pixels, so past 2× the extra resolution
  /// is memory the eye never sees on a small phone.
  static double captureRatio(double dpr, {double max = 3}) =>
      math.min(dpr, low ? math.min(max, 2.0) : max);

  @visibleForTesting
  static set debugTier(PerfTier? tier) => _override = tier;
}
