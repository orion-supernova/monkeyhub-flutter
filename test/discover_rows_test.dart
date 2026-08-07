import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/discover_rows.dart';
import 'package:monkeyhub/widgets/visibility_badge.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// Discover previews five of each list and sends the rest to a full-list
/// screen, so the header's count and the see-all row are the only things
/// telling you how much you haven't seen. Both have to be honest.
void main() {
  Widget host(Widget child, {double width = 375}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  group('section header', () {
    testWidgets('prints the total beside the label', (tester) async {
      await tester.pumpWidget(
        host(const DiscoverSectionHeader(label: 'PUBLIC ROOMS', count: '87')),
      );
      expect(find.text('PUBLIC ROOMS'), findsOneWidget);
      expect(find.text('87'), findsOneWidget);
    });

    testWidgets('shows no number at all while a fetch is in flight', (
      tester,
    ) async {
      // An empty count is how "still looking" is told apart from "looked,
      // found nothing" — a bare 0 during the first flight would be a lie.
      await tester.pumpWidget(
        host(const DiscoverSectionHeader(label: 'PUBLIC ROOMS', count: '')),
      );
      expect(find.text('PUBLIC ROOMS'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('see-all row', () {
    testWidgets('names the true total, not the preview length', (tester) async {
      await tester.pumpWidget(host(SeeAllRow(total: 87, onTap: () {})));
      expect(find.text('see all 87'), findsOneWidget);
    });

    testWidgets('is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(SeeAllRow(total: 24, onTap: () => tapped = true)),
      );
      await tester.tap(find.text('see all 24'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('fits the 360pt desktop column', (tester) async {
      await tester.pumpWidget(
        host(SeeAllRow(total: 1234, onTap: () {}), width: 360),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('public room row', () {
    ChatRoom room({
      String name = 'ankara coffee club',
      String? description,
      bool hasPassword = false,
      Duration? lifetime,
    }) => ChatRoom(
      id: 'r1',
      name: name,
      description: description,
      createdBy: 'u1',
      createdAt: DateTime(2026, 3, 4),
      isPrivate: false,
      memberCount: 12,
      hasPassword: hasPassword,
      type: lifetime == null ? RoomType.regular : RoomType.secret,
      messageLifetime: lifetime,
    );

    // The whole point of the two-tier row: the name and the description are
    // what a stranger reads, and on one line with the pills and the count they
    // had about a third of the row and ellipsed almost immediately.
    testWidgets('gives the name and the description two lines each', (
      tester,
    ) async {
      const name = 'the very long room name that never fit on a single line';
      const desc =
          'a description with enough in it to say what the room is actually '
          'for, which is more than a phone row ever gave it';
      await tester.pumpWidget(
        host(
          PublicRoomTile(
            room: room(name: name, description: desc),
            onTap: () {},
          ),
        ),
      );
      expect(tester.widget<Text>(find.text(name)).maxLines, 2);
      expect(tester.widget<Text>(find.text(desc)).maxLines, 2);
    });

    testWidgets('prints the description in the case its owner typed', (
      tester,
    ) async {
      // The old row lowercased it to keep one line quiet. Over two lines that
      // reads as a typo, and every proper noun in it loses.
      await tester.pumpWidget(
        host(
          PublicRoomTile(
            room: room(description: 'Ankara Coffee Club, Thursdays'),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Ankara Coffee Club, Thursdays'), findsOneWidget);
    });

    testWidgets('fits a narrow phone with every pill showing', (tester) async {
      await tester.pumpWidget(
        host(
          PublicRoomTile(
            room: room(
              name: 'a room with a name of an entirely unreasonable length',
              description: 'and a description to match it, at some length',
              hasPassword: true,
              lifetime: const Duration(minutes: 5),
            ),
            onTap: () {},
          ),
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LockedBadge), findsOneWidget);
      expect(find.byType(EphemeralBadge), findsOneWidget);
      expect(find.byType(VisibilityBadge), findsOneWidget);
    });

    testWidgets('a tap that lands on a pill still opens the room', (
      tester,
    ) async {
      // The pills answer for themselves on a room card. Here the row is one
      // target and what it opens says all of it in sentences, so a tooltip on
      // the pill would only swallow the tap and hand back less.
      var tapped = 0;
      await tester.pumpWidget(
        host(
          PublicRoomTile(
            room: room(hasPassword: true),
            onTap: () => tapped++,
          ),
        ),
      );
      await tester.tap(find.byType(LockedBadge));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('still counts the members', (tester) async {
      await tester.pumpWidget(host(PublicRoomTile(room: room(), onTap: () {})));
      expect(find.text('12'), findsOneWidget);
    });
  });

  testWidgets('an empty section is one quiet line', (tester) async {
    await tester.pumpWidget(host(const DiscoverEmptyLine('inbox quiet')));
    expect(find.text('inbox quiet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
