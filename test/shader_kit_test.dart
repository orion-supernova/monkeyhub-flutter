import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/shader_glass_config.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/ui/kits/shader/shader_engine.dart';
import 'package:monkeyhub/ui/kits/shader/shader_glass_surface.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

/// The shader glass kit is an Android + iOS opt-in: never on desktop or web,
/// never chosen by Automatic, and a failed shader start returns the app to
/// the glass kit.
void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    UiKits.shaderUsable = true;
  });

  test('available on Android and iOS only', () {
    for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = p;
      expect(UiKits.available(UiKit.shader), isTrue, reason: '$p');
      expect(UiKits.offered, contains(UiKit.shader), reason: '$p');
    }
    for (final p in [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      debugDefaultTargetPlatformOverride = p;
      expect(UiKits.available(UiKit.shader), isFalse, reason: '$p');
      expect(UiKits.offered, isNot(contains(UiKit.shader)), reason: '$p');
    }
  });

  test('offered between Frosted and Lite', () {
    final o = UiKits.offered;
    expect(o.indexOf(UiKit.shader), greaterThan(o.indexOf(UiKit.glass)));
    expect(o.indexOf(UiKit.shader), lessThan(o.indexOf(UiKit.lite)));
  });

  test('resolution: honoured on mobile, never automatic', () {
    UiKit r(UiKit? c, {bool mobile = true, bool android = true}) =>
        UiKits.resolveWith(c,
            nativeGlass: false, lowTier: false, android: android, mobile: mobile);
    expect(r(UiKit.shader), UiKit.shader);
    expect(r(UiKit.shader, mobile: false, android: false), UiKit.glass);
    expect(r(null), isNot(UiKit.shader));
    expect(
      UiKits.resolveWith(UiKit.shader,
          nativeGlass: false, lowTier: true, android: false, mobile: true),
      UiKit.shader,
      reason: 'an explicit choice beats the low-RAM default',
    );
    expect(UiKit.shader.fallback, UiKit.glass);
    expect(UiKit.shader.blurs, isTrue);
  });

  test('a failed shader start falls back to glass and never throws', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    ShaderGlassEngine.markFailed('test');
    expect(UiKits.available(UiKit.shader), isFalse);
    expect(UiKits.offered, isNot(contains(UiKit.shader)));
    expect(
      UiKits.resolveWith(UiKit.shader,
          nativeGlass: false, lowTier: false, android: false, mobile: true),
      UiKit.glass,
    );
  });

  test('kitValue reaches the shader value, else glass', () {
    expect(kitValue(UiKit.shader, glass: 1, shader: 3), 3);
    expect(kitValue(UiKit.shader, glass: 1, lite: 2), 1);
  });

  test('config round-trips sparse and clamps', () {
    const c = ShaderGlassConfig();
    expect(c.isStandard, isTrue);
    final d = c.with_(kShaderBlur, 99).with_(kShaderTint, 0.5).withFullLens(true);
    expect(d.of(kShaderBlur), kShaderBlur.max);
    final back = ShaderGlassConfig.decode(d.encode());
    expect(back, d);
    expect(back.fullLens, isTrue);
    expect(d.with_(kShaderBlur, kShaderBlur.standard).values.keys,
        isNot(contains('blur')));
    expect(ShaderGlassConfig.decode('not json'), const ShaderGlassConfig());
    // The blur dial scales the chrome blur (Swirl's 5 + 4 at mid level)…
    final s = d.settings(isLight: true);
    expect(s.blur, greaterThan(7.0 * 3));
    // …and the tab bar's iOS 27 frost.
    expect(d.nativeSettings(isLight: true).frost, greaterThan(6.5 * 3));
    // No drawn rim on controls: that is what read as a white outline.
    expect(c.settings(isLight: false).rimLight, 0);
  });

  test('premium lens unless saving power', () {
    const on = ShaderGlassConfig(fullLens: true);
    expect(ShaderGlassSurface.qualityFor(on, saving: false).name, 'premium');
    expect(ShaderGlassSurface.qualityFor(on, saving: true).name, 'standard');
    // Premium by default too: the standard tier's rim stroke read as a
    // white outline.
    expect(ShaderGlassSurface.qualityFor(const ShaderGlassConfig(), saving: false).name,
        'premium');
  });

  testWidgets('LiquidGlass draws the shader skin under the shader kit',
      (tester) async {
    Widget host(UiKit kit) => MaterialApp(
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: UiKitScope(
              kit: kit,
              child: const Scaffold(
                body: Center(
                  child: LiquidGlass(
                    shape: LiquidGlassShape.capsule,
                    padding: EdgeInsets.all(12),
                    child: Text('pill'),
                  ),
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(host(UiKit.shader));
    await tester.pump();
    expect(find.byType(ShaderGlassSurface), findsOneWidget);
    expect(find.text('pill'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(UiKit.glass));
    await tester.pump();
    expect(find.byType(ShaderGlassSurface), findsNothing);
  });
}
