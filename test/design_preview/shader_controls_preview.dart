// Every shared control in the Shader glass kit (the package's own widgets), on
// a colourful backdrop, next to the same board in Frosted.
//
//   flutter test test/design_preview/shader_controls_preview.dart
//
// Writes build/design_preview/shader_controls_*.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show LightweightLiquidGlass;
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/ui/kits/shader/shader_tab_bar.dart';
import 'package:monkeyhub/widgets/filter_capsule.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';
import 'package:monkeyhub/widgets/labeled_field.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';
import 'package:monkeyhub/widgets/pull_down_button.dart';
import 'package:monkeyhub/widgets/pull_down_menu.dart';
import 'package:monkeyhub/widgets/search_field.dart';
import 'package:monkeyhub/widgets/value_slider.dart';

import 'preview_kit.dart';

class _Board extends StatefulWidget {
  const _Board({required this.kit});
  final UiKit kit;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  final _field = TextEditingController(text: 'Hello glass');
  final _search = TextEditingController();
  int _seg = 1;

  @override
  void dispose() {
    _field.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return UiKitScope(
      kit: widget.kit,
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
                    colors: [
                      Color(0xFFFF7A59),
                      Color(0xFF7B5CFF),
                      Color(0xFF1FC8B4),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    for (var i = 0; i < 12; i++)
                      Positioned(
                        left: (i % 3) * 140.0 - 20,
                        top: 60.0 + (i ~/ 3) * 190,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.white
                                : const Color(0xFF101018),
                            shape: i % 3 == 0
                                ? BoxShape.circle
                                : BoxShape.rectangle,
                            borderRadius:
                                i % 3 == 0 ? null : BorderRadius.circular(16),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 64,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.kit.name,
                    style: theme.displayLarge.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GlassIconButton(icon: Icons.add, onTap: () {}),
                      const SizedBox(width: 10),
                      GlassIconButton(
                        icon: Icons.add,
                        tint: const Color(0xFF3478F6),
                        onTap: () {},
                      ),
                      const SizedBox(width: 10),
                      GlassPillButton(label: 'Done', onTap: () {}),
                      const SizedBox(width: 10),
                      PullDownButton<int>(
                        semanticLabel: 'More',
                        items: const [
                          PullDownItem(value: 1, label: 'One'),
                          PullDownItem(value: 2, label: 'Two', checked: true),
                        ],
                        onSelected: (_) {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassButtonGroup(
                    tone: GlassTone.app,
                    items: [
                      GlassGroupItem(
                        icon: Icons.undo,
                        semanticLabel: 'Undo',
                        onTap: () {},
                      ),
                      GlassGroupItem(
                        icon: Icons.brush,
                        semanticLabel: 'Pen',
                        active: true,
                        onTap: () {},
                      ),
                      GlassGroupItem(
                        text: 'HD',
                        semanticLabel: 'HD',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SheetActionButton(label: 'Continue', onTap: () {}),
                  const SizedBox(height: 8),
                  SheetActionButton(
                    label: 'Not now',
                    tonal: true,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Switch  ',
                          style: TextStyle(color: Colors.white)),
                      RowSwitch(value: true, onChanged: (_) {}),
                      const SizedBox(width: 12),
                      RowSwitch(value: false, onChanged: (_) {}),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ValueSlider(value: 0.6, onChanged: (_) {}),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  IosSegmentedControl<int>(
                    segments: const [
                      IosSegment(value: 0, label: 'Chats'),
                      IosSegment(value: 1, label: 'Calls'),
                      IosSegment(value: 2, label: 'Games'),
                    ],
                    value: _seg,
                    onChanged: (v) => setState(() => _seg = v),
                  ),
                  const SizedBox(height: 12),
                  ThemedInput(controller: _field, hint: 'A field'),
                  const SizedBox(height: 10),
                  SearchField(
                    controller: _search,
                    hintText: 'Search',
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterCapsule(label: 'All', active: true, onTap: () {}),
                      FilterCapsule(
                        label: 'Unread',
                        active: false,
                        count: 4,
                        onTap: () {},
                      ),
                      FilterCapsule(label: 'Groups', active: false, onTap: () {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const LiquidGlass(
                    shape: LiquidGlassShape.rounded,
                    radius: 26,
                    size: Size(300, 70),
                    child: Text('Generic surface'),
                  ),
                ],
              ),
            ),
            if (widget.kit == UiKit.shader)
              ShaderTabBar(
                active: HomeSection.values.first,
                onSelect: (_) {},
                badges: {HomeSection.values.first: 3},
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

  for (final id in ['basic_daylight', 'basic']) {
    for (final kit in [UiKit.shader, UiKit.glass]) {
      testWidgets('controls: ${kit.name} $id', (tester) async {
        SettingsStore.instance.setUiKit(kit);
        await snap(
          tester,
          previewApp(ThemeController.byId(id), _Board(kit: kit)),
          'shader_controls_${kit.name}_$id.png',
        );
      });
    }
  }
}
