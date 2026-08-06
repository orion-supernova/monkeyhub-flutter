import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:package_info_plus/package_info_plus.dart';

import '../data/settings_store.dart';
import '../env.dart';
import '../push/device_identity.dart';

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
      if (!kIsWeb) {
        out['os'] = Platform.operatingSystem;
        out['osVersion'] = Platform.operatingSystemVersion;
      }
    } catch (_) {}

    // Android-only native block. iOS gets the same treatment in v2; today the
    // bug is Android-only and a half-built iOS path would be untested code.
    try {
      if (!kIsWeb && Platform.isAndroid) {
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
      out['convexHost'] = Uri.tryParse(Env.convexUrl)?.host;
    } catch (_) {}

    _cached = out;
    return out;
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
    b.writeln('app         ${v('appVersion')} (${v('appBuild')})');
    b.writeln(
      'device      ${v('model')} · ${v('manufacturer')}'
      '${d['oneUi'] != null ? ' · One UI ${v('oneUi')}' : ''}'
      ' · ${v('os')} ${v('release')} (SDK ${v('sdkInt')})',
    );
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
      'locale      ${v('locale')} (override ${v('localeOverride')})'
      ' · textScale ${v('textScale')} · a11y ${v('a11y')}',
    );
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
