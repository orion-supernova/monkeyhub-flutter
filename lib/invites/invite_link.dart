import '../backend/server_store.dart';

/// The shape of a room invite as a URL, in one place — because it is parsed
/// by three things that must agree exactly: this app, the web page
/// (`hosting/invite.template.html`, served for every `/j/*` path), and the OS
/// association files (`apple-app-site-association` / `assetlinks.json`) whose
/// path patterns decide whether the tap reaches the app at all. A change here
/// is a change to all four, and DEEP_LINKS.md is the checklist.
///
///     https://monkeyhub.walhallaa.com/j/MUZU4KUP7V
///
/// A universal link (iOS/macOS) and an App Link (Android), which is the whole
/// point: with the app installed the tap opens the room; without it, the same
/// URL is an ordinary web page that says what the invite is and where to get
/// the app. There is no interstitial and no custom scheme in the shared string
/// — those are what turn an invite pasted into a browser into a dead end.
///
/// [kInviteScheme] exists anyway as a second door, registered but never
/// handed out. Android App Link verification depends on a network fetch of
/// `assetlinks.json` at install time and silently degrades to "open in
/// browser" when that fetch failed; on a device in that state, a `monkeyhub://`
/// URL is the only thing that still reaches the app.

/// Must match `HOSTING_URL` in deploy.sh and the domain in the association
/// files. Not derived from [ServerStore]: this host serves the app's public
/// site and the association files, and it stays the same when someone points
/// their install at their own backend — a self-hoster does not also own
/// Apple's and Google's opinion about which domain opens this app.
const String kInviteSiteUrl = 'https://monkeyhub.walhallaa.com';

/// The single path segment invites live under. Short because it is retyped and
/// read aloud, and distinct from `/download`, `/downloads/` and `/web/`, which
/// the same host already answers on.
const String kInvitePathSegment = 'j';

/// The private-scheme fallback. Registered on every platform; only ever used
/// when an App Link failed to verify.
const String kInviteScheme = 'monkeyhub';

/// The first segment of the iOS Share Extension's wake-up URL,
/// `monkeyhub://share/open` — which shares [kInviteScheme] because that scheme
/// is already registered on every platform and a second one would be a second
/// thing to keep in agreement.
///
/// It exists in THIS file because the invite parser is the only thing that
/// would otherwise misread it. See [parseInviteLink]'s refusal at the top: the
/// parser's last resort is "treat it as a typed code", and without an explicit
/// refusal `monkeyhub://share/open` becomes the invite code `SHAREOPEN` and
/// opens a join screen for a room that has never existed.
///
/// The extension carries the same string in `ios/Shared/ShareGroup.swift`;
/// `share_link_test.dart` pins the two together.
const String kSharePathSegment = 'share';

/// A code that is GUARANTEED never to be a real one. Use this, and only this,
/// anywhere an example code is shown or written down.
///
/// The server mints from Crockford base32 — no I, L, O or U — and
/// `roomInvites.normalizeCode` folds I and L to `1` and O to `0` so a typo
/// still resolves. **U is the one excluded letter that is neither minted nor
/// folded**, so any string containing one cannot match a live invite, now or
/// after a rotation.
///
/// That matters because an example is a lottery ticket otherwise: a
/// placeholder that looks like a code eventually IS somebody's code, and a
/// screenshot or a doc becomes a working key to a private room. 50 bits makes
/// that unlikely, not impossible — and "unlikely" is the wrong standard for a
/// string we choose ourselves and print forever.
///
/// Keep the U if you change it.
const String kExampleInviteCode = 'MUZU4KUP7V';


/// Query parameter naming the backend an invite belongs to.
///
/// Present ONLY when the sharer is on a server other than the shipped one.
/// A room id means nothing on a different deployment, so without this a
/// self-hoster's invite would resolve, on a default install, to either "no
/// such link" or — far worse — some unrelated room that happens to hold the
/// same id. With it, the recipient can be told plainly that the invite is for
/// a different server instead of being silently misrouted.
const String kInviteServerParam = 's';

