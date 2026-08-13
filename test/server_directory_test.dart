import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/backend/server_directory.dart';

/// The directive decides which backend an app opens its socket against, sight
/// unseen, before anyone can object. Two properties keep that safe, and both
/// are asymmetric on purpose:
///
///  * **Silence never moves anybody.** A plane, a captive portal, a backend
///    mid-deploy and a build older than the `serverDirectory` function all
///    produce the same nothing, and none of them is a reason to relocate a
///    client.
///  * **Only an explicit `homeserver` moves anybody.** Every other answer,
///    including a malformed one, means the ordinary deployment.
void main() {
  // Remembering a directive writes to secure storage. Without a binding that
  // write throws "Binding has not yet been initialized" rather than the
  // MissingPluginException this class swallows, and every passing test prints
  // eight lines of it.
  TestWidgetsFlutterBinding.ensureInitialized();

  final primary = KnownHosts.endpointFor(ServerRole.primary);
  final homeserver = KnownHosts.endpointFor(ServerRole.homeserver);

  ServerDirectory withBody(String body, {int status = 200}) =>
      ServerDirectory.forTest(
        client: MockClient((_) async => http.Response(body, status)),
      );

  String envelope(Object? value) =>
      jsonEncode({'status': 'success', 'value': value});

  group('classification', () {
    test('recognises the two deployments by host alone', () {
      expect(
        KnownHosts.roleOf('https://${KnownHosts.primaryHost}'),
        ServerRole.primary,
      );
      // A trailing slash, a port, a path — same server, same verdict. A badge
      // that appeared because a saved URL ended in `/` would be worse than none.
      expect(
        KnownHosts.roleOf('https://${KnownHosts.primaryHost}/'),
        ServerRole.primary,
      );
      expect(
        KnownHosts.roleOf('https://${KnownHosts.homeserverHost}/http'),
        ServerRole.homeserver,
      );
    });

    test('anything else is somebody\'s own', () {
      expect(KnownHosts.roleOf('https://chat.example.com'), ServerRole.selfHosted);
      expect(KnownHosts.roleOf(''), ServerRole.selfHosted);
      expect(KnownHosts.roleOf('not a url'), ServerRole.selfHosted);
    });

    test('a lookalike host is not the real one', () {
      // Same suffix, different registrable domain. Classifying this as the
      // primary would silence the badge on a server nobody vetted.
      expect(
        KnownHosts.roleOf('https://termio-api.walhallaa.com.evil.test'),
        ServerRole.selfHosted,
      );
    });

    test('both known endpoints carry the /http action origin', () {
      // Neither deployment splits actions onto a sibling domain the way Convex
      // Cloud does, and `deriveSiteUrl` cannot know that.
      expect(primary.siteUrl, endsWith('/http'));
      expect(homeserver.siteUrl, endsWith('/http'));
    });
  });

  group('parsing', () {
    test('reads an explicit homeserver directive', () {
      final d = ServerDirective.fromJson({'serve': 'homeserver'});
      expect(d!.serve, ServerRole.homeserver);
      expect(d.target.host, KnownHosts.homeserverHost);
    });

    test('anything unrecognised means the primary', () {
      for (final serve in ['primary', 'HOMESERVERS', 'yes', '']) {
        expect(
          ServerDirective.fromJson({'serve': serve})!.serve,
          ServerRole.primary,
          reason: serve,
        );
      }
    });

    test('honours a published address override', () {
      final d = ServerDirective.fromJson({
        'serve': 'homeserver',
        'homeserverUrl': 'https://backup.example.com',
      });
      expect(d!.target.deploymentUrl, 'https://backup.example.com');
    });

    test('normalizes a published address rather than trusting it', () {
      // A backend handing back `box.local/` must not produce a URL the client
      // then fails to build a socket from — which would be indistinguishable
      // from the deployment being down.
      final d = ServerDirective.fromJson({
        'serve': 'homeserver',
        'homeserverUrl': '  box.local/  ',
      });
      expect(d!.target.deploymentUrl, 'https://box.local');
    });

    test('a garbled payload is no directive at all', () {
      expect(ServerDirective.fromJson(null), isNull);
      expect(ServerDirective.fromJson('homeserver'), isNull);
      expect(ServerDirective.fromJson({'nope': 1}), isNull);
    });

    test('caps the operator note so it cannot flood the sheet', () {
      final d = ServerDirective.fromJson({
        'serve': 'primary',
        'note': 'x' * 900,
      });
      expect(d!.note!.length, lessThanOrEqualTo(200));
    });
  });

  group('who has to poll', () {
    // A Convex subscription rides the socket, and the socket is connected to
    // whichever deployment the client is on. So a client that followed to the
    // home server is watching the HOME SERVER's row, and the flip that brings
    // it back is made on the VPS — invisible to it. Outbound was instant and
    // the return leg was silent.
    test('only a client on the home server does', () {
      expect(ServerDirectory.pollsFrom(ServerRole.homeserver), isTrue);
      // Already subscribed to the authority.
      expect(ServerDirectory.pollsFrom(ServerRole.primary), isFalse);
      // Governed by nobody.
      expect(ServerDirectory.pollsFrom(ServerRole.selfHosted), isFalse);
    });

    test('the interval is short enough to follow a flip closely', () {
      // Only clients that have been displaced pay it, and only until they come
      // home — so this can afford to be brisk.
      expect(
        ServerDirectory.homeserverPollInterval,
        lessThanOrEqualTo(const Duration(minutes: 1)),
      );
    });
  });

  group('the check', () {
    test('moves a client when the directive names the other deployment',
        () async {
      final target = await withBody(
        envelope({'serve': 'homeserver'}),
      ).check(askUrl: primary.deploymentUrl);
      expect(target, isNotNull);
      expect(target!.host, KnownHosts.homeserverHost);
    });

    test('says nothing when already where it should be', () async {
      final target = await withBody(
        envelope({'serve': 'primary'}),
      ).check(askUrl: primary.deploymentUrl);
      expect(target, isNull);
    });

    test('a trailing slash is not a different server', () async {
      final target = await withBody(
        envelope({'serve': 'primary'}),
      ).check(askUrl: '${primary.deploymentUrl}/');
      expect(
        target,
        isNull,
        reason: '"move" is far too expensive an answer to give on a '
            'formatting difference',
      );
    });

    test('a backend with no such function leaves everyone put', () async {
      // Exactly what every deployment looks like until `serverDirectory` is
      // deployed — so shipping the app first has to be a no-op.
      final target = await withBody(
        jsonEncode({
          'status': 'error',
          'errorMessage': "Could not find public function",
        }),
      ).check(askUrl: primary.deploymentUrl);
      expect(target, isNull);
    });

    test('an unreachable backend leaves everyone put', () async {
      final target = await ServerDirectory.forTest(
        client: MockClient((_) async {
          throw http.ClientException('Connection refused');
        }),
      ).check(askUrl: primary.deploymentUrl);
      expect(target, isNull);
    });

    test('an HTTP error leaves everyone put', () async {
      final target = await withBody(
        'Bad Gateway',
        status: 502,
      ).check(askUrl: primary.deploymentUrl);
      expect(target, isNull);
    });

    test('a self-hosted install is never asked, let alone moved', () async {
      var called = false;
      final target = await ServerDirectory.forTest(
        client: MockClient((_) async {
          called = true;
          return http.Response(envelope({'serve': 'homeserver'}), 200);
        }),
      ).check(askUrl: 'https://chat.example.com');
      expect(called, isFalse);
      expect(target, isNull);
    });

    test('asks the primary first, even from the home server', () async {
      // The bug this replaced: the check asked whichever deployment the app was
      // already on, so a client that had followed to the home server could only
      // be brought back by the HOME SERVER agreeing to send it back. Flipping
      // SERVE_FROM on the VPS alone — the obvious thing to do — moved nobody.
      final asked = <String>[];
      final target = await ServerDirectory.forTest(
        client: MockClient((req) async {
          asked.add(req.url.host);
          return http.Response(envelope({'serve': 'primary'}), 200);
        }),
      ).check(askUrl: homeserver.deploymentUrl);
      expect(asked, [KnownHosts.primaryHost]);
      expect(target!.host, KnownHosts.primaryHost);
    });

    test('falls back to where it is when the primary is silent', () async {
      // The case the home server exists for. A client on it still has to be
      // able to learn things while the VPS is unreachable.
      final asked = <String>[];
      final target = await ServerDirectory.forTest(
        client: MockClient((req) async {
          asked.add(req.url.host);
          if (req.url.host == KnownHosts.primaryHost) {
            throw http.ClientException('Connection refused');
          }
          return http.Response(envelope({'serve': 'homeserver'}), 200);
        }),
      ).check(askUrl: homeserver.deploymentUrl);
      expect(asked, [KnownHosts.primaryHost, KnownHosts.homeserverHost]);
      // Already there, so nothing to do — but the directive was still read.
      expect(target, isNull);
    });

    test('does not ask twice when it is already on the primary', () async {
      final asked = <String>[];
      await ServerDirectory.forTest(
        client: MockClient((req) async {
          asked.add(req.url.host);
          throw http.ClientException('Connection refused');
        }),
      ).check(askUrl: primary.deploymentUrl);
      expect(asked, [KnownHosts.primaryHost]);
    });

    test('remembers the directive, including the note', () async {
      final directory = withBody(
        envelope({'serve': 'homeserver', 'note': 'migrating the VPS'}),
      );
      await directory.check(askUrl: primary.deploymentUrl);
      expect(directory.last!.serve, ServerRole.homeserver);
      expect(directory.last!.note, 'migrating the VPS');
    });

    test('throttles rechecks so a resume flicker is not a request each',
        () async {
      final directory = withBody(envelope({'serve': 'primary'}));
      expect(directory.dueForRecheck, isTrue);
      await directory.check(askUrl: primary.deploymentUrl);
      expect(directory.dueForRecheck, isFalse);
    });
  });
}
