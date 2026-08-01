import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'release_channel.dart';
import 'web_reload.dart';

/// The hosted download page. Two audiences share it: the retired Android APK,
/// which is sent here to be told how to move to Play, and the DMG or
/// Windows/Linux builds it is the natural home for later. Mirrors HOSTING_URL
/// in deploy.sh; `/download` 301s to `/downloads/` and must answer forever,
/// because installed APKs have this URL stored as their `updateUrl`.
const String kDownloadPageUrl = 'https://monkeyhub.walhallaa.com/download';

/// Android application id, from deploy.sh's ANDROID_PACKAGE.
const String kAndroidPackage = 'com.walhallaa.chattest20241220';

/// Sends the user wherever *their* copy of the app gets updated from.
///
/// [updateUrl] is whatever the backend published for this channel and always
/// wins — that's the mechanism by which a build shipped before the App Store
/// listing existed can still be pointed at it. The per-channel defaults below
/// are only the fallback for a row that doesn't specify one.
///
/// Every path is best-effort with a fallback, because a custom scheme
/// (`market://`, `itms-beta://`) fails outright when the store app isn't
/// installed. A tap that silently does nothing is the one outcome worth
/// engineering against: the user has already been told they're out of date and
/// has no other route.
Future<void> openUpdateDestination(
  ReleaseChannel channel,
  String? updateUrl, {
  String? version,
}) async {
  // Web doesn't navigate anywhere — it reloads onto the build that's already
  // deployed. Checked before updateUrl so a stray row value can't turn the web
  // prompt into a pointless link back to itself.
  if (channel == ReleaseChannel.web) {
    await WebReload.toVersion(version ?? '');
    return;
  }

  final candidates = <String>[
    if (updateUrl != null && updateUrl.trim().isNotEmpty) updateUrl.trim(),
    ..._defaultsFor(channel),
  ];

  for (final url in candidates) {
    if (await _tryLaunch(url)) return;
  }
  debugPrint('UPDATE: no destination could be opened for ${channel.wire}');
}

/// Ordered fallbacks per channel — the first that launches wins.
List<String> _defaultsFor(ReleaseChannel channel) {
  switch (channel) {
    case ReleaseChannel.iosTestflight:
    case ReleaseChannel.macosTestflight:
      // A per-app TestFlight deep link needs the numeric Apple ID, which only
      // exists in App Store Connect — so it has to arrive via updateUrl
      // (itms-beta://testflight.apple.com/v1/app/<appleId>). Bare `itms-beta://`
      // at least opens TestFlight, where the update is one tap away. Same
      // scheme on macOS, which has had a native TestFlight app since Big Sur.
      return const ['itms-beta://', 'https://testflight.apple.com/'];
    case ReleaseChannel.iosAppstore:
      // Same story: itms-apps://apps.apple.com/app/id<appleId> needs an ID we
      // don't have until the listing exists. Nothing useful to guess, so fall
      // through to the download page rather than opening a blank App Store.
      return const [kDownloadPageUrl];
    case ReleaseChannel.androidPlay:
      // market:// opens the Play app directly on our listing; the https form
      // covers a device without Play (or with it disabled).
      return const [
        'market://details?id=$kAndroidPackage',
        'https://play.google.com/store/apps/details?id=$kAndroidPackage',
      ];
    case ReleaseChannel.androidApk:
    case ReleaseChannel.macosDmg:
    case ReleaseChannel.windows:
    case ReleaseChannel.linux:
      // The download page always links the current versioned file, so it stays
      // correct without the client knowing this release's filename.
      return const [kDownloadPageUrl];
    case ReleaseChannel.macosAppstore:
      // Same missing-Apple-ID problem as iosAppstore; macappstore:// at least
      // opens the Mac App Store, and the DMG page is a working last resort.
      return const ['macappstore://apps.apple.com/', kDownloadPageUrl];
    case ReleaseChannel.web:
    case ReleaseChannel.unknown:
      return const [];
  }
}

/// `LaunchMode.externalApplication` matches the app's only other launch site
/// (the fallback path in `services/link_opener.dart`) and is what hands a store
/// scheme to the store app rather than to a browser surface.
Future<bool> _tryLaunch(String url) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // A scheme with no handler throws on some platforms and returns false on
    // others. Both mean "try the next candidate".
    return false;
  }
}
