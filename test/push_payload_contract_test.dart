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
  const web = 'web/mh-push-sw.js';

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
    'messageId': [backend, senders, ios],
    // Absolute unread count. Rides as data on the silent push because a
    // background APNs payload may not carry aps.badge.
    'badge': [backend, ios],
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

  group('kind values', () {
    // The five kinds sendAlert accepts. A sixth would need a home on every
    // platform, and a renamed one would fall through to the default branch.
    const kinds = ['message', 'approval', 'call_invite', 'group_call_invite'];
    for (final kind in kinds) {
      test('"$kind" is dispatched on Android', () {
        expect(source(androidRoute).contains('"$kind"'), isTrue);
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

    test('Android is sent data-only, never a notification block', () {
      // A `notification` payload is rendered by the system and skips
      // onMessageReceived while backgrounded, which forfeits collapse,
      // grouping, dismissal and active-room suppression.
      expect(source(backend).contains('notification:'), isFalse);
    });
  });
}
