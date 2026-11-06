import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/push/alert_burst.dart';
import 'package:monkeyhub/push/banner_composer.dart';

void main() {
  BannerCard dm(BannerComposer c, String text, {String? sender}) => c.add(
        roomId: 'dm',
        isDm: true,
        title: 'Ada',
        text: text,
        sender: sender,
        peerAvatar: 'ada.png',
      );

  BannerCard grp(BannerComposer c, String sender, String text) => c.add(
        roomId: 'g',
        isDm: false,
        title: 'Weekend plans',
        text: text,
        sender: sender,
        roomAvatar: 'room.png',
        senderAvatar: '$sender.png',
      );

  test('a DM is titled by the person and its lines are bare', () {
    final c = BannerComposer();
    dm(c, 'hi', sender: 'Ada');
    final card = dm(c, 'you there?', sender: 'Ada');
    expect(card.title, 'Ada');
    expect(card.lines, ['hi', 'you there?']);
    expect(card.body, 'hi\nyou there?');
  });

  test('a group is titled by the room and attributes each line', () {
    final c = BannerComposer();
    grp(c, 'Ada', 'lunch?');
    final card = grp(c, 'Bo', 'yes');
    expect(card.title, 'Weekend plans');
    expect(card.lines, ['Ada: lunch?', 'Bo: yes']);
  });

  test('a group line with an unknown sender stays bare', () {
    final c = BannerComposer();
    final card = c.add(
        roomId: 'g', isDm: false, title: 'G', text: 'hello', sender: null);
    expect(card.lines, ['hello']);
  });

  test('lines accumulate up to the cap, newest last', () {
    final c = BannerComposer();
    late BannerCard card;
    for (var i = 1; i <= 8; i++) {
      card = dm(c, 'm$i');
    }
    expect(card.lines, ['m4', 'm5', 'm6', 'm7', 'm8']);
    expect(card.lines.length, BannerComposer.maxLines);
  });

  test('rooms keep separate cards', () {
    final c = BannerComposer();
    dm(c, 'one');
    grp(c, 'Ada', 'two');
    expect(c.current('dm')!.lines, ['one']);
    expect(c.current('g')!.lines, ['Ada: two']);
  });

  test('reading a room starts the next card fresh', () {
    final c = BannerComposer();
    dm(c, 'old');
    c.reset('dm');
    expect(c.current('dm'), isNull);
    expect(dm(c, 'new').lines, ['new']);
  });

  test('replace keeps a single line, for secret rooms', () {
    final c = BannerComposer();
    for (var i = 0; i < 3; i++) {
      c.add(
          roomId: 's',
          isDm: false,
          title: 'S',
          text: 'Open the app',
          replace: true);
    }
    expect(c.current('s')!.lines, ['Open the app']);
  });

  group('avatar choice', () {
    test('a DM wears the partner, then the sender', () {
      expect(BannerComposer.pickAvatar(isDm: true, peer: 'p', sender: 's'), 'p');
      expect(BannerComposer.pickAvatar(isDm: true, sender: 's'), 's');
      expect(BannerComposer.pickAvatar(isDm: true, peer: ''), isNull);
    });

    test('a group wears its own picture, then the sender', () {
      expect(BannerComposer.pickAvatar(isDm: false, room: 'r', sender: 's'), 'r');
      expect(BannerComposer.pickAvatar(isDm: false, room: '', sender: 's'), 's');
      expect(BannerComposer.pickAvatar(isDm: false), isNull);
    });

    test('the card carries the chosen face', () {
      final c = BannerComposer();
      expect(dm(c, 'x').avatarStorageId, 'ada.png');
      expect(grp(c, 'Bo', 'x').avatarStorageId, 'room.png');
    });
  });

  // The burst rule decides loudness; the composer must keep stacking lines
  // through the quiet ones so nothing is lost by being silent.
  test('a burst alerts once while every line still lands on the card', () {
    final c = BannerComposer();
    final burst = AlertBurst();
    final t0 = DateTime(2026, 11, 6, 12);
    final loud = <bool>[];
    late BannerCard card;
    for (var i = 0; i < 4; i++) {
      loud.add(burst.shouldAlert('dm', t0.add(Duration(seconds: i * 5))));
      card = dm(c, 'm$i');
    }
    expect(loud, [true, false, false, false]);
    expect(card.lines, ['m0', 'm1', 'm2', 'm3']);
  });
}
