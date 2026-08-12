import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/backend/server_probe.dart';

/// The probe's job is not "did it work" — it is telling four different
/// failures apart, because each one has a different fix and the user cannot
/// see any of them. Conflating "nothing is listening" with "a Convex box that
/// runs somebody else's app" is precisely the ambiguity this class exists to
/// remove, so the classification is what gets tested.
void main() {
  ServerProbe probeWith(Future<http.Response> Function(http.Request) handler) =>
      ServerProbe(client: MockClient(handler));

  http.Response convexSuccess() => http.Response(
    jsonEncode({'status': 'success', 'value': null}),
    200,
    headers: {'content-type': 'application/json'},
  );

  test('a deployment running this app is ready', () async {
    final result = await probeWith((req) async {
      expect(req.url.path, '/api/query');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['path'], ServerProbe.healthQuery);
      return convexSuccess();
    }).probe('https://chat.example.com');
    expect(result.status, ServerProbeStatus.ready);
    expect(result.ok, isTrue);
  });

  test('reads the backend version off /version when it answers', () async {
    final result = await probeWith((req) async {
      if (req.url.path == '/version') return http.Response('"0.1.2"', 200);
      return convexSuccess();
    }).probe('https://chat.example.com');
    expect(result.backendVersion, '0.1.2');
  });

  test('a proxy answering HTML on /version does not fake a version', () async {
    final result = await probeWith((req) async {
      if (req.url.path == '/version') {
        return http.Response('<!doctype html><html>…', 200);
      }
      return convexSuccess();
    }).probe('https://chat.example.com');
    expect(result.status, ServerProbeStatus.ready);
    expect(result.backendVersion, isNull);
  });

  test('nothing listening reads as unreachable, not as "not Convex"', () async {
    final result = await probeWith((_) async {
      throw http.ClientException('Connection refused');
    }).probe('https://nope.example.com');
    expect(result.status, ServerProbeStatus.unreachable);
    expect(result.detail, contains('Connection refused'));
  });

  test('a bare web server 404 is not a Convex deployment', () async {
    final result = await probeWith(
      (_) async => http.Response('Not Found', 404),
    ).probe('https://example.com');
    expect(result.status, ServerProbeStatus.notConvex);
    expect(result.detail, 'HTTP 404');
  });

  test('a 200 that is not the Convex envelope is not a deployment', () async {
    // A login page or an SPA index served on every path.
    final result = await probeWith(
      (_) async => http.Response('<!doctype html><html>hi</html>', 200),
    ).probe('https://example.com');
    expect(result.status, ServerProbeStatus.notConvex);
  });

  test('a Convex box without this app is distinguished from a dead one',
      () async {
    final result = await probeWith(
      (_) async => http.Response(
        jsonEncode({
          'status': 'error',
          'errorMessage': "Could not find public function for 'releases:latest'",
        }),
        200,
      ),
    ).probe('https://someone-elses.convex.cloud');
    expect(result.status, ServerProbeStatus.notThisApp);
    // Insisting is defensible here — a deployment mid-rollout looks like this.
    expect(result.plausible, isTrue);
    expect(result.ok, isFalse);
  });

  test('a function that threw is a server error, not a missing app', () async {
    final result = await probeWith(
      (_) async => http.Response(
        jsonEncode({'status': 'error', 'errorMessage': 'Table not found'}),
        200,
      ),
    ).probe('https://chat.example.com');
    expect(result.status, ServerProbeStatus.serverError);
    expect(result.detail, 'Table not found');
  });

  test('normalizes the address before probing it', () async {
    Uri? seen;
    final result = await probeWith((req) async {
      seen ??= req.url;
      return convexSuccess();
    }).probe('  chat.example.com/  ');
    expect(seen.toString(), 'https://chat.example.com/api/query');
    expect(result.ok, isTrue);
  });

  test('an unusable address is refused without a request', () async {
    var called = false;
    final result = await probeWith((_) async {
      called = true;
      return convexSuccess();
    }).probe('ws://chat.example.com');
    expect(called, isFalse);
    expect(result.status, ServerProbeStatus.notConvex);
  });

  test('a stack trace from the server cannot push the UI off screen',
      () async {
    final result = await probeWith(
      (_) async => http.Response(
        jsonEncode({
          'status': 'error',
          'errorMessage': 'boom\n${'at frame\n' * 200}',
        }),
        200,
      ),
    ).probe('https://chat.example.com');
    expect(result.detail!.length, lessThanOrEqualTo(160));
    expect(result.detail, isNot(contains('\n')));
  });
}
