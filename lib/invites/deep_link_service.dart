import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../auth/device_login_link.dart';
import 'invite_link.dart';

/// Inbound links, from the OS to the app.
///
/// Two arrival paths and they behave differently, which is the whole reason
/// this class exists rather than a `listen` somewhere in `app.dart`:
///
///  * **Cold start** — the app was not running. The URL is waiting in
///    [AppLinks.getInitialLink] and has ALREADY happened; nothing will re-emit
///    it. Miss it and the tap silently did nothing.
///  * **Warm** — the app was backgrounded. The URL arrives on the stream, and
///    can arrive at any moment, including while the user is mid-call or on the
///    login screen.
///
/// Both are read here and both go to the same [onInvite], so no caller has to
/// know which one it got. What a caller DOES have to handle is that a link can
/// land before the app is ready for it — before auth is restored, before the
/// root navigator is mounted — so the callback is expected to stash and replay
/// rather than assume it can navigate. That is the same rule the push-tap
/// handler in `app.dart` already follows, and for the same reason.
///
/// Deliberately narrow: it reports the two URL shapes this app actually sends
/// itself, and nothing else. Every other URL the OS might hand us — including
/// links to this app's own site that are not invites — is dropped, because the
/// alternative is a generic router that guesses, and a wrong guess here opens
/// a screen the user did not ask for.
///
/// The device-login case is here rather than left to the in-app scanner
/// because the QR on a desktop sign-in screen is most often scanned with the
/// phone's own **Camera app**, not from inside this app. That path used to
/// reach [parseInviteLink], which read `monkeyhub://devicelogin?r=…` as the
/// invite code `DEVICELOGIN` and opened a join screen reporting a missing
/// room. Refusing it there is only half the fix — this is the other half.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  AppLinks? _links;
  StreamSubscription<Uri>? _sub;

  /// Called with the parsed invite. May fire before the app can act on it.
  void Function(InviteLink invite)? onInvite;

  /// Called with a device-login request id scanned from a desktop or web
  /// sign-in QR. Same "may fire before the app is ready" contract as
  /// [onInvite] — and one more caveat of its own: approving is only meaningful
  /// while signed in, so the handler is expected to drop it (not stash it) when
  /// there is no session. A signed-out phone cannot approve anything, and a
  /// request replayed after a later sign-in would be long expired.
  void Function(String requestId)? onDeviceLogin;

  bool _started = false;

  /// Begins listening. Idempotent — safe to call from a widget's `initState`
  /// that can run more than once across a hot restart or a server switch.
  ///
  /// Never throws. Deep linking is unsupported or unconfigured on some
  /// platforms and builds (a bare `flutter run` on desktop, a web build served
  /// from a path the association files do not cover), and an app that failed to
  /// start because an optional URL channel was missing would be a much worse
  /// bug than the one this prevents.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final links = _links ??= AppLinks();
      // The stream first, then the initial link. The other order has a real
      // race on Android: a link delivered between reading the initial value
      // and attaching the listener belongs to neither, and is lost.
      _sub = links.uriLinkStream.listen(
        _handle,
        onError: (Object e) => debugPrint('deep link stream error: $e'),
      );
      final initial = await links.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('deep links unavailable: $e');
    }
  }

  /// Feed a URL in by hand — a pasted link, a QR scan, a test.
  void handleExternal(String raw) => _route(raw);

  void _handle(Uri uri) => _route(uri.toString());

  /// The single place a URL is classified, so the stream, the cold-start link
  /// and [handleExternal] cannot diverge.
  void _route(String raw) {
    // Device login first. `isDeviceLoginUri` matches the SHAPE, so a malformed
    // id is swallowed here rather than falling through to the invite parser
    // and being mistaken for a typed code.
    if (isDeviceLoginUri(raw)) {
      final requestId = parseDeviceLoginRequestId(raw);
      if (requestId == null) {
        debugPrint('device login link ignored (no usable request id): $raw');
        return;
      }
      onDeviceLogin?.call(requestId);
      return;
    }
    final parsed = parseInviteLink(raw);
    if (parsed == null) {
      debugPrint('deep link ignored (not an invite): $raw');
      return;
    }
    onInvite?.call(parsed);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
