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

  group('parseInviteLink — what the PLATFORM delivers', () {
    // `didPushRouteInformation` reports a LOCATION, not the original URL. The
    // scheme and host are already gone by the time Flutter hands it over, so
    // these two shapes are what actually arrive on a real device — and both
    // crashed or mis-parsed before they were handled.
    test('the https form arrives as a bare /j/<code> path', () {
      expect(parseInviteLink('/j/MUZU4KUP7V')?.code, 'MUZU4KUP7V');
    });

    test('the custom scheme arrives with its host already stripped', () {
      // `monkeyhub://join/CODE` reaches Flutter as `/CODE`.
      expect(parseInviteLink('/MUZU4KUP7V')?.code, 'MUZU4KUP7V');
    });

    test('a /join/<code> path works too', () {
      expect(parseInviteLink('/join/MUZU4KUP7V')?.code, 'MUZU4KUP7V');
    });

    test('does NOT glue the marker onto the code', () {
      // The regression: stripping separators from `/j/ABC` yields `JABC`.
      expect(parseInviteLink('/j/MUZU4KUP7V')?.code, isNot(contains('JM')));
    });

    test('refuses an unrelated path rather than inventing a code', () {
      expect(parseInviteLink('/settings/theme'), isNull);
    });
  });

  group('kExampleInviteCode', () {
    // The rule: an example code must be impossible to mint. The server draws
    // from Crockford base32 (no I, L, O, U) and folds I/L to 1 and O to 0, so
    // U is the one letter that is neither produced nor produced-by-typo.
    //
    // Without this, a placeholder that merely LOOKS like a code eventually is
    // somebody's code, and every screenshot of it is a working key to a
    // private room.
    test('contains a U, so it can never be a minted code', () {
      expect(kExampleInviteCode.contains('U'), isTrue);
    });

    test('survives normalization still containing the U', () {
      // Folding must not quietly turn the example into a valid code. I/L/O are
      // rewritten; U is not, which is the whole reason it is the safe letter.
      final normalized = parseInviteLink(kExampleInviteCode)!.code;
      expect(normalized.contains('U'), isTrue);
    });

    test('is the right length to read as a real one', () {
      // It still has to look like a code to be useful as an example.
      expect(kExampleInviteCode.length, 10);
    });
  });

  /// The in-app tap has a different threat model from the OS one: the URL was
  /// typed by whoever is in the room, not delivered by a platform that only
  /// routes our own verified domains here.
  group('parseOwnInviteUrl — what may take a tap away from the browser', () {
    test('claims our own canonical invite', () {
      final link = parseOwnInviteUrl('$kInviteSiteUrl/j/K7M2XQ94RB');
      expect(link?.code, 'K7M2XQ94RB');
    });

    test('claims the private-scheme fallback', () {
      expect(parseOwnInviteUrl('monkeyhub://join/K7M2XQ94RB')?.code,
          'K7M2XQ94RB');
    });

    test('refuses the same path on somebody else\'s host', () {
      // The one that matters. `parseInviteLink` reads `/j/<code>` off any
      // host, which is right for a link the OS delivered and wrong for one a
      // stranger pasted into a room: without the host test they could dress a
      // link up as an invite and take a tap meant for their own site.
      expect(parseInviteLink('https://evil.example/j/K7M2XQ94RB'), isNotNull);
      expect(parseOwnInviteUrl('https://evil.example/j/K7M2XQ94RB'), isNull);
    });

    test('refuses a bare code, however code-shaped', () {
      // Prose is not the join box. `parseInviteLink` accepts these because
      // somebody types one in by hand; a message full of words must not have
      // one of them swallowed.
      expect(parseInviteLink('K7M2XQ94RB'), isNotNull);
      expect(parseOwnInviteUrl('K7M2XQ94RB'), isNull);
      expect(parseOwnInviteUrl('example.com'), isNull);
    });

    test('refuses our own non-invite pages', () {
      expect(parseOwnInviteUrl('$kInviteSiteUrl/download'), isNull);
      expect(parseOwnInviteUrl(kInviteSiteUrl), isNull);
    });

    test('refuses a scheme with no browser surface to leave', () {
      expect(parseOwnInviteUrl('mailto:someone@example.com'), isNull);
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
