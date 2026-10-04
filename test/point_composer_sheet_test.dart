import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/feed/point_composer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

/// The point composer's two bugs from the user's notes (§F1/§E of the
/// round-2 spec): "it cuts under the notch / Dynamic Island" and "I can not
/// close it by swiping down". Pinned on an iPhone 16 Pro's geometry, with the
/// keyboard up — which is the state the composer opens in.
class _FakeChatApi extends Fake implements ChatApi {}

class _FakeFeedApi extends Fake implements FeedApi {}

const _safeTop = 59.0;
const _keyboard = 336.0;
const _screen = Size(393, 852);

Widget _host() => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
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

void main() {
  Future<AppLocalizations> open(WidgetTester tester, {bool keyboard = true}) async {
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: _safeTop, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: _safeTop, bottom: 34);
    if (keyboard) {
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
    }
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('with the keyboard up the sheet stays below the island and the '
      'button sits above the keyboard', (tester) async {
    final l10n = await open(tester);

    final bar = tester.getRect(find.byType(SheetBar));
    expect(bar.top, greaterThanOrEqualTo(_safeTop + 8 - 0.5),
        reason: 'the bar must clear the Dynamic Island');

    final button = tester.getRect(
      find.widgetWithText(SheetActionButton, l10n.pointComposerPickFirst),
    );
    expect(button.bottom, lessThanOrEqualTo(_screen.height - _keyboard),
        reason: 'the commit button must ride above the keyboard');
    // No dead home-indicator band stacked on the keyboard.
    expect(button.bottom, greaterThan(_screen.height - _keyboard - 40));
  });

  testWidgets('the button says what is missing until a kind is picked', (
    tester,
  ) async {
    final l10n = await open(tester, keyboard: false);
    expect(find.text(l10n.pointComposerPickFirst), findsOneWidget);
    await tester.tap(find.text(l10n.momentTagJinx).first);
    await tester.pump();
    expect(find.text(l10n.pointComposerPickFirst), findsNothing);
    expect(find.text(l10n.pointComposerAdd), findsOneWidget);
  });

  testWidgets('a pull down on the body closes it', (tester) async {
    final l10n = await open(tester, keyboard: false);
    expect(find.text(l10n.pointComposerTitle), findsOneWidget);

    // Grab the grid — the body, not the handle or the bar.
    await tester.fling(
      find.text(l10n.momentTagJinx).first,
      const Offset(0, 300),
      1500,
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.pointComposerTitle), findsNothing);
  });

  testWidgets('a short slow pull springs back', (tester) async {
    final l10n = await open(tester, keyboard: false);
    await tester.timedDrag(
      find.text(l10n.momentTagJinx).first,
      const Offset(0, 40),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.pointComposerTitle), findsOneWidget);
  });
}
