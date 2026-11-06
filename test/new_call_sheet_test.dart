import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/calls/new_call_sheet.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_call_log.dart';

/// The new-call sheet: one tap per call, and a list that fills the sheet.
///
/// The first version held the friends in a fixed half-screen box inside a
/// shrink-to-fit sheet, then asked for a second tap on a footer button: the
/// list was cut off mid-row over a band of empty sheet, and the two buttons
/// sat greyed out until you had picked someone.
class _FakeApi extends Fake implements ChatApi {}

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
  });
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<List<(String, CallMediaKind)>> open(
    WidgetTester tester,
    List<ChatUser> friends,
  ) async {
    final started = <(String, CallMediaKind)>[];
    final dir = FakeDirectory(users: friends);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () => showNewCallSheet(
                  context,
                  directory: dir,
                  api: _FakeApi(),
                  onStart: (u, k) => started.add((u.id, k)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return started;
  }

  List<ChatUser> people(int n) => [
        for (var i = 0; i < n; i++) fakeUser('u$i', 'Person $i'),
      ];

  testWidgets('each row calls in one tap: voice, video, or the row itself',
      (tester) async {
    final started = await open(tester, people(3));
    expect(find.text('Voice call'), findsNothing,
        reason: 'no select-then-confirm footer');

    await tester.tap(find.byIcon(CupertinoIcons.videocam_fill).at(1));
    await tester.pumpAndSettle();
    expect(started, [('u1', CallMediaKind.video)]);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.phone_fill).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Person 2'));
    await tester.pumpAndSettle();
    expect(started, [
      ('u1', CallMediaKind.video),
      ('u0', CallMediaKind.audio),
      ('u2', CallMediaKind.audio),
    ]);
  });

  testWidgets('a long list fills the sheet and scrolls to its last friend',
      (tester) async {
    await open(tester, people(30));
    // Far more rows on screen than the old half-height box held.
    final shown = find.textContaining('Person ').evaluate().length;
    expect(shown, greaterThanOrEqualTo(9));
    await tester.scrollUntilVisible(find.text('Person 29'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Person 29'), findsOneWidget);
  });

  testWidgets('the log bot is not offered', (tester) async {
    await open(tester, [
      fakeUser('a', 'Ayla'),
      ChatUser(id: 'bot', username: 'logs', name: 'MH Logs', isSystem: true),
    ]);
    expect(find.text('Ayla'), findsOneWidget);
    expect(find.text('MH Logs'), findsNothing);
  });
}
