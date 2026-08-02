import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/keyboard/focusable_tap.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/screens/navigation/pill_bottom_nav.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

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
  Widget wrap(
    Widget child, {
    TextDirection direction = TextDirection.ltr,
  }) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
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

  /// The tappable slot for destination [i]. [FocusableTap] is the outermost
  /// per-segment widget, so its rect *is* the segment — which is the point: if
  /// the icon is not centred in this, the bar looks broken.
  Rect slotOf(WidgetTester tester, int i) =>
      tester.getRect(find.byType(FocusableTap).at(i));

  testWidgets('every segment gets an equal slice of the bar', (tester) async {
    await pumpNav(tester);

    final widths = [
      for (var i = 0; i < navDestinations.length; i++) slotOf(tester, i).width,
    ];
    for (final w in widths) {
      expect(w, closeTo(widths.first, 0.01));
    }

    // And they tile: no gaps, no overlap.
    for (var i = 1; i < navDestinations.length; i++) {
      expect(slotOf(tester, i).left, closeTo(slotOf(tester, i - 1).right, 0.01));
    }
  });

  testWidgets('each icon is centred in its own segment', (tester) async {
    await pumpNav(tester);

    for (var i = 0; i < navDestinations.length; i++) {
      final slot = slotOf(tester, i);
      final icon = tester.getRect(find.byIcon(navDestinations[i].icon));
      expect(
        icon.center.dx,
        closeTo(slot.center.dx, 0.5),
        reason:
            'destination ${navDestinations[i].label} is off-centre in its slot; '
            'FocusableTap must not loosen the tight width it is handed',
      );
    }
  });

  testWidgets('each label is centred in its own segment', (tester) async {
    await pumpNav(tester);

    for (var i = 0; i < navDestinations.length; i++) {
      final slot = slotOf(tester, i);
      final label = tester.getRect(find.text(navDestinations[i].label));
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
    for (var i = 0; i < navDestinations.length; i++) {
      final slot = slotOf(tester, i);
      await tester.tapAt(Offset(slot.left + 2, slot.center.dy));
      await tester.tapAt(Offset(slot.right - 2, slot.center.dy));
    }
    await tester.pump();

    expect(
      taps,
      [for (final d in navDestinations) ...[d.section, d.section]],
      reason: 'both outer edges of every segment must select that destination',
    );
  });

  testWidgets('the indicator sits over the active segment', (tester) async {
    for (final d in navDestinations) {
      await pumpNav(tester, active: d.section);
      final i = navDestinations.indexOf(d);
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
    for (final d in navDestinations) {
      await pumpNav(
        tester,
        active: d.section,
        direction: TextDirection.rtl,
      );
      final i = navDestinations.indexOf(d);
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
    for (final d in navDestinations) {
      await pumpNav(tester, active: d.section);
      final slot = slotOf(tester, navDestinations.indexOf(d));
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
    await pumpNav(tester, active: navDestinations.first.section);
    final bar = tester.getRect(find.byType(LiquidGlass));
    final first = tester.getRect(find.byKey(navIndicatorKey));

    await pumpNav(tester, active: navDestinations[1].section);
    final second = tester.getRect(find.byKey(navIndicatorKey));

    final outer = first.left - bar.left;
    final between = second.left - first.right;

    expect(
      outer,
      lessThan(between),
      reason: 'the bar edge should sit closer to the end pill than two pills '
          'sit to each other, or the ends read as dead space',
    );
    expect(outer, lessThan(8));

    // Symmetric at the far end, measured against the last destination.
    await pumpNav(tester, active: navDestinations.last.section);
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

    final icon = tester.getRect(find.byIcon(navDestinations.first.icon));
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
