import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/reaction_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins: you can get to a specific emoji without scrolling to it.
///
/// The sheet used to pass `BottomActionBarConfig(enabled: false)`, and that bar
/// is the only thing in `emoji_picker_flutter` that opens the search view — so
/// the sheet's own doc comment promised search while offering none, and the
/// only way to reach any of ~1,900 emoji was dragging through an 8-column grid.
/// A config flag flipped back the other way would restore that silently, hence
/// a test that goes through the UI rather than asserting on the config.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ThemeScope wraps MaterialApp rather than sitting inside `home`, matching
  // app.dart — sheets build in the Navigator's overlay, above any scope nested
  // under it.
  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  testWidgets('search is reachable and finds an emoji the old set lacked',
      (tester) async {
    await tester.pumpWidget(host(const ReactionPickerSheet()));
    await tester.pumpAndSettle();

    // The resting bar under the grid. No TextField yet — tapping it is what
    // swaps the whole picker for the search view.
    expect(find.text('search emoji'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('search emoji'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);

    // 🐦‍🔥 is Unicode 15.1 — absent from the package's bundled set entirely, so
    // this fails on both halves of the fix at once.
    await tester.enterText(find.byType(TextField), 'phoenix');
    await tester.pumpAndSettle();

    expect(find.text('🐦‍🔥'), findsOneWidget);
  });

  testWidgets('the picker lays out without overflowing its sheet',
      (tester) async {
    // The search bar is new height inside a fixed-height picker. Flutter only
    // reports overflow as a rendering error, which a test that just looks for
    // widgets would sail straight past.
    await tester.pumpWidget(host(const ReactionPickerSheet()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a query survives the keyboard sliding up under it',
      (tester) async {
    // Opening search opens the keyboard, so the sheet rebuilds on every frame
    // of that animation with a different bottom inset — and `EmojiPicker`
    // reloads itself from scratch whenever its `Config` compares unequal
    // between builds. Results computed before the animation finished have to
    // still be on screen after it.
    var inset = 0.0;
    late StateSetter setInset;

    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            setInset = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: EdgeInsets.only(bottom: inset),
              ),
              child: const ReactionPickerSheet(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('search emoji'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'phoenix');
    await tester.pumpAndSettle();
    expect(find.text('🐦‍🔥'), findsOneWidget);

    // Walk the inset up the way a keyboard animation would.
    for (final step in [40.0, 120.0, 240.0, 336.0]) {
      setInset(() => inset = step);
      await tester.pump();
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'search field disappeared at inset $step',
      );
      expect(
        find.text('🐦‍🔥'),
        findsOneWidget,
        reason: 'results were dropped at inset $step',
      );
    }

    await tester.pumpAndSettle();
    expect(find.text('phoenix'), findsOneWidget);
    expect(find.text('🐦‍🔥'), findsOneWidget);
  });

  testWidgets('the picker gives back the space the keyboard takes',
      (tester) async {
    // The regression this catches is only reachable now that the sheet has a
    // text field in it: the whole sheet is lifted by the keyboard's height,
    // so a picker sized off the *screen* is suddenly taller than what is left
    // above it. On a 640pt-tall test view a 336pt keyboard leaves 304.
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: const EdgeInsets.only(bottom: 336),
            ),
            child: const ReactionPickerSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
