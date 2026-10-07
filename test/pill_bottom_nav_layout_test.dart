import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/keyboard/focusable_tap.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/screens/navigation/pill_bottom_nav.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

final _l10n = AppLocalizationsEn();
final _navDestinations = navDestinations(_l10n);

/// Geometry the bottom nav asserts about itself, which `nav_geometry_test.dart`
/// structurally cannot: that file checks `segmentAlignmentX` as arithmetic and
/// never builds a widget, so it stayed green through a shipped bug where every
/// segment's icon+label sat 13.875pt left of centre.
///
/// The cause was not the indicator maths — that was exact. It was [FocusableTap]
/// wrapping its child in a `StackFit.loose` Stack: the wrapper received the
/// segment's tight 81.5pt from `Expanded`, loosened it, let the `mainAxisSize.min`
/// Column shrink-wrap to ~54pt, then pinned that at the Stack's default
/// `AlignmentDirectional.topStart`. The same slack left ~28pt of every segment
/// dead to touch, because the child's `GestureDetector` was all that was opaque.
///
/// So these tests deliberately assert against *measured* rects rather than
/// hardcoded points: the invariant is "content is centred in its own slot and
/// the whole slot is tappable", which holds at any width.
void main() {
  Widget wrap(Widget child, {TextDirection direction = TextDirection.ltr}) =>
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Directionality(
              textDirection: direction,
              child: Stack(children: [child]),
            ),
          ),
        ),
      );

  Future<void> pumpNav(
    WidgetTester tester, {
    HomeSection active = HomeSection.chat,
    ValueChanged<HomeSection>? onSelect,
    Map<HomeSection, int> badges = const {},
    TextDirection direction = TextDirection.ltr,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        PillBottomNav(
          active: active,
          onSelect: onSelect ?? (_) {},
          badges: badges,
        ),
        direction: direction,
      ),
    );
    // Re-pumping with a different `active` restarts the indicator's
    // AnimatedAlign from wherever it was, so without this the tests below
    // measure a half-finished slide rather than the resting position.
    await tester.pumpAndSettle();
  }

  /// Pumps the bar with a home-indicator inset, the way a notched phone has
  /// one, and hands back the screen height so the caller can measure the gap.
  Future<double> pumpNavWithInset(
    WidgetTester tester, {
    double inset = 34,
  }) async {
    const size = Size(375, 812);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    // `viewPadding`, not `padding` — that is precisely the distinction the bar
    // depends on, so the test has to set the one the widget reads.
    tester.view.viewPadding = FakeViewPadding(bottom: inset);
    tester.view.padding = FakeViewPadding(bottom: inset);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(PillBottomNav(active: HomeSection.chat, onSelect: (_) {}, badges: const {})),
    );
    await tester.pumpAndSettle();
    return size.height;
  }

  group('bottom placement', () {
    testWidgets('floats the knob above the home indicator, not above the '
        'whole inset', (tester) async {
      // An iPhone's inset. flutter_test reports Android by default, where a
      // 34pt inset would read as a button bar — see the Android tests below.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      late double screenH;
      late Rect bar;
      try {
        screenH = await pumpNavWithInset(tester, inset: 34);
        bar = tester.getRect(find.byType(LiquidGlass));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      // `kIndicatorKeepOut` + the knob. This has been wrong twice in opposite
      // directions: 46pt when the knob was ADDED to the inset, then 34pt when
      // it was floored by it — which put the bar's whole knob range at or above
      // 34 and left "there is too much space under it" unfixable by any
      // setting. The inset is padding around a thin glyph, not a keep-out.
      expect(screenH - bar.bottom, closeTo(kIndicatorKeepOut + 12, 0.5));
      // And it clears the glyph itself, which is the only hard constraint.
      expect(screenH - bar.bottom, greaterThanOrEqualTo(kIndicatorKeepOut));
    });

    testWidgets('is the knob alone where there is no indicator to clear',
        (tester) async {
      final screenH = await pumpNavWithInset(tester, inset: 0);
      final bar = tester.getRect(find.byType(LiquidGlass));
      // Hardware with no indicator has nothing to keep out of, so the knob is
      // the whole gap — which is why it cannot simply be replaced by the inset.
      expect(screenH - bar.bottom, closeTo(12, 0.5));
    });

    testWidgets('clears the whole of an Android button bar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        // 3-button navigation: 48dp of opaque back/home/recents. Floating 12pt
        // into it put the pill on top of the buttons.
        final screenH = await pumpNavWithInset(tester, inset: 48);
        final bar = tester.getRect(find.byType(LiquidGlass));
        expect(screenH - bar.bottom, closeTo(48 + 12, 0.5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('floats into an Android gesture handle like an iPhone one',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final screenH = await pumpNavWithInset(tester, inset: 24);
        final bar = tester.getRect(find.byType(LiquidGlass));
        expect(screenH - bar.bottom, closeTo(kIndicatorKeepOut + 12, 0.5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('navBottomKeepOut', () {
    test('a handle claims only the indicator; buttons claim the inset', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        expect(navBottomKeepOut(0), 0);
        expect(navBottomKeepOut(24), kIndicatorKeepOut);
        expect(navBottomKeepOut(48), 48);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      // iOS never has buttons down there, whatever the inset.
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        expect(navBottomKeepOut(34), kIndicatorKeepOut);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('section clearance rises with the pill over a button bar',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      late double padding;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                padding = sectionBottomPadding(context);
                return const SizedBox();
              },
            ),
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      expect(padding, kFloatingNavClearance + 48 - kIndicatorKeepOut);
    });
  });

  /// The tappable slot for destination [i]. [FocusableTap] is the outermost
  /// per-segment widget, so its rect *is* the segment — which is the point: if
  /// the icon is not centred in this, the bar looks broken.
  Rect slotOf(WidgetTester tester, int i) =>
      tester.getRect(find.byType(FocusableTap).at(i));

  testWidgets('every segment gets an equal slice of the bar', (tester) async {
    await pumpNav(tester);

    final widths = [
      for (var i = 0; i < _navDestinations.length; i++) slotOf(tester, i).width,
    ];
    for (final w in widths) {
      expect(w, closeTo(widths.first, 0.01));
    }

    // And they tile: no gaps, no overlap.
    for (var i = 1; i < _navDestinations.length; i++) {
      expect(
        slotOf(tester, i).left,
        closeTo(slotOf(tester, i - 1).right, 0.01),
      );
    }
  });

  testWidgets('each icon is centred in its own segment', (tester) async {
    await pumpNav(tester);

    for (var i = 0; i < _navDestinations.length; i++) {
      final slot = slotOf(tester, i);
      final icon = tester.getRect(find.byIcon(_navDestinations[i].icon));
      expect(
        icon.center.dx,
        closeTo(slot.center.dx, 0.5),
        reason:
            'destination ${_navDestinations[i].label} is off-centre in its slot; '
            'FocusableTap must not loosen the tight width it is handed',
      );
    }
  });

  testWidgets('each label is centred in its own segment', (tester) async {
    await pumpNav(tester);

    for (var i = 0; i < _navDestinations.length; i++) {
      final slot = slotOf(tester, i);
      final label = tester.getRect(find.text(_navDestinations[i].label));
      expect(label.center.dx, closeTo(slot.center.dx, 0.5));
    }
  });

  testWidgets('the whole slot is tappable, not just the centred content', (
    tester,
  ) async {
    final taps = <HomeSection>[];
    await pumpNav(tester, onSelect: taps.add);

    // The outer edges of each slot were the dead zone: ~14pt on each side of
    // every segment fell through to whatever was behind the bar.
    for (var i = 0; i < _navDestinations.length; i++) {
      final slot = slotOf(tester, i);
      await tester.tapAt(Offset(slot.left + 2, slot.center.dy));
      await tester.tapAt(Offset(slot.right - 2, slot.center.dy));
    }
    await tester.pump();

    expect(
      taps,
      [
        for (final d in _navDestinations) ...[d.section, d.section],
      ],
      reason: 'both outer edges of every segment must select that destination',
    );
  });

  testWidgets('the indicator sits over the active segment', (tester) async {
    for (final d in _navDestinations) {
      await pumpNav(tester, active: d.section);
      final i = _navDestinations.indexOf(d);
      final indicator = tester.getRect(find.byType(FractionallySizedBox));
      expect(
        indicator.center.dx,
        closeTo(slotOf(tester, i).center.dx, 0.5),
        reason: 'indicator is not over ${d.label}',
      );
    }
  });

  testWidgets('the indicator follows the destination under RTL, not the pixel', (
    tester,
  ) async {
    // The Row mirrors under RTL — destination 0 renders on the right — but an
    // absolute `Alignment(x, 0)` does not, so the indicator used to land on the
    // mirrored segment. Assert against the slot, which mirrors with the Row.
    for (final d in _navDestinations) {
      await pumpNav(tester, active: d.section, direction: TextDirection.rtl);
      final i = _navDestinations.indexOf(d);
      final indicator = tester.getRect(find.byType(FractionallySizedBox));
      expect(
        indicator.center.dx,
        closeTo(slotOf(tester, i).center.dx, 0.5),
        reason: 'RTL: indicator is not over ${d.label}',
      );
    }
  });

  testWidgets('the selection pill is inset in its slot, not full-bleed', (
    tester,
  ) async {
    // The reported symptom was "first item too close to the left, last has a
    // lot of space on the right". Equal gaps at both ends of every slot is the
    // invariant that has to hold for that to stop being true.
    for (final d in _navDestinations) {
      await pumpNav(tester, active: d.section);
      final slot = slotOf(tester, _navDestinations.indexOf(d));
      final pill = tester.getRect(find.byKey(navIndicatorKey));

      expect(pill.width, lessThan(slot.width));
      expect(
        pill.left - slot.left,
        closeTo(slot.right - pill.right, 0.01),
        reason: '${d.label}: the pill is not evenly inset in its slot',
      );
    }
  });

  testWidgets('the bar hugs the end pills tighter than it separates them', (
    tester,
  ) async {
    // The end margin is the shell's own padding *plus* the indicator's inset,
    // so holding the two equal made the outer gap as wide as the gap between
    // two pills and left the first and last destinations looking marooned.
    // Only one pill is painted at a time, so measure them a pump apart.
    await pumpNav(tester, active: _navDestinations.first.section);
    final bar = tester.getRect(find.byType(LiquidGlass));
    final first = tester.getRect(find.byKey(navIndicatorKey));

    await pumpNav(tester, active: _navDestinations[1].section);
    final second = tester.getRect(find.byKey(navIndicatorKey));

    final outer = first.left - bar.left;
    final between = second.left - first.right;

    expect(
      outer,
      lessThan(between),
      reason:
          'the bar edge should sit closer to the end pill than two pills '
          'sit to each other, or the ends read as dead space',
    );
    expect(outer, lessThan(8));

    // Symmetric at the far end, measured against the last destination.
    await pumpNav(tester, active: _navDestinations.last.section);
    final last = tester.getRect(find.byKey(navIndicatorKey));
    expect(bar.right - last.right, closeTo(outer, 0.01));
  });

  testWidgets('the bar stays under the clearance every section reserves', (
    tester,
  ) async {
    await pumpNav(tester);
    // kFloatingNavClearance is the bottom padding every scrolling section adds
    // so its last row clears this bar. It was a hand-computed number in a doc
    // comment that had already drifted once; tie it to the real height.
    final bar = tester.getRect(find.byType(LiquidGlass));
    expect(bar.height, lessThan(kFloatingNavClearance));
  });

  testWidgets('a badge hugs its icon instead of floating off to the right', (
    tester,
  ) async {
    await pumpNav(tester, badges: {HomeSection.chat: 3});

    final icon = tester.getRect(find.byIcon(_navDestinations.first.icon));
    final badge = tester.getRect(find.text('3'));

    // The badge overflows its 22pt box on purpose (Clip.none), so check it
    // still lands inside the segment it belongs to.
    expect(badge.right, lessThan(slotOf(tester, 0).right));

    expect(
      badge.left,
      greaterThan(icon.center.dx),
      reason: 'the badge belongs at the icon\'s top-right corner',
    );
    expect(
      badge.left - icon.right,
      lessThan(6),
      reason:
          'the badge was anchored to a 46pt box around a 22pt glyph, leaving a '
          'visible gap between the icon and its own count',
    );
  });
}
