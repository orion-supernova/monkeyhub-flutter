import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/glass_config.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/keyboard/focusable_tap.dart';
import 'package:monkeyhub/screens/glass_screen.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/screens/navigation/pill_bottom_nav.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

/// The glass tuning is stored sparsely and read back through a tolerant
/// decoder, which is what lets a look saved by one build survive being opened
/// by another. Both halves of that are easy to break silently — a config that
/// round-trips wrong just looks like the user's slot "not working".
GlassPreset _presetNamed(String name) =>
    kBuiltInGlassPresets.firstWhere((p) => p.name == name);

void main() {
  group('GlassConfig', () {
    test('an untouched dial reports its standard', () {
      const c = GlassConfig();
      expect(c.of(kBlur), kBlur.standard);
      expect(c.isStandard(kBlur), isTrue);
    });

    test('set marks the dial as moved, reset puts it back', () {
      final c = const GlassConfig().set(kBlur, 4);
      expect(c.of(kBlur), 4);
      expect(c.isStandard(kBlur), isFalse);
      expect(c.reset(kBlur).of(kBlur), kBlur.standard);
      expect(c.reset(kBlur).isStandard(kBlur), isTrue);
    });

    test('values are clamped on the way in and on the way out', () {
      expect(const GlassConfig().set(kBlur, 4000).of(kBlur), kBlur.max);
      expect(const GlassConfig().set(kBlur, -50).of(kBlur), kBlur.min);
      // A hand-edited keychain entry never goes through `set`.
      expect(
        const GlassConfig(<String, double>{'blur': 9999}).of(kBlur),
        kBlur.max,
      );
    });

    test('only moved dials are stored, so standards can be retuned later', () {
      final c = const GlassConfig().set(kFrost, 0.5);
      expect(c.toJson().keys, ['frost']);
    });

    test('round-trips through JSON', () {
      final c = const GlassConfig().set(kFrost, 0.5).set(kSaturation, 1.4);
      final back = GlassConfig.fromJson(jsonDecode(jsonEncode(c.toJson())));
      expect(back, c);
      expect(back.of(kFrost), 0.5);
      expect(back.of(kSaturation), 1.4);
    });

    test('survives junk rather than failing to parse', () {
      final c = GlassConfig.fromJson({
        'frost': 0.5,
        'blur': 'not a number',
        'knobFromAFutureBuild': 3,
        7: 9,
      });
      expect(c.of(kFrost), 0.5);
      expect(c.of(kBlur), kBlur.standard);
      expect(GlassConfig.fromJson('nonsense'), const GlassConfig());
      expect(GlassConfig.fromJson(null), const GlassConfig());
    });

    test('slider mapping is a round trip across the range', () {
      for (final knob in [...glassKnobs, ...navGeometryKnobs]) {
        for (final t in [0.0, 0.25, 0.5, 1.0]) {
          expect(
            knob.toSlider(knob.fromSlider(t)),
            closeTo(t, 1e-9),
            reason: '${knob.id} at $t',
          );
        }
      }
    });
  });

  group('GlassProfile / GlassPreset', () {
    test('a profile round-trips all three configs', () {
      final p = GlassProfile(
        nav: const GlassConfig().set(kBlur, 5),
        app: const GlassConfig().set(kFrost, 0.8),
        geometry: const GlassConfig().set(kBarMargin, 24),
      );
      expect(GlassProfile.fromJson(jsonDecode(jsonEncode(p.toJson()))), p);
    });

    test('a preset missing an id is dropped, not half-built', () {
      expect(GlassPreset.fromJson({'name': 'x'}), isNull);
      expect(GlassPreset.fromJson({'id': '', 'name': 'x'}), isNull);
      expect(GlassPreset.fromJson('nonsense'), isNull);
      expect(GlassPreset.fromJson({'id': 'a', 'name': 'x'}), isNotNull);
    });

    test('slot names are trimmed, collapsed and capped', () {
      expect(sanitizeSlotName('  late   night  '), 'late night');
      expect(sanitizeSlotName('   '), '');
      expect(
        sanitizeSlotName('x' * 100).length,
        lessThanOrEqualTo(kMaxSlotNameLength),
      );
    });
  });

  group('built-in presets', () {
    test('the default is the readable one, not the see-through one', () {
      expect(kDefaultGlassPresetId, 'frosted');
    });

    test('Frosted is the tuning the bar shipped with before Clear', () {
      final nav = kBuiltInGlassPresets
          .firstWhere((p) => p.id == 'frosted')
          .profile
          .nav;
      expect(nav.of(kFrost), 0.45);
      expect(nav.of(kBlur), 10);
      // No colour trickery — that arrived with Clear.
      expect(nav.of(kSaturation), 1.0);
    });

    test('Clear keeps the see-through tuning', () {
      final nav = kBuiltInGlassPresets
          .firstWhere((p) => p.id == 'clear')
          .profile
          .nav;
      expect(nav.of(kFrost), 0.3);
      expect(nav.of(kBlur), 5);
      expect(nav.of(kSaturation), 1.7);
    });

    test('neither built-in touches the app-wide or layout dials', () {
      for (final p in kBuiltInGlassPresets) {
        expect(p.profile.app, const GlassConfig(), reason: p.id);
        expect(p.profile.geometry, const GlassConfig(), reason: p.id);
      }
    });
  });

  group('SettingsStore slots', () {
    final store = SettingsStore.instance;

    tearDown(() async {
      for (final s in store.glassSlots) {
        store.deleteGlassSlot(s.id);
      }
      store.selectGlassPreset(kDefaultGlassPresetId);
      store.flushGlassWrites();
    });

    test('starts on the default preset', () {
      expect(store.glassPresetId, kDefaultGlassPresetId);
      expect(store.glass.nav.of(kBlur), 10);
    });

    test(
      'a fresh install wears the default look by name, not "Custom"',
      () async {
        // load() reads from a keychain the test harness does not provide, so
        // every read comes back null — exactly a first launch. The pointer used
        // to be read on its own, which overwrote the field's default with that
        // null and left the app wearing Frosted's values under the label
        // "Custom", a state the UI cannot otherwise reach.
        await SettingsStore.instance.load();
        expect(store.glassPresetId, kDefaultGlassPresetId);
        expect(store.glass, _presetNamed('Frosted').profile);
      },
    );

    test('selecting a preset replaces the live profile', () async {
      store.selectGlassPreset('clear');
      expect(store.glass.nav.of(kSaturation), 1.7);
      expect(store.glassPresetId, 'clear');
    });

    test('an unknown preset id falls back rather than throwing', () async {
      store.selectGlassPreset('does-not-exist');
      expect(store.glassPresetId, kBuiltInGlassPresets.first.id);
    });

    test('an edit keeps the look it is based on', () async {
      store.selectGlassPreset('clear');
      await store.setGlassProfile(
        store.glass.copyWith(nav: store.glass.nav.set(kBlur, 2)),
        presetId: store.glassPresetId,
      );
      expect(
        store.glassPresetId,
        'clear',
        reason: 'the pointer is what reset and the edited marker measure from',
      );
      expect(store.glass.nav.of(kBlur), 2);
    });

    test('saving names the live tuning and activates it', () async {
      await store.setGlassProfile(
        const GlassProfile().copyWith(nav: const GlassConfig().set(kBlur, 3)),
      );
      expect(store.saveGlassSlot('  late   night '), isTrue);

      final slot = store.glassSlots.single;
      expect(slot.name, 'late night');
      expect(slot.profile.nav.of(kBlur), 3);
      expect(store.glassPresetId, slot.id);
      expect(store.glassPresets.length, kBuiltInGlassPresets.length + 1);
    });

    test('a blank name is refused', () async {
      expect(store.saveGlassSlot('   '), isFalse);
      expect(store.glassSlots, isEmpty);
    });

    test('the cap is enforced', () async {
      for (var i = 0; i < kMaxGlassSlots; i++) {
        expect(store.saveGlassSlot('slot $i'), isTrue);
      }
      expect(store.glassSlotsFull, isTrue);
      expect(store.saveGlassSlot('one too many'), isFalse);
      expect(store.glassSlots.length, kMaxGlassSlots);
    });

    test(
      'overwriting a slot keeps its name and takes the live tuning',
      () async {
        store.saveGlassSlot('mood');
        final id = store.glassSlots.single.id;
        await store.setGlassProfile(
          store.glass.copyWith(nav: store.glass.nav.set(kFrost, 0.1)),
        );
        store.updateGlassSlot(id);

        expect(store.glassSlots.single.name, 'mood');
        expect(store.glassSlots.single.profile.nav.of(kFrost), 0.1);
        expect(store.glassPresetId, id);
      },
    );

    test('renaming leaves the tuning alone', () async {
      store.saveGlassSlot('before');
      final id = store.glassSlots.single.id;
      store.renameGlassSlot(id, 'after');
      expect(store.glassSlots.single.name, 'after');
      expect(store.glassSlots.single.id, id);
    });

    test('deleting the active slot keeps the look you are wearing', () async {
      await store.setGlassProfile(
        const GlassProfile().copyWith(nav: const GlassConfig().set(kBlur, 7)),
      );
      store.saveGlassSlot('doomed');
      store.deleteGlassSlot(store.glassSlots.single.id);

      expect(store.glassSlots, isEmpty);
      expect(store.glassPresetId, isNull, reason: 'it is Custom now');
      expect(
        store.glass.nav.of(kBlur),
        7,
        reason: 'deleting a name must not throw away the tuning',
      );
    });

    test('saved slots survive an encode/decode cycle', () async {
      store.saveGlassSlot('mood');
      final encoded = jsonEncode([
        for (final s in store.glassSlots) s.toJson(),
      ]);
      final back = [
        for (final e in jsonDecode(encoded) as List) GlassPreset.fromJson(e),
      ];
      expect(back.single, isNotNull);
      expect(back.single!.name, 'mood');
      expect(back.single!.profile, store.glassSlots.single.profile);
    });
  });

  group('the dials actually reach the widgets', () {
    final store = SettingsStore.instance;

    tearDown(() async {
      store.selectGlassPreset(kDefaultGlassPresetId);
      store.flushGlassWrites();
    });

    Widget wrap(Widget child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        home: Scaffold(body: Stack(children: [child])),
      ),
    );

    testWidgets('bar margin moves the bar', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<Rect> barAt(double margin) async {
        await store.setGlassProfile(
          store.glass.copyWith(
            geometry: store.glass.geometry.set(kBarMargin, margin),
          ),
        );
        // The setter debounces its keychain write, and the test binding fails
        // the test if a timer outlives the widget tree.
        store.flushGlassWrites();
        await tester.pumpWidget(
          wrap(
            PillBottomNav(
              active: HomeSection.chat,
              onSelect: (_) {},
              badges: const {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.getRect(find.byType(LiquidGlass));
      }

      expect((await barAt(16)).left, 16);
      expect((await barAt(32)).left, 32);
    });

    testWidgets('icon size and pill inset reach the layout', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await store.setGlassProfile(
        store.glass.copyWith(
          geometry: store.glass.geometry
              .set(kIconSize, 30)
              .set(kIndicatorInset, 12),
        ),
      );
      store.flushGlassWrites();
      await tester.pumpWidget(
        wrap(
          PillBottomNav(
            active: HomeSection.chat,
            onSelect: (_) {},
            badges: const {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byIcon(navDestinations.first.icon)).width, 30);

      // The pill's inset is measured against its slot, so it holds whatever
      // the bar's width works out to.
      final slot = tester.getRect(find.byType(FocusableTap).first);
      final pill = tester.getRect(find.byKey(navIndicatorKey));
      expect(pill.left - slot.left, closeTo(12, 0.01));
      expect(slot.right - pill.right, closeTo(12, 0.01));
    });

    testWidgets('every other surface follows the app config, not the nav one', (
      tester,
    ) async {
      await store.setGlassProfile(
        const GlassProfile(
          nav: GlassConfig(<String, double>{'shadowY': 19}),
          app: GlassConfig(<String, double>{'shadowY': 3}),
        ),
      );
      store.flushGlassWrites();
      await tester.pumpWidget(
        wrap(
          const Align(
            child: LiquidGlass(
              shape: LiquidGlassShape.rounded,
              size: Size(80, 40),
              child: SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(LiquidGlass),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final shadow = (decorated.decoration as ShapeDecoration).shadows!.single;
      expect(
        shadow.offset.dy,
        3,
        reason: 'a null config must read glass.app, never glass.nav',
      );
    });
  });

  group('the tuning screen', () {
    final store = SettingsStore.instance;

    tearDown(() {
      store.selectGlassPreset(kDefaultGlassPresetId);
      store.flushGlassWrites();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: const MaterialApp(home: GlassScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the preview stays on screen while the dials scroll past', (
      tester,
    ) async {
      await pumpScreen(tester);
      final before = tester.getRect(find.byType(PillBottomNav));

      // Far enough to bury the preview several times over — there are 17
      // dials below it.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      expect(
        find.byType(PillBottomNav),
        findsOneWidget,
        reason: 'the whole point is watching the bar while you tune it',
      );
      final after = tester.getRect(find.byType(PillBottomNav));
      expect(after.top, lessThan(before.top), reason: 'it should have pinned');
      expect(after.top, greaterThanOrEqualTo(0.0));
      expect(after.bottom, lessThanOrEqualTo(812.0));
    });

    testWidgets('a taller bar gets a taller pin rather than being clipped', (
      tester,
    ) async {
      store.setGlassProfile(
        const GlassProfile(
          geometry: GlassConfig(<String, double>{
            'iconSize': 32,
            'segmentPadV': 20,
            'shellPadV': 16,
            'barBottom': 40,
          }),
        ),
      );
      store.flushGlassWrites();
      await pumpScreen(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Pinned at the top with the layout dials wound right up, the bar still
      // has to fit inside the header it is pinned in.
      final bar = tester.getRect(find.byType(LiquidGlass));
      final header = tester.getRect(find.byKey(glassPreviewKey));
      expect(bar.top, greaterThanOrEqualTo(header.top - 0.5));
      expect(bar.bottom, lessThanOrEqualTo(header.bottom + 0.5));
    });

    testWidgets('the backdrop scrolls under the bar without moving the page', (
      tester,
    ) async {
      await pumpScreen(tester);
      final barBefore = tester.getRect(find.byType(LiquidGlass));

      // Inner scrollables win the gesture arena, so a drag that starts on the
      // preview must move the content behind the bar and leave the dials put.
      final backdrop = find.descendant(
        of: find.byKey(glassPreviewKey),
        matching: find.byType(Scrollable),
      );
      expect(backdrop, findsOneWidget);

      final firstRow = find.text('Dilan');
      final rowBefore = tester.getRect(firstRow);
      await tester.drag(backdrop, const Offset(0, -60));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(firstRow).top,
        lessThan(rowBefore.top),
        reason: 'the content behind the glass should have moved',
      );
      expect(
        tester.getRect(find.byType(LiquidGlass)),
        barBefore,
        reason: 'the bar itself must stay exactly where it is',
      );
    });

    testWidgets('an edit grows an undo, and it undoes back to the preset', (
      tester,
    ) async {
      // On a freshly selected preset nothing is "modified" — edits are marked
      // against the look you picked, not against the untuned recipe.
      await pumpScreen(tester);
      expect(find.byIcon(Icons.undo), findsNothing);

      final page = find.byType(Scrollable).first;
      // No `.first` on the target: scrollUntilVisible probes the finder while
      // it still matches nothing, and a first-finder throws there rather than
      // reporting empty.
      await tester.scrollUntilVisible(find.text('BLUR'), 140, scrollable: page);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.undo), findsNothing);

      store.setGlassProfile(
        store.glass.copyWith(nav: store.glass.nav.set(kBlur, 2)),
        presetId: store.glassPresetId,
      );
      store.flushGlassWrites();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.undo), findsOneWidget);
      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      expect(
        store.glass.nav.of(kBlur),
        10,
        reason: 'undo goes back to Frosted, not to the raw recipe',
      );
      expect(find.byIcon(Icons.undo), findsNothing);
    });

    testWidgets('a panel reset clears only its own dials', (tester) async {
      store.setGlassProfile(
        const GlassProfile(
          nav: GlassConfig(<String, double>{'blur': 2}),
          app: GlassConfig(<String, double>{'frost': 0.5}),
          geometry: GlassConfig(<String, double>{'barMargin': 30}),
        ),
        presetId: null,
      );
      store.flushGlassWrites();
      await pumpScreen(tester);

      // By key, not by index into find.byIcon: the dial rows live in a lazy
      // sliver, so which controls exist depends on where the list is scrolled.
      final target = find.byKey(glassPanelResetKey('BOTTOM BAR'));
      await tester.scrollUntilVisible(
        target,
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(store.glass.nav.isUntouched, isTrue);
      expect(store.glass.app.isUntouched, isFalse);
      expect(store.glass.geometry.isUntouched, isFalse);
    });

    testWidgets('reset every dial clears all three panels at once', (
      tester,
    ) async {
      store.setGlassProfile(
        const GlassProfile(
          nav: GlassConfig(<String, double>{'blur': 2}),
          app: GlassConfig(<String, double>{'frost': 0.5}),
          geometry: GlassConfig(<String, double>{'barMargin': 30}),
        ),
        presetId: null,
      );
      store.flushGlassWrites();
      await pumpScreen(tester);

      // With no look selected the baseline is the untuned recipe.
      expect(store.glassPresetId, isNull);
      await tester.tap(find.text('RESET EVERY DIAL'));
      await tester.pumpAndSettle();

      expect(store.glass.isUntouched, isTrue);
    });

    testWidgets('on a preset, reset is offered by that name and undoes to it', (
      tester,
    ) async {
      store.selectGlassPreset('clear');
      store.flushGlassWrites();
      await pumpScreen(tester);

      // Nothing edited yet, so nothing to undo — the control that read as a
      // bug when it stayed lit on a freshly picked preset.
      expect(find.text('RESET TO CLEAR'), findsOneWidget);
      expect(find.byIcon(Icons.undo), findsNothing);

      store.setGlassProfile(
        store.glass.copyWith(nav: store.glass.nav.set(kBlur, 25)),
        presetId: store.glassPresetId,
      );
      store.flushGlassWrites();
      await tester.pumpAndSettle();

      // Still based on Clear, now marked as drifted from it.
      expect(find.text('RESET TO CLEAR'), findsOneWidget);
      expect(find.textContaining('edited'), findsOneWidget);

      await tester.tap(find.text('RESET TO CLEAR'));
      await tester.pumpAndSettle();
      expect(store.glass.nav.of(kBlur), 5);
    });

    testWidgets('the preview follows the panel you scroll into', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.byType(PillBottomNav), findsOneWidget);

      final page = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('OTHER SURFACES'),
        200,
        scrollable: page,
      );
      // scrollUntilVisible stops as soon as the header is on screen at all —
      // the preview only switches once that panel is the one pinned at top.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(
        find.byType(PillBottomNav),
        findsNothing,
        reason:
            'the app-wide dials change nothing on the bar, so previewing '
            'the bar while tuning them would be tuning blind',
      );
      expect(find.text('message'), findsOneWidget);
    });

    testWidgets('matching copies the bar\'s glass onto the other surfaces', (
      tester,
    ) async {
      store.selectGlassPreset('clear');
      store.flushGlassWrites();
      await pumpScreen(tester);

      final target = find.text('MATCH THE BOTTOM BAR');
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(store.glass.app, store.glass.nav);
      expect(store.glass.app.of(kSaturation), 1.7);
      // The bar itself is untouched by the copy.
      expect(store.glass.nav, _presetNamed('Clear').profile.nav);
    });

    testWidgets('the preview collapses and expands', (tester) async {
      await pumpScreen(tester);
      final tall = tester.getRect(find.byKey(glassPreviewKey)).height;

      await tester.tap(find.byKey(glassPreviewToggleKey));
      await tester.pumpAndSettle();
      final short = tester.getRect(find.byKey(glassPreviewKey)).height;
      expect(short, lessThan(tall));
      expect(
        find.byType(LiquidGlass),
        findsWidgets,
        reason: 'collapsed still has to show the bar itself',
      );

      await tester.tap(find.byKey(glassPreviewToggleKey));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(glassPreviewKey)).height, tall);
    });
  });
}
