import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

/// The interface kit is one setting resolved once; these pin the resolution
/// rules and the promise every component relies on: the lite kit never draws
/// a backdrop blur, and a kit with no skin of its own falls back to glass.
void main() {
  group('UiKits.resolveWith', () {
    UiKit resolve(
      UiKit? choice, {
      bool nativeGlass = false,
      bool lowTier = false,
      bool android = false,
      bool materialReady = false,
    }) =>
        UiKits.resolveWith(
          choice,
          nativeGlass: nativeGlass,
          lowTier: lowTier,
          android: android,
          materialReady: materialReady,
        );

    test('automatic: iOS 26 gets Liquid Glass, even on a low-RAM phone', () {
      expect(resolve(null, nativeGlass: true), UiKit.liquid);
      expect(resolve(null, nativeGlass: true, lowTier: true), UiKit.liquid);
    });

    test('automatic: a low-RAM phone without native glass gets Lite', () {
      expect(resolve(null, lowTier: true), UiKit.lite);
      expect(resolve(null, lowTier: true, android: true), UiKit.lite);
    });

    test('automatic: everything else gets Frosted glass', () {
      expect(resolve(null), UiKit.glass);
      expect(resolve(null, android: true), UiKit.glass,
          reason: 'Material is not offered until its kit ships');
      expect(resolve(null, android: true, materialReady: true), UiKit.material);
    });

    test('an explicit choice wins when the device can draw it', () {
      expect(resolve(UiKit.glass, nativeGlass: true), UiKit.glass);
      expect(resolve(UiKit.lite, nativeGlass: true), UiKit.lite);
      expect(resolve(UiKit.glass, lowTier: true), UiKit.glass);
    });

    test('a choice the device cannot honour means automatic', () {
      expect(resolve(UiKit.liquid), UiKit.glass);
      expect(resolve(UiKit.liquid, lowTier: true), UiKit.lite);
      expect(resolve(UiKit.material, android: true), UiKit.glass);
    });
  });

  test('kitValue falls back to glass for a kit with no value', () {
    expect(kitValue(UiKit.lite, glass: 1, lite: 2), 2);
    expect(kitValue(UiKit.liquid, glass: 1, lite: 2), 1);
    expect(kitValue(UiKit.material, glass: 1), 1);
    expect(kitValue<int?>(UiKit.lite, glass: null), isNull);
  });

  Widget host(UiKit kit, Widget child) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: UiKitScope(
            kit: kit,
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );

  for (final tone in GlassTone.values) {
    testWidgets('lite draws no backdrop blur (${tone.name} tone)',
        (tester) async {
      final button = GlassIconButton(icon: Icons.add, tone: tone, onTap: () {});
      final surface = LiquidGlass(
        tone: tone,
        shape: LiquidGlassShape.capsule,
        padding: const EdgeInsets.all(12),
        child: const Text('pill'),
      );
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        children: [button, surface],
      );

      await tester.pumpWidget(host(UiKit.glass, column));
      expect(find.byType(BackdropFilter), findsWidgets,
          reason: 'the glass kit is the blurred reference');

      await tester.pumpWidget(host(UiKit.lite, column));
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('pill'), findsOneWidget);
    });
  }

  testWidgets('KitSwitch walks to the glass skin when a kit has none',
      (tester) async {
    const sw = KitSwitch(
      glass: _glass,
      lite: _lite,
    );
    await tester.pumpWidget(host(UiKit.lite, sw));
    expect(find.text('lite'), findsOneWidget);
    await tester.pumpWidget(host(UiKit.liquid, sw));
    expect(find.text('glass'), findsOneWidget);
  });
}

Widget _glass(BuildContext context) => const Text('glass');
Widget _lite(BuildContext context) => const Text('lite');
