import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../calls/phone_call_activity.dart';
import '../data/settings_store.dart';
import '../theme/low_power.dart';
import '../ui/foundation/channels.dart';

/// What a single haptic means, which decides its feel on every platform.
///
///  * [tick] - one detent of a ramp. The only kind a continuous ramp plays, and
///    the only one a lower [HapticTier] drops.
///  * [notch] - a distinct click into place (iOS rigid): the fork line.
///  * [arm] - a firm tick: a choice just armed.
///  * [commit] - the gesture went through (a medium impact).
///  * [soft] - the quiet counterpart: a disarm, a cancel.
enum HapticKind { tick, notch, arm, commit, soft }

/// How much vibration a gesture is allowed, decided ONCE at touch-down by
/// [HapticTick.current] so nothing is re-checked per tick.
enum HapticTier {
  /// The full continuous ramp.
  full,

  /// An Android motor with amplitude control but no tick primitives: the ramp
  /// thinned to [HapticTick.thinnedDetents] detents, at least
  /// [HapticTick.thinnedGapMs] apart, because one-shots closer than that blur
  /// on a mid-range motor.
  thinned,

  /// Landmarks only (notch, arm, commit, soft): low power, a motor that cannot
  /// do light short ticks, or an active call (a motor's buzz leaks into the
  /// microphone). Three clean bumps beat a rattle.
  landmarks,

  /// Nothing. Android's "touch feedback" switch is off, and raw Vibrator calls
  /// do not respect it, so we do.
  silent,
}

/// What the phone's vibration motor can do, asked of the platform once.
@immutable
class HapticCapabilities {
  const HapticCapabilities({
    required this.primitives,
    required this.amplitude,
    required this.touchFeedbackEnabled,
  });

  /// Android 11+ tick primitives (`PRIMITIVE_LOW_TICK` and `PRIMITIVE_TICK`).
  final bool primitives;

  /// Whether the motor can vibrate at a chosen amplitude.
  final bool amplitude;

  /// The system "touch feedback" switch (`HAPTIC_FEEDBACK_ENABLED`).
  final bool touchFeedbackEnabled;

  /// iOS and desktop: the Taptic Engine takes an intensity directly, and the
  /// OS silences it itself when System Haptics is off.
  static const platformManaged = HapticCapabilities(
    primitives: true,
    amplitude: true,
    touchFeedbackEnabled: true,
  );
}

/// A haptic with an intensity: the one thing [HapticFeedback] cannot do.
///
/// [HapticFeedback] has four fixed strengths, which is why the old
/// `HapticRamp` steps selection, light, medium. A ramp that feels smooth needs
/// a number, so this adds a `tick` method to the existing `monkeyhub/haptics`
/// channel:
///
///  * **iOS** - `UIImpactFeedbackGenerator(style:).impactOccurred(intensity:)`,
///    `prepare`d on touch-down so the first tick has no lag.
///  * **Android** - on 11+ with tick primitives a `VibrationEffect.Composition`
///    at that scale; with only amplitude control an ~8 ms one-shot; with
///    neither, nothing.
///  * **macOS, Linux, Windows, web** - the existing [HapticFeedback] calls,
///    stepped by intensity (on macOS they reach the trackpad through the
///    `HapticMessenger` in `AppBinding`).
///
/// Fire and forget: nothing awaits a haptic, and an older native build without
/// the method must be as silent as Flutter's own no-op.
class HapticTick {
  HapticTick._();

  static const MethodChannel _channel = Channels.haptics;

  /// Detents a [HapticTier.thinned] ramp plays.
  static const int thinnedDetents = 6;

  /// Minimum gap between two ticks on a [HapticTier.thinned] ramp.
  static const int thinnedGapMs = 40;

  static HapticCapabilities? _caps;
  static Future<HapticCapabilities>? _loading;

  /// Test seams: swap how the tier inputs are read.
  @visibleForTesting
  static bool Function() lowPowerProbe = _powerSaving;
  @visibleForTesting
  static bool Function() inCallProbe = () => PhoneCallActivity.instance.value;

  /// The power half of [LowPowerMode.active], WITHOUT its motion half.
  ///
  /// `LowPowerMode.active` is false whenever the user pinned a Motion level,
  /// because a pinned Full motion outranks power saving for ANIMATION. That
  /// must not carry over to the vibration motor: motion and power are
  /// different promises, and haptics follow the power one. So this reads the
  /// same [PowerSaving] choice and the phone's own state, and ignores the
  /// motion setting.
  static bool _powerSaving() => switch (SettingsStore.instance.powerSaving) {
        PowerSaving.on => true,
        PowerSaving.off => false,
        PowerSaving.auto => LowPowerMode.instance.value,
      };

