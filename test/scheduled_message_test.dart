import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/scheduled_message.dart';

/// The arithmetic behind the schedule sheet's four chips, and the wire split
/// that stops a skewed phone clock from mattering.
///
/// Two things here are easy to get wrong in a way no screenshot would show.
///
/// The first is [SchedulePreset.tomorrowMorning]. It means "the next 9am",
/// which is *today* for anybody awake before nine — so the chip's own label has
/// to follow where it actually lands, or at 2am it promises tomorrow and
/// delivers in seven hours. That is why [SchedulePreset.resolve] takes a `now`
/// instead of reading the clock: the interesting cases are 2am, 11pm and New
/// Year's Eve, and a test that waited for one of those would never run.
///
/// The second is which presets travel as a LENGTH and which as an INSTANT. The
/// relative ones send `delayMs` so the server adds it to its own clock (the
/// `rooms:muteRoom` rule); the wall-clock one cannot, because "morning" only
/// means anything in the sender's timezone. Exactly one of the two wire fields
/// must be set for any preset, and a preset that set both — or neither — is
/// refused by `scheduledMessages:schedule` with an error no user could act on.
void main() {
  group('SchedulePreset.resolve', () {
    test('relative presets are plain offsets from now', () {
      final now = DateTime(2026, 8, 12, 14, 30);
      expect(
        SchedulePreset.inAnHour.resolve(now),
        DateTime(2026, 8, 12, 15, 30),
      );
      expect(
        SchedulePreset.inEightHours.resolve(now),
        DateTime(2026, 8, 12, 22, 30),
      );
      expect(
        SchedulePreset.inAWeek.resolve(now),
        DateTime(2026, 8, 19, 14, 30),
      );
    });

    test('"morning" after 9am means tomorrow', () {
      final now = DateTime(2026, 8, 12, 14, 30);
      expect(
        SchedulePreset.tomorrowMorning.resolve(now),
        DateTime(2026, 8, 13, kScheduleMorningHour),
      );
    });

    test('"morning" before 9am means today — the 2am case', () {
      // The whole reason the chip has two labels. Someone scheduling at 2am
      // means "in seven hours", and a chip reading "Tomorrow morning" would be
      // wrong by a full day about the only thing it claims.
      final now = DateTime(2026, 8, 12, 2, 0);
      expect(
        SchedulePreset.tomorrowMorning.resolve(now),
        DateTime(2026, 8, 12, kScheduleMorningHour),
      );
    });

    test('9am exactly is already gone, so it means tomorrow', () {
      // `isAfter` is strict, deliberately: resolving to the very instant it is
      // now would be a send time in the past by the time the sheet closes.
      final now = DateTime(2026, 8, 12, kScheduleMorningHour);
      expect(
        SchedulePreset.tomorrowMorning.resolve(now),
        DateTime(2026, 8, 13, kScheduleMorningHour),
      );
    });

    test('"morning" rolls the month and the year without a special case', () {
      expect(
        SchedulePreset.tomorrowMorning.resolve(DateTime(2026, 12, 31, 23, 0)),
        DateTime(2027, 1, 1, kScheduleMorningHour),
      );
      expect(
        SchedulePreset.tomorrowMorning.resolve(DateTime(2026, 8, 31, 23, 0)),
        DateTime(2026, 9, 1, kScheduleMorningHour),
      );
    });
  });

  group('wire form', () {
    test('every preset sends exactly one of delayMs and sendAt', () {
      final now = DateTime(2026, 8, 12, 14, 30);
      for (final p in SchedulePreset.values) {
        final delay = p.wireDelayMs;
        final at = p.wireSendAt(now);
        expect(
          (delay == null) != (at == null),
          isTrue,
          reason: '$p must send exactly one of delayMs/sendAt',
        );
      }
    });

    test('relative presets carry a length, not an instant', () {
      expect(SchedulePreset.inAnHour.wireDelayMs, 3600 * 1000);
      expect(SchedulePreset.inEightHours.wireDelayMs, 8 * 3600 * 1000);
      expect(SchedulePreset.inAWeek.wireDelayMs, 7 * 24 * 3600 * 1000);
      expect(SchedulePreset.inAnHour.wireSendAt(DateTime(2026)), isNull);
    });

    test('the wall-clock preset carries the resolved instant', () {
      final now = DateTime(2026, 8, 12, 14, 30);
      expect(SchedulePreset.tomorrowMorning.wireDelayMs, isNull);
      expect(
        SchedulePreset.tomorrowMorning.wireSendAt(now),
        DateTime(2026, 8, 13, kScheduleMorningHour).millisecondsSinceEpoch,
      );
    });
  });

  group('ScheduledMessage', () {
    ScheduledMessage make({
      bool pending = true,
      String? failedReason,
      DateTime? sendAt,
    }) =>
        ScheduledMessage(
          id: 'sm1',
          roomId: 'r1',
          content: 'hello',
          sendAt: sendAt ?? DateTime(2026, 8, 12, 18),
          createdAt: DateTime(2026, 8, 12, 9),
          pending: pending,
          failedReason: failedReason,
        );

    test('a row that is not pending and has a reason has failed', () {
      expect(make().hasFailed, isFalse);
      expect(make(pending: false, failedReason: 'NOT_A_MEMBER').hasFailed,
          isTrue);
      // Not pending and no reason is not a failure — the successful case
      // deletes the row server-side, so this shape only reaches a client from a
      // build that predates the failure path.
      expect(make(pending: false).hasFailed, isFalse);
    });

    test('overdue is a pending row whose time has passed, not an error', () {
      final m = make(sendAt: DateTime(2026, 8, 12, 18));
      expect(m.isOverdueAt(DateTime(2026, 8, 12, 17, 59)), isFalse);
      expect(m.isOverdueAt(DateTime(2026, 8, 12, 18, 0, 1)), isTrue);
      // A failed row is never "overdue": it is not going out at all, and the
      // list has a different thing to say about it.
      expect(
        make(pending: false, failedReason: 'NOT_A_MEMBER')
            .isOverdueAt(DateTime(2026, 8, 12, 19)),
        isFalse,
      );
    });

    test('remaining floors at zero rather than going negative', () {
      final m = make(sendAt: DateTime(2026, 8, 12, 18));
      expect(m.remainingAt(DateTime(2026, 8, 12, 17)), const Duration(hours: 1));
      expect(m.remainingAt(DateTime(2026, 8, 12, 19)), Duration.zero);
    });

    test('round-trips through the wire shape', () {
      final m = ScheduledMessage(
        id: 'sm1',
        roomId: 'r1',
        content: 'hello',
        sendAt: DateTime(2026, 8, 12, 18),
        createdAt: DateTime(2026, 8, 12, 9),
        mentionsEveryone: true,
      );
      expect(ScheduledMessage.fromJson(m.toJson()), m);
    });

    test('a row with no `pending` key reads as pending', () {
      // Absent means true on the wire — the backend only ever writes the field
      // when it is unsetting it, so a row that has never failed simply has no
      // key. An `?? false` here would render every queued message as broken.
      final m = ScheduledMessage.fromJson({
        '_id': 'sm1',
        'roomId': 'r1',
        'content': 'hello',
        'sendAt': DateTime(2026, 8, 12, 18).millisecondsSinceEpoch,
        'createdAt': DateTime(2026, 8, 12, 9).millisecondsSinceEpoch,
      });
      expect(m.pending, isTrue);
      expect(m.hasFailed, isFalse);
    });

    test('retrying clears the failure it is retrying', () {
      final failed = make(pending: false, failedReason: 'NOT_A_MEMBER');
      final retried = failed.copyWith(pending: true);
      expect(retried.hasFailed, isFalse);
      expect(retried.failedReason, isNull);
    });
  });

  test('the client horizon matches what the server will accept', () {
    // Both halves of this pair live in `backend/convex/scheduledMessages.ts`
    // too, and the client is what stops anyone ever meeting the server's
    // refusal. A client that offered more would offer a date the send declines.
    expect(kScheduleMaxHorizon, const Duration(days: 365));
    // Two minutes against the server's one, deliberately: somebody who takes
    // ninety seconds to finish choosing must not be refused for thinking.
    expect(kScheduleMinLead, const Duration(minutes: 2));
    expect(kScheduleMinLead.inMilliseconds, greaterThan(60000));
  });
}
