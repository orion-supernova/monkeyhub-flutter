import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/glass_config.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/screens/navigation/native_tab_bar.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/search_field.dart';

/// LiquidGlass is the shared chrome surface for the compact chat style — the
/// header title capsule, the composer field and the round buttons all sit
/// inside one. Its internal Stack sizes to the content child, so
/// whether that child expands decides whether a capsule hugs its label or
/// paints a full-width slab. Getting that wrong is not subtle and it has
/// regressed once already (the header capsule grew a defensive IntrinsicWidth),
/// hence these tests.
void main() {
  Widget host(Widget child, {double width = 800}) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Center(child: child),
          ),
        ),
      ),
    ),
  );

  testWidgets('default buttons stay matched when switching to custom Frosted', (
    tester,
  ) async {
    final store = SettingsStore.instance;
    final previousEngine = store.glassEngine;
    final previousProfile = store.glass;
    final previousPreset = store.glassPresetId;
    final previousSupport = NativeChrome.supported;
    addTearDown(() {
      NativeChrome.debugSupported = previousSupport;
      store.setGlassEngine(previousEngine);
      store.setGlassProfile(previousProfile, presetId: previousPreset);
      store.flushGlassWrites();
    });
    NativeChrome.debugSupported = true;
    store.setGlassEngine(GlassEngine.native);
    store.selectGlassPreset('frosted');
    await tester.pumpWidget(
      host(GlassIconButton(icon: Icons.add, onTap: () {})),
    );

    final rim = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.foregroundPainter is SpecularRim,
    );
    ShapeDecoration frame() =>
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(LiquidGlass),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as ShapeDecoration;
    expect(rim, findsOneWidget);
    final nativeFrame = frame();

    // Keep the same mounted button: settings must update its material live.
    store.setGlassEngine(GlassEngine.flutter);
    await tester.pump();
    expect(rim, findsOneWidget);
    expect(frame(), nativeFrame);

    // Tab bar tuning must not opt the app's buttons into custom styling.
    store.setGlassProfile(
      store.glass.copyWith(
        nav: const GlassConfig({'frost': 0.1, 'shadowY': 19}),
      ),
    );
    store.flushGlassWrites();
    await tester.pump();
    expect(frame(), nativeFrame);

    store.setGlassProfile(
      store.glass.copyWith(app: const GlassConfig({'shadowY': 3})),
    );
    store.flushGlassWrites();
    await tester.pump();
    expect(rim, findsOneWidget);
    expect(frame().shadows!.single.offset.dy, 3.75);

    store.setGlassEngine(GlassEngine.native);
    await tester.pump();
    expect(rim, findsOneWidget);
    store.setGlassEngine(GlassEngine.flutter);
    await tester.pump();
    expect(rim, findsOneWidget);

    store.selectGlassPreset('frosted');
    await tester.pump();
    expect(rim, findsOneWidget);
    expect(frame(), nativeFrame);
  });

  testWidgets('search and buttons tune their specular edge live', (
    tester,
  ) async {
    final store = SettingsStore.instance;
    final previousEngine = store.glassEngine;
    final previousProfile = store.glass;
    final previousPreset = store.glassPresetId;
    store.setGlassEngine(GlassEngine.flutter);
    store.selectGlassPreset('frosted');
    addTearDown(() {
      store.setGlassEngine(previousEngine);
      store.setGlassProfile(previousProfile, presetId: previousPreset);
      store.flushGlassWrites();
    });
    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassIconButton(icon: Icons.add, onTap: () {}),
            SearchField.door(hint: 'Search rooms', onTap: () {}),
          ],
        ),
      ),
    );
    store.setGlassProfile(
      store.glass.copyWith(
        app: const GlassConfig({'rimWidth': 2.5, 'rimOpacity': 0.11}),
      ),
    );
    store.flushGlassWrites();
    await tester.pump();
    final rims = tester.widgetList<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is SpecularRim,
      ),
    );
    expect(rims.length, 2);
    for (final paint in rims) {
      final rim = paint.foregroundPainter! as SpecularRim;
      expect(rim.width, 2.5);
      expect(rim.opacity, 0.5);
    }
    store.selectGlassPreset('frosted');
    await tester.pump();
    for (final paint in tester.widgetList<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is SpecularRim,
      ),
    )) {
      expect((paint.foregroundPainter! as SpecularRim).width, 1);
    }
  });

  testWidgets('without an explicit size the glass hugs its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const LiquidGlass(
          shape: LiquidGlassShape.capsule,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: SizedBox(width: 100, height: 20),
        ),
      ),
    );

    // 100 of child + 12 padding either side. NOT the 800 on offer.
    expect(tester.getSize(find.byType(LiquidGlass)).width, 124);
  });

  testWidgets('a hugging glass still lets a flexible child ellipsize at the '
      'width on offer', (tester) async {
    await tester.pumpWidget(
      host(
        LiquidGlass(
          shape: LiquidGlassShape.capsule,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'x' * 4000,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        width: 300,
      ),
    );

    // Clamped by the parent rather than overflowing it.
    expect(
      tester.getSize(find.byType(LiquidGlass)).width,
      lessThanOrEqualTo(300),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an explicit size still pins the box and centres the child', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const LiquidGlass(
          shape: LiquidGlassShape.circle,
          size: Size(44, 44),
          child: SizedBox(width: 18, height: 18),
        ),
      ),
    );

    expect(tester.getSize(find.byType(LiquidGlass)), const Size(44, 44));
    final glass = tester.getCenter(find.byType(LiquidGlass));
    final icon = tester.getCenter(find.byType(SizedBox).last);
    expect(icon.dx, closeTo(glass.dx, 0.01));
    expect(icon.dy, closeTo(glass.dy, 0.01));
  });

  testWidgets('a tightly constrained glass still fills — the composer field', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Row(
          children: [
            Expanded(
              child: LiquidGlass(
                shape: LiquidGlassShape.rounded,
                child: SizedBox(height: 40),
              ),
            ),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(LiquidGlass)).width, 800);
  });
}
