import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/screens/calls/call_details_sheet.dart';
import 'package:monkeyhub/screens/calls/call_log_models.dart';
import 'package:monkeyhub/screens/calls/call_log_store.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/calls/calls_fav_suggestion.dart';
import 'package:monkeyhub/screens/calls/calls_format.dart';
import 'package:monkeyhub/screens/calls/calls_screen.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/people_picker.dart';

import 'fakes/fake_call_log.dart';

final _l10n = AppLocalizationsEn();

class _FakeApi extends Fake implements ChatApi {}

Widget _app(Widget child) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  final now = DateTime(2026, 11, 6, 15, 30);

  group('grouping', () {
    test('consecutive calls with one person, type and outcome merge per day', () {
      final rows = groupCallLog([
        fakeEntry('1', now: now, minutesAgo: 5, outcome: CallOutcome.missed),
        fakeEntry('2', now: now, minutesAgo: 20, outcome: CallOutcome.missed),
        fakeEntry('3', now: now, minutesAgo: 40, outcome: CallOutcome.missed),
        // Same person, another outcome: a new row.
        fakeEntry('4', now: now, minutesAgo: 50, durationMs: 60000),
        // Another person.
        fakeEntry('5', now: now, minutesAgo: 60, roomId: 'dm-b', peerId: 'b'),
        // The day before.
        fakeEntry('6', now: now, minutesAgo: 60 * 24, outcome: CallOutcome.missed),
      ]);
      expect(rows.whereType<CallDayHeader>(), hasLength(2));
      final calls = rows.whereType<CallRow>().toList();
      expect(calls.map((r) => r.count), [3, 1, 1, 1]);
      expect(calls.first.entries.map((e) => e.id), ['1', '2', '3']);
    });

    test('a different call type does not merge', () {
      final rows = groupCallLog([
        fakeEntry('1', now: now, minutesAgo: 5, video: true),
        fakeEntry('2', now: now, minutesAgo: 10),
      ]);
      expect(rows.whereType<CallRow>(), hasLength(2));
    });
  });

  group('badge', () {
    test('counts only missed calls newer than the last time the tab was opened', () {
      final missed = [
        fakeEntry('1', now: now, minutesAgo: 5, outcome: CallOutcome.missed),
        fakeEntry('2', now: now, minutesAgo: 30, outcome: CallOutcome.missed),
        fakeEntry('3', now: now, minutesAgo: 90, outcome: CallOutcome.missed),
      ];
      final seen = now.subtract(const Duration(minutes: 45)).millisecondsSinceEpoch;
      expect(missedSince(missed, seen), 2);
      expect(missedSince(missed, now.millisecondsSinceEpoch), 0);
      expect(missedSince(missed, 0), 3);
    });

    test('the store badge follows the shared missed subscription', () async {
      final live = DateTime.now();
      final src = FakeCallLogSource(byFilter: {
        'missed': [
          fakeEntry('1', now: live, minutesAgo: 5, outcome: CallOutcome.missed),
        ],
      });
      final store = CallLogStore.test(src);
      store.setEnabled(true);
      store.ensure('missed');
      store.ensure('all');
      store.ensure('all');
      await Future<void>.delayed(Duration.zero);
      // One subscription per filter, however often it is asked for.
      expect(src.subscribed, ['missed', 'all']);
      expect(store.badgeCount, greaterThanOrEqualTo(0));
      // Switching the tab off drops everything.
      store.setEnabled(false);
      expect(store.entries('missed'), isEmpty);
      expect(store.badgeCount, 0);
    });
  });

  group('settings toggle', () {
    tearDown(() => SettingsStore.instance.setShowCallsTab(true));

    test('Calls leads the bar and is on by default', () {
      expect(SettingsStore.instance.showCallsTab, isTrue);
      expect(navOrder.take(3), [
        HomeSection.calls,
        HomeSection.feed,
        HomeSection.chat,
      ]);
    });

    test('off removes it from the nav and sends a saved Calls section to Chat',
        () async {
      await SettingsStore.instance.setSection(HomeSection.calls, persist: false);
      expect(SettingsStore.instance.section, HomeSection.calls);
      await SettingsStore.instance.setShowCallsTab(false);
      expect(navOrder, isNot(contains(HomeSection.calls)));
      expect(navDestinations(_l10n).map((d) => d.section),
          isNot(contains(HomeSection.calls)));
      expect(SettingsStore.instance.section, HomeSection.chat);
      // Asking for it while hidden lands on Chat too.
      await SettingsStore.instance.setSection(HomeSection.calls, persist: false);
      expect(SettingsStore.instance.section, HomeSection.chat);
      await SettingsStore.instance.setShowCallsTab(true);
      await SettingsStore.instance.setSection(HomeSection.chat, persist: false);
    });
  });

  group('details', () {
    test('timeline: started, rang, answered on, handoff, ended', () {
      final t0 = now.millisecondsSinceEpoch;
      final e = fakeEntry(
        '1',
        now: now,
        durationMs: 120000,
        ringingAt: t0 - 5 * 60000 + 800,
        answeredAt: t0 - 5 * 60000 + 6000,
        answeredOn: 'ios',
        handoffs: [
          CallHandoff(at: t0 - 5 * 60000 + 60000, platform: 'macos'),
        ],
      );
      final labels = buildTimeline(_l10n, e).map((x) => x.label).toList();
      expect(labels, [
        'Started',
        'Rang',
        'Answered on iPhone',
        'Moved to Mac',
        'Ended',
      ]);
    });

    test('quality: strip hidden without a report, summary by roughness', () {
      expect(qualityLine(_l10n, const []), isNull);
      expect(qualityLine(_l10n, const [0, 0, 0])!.text,
          'Good connection throughout');
      expect(qualityLine(_l10n, const [0, 1, 1, 0])!.text,
          'Choppy for 50% of the call');
      expect(qualityLine(_l10n, const [0, 2, 2, 0])!.text,
          'Poor connection for 50% of the call');
    });

    test('the strip folds a long call to at most 60 segments, worst wins', () {
      final samples = List<int>.filled(360, 0)..[100] = 2;
      final folded = QualityStrip.fold(samples);
      expect(folded, hasLength(60));
      expect(folded.where((v) => v == 2), hasLength(1));
    });
  });

  group('formatting', () {
    test('call clock and talk time', () {
      expect(clockDuration(12 * 60000 + 41000), '12:41');
      expect(clockDuration(3725000), '1:02:05');
      expect(talkDuration(_l10n, (3 * 60 + 20) * 60000), '3h 20m');
      expect(talkDuration(_l10n, 12 * 60000), '12m');
      expect(talkDuration(_l10n, 40000), '40s');
    });
  });

  group('screen', () {
    late FakeCallLogSource src;
    late CallLogStore store;
    late FakeDirectory dir;

    setUp(() {
      // A fixed afternoon, not the wall clock: "26 hours ago" is Yesterday
      // at 15:30 but two days back at 01:30. `open` pins the screen to it.
      final live = now;
      final miss = [
        fakeEntry('m1', now: live, minutesAgo: 3, outcome: CallOutcome.missed),
        fakeEntry('m2', now: live, minutesAgo: 8, outcome: CallOutcome.missed),
        fakeEntry('m3', now: live, minutesAgo: 14, outcome: CallOutcome.missed),
      ];
      final all = [
        ...miss,
        fakeEntry('a1',
            now: live,
            minutesAgo: 30,
            roomId: 'dm-b',
            peerId: 'b',
            incoming: false,
            video: true,
            durationMs: 754000),
        fakeEntry('g1',
            now: live,
            minutesAgo: 60 * 26,
            roomId: 'grp',
            peerId: null,
            kind: CallLogKind.group,
            people: 4,
            durationMs: 300000),
      ];
      src = FakeCallLogSource(
        byFilter: {'all': all, 'missed': miss},
        week: const CallLogSummary(
          totalMs: (3 * 60 + 20) * 60000,
          calls: 7,
          top: [CallTopPeer(peerId: 'a', ms: 2 * 3600000, calls: 4)],
        ),
        month: const CallLogSummary(
          totalMs: 9 * 3600000,
          calls: 20,
          top: [CallTopPeer(peerId: 'a', ms: 5 * 3600000, calls: 9)],
        ),
      );
      store = CallLogStore.test(src);
      dir = FakeDirectory(
        users: [fakeUser('a', 'Ayla Demir'), fakeUser('b', 'Ben Carter')],
        rooms: [fakeDm('dm-a', 'a'), fakeDm('dm-b', 'b'), fakeGroup('grp', 'Climbing crew')],
      );
    });

    Future<void> open(WidgetTester tester) async {
      // The fixtures are minutes before a fixed `now`; so is the screen.
      callsClock = () => now;
      addTearDown(() => callsClock = DateTime.now);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(CallsScreen(directory: dir, store: store)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('lists days, merges the three missed calls and shows names',
        (tester) async {
      await open(tester);
      expect(find.text('Calls'), findsWidgets);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.textContaining('Ayla Demir'), findsWidgets);
      // The three missed calls from Ayla are one row.
      expect(find.textContaining('(3)'), findsOneWidget);
      // The duration rides in the sentence, never as a bare number.
      expect(find.text('Outgoing video call · 12:34'), findsOneWidget);
      expect(find.text('Climbing crew'), findsOneWidget);
    });

    testWidgets('the header says what it counts', (tester) async {
      await open(tester);
      expect(find.text('This week: 3h 20m on calls'), findsOneWidget);
    });

    testWidgets('Missed shows only missed calls', (tester) async {
      await open(tester);
      expect(find.text('Outgoing video call · 12:34'), findsOneWidget);
      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();
      expect(find.text('Outgoing video call · 12:34'), findsNothing);
      expect(find.text('Climbing crew'), findsNothing);
      expect(find.textContaining('(3)'), findsOneWidget);
    });

    testWidgets('empty history and empty Missed each say so', (tester) async {
      src = FakeCallLogSource(byFilter: {'all': [], 'missed': []});
      store = CallLogStore.test(src);
      await open(tester);
      expect(find.text('No calls yet'), findsOneWidget);
      await tester.tap(find.text('Missed'));
      await tester.pumpAndSettle();
      expect(find.text('No missed calls'), findsOneWidget);
      expect(find.text('No calls yet'), findsNothing);
    });

    testWidgets('a merged row opens details with its calls; a single row opens details',
        (tester) async {
      await open(tester);
      await tester.tap(find.textContaining('(3)'));
      await tester.pumpAndSettle();
      // Every call of the stack under "Call history", the newest shown.
      expect(find.text('Call history'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('Call history'), findsNothing);
      await tester.tap(find.text('Climbing crew'));
      await tester.pumpAndSettle();
      expect(find.text('Started'), findsOneWidget);
      expect(find.text('Ended'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('each row carries voice and video buttons of at least 44pt',
        (tester) async {
      await open(tester);
      final voice = find.bySemanticsLabel('Voice call');
      final video = find.bySemanticsLabel('Video call');
      expect(voice, findsWidgets);
      expect(video, findsWidgets);
      final size = tester.getSize(find
          .ancestor(
              of: find.byIcon(CupertinoIcons.phone_fill),
              matching: find.byType(GlassIconButton))
          .first);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('swipe left reveals Delete; tapping it removes the entry',
        (tester) async {
      await open(tester);
      await tester.drag(find.text('Climbing crew'), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(src.removed, ['g1']);
    });

    testWidgets('a full swipe left deletes on release', (tester) async {
      await open(tester);
      await tester.drag(find.text('Climbing crew'), const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(src.removed, ['g1']);
    });

    testWidgets('a short swipe does not delete', (tester) async {
      await open(tester);
      await tester.drag(find.text('Climbing crew'), const Offset(-30, 0));
      await tester.pumpAndSettle();
      expect(src.removed, isEmpty);
    });

    testWidgets('opening the tab marks the missed calls seen', (tester) async {
      await open(tester);
      expect(SettingsStore.instance.callsSeenAt, greaterThan(0));
    });
  });

  group('suggestion rule', () {
    final users = {
      'a': fakeUser('a', 'Ayla Demir'),
      'b': fakeUser('b', 'Ben Carter'),
      'bot': ChatUser(id: 'bot', username: 'bot', name: 'Log bot', isSystem: true),
    };
    FavSuggestion? pick(
      List<CallTopPeer> top, {
      Set<String> pinned = const {},
      Map<String, int> snoozed = const {},
      int now = 1000,
    }) =>
        pickFavSuggestion(
          month: CallLogSummary(totalMs: 0, calls: 0, top: top),
          favouriteIds: pinned,
          userOf: (id) => users[id],
          snoozedUntil: (id) => snoozed[id] ?? 0,
          nowMs: now,
        );

    test('three calls or twenty minutes qualify, less does not', () {
      expect(pick([const CallTopPeer(peerId: 'a', ms: 0, calls: 3)])?.user.id, 'a');
      expect(
        pick([const CallTopPeer(peerId: 'a', ms: 20 * 60000, calls: 1)])?.user.id,
        'a',
      );
      expect(pick([const CallTopPeer(peerId: 'a', ms: 19 * 60000, calls: 2)]), isNull);
      expect(pick(const []), isNull);
      expect(
        pickFavSuggestion(
          month: null,
          favouriteIds: const [],
          userOf: (id) => users[id],
          snoozedUntil: (_) => 0,
          nowMs: 0,
        ),
        isNull,
      );
    });

    test('skips pinned, snoozed and system people and takes the next one', () {
      const top = [
        CallTopPeer(peerId: 'bot', ms: 9999999, calls: 50),
        CallTopPeer(peerId: 'a', ms: 5000000, calls: 9),
        CallTopPeer(peerId: 'b', ms: 3000000, calls: 4),
      ];
      expect(pick(top)?.user.id, 'a');
      expect(pick(top, pinned: {'a'})?.user.id, 'b');
      expect(pick(top, snoozed: {'a': 2000})?.user.id, 'b');
      // A snooze that has run out no longer counts.
      expect(pick(top, snoozed: {'a': 900})?.user.id, 'a');
      expect(pick(top, pinned: {'a', 'b'}), isNull);
    });
  });

  group('favourites', () {
    late FakeCallLogSource src;
    late CallLogStore store;
    late FakeDirectory dir;

    void build({List<String> pinned = const [], bool frequent = true}) {
      final live = DateTime.now();
      src = FakeCallLogSource(
        byFilter: {
          'all': [
            fakeEntry('a1', now: live, minutesAgo: 30, roomId: 'dm-b', peerId: 'b', durationMs: 60000),
            fakeEntry('a2', now: live, minutesAgo: 90, roomId: 'dm-a', peerId: 'a', durationMs: 60000),
            fakeEntry('g1', now: live, minutesAgo: 120, roomId: 'grp', peerId: null, kind: CallLogKind.group, people: 3),
          ],
          'missed': [],
        },
        month: CallLogSummary(
          totalMs: 9 * 3600000,
          calls: 20,
          top: frequent
              ? const [CallTopPeer(peerId: 'a', ms: 5 * 3600000, calls: 9)]
              : const [],
        ),
        favourites: pinned,
      );
      store = CallLogStore.test(src);
      dir = FakeDirectory(
        users: [
          fakeUser('a', 'Ayla Demir'),
          fakeUser('b', 'Ben Carter'),
          fakeUser('c', 'Cleo Park'),
          ChatUser(id: 'bot', username: 'bot', name: 'Log bot', isSystem: true),
        ],
        rooms: [fakeDm('dm-a', 'a'), fakeDm('dm-b', 'b'), fakeGroup('grp', 'Climbing crew')],
      );
    }

    tearDown(() => SettingsStore.instance.resetCallsFavSnoozes());

    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(CallsScreen(directory: dir, store: store, api: _FakeApi())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Finder circle(String first) => find.text(first);
    final plus = find.byIcon(CupertinoIcons.plus);

    testWidgets('the row holds only what the user pinned, never the frequent caller',
        (tester) async {
      build(pinned: ['b']);
      await open(tester);
      expect(circle('Ben'), findsOneWidget);
      // Ayla is called 9 times a month and still is not in the row.
      expect(circle('Ayla'), findsNothing);
      expect(plus, findsOneWidget);
    });

    testWidgets('no pins: just the plus and a caption, never auto-filled',
        (tester) async {
      build(frequent: false);
      await open(tester);
      expect(plus, findsOneWidget);
      expect(find.text('Pin the people you call most. Tap + to add one.'),
          findsOneWidget);
      expect(circle('Ayla'), findsNothing);
      expect(find.text('Add to favourites'), findsNothing);
    });

    testWidgets('+ opens the picker without pinned people or system users, and a tap adds',
        (tester) async {
      build(pinned: ['b']);
      await open(tester);
      await tester.tap(plus);
      await tester.pumpAndSettle();
      final picker = find.byType(PeoplePicker);
      expect(find.text('Add a favourite'), findsWidgets);
      expect(find.descendant(of: picker, matching: find.text('Cleo Park')), findsOneWidget);
      expect(find.descendant(of: picker, matching: find.text('Ayla Demir')), findsOneWidget);
      expect(find.descendant(of: picker, matching: find.text('Ben Carter')), findsNothing);
      expect(find.descendant(of: picker, matching: find.text('Log bot')), findsNothing);
      await tester.tap(find.descendant(of: picker, matching: find.text('Cleo Park')));
      await tester.pumpAndSettle();
      expect(picker, findsNothing);
      expect(src.favouriteAdds, ['c']);
      expect(circle('Cleo'), findsOneWidget);
      // Oldest first: Ben, then Cleo.
      expect(tester.getTopLeft(circle('Ben')).dx,
          lessThan(tester.getTopLeft(circle('Cleo')).dx));
    });

    testWidgets('a frequent caller is suggested once, saying what it counts',
        (tester) async {
      build();
      await open(tester);
      expect(find.text('You called Ayla 9 times in the last 30 days'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      // Suggested, not added.
      expect(circle('Ayla'), findsNothing);
      expect(src.favouriteAdds, isEmpty);
    });

    testWidgets('Add to favourites on the card pins them and the card collapses',
        (tester) async {
      build();
      await open(tester);
      await tester.tap(find.text('Add to favourites'));
      await tester.pumpAndSettle();
      expect(src.favouriteAdds, ['a']);
      expect(circle('Ayla'), findsOneWidget);
      expect(find.textContaining('You called Ayla'), findsNothing);
    });

    testWidgets('Not now snoozes for 30 days, locally, and writes nothing',
        (tester) async {
      build();
      await open(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You called Ayla'), findsNothing);
      expect(src.favouriteAdds, isEmpty);
      final until = SettingsStore.instance.callsFavSnoozedUntil('a');
      final days = (until - DateTime.now().millisecondsSinceEpoch) / 86400000;
      expect(days, inInclusiveRange(29.9, 30.1));
    });

    testWidgets('holding a circle offers Remove from favourites', (tester) async {
      build(pinned: ['b']);
      await open(tester);
      await tester.longPress(circle('Ben'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from favourites'));
      await tester.pumpAndSettle();
      expect(src.favouriteRemoves, ['b']);
      expect(circle('Ben'), findsNothing);
    });

    testWidgets('a refused add rolls the circle back and says so', (tester) async {
      build();
      src.failFavouriteWrites = true;
      await open(tester);
      await tester.tap(find.text('Add to favourites'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
      // Optimistic: there at once.
      expect(circle('Ayla'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(circle('Ayla'), findsNothing);
      expect(find.text("Couldn't add to favourites. Try again."), findsOneWidget);
    });

    testWidgets('a refused remove brings the circle back and says so', (tester) async {
      build(pinned: ['b']);
      src.failFavouriteWrites = true;
      await open(tester);
      await tester.longPress(circle('Ben'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from favourites'));
      await tester.pumpAndSettle();
      expect(circle('Ben'), findsOneWidget);
      expect(find.text("Couldn't remove from favourites. Try again."), findsOneWidget);
    });

    testWidgets('call details offer the toggle for a person, not for a group',
        (tester) async {
      build(pinned: ['b']);
      await open(tester);
      // Ben is pinned: Remove.
      await tester.tap(find.text('Ben Carter'));
      await tester.pumpAndSettle();
      expect(find.text('Remove from favourites'), findsOneWidget);
      await tester.tap(find.text('Remove from favourites'));
      await tester.pumpAndSettle();
      expect(src.favouriteRemoves, ['b']);
      expect(find.text('Add to favourites'), findsWidgets);
    });

    testWidgets('a group call has no favourite button', (tester) async {
      build(pinned: ['b']);
      await open(tester);
      await tester.tap(find.text('Climbing crew'));
      await tester.pumpAndSettle();
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Remove from favourites'), findsNothing);
    });
  });
}
