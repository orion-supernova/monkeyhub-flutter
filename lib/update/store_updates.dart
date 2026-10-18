import 'apple_store.dart';
import 'play_update.dart';
import 'release_channel.dart';
import 'store_answer.dart';
import 'windows_store_update.dart';

/// Asks the store this copy came from whether it can install something newer.
///
/// One switch so the checker never needs to know which stores can answer:
/// Play (In-App Updates), the Microsoft Store (`StoreContext`) and the App
/// Store (its public lookup, per storefront). Everything else — TestFlight,
/// web, Linux, the retired APK — has no store to ask, and the release row
/// keeps deciding for it.
Future<StoreAnswer> askStore(ReleaseChannel channel, String currentVersion) {
  switch (channel) {
    case ReleaseChannel.androidPlay:
      // Play reports a version code, not a name, so no version here: the
      // row's stands in for the sheet's "v1.3.9 → v1.3.10".
      return playHasUpdate().then(
        (has) => has
            ? const StoreAnswer(StoreVerdict.available)
            : StoreAnswer.upToDate,
      );
    case ReleaseChannel.windows:
      return windowsStoreAnswer();
    case ReleaseChannel.iosAppstore:
      return appStoreAnswer(currentVersion, mac: false);
    case ReleaseChannel.macosAppstore:
      return appStoreAnswer(currentVersion, mac: true);
    case ReleaseChannel.iosTestflight:
    case ReleaseChannel.macosTestflight:
    case ReleaseChannel.androidApk:
    case ReleaseChannel.macosDmg:
    case ReleaseChannel.linux:
    case ReleaseChannel.web:
    case ReleaseChannel.unknown:
      return Future.value(StoreAnswer.notApplicable);
  }
}

/// Whether [askStore] goes to a store for this channel. The answers can change
/// with no release row moving (an approval, a certification), so these are
/// the channels the checker re-asks on resume.
bool storeAnswers(ReleaseChannel channel) => switch (channel) {
      ReleaseChannel.androidPlay ||
      ReleaseChannel.windows ||
      ReleaseChannel.iosAppstore ||
      ReleaseChannel.macosAppstore =>
        true,
      _ => false,
    };

/// Runs the update without the user leaving the app, as far as the platform
/// allows: Play's and the Microsoft Store's own installers, and the App Store
/// page as an in-app sheet (Apple lets no app install its own update, so the
/// sheet's Update button is as close as it gets). True when that ran; false
/// sends the caller to the store or download page instead.
Future<bool> startInAppUpdate(ReleaseChannel channel) {
  switch (channel) {
    case ReleaseChannel.androidPlay:
      return startPlayUpdate();
    case ReleaseChannel.windows:
      return startWindowsStoreUpdate();
    case ReleaseChannel.iosAppstore:
    case ReleaseChannel.macosAppstore:
      return showAppStorePage();
    case ReleaseChannel.iosTestflight:
    case ReleaseChannel.macosTestflight:
    case ReleaseChannel.androidApk:
    case ReleaseChannel.macosDmg:
    case ReleaseChannel.linux:
    case ReleaseChannel.web:
    case ReleaseChannel.unknown:
      return Future.value(false);
  }
}
