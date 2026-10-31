import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// How this copy of the app was distributed — which decides both *what* counts
/// as "the latest version" and *where* the update button has to send the user.
///
/// The same build reaches TestFlight and the App Store weeks apart, and a
/// sideloaded APK and a Play install update by completely different means, so
/// platform alone is not enough: the channel is the unit the backend tracks.
///
/// [wire] must match the `channel` field on the backend's `appReleases` rows.
enum ReleaseChannel {
  iosTestflight('ios-testflight'),
  iosAppstore('ios-appstore'),

  /// Retired as a delivery channel — nothing is built for it any more. It stays
  /// because the APKs already out there were stamped with it and will keep
  /// asking about it forever, which makes it the only way to reach them. Its
  /// backend row is now a migration notice pointing at the download page. See
  /// DEPLOY.md → "Retired: the APK".
  androidApk('android-apk'),
  androidPlay('android-play'),
  // macOS ships all three ways: a direct DMG download, and — once the bundle is
  // bound in App Store Connect — TestFlight and the Mac App Store. None of them
  // are distinguishable at runtime (the macOS plugin hardcodes a null
  // installerStore), so on macOS the build-time define is the *only* signal.
  macosDmg('macos-dmg'),
  macosTestflight('macos-testflight'),
  macosAppstore('macos-appstore'),
  windows('windows'),
  linux('linux'),
  web('web'),

  /// Not a real channel — a build we can't place (debug, simulator, an
  /// unrecognised define). The update check is skipped entirely.
  unknown('unknown');

  const ReleaseChannel(this.wire);
  final String wire;

  static ReleaseChannel? parse(String? wire) {
    if (wire == null || wire.isEmpty) return null;
    for (final c in ReleaseChannel.values) {
      if (c.wire == wire) return c;
    }
    return null;
  }
}

/// Stamped by `deploy.sh` via `--dart-define=MH_CHANNEL=…`. Empty for anything
/// built by hand. Must be a `const` read to survive AOT compilation.
const String _definedChannel = String.fromEnvironment('MH_CHANNEL');

/// The channel this build belongs to.
///
/// The build-time define wins, because it's the only thing that can distinguish
/// the cases the OS won't tell us apart — a DMG from a Mac App Store install,
/// or a Windows/Linux build from anything. `installerStore` is the fallback for
/// builds that carry no define, which is worth having: it means a hand-built
/// TestFlight upload still resolves correctly if the define is ever forgotten.
///
/// Debug builds always resolve to [ReleaseChannel.unknown] so a developer
/// working on 1.3.29 while the backend advertises 1.3.30 doesn't get nagged on
/// every hot restart.
///
/// Uses `defaultTargetPlatform` rather than `dart:io`'s `Platform`, so this
/// file compiles for web untouched (same reasoning as `lib/platform.dart`).
/// `kIsWeb` is checked first regardless, since on web `defaultTargetPlatform`
/// reports the browser's host OS.
Future<ReleaseChannel> resolveChannel() async {
  if (kDebugMode) return ReleaseChannel.unknown;

  final defined = ReleaseChannel.parse(_definedChannel);
  // The one define that is right for only half a build's life: the binary
  // deploy.sh stamps `macos-testflight` is the same one the Mac App Store sells
  // after approval. StoreKit tells the two apart at runtime; without that a
  // store install would read the TestFlight row and be told about versions
  // the store doesn't have yet.
  if (defined == ReleaseChannel.macosTestflight &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.macOS) {
    return await _macInstallerEnvironment() == 'production'
        ? ReleaseChannel.macosAppstore
        : ReleaseChannel.macosTestflight;
  }
  if (defined != null) return defined;

  if (kIsWeb) return ReleaseChannel.web;

  String? installer;
  try {
    installer = (await PackageInfo.fromPlatform()).installerStore;
  } catch (_) {
    installer = null;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      // Values are documented by package_info_plus and derived from the receipt
      // path: sandboxReceipt → TestFlight, CoreSimulator → simulator, else the
      // App Store. A locally-built release install has no receipt at all and so
      // reads as 'com.apple' — a known false positive that only ever affects
      // hand-made builds, which is why real ones carry the define.
      switch (installer) {
        case 'com.apple.testflight':
          return ReleaseChannel.iosTestflight;
        case 'com.apple.simulator':
          return ReleaseChannel.unknown;
        default:
          return ReleaseChannel.iosAppstore;
      }
    case TargetPlatform.android:
      // Play reports itself; a manual/ADB install reports null. Some
      // third-party stores don't implement the API and also report null — they
      // fall in with sideloads, which is the right side to err on: the hosted
      // download page works for anyone.
      return installer == 'com.android.vending'
          ? ReleaseChannel.androidPlay
          : ReleaseChannel.androidApk;
    // macOS/Windows/Linux always report a null installerStore, so these are
    // guesses that only hold until the define lands. macOS assumes the DMG:
    // it's the only macOS channel that exists today, and it's also the one that
    // can't be re-derived from anything else, whereas a macOS TestFlight or Mac
    // App Store build necessarily comes out of deploy.sh carrying its define.
    case TargetPlatform.macOS:
      return ReleaseChannel.macosDmg;
    case TargetPlatform.windows:
      return ReleaseChannel.windows;
    case TargetPlatform.linux:
      return ReleaseChannel.linux;
    case TargetPlatform.fuchsia:
      return ReleaseChannel.unknown;
  }
}

/// 'production' (Mac App Store), 'sandbox' (TestFlight), 'xcode', or null when
/// StoreKit can't say (macOS 12, no transaction). See
/// `macos/Runner/InstallerEnvironment.swift`.
Future<String?> _macInstallerEnvironment() async {
  try {
    return await const MethodChannel('monkeyhub/installer')
        .invokeMethod<String>('environment');
  } catch (_) {
    return null;
  }
}
