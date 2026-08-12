import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/scheduled_message.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/scheduled_list_sheet.dart';

/// The list of messages waiting to send, and the four things you can do to one.
///
/// The row that matters most here is the FAILED one. A scheduled send is the
/// only path in this app where a refusal arrives with nobody watching: the
/// guard runs days after the message was written, so `scheduledMessages:release`
/// has no client to throw at and writes the reason onto the row instead. If the
/// list rendered that row as an ordinary countdown, the message would simply
/// never arrive and nothing anywhere would say so — which is the failure this
/// whole feature cannot afford.
///
/// The reason is also translated rather than shown raw. `NOT_A_MEMBER` is a
/// wire constant; "You're not in this chat any more." is what the user needs.
/// And `MESSAGE_FAILED` deliberately falls through to the generic sentence,
/// because it is what the backend throws when the OTHER person has blocked this
/// one — telling them that is exactly what `guardOutgoing` refuses to do.
void main() {
  final en = AppLocalizationsEn();
  final controller = ThemeController(BasicTheme.midnight());

  ScheduledMessage msg(
    String id,
    String content, {
    bool pending = true,
    String? failedReason,
    DateTime? sendAt,
  }) =>
      ScheduledMessage(
        id: id,
        roomId: 'r',
        content: content,
        sendAt: sendAt ?? DateTime.now().add(const Duration(hours: 5)),
        createdAt: DateTime.now(),
        pending: pending,
        failedReason: failedReason,
      );

  Widget host(List<ScheduledMessage> rows) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // See schedule_message_sheet_test.dart: the scope has to wrap the
        // Navigator, not sit inside `home`, or the sheet's route has no theme.
        builder: (context, navigator) => ThemeScope(
          controller: controller,
          child: navigator!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showScheduledListSheet(
                context,
                repo: _FakeRepo(rows),
                roomId: 'r',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester, List<ScheduledMessage> rows) async {
    await tester.pumpWidget(host(rows));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('says nothing is waiting when nothing is', (tester) async {
    await open(tester, const []);
    expect(find.text(en.scheduledListEmpty), findsOneWidget);
  });

  testWidgets('lists each queued message with all four actions', (
    tester,
  ) async {
    await open(tester, [msg('s1', 'happy birthday'), msg('s2', 'reminder')]);

    expect(find.text('happy birthday'), findsOneWidget);
    expect(find.text('reminder'), findsOneWidget);
    expect(find.text(en.scheduledListSendNow), findsNWidgets(2));
    expect(find.text(en.scheduledListChangeTime), findsNWidgets(2));
    expect(find.text(en.scheduledListEdit), findsNWidgets(2));
    expect(find.text(en.scheduledListDelete), findsNWidgets(2));
  });

  testWidgets('a pending row says when it sends', (tester) async {
    await open(tester, [msg('s1', 'later')]);
    expect(find.textContaining('Sends '), findsOneWidget);
    expect(find.text(en.scheduledListFailedTitle), findsNothing);
  });

  testWidgets('a failed row says so, in words, and offers a retry', (
    tester,
  ) async {
    await open(tester, [
      msg('s1', 'later', pending: false, failedReason: 'NOT_A_MEMBER'),
    ]);

    expect(find.text(en.scheduledListFailedTitle), findsOneWidget);
    // The reason, translated — never the raw wire constant.
    expect(find.text(en.scheduleErrorNotMember), findsOneWidget);
    expect(find.text('NOT_A_MEMBER'), findsNothing);
    // "Send now" becomes "Try again" — the same button, honestly named.
    expect(find.text(en.scheduledListRetry), findsOneWidget);
    expect(find.text(en.scheduledListSendNow), findsNothing);
  });

  testWidgets('a blocked-by-them failure stays vague', (tester) async {
    // `MESSAGE_FAILED` is what the backend throws when the recipient has
    // blocked the sender. Saying so would leak the block, so it must render as
    // the generic sentence and nothing more specific.
    await open(tester, [
      msg('s1', 'hello', pending: false, failedReason: 'MESSAGE_FAILED'),
    ]);

    expect(find.text(en.scheduleErrorGeneric), findsOneWidget);
    expect(find.text(en.scheduleErrorBlocked), findsNothing);
  });

  testWidgets('an overdue row says it is sending, not a negative countdown', (
    tester,
  ) async {
    await open(tester, [
      msg('s1', 'now', sendAt: DateTime.now().subtract(const Duration(minutes: 2))),
    ]);
    expect(find.text(en.scheduledListSending), findsOneWidget);
  });

  testWidgets('deleting asks the repository to cancel that row', (
    tester,
  ) async {
    final repo = _FakeRepo([msg('s1', 'bye')]);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, navigator) =>
          ThemeScope(controller: controller, child: navigator!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showScheduledListSheet(context, repo: repo, roomId: 'r'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(en.scheduledListDelete));
    await tester.pumpAndSettle();

    expect(repo.cancelled, ['s1']);
  });

  group('scheduleErrorSentence', () {
    testWidgets('maps every code the repository can return', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox.shrink(),
      ));
      final context = tester.element(find.byType(SizedBox));

      expect(scheduleErrorSentence(context, 'SCHEDULE_OUT_OF_RANGE'),
          en.scheduleErrorOutOfRange);
      expect(scheduleErrorSentence(context, 'TOO_MANY_SCHEDULED'),
          en.scheduleErrorTooMany);
      expect(scheduleErrorSentence(context, 'SCHEDULE_NOT_IN_EPHEMERAL'),
          en.scheduleErrorNotInEphemeral);
      expect(scheduleErrorSentence(context, 'NOT_A_MEMBER'),
          en.scheduleErrorNotMember);
      expect(scheduleErrorSentence(context, 'UNBLOCK_FIRST'),
          en.scheduleErrorBlocked);
      // Anything unrecognised — including a future server's new code — gets a
      // sentence rather than leaking a constant into the UI.
      expect(scheduleErrorSentence(context, 'WHAT_IS_THIS'),
          en.scheduleErrorGeneric);
    });
  });
}

/// Real enough to drive the sheet: it is a `ChangeNotifier` because the sheet
/// listens to it, and it records what it was asked to do.
class _FakeRepo extends ChangeNotifier implements ChatRepository {
  _FakeRepo(this._rows);

  List<ScheduledMessage> _rows;
  final cancelled = <String>[];

  @override
  List<ScheduledMessage> scheduledFor(String roomId) => _rows;

  @override
  Future<void> cancelScheduledMessage(String id) async {
    cancelled.add(id);
    _rows = [for (final r in _rows) if (r.id != id) r];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
