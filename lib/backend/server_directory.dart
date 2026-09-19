import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:http/http.dart' as http;

import '../data/any_class_keychain.dart';
import '../diagnostics/diag_log.dart';
import 'convex_client.dart';
import 'server_endpoint.dart';
import 'server_store.dart';

/// What kind of backend an address is, from this app's point of view.
enum ServerRole {
  /// The VPS this app normally serves from. Nothing is shown for it.
  primary,

  /// The operator's home server — an interchangeable, replicated copy of
  /// [primary] that traffic is moved onto during maintenance. Badged, because
  /// it is a temporary arrangement with real consequences (see the info sheet)
  /// and nothing else on screen would say so.
  homeserver,

  /// A deployment this app does not ship knowing about: somebody self-hosting.
  /// Badged for a different reason — see [SelfHostBadge].
  selfHosted,
}

/// The two addresses this app ships knowing about, and how to recognise them.
///
/// Compiled in rather than fetched, because the classification has to be right
/// on the first frame of a cold launch with no network — the badge must not
/// flicker in after the socket connects, and a device that is offline still
/// deserves to be told which backend it is pointed at.
///
/// The directive ([ServerDirectory]) may hand back different addresses for the
/// same two ROLES, which is what lets a host be renamed without a client
/// release; these are the fallback, not the authority.
class KnownHosts {
  const KnownHosts._();

  static const String primaryHost = 'termio-api.walhallaa.com';
  static const String homeserverHost = 'monkeyhub-homeserver-api.walhallaa.com';

  /// Both deployments serve HTTP actions under a `/http` path prefix rather
  /// than on a sibling domain the way Convex Cloud does — see `env.local`.
  /// [deriveSiteUrl] cannot know that (it is true of this operator's reverse
  /// proxy, not of self-hosted Convex generally), so the pair is spelled out.
  static const String _sitePathSuffix = '/http';

  static ServerEndpoint endpointFor(ServerRole role, {String? url}) {
    final base =
        url ??
        switch (role) {
          ServerRole.primary => 'https://$primaryHost',
          ServerRole.homeserver => 'https://$homeserverHost',
          ServerRole.selfHosted => '',
        };
    if (base.isEmpty) return const ServerEndpoint(deploymentUrl: '');
    return ServerEndpoint(
      deploymentUrl: base,
      siteUrlOverride: '$base$_sitePathSuffix',
    );
  }

  /// Which of the three [ServerRole]s an address is.
  ///
  /// Matches on HOST only — not on the whole URL — so `https://host`,
  /// `https://host/`, and a stray port or path all classify the same way. A
  /// badge that appeared because someone's saved URL had a trailing slash
  /// would be worse than no badge at all.
  static ServerRole roleOf(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return ServerRole.selfHosted;
    if (host == primaryHost) return ServerRole.primary;
    if (host == homeserverHost) return ServerRole.homeserver;
    return ServerRole.selfHosted;
  }

  /// Whether [url] is one of the two deployments the directive governs.
  ///
  /// False for a self-hosted address, and that is the whole point: somebody
  /// running their own backend must never be moved by a directive published on
  /// a server they chose not to use.
  ///
  /// A question about an ADDRESS, and therefore only half of "may this install
  /// be moved" — one of these two addresses can also be typed in by hand, and
  /// an install that got here that way is nobody's to relocate either. Ask
  /// [ServerStore.followsDirectives], which is both halves.
  static bool isManaged(String url) => roleOf(url) != ServerRole.selfHosted;
}

/// A directive: which of the two deployments clients should be on.
@immutable
class ServerDirective {
  const ServerDirective({
    required this.serve,
    this.primaryUrl,
    this.homeserverUrl,
    this.note,
  });

  final ServerRole serve;

  /// Address overrides published by the backend, or null to use [KnownHosts].
  final String? primaryUrl;
  final String? homeserverUrl;

  /// The operator's own words about why, shown in the info sheet. Never
  /// invented on this side, and absent far more often than not.
  final String? note;

  /// The endpoint this directive points at.
  ServerEndpoint get target => KnownHosts.endpointFor(
    serve,
    url: switch (serve) {
      ServerRole.primary => primaryUrl,
      ServerRole.homeserver => homeserverUrl,
      ServerRole.selfHosted => null,
    },
  );

