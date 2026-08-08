import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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

/// The bottom nav's *behaviour under a finger*, as opposed to
/// `pill_bottom_nav_layout_test.dart`'s geometry at rest.
///
/// The bar accepts a press that becomes a drag: the selection pill inflates
/// where it already is, then moves by the finger's *travel* — never to the
/// finger — resists past the ends, and commits wherever it is released. None of
/// that is expressible with per-segment tap recognizers, so none of it was
/// checkable before; these tests exist to keep it from quietly regressing back
/// into a row of buttons.
///
/// Two rules for anything added here:
///
///  * **Never `pumpAndSettle` with a pointer still down.** It would settle
///    fine today — the springs stop the ticker even mid-hold — but a future
///    hold that keeps a ticker alive turns that into a ten-minute timeout
///    rather than a failure. Use [_frames] while a gesture is live.
///  * **Assert against measured rects, not points.** Same reason the layout
///    tests do: the invariants here hold at any bar width.
void main() {
  /// Advance the springs by [count] frames of real time.
  ///
  /// `pump(const Duration(milliseconds: 400))` does *not* do this: it produces
  /// one frame, and the ticker treats the first frame of a run as 1/60s no
  /// matter how much wall clock it covers. A single long pump therefore leaves
  /// the pill a sixtieth of a second into a journey, which is a confusing way
  /// to watch a test fail.
  Future<void> frames(WidgetTester tester, [int count = 30]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Widget wrap(
    Widget child, {
    TextDirection direction = TextDirection.ltr,
    bool calm = false,
  }) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Directionality(
          textDirection: direction,
          child: Builder(
            // Reduce motion resolves through MediaQuery — see [MotionScope] —
            // so the override has to sit *inside* MaterialApp's own
            // MediaQuery, and has to copyWith rather than replace it, or the
            // bar's SafeArea and size stop reading the real view and every
            // measurement in here shifts.
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: calm),
              child: Stack(children: [child]),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> pumpNav(
    WidgetTester tester, {
    HomeSection active = HomeSection.chat,
    ValueChanged<HomeSection>? onSelect,
    TextDirection direction = TextDirection.ltr,
    bool calm = false,
  }) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(
        PillBottomNav(
          active: active,
          onSelect: onSelect ?? (_) {},
          badges: const {},
        ),
        direction: direction,
        calm: calm,
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect slotOf(WidgetTester tester, int i) =>
      tester.getRect(find.byType(FocusableTap).at(i));
  Rect pillOf(WidgetTester tester) =>
      tester.getRect(find.byKey(navIndicatorKey));

  testWidgets(
    'a tap still selects, exactly as it did before there was a drag',
    (tester) async {
      final picked = <HomeSection>[];
      await pumpNav(tester, onSelect: picked.add);

      await tester.tapAt(slotOf(tester, 3).center);
      await tester.pumpAndSettle();

      expect(picked, [_navDestinations[3].section]);
      expect(
        pillOf(tester).center.dx,
        closeTo(slotOf(tester, 3).center.dx, 0.5),
        reason: 'the pill should have travelled to the tapped segment',
      );
    },
  );

  testWidgets('a tap pops the pill the way a hold does, and switches instantly',
      (tester) async {
    // The bar used to speak two languages: hold it and the selection was
    // visibly picked up, tap it and the selection merely relocated. A tap now
    // plays the hold's swell on the hold's own spring — half the response,
    // turned around after a fixed dwell — so the two gestures read as one
    // motion at two speeds rather than as two similar-but-different ones.
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);
    final rest = pillOf(tester);
    final target = slotOf(tester, 2);

    await tester.tapAt(target.center);

    expect(
      picked,
      [_navDestinations[2].section],
      reason:
          'not one frame has been pumped yet. onSelect fires straight out of '
          'the pointer-up handler, so the pop decorates an instant switch — '
          'it must never become a gate in front of one',
    );

    // Height is the load-bearing measurement, and segment 2 is deliberately
    // not an end. Neither of the other two things that resize the pill can
    // fake a *taller* pill mid-slide: the wall squash needs an end segment to
    // compress against, and the travel stretch only ever trades height away
    // for length (see `_placed`). So this can only be the pop.
    await frames(tester, 3);
    final popped = pillOf(tester);
    expect(
      popped.height,
      greaterThan(rest.height + 4),
      reason:
          'three frames in, the pill should be visibly mid-pop rather than '
          'sliding across at scale 1.0, which is all a tap used to do',
    );
    expect(
      popped.center.dx,
      greaterThan(rest.center.dx),
      reason: 'and popping *while* it travels, not before it sets off',
    );

    // And out of the way well before the slide lands. "Quickly" is the whole
    // brief: a pop still inflating when the pill arrives would read as the bar
    // being busy rather than as the tab being snappy.
    await frames(tester, 5);
    final settling = pillOf(tester);
    expect(settling.height, lessThan(rest.height + 2));
    expect(
      settling.center.dx,
      lessThan(target.center.dx - 20),
      reason: 'the pop is spent and the pill is still on its way',
    );

    await tester.pumpAndSettle();
    final after = pillOf(tester);
    expect(
      after.height,
      closeTo(rest.height, 0.01),
      reason: 'the scale comes all the way back to 1',
    );
    expect(after.width, closeTo(rest.width, 0.01));
    expect(
      after.center.dx,
      closeTo(target.center.dx, 0.5),
      reason: 'parked on the tapped destination',
    );
  });

  testWidgets('re-tapping the active tab pops it and puts it back exactly', (
    tester,
  ) async {
    // Nothing travels here, which isolates the pop from the slide completely:
    // whatever the pill does it must do about its own centre and undo entirely.
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);
    final rest = pillOf(tester);

    await tester.tapAt(slotOf(tester, 0).center);
    expect(
      picked,
      [_navDestinations[0].section],
      reason: 'a reselect is still an event the shell wants — see tab_reselect',
    );

    await frames(tester, 3);
    final popped = pillOf(tester);
    expect(popped.height, greaterThan(rest.height + 4));
    expect(
      popped.width - rest.width,
      closeTo(popped.height - rest.height, 0.5),
      reason:
          'the pop inherits the hold\'s equal-points swell, so it grows by the '
          'same number of points on every side instead of ballooning sideways',
    );
    expect(
      popped.center,
      within(distance: 0.5, from: rest.center),
      reason: 'about its own centre — the selection has nowhere to go',
    );

    await tester.pumpAndSettle();
    expect(pillOf(tester), rectMoreOrLessEquals(rest, epsilon: 0.01));
  });

  testWidgets('rapid taps across the bar never strand the pill mid-pop', (
    tester,
  ) async {
    // Each tap retargets the spring the previous one is still riding rather
    // than restarting it from a stale zero, and reschedules the one pending
    // turnaround rather than adding a second. Get either wrong and a burst of
    // taps ends with the bar wearing a swollen pill that nothing is coming
    // back to deflate.
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);
    final rest = pillOf(tester);

    for (final i in [1, 2, 3]) {
      await tester.tapAt(slotOf(tester, i).center);
      // Two frames: nowhere near enough for either spring to arrive, so every
      // tap after the first lands on a pill that is already in motion.
      await frames(tester, 2);
    }
    await tester.pumpAndSettle();

    expect(picked, [
      _navDestinations[1].section,
      _navDestinations[2].section,
      _navDestinations[3].section,
    ]);
    final after = pillOf(tester);
    expect(after.width, closeTo(rest.width, 0.01));
    expect(after.height, closeTo(rest.height, 0.01));
    expect(after.center.dx, closeTo(slotOf(tester, 3).center.dx, 0.5));
  });

  testWidgets('reduce motion switches the tab without popping anything', (
    tester,
  ) async {
    // Calm is a code path, not a faster pop: the selection is simply *there*,
    // and the tap still selects. Reduce Motion means stop decorating, never
    // stop responding — see [MotionScope].
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add, calm: true);
    final rest = pillOf(tester);

    await tester.tapAt(slotOf(tester, 2).center);
    await tester.pump(const Duration(milliseconds: 16));

    final after = pillOf(tester);
    expect(picked, [_navDestinations[2].section]);
    expect(after.width, closeTo(rest.width, 0.01), reason: 'no swell');
    expect(after.height, closeTo(rest.height, 0.01));
    expect(
      after.center.dx,
      closeTo(slotOf(tester, 2).center.dx, 0.5),
      reason: 'and no slide either — it is already there',
    );
  });

  testWidgets('switching tabs travels; it does not cut', (tester) async {
    // The bug this guards: a 220ms easeOutCubic has done most of its distance
    // in its first third, so the pill appeared to be *already there* one frame
    // in. A spring leaves visibly, and is still visibly on its way a frame
    // later.
    await pumpNav(tester);
    final from = pillOf(tester).center.dx;

    await tester.pumpWidget(
      wrap(
        PillBottomNav(
          active: _navDestinations.last.section,
          onSelect: (_) {},
          badges: const {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final oneFrameIn = pillOf(tester).center.dx;

    await tester.pumpAndSettle();
    final to = pillOf(tester).center.dx;

    expect(oneFrameIn, greaterThan(from), reason: 'it left');
    expect(
      oneFrameIn,
      lessThan(from + (to - from) * 0.5),
      reason: 'a single frame must not carry it half way across the bar',
    );
    expect(to, closeTo(slotOf(tester, 3).center.dx, 0.5));
  });

  testWidgets('a drag carries the pill and commits where it is released', (
    tester,
  ) async {
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);

    final start = slotOf(tester, 0).center;
    final end = slotOf(tester, 2).center;
    final gesture = await tester.startGesture(start);
    await gesture.moveTo(Offset(end.dx, start.dy));
    await frames(tester);

    expect(
      pillOf(tester).center.dx,
      closeTo(end.dx, 1),
      reason:
          'the pill should be under the finger, not waiting for the release',
    );
    expect(
      picked,
      isEmpty,
      reason: 'a drag in flight must not switch the section out from under it',
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(picked, [_navDestinations[2].section]);
    expect(pillOf(tester).center.dx, closeTo(end.dx, 0.5));
  });

  testWidgets('a drag that turns back commits where it stopped, not where it '
      'went', (tester) async {
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);

    final gesture = await tester.startGesture(slotOf(tester, 0).center);
    await gesture.moveTo(slotOf(tester, 3).center);
    await frames(tester, 8);
    await gesture.moveTo(slotOf(tester, 1).center);
    await frames(tester, 8);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(picked, [_navDestinations[1].section]);
  });

  testWidgets('a hold inflates the pill where it is; it does not fetch it', (
    tester,
  ) async {
    // Pressing a *different* segment and holding must not teleport the
    // selection under the finger. The hold picks up the selection where it
    // already is; the drag is what moves it.
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);
    final home = pillOf(tester);

    final gesture = await tester.startGesture(slotOf(tester, 3).center);
    await tester.pump(const Duration(milliseconds: 260));
    await frames(tester);
    final held = pillOf(tester);

    expect(
      held.center.dx,
      closeTo(home.center.dx, 0.5),
      reason: 'the pill stayed on the active segment and grew about its centre',
    );
    expect(held.width, greaterThan(home.width), reason: 'and grew in place');
    expect(
      held.center.dx,
      lessThan(slotOf(tester, 1).left),
      reason: 'nowhere near the finger, which is three segments away',
    );
    expect(picked, isEmpty, reason: 'nothing is selected until release');

    // Released without ever travelling, a hold means what a tap means.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, [_navDestinations[3].section]);
    expect(pillOf(tester).center.dx, closeTo(slotOf(tester, 3).center.dx, 0.5));
  });

  testWidgets('a drag moves the pill by the finger travel, not to the finger', (
    tester,
  ) async {
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);
    final segment = slotOf(tester, 1).center.dx - slotOf(tester, 0).center.dx;

    // Grab at the far end of the bar and pull one segment's width. The pill is
    // on segment 0 and must end on segment 1 — not on segment 3 where the
    // finger is, and not on the segment the finger ends over.
    final start = slotOf(tester, 3).center;
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 260));
    await gesture.moveTo(Offset(start.dx + segment, start.dy));
    await frames(tester);

    expect(pillOf(tester).center.dx, closeTo(slotOf(tester, 1).center.dx, 1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(picked, [_navDestinations[1].section]);
  });

  testWidgets('holding swells the selection, and releasing shrinks it back', (
    tester,
  ) async {
    await pumpNav(tester);
    final rest = pillOf(tester);

    final gesture = await tester.startGesture(slotOf(tester, 0).center);
    // Past the hold threshold, then long enough for the spring to inflate.
    await tester.pump(const Duration(milliseconds: 260));
    await frames(tester);
    final held = pillOf(tester);

    expect(held.width, greaterThan(rest.width));
    expect(held.height, greaterThan(rest.height));
    expect(
      held.center.dx,
      closeTo(rest.center.dx, 0.5),
      reason:
          'a hold in place inflates the pill about its centre; it does not '
          'drag it',
    );
    expect(
      held.width - rest.width,
      closeTo(held.height - rest.height, 0.5),
      reason:
          'evenly, in every direction — a selection that grows more one way '
          'than another reads as a glitch rather than as a lift. Points, not '
          'ratio: the pill is ~80x50, so the uniform 1.32 factor this replaced '
          'put half again as much swell on the ends as on the top and bottom, '
          'which is the ballooning it looked like',
    );
    expect(
      held.center.dy,
      closeTo(rest.center.dy, 0.5),
      reason: 'and about its centre vertically too',
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      pillOf(tester).height,
      lessThan(held.height),
      reason:
          'a hold released in place still commits like a tap, but it must not '
          'also fire the tap\'s pop: the pill is already at the top of its arc '
          'and already on its way down, and re-inflating it after the finger '
          'has gone reads as the release not taking',
    );
    await tester.pumpAndSettle();

    final after = pillOf(tester);
    expect(after.width, closeTo(rest.width, 0.01));
    expect(after.height, closeTo(rest.height, 0.01));
    expect(after.center.dx, closeTo(rest.center.dx, 0.01));
  });

  testWidgets('a swollen pill grows evenly on every segment, ends included', (
    tester,
  ) async {
    // The first attempt at a big swell anchored the growth to the bar's inner
    // edge on the end segments, so that the pill could not be clipped by the
    // capsule. It could not, and it also visibly lurched sideways as it grew,
    // on exactly the two segments a thumb reaches for most. The pill is painted
    // outside the glass's clip instead, and grows the same way everywhere.
    for (var i = 0; i < _navDestinations.length; i++) {
      await pumpNav(tester, active: _navDestinations[i].section);
      final rest = pillOf(tester);

      final gesture = await tester.startGesture(slotOf(tester, i).center);
      await tester.pump(const Duration(milliseconds: 260));
      await frames(tester);
      final held = pillOf(tester);

      expect(
        held.center,
        within(distance: 0.5, from: rest.center),
        reason: 'segment $i grew off-centre',
      );
      expect(
        held.width - rest.width,
        closeTo(held.height - rest.height, 0.5),
        reason: 'segment $i grew unevenly',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a swollen pill is allowed out of the bar', (tester) async {
    // It is a thing being lifted towards you. Anything inside LiquidGlass is
    // inside its capsule clip, which leaves ~6pt for a swell in a 62pt bar —
    // so the indicator is painted as a sibling of the glass rather than a
    // child, and this is the test that says why.
    await pumpNav(tester);
    final bar = tester.getRect(find.byType(LiquidGlass));

    final gesture = await tester.startGesture(slotOf(tester, 0).center);
    await tester.pump(const Duration(milliseconds: 260));
    await frames(tester);
    final held = pillOf(tester);

    expect(held.top, lessThan(bar.top));
    expect(held.bottom, greaterThan(bar.bottom));

    await gesture.up();
    await tester.pumpAndSettle();
    final rest = pillOf(tester);
    expect(rest.top, greaterThanOrEqualTo(bar.top));
    expect(rest.bottom, lessThanOrEqualTo(bar.bottom));
  });

  testWidgets('pulling past the end squashes the pill against the wall', (
    tester,
  ) async {
    // Not "slides off the end of the bar", which it now physically could: the
    // pull turns into compression instead, which is also what absorbs the
    // settle spring's overshoot when it arrives at an end segment.
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);
    final bar = tester.getRect(find.byType(LiquidGlass));
    final home = pillOf(tester);

    // Hold first and measure that, so what follows isolates the pull from the
    // swell it is necessarily wearing.
    final gesture = await tester.startGesture(slotOf(tester, 0).center);
    await tester.pump(const Duration(milliseconds: 260));
    await frames(tester);
    final held = pillOf(tester);

    await gesture.moveTo(Offset(bar.left - 400, home.center.dy));
    await frames(tester);
    final pulled = pillOf(tester);

    expect(
      pulled.width,
      lessThan(held.width),
      reason: 'it should give, or the end of the bar feels dead',
    );
    expect(
      pulled.height,
      greaterThan(held.height),
      reason:
          'and bulge across as it loses length, like something with a '
          'volume',
    );
    expect(
      pulled.center.dx,
      closeTo(held.center.dx, 1),
      reason: 'it compresses in place; it does not leave the last segment',
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(picked, [_navDestinations.first.section]);
    expect(pillOf(tester).center.dx, closeTo(home.center.dx, 0.5));
    expect(pillOf(tester).width, closeTo(home.width, 0.01));
  });

  testWidgets('a jump to an end segment never overshoots out of the bar', (
    tester,
  ) async {
    // The settle spring overshoots by design, and across the whole bar that is
    // a quarter of a segment of travel arriving at a segment with ~7pt of
    // slack beside it. Watch every frame, not just the resting one.
    await pumpNav(tester, active: _navDestinations.last.section);
    final bar = tester.getRect(find.byType(LiquidGlass));

    await tester.pumpWidget(
      wrap(
        PillBottomNav(
          active: _navDestinations.first.section,
          onSelect: (_) {},
          badges: const {},
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final pill = pillOf(tester);
      expect(pill.left, greaterThanOrEqualTo(bar.left), reason: 'frame $i');
      expect(pill.right, lessThanOrEqualTo(bar.right), reason: 'frame $i');
    }
    await tester.pumpAndSettle();
    expect(pillOf(tester).center.dx, closeTo(slotOf(tester, 0).center.dx, 0.5));
  });

  testWidgets('a drag under RTL follows the finger, not its mirror image', (
    tester,
  ) async {
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add, direction: TextDirection.rtl);

    // Destination 0 renders on the *right* under RTL, so this drag travels
    // leftwards across the screen while moving forwards through the nav order
    // — the exact case an un-mirrored pointer-to-index map gets backwards.
    final gesture = await tester.startGesture(slotOf(tester, 0).center);
    await gesture.moveTo(slotOf(tester, 2).center);
    await frames(tester);

    expect(pillOf(tester).center.dx, closeTo(slotOf(tester, 2).center.dx, 1.5));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(picked, [_navDestinations[2].section]);
  });

  testWidgets('sliding off the bar without taking the pill cancels the tap', (
    tester,
  ) async {
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);
    final bar = tester.getRect(find.byType(LiquidGlass));

    final gesture = await tester.startGesture(slotOf(tester, 0).center);
    // Straight down and out — no horizontal travel, so the pill is never
    // grabbed and this stays an ordinary press that wandered off its button.
    await gesture.moveTo(Offset(slotOf(tester, 0).center.dx, bar.bottom + 120));
    await tester.pump(const Duration(milliseconds: 60));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
    expect(pillOf(tester).center.dx, closeTo(slotOf(tester, 0).center.dx, 0.5));
  });

  testWidgets('a screen reader can still activate a destination', (
    tester,
  ) async {
    // The bar-level Listener is invisible to assistive tech — a VoiceOver
    // activation arrives as a SemanticsAction and never as a pointer — so
    // moving pointer handling off the segments would have silently made the
    // whole nav unusable with a screen reader.
    final handle = tester.ensureSemantics();
    final picked = <HomeSection>[];
    await pumpNav(tester, onSelect: picked.add);

    // Anchored on the icon, not on FocusableTap: the node is created by the
    // Semantics *inside* the wrapper, so looking the wrapper's own element up
    // finds the route above it instead.
    final node = tester.getSemantics(find.byIcon(_navDestinations[2].icon));
    expect(
      node.label,
      _navDestinations[2].label,
      reason: 'exactly once — the visible label merges into this node too',
    );
    expect(node.flagsCollection.isButton, isTrue);
    expect(
      node.flagsCollection.isSelected,
      // Tristate, not bool: "not selected" and "not selectable" are different
      // announcements, and a nav destination is always the former.
      Tristate.isFalse,
      reason: 'chat is the active destination, not this one',
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel(_navDestinations[2].label));
    await tester.pumpAndSettle();

    expect(picked, [_navDestinations[2].section]);
    handle.dispose();
  });

  testWidgets('the label under the pill takes the accent as the pill arrives', (
    tester,
  ) async {
    // The colour used to be a 220ms implicit animation on its own clock, so a
    // slower slide left the destination lit before the pill got there. It is
    // now derived from the pill's real position.
    await pumpNav(tester);
    final theme = BasicTheme.midnight();

    Color labelColor(int i) =>
        tester.widget<Text>(find.text(_navDestinations[i].label)).style!.color!;

    expect(labelColor(0), theme.accent);
    expect(labelColor(1), theme.inkSoft);

    final gesture = await tester.startGesture(slotOf(tester, 0).center);
    await gesture.moveTo(slotOf(tester, 1).center);
    // Two frames in, the pill is somewhere between the two segments — and so,
    // necessarily, are both labels.
    await frames(tester, 2);

    expect(labelColor(0), isNot(theme.accent));
    expect(labelColor(0), isNot(theme.inkSoft));
    expect(labelColor(1), isNot(theme.inkSoft));
    expect(labelColor(1), isNot(theme.accent));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(labelColor(0), theme.inkSoft);
    expect(labelColor(1), theme.accent);
  });
}
