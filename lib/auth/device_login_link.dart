/// The device-login QR, in one place — builder and parser together, for the
/// same reason `invite_link.dart` keeps its pair together: they are read by
/// things that must agree exactly, and they were previously a hundred lines
/// apart in two unrelated files (`device_login_panel.dart` built the URI,
/// `device_login_scan_screen.dart` parsed it) with nothing pinning them.
///
///     monkeyhub://devicelogin?r=<32 hex chars>
///
/// Deliberately the private scheme rather than an https universal link. An
/// invite is a URL you hand to someone else and it has to survive landing in a
/// browser on a phone with no app installed; this one is only ever rendered as
/// a QR on a screen the account holder is already looking at, and scanned by
/// their own phone seconds later. There is nothing useful for a browser to
/// show, and a signed-out web page that accepted a request id would be a
/// phishing surface rather than a convenience.
///
/// Three cameras produce this string and all three are handled:
///
///  * the in-app scanner on `DeviceLoginScanScreen`, which reads the raw
///    barcode and calls [parseDeviceLoginRequestId] directly;
///  * the phone's own **Camera app**, which opens it as a deep link — see
///    `DeepLinkService.onDeviceLogin`. This is the common case, and the one
///    that used to land in the invite parser and report a missing room;
///  * a QR reader that hands over the bare id with the URL stripped, which
///    [parseDeviceLoginRequestId] also accepts.
library;

import '../invites/invite_link.dart'
    show kDeviceLoginPathSegment, kInviteScheme;

/// The URI the QR encodes for [requestId].
String deviceLoginUri(String requestId) =>
    '$kInviteScheme://$kDeviceLoginPathSegment?r=$requestId';

/// Pull the request id out of whatever a scanner saw, or null.
///
/// Accepts the full URI and a bare id, mirroring `extractPairingCode` in
/// `child_pair_screen.dart`.
///
/// The shape check is not cosmetic: it is what makes this safe to call on
/// every deep link the OS delivers. `r` is 16 random bytes hex-encoded by
/// `randomHex` in `deviceLogin.ts`, so anything that is not exactly 32 hex
/// characters cannot be a request id this app minted, and is refused here
/// rather than sent to the server to be refused there.
String? parseDeviceLoginRequestId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  // A custom scheme has no authority, so the marker is the HOST here and the
  // whole path is empty — the same flattening `invite_link.dart` does.
  final fromQuery = uri?.queryParameters['r'];
  final candidate = (fromQuery != null && fromQuery.isNotEmpty)
      ? fromQuery
      : trimmed;
  return _isRequestId(candidate) ? candidate : null;
}

/// Whether [raw] is a device-login URI specifically — used by the deep-link
/// router to decide whether a URL is its business at all, before it cares
/// whether the id inside is well formed.
///
/// Separate from [parseDeviceLoginRequestId] because the two answer different
/// questions: a `monkeyhub://devicelogin?r=garbage` is unmistakably ours and
/// must NOT fall through to the invite parser, even though there is no usable
/// id in it.
bool isDeviceLoginUri(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  final parts = [
    if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments.where((s) => s.isNotEmpty),
  ];
  return parts.isNotEmpty &&
      parts.first.toLowerCase() == kDeviceLoginPathSegment;
}

/// 16 random bytes, hex-encoded — see `randomHex` in `deviceLogin.ts`.
bool _isRequestId(String s) => RegExp(r'^[0-9a-f]{32}$').hasMatch(s);
