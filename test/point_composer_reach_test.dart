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

    // The commit button is the sheet's pinned footer now (§F1): on screen
    // from the first frame, with no scrolling at all, while the body above
    // it scrolls. It reads "Pick one above first" until a kind is chosen.
    final label = sentenceCase(l10n.pointComposerPickFirst, languageCode: 'en');
    expect(find.text(label), findsOneWidget);
    final button = tester.getRect(find.text(label));
    expect(button.top, greaterThan(0));
    expect(button.bottom, lessThanOrEqualTo(520));

    // The body still scrolls — the grid and the field do not fit 520pt.
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
