import 'dart:convert';

/// Why a typed server URL was refused. Each value maps to one sentence in the
/// server screen, so the user is told what is wrong rather than just "invalid".
enum ServerUrlProblem {
  /// Nothing typed yet. Not an error the UI shouts about — it just keeps the
  /// CONNECT button off.
  empty,

  /// Parsed, but not as a URL at all (spaces, control characters, `::`, …).
  malformed,

  /// A scheme we cannot open a WebSocket over — `ws://`, `ftp://`, `file://`.
  /// http/https only; the Convex client derives its `wss://` from the https.
  badScheme,

  /// `https://` with nothing after it, or a scheme-relative `//host` that lost
  /// its authority in parsing.
  noHost,

  /// `https://user:pass@host`. Refused rather than stripped: a credential in a
  /// deployment URL is almost always a mis-paste of an admin key, and quietly
  /// dropping half of what someone pasted is worse than saying no.
  hasCredentials,
}

/// A backend this install can be pointed at — the bundled default, or one the
/// user is hosting themselves.
///
/// Immutable and free of Flutter, so [normalizeServerUrl] and [deriveSiteUrl]
/// can be tested without a binding; see test/server_endpoint_test.dart.
class ServerEndpoint {
  const ServerEndpoint({required this.deploymentUrl, this.siteUrlOverride});

  /// Canonical, already normalized (see [normalizeServerUrl]). No trailing
  /// slash, lowercase scheme and host, no query or fragment.
  final String deploymentUrl;

  /// Where HTTP actions answer, when that is NOT derivable from
  /// [deploymentUrl]. Null on every ordinary deployment — see [deriveSiteUrl]
  /// for the two shapes that are derivable, and why an override still exists.
  final String? siteUrlOverride;

  /// Origin serving HTTP actions (`/viewOnce`). Honours the override, else
  /// derives.
  String get siteUrl => siteUrlOverride ?? deriveSiteUrl(deploymentUrl);

  /// What the badge and the settings row show. The host alone, because that is
  /// the part a self-hoster recognises — `chat.example.com`, `192.168.1.40`.
  String get host {
    final u = Uri.tryParse(deploymentUrl);
    if (u == null || u.host.isEmpty) return deploymentUrl;
    return u.hasPort ? '${u.host}:${u.port}' : u.host;
  }

  /// False for `http://`, which every mobile OS blocks by default (Android's
  /// cleartext policy since API 28, iOS ATS). Surfaced as a warning rather than
  /// a refusal — desktop and web builds can genuinely reach one, and so can iOS
  /// on `localhost`, which ATS exempts.
  bool get isSecure => Uri.tryParse(deploymentUrl)?.scheme == 'https';

  Map<String, dynamic> toJson() => {
    'url': deploymentUrl,
    if (siteUrlOverride != null) 'site': siteUrlOverride,
  };

  static ServerEndpoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url'];
    if (url is! String || url.isEmpty) return null;
    final site = raw['site'];
    return ServerEndpoint(
      deploymentUrl: url,
      siteUrlOverride: site is String && site.isNotEmpty ? site : null,
    );
  }

  static String encodeList(List<ServerEndpoint> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  /// Tolerant by design: a decode failure means the recents list is dropped,
  /// never that the app fails to start.
  static List<ServerEndpoint> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final item in decoded) ?fromJson(item)];
    } catch (_) {
      return const [];
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ServerEndpoint &&
      other.deploymentUrl == deploymentUrl &&
      other.siteUrlOverride == siteUrlOverride;

  @override
  int get hashCode => Object.hash(deploymentUrl, siteUrlOverride);

  @override
  String toString() => 'ServerEndpoint($deploymentUrl)';
}

/// The outcome of typing a URL: exactly one of the two fields is non-null.
typedef ServerUrlCheck = ({String? url, ServerUrlProblem? problem});

/// Turn what someone typed or pasted into a canonical deployment URL, or say
/// why it cannot be one.
///
/// Forgiving about the things people actually get wrong — a missing scheme, a
/// trailing slash from a browser address bar, a stray `?` from a dashboard
/// link, smart quotes and angle brackets from a chat app that "helpfully"
/// wrapped the link — and unforgiving about the two that would fail silently
/// much later: a scheme no WebSocket can be built from, and an embedded
/// credential.
///
/// A path is KEPT (minus its trailing slash). Self-hosted Convex behind a
/// reverse proxy at `https://example.com/convex` is a real deployment shape,
/// and dropping the prefix would produce a URL that parses, saves, and then
/// never connects.
ServerUrlCheck normalizeServerUrl(String raw) {
  var s = raw.trim();
  // Chat apps and PDFs wrap links; mail clients turn quotes into typographic
  // ones. Strip the wrappers before anything looks at the scheme.
  s = s
      .replaceAll(RegExp('^[<"\'“”«]+'), '')
      .replaceAll(RegExp('[>"\'“”»]+\$'), '')
      .trim();
  if (s.isEmpty) return (url: null, problem: ServerUrlProblem.empty);
  // Any internal whitespace is a paste accident, never part of a host.
  if (RegExp(r'\s').hasMatch(s)) {
    return (url: null, problem: ServerUrlProblem.malformed);
  }
  // Bare host — the overwhelmingly common way this field gets filled in.
  // Defaulting to https rather than http is deliberate: it is what every
  // reachable deployment actually speaks, and the alternative would hand the
  // user a URL both mobile platforms block.
  if (!s.contains('://')) s = 'https://$s';

  final uri = Uri.tryParse(s);
  if (uri == null) return (url: null, problem: ServerUrlProblem.malformed);

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return (url: null, problem: ServerUrlProblem.badScheme);
  }
  if (uri.host.isEmpty) return (url: null, problem: ServerUrlProblem.noHost);
  if (uri.userInfo.isNotEmpty) {
    return (url: null, problem: ServerUrlProblem.hasCredentials);
  }

  // Path kept, trailing slashes dropped, query and fragment discarded.
  final path = uri.path.replaceAll(RegExp(r'/+$'), '');
  final canonical = Uri(
    scheme: scheme,
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
  return (url: canonical, problem: null);
}

/// Where HTTP actions live, given a deployment URL.
///
/// Convex Cloud splits the two across sibling domains — queries and the socket
/// on `.convex.cloud`, HTTP actions on `.convex.site` — so a cloud deployment
/// URL implies its own action origin and the user should never have to type a
/// second one.
///
/// Every self-hosted `convex-backend` answers both on ONE origin, which is why
/// the fallback returns the input unchanged rather than guessing at a sibling
/// host that does not exist.
///
/// [ServerEndpoint.siteUrlOverride] survives for the deployment neither rule
/// describes: a self-host that has split the two behind separate proxies.
String deriveSiteUrl(String deploymentUrl) {
  final uri = Uri.tryParse(deploymentUrl);
  if (uri == null || uri.host.isEmpty) return deploymentUrl;
  if (!uri.host.endsWith('.convex.cloud')) return deploymentUrl;
  final swapped = uri.host.substring(
    0,
    uri.host.length - '.convex.cloud'.length,
  );
  return uri.replace(host: '$swapped.convex.site').toString();
}
