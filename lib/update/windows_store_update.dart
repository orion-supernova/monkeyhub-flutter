import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'store_answer.dart';

/// The Microsoft Store's own answer for a Store install, and its in-place
/// installer — Windows' counterpart to `play_update.dart`.
///
/// deploy.sh announces `windows` the moment the submission goes in, but
/// certification takes hours to days and the Store can take up to a day after
/// that to offer the package. `StoreContext` answers for this install, so a
/// submission still in certification is simply not an update yet.
///
/// Native side: `monkeyhub/store_update` in `windows/runner/store_update.cpp`.
/// A build not installed from the Store (a dev run, a sideloaded MSIX) has no
/// Store identity; the native side reports that as an error, which lands here
/// as no answer.
const _channel = MethodChannel('monkeyhub/store_update');

/// Whether the Store has a newer package for this install, and which.
Future<StoreAnswer> windowsStoreAnswer() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) {
    return StoreAnswer.noAnswer;
  }
  try {
    final res = await _channel.invokeMapMethod<String, dynamic>('check');
    if (res == null) return StoreAnswer.noAnswer;
    if (res['available'] != true) return StoreAnswer.upToDate;
    return StoreAnswer(
      StoreVerdict.available,
      version: _displayVersion(res['version'] as String?),
    );
  } catch (e) {
    debugPrint('MS STORE check failed: $e');
    return StoreAnswer.noAnswer;
  }
}

/// Downloads and installs the update through the Store's own dialog, without
/// the user going anywhere; Windows restarts the app to finish. True when the
/// Store took it; false means "fall back to opening the listing".
Future<bool> startWindowsStoreUpdate() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return false;
  try {
    return await _channel.invokeMethod<bool>('install') ?? false;
  } catch (e) {
    debugPrint('MS STORE install failed: $e');
    return false;
  }
}

/// MSIX versions are four-part with a reserved trailing 0 (`1.3.134.0`, see
/// msix_config in pubspec.yaml); the app shows three.
String? _displayVersion(String? msix) {
  if (msix == null || msix.isEmpty) return null;
  final parts = msix.split('.');
  return parts.length == 4 && parts.last == '0'
      ? parts.take(3).join('.')
      : msix;
}