  Map<String, dynamic> toJson() => {
    'serve': serve.name,
    if (primaryUrl != null) 'primaryUrl': primaryUrl,
    if (homeserverUrl != null) 'homeserverUrl': homeserverUrl,
    if (note != null) 'note': note,
  };

  /// Parses the `serverDirectory:current` payload.
  ///
  /// Tolerant in one direction only: anything it cannot read as an explicit
  /// `homeserver` is [ServerRole.primary]. A malformed or half-deployed
  /// backend must not be able to scatter clients onto the home server — the
  /// failure direction is always "the normal one".
  static ServerDirective? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final serve = raw['serve'];
    if (serve is! String) return null;
    return ServerDirective(
      serve: serve.trim().toLowerCase() == 'homeserver'
          ? ServerRole.homeserver
          : ServerRole.primary,
      primaryUrl: _url(raw['primaryUrl']),
      homeserverUrl: _url(raw['homeserverUrl']),
      note: _note(raw['note']),
    );
  }

  /// A published address is run through the same normalizer a typed one is.
  /// The client builds a socket from this; accepting `htps://…` from the
  /// backend and finding out at connect time would be indistinguishable from
  /// the deployment being down.
  static String? _url(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return normalizeServerUrl(raw).url;
  }

  static String? _note(Object? raw) {
    if (raw is! String) return null;
    final one = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (one.isEmpty) return null;
    return one.length <= 200 ? one : '${one.substring(0, 197)}…';
  }

  @override
  bool operator ==(Object other) =>
      other is ServerDirective &&
      other.serve == serve &&
      other.primaryUrl == primaryUrl &&
      other.homeserverUrl == homeserverUrl &&
      other.note == note;

  @override
  int get hashCode => Object.hash(serve, primaryUrl, homeserverUrl, note);
}

/// Asks the backend which deployment to use, before a socket is opened.
///
/// ───────── the rule when nothing answers ─────────
///
/// **Stay where you are.** Silence is not a directive: a launch on a plane, a
/// captive portal, a backend mid-deploy and a build older than the
/// `serverDirectory` function all produce exactly the same nothing, and none of
/// them is a reason to move a client. So a failed check falls back to the last
/// directive this device was given, and to [ServerRole.primary] on a device
/// that has never had one.
///
/// That also makes this safe to ship BEFORE the backend function exists: every
/// client simply keeps using the deployment it already had.
///
/// Deliberately NOT a failover. A primary that stops answering leaves clients
/// on the primary, showing the ordinary "can't reach server" banner. Moving
/// people because a server went quiet would mean a flaky uplink and a real
/// migration are the same event, and only one of them should relocate anybody.
///
/// ───────── three paths, because one is not enough ─────────
///
///  * **[check]**, at launch, because a client with no socket still has to find
///    out where to open one.
///  * **[watch]**, once a socket exists, subscribing to the same function so a
///    flip moves everyone within a second rather than at their next relaunch.
///  * **A poll of the primary, but only while displaced onto the home server.**
///
/// That third one exists because a Convex subscription rides the socket, and
/// the socket is connected to whichever deployment the client is currently on.
/// So a client that has followed to the home server is watching the HOME
/// SERVER's row — and the flip that brings it back is made on the VPS, which it
/// cannot see. Outbound was instant and the return leg was silent, which is a
/// deeply confusing way for this to half-work.
///
/// It could have been fixed by writing the row on both deployments, and that is
/// exactly the discipline this whole class exists to stop depending on: forget
/// once and clients are stranded on a machine nobody meant them to be on. A
/// client that is somewhere temporary asking the authority every so often costs
/// one small request a minute, only while displaced, and needs nobody to
/// remember anything.
class ServerDirectory {
  ServerDirectory._() : _injected = null;
  static final ServerDirectory instance = ServerDirectory._();

  /// Builds one with a stubbed transport, so the classification and the
  /// stay-put rule can be exercised without a network.
  @visibleForTesting
  ServerDirectory.forTest({http.Client? client}) : _injected = client;

