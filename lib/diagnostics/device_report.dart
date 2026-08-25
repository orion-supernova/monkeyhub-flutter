import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:package_info_plus/package_info_plus.dart';

import '../backend/server_store.dart';
import '../data/settings_store.dart';
import '../push/device_identity.dart';
import '../update/release_channel.dart';

/// The snapshot printed at the top of every export and as line one of every
/// session file.
///
/// Written to answer, in one screen, the questions a triager would otherwise
/// spend three messages asking. Several fields here are not general hygiene —
/// they are live hypotheses for the specific bug this feature was built for:
///
///  * **refresh rate** — the affected handset has a variable-refresh panel, and
///    an adaptive-refresh handoff is a plausible cause of a visible strobe.
///  * **animation scales** — a user or an OEM battery mode can set these to 0,
///    which changes how every transition in the app behaves.
///  * **captureProtection** — when on, the app sets FLAG_SECURE, and changing
///    window flags on Android forces a surface reconfigure.
///  * **power save** — Samsung's power manager throttles aggressively and is a
///    standing suspect in anything that only reproduces on one Galaxy.
///  * **theme id** — several themes render shader-backed background layers.
class DeviceReport {
  const DeviceReport._();

  static const MethodChannel _device = MethodChannel('monkeyhub/device');

  static Map<String, Object?>? _cached;

  /// The language the app is actually rendering in, as a BCP-47 tag.
  ///
  /// Not derivable from anything else here, which is why it is a static set
  /// from the widget tree (`app.dart`, in `MaterialApp.builder`) rather than a
  /// field of [gather]. The device locale is what the handset asks for; the
  /// saved override is what the user picked *if* they picked anything. Neither
  /// is the answer: with no override, Flutter resolves the device locale
  /// against `supportedLocales` and falls back to English, so a Norwegian
  /// phone runs an English app and both other fields say otherwise.
  ///
  /// Deliberately outside the [gather] cache — the user can change language
  /// mid-session from `LanguageScreen`, and a value cached at launch would then
  /// be wrong for the rest of it.
  static String? appLocaleTag;

