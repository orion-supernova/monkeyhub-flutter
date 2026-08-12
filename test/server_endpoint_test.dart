import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/server_endpoint.dart';
import 'package:monkeyhub/widgets/self_host_badge.dart' show shortHost;

/// The address field is the whole attack surface of self-hosting: everything
/// downstream — the socket, the HTTP-action URL, the recents list, the badge —
/// is derived from what comes out of [normalizeServerUrl]. A URL that parses
/// but is subtly wrong does not fail here, it fails as a socket that never
/// opens, which is exactly the failure this feature exists to make legible.
void main() {
  group('normalizeServerUrl', () {
    String? ok(String raw) => normalizeServerUrl(raw).url;
    ServerUrlProblem? bad(String raw) => normalizeServerUrl(raw).problem;

    test('adds https to a bare host', () {
      expect(ok('chat.example.com'), 'https://chat.example.com');
    });

    test('keeps an explicit http scheme rather than upgrading it', () {
      // Upgrading silently would produce an address the user never typed and
      // cannot debug. The screen warns about cleartext instead.
      expect(ok('http://192.168.1.40:3210'), 'http://192.168.1.40:3210');
    });

    test('drops trailing slashes', () {
      expect(ok('https://a.example.com/'), 'https://a.example.com');
      expect(ok('https://a.example.com///'), 'https://a.example.com');
    });

    test('keeps a path prefix, which a reverse proxy may need', () {
      expect(ok('https://example.com/convex/'), 'https://example.com/convex');
    });

    test('drops query and fragment', () {
      expect(ok('https://a.example.com/?x=1#frag'), 'https://a.example.com');
    });

    test('keeps a non-default port', () {
      expect(ok('https://a.example.com:8443'), 'https://a.example.com:8443');
    });

    test('lowercases the host and scheme', () {
      expect(ok('HTTPS://Chat.Example.COM'), 'https://chat.example.com');
    });

    test('strips wrappers a chat app or mail client added', () {
      expect(ok('<https://a.example.com>'), 'https://a.example.com');
      expect(ok('“https://a.example.com”'), 'https://a.example.com');
    });

    test('trims surrounding whitespace', () {
      expect(ok('  https://a.example.com \n'), 'https://a.example.com');
    });

    test('refuses internal whitespace', () {
      expect(bad('https://a.example .com'), ServerUrlProblem.malformed);
    });

    test('refuses a scheme no socket can be built from', () {
      expect(bad('ws://a.example.com'), ServerUrlProblem.badScheme);
      expect(bad('file:///tmp/x'), ServerUrlProblem.badScheme);
    });

    test('refuses a scheme with no host after it', () {
      expect(bad('https://'), ServerUrlProblem.noHost);
    });

    test('refuses embedded credentials rather than stripping them', () {
      // Usually a mis-pasted admin key. Dropping half of what someone pasted
      // is worse than saying no.
      expect(
        bad('https://admin:hunter2@a.example.com'),
        ServerUrlProblem.hasCredentials,
      );
    });

    test('empty is a problem the UI stays quiet about', () {
      expect(bad(''), ServerUrlProblem.empty);
      expect(bad('   '), ServerUrlProblem.empty);
    });

    test('is idempotent — normalizing twice changes nothing', () {
      const inputs = [
        'chat.example.com',
        'https://example.com/convex/',
        'HTTP://Box.local:3210/',
      ];
      for (final raw in inputs) {
        final once = ok(raw)!;
        expect(ok(once), once, reason: raw);
      }
    });
  });

  group('deriveSiteUrl', () {
    test('swaps convex.cloud for convex.site', () {
      expect(
        deriveSiteUrl('https://tidy-otter-123.convex.cloud'),
        'https://tidy-otter-123.convex.site',
      );
    });

    test('leaves a self-hosted origin alone — one host answers both', () {
      expect(
        deriveSiteUrl('https://chat.example.com'),
        'https://chat.example.com',
      );
    });

    test('does not swap a host that merely contains the cloud domain', () {
      // `convex.cloud.example.com` is somebody else's domain, not a Convex
      // deployment, and rewriting its host would point HTTP actions at a
      // server that has nothing to do with this account.
      expect(
        deriveSiteUrl('https://convex.cloud.example.com'),
        'https://convex.cloud.example.com',
      );
    });

    test('keeps the port and path when swapping', () {
      expect(
        deriveSiteUrl('https://a.convex.cloud:8443/base'),
        'https://a.convex.site:8443/base',
      );
    });
  });

  group('ServerEndpoint', () {
    test('host carries the port, which separates two boxes on a LAN', () {
      const e = ServerEndpoint(deploymentUrl: 'https://box.local:3210');
      expect(e.host, 'box.local:3210');
    });

    test('siteUrl prefers an explicit override over the derived value', () {
      const e = ServerEndpoint(
        deploymentUrl: 'https://a.convex.cloud',
        siteUrlOverride: 'https://actions.example.com',
      );
      expect(e.siteUrl, 'https://actions.example.com');
    });

    test('isSecure is false for http', () {
      expect(
        const ServerEndpoint(deploymentUrl: 'http://box.local').isSecure,
        isFalse,
      );
    });

    test('round-trips through the recents encoding', () {
      const list = [
        ServerEndpoint(deploymentUrl: 'https://a.example.com'),
        ServerEndpoint(
          deploymentUrl: 'https://b.example.com',
          siteUrlOverride: 'https://b-actions.example.com',
        ),
      ];
      expect(ServerEndpoint.decodeList(ServerEndpoint.encodeList(list)), list);
    });

    test('a corrupt recents blob decodes to empty, never throws', () {
      // Storage corruption must cost the history, not the launch.
      expect(ServerEndpoint.decodeList('not json'), isEmpty);
      expect(ServerEndpoint.decodeList('{"url":"x"}'), isEmpty);
      expect(ServerEndpoint.decodeList('[{"nope":1},null,3]'), isEmpty);
      expect(ServerEndpoint.decodeList(null), isEmpty);
    });
  });

  group('shortHost', () {
    test('leaves a short host alone', () {
      expect(shortHost('example.com'), 'example.com');
    });

    test('elides the middle, keeping the registrable tail', () {
      // The tail is the identifying half: `matrix.home.exa…` would look
      // identical for every host on that domain.
      final out = shortHost('matrix.home.verylongdomainname.example.com');
      expect(out, contains('…'));
      expect(out.endsWith('example.com'), isTrue);
      expect(out.length, lessThanOrEqualTo(22));
    });

    test('copes with a single label longer than the budget', () {
      final out = shortHost('a' * 40);
      expect(out.length, lessThanOrEqualTo(22));
    });
  });
}
