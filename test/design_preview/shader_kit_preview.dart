// The Shader glass kit (liquid_glass_widgets engine), next to Frosted.
//
//   flutter test test/design_preview/shader_kit_preview.dart
//
// Writes build/design_preview/shader_*.png: a board of real LiquidGlass
// surfaces over a colourful backdrop in each kit, and Settings › Glass with
// the shader dials.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show LightweightLiquidGlass;
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/data/shader_glass_config.dart';
import 'package:monkeyhub/screens/glass_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

import 'preview_kit.dart';

class _Board extends StatelessWidget {
  const _Board({required this.kit});
  final UiKit kit;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return UiKitScope(
      kit: kit,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF7A59), Color(0xFF7B5CFF), Color(0xFF1FC8B4)],
                  ),
                ),
                child: Stack(children: [
                  for (var i = 0; i < 9; i++)
                    Positioned(
                      left: (i % 3) * 140.0 - 20,
                      top: 80.0 + (i ~/ 3) * 250,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: i.isEven ? Colors.white : const Color(0xFF101018),
                          shape: i % 3 == 0 ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: i % 3 == 0 ? null : BorderRadius.circular(18),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
            Positioned(
              top: 70,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kit.name, style: theme.displayLarge.copyWith(color: Colors.white)),
                  const SizedBox(height: 18),
                  Row(children: [
                    GlassIconButton(icon: Icons.add, onTap: () {}),
                    const SizedBox(width: 12),
                    GlassIconButton(icon: Icons.add, tint: const Color(0xFF3478F6), onTap: () {}),
                    const SizedBox(width: 12),
                    const LiquidGlass(
                      shape: LiquidGlassShape.capsule,
                      tinted: true,
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Text('Tinted pill'),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  const LiquidGlass(
                    shape: LiquidGlassShape.capsule,
                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    child: Text('A capsule over busy content'),
                  ),
                  const SizedBox(height: 40),
                  const LiquidGlass(
                    shape: LiquidGlassShape.rounded,
                    radius: 26,
                    size: Size(300, 150),
                    child: Text('Rounded card'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    await LightweightLiquidGlass.preWarm();
  });

  for (final kit in [UiKit.shader, UiKit.glass]) {
    testWidgets('board: ${kit.name}', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId('basic_daylight'), _Board(kit: kit)),
        'shader_board_${kit.name}.png',
      );
    });
  }

  testWidgets('board: shader, full lens, tuned', (tester) async {
    SettingsStore.instance.setShaderGlass(
      const ShaderGlassConfig()
          .with_(kShaderThickness, 36)
          .with_(kShaderChromatic, 0.05)
          .withFullLens(true),
    );
    await snap(
      tester,
      previewApp(ThemeController.byId('basic_daylight'), const _Board(kit: UiKit.shader)),
      'shader_board_tuned.png',
    );
    SettingsStore.instance.setShaderGlass(const ShaderGlassConfig());
  });

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('settings: shader $id', (tester) async {
      SettingsStore.instance.setUiKit(UiKit.shader);
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const GlassScreen()),
        'shader_settings_$id.png',
        act: () async {
          await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
        },
      );
    });
  }
}
