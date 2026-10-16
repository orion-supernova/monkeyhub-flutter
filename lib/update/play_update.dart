import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Google Play's own answer to "is there an update for this install?".
///
/// Play internal testing and production install the same binary from the same
/// store, so neither the build nor the server can tell which track a phone is
/// on, and the `android-play` row moves the moment deploy.sh uploads to the
/// internal track. Asked directly, Play answers for this install's own track:
/// a tester sees the internal build, a production user sees nothing until the
/// release reaches production. The update check gates every Play prompt on it.
///
/// Never throws. Off Android, or when Play can't answer (a sideloaded build,
/// no Play services), it reports no update: an update prompt that sends
/// someone to a store with nothing for them is worse than no prompt.
Future<bool> playHasUpdate() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final info = await InAppUpdate.checkForUpdate();
    return info.updateAvailability == UpdateAvailability.updateAvailable ||
        info.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress;
  } catch (e) {
    debugPrint('PLAY UPDATE check failed: $e');
    return false;
  }
}

/// Runs Play's full-screen updater, which downloads and installs without the
/// user going anywhere. True when Play ran it; false means "fall back to
/// opening the listing".
Future<bool> startPlayUpdate() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final info = await InAppUpdate.checkForUpdate();
    if (!info.immediateUpdateAllowed) return false;
    return await InAppUpdate.performImmediateUpdate() ==
        AppUpdateResult.success;
  } catch (e) {
    debugPrint('PLAY UPDATE flow failed: $e');
    return false;
  }
}
