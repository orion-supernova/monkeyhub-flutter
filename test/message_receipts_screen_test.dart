import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/message_receipts_screen.dart';
import 'package:monkeyhub/screens/room_items.dart' show transcriptDay;
import 'package:monkeyhub/widgets/sheet_kit.dart' show sentenceCase;
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins is the one piece of judgement on the receipts screen: turning
/// two ROOM-WIDE cursors into a per-person answer about ONE message.
///
/// The server keeps no per-message read row — `schema.ts` rules that fan-out
/// out twice, in as many words — so "who read this" is derived here, and every
/// one of the four answers is a different kind of fact:
///
///   read      their cursor is at or past this message
///   delivered their device has it, they have not looked
///   sent      it has not reached them
///   hidden    they share no cursors at all, so nothing can be said either way
///
/// The last one is the interesting one. A member withholding receipts is
/// ABSENT from both maps rather than sitting at zero in them, and folding that
/// absence into SENT would quietly accuse them of being offline forever.
class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends ChangeNotifier implements ChatRepository {
  _FakeRepo({required this.message, required this.reads, required this.delivers});

  final ChatMessage message;
  final Map<String, DateTime> reads;
  final Map<String, DateTime> delivers;

  @override
  ChatMessage? findMessageInRoom(String roomId, String id) => message;

  @override
  Map<String, DateTime> get roomReadCursors => reads;

  @override
  Map<String, DateTime> get roomDeliveredCursors => delivers;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final sentAt = DateTime(2026, 8, 8, 14, 20);

  final message = ChatMessage(
    id: 'm1',
    roomId: 'r1',
    senderId: 'me',
    senderName: 'Murat',
    content: 'the thing about the thing',
    createdAt: sentAt,
  );

  final people = <ChatUser>[
    ChatUser(id: 'me', username: 'murat', name: 'Murat'),
    ChatUser(id: 'ada', username: 'ada', name: 'Ada'),
    ChatUser(id: 'lin', username: 'lin', name: 'Lin'),
    ChatUser(id: 'kai', username: 'kai', name: 'Kai'),
    ChatUser(id: 'noa', username: 'noa', name: 'Noa'),
  ];

