import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/search_field.dart';

/// What this pins: **the one search bar, and the flight into it.**
///
/// Three screens drew their own bar before [SearchField] existed and had
/// already drifted — one a pill, one a rounded box, one with no way to clear
/// it. The tests below cover the two things that made a shared widget worth
/// having: a clear button that behaves the same everywhere, and a flight out
/// of Discover's door.
///
/// That flight is a re-run. It shipped once as a plain [Hero], overflowed on
/// every frame, and was removed — a default shuttle draws the *destination's*
/// child at every intermediate size, so a two-line card's text was being asked
/// to fit a box collapsing toward a one-line field. `overflows going the other
/// way` is the guard against writing that bug a second time: a Flutter
/// overflow reports through `FlutterError`, which fails a widget test whether
/// or not anyone looks for it.
void main() {
  const doorTag = 'search-door-people';
  const doorTitle = 'find people';

  // ThemeScope sits ABOVE the MaterialApp, as `app.dart` builds it — a hero's
  // shuttle is built in the navigator's overlay, so a scope nested under
  // `home` would leave it with no theme to read.
  Widget host(Widget home) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Widget bar(
    TextEditingController c, {
    ValueChanged<String>? onChanged,
    VoidCallback? onClear,
    bool autofocus = false,
    Object? heroTag,
  }) => Scaffold(
    body: SafeArea(
      child: SearchField(
        controller: c,
        hintText: 'search people…',
        onChanged: onChanged ?? (_) {},
        onClear: onClear,
        autofocus: autofocus,
        heroTag: heroTag,
      ),
    ),
  );

  /// Discover's door, at its real geometry: a card two lines of text tall,
  /// which is the shape that broke the first attempt at this flight.
  Widget door(VoidCallback onTap) => Scaffold(
    body: SafeArea(
      child: GestureDetector(
        onTap: onTap,
        child: const SearchFieldHero(
          tag: doorTag,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: searchDoorHPadding,
              vertical: 12,
            ),
            child: Row(
              children: [
                SizedBox(width: 36, height: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doorTitle),
                      SizedBox(height: 2),
                      Text('by username'),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Icon(CupertinoIcons.search, size: searchFieldIconSize),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  group('the bar', () {
    testWidgets('the clear button appears only once there is text', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(host(bar(c)));

      final clear = find.byIcon(CupertinoIcons.xmark_circle_fill);
      expect(
        find.byIcon(CupertinoIcons.search),
        findsOneWidget,
        reason: 'the magnifier is always there',
      );
      expect(clear, findsNothing, reason: 'nothing to clear yet');

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump();
      expect(clear, findsOneWidget);

      c.clear();
      await tester.pump();
      expect(clear, findsNothing);
    });

    testWidgets('clearing empties the field and reports an empty query', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      String? reported;
      await tester.pumpWidget(host(bar(c, onChanged: (v) => reported = v)));

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump();
      expect(reported, 'ada');

      // The default clear — the one a caller gets without writing anything.
      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await tester.pump();

      expect(c.text, isEmpty);
      expect(
        reported,
        isEmpty,
        reason: 'a caller filtering on the query has to hear about the reset',
      );
    });

    testWidgets("a caller's own clear replaces the default entirely", (
      tester,
    ) async {
      final c = TextEditingController(text: 'ada');
      addTearDown(c.dispose);
      var custom = 0;
      var changed = 0;
      await tester.pumpWidget(
        host(bar(c, onChanged: (_) => changed++, onClear: () => custom++)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
      await tester.pump();

      expect(custom, 1);
      expect(
        changed,
        0,
        reason: 'the caller owns what clearing means — including the reporting',
      );
    });
  });

  group('one pill', () {
    testWidgets('field and door are the same 40pt box, glyph at the same x', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  SearchField(
                    key: const ValueKey('field'),
                    controller: c,
                    hintText: 'Search people',
                    onChanged: (_) {},
                    showCancel: false,
                  ),
                  SearchField.door(
                    key: const ValueKey('door'),
                    hint: 'Search people',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final field = tester.getSize(find.byKey(const ValueKey('field')));
      final door = tester.getSize(find.byKey(const ValueKey('door')));
      expect(field.height, searchFieldHeight);
      expect(door, field);
      final glyphs = find.byIcon(CupertinoIcons.search);
      expect(
        tester.getTopLeft(glyphs.at(0)).dx,
        tester.getTopLeft(glyphs.at(1)).dx,
      );
    });

    testWidgets('Cancel slides in on focus and clears, unfocuses, reports', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      var cancelled = 0;
      String? reported;
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SafeArea(
              child: SearchField(
                controller: c,
                hintText: 'Search settings',
                onChanged: (v) => reported = v,
                onCancel: () => cancelled++,
              ),
            ),
          ),
        ),
      );
      final cancel = find.byIcon(CupertinoIcons.xmark);
      expect(cancel, findsNothing, reason: 'idle: no Cancel');

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pumpAndSettle();
      expect(cancel, findsOneWidget);
      expect(
        find.text('Cancel'),
        findsNothing,
        reason: 'exit search uses an icon with a localized semantic label',
      );

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(c.text, isEmpty);
      expect(reported, isEmpty);
      expect(cancelled, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isFalse,
      );
      expect(cancel, findsNothing);
    });

    testWidgets('inside a sheet (showCancel: false) there is no Cancel', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Scaffold(
            body: SafeArea(
              child: SearchField(
                controller: c,
                hintText: 'Search',
                onChanged: (_) {},
                showCancel: false,
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('the flight', () {
    testWidgets('the door morphs into the bar without overflowing', (
      tester,
    ) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => door(
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => bar(c, autofocus: true, heroTag: doorTag),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text(doorTitle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      // A hero in the air takes its child out of BOTH routes and flies a
      // shuttle in the overlay instead. The door's own text being gone is the
      // signal that this is a real flight and not a plain page transition.
      expect(
        find.text(doorTitle),
        findsNothing,
        reason: 'the door is mid-air, not sitting under the incoming route',
      );

      // Every frame of the morph, at the size where the old plain Hero blew up.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('overflows going the other way either', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => door(
              () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => bar(c, autofocus: true, heroTag: doorTag),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(doorTitle));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(SearchField))).pop();
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      expect(find.text(doorTitle), findsOneWidget);
    });

    testWidgets('the keyboard waits for the screen to arrive', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => bar(c, autofocus: true)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final field = find.byType(TextField);
      expect(
        tester.widget<TextField>(field).focusNode?.hasFocus,
        isFalse,
        reason:
            'a keyboard rising through a page still sliding in is two '
            'animations arguing over the same 300ms',
      );

      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);
    });
  });
}
