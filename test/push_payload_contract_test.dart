import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The push payload is a contract spoken by five files in four languages, and
/// nothing but agreement holds it together.
///
/// The backend builds a flat map of string keys; iOS reads it out of
/// `userInfo`, Android out of the FCM `data` map, and the browser out of the
/// service worker's JSON. Renaming a key in one place is a compile error in
/// none of them — it just silently stops working on a platform nobody is
/// looking at, and only on a physical device.
///
/// So this test asserts the literal strings are present wherever they must be.
/// It is deliberately crude: a grep is exactly the check that a compiler
/// cannot do here.
void main() {
  const backend = 'backend/convex/push.ts';
  const senders = 'backend/convex/notifications.ts';
  const ios = 'ios/Runner/AppDelegate.swift';
  const androidRender = 'android/app/src/main/kotlin/com/walhallaa/'
      'chattest20241220/ChatNotifications.kt';
  const androidRoute = 'android/app/src/main/kotlin/com/walhallaa/'
      'chattest20241220/CallFcmService.kt';
  const androidActivity = 'android/app/src/main/kotlin/com/walhallaa/'
      'chattest20241220/MainActivity.kt';
  const web = 'web/mh-push-sw.js';
  const nudge = 'backend/convex/dailyNudge.ts';
  // The Notification Service Extension, which redraws a banner with the
  // sender's face. A fifth reader of the same flat map, in a fourth language.
  const iosNse = 'ios/NotificationService/NotificationService.swift';
  // The App Group helper both iOS binaries share. It parks an arriving chat
  // message for the app to pick up, and files it under its message id.
  const iosShared = 'ios/Shared/ShareGroup.swift';
  // The Dart end of the seed. The native handlers forward the `data` map
  // wholesale and read almost none of it, so this is the file that actually
  // has to know these key names — which is exactly the asymmetry that makes a
  // grep the right check.
  const dartRepo = 'lib/data/chat_repository.dart';
  const calls = 'backend/convex/calls.ts';
  const groupCalls = 'backend/convex/groupCalls.ts';
  // The RING transport — a different topic and a different token from the
  // banner one in push.ts, and the sender of the two kinds a native ringer
  // (rather than a notification) is raised from.
  const voip = 'backend/convex/voipPush.ts';
  // Where a native card's accept and decline are turned back into backend
  // calls. The only reader of the ring payload that is neither iOS nor
  // Android — it sees what both of them forward.
  const dartNative = 'lib/calls/native_call_handler.dart';
  // The group-call overlay: the one place a foregrounded Android app raises
  // the group card itself, off the realtime invite rather than off a push.
  const dartApp = 'lib/app.dart';

  final cache = <String, String>{};
  String source(String path) => cache.putIfAbsent(path, () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing $path');
        return file.readAsStringSync();
      });

  /// Every consumer that must recognise [key] by that exact name.
  const contract = <String, List<String>>{
    // Routes a tap, and suppresses a banner for the room already on screen.
    'roomId': [backend, ios, androidRender, web],
    // The discriminator every platform switches on.
    'kind': [backend, ios, androidRoute, web],
    // Replaces an already-displayed notification rather than stacking one.
    // iOS uses the apns-collapse-id HEADER instead, so it is absent there.
    'collapseId': [backend, androidRender, web],
    // Groups a room's notifications. iOS uses aps.thread-id.
    'threadId': [backend, web],
    'title': [backend, androidRender, web],
    'body': [backend, androidRender, web],
    // Which already-delivered notifications to pull back down.
    'dismissIds': [senders, ios, androidRender],
    // iOS matches a dismiss against this, NOT only against the notification
    // identifier: the identifier is assigned by iOS from apns-collapse-id and
    // is not a value we control, whereas this one is. Drop it from the message
    // payload and deleting a message stops clearing its banner.
    //
    // It also names the file each platform stages an arriving message in, which
    // is what makes a repeat delivery idempotent for free — hence the two
    // seeding readers alongside the three dismissal ones.
    'messageId': [backend, senders, ios, androidRender, iosShared],
    // Absolute unread count. Rides as data on the silent push because a
    // background APNs payload may not carry aps.badge.
    'badge': [backend, ios],
    // iOS-only: `aps.alert.subtitle`, distinct from both title and body —
    // the group name under the sender's name. Android/web have no such
    // field and read `roomName`/`isGroup` out of the flat data instead, so
    // this key is never expected to appear in either of them.
    'subtitle': [backend, senders],
    // Whether the room is a group, not a 1:1 DM — gates both `roomName`
    // below and whether Android/web render a subtitle line at all.
    'isGroup': [senders, androidRender, web, iosNse],
    // The group's name, sent only when `isGroup` is true. Absent for a DM,
    // whose `rooms.name` is the internal `dm:...` key, not a real title.
    'roomName': [senders, androidRender, web, iosNse],
    // The room's own picture, when it has one, for a group banner. Shared
    // rather than per recipient — a room is visible to every member — which
    // is the one way it differs from `senderAvatarUrl` below. Only iOS draws
    // it today: the extension titles a group message with the room and
    // prefers the room's picture to the sender's for the same banner.
    'roomAvatarUrl': [senders, iosNse],
    // Whether THIS recipient was named. Every renderer has to carry it into
    // a line it actually draws: MessagingStyle and the web worker replace the
    // title the backend put "X mentioned you" in, and iOS's communication
    // layout replaces the title and never draws the subtitle.
    'mention': [senders, androidRender, web, iosNse],
    // The sender's avatar, present only for a recipient the sender's own
    // avatar-visibility setting actually allows to see it (resolved
    // per-recipient in rooms.ts, mirroring the call ringer in calls.ts).
    'senderAvatarUrl': [senders, androidRender, web, iosNse, calls, groupCalls],
    // The name the iOS extension puts on the INPerson, which is what a
    // communication notification draws as the title. Losing it does not lose
    // the banner — it silently costs the sender's name on the one platform
    // that renders the notification from an intent rather than from the title.
    'senderName': [senders, iosNse],
    // The message's own server-minted `createdAt`, which is what lets a room
    // opened from a notification show the message BEFORE the network answers
    // (`ChatRepository.takePushedMessages`). It is the one field a stub cannot
    // be built without — nothing else says where the bubble goes — so losing
    // it does not corrupt anything, it silently turns the whole seed off.
    'createdAt': [senders, dartRepo],
    // Whether the message is simple enough to seed at all: no formatting, no
    // mentions, no reply tether, none of which fit in a push and all of which
    // would make the bubble RE-LAY-OUT when the real row landed. Decided
    // server-side in rooms.ts off the row it already holds.
    'plain': [senders, dartRepo],
    // The GROUP RING's identity, and its discriminant.
    //
    // A group invite reaches the same two native ringers a 1:1 call does, and
    // the plugin hands back one undifferentiated "the user pressed answer"
    // for both. This key's mere PRESENCE in the card's `extra` is what tells
    // Dart to answer with `groupCalls:join` rather than `calls:accept` — two
    // mutations against two tables that are not interchangeable. Every writer
    // of that `extra` and its one reader have to spell it the same way, and
    // nothing but this test says so: a 1:1 invite omits the key rather than
    // sending it empty, so a typo reads as "1:1" and is indistinguishable
    // from the normal case until a group call is answered as a DM.
    'groupCallId': [voip, ios, androidRoute, dartNative, groupCalls],
    // The starter's face for the group card a FOREGROUNDED Android app raises
    // itself, read off the realtime invite. The killed-app path carries the
    // same picture as `callerAvatarUrl` in the push; without this key the
    // in-app path drew a card with no face where the push path drew one.
    'starterAvatarUrl': [groupCalls, dartApp],
  };

  contract.forEach((key, consumers) {
    for (final path in consumers) {
      test('"$key" is known to $path', () {
        expect(
          source(path).contains(key),
          isTrue,
          reason: 'the push payload key "$key" is not mentioned in $path — '
              'either it was renamed on one side only, or that platform '
              'silently stopped handling it',
        );
      });
    }
  });

  group('the seeding channel', () {
    // `monkeyhub/notifications` carries one more method now: the app asking
    // the platform for chat messages its notification handler already staged,
    // so a room can open showing them instead of asking the network for
    // something the phone was told minutes ago.
    //
    // Pinned here rather than by a mocked channel in a repository test,
    // because a mock proves only that Dart calls what the mock answers. The
    // failure this guards is a native side that stops recognising the name —
    // which no Dart test can see, and which shows up as the feature simply not
    // working on one platform.
    const dartCaller = 'lib/push/push_manager.dart';
    for (final method in ['takePushInbox', 'clearPushInbox']) {
      for (final path in [dartCaller, androidActivity, ios]) {
        test('"$method" is known to $path', () {
          expect(
            source(path).contains(method),
            isTrue,
            reason: 'the notification channel method "$method" is not '
                'mentioned in $path — push seeding is silently dead on that '
                'platform',
          );
        });
      }
    }
  });

  group('kind values', () {
    // The kinds the senders in push.ts emit. A new one would need a home on
    // every platform, and a renamed one would fall through to the default
    // branch — silently, on a device nobody is holding.
    const kinds = [
      'message',
      'approval',
      'call_invite',
      'group_call_invite',
      'daily_games',
    ];
    for (final kind in kinds) {
      test('"$kind" is dispatched on Android', () {
        expect(source(androidRoute).contains('"$kind"'), isTrue);
      });
    }
    // The two RING kinds. These do not travel through push.ts at all — they
    // are PushKit on iOS and a data-only FCM message on Android, sent by
    // voipPush.ts — and they are what makes a group call ring rather than
    // merely announce itself. `group_call_invite` above is the BANNER that
    // now serves as their rescue, and the two names are one character apart:
    // confusing them routes a ring into the notification shade, which is
    // exactly the bug this pair was written to end.
    for (final kind in ['group_invite', 'group_taken']) {
      test('"$kind" rings on both phone platforms', () {
        expect(source(voip).contains('"$kind"'), isTrue,
            reason: 'voipPush.ts no longer sends "$kind"');
        expect(source(androidRoute).contains('"$kind"'), isTrue,
            reason: 'CallFcmService no longer dispatches "$kind" — a group '
                'call is silent on Android');
        expect(source(ios).contains('"$kind"'), isTrue,
            reason: 'AppDelegate no longer recognises "$kind" — a group call '
                'either does not ring on iOS, or rings forever');
      });
    }
    test('"dismiss" is handled on every platform that receives it', () {
      // Web deliberately never receives it: Chrome's userVisibleOnly forbids
      // a push that shows nothing. The service worker guards anyway.
      expect(source(backend).contains('"dismiss"'), isTrue);
      expect(source(ios).contains('"dismiss"'), isTrue);
      expect(source(androidRoute).contains('"dismiss"'), isTrue);
      expect(source(web).contains("'dismiss'"), isTrue);
    });
    test('"approval" routes to the requests screen on iOS', () {
      expect(source(ios).contains('onOpenRequests'), isTrue);
      expect(source(ios).contains('"approval"'), isTrue);
    });

    test('"daily_games" routes to the games shelf on both phone platforms', () {
      // The nudge carries no roomId, so on both platforms it falls past the
      // room branch and has to be recognised by kind. Miss either half and the
      // tap merely raises the app — which looks like the notification working,
      // right up until somebody says "it doesn't open the games".
      expect(source(ios).contains('"daily_games"'), isTrue);
      expect(source(ios).contains('onOpenGames'), isTrue);
      expect(source(androidActivity).contains('"daily_games"'), isTrue);
      expect(source(androidActivity).contains('onOpenGames'), isTrue);
    });

    test('"daily_games" gets its own Android channel', () {
      // A daily broadcast rendered on the messages channel cannot be silenced
      // from system settings without silencing messages too — which is the
      // whole promise the in-app switch makes, broken on the one platform
      // where the OS offers the finer control.
      final src = source(androidRender);
      expect(src.contains('CH_GAMES'), isTrue);
      expect(src.contains('mh_games'), isTrue);
    });

    test('the daily nudge is not sent to the web', () {
      // Not an oversight: a browser only receives a push while its service
      // worker is alive, so the audience would be whoever left a tab open. The
      // audience filter is the record of that decision — if it ever accepts a
      // web subscription again, mh-push-sw.js needs a `daily_games` branch in
      // `notificationclick` before this test is deleted.
      final src = source(nudge);
      expect(src.contains('webEndpoint'), isFalse,
          reason: 'dailyNudge must not select web subscriptions');
      expect(source(web).contains('daily_games'), isFalse,
          reason: 'the service worker has no daily_games branch to reach');
    });
  });

  group('transport invariants', () {
    test('a device the alert sender can see carries no PushKit token', () {
      // Sending a voipToken on the alert topic earns a 400
      // DeviceTokenNotForTopic, and the dead-token sweep then clears a
      // perfectly good credential — silently stopping that phone ringing,
      // with a symptom pointing nowhere near notifications.
      //
      // The guard is structural: the type the fan-out receives has no such
      // field, so the mistake cannot be written. (coverageReport reads
      // voipToken deliberately — "an iOS device with a PushKit token but no
      // alert token is still on the old build" is the rollout curve — which is
      // why this asserts on the type rather than the whole file.)
      final src = source(backend);
      final start = src.indexOf('type AlertDevice = {');
      expect(start, greaterThan(-1), reason: 'AlertDevice type not found');
      final end = src.indexOf('};', start);
      expect(end, greaterThan(start));
      final decl = src.substring(start, end);
      expect(
        decl.contains('voipToken'),
        isFalse,
        reason: 'AlertDevice must not carry voipToken — that is voipPush.ts',
      );
      // …and the sender addresses the alert token by name.
      expect(src.contains('token: d.apnsToken'), isTrue);
    });

    test('the alert topic is the bare bundle id, not the VoIP one', () {
      expect(source(backend).contains('topicSuffix: ""'), isTrue);
      expect(source('backend/convex/voipPush.ts').contains('topicSuffix: ".voip"'),
          isTrue);
    });

    test('the silent dismiss push carries a badge, so it is not throttled', () {
      // This is the only thing that takes a deleted message's banner off a
      // lock screen, and a payload with ONLY content-available is a pure
      // background push — the most throttled class iOS has, and never
      // delivered at all to a force-quit app. A badge makes it an `alert`
      // push, which is prompt, while still displaying nothing because there
      // is no alert or sound key. Shipping it as `background` once already
      // broke this feature in production.
      final src = source(backend);
      expect(src.contains('"content-available": 1, badge: spec.badge'), isTrue,
          reason: 'the dismiss payload must keep its aps badge');
      expect(src.contains('pushType: "alert"'), isTrue);
      expect(src.contains('"background"'), isFalse,
          reason: 'no push here may be sent as apns-push-type: background');
    });

    test('dismissIds crosses the wire as JSON, not an array', () {
      // FCM v1 data values are all strings, and a naive stringify would turn
      // ["a","b"] into "a,b". Both native sides parse the same encoding.
      expect(source(senders).contains('JSON.stringify(dismissIds'), isTrue);
      expect(source(ios).contains('JSONSerialization'), isTrue);
      expect(source(androidRender).contains('JSONArray'), isTrue);
    });

    test('the sender avatar is gated per recipient, not sent blind', () {
      // `senderAvatarUrl` must ride the per-user override map keyed off
      // `avatarVisible` — never the shared `data` block every recipient of
      // one message gets verbatim. Getting this backwards would leak a face
      // to a recipient the sender's own avatar-visibility setting ("friends"
      // or "nobody") says shouldn't see it.
      final src = source(senders);
      expect(src.contains('m.avatarVisible'), isTrue,
          reason: 'avatar visibility must be checked per recipient');
      final sharedDataStart = src.indexOf('data: {\n        kind: "message"');
      expect(sharedDataStart, greaterThan(-1),
          reason: 'the shared per-message data block moved — update this test');
      final sharedDataEnd = src.indexOf('roomId,', sharedDataStart);
      final sharedData = src.substring(sharedDataStart, sharedDataEnd);
      expect(sharedData.contains('senderAvatarUrl'), isFalse,
          reason:
              'senderAvatarUrl must never sit in the data every recipient '
              'shares — it belongs in the per-user override only');

      // The call paths send the same key and must obey the same rule. A group
      // call fans out to a whole room, so a face in its shared `data` block
      // would leak exactly as a message's would; the 1:1 path has one recipient
      // and would be equivalent today, which is precisely the exception
      // somebody copies the day it grows a second.
      for (final path in [calls, groupCalls]) {
        final src = source(path);
        expect(src.contains('senderAvatarUrl'), isTrue,
            reason: '$path stopped sending the avatar entirely');
        expect(_sendAlertData(src).contains('senderAvatarUrl'), isFalse,
            reason: 'in $path, senderAvatarUrl must travel inside the perUser '
                'map — never the shared data block every recipient gets');
      }
    });

    test('mutable-content is set for a chat message, or for a face', () {
      // `mutable-content` launches the Notification Service Extension on the
      // recipient's phone, and the extension does two jobs: it redraws the
      // banner with the sender's face, and it parks the message in the App
      // Group so the room can open already showing it.
      //
      // So the gate is an OR, and each half stands on its own:
      //
      //  * `kind === "message"` — the seed. This is the load-bearing half, and
      //    the one with no other signal when it regresses: drop it and every
      //    iOS notification tap silently goes back to opening a room that has
      //    to ask the network for a message the phone was already told.
      //  * an avatar — the face, and the ONLY reason for every other kind.
      //    Still gated on `senderAvatarUrl` being present, which is also what
      //    gates it on the recipient being allowed to see the face at all
      //    (resolved per-recipient in rooms.ts), so a launch is never spent on
      //    a push that could only hand back the banner it was given.
      final src = source(backend);
      final at = src.indexOf('aps["mutable-content"]');
      expect(at, greaterThan(-1),
          reason: 'mutable-content moved — update this test');
      final guard = src.lastIndexOf(
        'if (spec.kind === "message" || spec.data.senderAvatarUrl)',
        at,
      );
      expect(guard, greaterThan(-1),
          reason: 'mutable-content must be gated on the message kind OR a '
              'visible avatar. Losing the message half turns off push seeding '
              'on iOS with no other symptom; losing the avatar half spends an '
              'extension launch on every push in the app');
    });

    test('Android is sent data-only, never a notification block', () {
      // A `notification` payload is rendered by the system and skips
      // onMessageReceived while backgrounded, which forfeits collapse,
      // grouping, dismissal and active-room suppression.
      expect(source(backend).contains('notification:'), isFalse);
    });
  });
}


/// The literal `data: { … }` object handed to `push.sendAlert`, brace-balanced.
///
/// Crude on purpose, like the rest of this file: a real parse would be a
/// dependency, and what is being checked is the presence of one string inside
/// one block. Returns an empty string when the call has no `data` block, which
/// reads as "nothing leaked" — correct, because there is nothing to leak.
String _sendAlertData(String src) {
  final call = src.indexOf('internal.push.sendAlert');
  if (call < 0) return '';
  final open = src.indexOf('data: {', call);
  if (open < 0) return '';
  var depth = 0;
  for (var i = src.indexOf('{', open); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}') {
      depth--;
      if (depth == 0) return src.substring(open, i + 1);
    }
  }
  return src.substring(open);
}