  // ThemeScope wraps MaterialApp rather than sitting inside `home`, matching
  // app.dart and the reaction-details test next door.
  Widget host(ChatRepository repo) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: MessageReceiptsScreen(
            repo: repo,
            api: _FakeApi(),
            roomId: 'r1',
            messageId: 'm1',
            fallbackMessage: message,
            currentUserId: 'me',
            roster: () => people,
            onOpenProfile: (_) {},
          ),
        ),
      );

  testWidgets('each member lands in the bucket their cursors put them in', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeRepo(
      message: message,
      reads: {
        // The viewer's own row always comes back, and is never a receipt.
        'me': sentAt,
        // Read a minute after it was sent.
        'ada': sentAt.add(const Duration(minutes: 1)),
        // Caught up to just BEFORE this message — has not read it.
        'lin': sentAt.subtract(const Duration(minutes: 5)),
      },
      delivers: {
        'me': sentAt,
        'ada': sentAt.add(const Duration(minutes: 1)),
        // On the device, unread.
        'lin': sentAt.add(const Duration(seconds: 3)),
        // Neither cursor has reached the message.
        'kai': sentAt.subtract(const Duration(hours: 2)),
      },
      // 'noa' appears in neither map: receipts withheld.
    )));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // One section per state, in ladder order, and nothing for the viewer.
    expect(find.text(sentenceCase(l10n.messageReceiptsSectionRead)), findsOneWidget);
    expect(find.text(sentenceCase(l10n.messageReceiptsSectionDelivered)), findsOneWidget);
    expect(find.text(sentenceCase(l10n.messageReceiptsSectionSent)), findsOneWidget);
    expect(find.text(sentenceCase(l10n.messageReceiptsSectionHidden)), findsOneWidget);

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Lin'), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);
    expect(find.text('Noa'), findsOneWidget);
    expect(find.text('Murat'), findsNothing, reason: 'your own row is not a receipt');

    // Four other members, one of whom has read it.
    expect(find.text(l10n.messageReceiptsSummary(1, 4)), findsOneWidget);

    // Ada's stamps: the day and the clock are separate strings, deliberately
    // — they are set in different sizes, weights and inks, and one Text
    // carrying "TODAY 14:21" could not be. Two of them, because she both
    // received and read it at 14:21 and each is its own fact.
    expect(find.text('14:21'), findsNWidgets(2));

    // Undated rows say why they are undated instead of showing a blank.
    expect(find.text(sentenceCase(l10n.messageReceiptsStateWaiting)), findsOneWidget);
    expect(find.text(sentenceCase(l10n.messageReceiptsStateHidden)), findsOneWidget);
  });

  testWidgets('a cursor exactly on the message counts as read', (tester) async {
    // The boundary the server's own rule is written on: seen when
    // `lastReadAt >= createdAt`. An off-by-one here reads as a message the
    // recipient is looking at right now still sitting in SENT.
    await tester.pumpWidget(host(_FakeRepo(
      message: message,
      reads: {'me': sentAt, 'ada': sentAt},
      delivers: {'me': sentAt, 'ada': sentAt},
    )));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(sentenceCase(l10n.messageReceiptsSectionRead)), findsOneWidget);
    expect(find.text(sentenceCase(l10n.messageReceiptsSectionDelivered)), findsNothing);
  });

  // The report: "sent and read are different things, I want to see all of it".
  // A reader's row used to show only the read time — the furthest the message
  // had got — and lost the moment it reached their phone.
  testWidgets('a reader keeps their delivery time, each fact labelled', (
    tester,
  ) async {
    await tester.pumpWidget(host(_FakeRepo(
      message: message,
      reads: {
        'me': sentAt,
        'ada': sentAt.add(const Duration(minutes: 15)),
      },
      delivers: {
        'me': sentAt,
        'ada': sentAt.add(const Duration(minutes: 2)),
        'lin': sentAt.add(const Duration(minutes: 4)),
      },
    )));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Ada: delivered 14:22, read 14:35 — both, and both labelled.
    expect(find.text('14:35'), findsOneWidget);
    expect(find.text('14:22'), findsOneWidget);
    expect(find.text(l10n.messageReceiptsStampRead), findsOneWidget);
    // Ada's delivery and Lin's.
    expect(find.text(l10n.messageReceiptsStampDelivered), findsNWidgets(2));
    expect(find.text('14:24'), findsOneWidget);

    // The header counts both: one read, two reached (a reader counts as
    // reached), of four others.
    expect(find.text(l10n.messageReceiptsSummary(1, 4)), findsOneWidget);
    expect(find.text(l10n.messageReceiptsDeliveredSummary(2, 4)),
        findsOneWidget);
    // And the card says when it was sent, in so many words.
    expect(
      find.textContaining('${sentenceCase(l10n.messageReceiptsSentLabel)} · '),
      findsOneWidget,
    );
  });

  testWidgets('a stamp on another day says which day', (tester) async {
    await tester.pumpWidget(host(_FakeRepo(
      message: message,
      reads: {'me': sentAt, 'ada': sentAt.add(const Duration(days: 1))},
      delivers: {'me': sentAt, 'ada': sentAt.add(const Duration(minutes: 1))},
    )));
    await tester.pumpAndSettle();

    // The delivery landed the same day as the send, so it is just a clock;
    // the read did not, so it carries its day.
    final nextDay = DateTime(sentAt.year, sentAt.month, sentAt.day + 1);
    final ctx = tester.element(find.byType(MessageReceiptsScreen));
    expect(find.text(transcriptDay(ctx, nextDay)), findsOneWidget);
    expect(find.text('14:21'), findsOneWidget);
  });

  testWidgets('two empty maps mean "not loaded", not "nobody shares"', (
    tester,
  ) async {
    // The subscription always returns the viewer's own row, so nothing at all
    // is the loading state. Bucketing here would file the whole room under NO
    // RECEIPTS for half a second and then move everyone.
    await tester.pumpWidget(host(_FakeRepo(
      message: message,
      reads: const {},
      delivers: const {},
    )));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text(sentenceCase(l10n.messageReceiptsSectionHidden)), findsNothing);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('a room with nobody else in it says so', (tester) async {
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: MessageReceiptsScreen(
          repo: _FakeRepo(
            message: message,
            reads: {'me': sentAt},
            delivers: {'me': sentAt},
          ),
          api: _FakeApi(),
          roomId: 'r1',
          messageId: 'm1',
          fallbackMessage: message,
          currentUserId: 'me',
          roster: () => [people.first],
          onOpenProfile: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.messageReceiptsEmptyState), findsOneWidget);
  });
}
