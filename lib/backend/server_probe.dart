import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'server_endpoint.dart';

/// What a pre-flight probe concluded about a URL, worst news first.
///
/// The ladder matters more than any single value: each rung answers a
/// different question, and knowing WHICH one failed is the whole difference
/// between "your server is down" and "your server is fine but it isn't running
/// MonkeyHub". Both used to look identical from inside the app — a spinner
/// that never stopped.
enum ServerProbeStatus {
  /// Nothing answered: DNS failure, connection refused, no route, or a TLS
  /// handshake the platform rejected.
  unreachable,

  /// Something is listening and it answered in time, but not as a Convex
  /// deployment — a 404 from a bare nginx, an HTML login page, a JSON body
  /// with none of the shape Convex's HTTP API produces.
  notConvex,

  /// A Convex deployment, reachable, running a DIFFERENT app: the health-check
  /// function this app depends on does not exist on it.
  notThisApp,

  /// A Convex deployment running this app, which answered an error rather than
  /// a result. Rare, and worth showing verbatim — it usually means the backend
  /// is mid-deploy or its tables have not been seeded.
  serverError,

  /// Answered the health-check query. Ready to connect.
  ready,
}

/// The full finding, including the numbers worth putting on screen.
class ServerProbeResult {
  const ServerProbeResult({
    required this.status,
    required this.roundTrip,
    this.detail,
    this.backendVersion,
  });

  final ServerProbeStatus status;

  /// How long the decisive request took. Shown because latency is the single
  /// most useful number about a server you are about to route every message
  /// through, and a self-hoster is the one person who can act on it.
  final Duration roundTrip;

  /// The server's own words, when it had any. Never invented on this side.
  final String? detail;

  /// From `GET /version`, when the deployment answers it. Best-effort garnish.
  final String? backendVersion;

  bool get ok => status == ServerProbeStatus.ready;

  /// Whether connecting anyway is a defensible choice. A server that answered
  /// as Convex but not as this app might be a deployment mid-rollout, so the
  /// user is allowed to insist. Nothing answering at all is not a judgement
  /// call — but the app still lets it through, because a probe blocked by a
  /// captive portal or a corporate proxy must not be able to lock someone out
  /// of their own server. See `ServerScreen`'s override affordance.
  bool get plausible =>
      status == ServerProbeStatus.notThisApp ||
      status == ServerProbeStatus.serverError;
}

/// Asks a URL, over plain HTTP, whether it is a Convex deployment running this
/// app — before the WebSocket client is ever pointed at it.
///
/// Why not just connect and see: the Convex client has no notion of "that URL
/// was wrong". It builds a socket, fails to reach anything, and enters its own
/// reconnect backoff — indistinguishable from a server that is merely down.
/// The user would type a typo and get a permanent "reconnecting…" with no way
/// to tell which of the two it was. Doing the check over one-shot HTTP first
/// makes the failure legible and, crucially, keeps the app pointed at the
/// server that still works while the answer comes back.
///
/// Uses Convex's documented HTTP API (`POST /api/query`), which every
/// deployment serves — cloud and self-hosted alike — on the same origin as the
/// WebSocket. So a pass here is real evidence about the URL that is about to be
/// saved, not about a neighbouring one.
class ServerProbe {
  ServerProbe({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// The function every probe calls. Public, unauthenticated, and cheap — the
  /// same one [ConvexBackend.probeConnection] already round-trips as its
  /// connectivity canary, so choosing it costs the backend nothing new and
  /// guarantees that a server passing this probe can serve the query the app
  /// issues first.
  static const healthQuery = 'releases:latest';
  static const healthArgs = {'channel': 'stable'};

  /// Long enough for a cold self-hosted container on a domestic uplink, short
  /// enough that a black-holed address doesn't leave someone watching a
  /// spinner. A server slower than this is one they do not want anyway.
  static const timeout = Duration(seconds: 10);

  Future<ServerProbeResult> probe(String deploymentUrl) async {
    final check = normalizeServerUrl(deploymentUrl);
    final url = check.url;
    if (url == null) {
      return const ServerProbeResult(
        status: ServerProbeStatus.notConvex,
        roundTrip: Duration.zero,
      );
    }

    final sw = Stopwatch()..start();
    late final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$url/api/query'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'path': healthQuery,
              'args': healthArgs,
              'format': 'json',
            }),
          )
          .timeout(timeout);
    } catch (e) {
      // Everything that never produced a response lands here as one status —
      // SocketException, HandshakeException, TimeoutException, and on web an
      // opaque ClientException that CORS and a dead host are indistinguishable
      // through. The exception text is passed along untouched because on
      // desktop and mobile it names the actual cause.
      return ServerProbeResult(
        status: ServerProbeStatus.unreachable,
        roundTrip: sw.elapsed,
        detail: _short(e.toString()),
      );
    }
    final elapsed = sw.elapsed;

    // A Convex deployment answers /api/query with 200 and a JSON envelope even
    // when the FUNCTION failed. Any other code means the route isn't there.
    if (res.statusCode != 200) {
      return ServerProbeResult(
        status: ServerProbeStatus.notConvex,
        roundTrip: elapsed,
        detail: 'HTTP ${res.statusCode}',
      );
    }

    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      /* handled below — an HTML error page lands here */
    }
    if (body == null || !body.containsKey('status')) {
      return ServerProbeResult(
        status: ServerProbeStatus.notConvex,
        roundTrip: elapsed,
        detail: _short(res.body),
      );
    }

    if (body['status'] == 'success') {
      return ServerProbeResult(
        status: ServerProbeStatus.ready,
        roundTrip: elapsed,
        backendVersion: await _version(url),
      );
    }

    final message = (body['errorMessage'] ?? body['errorData'] ?? '')
        .toString();
    // Convex phrases a missing function two ways depending on version. Both
    // mean the same thing here: right platform, wrong app.
    final missing =
        message.contains('Could not find public function') ||
        message.contains('function not found') ||
        message.contains("Couldn't find function");
    return ServerProbeResult(
      status: missing
          ? ServerProbeStatus.notThisApp
          : ServerProbeStatus.serverError,
      roundTrip: elapsed,
      detail: _short(message),
      backendVersion: await _version(url),
    );
  }

  /// `GET /version`, which self-hosted `convex-backend` answers with its build
  /// string. Pure garnish: it tells a self-hoster whether the box they are
  /// about to trust is the one they think they deployed. Never fails the probe.
  Future<String?> _version(String url) async {
    try {
      final res = await _client
          .get(Uri.parse('$url/version'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      final v = res.body.trim().replaceAll('"', '');
      // Guard against a proxy answering an HTML page on every path.
      if (v.isEmpty || v.length > 32 || v.contains('<')) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Server text goes on screen, so it is capped and stripped of newlines.
  /// A backend that answers with a stack trace must not be able to push the
  /// buttons off the bottom of the sheet.
  static String? _short(String s) {
    final one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (one.isEmpty) return null;
    return one.length <= 160 ? one : '${one.substring(0, 157)}…';
  }

  void dispose() => _client.close();
}
