import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/screens/navigation/section_switcher.dart';

/// What a tab change looks like between the tap and the new section arriving.
///
/// The transition itself is taste, and largely untestable; what is testable —
/// and what actually broke — is everything around it. The first version tore
/// the *outgoing* section's element tree down and rebuilt it from scratch in
/// the middle of the transition, which on a real device reads as a flicker on
/// every tab change. Nothing could have caught that, because the switcher lived
/// inside a shell that needs five backend services to pump. It lives in its own
/// file now, and these are the invariants that keep it honest.
void main() {
  /// Counts how many times each section's State has been *created*. Rebuilds
  /// are free and expected; a second creation means the subtree was thrown
  /// away, and with it that section's scroll offset, controllers and futures.
  final mounts = <String, int>{};

  setUp(mounts.clear);

  Widget wrap(HomeSection section, {String variant = 'midnight'}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(375, 812)),
          child: SectionSwitcher(
            section: section,
            variant: variant,
            child: _Section(section.name, mounts),
          ),
        ),
      );

  Finder sectionFinder(HomeSection s) => find.text(s.name);

  /// The opacity actually being painted for [s] right now.
  double opacityOf(WidgetTester tester, HomeSection s) => tester
      .widget<FadeTransition>(
        find.ancestor(
          of: sectionFinder(s),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets(
    'the leaving section is not rebuilt from scratch mid-transition',
    (tester) async {
      await tester.pumpWidget(wrap(HomeSection.chat));
      expect(mounts, {'chat': 1});

      await tester.pumpWidget(wrap(HomeSection.feed));
      await tester.pump(const Duration(milliseconds: 16));
      expect(mounts, {'chat': 1, 'feed': 1});

      // The shell rebuilds several times during a transition — a badge count
      // arrives, a settings listener fires — and every one of those rebuilds
      // used to hand AnimatedSwitcher a brand new transitionBuilder closure,
      // which made it re-run the builder for the outgoing entry and swap the
      // widget type above it. Rebuild a few times and check nothing was
      // reconstructed.
      for (var i = 0; i < 4; i++) {
        await tester.pumpWidget(wrap(HomeSection.feed));
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        mounts,
        {'chat': 1, 'feed': 1},
        reason:
            'a rebuild during the transition must not remount either section',
      );
      expect(sectionFinder(HomeSection.chat), findsOneWidget);

      await tester.pumpAndSettle();
      expect(sectionFinder(HomeSection.chat), findsNothing);
      expect(mounts, {'chat': 1, 'feed': 1});
    },
  );

  testWidgets('the leaving section stays opaque until the arrival is opaque', (
    tester,
  ) async {
    // Both translucent at once lets the app background show through the
    // overlap. Avoiding that is what allows the arrival to be slow enough to
    // read as a transition at all.
    await tester.pumpWidget(wrap(HomeSection.chat));
    await tester.pumpWidget(wrap(HomeSection.feed));

    var arrivedAt = -1;
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final gone = sectionFinder(HomeSection.chat).evaluate().isEmpty;
      if (gone) {
        expect(
          arrivedAt,
          greaterThan(-1),
          reason:
              'the arriving section must be fully opaque *before* the one '
              'underneath is removed, or the screen jumps brighter as it goes',
        );
        break;
      }
      expect(
        opacityOf(tester, HomeSection.chat),
        1.0,
        reason: 'frame $frame: the leaving section never fades',
      );
      if (arrivedAt < 0 && opacityOf(tester, HomeSection.feed) == 1.0) {
        arrivedAt = frame;
      }
    }
    expect(
      arrivedAt,
      greaterThan(0),
      reason: 'and it did not arrive instantly',
    );
  });

  testWidgets('the arriving section enters from the side it lives on', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(HomeSection.chat));
    await tester.pumpWidget(wrap(HomeSection.settings));
    await tester.pump(const Duration(milliseconds: 16));
    // Settings is last in navOrder, so it comes from the trailing edge.
    final forwards = tester.getTopLeft(sectionFinder(HomeSection.settings)).dx;
    expect(forwards, greaterThan(0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sectionFinder(HomeSection.settings)).dx, 0);

    // ...and back the other way.
    await tester.pumpWidget(wrap(HomeSection.chat));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.getTopLeft(sectionFinder(HomeSection.chat)).dx, lessThan(0));
    await tester.pumpAndSettle();
  });

  testWidgets('a theme change cross-fades in place rather than navigating', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(HomeSection.chat));
    await tester.pumpWidget(wrap(HomeSection.chat, variant: 'cyberpunk'));
    await tester.pump(const Duration(milliseconds: 16));

    // Two chats on screen, and the new one is not sliding: nothing navigated.
    expect(sectionFinder(HomeSection.chat), findsNWidgets(2));
    expect(mounts['chat'], 2);
    for (final dx
        in tester
            .widgetList<SlideTransition>(find.byType(SlideTransition))
            .map((s) => s.position.value.dx)) {
      expect(dx, 0);
    }
    await tester.pumpAndSettle();
  });
}

/// A stand-in for a real section: fills the space, prints its name, and records
/// every time it is constructed from scratch.
class _Section extends StatefulWidget {
  const _Section(this.name, this.mounts);
  final String name;
  final Map<String, int> mounts;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  @override
  void initState() {
    super.initState();
    widget.mounts[widget.name] = (widget.mounts[widget.name] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ColoredBox(color: const Color(0xFF101010), child: Text(widget.name)),
  );
}
