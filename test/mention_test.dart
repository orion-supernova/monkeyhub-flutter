import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/mention.dart';

/// The three pure halves of @-mentions: finding them in sent text, deciding
/// whether the caret is inside one, and ordering the picker.
///
/// All of it is deliberately Flutter-free so these run as plain unit tests —
/// the detector is on the render path of every text bubble, so it needs to be
/// cheap to re-check.
ChatUser _user(
  String id,
  String username, {
  String name = '',
  String? role,
  String? status,
}) =>
    ChatUser(
      id: id,
      username: username,
      name: name,
      role: role,
      status: status,
    );

void main() {
  group('MentionDetector', () {
    test('finds a handle and reports its exact span', () {
      final m = MentionDetector.matches(
        'hey @murat look',
        usernameById: {'u1': 'murat'},
      );
      expect(m, hasLength(1));
      expect(m.single.userId, 'u1');
      expect(m.single.start, 4);
      expect(m.single.end, 10);
      expect('hey @murat look'.substring(m.single.start, m.single.end), '@murat');
    });

    test('ignores a handle the message never claimed', () {
      // The id array is the truth. Typing someone's handle by hand is just
      // text, or every "@bob" in prose would light up.
      expect(
        MentionDetector.matches('hey @bob', usernameById: const {}),
        isEmpty,
      );
    });

    test('prefers the longer handle when one is a prefix of the other', () {
      final m = MentionDetector.matches(
        '@bobby hi',
        usernameById: {'u1': 'bob', 'u2': 'bobby'},
      );
      expect(m.single.userId, 'u2');
      expect(m.single.end, 6);
    });

    test('will not match a short handle inside a longer word', () {
      // Only Bob is mentioned, but the text says "bobby" — highlighting the
      // first three letters of someone else's name is worse than nothing.
      expect(
        MentionDetector.matches('@bobby hi', usernameById: {'u1': 'bob'}),
        isEmpty,
      );
    });

    test('handles a username containing a space', () {
      // Signup only trims and de-duplicates, so this is a legal handle and a
      // pattern-based parser would clip it in half.
      final m = MentionDetector.matches(
        'ping @john smith now',
        usernameById: {'u1': 'john smith'},
      );
      expect(m.single.userId, 'u1');
      expect('ping @john smith now'.substring(m.single.start, m.single.end),
          '@john smith');
    });

    test('does not fire on an email address', () {
      expect(
        MentionDetector.matches(
          'write to bob@murat.com',
          usernameById: {'u1': 'murat'},
        ),
        isEmpty,
      );
    });

    test('finds several mentions in order, without overlapping', () {
      final m = MentionDetector.matches(
        '@a and @b',
        usernameById: {'u1': 'a', 'u2': 'b'},
      );
      expect(m.map((e) => e.userId), ['u1', 'u2']);
      expect(m[0].end, lessThanOrEqualTo(m[1].start));
    });

    test('matches @everyone only when it is armed', () {
      expect(
        MentionDetector.matches('@everyone hi', usernameById: const {}),
        isEmpty,
      );
      final m = MentionDetector.matches(
        '@everyone hi',
        usernameById: const {},
        everyone: true,
      );
      expect(m.single.isEveryone, isTrue);
      expect(m.single.userId, isNull);
    });

    test('a member who owns the handle "everyone" outranks the broadcast', () {
      final m = MentionDetector.matches(
        '@everyone hi',
        usernameById: {'u1': 'everyone'},
        everyone: true,
      );
      expect(m.single.userId, 'u1');
    });

    test('survivingIds drops a mention the user has edited away', () {
      const handles = {'u1': 'murat'};
      expect(MentionDetector.survivingIds('hi @murat', usernameById: handles),
          {'u1'});
      // One backspace and it is no longer that person's handle.
      expect(MentionDetector.survivingIds('hi @mura', usernameById: handles),
          isEmpty);
    });
  });

  group('MentionQuery.activeAt', () {
    test('opens at the start of the text', () {
      final q = MentionQuery.activeAt('@mu', 3);
      expect(q, isNotNull);
      expect(q!.atIndex, 0);
      expect(q.query, 'mu');
    });

    test('opens after whitespace, and reports an empty query at the @', () {
      final q = MentionQuery.activeAt('hey @', 5);
      expect(q!.atIndex, 4);
      expect(q.query, '');
    });

    test('stays closed mid-word', () {
      expect(MentionQuery.activeAt('bob@mu', 6), isNull);
    });

    test('stays closed inside a URL', () {
      const t = 'see https://x.com/@murat';
      expect(MentionQuery.activeAt(t, t.length), isNull);
    });

    test('spans a space so "john sm" still reaches John Smith', () {
      final q = MentionQuery.activeAt('@john sm', 8);
      expect(q!.query, 'john sm');
    });

    test('does not reach back past a newline', () {
      expect(MentionQuery.activeAt('@bob\nhello', 10), isNull);
    });

    test('gives up on a stale @ far behind the caret', () {
      final text = '@${'x' * (MentionQuery.maxQueryLength + 5)}';
      expect(MentionQuery.activeAt(text, text.length), isNull);
    });

    test('is null when the caret sits before the @', () {
      expect(MentionQuery.activeAt('hey @bob', 3), isNull);
    });
  });

  group('rankMembers', () {
    test('empty query lists everyone, owner first then online', () {
      final ranked = rankMembers([
        _user('3', 'cara', status: 'offline'),
        _user('2', 'bea', status: 'online'),
        _user('1', 'al', role: 'owner', status: 'offline'),
      ], '');
      expect(ranked.map((u) => u.id), ['1', '2', '3']);
    });

    test('a handle prefix beats a name prefix', () {
      final ranked = rankMembers([
        _user('name', 'zed', name: 'Mura Jones'),
        _user('handle', 'murat'),
      ], 'mur');
      expect(ranked.first.id, 'handle');
    });

    test('a prefix beats a mere substring', () {
      final ranked = rankMembers([
        _user('sub', 'amurat'),
        _user('pre', 'murat'),
      ], 'mur');
      expect(ranked.map((u) => u.id), ['pre', 'sub']);
    });

    test('matches a word boundary inside a display name', () {
      final ranked = rankMembers([_user('1', 'jd', name: 'John Smith')], 'smi');
      expect(ranked, hasLength(1));
    });

    test('drops non-matches and the sender', () {
      final ranked = rankMembers(
        [_user('me', 'murat'), _user('you', 'murad'), _user('no', 'zed')],
        'mura',
        excludeUserId: 'me',
      );
      expect(ranked.map((u) => u.id), ['you']);
    });

    test('is case-insensitive', () {
      final ranked = rankMembers([_user('1', 'Murat')], 'MUR');
      expect(ranked, hasLength(1));
    });
  });
}
