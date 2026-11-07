import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/ui/kits/shader/shader_tab_bar.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';
import 'package:monkeyhub/widgets/value_slider.dart';

/// Under the shader kit every shared control is the package's own widget, and
/// the behaviour the app owns (the tap, the value) still comes through.
void main() {
  Widget host(Widget child, {UiKit kit = UiKit.shader}) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: UiKitScope(
            kit: kit,
            child: Material(
              child: Center(child: SizedBox(width: 320, child: child)),
            ),
          ),
        ),
      );

  testWidgets('buttons are the package GlassButton and still tap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassIconButton(icon: Icons.add, onTap: () => taps++),
        GlassPillButton(label: 'Done', onTap: () => taps++),
        SheetActionButton(label: 'Continue', onTap: () => taps++),
      ],
    )));
    await tester.pump();
    expect(find.byType(lgw.GlassButton), findsNWidgets(3));
    await tester.tap(find.byType(lgw.GlassButton).first);
    await tester.pump();
    expect(taps, 1);
    await tester.pumpWidget(host(
      GlassIconButton(icon: Icons.add, onTap: () {}),
      kit: UiKit.glass,
    ));
    await tester.pump();
    expect(find.byType(lgw.GlassButton), findsNothing);
  });

  testWidgets('switch, slider and segmented are the package widgets',
      (tester) async {
    bool? on;
    int? seg;
    await tester.pumpWidget(host(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RowSwitch(value: false, onChanged: (v) => on = v),
        ValueSlider(value: 0.5, onChanged: (_) {}),
        IosSegmentedControl<int>(
          segments: const [
            IosSegment(value: 0, label: 'A'),
            IosSegment(value: 1, label: 'B'),
          ],
          value: 0,
          onChanged: (v) => seg = v,
        ),
      ],
    )));
    await tester.pump();
    expect(find.byType(lgw.GlassSwitch), findsOneWidget);
    expect(find.byType(lgw.GlassSlider), findsOneWidget);
    expect(find.byType(lgw.GlassSegmentedControl), findsOneWidget);
    await tester.tap(find.byType(lgw.GlassSwitch));
    await tester.pumpAndSettle();
    expect(on, isTrue);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(seg, 1);
  });

  test('pill widths hug the label and the end tabs reach the bar edge', () {
    final w = ShaderTabBar.pillWidths([30, 60, 40, 44, 52], 340);
    expect(w, hasLength(5));
    expect(w[1], greaterThan(w[2]), reason: 'a longer label, a wider pill');
    expect(w.every((x) => x >= 78), isTrue);
    final slot = (340 - 2 * ShaderTabBar.tabInset) / 5;
    final endCentre = ShaderTabBar.tabInset + slot / 2;
    expect(w.first, greaterThanOrEqualTo(2 * (endCentre - 4)));
    expect(w.last, greaterThanOrEqualTo(2 * (endCentre - 4)));
  });

  test('Interactive glass defaults on and persists as a plain toggle', () async {
    final store = SettingsStore.instance;
    expect(store.glassInteractive, isTrue);
    await store.setGlassInteractive(false);
    expect(store.glassInteractive, isFalse);
    await store.setGlassInteractive(true);
    expect(store.glassInteractive, isTrue);
  });
}
