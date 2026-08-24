import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/speaker_colors.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Holds the per-speaker colour system to the two things it actually promises:
/// that a person's colour does not move, and that whatever colour they get is
/// still readable on all thirteen themes.
///
/// Both are invisible failures. A colour that reshuffles when someone joins
/// looks fine in every screenshot and only breaks the thing the feature is for
/// — recognising a speaker WITHOUT reading the name — and a hue that lands at
/// 2:1 against a cream background is perfectly legible on the dark theme it
/// was eyeballed on.
void main() {
  SpeakerMember m(String id, int joinedAt) => (id: id, joinedAt: joinedAt);

  group('assignment', () {
    test('is a pure function of the roster, not of its order', () {
      final roster = [m('alice', 10), m('bob', 20), m('carol', 30)];
      final forward = SpeakerSlots.forMembers(roster);
      final backward = SpeakerSlots.forMembers(roster.reversed);
      for (final u in roster) {
        expect(forward.slotOf(u.id), backward.slotOf(u.id),
            reason: '${u.id} moved when the roster arrived in a different '
                'order — every client would see different colours');
      }
    });

    test('a new member never takes an existing one\'s colour', () {
      final founding = [
        for (var i = 0; i < 9; i++) m('user_$i', 100 + i),
      ];
      final before = SpeakerSlots.forMembers(founding);
      // Joins last in time but FIRST alphabetically — the shape that would
      // cascade the room if ordering fell back to id.
      final after = SpeakerSlots.forMembers([...founding, m('aaa', 999)]);
      for (final u in founding) {
        expect(after.slotOf(u.id), before.slotOf(u.id),
            reason: '${u.id} changed colour because someone else joined');
      }
      expect(after.slotOf('aaa'), isNotNull);
    });

    test('a full room hands out twelve distinct colours', () {
      final roster = [for (var i = 0; i < 12; i++) m('member_$i', i)];
      final slots = SpeakerSlots.forMembers(roster);
      final assigned = {for (final u in roster) slots.slotOf(u.id)};
      expect(assigned.length, 12);
    });

    test('past twelve it starts a fresh band rather than piling up', () {
      final roster = [for (var i = 0; i < 25; i++) m('member_$i', i)];
      final slots = SpeakerSlots.forMembers(roster);
      final counts = <int, int>{};
      for (final u in roster) {
        counts.update(slots.slotOf(u.id)!, (n) => n + 1, ifAbsent: () => 1);
      }
      // 25 people over 12 colours: two full bands plus one. Nobody should be
      // wearing a colour three deep while another colour goes unused.
      expect(counts.length, 12);
      expect(counts.values.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(3));
    });

    test('the viewer is left out, and so is everyone not in the room', () {
      final slots = SpeakerSlots.forMembers(
        [m('me', 1), m('them', 2)],
        exclude: 'me',
      );
      expect(slots.slotOf('me'), isNull);
      expect(slots.slotOf('them'), isNotNull);
      expect(slots.slotOf('a-stranger'), isNull);
      expect(slots.slotOf(null), isNull);
    });

    test('a preferred slot travels with the id, between rooms and launches', () {
      // Alone in two different rooms, one person gets the same colour in both
      // — which is what makes a colour feel like it belongs to them.
      final roomA = SpeakerSlots.forMembers([m('dana', 5)]);
      final roomB = SpeakerSlots.forMembers([m('dana', 900), m('eve', 901)]);
      expect(roomA.slotOf('dana'), speakerPreferredSlot('dana'));
      expect(roomB.slotOf('dana'), speakerPreferredSlot('dana'));
    });

    test('a pin wins, and closes its colour to everyone automatic', () {
      // Nine people, one of them pinned onto the slot somebody else's hash
      // wanted. The pin is not a preference that loses a tiebreak.
      final roster = [for (var i = 0; i < 9; i++) m('user_$i', 100 + i)];
      final contested = speakerPreferredSlot('user_3');
      final slots = SpeakerSlots.forMembers(
        roster,
        pinned: {'user_7': contested},
      );
      expect(slots.slotOf('user_7'), contested);
      expect(slots.slotOf('user_3'), isNot(contested),
          reason: 'an automatic member was left sitting on a pinned colour');
      expect(slots.holdersOf(contested), ['user_7']);
    });

    test('two people pinned to one colour is honoured, not corrected', () {
      // A reader is allowed to decide they do not need to tell two people
      // apart. A picker that silently moved the second one would be overruling
      // the person it is for — the UI states the overlap instead.
      final roster = [m('a', 1), m('b', 2), m('c', 3)];
      final slots = SpeakerSlots.forMembers(roster, pinned: {'a': 5, 'b': 5});
      expect(slots.slotOf('a'), 5);
      expect(slots.slotOf('b'), 5);
      expect(slots.holdersOf(5)..sort(), ['a', 'b']);
      expect(slots.slotOf('c'), isNot(5),
          reason: 'the automatic third should still steer clear');
    });

    test('a pin on somebody who has left holds nothing shut', () {
      // The server sweeps these rows on departure; this is the window before
      // that lands, and the failure it prevents is a colour reserved forever
      // for a person who cannot speak.
      final roster = [m('a', 1), m('b', 2)];
      final slots =
          SpeakerSlots.forMembers(roster, pinned: {'ghost': 4, 'a': 9});
      expect(slots.slotOf('ghost'), isNull);
      expect(slots.slotOf('a'), 9);
      // 4 is free again, so whoever wants it may have it.
      final crowd = SpeakerSlots.forMembers(
        [for (var i = 0; i < 12; i++) m('u_$i', i)],
        pinned: const {'ghost': 4},
      );
      expect(crowd.holdersOf(4).length, 1);
    });

    test('the viewer cannot be pinned, and a wild slot is folded in range', () {
      final slots = SpeakerSlots.forMembers(
        [m('me', 1), m('them', 2)],
        exclude: 'me',
        pinned: const {'me': 3, 'them': kSpeakerSlotCount + 2},
      );
      expect(slots.slotOf('me'), isNull);
      expect(slots.slotOf('them'), 2,
          reason: 'a server or a future client sending a slot past the '
              'palette must not paint out of range');
    });

    test('pinning nobody is exactly the unpinned assignment', () {
      // The cheap path has to stay the same path — most rooms will never hold
      // a single override, and a divergence here would be invisible.
      final roster = [for (var i = 0; i < 15; i++) m('user_$i', i)];
      final plain = SpeakerSlots.forMembers(roster);
      final empty = SpeakerSlots.forMembers(roster, pinned: const {});
      expect(plain, empty);
    });

    test('an empty roster is the no-colours room', () {
      expect(SpeakerSlots.forMembers(const []).isEmpty, isTrue);
      expect(SpeakerSlots.none.slotOf('anyone'), isNull);
    });
  });

  group('palette', () {
    // Every theme, not the one that happened to be on screen — the light ones
    // (Daylight, Ivory, Risograph) are the ones a dark-theme eyeball misses.
    final themes = ThemeController.all;

    test('names clear WCAG AA on the ground they are written on', () {
      final failures = <String>[];
      for (final theme in themes) {
        for (var slot = 0; slot < kSpeakerSlotCount; slot++) {
          final ink = theme.speakerInk(slot, on: theme.background);
          final ratio = speakerContrast(ink, theme.background);
          if (ratio < 4.5) {
            failures.add('${theme.id} slot $slot: '
                '${ratio.toStringAsFixed(2)}:1 on background');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('marks clear the 3:1 floor for a non-text object', () {
      final failures = <String>[];
      for (final theme in themes) {
        for (var slot = 0; slot < kSpeakerSlotCount; slot++) {
          final mark = theme.speakerMark(slot, on: theme.background);
          final ratio = speakerContrast(mark, theme.background);
          if (ratio < 3.0) {
            failures.add('${theme.id} slot $slot: '
                '${ratio.toStringAsFixed(2)}:1 on background');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('quote-card ink clears AA on a raised surface too', () {
      // Where the four reply designs draw the quoted author's name.
      final failures = <String>[];
      for (final theme in themes) {
        final ground = theme.surfaceRaised.a >= 1.0
            ? theme.surfaceRaised
            : Color.alphaBlend(theme.surfaceRaised, theme.background);
        for (var slot = 0; slot < kSpeakerSlotCount; slot++) {
          final ink = theme.speakerInk(slot, on: theme.surfaceRaised);
          final ratio = speakerContrast(ink, ground);
          if (ratio < 4.5) {
            failures.add('${theme.id} slot $slot: '
                '${ratio.toStringAsFixed(2)}:1 on surfaceRaised');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('the bubble wash never costs the message its legibility', () {
      // The one way this feature could make the app WORSE: tinting the fill a
      // sender's words are printed on until the words stop reading.
      final failures = <String>[];
      for (final theme in themes) {
        final authored =
            theme.messageBubbleDecoration(isMine: false, ephemeral: false);
        final fill = authored.color;
        if (fill == null) continue;
        final plain = speakerContrast(
          theme.ink,
          fill.a >= 1.0 ? fill : Color.alphaBlend(fill, theme.background),
        );
        for (var slot = 0; slot < kSpeakerSlotCount; slot++) {
          final washed = theme.speakerWash(slot, surface: fill);
          final ratio = speakerContrast(theme.ink, washed);
          if (ratio < 4.5) {
            failures.add('${theme.id} slot $slot: body ink at '
                '${ratio.toStringAsFixed(2)}:1 over the wash '
                '(${plain.toStringAsFixed(2)}:1 untinted)');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('the wash actually moves the fill — it is not a no-op', () {
      // The opposite failure to the one above, and just as quiet: an alpha
      // tuned down until the feature does nothing but still passes contrast.
      for (final theme in themes) {
        final fill =
            theme.messageBubbleDecoration(isMine: false, ephemeral: false).color;
        if (fill == null) continue;
        final base = fill.a >= 1.0
            ? fill
            : Color.alphaBlend(fill, theme.background);
        for (var slot = 0; slot < kSpeakerSlotCount; slot++) {
          final washed = theme.speakerWash(slot, surface: fill);
          final distance = (washed.r - base.r).abs() +
              (washed.g - base.g).abs() +
              (washed.b - base.b).abs();
          expect(distance, greaterThan(0.02),
              reason: '${theme.id} slot $slot: the wash is invisible');
        }
      }
    });

    test('neighbouring slots do not look alike', () {
      // Collisions probe FORWARD, so slot n and slot n+1 are the two colours
      // most likely to end up side by side in one room.
      for (final theme in themes) {
        for (var slot = 0; slot < kSpeakerSlotCount; slot++) {
          final a = HSLColor.fromColor(
              theme.speakerMark(slot, on: theme.background));
          final b = HSLColor.fromColor(theme.speakerMark(
              (slot + 1) % kSpeakerSlotCount,
              on: theme.background));
          var delta = (a.hue - b.hue).abs();
          if (delta > 180) delta = 360 - delta;
          expect(delta, greaterThan(60),
              reason: '${theme.id}: slots $slot and ${slot + 1} are only '
                  '${delta.toStringAsFixed(0)}° apart');
        }
      }
    });

    test('a theme with a washed-out accent still differentiates', () {
      // Vault Noir is the one that would degrade to twelve greys if the
      // saturation floor ever came out.
      final noir = ThemeController.all.firstWhere((t) => t.id.contains('noir'));
      final hues = {
        for (var slot = 0; slot < kSpeakerSlotCount; slot++)
          HSLColor.fromColor(noir.speakerMark(slot, on: noir.background))
              .saturation,
      };
      expect(hues.every((s) => s >= 0.4), isTrue,
          reason: 'noir speakers came out unsaturated: $hues');
    });
  });
}