  /// Forgets the cached capabilities, so a test starts clean.
  @visibleForTesting
  static void resetForTest() {
    _caps = null;
    _loading = null;
    platformOverride = null;
    lowPowerProbe = _powerSaving;
    inCallProbe = () => PhoneCallActivity.instance.value;
  }

  /// Test seam: pretend to be another platform. (Flutter's own override has to
  /// be unset before a widget test ends, which a failing expect would skip.)
  @visibleForTesting
  static TargetPlatform? platformOverride;

  static TargetPlatform get _platform =>
      platformOverride ?? defaultTargetPlatform;
  static bool get _android => !kIsWeb && _platform == TargetPlatform.android;
  static bool get _ios => !kIsWeb && _platform == TargetPlatform.iOS;

  /// The cached capabilities, or null while still unknown (Android only; every
  /// other platform is known without asking).
  static HapticCapabilities? get capabilities =>
      _android ? _caps : HapticCapabilities.platformManaged;

  /// Asks the platform once and caches the answer. Safe to call from anywhere,
  /// any number of times; the app may call it at launch so the first gesture
  /// already has it. A failure (an older native build) caches the most
  /// conservative answer: no primitives, no amplitude, feedback on, which is
  /// landmarks only.
  static Future<HapticCapabilities> load() {
    final known = capabilities;
    if (known != null) return Future.value(known);
    return _loading ??= () async {
      HapticCapabilities caps;
      try {
        final raw = await _channel.invokeMapMethod<String, Object?>(
          'capabilities',
        );
        caps = HapticCapabilities(
          primitives: raw?['primitives'] == true,
          amplitude: raw?['amplitude'] == true,
          touchFeedbackEnabled: raw?['touchFeedbackEnabled'] != false,
        );
      } catch (_) {
        caps = const HapticCapabilities(
          primitives: false,
          amplitude: false,
          touchFeedbackEnabled: true,
        );
      }
      _caps = caps;
      return caps;
    }();
  }

  /// How much vibration this gesture may use. Call ONCE, on touch-down.
  ///
  /// Silent when Android touch feedback is off. Landmarks only under low power
  /// (an explicit "Full motion" setting does NOT force the ramp back on: see
  /// [lowPowerProbe]), in a call, or on a motor without amplitude control. Thinned for
  /// amplitude without primitives. Full otherwise.
  ///
  /// On Android before [load] has answered it plays safe, landmarks only.
  static HapticTier current() {
    final caps = capabilities;
    if (caps == null) {
      load();
      return HapticTier.landmarks;
    }
    if (!caps.touchFeedbackEnabled) return HapticTier.silent;
    if (lowPowerProbe() || inCallProbe()) return HapticTier.landmarks;
    if (!caps.amplitude && !caps.primitives) return HapticTier.landmarks;
    if (!caps.primitives) return HapticTier.thinned;
    return HapticTier.full;
  }

  /// Warms the generator ahead of the first tick: call on touch-down. A no-op
  /// off iOS, and it also starts the capability read everywhere it matters.
  static void prepare() {
    if (_android) load();
    if (!_ios) return;
    _channel.invokeMethod<void>('prepare').catchError((Object _) {});
  }

  /// Plays one haptic at [intensity] (0..1).
  ///
  /// [tier] is the gesture's own, from [current]; null asks again, which is
  /// right for a one-off. [HapticKind.tick] is dropped on
  /// [HapticTier.landmarks]; every other kind is a landmark and plays unless
  /// the tier is [HapticTier.silent]. Thinning a ramp is the caller's job (see
  /// `HapticRamp`), because it needs to know about the gap between ticks.
  static void play(
    double intensity, {
    HapticKind kind = HapticKind.tick,
    HapticTier? tier,
  }) {
    tier ??= current();
    if (tier == HapticTier.silent) return;
    if (tier == HapticTier.landmarks && kind == HapticKind.tick) return;
    final level = intensity.clamp(0.0, 1.0);
    if (_android || _ios) {
      _channel.invokeMethod<void>('tick', {
        'intensity': level,
        'style': _style(kind),
      }).catchError((Object _) {});
      return;
    }
    switch (kind) {
      case HapticKind.tick:
        if (level < 1 / 3) {
          HapticFeedback.selectionClick();
        } else if (level < 2 / 3) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      case HapticKind.notch:
        HapticFeedback.heavyImpact();
      case HapticKind.arm:
      case HapticKind.commit:
        HapticFeedback.mediumImpact();
      case HapticKind.soft:
        HapticFeedback.selectionClick();
    }
  }

  /// The iOS feedback style (and Android primitive family) a kind maps to.
  static String _style(HapticKind kind) => switch (kind) {
        HapticKind.tick => 'light',
        HapticKind.notch => 'rigid',
        HapticKind.arm => 'medium',
        HapticKind.commit => 'medium',
        HapticKind.soft => 'soft',
      };
}
