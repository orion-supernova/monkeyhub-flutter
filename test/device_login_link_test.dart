import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/device_login_link.dart';
import 'package:monkeyhub/invites/invite_link.dart';

/// The desktop sign-in QR, and the bug it caused for everyone who scanned it
/// the obvious way.
///
/// `monkeyhub://devicelogin?r=<id>` has no path — a custom scheme has no
/// authority, so `devicelogin` lands in the URI's HOST. `parseInviteLink`'s
/// single-part branch read that as a typed code, upper-cased it, and handed
/// back the invite `DEVICELOGIN`; the app then opened a join screen and
/// reported the room missing. Scanning from inside the app was fine, because
/// that path never touches the invite parser — so the break only showed up for
/// the people using the phone's own Camera app, which is most of them.
void main() {
  // A real-shaped id: 16 random bytes hex-encoded, per `randomHex` in
  // deviceLogin.ts.
  const id = '0f1e2d3c4b5a69788796a5b4c3d2e1f0';

  group('the sign-in QR is not an invite', () {
    test('the URI the panel actually renders is refused', () {
      expect(parseInviteLink(deviceLoginUri(id)), isNull);
    });

    test('every spelling a platform might deliver is refused', () {
      for (final raw in [
        'monkeyhub://devicelogin?r=$id',
        'monkeyhub://DeviceLogin?r=$id',
        'monkeyhub:///devicelogin?r=$id',
        // What `didPushRouteInformation` reports rather than the original URL.
        '/devicelogin?r=$id',
        'devicelogin?r=$id',
        // Shape is ours even when the payload is not usable — this must not
        // fall through to the invite parser and become a code.
        'monkeyhub://devicelogin',
        'monkeyhub://devicelogin?r=garbage',
      ]) {
        expect(parseInviteLink(raw), isNull, reason: raw);
      }
    });

    test('a real invite still parses — the refusal is not too wide', () {
      expect(
        parseInviteLink('monkeyhub://join/$kExampleInviteCode')?.code,
        kExampleInviteCode,
      );
      expect(
        parseInviteLink(
          '$kInviteSiteUrl/$kInvitePathSegment/$kExampleInviteCode',
        )?.code,
        kExampleInviteCode,
      );
    });
  });

  group('parseDeviceLoginRequestId', () {
    test('reads the id back out of the URI the panel builds', () {
      expect(parseDeviceLoginRequestId(deviceLoginUri(id)), id);
    });

    test('accepts a bare id, for readers that strip the URL', () {
      expect(parseDeviceLoginRequestId(id), id);
      expect(parseDeviceLoginRequestId('  $id  '), id);
    });

    test('refuses anything that cannot be an id this app minted', () {
      for (final raw in [
        '',
        'garbage',
        id.toUpperCase(), // hex is lower-case out of randomHex
        id.substring(0, 31), // one short
        '${id}0', // one long
        'monkeyhub://devicelogin?r=',
        'monkeyhub://devicelogin',
        // An invite must not be mistaken for a login request either.
        'monkeyhub://join/$kExampleInviteCode',
      ]) {
        expect(parseDeviceLoginRequestId(raw), isNull, reason: '"$raw"');
      }
    });
  });

  group('isDeviceLoginUri', () {
    test('claims the shape even when the id is unusable', () {
      // The router leans on this: a malformed id must be swallowed here, not
      // passed on to be read as an invite code.
      expect(isDeviceLoginUri('monkeyhub://devicelogin?r=garbage'), isTrue);
      expect(isDeviceLoginUri('monkeyhub://devicelogin'), isTrue);
      expect(isDeviceLoginUri('/devicelogin?r=$id'), isTrue);
    });

    test('does not claim anything else', () {
      expect(isDeviceLoginUri('monkeyhub://join/$kExampleInviteCode'), isFalse);
      expect(isDeviceLoginUri('monkeyhub://share/open'), isFalse);
      expect(isDeviceLoginUri(id), isFalse);
      expect(isDeviceLoginUri(''), isFalse);
    });
  });

  test('the builder and the reserved segment cannot drift apart', () {
    // Two files have to agree for the refusal above to hold: the QR builder
    // and the invite parser's reserved list.
    expect(deviceLoginUri(id), contains('://$kDeviceLoginPathSegment'));
    expect(deviceLoginUri(id), startsWith('$kInviteScheme://'));
  });
}