  /// When set, used instead of a fresh client and never closed — the test owns
  /// its lifetime.
  final http.Client? _injected;

  static const _kLast = 'mh.server.directive';

  // `first_unlock` through [AnyClassKeychain], for the same reasons as
  // [ServerStore]'s: readable on a locked launch, and found wherever 1.3.105's
  // settings migration moved it.
  final _storage = const AnyClassKeychain(
    FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );

  /// The whole launch budget for this check.
  ///
  /// Short on purpose: it sits in front of the first socket, so every
  /// millisecond here is a millisecond of splash screen. Long enough for a
  /// round trip to a VPS on a mobile connection, and no longer — the fallback
  /// is a perfectly good answer, and a slow check that delays launch is worse
  /// than a stale directive.
  static const Duration launchTimeout = Duration(seconds: 3);

  /// Budget for the second request, made only from the home server and only
  /// after the primary said nothing. Shorter than [launchTimeout] because it is
  /// additive: the worst case is a client on the home server with a dead VPS,
  /// and it still has to reach the first frame in reasonable time.
  static const Duration _fallbackTimeout = Duration(seconds: 2);

  /// How often a displaced client re-asks the primary whether it can come home.
  ///
  /// Frequent enough that "everyone is back" follows the flip closely, and
  /// affordable because of who pays it: only clients currently on the home
  /// server, only for as long as the migration lasts. On the primary — every
  /// client, almost always — this timer does not exist.
  static const Duration homeserverPollInterval = Duration(seconds: 30);

  /// Whether a client in [role] has to poll to hear about a move.
  ///
  /// Only the home server does. A client on the primary is already subscribed
  /// to the authority, and a self-hosted install is governed by nobody.
  static bool pollsFrom(ServerRole role) => role == ServerRole.homeserver;

  /// Floor between two checks once the app is running, so a foreground/
  /// background flicker cannot turn into a request per resume.
  static const Duration recheckInterval = Duration(minutes: 5);

  ServerDirective? _last;
  DateTime? _lastCheckedAt;

  /// The live subscription, and what to do when it says to move.
  Subscription? _sub;
  void Function(ServerEndpoint target)? _onRedirect;

  /// Runs only while this client is on the home server. See the class doc.
  Timer? _poll;

  /// The most recent directive this device holds — from the network if the
  /// last check succeeded, from storage otherwise, null if it has never had
  /// one.
  ServerDirective? get last => _last;

  Future<void> load() async {
    if (_last != null) return;
    try {
      final raw = await _storage.read(key: _kLast);
      if (raw != null && raw.isNotEmpty) {
        _last = ServerDirective.fromJson(jsonDecode(raw));
      }
    } on MissingPluginException {
      /* no secure storage in the test harness */
    } catch (e) {
      debugPrint('ServerDirectory.load: $e');
    }
  }

