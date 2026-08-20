import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/invites/invite_link.dart';

/// The invite URL is parsed by four things that must agree exactly: this app,
/// the page at `hosting/invite.template.html`, and the two OS association
/// files whose path patterns decide whether a tap reaches the app at all.
///
/// The failure mode when they disagree is the worst kind of silent: a tapped
/// link opens the browser instead of the app, with no error on the device and
/// nothing in any log. These tests pin the half of that contract that lives in
/// Dart — everything [parseInviteLink] must accept, and, just as important,
/// everything it must refuse.
void main() {
  group('parseInviteLink — the shared https form', () {
    test('reads the code out of the canonical URL', () {
      final link = parseInviteLink('$kInviteSiteUrl/j/K7M2XQ94RB');
      expect(link?.code, 'K7M2XQ94RB');
      expect(link?.serverUrl, isNull);
    });

    test('carries the server tag when the invite names one', () {
      final link = parseInviteLink(
        '$kInviteSiteUrl/j/K7M2XQ94RB?s=https%3A%2F%2Fchat.example.com',
      );
      expect(link?.code, 'K7M2XQ94RB');
      expect(link?.serverUrl, 'https://chat.example.com');
    });

    test('refuses every OTHER path on the same host', () {
      // The whole reason the intent-filter and the AASA use a `/j/` prefix
      // rather than `/`: this host also serves the landing page, the downloads
      // page and the Flutter web app, and an app that swallowed those would be
      // a genuinely baffling thing to debug.
      expect(parseInviteLink('$kInviteSiteUrl/'), isNull);
      expect(parseInviteLink('$kInviteSiteUrl/downloads/'), isNull);
      expect(parseInviteLink('$kInviteSiteUrl/web/'), isNull);
      expect(parseInviteLink('$kInviteSiteUrl/download'), isNull);
    });

    test('refuses a /j/ path with no code, and one with too many segments', () {
      expect(parseInviteLink('$kInviteSiteUrl/j/'), isNull);
      expect(parseInviteLink('$kInviteSiteUrl/j/ABC/DEF'), isNull);
    });
  });

  group('parseInviteLink — the private-scheme fallback', () {
    // A custom scheme has no authority, so `monkeyhub://join/CODE` parses with
    // "join" as the HOST while `monkeyhub:///j/CODE` puts everything in the
    // path. Which one arrives depends on the platform that produced it, so
    // both have to work.
    test('accepts monkeyhub://join/CODE', () {
      expect(parseInviteLink('monkeyhub://join/K7M2XQ94RB')?.code, 'K7M2XQ94RB');
    });

    test('accepts monkeyhub://j/CODE', () {
      expect(parseInviteLink('monkeyhub://j/K7M2XQ94RB')?.code, 'K7M2XQ94RB');
    });

    test('accepts a bare monkeyhub://CODE', () {
      expect(parseInviteLink('monkeyhub://K7M2XQ94RB')?.code, 'K7M2XQ94RB');
    });

    test('keeps the server tag through the scheme form', () {
      final link = parseInviteLink(
        'monkeyhub://join/K7M2XQ94RB?s=https%3A%2F%2Fchat.example.com',
      );
      expect(link?.serverUrl, 'https://chat.example.com');
    });

    test('refuses a scheme path that is not a join', () {
      expect(parseInviteLink('monkeyhub://settings/theme'), isNull);
    });
  });

  group('parseInviteLink — what a person types', () {
    test('accepts a bare code', () {
      expect(parseInviteLink('K7M2XQ94RB')?.code, 'K7M2XQ94RB');
    });

    test('accepts the grouped form the UI shows', () {
      expect(parseInviteLink('K7M2-XQ94-RB')?.code, 'K7M2XQ94RB');
    });

    test('tolerates surrounding whitespace from a paste', () {
      expect(parseInviteLink('  K7M2-XQ94-RB \n')?.code, 'K7M2XQ94RB');
    });

    test('does NOT judge length — the server owns that', () {
      // Duplicating `roomInvites.normalizeCode`'s length rule here would mean
      // a client that rejects a valid code the day the server's format
      // changes. Anything code-shaped is passed through to be judged there.
      expect(parseInviteLink('ABC')?.code, 'ABC');
    });

    test('refuses empty and punctuation-only input', () {
      expect(parseInviteLink(''), isNull);
      expect(parseInviteLink('   '), isNull);
      expect(parseInviteLink('---'), isNull);
    });
  });

  group('inviteUrl', () {
    test('builds the canonical shared form', () {
      expect(inviteUrl('K7M2XQ94RB'), '$kInviteSiteUrl/j/K7M2XQ94RB');
    });

    test('appends an encoded server tag when given one', () {
      expect(
        inviteUrl('K7M2XQ94RB', serverUrl: 'https://chat.example.com'),
        '$kInviteSiteUrl/j/K7M2XQ94RB?s=https%3A%2F%2Fchat.example.com',
      );
    });

    test('round-trips through the parser', () {
      const server = 'https://chat.example.com:8443';
      final parsed = parseInviteLink(inviteUrl('K7M2XQ94RB', serverUrl: server));
      expect(parsed?.code, 'K7M2XQ94RB');
      expect(parsed?.serverUrl, server);
    });
  });
}
