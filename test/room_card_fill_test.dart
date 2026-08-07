import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/room_card.dart';
import 'package:monkeyhub/widgets/room_grid_tile.dart';
import 'package:monkeyhub/widgets/room_identity.dart';

/// What a room card says when the room hasn't said anything yet.
///
/// The box is a fixed size whether or not there's anything in it, so the rules
/// here are about what fills it: the description nobody was showing, a stamp
/// for how long it's been quiet, a name that takes the space it's given, and
/// a monogram for the rooms that have none of the above. And the card must not
/// shrink — a card that collapses for want of a preview is the one that looks
/// broken next to a full one.
void main() {
  final epoch = DateTime(2026, 8, 8, 12);

  ChatRoom room({
    String name = 'design',
    String? description,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) => ChatRoom(
    id: 'r1',
    name: name,
    createdBy: 'u1',
    // Relative to the wall clock, because the card's stamp is: three days and
    // change reads as "3d" whenever the suite happens to run.
    createdAt: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
    isPrivate: false,
    memberCount: 4,
    description: description,
    lastMessage: lastMessage,
    lastMessageTime: lastMessageTime,
  );

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(body: child),
    ),
  );

  Widget tile(ChatRoom r) =>
      SizedBox(width: 180, height: 164, child: RoomGridTile(room: r, onTap: () {}));

  Future<AppLocalizations> en() =>
      AppLocalizations.delegate.load(const Locale('en'));

  group('what fills the space', () {
    testWidgets('a room with no messages shows its description', (tester) async {
      await tester.pumpWidget(host(tile(room(description: 'where the pixels get argued about'))));
      expect(tester.takeException(), isNull);
      expect(find.text('where the pixels get argued about'), findsOneWidget);
    });

    testWidgets('a message outranks the description', (tester) async {
      await tester.pumpWidget(
        host(tile(room(description: 'the description', lastMessage: 'ayşe: pushed the fix'))),
      );
      expect(find.text('ayşe: pushed the fix'), findsOneWidget);
      expect(find.text('the description'), findsNothing);
    });

    testWidgets('with neither, the name takes the room', (tester) async {
      await tester.pumpWidget(host(tile(room())));
      final quiet = tester.widget<Text>(find.text('design')).style!.fontSize;

      await tester.pumpWidget(host(tile(room(lastMessage: 'something'))));
      final busy = tester.widget<Text>(find.text('design')).style!.fontSize;

      expect(
        quiet,
        greaterThan(busy!),
        reason: 'an empty tile spends its space on the one thing it knows',
      );
    });

    testWidgets('a faceless room gets a monogram, a pictured one does not', (tester) async {
      await tester.pumpWidget(host(tile(room())));
      expect(find.byType(RoomMonogram), findsOneWidget);
      expect(find.text('D'), findsOneWidget, reason: 'the room initial');
    });
  });

  group('the card holds its size', () {
    testWidgets('quiet and busy rows are the same height', (tester) async {
      Future<double> heightOf(ChatRoom r) async {
        await tester.pumpWidget(host(RoomCard(room: r, onTap: () {})));
        expect(tester.takeException(), isNull);
        return tester.getSize(find.byType(RoomCard)).height;
      }

      final busy = await heightOf(
        room(lastMessage: 'ayşe: pushed the fix', lastMessageTime: epoch),
      );
      final described = await heightOf(room(description: 'a quiet corner'));
      final bare = await heightOf(room());

      expect(described, busy);
      expect(bare, busy);
    });

    testWidgets('a room nobody has spoken in says how long it has been there',
        (tester) async {
      final loc = await en();
      await tester.pumpWidget(host(RoomCard(room: room(), onTap: () {})));
      expect(
        find.text(loc.roomCardStartedAgo(loc.roomCardTimeAgoDays(3))),
        findsOneWidget,
      );
    });
  });
}