  /// Ask [askUrl] where clients should be, and return the endpoint to use.
  ///
  /// Returns null when the answer is "no change" — including every failure
  /// path — so a caller can treat null as "carry on with what you have"
  /// without inspecting why.
  ///
  /// [askUrl] is the deployment the app is currently pointed at, NOT a
  /// hardcoded primary. A client that already followed to the home server asks
  /// the home server, which is what makes moving everyone back a matter of
  /// flipping the env var there too — and what stops a client that cannot
  /// reach the VPS from being unable to learn anything at all.
  Future<ServerEndpoint?> check({
    required String askUrl,
    Duration timeout = launchTimeout,
  }) async {
    // A self-hosted address is not ours to redirect. Someone who deliberately
    // pointed this app at their own backend must never be moved by a directive
    // — least of all one published by a server they chose not to use.
    if (!KnownHosts.isManaged(askUrl)) return null;
    // Nor is one of OUR addresses that somebody typed in. It is the same host
    // either way, so the URL cannot tell these apart and the store is asked
    // instead: a pinned install has been put here on purpose, and moving it
    // would overrule the person who did it. See [ServerStore.isPinned].
    if (ServerStore.instance.isPinned) return null;

    _lastCheckedAt = DateTime.now();
    final client = _injected ?? http.Client();
    try {
      // ── the primary is asked FIRST, even from the home server ──────────────
      //
      // This used to ask whichever deployment the app was already on, which
      // sounds symmetrical and is not: it means a client that has followed to
      // the home server can only be brought back by the HOME SERVER agreeing to
      // send it back. Flip `SERVE_FROM` on the VPS alone — the obvious thing to
      // do, and the thing that was done — and every client that listened to you
      // stays where it is, because it never asks you again. The same trap
      // catches a `serverDirectory` deployed to one backend and not the other.
      //
      // So the primary is the authority whenever it can be reached, which is
      // also the only arrangement matching what an operator expects: the
      // switch that sent everyone away is the switch that brings them home.
      final primary = KnownHosts.endpointFor(ServerRole.primary).deploymentUrl;
      var directive = await _ask(client, primary, timeout);
      // Only when the primary said nothing does where-we-are get a vote. That
      // is the case the home server exists for: the VPS is unreachable, and a
      // client on the home server still needs to be able to learn things.
      if (directive == null &&
          Uri.tryParse(askUrl)?.host != Uri.tryParse(primary)?.host) {
        directive = await _ask(client, askUrl, _fallbackTimeout);
      }
      if (directive == null) return null;
      await _remember(directive);

      final target = directive.target;
      if (target.deploymentUrl.isEmpty) return null;
      // Host comparison, not string equality: the published URL and the saved
      // one can differ by a trailing slash or a port and still be the same
      // server, and "move" is far too expensive an answer to give on a
      // formatting difference.
      final same =
          Uri.tryParse(target.deploymentUrl)?.host ==
          Uri.tryParse(askUrl)?.host;
      if (same) return null;
      DiagLog.connection('directory', 'directed to ${directive.serve.name}');
      return target;
    } finally {
      if (_injected == null) client.close();
    }
  }

