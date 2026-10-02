import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/create_room_sheet.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart' show sentenceCase;

/// What this pins: **the create-room sheet is a sheet, not a floating card.**
///
/// It was wrapped in `Padding(12, 0, 12, 12)` inside a `SafeArea(top: false)`,
/// which is three mistakes in one: `sheetDecoration` rounds its top corners and
/// draws a top border only — it is authored to sit against the bottom of the
/// screen — so floating it left square bottom corners over the scrim and a
/// hairline running across mid-air, with the home indicator's inset and then
/// another 12pt of nothing underneath it. The user's words were "nonsense
/// spaces on left and right and bottom".
///
/// The second half is the one that actually loses work rather than looking
/// wrong. An `isScrollControlled` sheet with an unbounded column does not
/// overflow loudly, it silently clips — and on a short phone with the keyboard
/// up, the thing past the bottom edge is OPEN ROOM.
class _FakeRepo extends Fake implements ChatRepository {}

class _FakeApi extends Fake implements ChatApi {}

void main() {
  Widget host() => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAdaptiveSheet(
                context,
                useSafeArea: true,
                builder: (_) =>
                    CreateRoomSheet(repo: _FakeRepo(), api: _FakeApi()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<Size> open(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return size;
  }

  /// The sheet's own surface — the one `sheetDecoration` paints.
  Finder card() => find.descendant(
    of: find.byType(CreateRoomSheet),
    matching: find.byType(Container),
  );

  testWidgets('runs edge to edge, with nothing beside it', (tester) async {
    final size = await open(tester);
    final rect = tester.getRect(card().first);

    expect(rect.left, 0, reason: 'a 12pt gutter is not a sheet');
    expect(rect.right, size.width);
  });

  testWidgets('reaches the bottom of the screen', (tester) async {
    final size = await open(tester);
    final rect = tester.getRect(card().first);

    // Flush. The surface runs under the home indicator and the CONTENT is what
    // clears it, via the card's own bottom padding — which is the opposite of
    // wrapping the card in a SafeArea and leaving scrim below it.
    expect(rect.bottom, size.height);
  });

  testWidgets('OPEN ROOM is reachable on a short screen', (tester) async {
    // The shape of a small phone with the keyboard up: the fields, both
    // segment pairs and the password row already fill this.
    await open(tester, size: const Size(360, 520));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // The button prints its label in sentence case.
    final cta = find.text(sentenceCase(l10n.createRoomSheetOpenRoomButton));
    await tester.scrollUntilVisible(
      cta,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(cta, findsOneWidget);
  });
}
