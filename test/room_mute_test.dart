import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/models/room_mute.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/count_badge.dart';
import 'package:monkeyhub/widgets/muted_badge.dart';
import 'package:monkeyhub/widgets/room_card.dart';

/// Per-room mute: two switches, one clock, and the arithmetic that has to be
/// right on both sides of the wire.
///
/// The interesting property of this feature is that nothing *runs* when a mute
/// ends. There is no timer here and no cron on the backend — a mute lapses
/// because a comparison against the wall clock started coming out the other
/// way. That makes it exactly testable, and it is what most of this file
/// pins: every question takes the instant it is being asked about, so
/// "eight hours from now" is an argument rather than a wait.
///
/// The other property worth guarding is that the two switches are genuinely
/// independent. It would be very easy — and quietly wrong — for muting
/// notifications to also stop a room counting, because that is what "muted"
/// means in most apps. Here it is a separate choice, and a room with only the
/// first switch on must keep climbing its unread count.
void main() {
  final l10n = AppLocalizationsEn();

  // A fixed "now" and a set of instants around it. Nothing in this file reads
  // the real clock except where that is the thing under test.
  final now = DateTime.utc(2026, 8, 9, 12, 0, 0);
  final inOneHour = now.add(const Duration(hours: 1));
  final inEightHours = now.add(const Duration(hours: 8));

  ChatRoom room({
    String id = 'r1',
    String name = 'general',
    int unreadCount = 0,
    bool hasMention = false,
    RoomMute mute = RoomMute.none,
  }) => ChatRoom(
    id: id,
    name: name,
    createdBy: 'u0',
    createdAt: DateTime(2026),
    isPrivate: true,
    memberCount: 3,
    unreadCount: unreadCount,
    hasMention: hasMention,
    mute: mute,
    participantIds: const ['u0', 'u1', 'u2'],
  );

  /// A mute that ends at [until], expressed the way the backend stores it.
  RoomMute muteUntil(
    DateTime until, {
    bool notifications = true,
    bool badges = false,
  }) => RoomMute(
    notifications: notifications,
    badges: badges,
    untilMs: until.millisecondsSinceEpoch,
  );

  RoomMute muteAlways({bool notifications = true, bool badges = false}) =>
      RoomMute(
        notifications: notifications,
        badges: badges,
        untilMs: kMuteAlwaysMs,
      );

  /// A mute whose deadline is already behind us, anchored to the REAL clock.
  ///
  /// The synthetic [now] above is a fixed instant, which is exactly what the
  /// pure-arithmetic tests want and exactly wrong for the ones that go through
  /// [ChatRoom]'s getters — those read `DateTime.now()`, so a fixture has to be
  /// in the past relative to whenever the suite happens to run, not relative to
  /// an August afternoon.
  RoomMute lapsed({bool notifications = true, bool badges = true}) => RoomMute(
        notifications: notifications,
        badges: badges,
        untilMs: DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      );

  group('the two switches are independent', () {
    test('notifications alone silences pushes and nothing else', () {
      final m = muteUntil(inOneHour, notifications: true, badges: false);
      expect(m.silencesNotificationsAt(now), isTrue);
      expect(
        m.silencesBadgesAt(now),
        isFalse,
        reason:
            'muting the banner must not quietly also hide the count — that is '
            'the second switch, and the user did not ask for it',
      );
    });

    test('badges alone hides counts while pushes still land', () {
      final m = muteUntil(inOneHour, notifications: false, badges: true);
      expect(m.silencesBadgesAt(now), isTrue);
      expect(
        m.silencesNotificationsAt(now),
        isFalse,
        reason:
            'hiding an unread count is a real thing to want on its own — a '
            'busy room you check on your own schedule but still want pinged '
            'about. A ladder of presets could not express it.',
      );
    });

    test('both switches together silence both', () {
      final m = muteUntil(inOneHour, notifications: true, badges: true);
      expect(m.silencesNotificationsAt(now), isTrue);
      expect(m.silencesBadgesAt(now), isTrue);
    });

    test('a deadline with neither switch on is not a mute', () {
      // `rooms.muteRoom` refuses to write this, but a client holding a row
      // from a build that could must not draw a MUTED pill over nothing.
      final m = RoomMute(
        notifications: false,
        badges: false,
        untilMs: inOneHour.millisecondsSinceEpoch,
      );
      expect(m.isLiveAt(now), isFalse);
    });
  });

  group('expiry is arithmetic, not an event', () {
    test('a mute lapses on its own once the deadline passes', () {
      final m = muteUntil(inOneHour, notifications: true, badges: true);

      expect(m.silencesNotificationsAt(now), isTrue);
      expect(m.silencesBadgesAt(now), isTrue);

      // The whole point. No mutation is called, no timer fires, no sweep runs
      // and the object is not touched — the only thing that changed is which
      // instant we are asking about. The backend answers the same way, from
      // the same stored number, at the moment it decides to send a push.
      final afterwards = now.add(const Duration(hours: 1, seconds: 1));
      expect(m.silencesNotificationsAt(afterwards), isFalse);
      expect(m.silencesBadgesAt(afterwards), isFalse);
      expect(m.isLiveAt(afterwards), isFalse);
    });

    test('the deadline itself is the first unmuted instant', () {
      final m = muteUntil(inOneHour);
      expect(
        m.silencesNotificationsAt(
          inOneHour.subtract(const Duration(milliseconds: 1)),
        ),
        isTrue,
      );
      expect(
        m.silencesNotificationsAt(inOneHour),
        isFalse,
        reason:
            'the stored instant is when the mute ENDS, so it is exclusive — '
            'and it has to match `now >= until` in mute.ts exactly or a push '
            'sent on that millisecond disagrees with the room list',
      );
    });

    test('a room whose mute lapsed is indistinguishable from one never muted',
        () {
      // Goes through the real clock deliberately: these getters are what every
      // widget calls, and nothing was asked to unmute this room.
      final r = room(unreadCount: 4, mute: lapsed());
      expect(r.isMuted, isFalse);
      expect(r.badgesMuted, isFalse);
      expect(r.visibleUnreadCount, 4);
      expect(r.hasUnread, isTrue);
    });

    test('"always" never lapses', () {
      final m = muteAlways(notifications: true, badges: true);
      expect(m.isAlways, isTrue);
      expect(m.silencesNotificationsAt(now), isTrue);

      // Far past anything a bounded preset could reach, and past anything a
      // person will be around to observe.
      final farFuture = DateTime.utc(9999, 12, 31);
      expect(m.silencesNotificationsAt(farFuture), isTrue);
      expect(m.silencesBadgesAt(farFuture), isTrue);
    });

    test('the always sentinel is a real, representable instant', () {
      // The sentinel is only safe because both languages can hold it. If Dart
      // ever narrows its DateTime range this throws here rather than in a
      // user's chat list.
      expect(
        () => DateTime.fromMillisecondsSinceEpoch(kMuteAlwaysMs, isUtc: true),
        returnsNormally,
      );
      expect(
        kMuteAlwaysMs,
        lessThan(1 << 53),
        reason: 'must survive float64 on the wire without rounding',
      );
    });

    test('"always" has no deadline to render', () {
      // [until] deliberately collapses "always" and "not muted" to null, so
      // every display site reaches for the word instead of a date in the year
      // 275760.
      expect(muteAlways().until, isNull);
      expect(RoomMute.none.until, isNull);
      // Compared as instants rather than as DateTimes: `until` rebuilds a
      // LOCAL DateTime from the stored epoch, and Dart's `==` treats a local
      // and a UTC DateTime at the same moment as unequal.
      expect(
        muteUntil(inEightHours).until?.millisecondsSinceEpoch,
        inEightHours.millisecondsSinceEpoch,
      );
    });
  });

  group('a notification-muted room still counts', () {
    test('the unread count keeps climbing when only pushes are silenced', () {
      final r = room(unreadCount: 7, mute: muteAlways(notifications: true));

      expect(r.notificationsMuted, isTrue);
      expect(r.badgesMuted, isFalse);
      expect(
        r.visibleUnreadCount,
        7,
        reason:
            'the user asked for silence, not for the room to disappear — they '
            'still want to see there are seven things waiting',
      );
      expect(r.hasUnread, isTrue);
      expect(r.unreadLabel, '7');
    });

    test('it still contributes to the app-icon aggregate', () {
      final counts = RoomFacetCounts.of([
        room(id: 'a', unreadCount: 7, mute: muteAlways(notifications: true)),
        room(id: 'b', unreadCount: 3),
      ]);
      expect(
        counts.unreadMessages,
        10,
        reason:
            'this number is what BadgeManager writes to the app icon, and the '
            'backend badgeTotalFor only skips BADGE-muted rooms — the two are '
            'independent computations of one number and must apply one rule',
      );
      expect(counts.unreadRooms, 2);
    });

    test('it is still findable by the unread filter', () {
      final r = room(
        unreadCount: 2,
        hasMention: true,
        mute: muteAlways(notifications: true),
      );
      expect(RoomFacet.unread.matches(r), isTrue);
      expect(RoomFacet.mentions.matches(r), isTrue);
    });
  });

  group('a badge-muted room leaves every count', () {
    test('its unread count reads as zero everywhere on screen', () {
      final r = room(
        unreadCount: 12,
        hasMention: true,
        mute: muteAlways(notifications: false, badges: true),
      );

      expect(
        r.unreadCount,
        12,
        reason:
            'the true figure survives, so the room info screen can still say '
            'how much is waiting in a room you have silenced',
      );
      expect(r.visibleUnreadCount, 0);
      expect(r.hasVisibleMention, isFalse);
      expect(
        r.hasUnread,
        isFalse,
        reason:
            'hiding the pill while keeping the glowing dot and the bold name '
            'would silence the number and none of the noise around it',
      );
    });

    test('it drops out of the aggregates the app icon is built from', () {
      final counts = RoomFacetCounts.of([
        room(id: 'a', unreadCount: 12, mute: muteAlways(badges: true)),
        room(id: 'b', unreadCount: 3),
      ]);
      expect(counts.unreadMessages, 3);
      expect(counts.unreadRooms, 1);
    });

    test('and out of the unread and mention filters', () {
      final r = room(
        unreadCount: 2,
        hasMention: true,
        mute: muteAlways(badges: true),
      );
      expect(
        RoomFacet.unread.matches(r),
        isFalse,
        reason:
            'a room silenced down to its counts must not be findable by asking '
            'for the rooms with counts',
      );
      expect(RoomFacet.mentions.matches(r), isFalse);
    });

    test('the counts come back the moment the mute lapses', () {
      final r = room(unreadCount: 12, mute: lapsed());
      expect(RoomFacetCounts.of([r]).unreadMessages, 12);
      expect(RoomFacetCounts.of([r]).unreadRooms, 1);
    });
  });

  group('the wire', () {
    test('a room from a backend that predates the feature is not muted', () {
      final r = ChatRoom.fromJson({
        '_id': 'r1',
        'name': 'general',
        'createdBy': 'u0',
        'createdAt': DateTime(2026).millisecondsSinceEpoch,
        'isPrivate': true,
        'memberCount': 2,
        'unreadCount': 5,
      });
      expect(r.mute, RoomMute.none);
      expect(r.isMuted, isFalse);
      expect(r.visibleUnreadCount, 5);
    });

    test('the three columns survive a cache round-trip', () {
      final original = room(
        unreadCount: 5,
        mute: muteUntil(inEightHours, notifications: true, badges: true),
      );
      final restored = ChatRoom.fromJson(original.toJson());
      expect(restored.mute, original.mute);
      expect(restored.mute.untilMs, inEightHours.millisecondsSinceEpoch);
    });

    test('"always" survives it too, sentinel intact', () {
      final restored =
          ChatRoom.fromJson(room(mute: muteAlways(badges: true)).toJson());
      expect(restored.mute.isAlways, isTrue);
      expect(restored.mute.badges, isTrue);
    });

    test('an unmuted room writes no mute keys at all', () {
      final json = room().toJson();
      expect(json.containsKey('mutedUntil'), isFalse);
      expect(json.containsKey('muteNotifications'), isFalse);
      expect(json.containsKey('muteBadges'), isFalse);
    });

    test('durations go out as lengths, not deadlines', () {
      // The server turns these into an absolute instant with its own clock —
      // sending our own would mute for the wrong stretch of time on a device
      // whose clock has drifted.
      expect(MuteDuration.hour.wireMs, const Duration(hours: 1).inMilliseconds);
      expect(
        MuteDuration.eightHours.wireMs,
        const Duration(hours: 8).inMilliseconds,
      );
      expect(MuteDuration.week.wireMs, const Duration(days: 7).inMilliseconds);
      expect(
        MuteDuration.always.wireMs,
        isNull,
        reason: '"always" is an absent durationMs, not a very large one',
      );
    });
  });

  group('the capability table decides who may be muted', () {
    test('ordinary rooms and DMs may be', () {
      expect(RoomCapabilities.group.canMute, isTrue);
      expect(RoomCapabilities.dm.canMute, isTrue);
    });

    test('Saved Messages may not — the switch could not do anything', () {
      expect(
        RoomCapabilities.savedMessages.canMute,
        isFalse,
        reason:
            'every push and every unread count already excludes the sender, '
            'and in a room whose only member is you that is every message',
      );
    });

    test('a system room may, unlike every other affordance it is denied', () {
      expect(
        RoomCapabilities.system.canMute,
        isTrue,
        reason:
            'the one flag whose OFF state is the unsafe one — a bot feed you '
            'cannot shut up — and muting cannot break a room the way a call '
            'button or a leave can',
      );
      expect(RoomCapabilities.system.canCall, isFalse);
      expect(RoomCapabilities.system.canLeave, isFalse);
    });

    test('resolves through the same table the rest of the chrome uses', () {
      ChatRoom named(String name, {String? systemRole}) => ChatRoom(
        id: 'x',
        name: name,
        createdBy: 'u0',
        createdAt: DateTime(2026),
        isPrivate: true,
        memberCount: 2,
        systemRole: systemRole,
      );
      expect(roomCapabilitiesFor(named('general')).canMute, isTrue);
      expect(roomCapabilitiesFor(named('dm:regular:u0:u1')).canMute, isTrue);
      expect(roomCapabilitiesFor(named('dm:self:u0')).canMute, isFalse);
      expect(
        roomCapabilitiesFor(named('dm:regular:u0:bot', systemRole: 'logs'))
            .canMute,
        isTrue,
      );
    });
  });

  group('the chat row', () {
    Future<void> pump(WidgetTester tester, ChatRoom r) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: RoomCard(room: r, onTap: () {})),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an unmuted room wears no pill and shows its count', (
      tester,
    ) async {
      await pump(tester, room(unreadCount: 4));
      expect(find.byType(MutedBadge), findsNothing);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('notification-muted: pill on, count still there', (
      tester,
    ) async {
      await pump(
        tester,
        room(unreadCount: 4, mute: muteAlways(notifications: true)),
      );
      expect(find.byType(MutedBadge), findsOneWidget);
      expect(find.text(l10n.mutedBadgeLabel), findsOneWidget);
      expect(
        find.text('4'),
        findsOneWidget,
        reason:
            'the two switches have to be visibly different on the row, or the '
            'sheet is offering a choice the list then hides',
      );
    });

    testWidgets('badge-muted: pill on, no count at all', (tester) async {
      await pump(tester, room(unreadCount: 4, mute: muteAlways(badges: true)));
      expect(find.byType(MutedBadge), findsOneWidget);
      expect(find.text('4'), findsNothing);
      expect(find.byType(CountBadge), findsNothing);
    });

    testWidgets('a lapsed mute leaves the row looking ordinary again', (
      tester,
    ) async {
      await pump(tester, room(unreadCount: 4, mute: lapsed()));
      expect(find.byType(MutedBadge), findsNothing);
      expect(find.text('4'), findsOneWidget);
    });
  });
}
