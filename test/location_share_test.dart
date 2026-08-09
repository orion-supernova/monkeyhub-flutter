import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/location_share.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/widgets/location_map_preview.dart';

/// What this pins, in three groups:
///
///  1. **Serialization.** `ChatMessage.toJson`/`fromJson`/`copyWith` all
///     hand-enumerate their fields and none is a `switch`, so a location field
///     added to the class and forgotten in one of them compiles clean. For a
///     location the failure is total rather than cosmetic — a bubble IS its
///     coordinates — and a dropped `liveExpiresAt` is worse than total: a share
///     that ended overnight comes back off the disk cache claiming to be a
///     static pin.
///
///  2. **Expiry.** A share ending is a pure function of the deadline and the
///     clock, deliberately, so that it happens on the tick rather than on a
///     round trip. Every case below is a `now` this app will really be handed:
///     before, exactly at, after, stopped early, and stopped-then-past-deadline.
///
///  3. **Scale.** The preview draws real measurements, so the two functions
///     that decide them have to stay honest at both ends of the accuracy range.
void main() {
  final t0 = DateTime.utc(2026, 8, 9, 14, 0);

  ChatMessage live({
    Duration runs = const Duration(hours: 1),
    DateTime? endedAt,
    DateTime? updatedAt,
    double? accuracy = 12.5,
  }) =>
      ChatMessage(
        id: 'm1',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: '',
        createdAt: t0,
        type: MessageType.liveLocation,
        latitude: 41.0138,
        longitude: 28.9497,
        locationAccuracyM: accuracy,
        liveExpiresAt: t0.add(runs),
        liveUpdatedAt: updatedAt ?? t0,
        liveEndedAt: endedAt,
      );

  ChatMessage fixed() => ChatMessage(
        id: 'm2',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: '',
        createdAt: t0,
        type: MessageType.location,
        latitude: -33.8688,
        longitude: 151.2093,
        locationAccuracyM: 8,
      );

  group('wire enum', () {
    test('both location types survive the round trip', () {
      expect(MessageType.location.wire, 'location');
      expect(MessageType.liveLocation.wire, 'liveLocation');
      expect(MessageTypeWire.parse('location'), MessageType.location);
      expect(MessageTypeWire.parse('liveLocation'), MessageType.liveLocation);
    });

    test('a client too old to know these still degrades to text', () {
      // The server can write either type; a client that predates them parses
      // through the default branch. An empty text bubble is a poor rendering
      // and an acceptable one — a thrown exception in `messages:list` is not.
      expect(MessageTypeWire.parse('liveLocationV2'), MessageType.text);
    });
  });

  group('toJson → fromJson', () {
    test('a static location keeps its position across the disk cache', () {
      final back = ChatMessage.fromJson(fixed().toJson());
      expect(back.type, MessageType.location);
      expect(back.latitude, -33.8688);
      expect(back.longitude, 151.2093);
      expect(back.locationAccuracyM, 8);
      expect(back.locationShare, isNotNull);
    });

    test('a live share keeps the three timestamps that define its state', () {
      final back = ChatMessage.fromJson(
        live(endedAt: t0.add(const Duration(minutes: 20))).toJson(),
      );
      // Compared as instants, not as objects. `fromJson` rebuilds these with
      // `DateTime.fromMillisecondsSinceEpoch`, which is local-zone by
      // construction, so a whole-object match would be asserting the test
      // machine's timezone rather than the round trip.
      expect(back.liveExpiresAt!.isAtSameMomentAs(t0.add(const Duration(hours: 1))), isTrue);
      expect(back.liveUpdatedAt!.isAtSameMomentAs(t0), isTrue);
      expect(
        back.liveEndedAt!.isAtSameMomentAs(t0.add(const Duration(minutes: 20))),
        isTrue,
      );
      expect(
        back.locationShare!.stateAt(t0.add(const Duration(minutes: 25))),
        LiveShareState.ended,
        reason: 'a cold boot must not resurrect a share that was stopped',
      );
    });

    test('an ended share does not come back looking static', () {
      // The sharpest cache bug available here: drop `liveExpiresAt` and an
      // eight-hour share that finished last night reloads as a permanent pin
      // with no badge, no end time and nothing to say it was ever live.
      final back = ChatMessage.fromJson(
        live(endedAt: t0.add(const Duration(minutes: 5))).toJson(),
      );
      expect(back.locationShare!.isLive, isTrue);
      expect(back.type, MessageType.liveLocation);
    });

    test('the fields are omitted, not written null, on an ordinary message', () {
      final text = ChatMessage(
        id: 'm3',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: 'hi',
        createdAt: t0,
      );
      final json = text.toJson();
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('liveExpiresAt'), isFalse);
    });

    test('a whole-number coordinate arriving as an int still parses', () {
      // Convex hands back 0 for a position on the equator or the prime
      // meridian, and a JSON round trip can widen an int to a double. A raw
      // `as double?` on either would throw on the wire rather than render.
      final back = ChatMessage.fromJson({
        '_id': 'm4',
        'roomId': 'r1',
        'userId': 'u1',
        'senderName': 'ada',
        'content': '',
        'createdAt': t0.millisecondsSinceEpoch,
        'type': 'location',
        'latitude': 0,
        'longitude': 0,
      });
      expect(back.locationShare, isNotNull);
      expect(back.locationShare!.latitude, 0.0);
    });

    test('the send-only duration never reaches the wire', () {
      final m = ChatMessage(
        id: 'tmp_1',
        roomId: 'r1',
        senderId: 'u1',
        senderName: '',
        content: '',
        createdAt: t0,
        type: MessageType.liveLocation,
        latitude: 1,
        longitude: 2,
        liveExpiresAt: t0.add(const Duration(hours: 8)),
        liveShareDurationMs: 8 * 60 * 60 * 1000,
      );
      expect(m.toJson().containsKey('liveShareDurationMs'), isFalse);
      expect(
        m.copyWith(id: 'server_1').liveShareDurationMs,
        8 * 60 * 60 * 1000,
        reason: 'a retry after the ack must re-send the same duration',
      );
    });
  });

  group('copyWith', () {
    test('a reaction does not turn a live share into an empty card', () {
      // `copyWith` runs on the reaction path, which knows nothing about
      // locations. Dropping these would replace a moving map with a blank
      // plate, and — because `liveExpiresAt` would go too — one that no longer
      // knew it had ever been live.
      final reacted = live().copyWith(
        reactions: [
          MessageReaction(
            id: 'rx1',
            messageId: 'm1',
            userId: 'u2',
            emoji: '👍',
            createdAt: t0,
          ),
        ],
      );
      expect(reacted.locationShare, isNotNull);
      expect(reacted.locationShare!.isLive, isTrue);
      expect(reacted.liveExpiresAt, t0.add(const Duration(hours: 1)));
    });
  });

  group('locationShare', () {
    test('a location-typed message with no coordinates has no share', () {
      final broken = ChatMessage(
        id: 'm5',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: '',
        createdAt: t0,
        type: MessageType.location,
      );
      expect(broken.locationShare, isNull);
    });

    test('a stray coordinate on a text message is not a location', () {
      // The type gate, not the coordinate gate. The server refuses to write
      // this shape, but a fixture or a future field could produce it, and a
      // text bubble that silently became a map would be worse than either.
      final text = ChatMessage(
        id: 'm6',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: 'hi',
        createdAt: t0,
        latitude: 1,
        longitude: 2,
      );
      expect(text.locationShare, isNull);
    });
  });

  group('expiry', () {
    test('a static share is never live and never ends', () {
      final s = fixed().locationShare!;
      expect(s.isLive, isFalse);
      expect(s.stateAt(t0), LiveShareState.fixed);
      expect(
        s.stateAt(t0.add(const Duration(days: 365))),
        LiveShareState.fixed,
      );
      expect(s.remainingAt(t0), Duration.zero);
    });

    test('a running share is live and counts down', () {
      final s = live().locationShare!;
      expect(s.stateAt(t0.add(const Duration(minutes: 30))),
          LiveShareState.live);
      expect(
        s.remainingAt(t0.add(const Duration(minutes: 30))),
        const Duration(minutes: 30),
      );
    });

    test('it ends AT the deadline, not after it', () {
      // The boundary is the whole point: a bubble that still says "live until
      // 15:00" at exactly 15:00 is a bubble claiming something the server has
      // already stopped believing.
      final s = live().locationShare!;
      expect(s.stateAt(t0.add(const Duration(hours: 1))), LiveShareState.ended);
      expect(s.remainingAt(t0.add(const Duration(hours: 1))), Duration.zero);
    });

    test('expiry needs no server round trip', () {
      // The case this feature must not get wrong. The row still says
      // `liveShareLive: true` — the scheduled expiry has not run, or its
      // result has not reached this device — and every client stops trusting
      // it at exactly the right second anyway, because the deadline is data.
      final s = live().locationShare!;
      expect(s.liveEndedAt, isNull);
      expect(
        s.stateAt(t0.add(const Duration(hours: 6))),
        LiveShareState.ended,
        reason: 'a lost expiry job must not extend a share',
      );
    });

    test('stopping early ends it before the deadline', () {
      final s = live(endedAt: t0.add(const Duration(minutes: 4)))
          .locationShare!;
      expect(
        s.stateAt(t0.add(const Duration(minutes: 5))),
        LiveShareState.ended,
      );
      expect(s.remainingAt(t0.add(const Duration(minutes: 5))), Duration.zero);
    });

    test('a share stopped early stays ended once its deadline passes', () {
      // Both clauses fire at once here. Ordering them wrong is how a stopped
      // share flickers back to "live" for the caller who asks at the wrong
      // moment.
      final s = live(endedAt: t0.add(const Duration(minutes: 4)))
          .locationShare!;
      expect(
        s.stateAt(t0.add(const Duration(hours: 3))),
        LiveShareState.ended,
      );
    });
  });

  group('staleness', () {
    test('a share updated moments ago is fresh', () {
      final s = live(updatedAt: t0.add(const Duration(minutes: 9))).locationShare!;
      expect(s.isStaleAt(t0.add(const Duration(minutes: 10))), isFalse);
    });

    test('three missed heartbeats is stale', () {
      final s = live(updatedAt: t0).locationShare!;
      expect(s.isStaleAt(t0.add(kLiveStaleAfter + const Duration(seconds: 1))),
          isTrue);
    });

    test('an ended share is finished, not stale', () {
      // Drawing both at once would say neither. "No recent update" on a share
      // that is over reads as a fault; it is simply the end.
      final s = live(updatedAt: t0).locationShare!;
      expect(s.isStaleAt(t0.add(const Duration(hours: 5))), isFalse);
    });
  });

  group('durations', () {
    test('the offered set is exactly the three the server accepts', () {
      // Mirrored in LIVE_SHARE_DURATIONS_MS (backend/convex/messages.ts). A
      // fourth added here without adding it there is silently downgraded to a
      // static pin by the server, which is the failure this pins.
      expect(
        LiveShareDuration.values.map((d) => d.milliseconds).toList(),
        [15 * 60 * 1000, 60 * 60 * 1000, 8 * 60 * 60 * 1000],
      );
    });
  });

  group('formatting and geometry', () {
    test('coordinates print at metre precision', () {
      expect(formatCoordinates(41.0138, 28.9497), '41.01380, 28.94970');
    });

    test('haversine measures a short hop', () {
      // ~111.32 m per 0.001° of latitude, anywhere.
      final d = haversineMeters(41.0, 29.0, 41.001, 29.0);
      expect(d, closeTo(111.3, 1.0));
    });

    test('haversine is longitude-correct away from the equator', () {
      // The reason it is haversine and not a flat approximation: at 60°N a
      // degree of longitude is half a degree of latitude, and the cheap version
      // is wrong by that factor exactly where people live.
      final d = haversineMeters(60.0, 10.0, 60.0, 10.001);
      expect(d, closeTo(55.7, 1.0));
    });
  });

  group('preview scale', () {
    test('an unknown accuracy gets a street-level view', () {
      expect(spanMetersFor(null), 250);
      expect(spanMetersFor(0), 250);
    });

    test('a good fix does not zoom in past the floor', () {
      // Six times 5 m is 30 m, which would be a view of one doorway — more
      // precision than the fix supports and more than the card can label.
      expect(spanMetersFor(5), 250);
    });

    test('a vague fix widens the view so the ring fits inside it', () {
      expect(spanMetersFor(200), 1200);
    });

    test('a catastrophic fix is clamped rather than zooming to a continent', () {
      expect(spanMetersFor(50000), 6000);
    });

    test('the graticule step keeps the grid legible at every span', () {
      for (final span in [250.0, 600.0, 1200.0, 6000.0]) {
        final step = graticuleStepMeters(span);
        expect(span / step, lessThanOrEqualTo(8),
            reason: 'span $span would draw too many lines');
        expect(span / step, greaterThan(1),
            reason: 'span $span would draw no grid at all');
      }
    });

    test('the step is always a round number a scale bar can print', () {
      for (final span in [250.0, 400.0, 900.0, 3000.0, 6000.0]) {
        final step = graticuleStepMeters(span);
        final mantissa = step / largestPowerOfTenAtMost(step);
        expect([1.0, 2.0, 5.0], contains(mantissa),
            reason: '$step is not on the 1-2-5 ladder');
      }
    });
  });
}

/// Largest power of ten not exceeding [v] — for asserting the 1-2-5 ladder
/// without importing `dart:math` into the expectations.
double largestPowerOfTenAtMost(double v) {
  var p = 1.0;
  while (p * 10 <= v) {
    p *= 10;
  }
  return p;
}
