import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/feed/point_composer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/text_case.dart';

/// What this pins: you can actually reach ADD POINT.
///
/// The sheet was an unscrollable, unbounded `Column` inside an
/// `isScrollControlled` bottom sheet, which does not overflow loudly — it just
/// clips whatever runs past the viewport. On a short screen, with the keyboard
/// up and a photo attached, the thing that got clipped was the commit button
/// itself, so a point could be composed and never posted. The user's report was
/// "I shared a life point and nothing happened".
///
/// The highlight composer already carries this fix
/// (`ConstrainedBox` + `SingleChildScrollView`); this is the guard that keeps
/// the two in step, since the previous pass fixed one and not the other.
class _FakeChatApi extends Fake implements ChatApi {}

class _FakeFeedApi extends Fake implements FeedApi {}

void main() {
  // ThemeScope sits ABOVE MaterialApp on purpose: the sheet is a route on the
  // app's Navigator, so a scope inside `home` would be out of its reach.
  Widget host() => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showPointComposer(
                context,
                api: _FakeChatApi(),
                feedApi: _FakeFeedApi(),
                userId: 'u1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('ADD POINT is reachable on a short screen', (tester) async {
    // Short enough that the title, the five-category grid and the note field
    // already fill it — the shape of a small phone with the keyboard up.
    tester.view.physicalSize = const Size(360, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The sheet's own scroller, not the desktop popover's: on a compact window
    // `showAdaptiveSheet` goes down the `showModalBottomSheet` path, so any
    // scroller found here is the one this fix added.
    expect(find.byType(SingleChildScrollView), findsWidgets);

    // Reachable — by scrolling if need be, which is exactly what was missing.
    // The button prints its label in sentence case.
    final add = sentenceCase(l10n.pointComposerAdd, languageCode: 'en');
    await tester.scrollUntilVisible(
      find.text(add),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(add), findsOneWidget);
  });
}
