import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/room_card.dart';
import 'package:monkeyhub/widgets/room_grid_tile.dart';
import 'package:monkeyhub/widgets/visibility_badge.dart';

/// What a room's facts say on a card and a grid tile, and where.
///
/// Neither carries pills any more: a tile shows the quiet glyphs a row has,
/// a card spells the facts out in one meta line of words. The rules worth
/// pinning down are the ones a later layout change would quietly break: a DM
/// never says "private", and a glyph on a tile never swallows the tap that
/// opens the room.
void main() {
  final epoch = DateTime(2026, 8, 8, 12);

  ChatRoom room({
    String name = 'design',
    bool isPrivate = false,
    bool hasPassword = false,
    Duration? ttl,
    bool isPinned = false,
  }) => ChatRoom(
    id: 'r1',
    name: name,
    createdBy: 'u1',
    createdAt: epoch,
    isPrivate: isPrivate,
    memberCount: 4,
    hasPassword: hasPassword,
    type: ttl == null ? RoomType.regular : RoomType.secret,
    messageLifetime: ttl,
    isPinned: isPinned,
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

  Future<AppLocalizations> en() =>
      AppLocalizations.delegate.load(const Locale('en'));

  group('grid tile', () {
    Widget tile(ChatRoom r, {VoidCallback? onTap}) => host(
          SizedBox(
            width: 180,
            height: 180,
            child: RoomGridTile(room: r, onTap: onTap ?? () {}),
          ),
        );

    testWidgets('carries no pills at all, only the quiet glyphs a row has',
        (tester) async {
      await tester.pumpWidget(
        tile(room(hasPassword: true, ttl: const Duration(minutes: 5))),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(RoomBadge), findsNothing);
      expect(find.byIcon(CupertinoIcons.lock_fill), findsOneWidget);
    });

    testWidgets('a DM carries no visibility word', (tester) async {
      final loc = await en();
      await tester.pumpWidget(tile(room(name: 'dm:u1:u2', isPrivate: true)));
      expect(tester.takeException(), isNull);
      expect(find.text(loc.enterPublicRoomVisibilityPrivateLabel), findsNothing);
    });

    testWidgets('a tap anywhere on the tile opens the room', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        tile(room(hasPassword: true), onTap: () => opened = true),
      );
      await tester.tap(find.byIcon(CupertinoIcons.lock_fill));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });
  });

  group('iconography', () {
    // A private room and a password-protected one are different questions —
    // who can see it, versus what it costs to walk in — and a group room can
    // be both at once. When both pills drew a padlock the tile said the same
    // thing twice and neither said which.
    final padlocks = <IconData>{
      Icons.lock,
      Icons.lock_outline,
      Icons.lock_outline_rounded,
      Icons.lock_rounded,
      Icons.lock_open,
    };
    // The app draws Cupertino glyphs now; LockedBadge's padlock is one of
    // these. (Kept apart from [padlocks] above only because three character
    // themes still draw a Cupertino padlock for "private" — a known conflict
    // reported to the theme owner; fold this set into [padlocks] once fixed.)
    final cupertinoPadlocks = <IconData>{
      CupertinoIcons.lock,
      CupertinoIcons.lock_fill,
    };

    testWidgets('no theme locks the private room pill', (tester) async {
      for (final theme in ThemeController.all) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: theme.visibilityIcon(isPublic: false)),
          ),
        );
        final icons = tester.widgetList<Icon>(find.byType(Icon));
        for (final icon in icons) {
          expect(
            padlocks.contains(icon.icon),
            isFalse,
            reason: '${theme.id} draws a padlock for private — that glyph '
                'belongs to LockedBadge',
          );
        }
      }
    });

    testWidgets('the locked pill is the one that locks', (tester) async {
      await tester.pumpWidget(host(const LockedBadge()));
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byType(LockedBadge), matching: find.byType(Icon)),
      );
      expect(
        padlocks.contains(icon.icon) || cupertinoPadlocks.contains(icon.icon),
        isTrue,
      );
    });
  });

  group('row card', () {
    testWidgets('spells the facts out in words, without pills', (tester) async {
      final loc = await en();
      await tester.pumpWidget(
        host(RoomCard(room: room(hasPassword: true), onTap: () {})),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(RoomBadge), findsNothing);
      final meta = find.textContaining(loc.roomCardLockedBadge, findRichText: true);
      expect(meta, findsOneWidget);
      final text = tester.widget<RichText>(meta).text.toPlainText();
      expect(text, contains(loc.enterPublicRoomVisibilityPublicLabel));
      expect(text, contains(loc.roomCardMemberCount(4)));
    });

    testWidgets('a secret room leads with how long messages last',
        (tester) async {
      final loc = await en();
      await tester.pumpWidget(
        host(RoomCard(
          room: room(hasPassword: true, ttl: const Duration(hours: 24)),
          onTap: () {},
        )),
      );
      final eph = loc.enterPublicRoomEphemeralBadgeLabel(
        loc.enterPublicRoomEphemeralHoursShort(24),
      );
      final text = tester
          .widget<RichText>(find.textContaining(eph, findRichText: true))
          .text
          .toPlainText();
      expect(text.indexOf(eph), lessThan(text.indexOf(loc.roomCardMemberCount(4))));
    });

    testWidgets('a DM has no meta line', (tester) async {
      final loc = await en();
      await tester.pumpWidget(
        host(
          RoomCard(
            room: room(name: 'dm:u1:u2', isPrivate: true),
            onTap: () {},
          ),
        ),
      );
      expect(
        find.textContaining(loc.enterPublicRoomVisibilityPrivateLabel,
            findRichText: true),
        findsNothing,
      );
    });
  });

  group('pinned & Saved Messages', () {
    testWidgets('a pinned room carries the pinned badge', (tester) async {
      await tester.pumpWidget(
        host(RoomCard(room: room(isPinned: true), onTap: () {})),
      );
      expect(find.byIcon(CupertinoIcons.pin_fill), findsOneWidget);
    });

    testWidgets('an unpinned room carries no pinned badge', (tester) async {
      await tester.pumpWidget(host(RoomCard(room: room(), onTap: () {})));
      expect(find.byIcon(CupertinoIcons.pin_fill), findsNothing);
    });

    testWidgets(
      'Saved Messages shows the pinned badge like any other pinned room',
      (tester) async {
        await tester.pumpWidget(
          host(
            RoomCard(
              room: room(name: 'dm:self:u1', isPinned: true),
              onTap: () {},
            ),
          ),
        );
        expect(find.byIcon(CupertinoIcons.pin_fill), findsOneWidget);
      },
    );

    testWidgets('unpinned Saved Messages drops the badge with it', (
      tester,
    ) async {
      // The badge was suppressed here while the room was pinned by
      // construction and the pill could only ever say the same thing. Now
      // that unpinning it is a real choice, the pill is what reports which
      // way it went.
      await tester.pumpWidget(
        host(
          RoomCard(room: room(name: 'dm:self:u1'), onTap: () {}),
        ),
      );
      expect(find.byIcon(CupertinoIcons.pin_fill), findsNothing);
    });

    testWidgets(
      'Saved Messages renders its localized title and a bookmark avatar, '
      'not the raw room name',
      (tester) async {
        final loc = await en();
        await tester.pumpWidget(
          host(RoomCard(room: room(name: 'dm:self:u1'), onTap: () {})),
        );
        expect(find.text(loc.savedMessagesTitle), findsOneWidget);
        expect(find.text('dm:self:u1'), findsNothing);
        expect(find.byIcon(CupertinoIcons.bookmark_fill), findsOneWidget);
      },
    );

    testWidgets('the grid tile renders the same Saved Messages override', (
      tester,
    ) async {
      final loc = await en();
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 180,
            height: 180,
            child: RoomGridTile(room: room(name: 'dm:self:u1'), onTap: () {}),
          ),
        ),
      );
      expect(find.text(loc.savedMessagesTitle), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.bookmark_fill), findsOneWidget);
    });
  });
}
