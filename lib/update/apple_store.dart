import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'store_answer.dart';
import 'update_destination.dart' show kAppleAppId;
import 'version_compare.dart';

/// The App Store's own answer for an App Store install, on iOS and macOS.
///
/// The release row can't give it. An upload is a TestFlight build until Apple
/// approves it, approval can sit waiting for a manual release, and a released
/// version spreads across storefronts over hours. The public lookup endpoint is
/// what the App Store itself serves, per storefront, so asking it from the
/// device answers the only question that matters: can *this* user, in *their*
/// storefront, install something newer right now. A lag on Apple's side makes
/// the prompt late, never early.
///
/// Native side: `monkeyhub/installer` in `ios/Runner/InstallerEnvironment.swift`
/// and `macos/Runner/InstallerEnvironment.swift`.
const _installer = MethodChannel('monkeyhub/installer');

/// What the App Store would install for this device, or why it can't say.
Future<StoreAnswer> appStoreAnswer(
  String currentVersion, {
  required bool mac,
}) async {
  final country = await _storefrontCountry();
  final version = await lookupAppStoreVersion(country: country, mac: mac);
  if (version == null) return StoreAnswer.noAnswer;
  return StoreAnswer(
    compareVersions(version, currentVersion) > 0
        ? StoreVerdict.available
        : StoreVerdict.upToDate,
    version: version,
  );
}

/// The version the App Store lists for MonkeyHub in [country], or null when
/// it lists none there (not live yet, not sold there, offline).
///
/// iOS and macOS share one App Store Connect app id, so the lookup can answer
/// with either platform's record; [mac] picks the record by its `kind` rather
/// than trusting whichever comes first. A record of the wrong kind is no
/// answer, never a version — mistaking the iOS version for the Mac one would
/// prompt Mac users for a build their store doesn't have.
@visibleForTesting
Future<String?> lookupAppStoreVersion({
  String? country,
  required bool mac,
  http.Client? client,
}) async {
  final query = <String, String>{
    'id': kAppleAppId,
    'country': ?country,
    if (mac) 'entity': 'macSoftware',
    // The endpoint sits behind a cache that holds a record for hours; a
    // per-request key at least keeps an HTTP cache on our side out of it.
    '_': DateTime.now().millisecondsSinceEpoch.toString(),
  };
  final uri = Uri.https('itunes.apple.com', '/lookup', query);
  final c = client ?? http.Client();
  try {
    final res = await c.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    return parseAppStoreLookup(res.body, mac: mac);
  } catch (e) {
    debugPrint('APP STORE lookup failed: $e');
    return null;
  } finally {
    if (client == null) c.close();
  }
}

/// Pulls our record's version out of a lookup response body.
@visibleForTesting
String? parseAppStoreLookup(String body, {required bool mac}) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final results = (json['results'] as List?) ?? const [];
    final wantKind = mac ? 'mac-software' : 'software';
    for (final r in results) {
      if (r is! Map) continue;
      if ('${r['trackId']}' != kAppleAppId) continue;
      if (r['kind'] != wantKind) continue;
      final v = r['version'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
  } catch (_) {
    // Malformed body: no answer, same as an empty one.
  }
  return null;
}

/// Opens MonkeyHub's App Store page *inside* the app
/// (`SKStoreProductViewController`), where an installed app's button reads
/// Update. Apple allows nothing closer to an in-place update: no app may
/// install its own binary. False when the sheet couldn't be shown, so the
/// caller can fall back to opening the App Store itself.
Future<bool> showAppStorePage() async {
  try {
    return await _installer.invokeMethod<bool>(
          'showStorePage',
          {'appId': kAppleAppId},
        ) ??
        false;
  } catch (e) {
    debugPrint('APP STORE sheet failed: $e');
    return false;
  }
}

/// The storefront this device buys from, as the two-letter code the lookup
/// takes. StoreKit reports ISO alpha-3 (`TUR`), so it is mapped here; a code
/// we can't map falls back to the device region, and failing that the lookup
/// runs without a country, which Apple answers from the US store.
Future<String?> _storefrontCountry() async {
  try {
    final alpha3 = await _installer.invokeMethod<String>('storefront');
    final mapped = alpha3 == null ? null : alpha3ToAlpha2(alpha3);
    if (mapped != null) return mapped;
  } catch (_) {
    // Older OS or no StoreKit answer: fall through to the region.
  }
  final region = PlatformDispatcher.instance.locale.countryCode;
  return region == null || region.length != 2 ? null : region.toLowerCase();
}

/// ISO 3166 alpha-3 → alpha-2, lowercase, for every territory the App Store
/// sells in. Null for anything else.
@visibleForTesting
String? alpha3ToAlpha2(String alpha3) => _alpha3[alpha3.toUpperCase()];

