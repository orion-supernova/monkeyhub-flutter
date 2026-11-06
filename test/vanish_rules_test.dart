import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/privacy/vanish_rules.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/vanish_palette.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';
import 'package:monkeyhub/widgets/vanish_card.dart';

/// Vanish mode's client rules, as tables. Nothing here pumps a widget.
void main() {
  final t0 = DateTime(2026, 11, 6, 12, 0, 0);

  ChatRoom room({
    bool vanish = false,
    RoomType type = RoomType.regular,
    String? clock,
  }) =>
      ChatRoom(
        id: 'r',
        name: 'R',
        createdBy: 'a',
        createdAt: t0,
        isPrivate: false,
        memberCount: 2,
        type: type,
        messageClock: clock,
        vanishMode: vanish,
      );

  ChatMessage msg(String id, String sender, DateTime at, {bool vanishing = true}) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: sender,
        senderName: sender,
        content: 'hi $id',
        createdAt: at,
        vanishUntil: vanishing ? at.add(const Duration(hours: 24)) : null,
      );

  group('markRoomRead arguments', () {
    test('an ordinary room sends nothing new', () {
      for (final protects in [true, false]) {
        expect(
          vanishReadArgs(
            room: room(),
            prefs: const VanishPrefs(),
            platformProtects: protects,
          ),
          isNull,
        );
      }
      expect(
        vanishReadArgs(room: null, prefs: null, platformProtects: true),
        isNull,
      );
    });

    test('a secret room counts only on a seen clock', () {
      final seen = room(type: RoomType.secret, clock: 'seen');
      final sent = room(type: RoomType.secret, clock: 'sent');
      expect(isVanishReadRoom(seen), isTrue);
      expect(isVanishReadRoom(sent), isFalse);
    });

    // seen visibility x global x perChat, on a protecting platform.
    final matrix = <(String seen, bool global, bool? perChat, bool counts)>[
      ('friends', false, null, true),
      ('public', false, null, true),
      ('friends', false, false, true), // not hiding: a "no" here changes nothing
      ('nobody', false, null, false),
      ('nobody', false, false, false),
      ('nobody', false, true, true),
      ('nobody', true, null, true),
      ('nobody', true, false, true), // the global switch wins
      ('nobody', true, true, true),
    ];
    for (final (seen, global, perChat, counts) in matrix) {
      test('seen=$seen global=$global perChat=$perChat -> counts=$counts', () {
        final args = vanishReadArgs(
          room: room(vanish: true),
          prefs: VanishPrefs(seen: seen, global: global, perChat: perChat),
          platformProtects: true,
        );
        expect(args, isNotNull);
        expect(args!.vanish, isTrue);
        expect(args.vanishCounts, counts);
      });
    }

    test('unknown prefs never count', () {
      final args = vanishReadArgs(
        room: room(vanish: true),
        prefs: null,
        platformProtects: true,
      );
      expect(args!.vanishCounts, isFalse);
    });

    test('where screenshots cannot be blocked a read never counts', () {
      final args = vanishReadArgs(
        room: room(vanish: true),
        prefs: const VanishPrefs(seen: 'public', global: true, perChat: true),
        platformProtects: false,
      );
      expect(args!.vanish, isTrue);
      expect(args.vanishCounts, isFalse);
    });
  });

  group('read cursor on a platform that seals', () {
    final a = msg('a', 'zeynep', t0, vanishing: false);
    final b = msg('b', 'zeynep', t0.add(const Duration(minutes: 1)));
    final c = msg('c', 'zeynep', t0.add(const Duration(minutes: 2)),
        vanishing: false);
    final mineSealed = msg('m', 'me', t0.add(const Duration(seconds: 1)));

    test('protecting platforms pass the cursor through', () {
      expect(
        readCursorFor(
            upTo: c.createdAt, messages: [a, b, c], me: 'me', platformProtects: true),
        c.createdAt,
      );
    });

    test('never passes the oldest sealed message', () {
      final cursor = readCursorFor(
        upTo: c.createdAt,
        messages: [a, b, c],
        me: 'me',
        platformProtects: false,
      );
      expect(cursor!.isBefore(b.createdAt), isTrue);
      expect(cursor.isAfter(a.createdAt), isTrue);
    });

    test('a cursor already before the sealed one is untouched', () {
      expect(
        readCursorFor(
            upTo: a.createdAt, messages: [a, b, c], me: 'me', platformProtects: false),
        a.createdAt,
      );
    });

    test('my own vanishing messages are not sealed against me', () {
      expect(
        readCursorFor(
            upTo: c.createdAt,
            messages: [a, mineSealed, c],
            me: 'me',
            platformProtects: false),
        c.createdAt,
      );
    });

    test('no cursor still holds back at the sealed one', () {
      final cursor = readCursorFor(
          upTo: null, messages: [b], me: 'me', platformProtects: false);
      expect(cursor, isNotNull);
      expect(cursor!.isBefore(b.createdAt), isTrue);
    });

    test('nothing sealed: unchanged, null stays null', () {
      expect(
        readCursorFor(upTo: null, messages: [a, c], me: 'me', platformProtects: false),
        isNull,
      );
    });
  });

  group('ring or clock', () {
    final burnAt = t0.add(const Duration(seconds: 10));
    final state = VanishState(
      active: true,
      afterSeen: 10,
      burnAt: burnAt,
      burnUpTo: t0.add(const Duration(minutes: 5)),
      mineUpTo: t0.add(const Duration(minutes: 8)),
    );

    test('a normal message has neither', () {
      expect(
        vanishStampKind(
            message: msg('a', 'x', t0, vanishing: false), isMine: false, state: state),
        VanishStampKind.none,
      );
    });

    test('no burn pending: the 24h clock', () {
      expect(
        vanishStampKind(message: msg('a', 'x', t0), isMine: false, state: null),
        VanishStampKind.clock,
      );
      expect(
        vanishStampKind(
            message: msg('a', 'x', t0),
            isMine: false,
            state: const VanishState(active: true, afterSeen: 10)),
        VanishStampKind.clock,
      );
    });

    test('inside burnUpTo: the ring, mine or theirs', () {
      final m = msg('a', 'x', t0.add(const Duration(minutes: 5)));
      expect(vanishStampKind(message: m, isMine: false, state: state),
          VanishStampKind.ring);
      expect(vanishStampKind(message: m, isMine: true, state: state),
          VanishStampKind.ring);
    });

    test('past burnUpTo: the clock', () {
      final m = msg('a', 'x', t0.add(const Duration(minutes: 6)));
      expect(vanishStampKind(message: m, isMine: false, state: state),
          VanishStampKind.clock);
    });

    test('mineUpTo reaches only MY messages', () {
      final m = msg('a', 'x', t0.add(const Duration(minutes: 7)));
      expect(vanishStampKind(message: m, isMine: true, state: state),
          VanishStampKind.ring);
      expect(vanishStampKind(message: m, isMine: false, state: state),
          VanishStampKind.clock);
      final beyond = msg('b', 'x', t0.add(const Duration(minutes: 9)));
      expect(vanishStampKind(message: beyond, isMine: true, state: state),
          VanishStampKind.clock);
    });

    test('the ring drains linearly from afterSeen to the burn', () {
      expect(vanishRingRemaining(state, burnAt.subtract(const Duration(seconds: 10))), 1);
      expect(
          vanishRingRemaining(state, burnAt.subtract(const Duration(seconds: 5))),
          closeTo(0.5, 1e-9));
      expect(vanishRingRemaining(state, burnAt), 0);
      expect(vanishRingRemaining(state, burnAt.add(const Duration(seconds: 3))), 0);
    });

    test('state parses from the wire', () {
      final s = VanishState.fromJson({
        'active': true,
        'afterSeen': 60,
        'burnAt': burnAt.millisecondsSinceEpoch,
        'burnUpTo': null,
        'mineUpTo': 5,
      });
      expect(s!.afterSeen, 60);
      expect(s.burnAt, burnAt);
      expect(s.burnUpTo, isNull);
      expect(s.mineUpTo, DateTime.fromMillisecondsSinceEpoch(5));
      expect(VanishState.fromJson(null), isNull);
    });
  });

  group('hidden-seen card', () {
    bool shown({
      bool on = true,
      VanishPrefs? prefs = const VanishPrefs(seen: 'nobody'),
      bool answered = false,
    }) =>
        showHiddenSeenCard(vanishOn: on, prefs: prefs, answeredHere: answered);

    test('shows when vanish is on, seen hidden, no global, no answer', () {
      expect(shown(), isTrue);
    });
    test('hidden when any condition fails', () {
      expect(shown(on: false), isFalse);
      expect(shown(prefs: null), isFalse);
      expect(shown(prefs: const VanishPrefs(seen: 'friends')), isFalse);
      expect(shown(prefs: const VanishPrefs(seen: 'nobody', global: true)), isFalse);
      expect(shown(prefs: const VanishPrefs(seen: 'nobody', perChat: true)), isFalse);
      expect(shown(prefs: const VanishPrefs(seen: 'nobody', perChat: false)), isFalse);
      expect(shown(answered: true), isFalse);
    });
  });

  group('system lines', () {
    test('parse', () {
      expect(VanishLine.parse('vanish:on:10')!.kind, VanishLineKind.on);
      expect(VanishLine.parse('vanish:on:10')!.seconds, 10);
      expect(VanishLine.parse('vanish:change:3600')!.kind, VanishLineKind.change);
      expect(VanishLine.parse('vanish:change:3600')!.seconds, 3600);
      expect(VanishLine.parse('vanish:off')!.kind, VanishLineKind.off);
      expect(VanishLine.parse('vanish:on'), isNull);
      expect(VanishLine.parse('vanish:wat:1'), isNull);
      expect(VanishLine.parse('joined'), isNull);
    });

    test('text', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      String text(String c, [String who = 'Murat']) =>
          vanishLineText(l10n, VanishLine.parse(c)!, name: who);
      expect(
        text('vanish:on:10'),
        'Murat turned on vanish mode. New messages disappear 10 seconds after '
        'everyone has seen them, or after 24 hours at most. Screenshots are blocked.',
      );
      expect(text('vanish:on:60', 'You'), contains('You turned on vanish mode'));
      expect(text('vanish:on:60'), contains('1 minute after everyone'));
      expect(text('vanish:change:3600'),
          'Murat changed vanish mode. New messages disappear 1 hour after everyone has seen them.');
      expect(text('vanish:off'), startsWith('Murat turned off vanish mode.'));
      expect(text('vanish:off'), isNot(contains('—')));
    });
  });

  group('menu gating', () {
    ChatMessage plain({DateTime? vanishUntil, MessageType type = MessageType.text}) =>
        ChatMessage(
          id: 'm1',
          roomId: 'r',
          senderId: 'alice',
          senderName: 'alice',
          content: 'hey',
          createdAt: t0,
          type: type,
          vanishUntil: vanishUntil,
          latitude: type == MessageType.location ? 1 : null,
          longitude: type == MessageType.location ? 2 : null,
        );
    MessageCapabilities caps(ChatMessage m) => messageCapabilitiesFor(
          message: m,
          isMine: false,
          room: RoomCapabilities.dm,
          roomIsEphemeral: false,
          serverNow: t0,
        );

    test('an ordinary message keeps copy, forward and save', () {
      final c = caps(plain());
      expect(c.canCopy, isTrue);
      expect(c.canForward, isTrue);
      expect(c.canSave, isTrue);
    });

    test('a vanishing message loses copy, forward, save, pin and translate', () {
      final c = caps(plain(vanishUntil: t0.add(const Duration(hours: 24))));
      expect(c.canCopy, isFalse);
      expect(c.canForward, isFalse);
      expect(c.canSave, isFalse);
      expect(c.canPin, isFalse);
      expect(c.canTranslate, isFalse);
      expect(c.canCopyName, isFalse);
      expect(c.canCopyCoordinates, isFalse);
      // Replying stays: the quote travels with its parent and says "Vanished".
      expect(c.canReply, isTrue);
    });
  });

  group('receipts', () {
    test('a vanishing message never reads Seen', () {
      expect(
        messageReceipt(
            isMine: true,
            deliveredToOthers: true,
            seenByOthers: true,
            vanishing: true),
        MessageReceipt.delivered,
      );
      expect(
        messageReceipt(isMine: true, deliveredToOthers: true, seenByOthers: true),
        MessageReceipt.seen,
      );
    });
  });

  group('palette', () {
    test('bubble fill keeps the outgoing ink legible on every theme', () {
      for (final theme in [
        BasicTheme.midnight(),
        BasicTheme.daylight(),
        BasicTheme.graphite(),
        BasicTheme.rose(),
        BasicTheme.forest(),
      ]) {
        final p = VanishPalette(theme);
        final fill = p.bubbleFill;
        final ink = theme.accentInk;
        final hi = fill.computeLuminance() > ink.computeLuminance() ? fill : ink;
        final lo = fill.computeLuminance() > ink.computeLuminance() ? ink : fill;
        final contrast = (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
        expect(contrast, greaterThanOrEqualTo(3.0), reason: theme.id);
      }
    });
  });
}