  /// Gathered once per launch. Every lookup is individually guarded: a
  /// diagnostics header that throws is worse than one with a hole in it.
  static Future<Map<String, Object?>> gather() async {
    final cached = _cached;
    if (cached != null) return cached;

    final out = <String, Object?>{};

    try {
      final info = await PackageInfo.fromPlatform();
      out['appVersion'] = info.version;
      out['appBuild'] = info.buildNumber;
    } catch (_) {}

    try {
      out['deviceId'] = await DeviceIdentity.ensure();
      out['platform'] = DeviceIdentity.platformTag();
    } catch (_) {}

    try {
      // How this copy was delivered. `unknown` in debug, and on a build carrying
      // no MH_CHANNEL define it falls back to the installer — see
      // `resolveChannel()`. Paired with `platform` above it is the only thing
      // here that tells an iOS build installed on an Apple silicon Mac apart
      // from the real macOS one; see `describeBuild`.
      out['channel'] = (await resolveChannel()).wire;
    } catch (_) {}

    try {
      if (!kIsWeb) {
        out['os'] = Platform.operatingSystem;
        out['osVersion'] = Platform.operatingSystemVersion;
      }
    } catch (_) {}

    // Native build facts. Both mobile platforms answer `getBuildInfo` with the
    // same key names — `model`, `manufacturer`, `release`, `powerSaveMode`,
    // `refreshRate` — so nothing downstream has to branch. Android adds its own
    // extras (`sdkInt`, `oneUi`, the animation scales); iOS adds `osName`.
    //
    // Guarded per-platform rather than by a bare invoke because `_device` is
    // only registered on Android and iOS; on desktop and web the channel does
    // not exist and the miss would be a thrown MissingPluginException per
    // launch.
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final build = await _device.invokeMapMethod<String, Object?>(
          'getBuildInfo',
        );
        if (build != null) out.addAll(build);
      }
    } catch (_) {}

    try {
      final view = ui.PlatformDispatcher.instance.implicitView;
      if (view != null) {
        out['dpr'] = view.devicePixelRatio;
        out['physW'] = view.physicalSize.width;
        out['physH'] = view.physicalSize.height;
        out['padTop'] = view.viewPadding.top / view.devicePixelRatio;
        out['padBottom'] = view.viewPadding.bottom / view.devicePixelRatio;
        out['insetBottom'] = view.viewInsets.bottom / view.devicePixelRatio;
      }
    } catch (_) {}

    try {
      final d = ui.PlatformDispatcher.instance;
      out['locale'] = d.locale.toLanguageTag();
      out['brightness'] = d.platformBrightness.name;
      out['textScale'] = d.textScaleFactor;
      final a = d.accessibilityFeatures;
      out['a11y'] = [
        if (a.accessibleNavigation) 'accessibleNavigation',
        if (a.boldText) 'boldText',
        if (a.disableAnimations) 'disableAnimations',
        if (a.highContrast) 'highContrast',
        if (a.reduceMotion) 'reduceMotion',
        if (a.invertColors) 'invertColors',
      ].join(',');
    } catch (_) {}

    try {
      final s = SettingsStore.instance;
      out['theme'] = s.themeId;
      out['navStyle'] = s.navStyle.name;
      out['chatStyle'] = s.chatStyle.name;
      out['roomLayout'] = s.roomLayout.name;
      out['captureProtection'] = s.captureProtection;
      out['localeOverride'] = s.localeCode;
    } catch (_) {}

    try {
      // HOST ONLY. The full URL is not a secret, but it is the one field where
      // a careless change could start exporting a deployment key, so the shape
      // of this line is deliberately incapable of carrying one.
      //
      // Reads the LIVE server rather than the bundled one: on a self-hosted
      // install those differ, and a report naming the deployment the app is not
      // talking to would send every reader in the wrong direction.
      out['convexHost'] = Uri.tryParse(ServerStore.instance.deploymentUrl)?.host;
      // The single most load-bearing fact about a self-hosted install, and one
      // no other field implies — a private host is unremarkable on its own, and
      // a self-hoster can perfectly well be running on a cloud URL shape.
      out['selfHosted'] = ServerStore.instance.isCustom;
    } catch (_) {}

    _cached = out;
    return out;
  }

  /// The build, in one line: `1.3.81 (1) · macos · macos-testflight`.
  ///
  /// Answers "which binary am I actually looking at", which is not the question
  /// the version alone answers. The three parts disagree in exactly the case
  /// that is hardest to spot from the outside: an iOS build installed on an
  /// Apple silicon Mac reports `ios · ios-testflight` here while the window,
  /// the Dock icon and the app name all say Mac — and every `isWebOrDesktop`
  /// gate in the app quietly takes the mobile branch. `platform` is the part
  /// that decides behaviour, because it reads the same `dart:io` answer
  /// `lib/platform.dart` gates on; `channel` is the part that says how it got
  /// installed, which is what you go and change.
  static String describeBuild(Map<String, Object?> d) {
    final version = d['appVersion']?.toString();
    final build = d['appBuild']?.toString();
    final b = StringBuffer(
      version == null || version.isEmpty ? '—' : version,
    );
    if (build != null && build.isNotEmpty) b.write(' ($build)');
    for (final key in const ['platform', 'channel']) {
      final value = d[key]?.toString();
      if (value != null && value.isNotEmpty) b.write(' · $value');
    }
    return b.toString();
  }

  /// The handset, in one line: `iPhone15,3 · Apple` / `SM-S918B · samsung`.
  ///
  /// Shared by the export header and the user-facing problem report so the two
  /// cannot disagree, and so a platform that answers with fewer fields degrades
  /// in one place. Every part is optional: a line reading just `Apple` is still
  /// worth more than `— · —`, which is what both callers used to render on iOS
  /// before there was an iOS `getBuildInfo`.
  static String describeDevice(Map<String, Object?> d) {
    final parts = [
      d['model'],
      d['manufacturer'],
      if (d['oneUi'] != null) 'One UI ${d['oneUi']}',
    ].map((v) => v?.toString()).where((v) => v != null && v.isNotEmpty);
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  /// The OS, in one line: `iOS 18.1.1` / `android 15 (SDK 35)`.
  ///
  /// Falls back to `Platform.operatingSystemVersion` when the native side gave
  /// no `release`, which is what keeps desktop and web from rendering a bare
  /// platform name with nothing after it.
  static String describeSystem(Map<String, Object?> d) {
    final name = (d['osName'] ?? d['os'])?.toString();
    final version = d['release']?.toString() ?? d['osVersion']?.toString();
    final b = StringBuffer(name == null || name.isEmpty ? '—' : name);
    if (version != null && version.isNotEmpty) b.write(' $version');
    if (d['sdkInt'] != null) b.write(' (SDK ${d['sdkInt']})');
    return b.toString();
  }

  /// The human-readable header block that opens an export.
  static String format(
    Map<String, Object?> d, {
    required int events,
    required int dropped,
    required int uptimeMs,
    required String redactionVersion,
    String? connectionPhase,
  }) {
    String v(String k) => d[k]?.toString() ?? '—';
    final b = StringBuffer();
    b.writeln('MonkeyHub diagnostics');
    b.writeln(
      'generated   ${DateTime.now().toIso8601String()}'
      '  (uptime ${_hms(uptimeMs)})',
    );
    b.writeln('app         ${describeBuild(d)}');
    b.writeln('device      ${describeDevice(d)} · ${describeSystem(d)}');
    b.writeln('deviceId    ${v('deviceId')}');
    b.writeln(
      'display     ${v('physW')}x${v('physH')} @${v('dpr')}'
      ' · refresh ${v('refreshRate')} Hz'
      ' · anim scales ${v('animatorScale')}/${v('transitionScale')}/${v('windowScale')}',
    );
    b.writeln(
      'window      padTop ${v('padTop')} padBottom ${v('padBottom')}'
      ' · insetBottom ${v('insetBottom')} · ${v('brightness')}',
    );
    b.writeln(
      'settings    theme=${v('theme')} nav=${v('navStyle')}'
      ' chat=${v('chatStyle')} captureProtection=${v('captureProtection')}',
    );
    b.writeln(
      'language    app ${appLocaleTag ?? '—'}'
      ' · system ${v('locale')} · override ${v('localeOverride')}',
    );
    b.writeln('a11y        textScale ${v('textScale')} · flags ${v('a11y')}');
    b.writeln('power       powerSave=${v('powerSaveMode')}');
    b.writeln(
      'network     convex ${v('convexHost')}'
      '${connectionPhase != null ? ' · phase=$connectionPhase' : ''}',
    );
    b.writeln(
      'session     events $events (dropped $dropped)'
      ' · redaction $redactionVersion',
    );
    return b.toString();
  }

  static String _hms(int ms) {
    final s = ms ~/ 1000;
    final h = (s ~/ 3600).toString().padLeft(2, '0');
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }
}