  /// One request. Returns null for every failure — see the class doc on why
  /// silence is never a directive.
  Future<ServerDirective?> _ask(
    http.Client client,
    String url,
    Duration timeout,
  ) async {
    final host = Uri.tryParse(url)?.host ?? '?';
    try {
      final res = await client
          .post(
            Uri.parse('${url.replaceAll(RegExp(r'/+$'), '')}/api/query'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'path': 'serverDirectory:current',
              'args': const <String, dynamic>{},
              'format': 'json',
            }),
          )
          .timeout(timeout);
      if (res.statusCode != 200) {
        DiagLog.connection('directory', '$host: HTTP ${res.statusCode}');
        return null;
      }
      final body = jsonDecode(res.body);
      if (body is! Map || body['status'] != 'success') {
        // The overwhelmingly likely cause is a backend that predates the
        // function. Logged at info, not warn: on the build that ships this
        // ahead of the deploy, it is the expected answer.
        DiagLog.connection('directory', '$host: no directive published');
        return null;
      }
      final directive = ServerDirective.fromJson(body['value']);
      if (directive == null) {
        DiagLog.connection('directory', '$host: unreadable payload');
        return null;
      }
      DiagLog.connection('directory', '$host: serve ${directive.serve.name}');
      return directive;
    } catch (e) {
      DiagLog.connection('directory', '$host: unavailable ${_short(e)}');
      return null;
    }
  }

  /// Follow the directive live, over the socket the app already has.
  ///
  /// [onRedirect] fires only when the published directive names a DIFFERENT
  /// deployment from the one in force — never on the first delivery confirming
  /// where we already are, which is what every client sees on every connect.
  ///
  /// Only ever attached on a managed deployment the app was directed onto. An
  /// install that is somebody's own — a private box, or one of these two
  /// addresses entered by hand — is not governed by anybody's directive, and
  /// subscribing there would be asking for permission to stay put.
  ///
  /// Idempotent: the previous subscription is cancelled first, so this can be
  /// re-run after a reconnect or a follow without stacking listeners.
  Future<void> watch(
    ConvexBackend backend, {
    required void Function(ServerEndpoint target) onRedirect,
  }) async {
    _onRedirect = onRedirect;
    _sub?.cancel();
    _sub = null;
    // BEFORE the managed guard below, not after: a self-hosting switch made
    // from the home server lands here and returns early, and a poll left
    // running would go on asking the operator's VPS where a install that is no
    // longer theirs to move should be.
    _syncPoll();
    if (!ServerStore.instance.followsDirectives) return;
    try {
      _sub = await backend.subscribe(
        'serverDirectory:current',
        const {},
        onData: _onDirective,
        onError: (e) =>
            DiagLog.connection('directory', 'watch failed: ${_short(e)}'),
      );
    } catch (e) {
      // A backend that predates the function throws here rather than delivering
      // an error, and that is the expected answer on every deployment until it
      // ships. The launch check remains, so nothing is lost.
      DiagLog.connection('directory', 'watch unavailable: ${_short(e)}');
    }
  }

  /// Start or stop the displaced-client poll to match where we are now.
  ///
  /// Driven from [watch], which the app re-runs after every rebind, so the
  /// timer starts when a follow lands on the home server and stops when one
  /// lands back on the primary — without either caller knowing it exists.
  void _syncPoll() {
    if (!pollsFrom(ServerStore.instance.role)) {
      if (_poll != null) {
        DiagLog.connection('directory', 'poll stopped');
      }
      _poll?.cancel();
      _poll = null;
      return;
    }
    if (_poll != null) return;
    DiagLog.connection('directory', 'poll started (on the home server)');
    _poll = Timer.periodic(homeserverPollInterval, (_) => _pollPrimary());
  }

  Future<void> _pollPrimary() async {
    final onRedirect = _onRedirect;
    if (onRedirect == null) return;
    // [check] already asks the primary first, which is the entire point here:
    // the answer this poll is looking for is the one only the VPS has.
    final target = await check(askUrl: ServerStore.instance.deploymentUrl);
    if (target != null) onRedirect(target);
  }

  Future<void> _onDirective(dynamic raw) async {
    final directive = ServerDirective.fromJson(raw);
    if (directive == null) return;
    await _remember(directive);
    final target = directive.target;
    if (target.deploymentUrl.isEmpty) return;
    final current = ServerStore.instance.deploymentUrl;
    // Host comparison, for the same reason as in [check]: a trailing slash is
    // not a different server, and "move" is far too expensive an answer to give
    // on a formatting difference. Every client gets a delivery on every connect
    // confirming where it already is; that one has to be silent.
    if (Uri.tryParse(target.deploymentUrl)?.host ==
        Uri.tryParse(current)?.host) {
      return;
    }
    // Also silent for an install that is not ours to move — belt and braces
    // behind the guard in [watch], because a follow leaves the subscription
    // live and both ways out of being movable, a self-host switch and pinning
    // this address, are one tap away on the same screen.
    if (!ServerStore.instance.followsDirectives) return;
    DiagLog.connection('directory', 'live redirect to ${directive.serve.name}');
    _onRedirect?.call(target);
  }

  /// Drop the live subscription and the poll.
  void unwatch() {
    _sub?.cancel();
    _sub = null;
    _poll?.cancel();
    _poll = null;
    _onRedirect = null;
  }

  /// Whether enough time has passed to ask again. Read by the resume path,
  /// which fires far more often than this needs to run.
  bool get dueForRecheck {
    final at = _lastCheckedAt;
    return at == null || DateTime.now().difference(at) >= recheckInterval;
  }

  Future<void> _remember(ServerDirective d) async {
    if (_last == d) return;
    _last = d;
    try {
      await _storage.write(key: _kLast, value: jsonEncode(d.toJson()));
    } on MissingPluginException {
      /* no secure storage in the test harness */
    } catch (e) {
      debugPrint('ServerDirectory: persisting the directive failed: $e');
    }
  }

  static String _short(Object e) {
    final s = e.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length <= 120 ? s : '${s.substring(0, 117)}…';
  }

  @visibleForTesting
  void resetForTest() {
    _last = null;
    _lastCheckedAt = null;
    _sub = null;
    _poll?.cancel();
    _poll = null;
    _onRedirect = null;
  }

  /// Whether the displaced-client poll is running. Test seam.
  @visibleForTesting
  bool get isPolling => _poll != null;
}