const Map<String, String> _alpha3 = {
  'AFG': 'af', 'ALB': 'al', 'DZA': 'dz', 'AGO': 'ao', 'AIA': 'ai',
  'ATG': 'ag', 'ARG': 'ar', 'ARM': 'am', 'AUS': 'au', 'AUT': 'at',
  'AZE': 'az', 'BHS': 'bs', 'BHR': 'bh', 'BRB': 'bb', 'BLR': 'by',
  'BEL': 'be', 'BLZ': 'bz', 'BEN': 'bj', 'BMU': 'bm', 'BTN': 'bt',
  'BOL': 'bo', 'BIH': 'ba', 'BWA': 'bw', 'BRA': 'br', 'VGB': 'vg',
  'BRN': 'bn', 'BGR': 'bg', 'BFA': 'bf', 'KHM': 'kh', 'CMR': 'cm',
  'CAN': 'ca', 'CPV': 'cv', 'CYM': 'ky', 'TCD': 'td', 'CHL': 'cl',
  'CHN': 'cn', 'COL': 'co', 'COD': 'cd', 'COG': 'cg', 'CRI': 'cr',
  'CIV': 'ci', 'HRV': 'hr', 'CYP': 'cy', 'CZE': 'cz', 'DNK': 'dk',
  'DMA': 'dm', 'DOM': 'do', 'ECU': 'ec', 'EGY': 'eg', 'SLV': 'sv',
  'EST': 'ee', 'SWZ': 'sz', 'FJI': 'fj', 'FIN': 'fi', 'FRA': 'fr',
  'GAB': 'ga', 'GMB': 'gm', 'GEO': 'ge', 'DEU': 'de', 'GHA': 'gh',
  'GRC': 'gr', 'GRD': 'gd', 'GTM': 'gt', 'GNB': 'gw', 'GUY': 'gy',
  'HND': 'hn', 'HKG': 'hk', 'HUN': 'hu', 'ISL': 'is', 'IND': 'in',
  'IDN': 'id', 'IRQ': 'iq', 'IRL': 'ie', 'ISR': 'il', 'ITA': 'it',
  'JAM': 'jm', 'JPN': 'jp', 'JOR': 'jo', 'KAZ': 'kz', 'KEN': 'ke',
  'KOR': 'kr', 'XKS': 'xk', 'KWT': 'kw', 'KGZ': 'kg', 'LAO': 'la',
  'LVA': 'lv', 'LBN': 'lb', 'LBR': 'lr', 'LBY': 'ly', 'LTU': 'lt',
  'LUX': 'lu', 'MAC': 'mo', 'MDG': 'mg', 'MWI': 'mw', 'MYS': 'my',
  'MDV': 'mv', 'MLI': 'ml', 'MLT': 'mt', 'MRT': 'mr', 'MUS': 'mu',
  'MEX': 'mx', 'FSM': 'fm', 'MDA': 'md', 'MNG': 'mn', 'MNE': 'me',
  'MSR': 'ms', 'MAR': 'ma', 'MOZ': 'mz', 'MMR': 'mm', 'NAM': 'na',
  'NRU': 'nr', 'NPL': 'np', 'NLD': 'nl', 'NZL': 'nz', 'NIC': 'ni',
  'NER': 'ne', 'NGA': 'ng', 'MKD': 'mk', 'NOR': 'no', 'OMN': 'om',
  'PAK': 'pk', 'PLW': 'pw', 'PAN': 'pa', 'PNG': 'pg', 'PRY': 'py',
  'PER': 'pe', 'PHL': 'ph', 'POL': 'pl', 'PRT': 'pt', 'QAT': 'qa',
  'ROU': 'ro', 'RUS': 'ru', 'RWA': 'rw', 'KNA': 'kn', 'LCA': 'lc',
  'VCT': 'vc', 'STP': 'st', 'SAU': 'sa', 'SEN': 'sn', 'SRB': 'rs',
  'SYC': 'sc', 'SLE': 'sl', 'SGP': 'sg', 'SVK': 'sk', 'SVN': 'si',
  'SLB': 'sb', 'ZAF': 'za', 'ESP': 'es', 'LKA': 'lk', 'SUR': 'sr',
  'SWE': 'se', 'CHE': 'ch', 'TWN': 'tw', 'TJK': 'tj', 'TZA': 'tz',
  'THA': 'th', 'TON': 'to', 'TTO': 'tt', 'TUN': 'tn', 'TUR': 'tr',
  'TKM': 'tm', 'TCA': 'tc', 'UGA': 'ug', 'UKR': 'ua', 'ARE': 'ae',
  'GBR': 'gb', 'USA': 'us', 'URY': 'uy', 'UZB': 'uz', 'VUT': 'vu',
  'VEN': 've', 'VNM': 'vn', 'YEM': 'ye', 'ZMB': 'zm', 'ZWE': 'zw',
};
