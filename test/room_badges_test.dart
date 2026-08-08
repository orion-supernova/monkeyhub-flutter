import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/pinned_badge.dart';
import 'package:monkeyhub/widgets/room_card.dart';
import 'package:monkeyhub/widgets/room_grid_tile.dart';
import 'package:monkeyhub/widgets/visibility_badge.dart';

/// What the pills on a room say, and where they say it.
///
/// A grid tile has room for icons and nothing else, so the words move into a
/// tap tooltip; a full-width card keeps them. The rules worth pinning down are
/// the ones a later layout change would quietly break: a DM must never carry a
/// "PRIVATE" pill, an icon-only pill must still answer when tapped, and that
/// tap must not fall through and open the room.
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

  /// Taps [badge] and returns once the tooltip is up. Lets the tooltip's own
  /// hide timer run out afterwards so no timer outlives the test.
  Future<void> tapBadge(WidgetTester tester, Finder badge) async {
    await tester.tap(badge, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> settleTooltip(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  group('grid tile', () {
    testWidgets('a DM carries no visibility pill', (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 180,
            height: 180,
            child: RoomGridTile(
              room: room(name: 'dm:u1:u2', isPrivate: true),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(VisibilityBadge),
        findsNothing,
        reason: 'private is the only thing a one-to-one could be',
      );
    });

    testWidgets('a group room shows pills without words', (tester) async {
      final loc = await en();
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 180,
            height: 180,
            child: RoomGridTile(
              room: room(hasPassword: true, ttl: const Duration(minutes: 5)),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      expect(find.byType(VisibilityBadge), findsOneWidget);
      expect(find.byType(LockedBadge), findsOneWidget);
      expect(find.byType(EphemeralBadge), findsOneWidget);
      expect(find.text(loc.enterPublicRoomVisibilityPublicLabel), findsNothing);
      expect(find.text(loc.roomCardLockedBadge), findsNothing);
    });

    testWidgets('an icon-only pill explains itself on tap, and the tap does '
        'not open the room', (tester) async {
      final loc = await en();
      var opened = false;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 180,
            height: 180,
            child: RoomGridTile(
              room: room(hasPassword: true),
              onTap: () => opened = true,
            ),
          ),
        ),
      );

      await tapBadge(tester, find.byType(LockedBadge));
      expect(find.text(loc.roomBadgeLockedTooltip), findsOneWidget);
      expect(opened, isFalse, reason: 'the pill consumed its own tap');
      await settleTooltip(tester);
    });

    testWidgets('the hourglass keeps its timer in the tooltip', (tester) async {
      final loc = await en();
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 180,
            height: 180,
            child: RoomGridTile(
              room: room(ttl: const Duration(minutes: 5)),
              onTap: () {},
            ),
          ),
        ),
      );

      await tapBadge(tester, find.byType(EphemeralBadge));
      expect(
        find.text(loc.roomBadgeEphemeralTooltip(
          loc.enterPublicRoomEphemeralMinutesShort(5),
        )),
        findsOneWidget,
        reason: 'an hourglass alone says "not forever", not when',
      );
      await settleTooltip(tester);
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
      expect(padlocks.contains(icon.icon), isTrue);
    });
  });

  group('row card', () {
    testWidgets('keeps the words a grid tile has no room for', (tester) async {
      final loc = await en();
      await tester.pumpWidget(
        host(RoomCard(room: room(hasPassword: true), onTap: () {})),
      );
      expect(tester.takeException(), isNull);

      expect(find.text(loc.enterPublicRoomVisibilityPublicLabel), findsOneWidget);
      expect(find.text(loc.roomCardLockedBadge), findsOneWidget);
    });

    testWidgets('still explains on tap', (tester) async {
      final loc = await en();
      await tester.pumpWidget(
        host(RoomCard(room: room(), onTap: () {})),
      );

      await tapBadge(tester, find.byType(VisibilityBadge));
      expect(find.text(loc.roomBadgePublicTooltip), findsOneWidget);
      await settleTooltip(tester);
    });

    testWidgets('a DM carries no visibility pill either', (tester) async {
      await tester.pumpWidget(
        host(
          RoomCard(
            room: room(name: 'dm:u1:u2', isPrivate: true),
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(VisibilityBadge), findsNothing);
    });
  });

  group('pinned & Saved Messages', () {
    testWidgets('a pinned room carries the pinned badge', (tester) async {
      await tester.pumpWidget(
        host(RoomCard(room: room(isPinned: true), onTap: () {})),
      );
      expect(find.byType(PinnedBadge), findsOneWidget);
    });

    testWidgets('an unpinned room carries no pinned badge', (tester) async {
      await tester.pumpWidget(host(RoomCard(room: room(), onTap: () {})));
      expect(find.byType(PinnedBadge), findsNothing);
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
        expect(find.byType(PinnedBadge), findsOneWidget);
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
      expect(find.byType(PinnedBadge), findsNothing);
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
