import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/diagnostics/device_report.dart';

/// The two lines the problem-report screen and the diagnostics header both show
/// for "what phone is this".
///
/// These exist because both rendered `Device: — · —` and `System: ios —` on every
/// iPhone: `model`, `manufacturer` and `release` were only ever produced by the
/// Android native handler, and the format strings interpolated them regardless.
/// The bug was invisible on the platform being developed on and total on the
/// other, which is exactly the shape a unit test is for.
void main() {
  group('describeDevice', () {
    test('joins the parts an iPhone reports', () {
      expect(
        DeviceReport.describeDevice({
          'model': 'iPhone15,3',
          'manufacturer': 'Apple',
        }),
        'iPhone15,3 · Apple',
      );
    });

    test('appends One UI only when Samsung reported one', () {
      expect(
        DeviceReport.describeDevice({
          'model': 'SM-S918B',
          'manufacturer': 'samsung',
          'oneUi': '6.1',
        }),
        'SM-S918B · samsung · One UI 6.1',
      );
      expect(
        DeviceReport.describeDevice({
          'model': 'Pixel 7',
          'manufacturer': 'Google',
        }),
        'Pixel 7 · Google',
      );
    });

    test('degrades to whatever it has rather than printing separators', () {
      expect(DeviceReport.describeDevice({'manufacturer': 'Apple'}), 'Apple');
      // The regression: an empty map used to render as "— · —".
      expect(DeviceReport.describeDevice({}), '—');
    });
  });

  group('describeSystem', () {
    test('prefers the specific OS name over the platform name', () {
      // `Platform.operatingSystem` says "ios" for an iPad too; systemName does
      // not, and the distinction matters for a layout bug.
      expect(
        DeviceReport.describeSystem({
          'os': 'ios',
          'osName': 'iPadOS',
          'release': '18.1.1',
        }),
        'iPadOS 18.1.1',
      );
    });

    test('carries the Android SDK level, which no other field implies', () {
      expect(
        DeviceReport.describeSystem({
          'os': 'android',
          'release': '15',
          'sdkInt': 35,
        }),
        'android 15 (SDK 35)',
      );
    });

    test('falls back to operatingSystemVersion when there is no release', () {
      // Desktop and web reach neither native handler, so `release` is absent and
      // this is the only version string there is.
      expect(
        DeviceReport.describeSystem({
          'os': 'macos',
          'osVersion': 'Version 15.1 (Build 24B83)',
        }),
        'macos Version 15.1 (Build 24B83)',
      );
    });

    test('never renders a bare platform name with a dangling version', () {
      expect(DeviceReport.describeSystem({'os': 'linux'}), 'linux');
      expect(DeviceReport.describeSystem({}), '—');
    });
  });

  /// The line that exists because an iOS build installed on an Apple silicon
  /// Mac is indistinguishable from the real macOS build by eye — same name,
  /// same Dock icon, same window — while every `isWebOrDesktop` gate in the app
  /// takes the mobile branch. Two builds of the SAME version must not render
  /// the same string.
  group('describeBuild', () {
    test('the two Apple desktop cases are told apart', () {
      const mac = {
        'appVersion': '1.3.81',
        'appBuild': '1',
        'platform': 'macos',
        'channel': 'macos-testflight',
      };
      const iosOnMac = {
        'appVersion': '1.3.81',
        'appBuild': '1',
        'platform': 'ios',
        'channel': 'ios-testflight',
      };

      expect(
        DeviceReport.describeBuild(mac),
        '1.3.81 (1) · macos · macos-testflight',
      );
      expect(
        DeviceReport.describeBuild(iosOnMac),
        '1.3.81 (1) · ios · ios-testflight',
      );
      expect(
        DeviceReport.describeBuild(mac),
        isNot(DeviceReport.describeBuild(iosOnMac)),
      );
    });

    test('degrades a part at a time rather than rendering a hole', () {
      expect(
        DeviceReport.describeBuild({
          'appVersion': '1.3.81',
          'platform': 'macos',
        }),
        '1.3.81 · macos',
      );
      expect(
        DeviceReport.describeBuild({'appVersion': '1.3.81', 'appBuild': '1'}),
        '1.3.81 (1)',
      );
      expect(DeviceReport.describeBuild({}), '—');
    });
  });
}