/// A parsed invite URL.
class InviteLink {
  const InviteLink({required this.code, this.serverUrl});

  /// The token, separators stripped and upper-cased — see [_normalizeCode] for
  /// why the casing is load-bearing rather than cosmetic. The server normalizes
  /// again on redemption; this only has to be right about INPUT.
  final String code;

  /// The deployment this invite belongs to, when the sharer said so. Null
  /// means "the shipped default", which is the overwhelmingly common case.
  final String? serverUrl;

  /// Whether this invite belongs to the backend this install is currently
  /// talking to.
  ///
  /// Null [serverUrl] is trusted as "the default deployment" and compared
  /// against the bundled URL, NOT waved through — an install pointed at a
  /// self-hosted box must not treat a default-server invite as its own.
  bool matchesActiveServer(ServerStore store) {
    final expected = serverUrl ?? store.bundledUrl;
    if (expected.isEmpty) return true;
    return _sameOrigin(expected, store.deploymentUrl);
  }
}

/// The URL to hand out for [code].
///
/// [serverUrl] should be [ServerStore.deploymentUrl] when the caller is on a
/// custom server and null otherwise; [inviteUrlForCurrentServer] makes that
/// decision so no call site has to remember it.
String inviteUrl(String code, {String? serverUrl}) {
  final base = '$kInviteSiteUrl/$kInvitePathSegment/$code';
  if (serverUrl == null || serverUrl.isEmpty) return base;
  return '$base?$kInviteServerParam=${Uri.encodeComponent(serverUrl)}';
}

/// The URL to share from THIS install, with the server tag attached only when
/// it is actually needed.
///
/// Deliberately silent on the ordinary deployment: tagging every invite with
/// the backend address would publish infrastructure into every shared link and
/// make the common case uglier to serve a case most users never hit.
String inviteUrlForCurrentServer(String code, {ServerStore? store}) {
  final s = store ?? ServerStore.instance;
  final onDefault = !s.isCustom || _sameOrigin(s.deploymentUrl, s.bundledUrl);
  return inviteUrl(code, serverUrl: onDefault ? null : s.deploymentUrl);
}

/// Pull an invite out of anything the OS might hand us, or null.
///
/// Accepts the shared https form, the private-scheme fallback in both the
/// `monkeyhub://join/CODE` and `monkeyhub://j/CODE` spellings, and a bare code
/// typed into the join box. Anything else — including a link to this same host
/// that is not an invite — returns null rather than guessing, because the
/// caller's next move is to open a join screen and the wrong guess there is a
/// confusing dead end rather than a harmless no-op.
InviteLink? parseInviteLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // The share-extension handoff, refused before anything else looks at it.
  //
  // Refused rather than merely unmatched, because "unmatched" is not a safe
  // state in this function: every shape that falls past the branches below
  // ends at [_bareCode], which strips the separators and calls what is left a
  // code. `monkeyhub://share/open` would become `SHAREOPEN`, and the route
  // form the engine reports it as (`/share/open`, or `/open` depending on the
  // platform) would become `SHAREOPEN` or `OPEN`. All three open a join screen
  // for a room that does not exist, from a URL the app sent itself.
  if (_isShareHandoff(trimmed)) return null;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || (!uri.hasScheme && uri.pathSegments.length <= 1)) {
    // No scheme and a single segment: someone typed or pasted a bare code.
    return _bareCode(trimmed);
  }

  final server = uri.queryParameters[kInviteServerParam];

  if (uri.scheme == 'http' || uri.scheme == 'https') {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // Only the exact `/j/<code>` shape. Matching loosely here would turn every
    // other link this host serves — `/download`, `/web/`, the landing page —
    // into a broken join attempt.
    if (segments.length != 2 || segments[0] != kInvitePathSegment) return null;
    return InviteLink(code: _normalizeCode(segments[1]), serverUrl: server);
  }

  if (uri.scheme == kInviteScheme) {
    // A custom scheme has no authority, so `monkeyhub://join/CODE` parses with
    // "join" as the HOST and the code as the path — while `monkeyhub:///j/X`
    // puts both in the path. Flattening the two makes the accepted spellings
    // independent of which one the sending platform produced.
    final parts = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (parts.isEmpty) return null;
    // `parts[0]` may have come from `uri.host`, which Dart lower-cases
    // because hosts are case-insensitive. Codes are not — hence
    // [_normalizeCode], and hence the case-insensitive comparison on the
    // `join`/`j` marker below.
    if (parts.length == 1) {
      return InviteLink(code: _normalizeCode(parts[0]), serverUrl: server);
    }
    final marker = parts[0].toLowerCase();
    if (marker == 'join' || marker == kInvitePathSegment) {
      return InviteLink(code: _normalizeCode(parts[1]), serverUrl: server);
    }
    return null;
  }

  // Scheme-less, but with a path: this is what the PLATFORM hands us.
  //
  // `WidgetsBindingObserver.didPushRouteInformation` reports a location, not
  // the original URL — `monkeyhub://join/ABC` arrives as `/ABC` and
  // `https://…/j/ABC` as `/j/ABC`. Falling through to [_bareCode] turned the
  // second into the literal code `JABC`, because stripping the separators from
  // `/j/ABC` leaves the marker glued to the front.
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length >= 2) {
    final marker = segments[0].toLowerCase();
    if (marker == 'join' || marker == kInvitePathSegment) {
      return InviteLink(code: _normalizeCode(segments[1]), serverUrl: server);
    }
    return null;
  }

  return _bareCode(trimmed);
}

