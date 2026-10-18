import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/live_calls_store.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_list_row.dart';
import 'package:monkeyhub/widgets/live_call_row.dart';
import 'package:monkeyhub/widgets/room_card.dart';
import 'package:monkeyhub/widgets/room_filter_bar.dart';
import 'package:monkeyhub/widgets/room_grid_tile.dart';

/// The live-call indicator is one component in every chat-list layout, and
/// it fits by dropping parts in every language rather than truncating.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  final started = DateTime.now().subtract(const Duration(minutes: 4));
  final call = LiveRoomCall(
    roomId: 'r1',
    groupCallId: 'g1',
    video: true,
    count: 3,
    mine: false,
    startedAt: started,
  );

  ChatRoom room() => ChatRoom(
        id: 'r1',
        name: 'Weekend Crew',
        createdBy: 'u1',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        isPrivate: true,
        memberCount: 6,
        lastMessage: 'are you driving?',
        lastMessageTime: DateTime.now(),
      );

  Widget host(Widget child, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  /// Unmounts so the glyph's loop and the clock's timer stop with the test.
  Future<void> tidy(WidgetTester tester) async {
    LiveCallsStore.instance.debugShow(const []);
    await tester.pumpWidget(const SizedBox());
  }

  group('fit', () {
    ({bool label, bool people, bool clock}) fit(double w) => LiveCallChip.fit(
          maxWidth: w,
          glyph: 16,
          pad: 8,
          gap: 5,
          label: 80,
          people: 60,
          clock: 36,
          dot: 12,
        );

    test('everything when there is room', () {
      expect(fit(400), (label: true, people: true, clock: true));
    });
    test('the head count goes first', () {
      expect(fit(170), (label: true, people: false, clock: true));
    });
    test('then the label, keeping the clock', () {
      expect(fit(90), (label: false, people: false, clock: true));
    });
    test('the glyph alone at the very least', () {
      expect(fit(40), (label: false, people: false, clock: false));
    });
  });

  testWidgets('fits without overflow in all 12 languages at every width',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final w in const [96.0, 130.0, 170.0, 260.0, 360.0]) {
        await tester.pumpWidget(host(
          SizedBox(
            width: w,
            child: Align(
              alignment: Alignment.centerLeft,
              child: LiveCallChip(call: call),
            ),
          ),
          locale: locale,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$locale at $w');
        final size = tester.getSize(find.byType(LiveCallChip));
        expect(size.width, lessThanOrEqualTo(w), reason: '$locale at $w');
      }
    }
    await tidy(tester);
  });

  // 420 rather than a phone row's ~300: the test font draws every glyph a
  // full em wide, roughly half again what the real face takes.
  testWidgets('Turkish shows the whole label in a row, never "ar..."',
      (tester) async {
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    await tester.pumpWidget(host(
      SizedBox(width: 420, child: Align(
        alignment: Alignment.centerLeft,
        child: LiveCallChip(call: call),
      )),
      locale: const Locale('tr'),
    ));
    await tester.pump();
    expect(find.text(tr.liveCallChipVideo), findsOneWidget);
    await tidy(tester);
  });

  group('every layout shows the call', () {
    for (final (name, build) in <(String, Widget Function(ChatRoom))>[
      ('rows', (r) => ChatListRow(room: r, onTap: () {})),
      ('cards', (r) => RoomCard(room: r, onTap: () {})),
      (
        'grid',
        (r) => SizedBox(
              width: 170,
              height: 160,
              child: RoomGridTile(room: r, onTap: () {}),
            ),
      ),
    ]) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(host(SizedBox(width: 390, child: build(room()))));
        expect(find.byType(LiveCallChip), findsNothing);
        expect(find.byType(LiveCallGlyph), findsNothing,
            reason: 'an idle room runs no glyph ticker');

        LiveCallsStore.instance.debugShow([call]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(find.byType(LiveCallChip), findsOneWidget);
        expect(find.byType(LiveCallHalo), findsOneWidget);
        await tidy(tester);
      });
    }
  });

  group('desktop filter segments', () {
    Future<RoomFilter?> tapLabel(WidgetTester tester, RoomFilter filter,
        String label) async {
      RoomFilter? got;
      await tester.pumpWidget(host(SizedBox(
        width: 360,
        child: RoomFilterSegments(
          filter: filter,
          counts: RoomFacetCounts.projected([room()], RoomFilter.empty),
          onChanged: (f) => got = f,
        ),
      )));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return got;
    }

    testWidgets('a facet toggles on', (tester) async {
      final got = await tapLabel(tester, RoomFilter.empty, 'Unread');
      expect(got?.has(RoomFacet.unread), isTrue);
    });

    testWidgets('All resets', (tester) async {
      final got = await tapLabel(
        tester,
        RoomFilter({RoomFacet.unread, RoomFacet.dms}),
        'All',
      );
      expect(got, isNotNull);
      expect(got!.isEmpty, isTrue);
    });

    testWidgets('every facet is on screen at once, in three groups',
        (tester) async {
      await tester.pumpWidget(host(SizedBox(
        width: 360,
        child: RoomFilterSegments(
          filter: RoomFilter.empty,
          counts: RoomFacetCounts.projected([room()], RoomFilter.empty),
          onChanged: (_) {},
        ),
      )));
      expect(find.byType(SegmentGroup), findsNWidgets(3));
      for (final l in const ['All', 'Unread', 'Mentions', 'Dms', 'Groups']) {
        expect(find.textContaining(RegExp(l, caseSensitive: false)),
            findsWidgets, reason: l);
      }
    });
  });
}
