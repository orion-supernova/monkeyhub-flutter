import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/settings_store.dart';
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

  /// A phone, not the 800x600 default. Both views are bounded and scrollable,
  /// so on the default surface the lower half sits below the fold and every
  /// `tap` misses — which says nothing about the sheet and everything about the
  /// viewport.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> open(WidgetTester tester, List<ScheduledMessage> rows) async {
    phone(tester);
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
    phone(tester);
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
    // Asked first, like every delete: nothing has gone yet.
    expect(find.text(en.scheduledListDeleteHeadline), findsOneWidget);
    expect(repo.cancelled, isEmpty);

    await tester.tap(find.text(en.scheduledListDelete).last);
    await tester.pump();
    // The row is dust before it is gone: the cancel waits for it to settle.
    expect(repo.cancelled, isEmpty);
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

  group('indicator preference', () {
    testWidgets('offers all three and persists the choice', (tester) async {
      // The control lives in this sheet rather than in Settings, so this is the
      // only place it can be exercised. Both halves matter: `showsPill` and
      // `showsBadge` are what `room_screen` builds its chrome from, and the
      // liquid style's transcript padding follows `showsPill` — get the mapping
      // wrong and the newest bubble hides under the composer.
      // `SettingsStore`'s setters await `FlutterSecureStorage.write`, and with
      // no platform behind it that future never completes — the first version
      // of this test sat there for the full ten-minute timeout. An in-memory
      // double, the `device_identity_test.dart` pattern.
      FlutterSecureStoragePlatform.instance = _MemoryStorage();
      await open(tester, [msg('s1', 'later')]);

      // The choice lives behind a row now, as its own view — one tap in.
      await tester.tap(find.text(en.scheduledListShowAsRow));
      await tester.pumpAndSettle();

      expect(find.text(en.scheduledIndicatorPill), findsOneWidget);
      expect(find.text(en.scheduledIndicatorBadge), findsOneWidget);
      expect(find.text(en.scheduledIndicatorBoth), findsOneWidget);
      // Each choice explains itself and draws what it does; three words could
      // not say that the badge is invisible until you type.
      expect(find.text(en.scheduledIndicatorBadgeSub), findsOneWidget);

      await tester.tap(find.text(en.scheduledIndicatorBadge));
      await tester.pumpAndSettle();
      expect(SettingsStore.instance.scheduledIndicator,
          ScheduledIndicator.badge);

      await tester.tap(find.text(en.scheduledIndicatorBoth));
      await tester.pumpAndSettle();
      expect(SettingsStore.instance.scheduledIndicator,
          ScheduledIndicator.both);

      // Back — the bar's chevron, the one way back — returns to the list
      // rather than closing the sheet.
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      // The title reads in sentence case; the string is stored in capitals.
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data?.toLowerCase() == en.scheduledListTitle.toLowerCase()),
        findsOneWidget,
      );

      // Put it back, so this test cannot leak into another through the
      // singleton.
      await SettingsStore.instance
          .setScheduledIndicator(ScheduledIndicator.pill);
    });

    test('each choice maps to the chrome it names', () {
      expect(ScheduledIndicator.pill.showsPill, isTrue);
      expect(ScheduledIndicator.pill.showsBadge, isFalse);
      expect(ScheduledIndicator.badge.showsPill, isFalse);
      expect(ScheduledIndicator.badge.showsBadge, isTrue);
      expect(ScheduledIndicator.both.showsPill, isTrue);
      expect(ScheduledIndicator.both.showsBadge, isTrue);
    });

    test('an unknown or absent stored name falls back to the pill', () {
      // The only choice that stands alone — the badge rides on the send button,
      // which does not exist while the composer is empty.
      expect(ScheduledIndicator.parse(null), ScheduledIndicator.pill);
      expect(ScheduledIndicator.parse('nonsense'), ScheduledIndicator.pill);
      expect(ScheduledIndicator.parse('both'), ScheduledIndicator.both);
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

/// In-memory stand-in for the keychain, so `SettingsStore`'s writes complete.
class _MemoryStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> _values = {};

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      _values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async =>
      _values.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _values.clear();

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      _values[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of(_values);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _values[key] = value;
  }
}