/// Whether [raw] is the share-extension handoff rather than an invite.
///
/// Matches on the first meaningful segment however the platform spelled the
/// URL — `monkeyhub://share/open` puts `share` in the HOST, `/share/open` puts
/// it in the path, and both have to be refused.
///
/// The cost is that the literal string `share` can no longer be typed into the
/// join box as a bare code. Codes are ten Crockford characters, so that was
/// never one.
bool _isShareHandoff(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  final parts = [
    if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((s) => s.isNotEmpty),
  ];
  return parts.isNotEmpty && parts.first.toLowerCase() == kSharePathSegment;
}

/// A typed code, accepted with or without the dashes the UI shows it with.
/// Length is NOT checked here — `roomInvites.normalizeCode` owns that, and
/// duplicating it would mean a client that rejects a valid code after the
/// server's format changed.
InviteLink? _bareCode(String raw) {
  final cleaned = _normalizeCode(raw);
  if (cleaned.isEmpty) return null;
  return InviteLink(code: cleaned);
}

/// Strip separators and upper-case.
///
/// Upper-casing is NOT cosmetic here, and it is not the locale-unsafe kind:
/// `monkeyhub://CODE` parses with the code as the URI's HOST, and Dart
/// lower-cases hosts because hosts are case-insensitive. Without this, the
/// bare-scheme fallback — the only door left on a device where App Link
/// verification failed — hands back a code that matches nothing.
///
/// `String.toUpperCase()` is invariant-locale, not device-locale, so a Turkish
/// handset maps `i` to `I` rather than `İ`. Over this code's A–Z/0–9 alphabet
/// that is exactly the wanted behaviour, and it matches what
/// `roomInvites.normalizeCode` does server-side. (Display strings are a
/// different matter entirely — see the note in `room_invite_sheet.dart`.)
String _normalizeCode(String raw) =>
    raw.trim().replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();

/// Scheme + host + port equality, ignoring trailing slashes and case.
/// Deliberately not full string equality — `https://x.com` and
/// `https://x.com/` are the same backend and have both been written into
/// `env.local` at different times.
bool _sameOrigin(String a, String b) {
  final ua = Uri.tryParse(a.trim());
  final ub = Uri.tryParse(b.trim());
  if (ua == null || ub == null) return false;
  return ua.scheme.toLowerCase() == ub.scheme.toLowerCase() &&
      ua.host.toLowerCase() == ub.host.toLowerCase() &&
      ua.port == ub.port;
}
