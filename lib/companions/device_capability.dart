/// How much machine there is to run a companion on.
///
/// ── Why this exists ────────────────────────────────────────────────────────
///
/// Sebastian's brain is deliberately not a choice the user makes — see
/// [Companion.brainsAreUserChosen]. Somebody who wants a translated bubble is
/// not shopping for a language model, and offering them the pick would be
/// offering a decision they have no way to make well.
///
/// But there IS a real decision underneath, and the device can make it. A 1.5B
/// model translates markedly better than a 0.5B one and costs about two and a
/// half times the download and roughly that again in resident memory; a phone
/// with 3 GB running a chat app cannot hold it, and the platform's answer to
/// trying is to kill the app. So the shelf is ordered best-first and the device
/// takes the best row it can actually carry. No picker, no explaining, and
/// nobody gets handed a model their handset will die on.
///
/// ── Why unknown means "assume small" ───────────────────────────────────────
///
/// Every failure here resolves downward. A platform this cannot read, a plugin
/// call that throws, a query that has not finished yet: all of them mean the
/// smallest brain, which every supported device can run. The cost of being
/// wrong in that direction is a translation that could have been better. The
/// cost of being wrong the other way is the OS terminating a chat app
/// mid-conversation, which the user experiences as the app crashing and has no
/// way to connect to a model they never chose.
library;

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'brain_spec.dart';

class DeviceCapability {
  DeviceCapability._();
  static final DeviceCapability instance = DeviceCapability._();

  /// Physical RAM in binary megabytes, or null while unknown.
  ///
  /// Null is not an error state and never becomes one: see the library note.
  int? get ramMb => _ramMb;
  int? _ramMb;

  Future<void>? _probe;

  /// Reads the machine once. Idempotent and safe to call concurrently — the
  /// future is memoised, so a second caller awaits the first call rather than
  /// starting a second query.
  ///
  /// Called from `main.dart` BEFORE `BrainManager.refresh`, which is what makes
  /// the answer available by the time anything asks which brain Sebastian runs.
  /// It is cheap: one plugin call, no weights touched.
  Future<void> prime() {
    return _probe ??= () async {
      try {
        _ramMb = await _readRamMb();
        if (kDebugMode) {
          debugPrint('DeviceCapability: ${_ramMb ?? 'unknown'} MB RAM');
        }
      } catch (e) {
        // Stays null, which is the conservative answer. Deliberately not
        // rethrown: a companion picking a smaller brain is not worth failing a
        // boot over.
        debugPrint('DeviceCapability.prime: $e');
      }
    }();
  }

  Future<int?> _readRamMb() async {
    // Sebastian does not run on web at all — see [BrainGateway.isSupported] —
    // so there is nothing to size there, and `Platform` would throw.
    if (kIsWeb) return null;
    final info = DeviceInfoPlugin();
    const mib = 1024 * 1024;

    if (Platform.isAndroid) return (await info.androidInfo).physicalRamSize;
    if (Platform.isIOS) return (await info.iosInfo).physicalRamSize;
    // Desktop reports bytes rather than megabytes, except Windows which reports
    // megabytes already. Named per-platform rather than guessed at, because a
    // unit mistake here reads as a device with a thousand times the memory it
    // has, and this value gates whether a 1.5 GB model gets loaded.
    if (Platform.isMacOS) return (await info.macOsInfo).memorySize ~/ mib;
    if (Platform.isWindows) {
      return (await info.windowsInfo).systemMemoryInMegabytes;
    }
    // Linux exposes no memory figure through this plugin. Unknown, which means
    // the small brain — the same answer any unreadable platform gets.
    return null;
  }

  /// Whether this machine should be asked to run [spec].
  ///
  /// True when the requirement is unstated (a brain with no floor is one every
  /// device can carry) and false whenever the answer is not known to be yes.
  bool canRun(BrainSpec spec) {
    final need = spec.minRamMb;
    if (need == null) return true;
    final have = _ramMb;
    if (have == null) return false;
    return have >= need;
  }

  /// Test seam. An app reads its own hardware once and lives with the answer,
  /// which is what makes memoising it correct there and useless in a suite
  /// where each case wants a different machine.
  @visibleForTesting
  void setRamForTest(int? mb) {
    _ramMb = mb;
    _probe = Future<void>.value();
  }
}
