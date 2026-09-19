/// The device half of Sign in with Apple / Google.
///
/// Its only job is to obtain a provider ID token and hand it up. Nothing here
/// decides anything about identity — the token is verified server-side in
/// `backend/convex/idToken.ts`, and a token this file produced is worth exactly
/// nothing until the backend has checked its signature, issuer and audience.
///
/// NATIVE flows only. No webview, no redirect URI, no custom URL scheme to
/// register — which is why moving the backend to another machine later costs
/// nothing on the auth side.
///
/// The web is the one exception, and only for Google: there the token comes
/// from Google's own rendered button rather than a call we make (see
/// [SocialSignIn.googleUsesRenderedButton]). Still no redirect URI — but the
/// web OAuth client must list the page's origin under Authorized JavaScript
/// origins, which is the one domain-bound piece of Google sign-in.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../backend/hashing.dart';
import '../env.dart';

enum SocialProvider {
  apple('apple'),
  google('google');

  const SocialProvider(this.wire);

  /// Matches the backend's `v.union(v.literal("apple"), v.literal("google"))`.
  final String wire;

  String get label => this == SocialProvider.apple ? 'Apple' : 'Google';
}

@immutable
class SocialCredential {
  const SocialCredential({
    required this.provider,
    required this.idToken,
    this.rawNonce,
    this.authorizationCode,
    this.suggestedName,
  });

  final SocialProvider provider;
  final String idToken;

  /// The PREIMAGE. Apple receives `sha256(rawNonce)` and echoes it back inside
  /// the token; the backend re-hashes this to prove the token was minted for
  /// this specific attempt.
  final String? rawNonce;

  /// Apple only. Exchanged server-side for a refresh token, which is the only
  /// way to later satisfy Apple's revoke-on-account-deletion requirement.
  final String? authorizationCode;

  /// Apple gives a name only on the FIRST authorization for an Apple ID, ever.
  /// Used to prefill the username step; never authoritative.
  final String? suggestedName;
}

/// The user backed out. Not an error — callers show nothing at all.
class SocialSignInCancelled implements Exception {
  const SocialSignInCancelled();
}

/// The provider succeeded but handed back no ID token, which leaves nothing to
/// verify. Rare, and always a configuration problem rather than a user one.
class SocialSignInNoToken implements Exception {
  const SocialSignInNoToken(this.provider);
  final SocialProvider provider;
  @override
  String toString() => 'No identity token from ${provider.label}.';
}

/// Debug-only trace of the claims that decide whether the backend will accept a
/// token: `aud`, `iss`, and whether a `nonce` is present.
///
/// This exists because the backend is deliberately opaque — every rejection
/// comes back as one of two codes that both read "try again" — so from the
/// client there is otherwise NO way to tell an audience mismatch from a nonce
/// problem from an expired token. Those three are essentially the whole failure
/// space, and all three are sitting in plain sight in the payload.
///
/// Payload only. The signature is never decoded, nothing is verified here, and
/// [kDebugMode] keeps every line of it out of release builds — a shipped app
/// must not print identity tokens to the system log.
void _traceClaims(SocialProvider provider, String idToken, String? rawNonce) {
  if (!kDebugMode) return;
  try {
    final parts = idToken.split('.');
    if (parts.length != 3) {
      debugPrint('[social] ${provider.wire}: token is not a JWT (${parts.length} parts)');
      return;
    }
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    final exp = payload['exp'];
    debugPrint(
      '[social] ${provider.wire} token claims: '
      'iss=${payload['iss']} '
      'aud=${payload['aud']} '
      'sub=${(payload['sub'] as String?)?.substring(0, 6)}… '
      'nonce=${payload['nonce'] == null ? 'ABSENT' : 'present'} '
      'weSent rawNonce=${rawNonce == null ? 'NO' : 'yes'} '
      'expiresIn=${exp is int ? '${exp - DateTime.now().millisecondsSinceEpoch ~/ 1000}s' : '?'}',
    );
    // Run the backend's own nonce check here, where the answer is visible.
    // Server-side this comparison is what decides SOCIAL_NONCE_MISMATCH, and it
    // reports nothing about why — so failing it locally first is the only way to
    // see whether the provider echoed the value we actually handed it.
    final nonceClaim = payload['nonce'];
    if (nonceClaim != null) {
      if (rawNonce == null) {
        debugPrint(
          '[social] ${provider.wire}: token carries a nonce but no preimage was '
          'sent — the backend will reject this as SOCIAL_NONCE_MISMATCH',
        );
      } else if (nonceClaim != sha256Hash(rawNonce)) {
        debugPrint(
          '[social] ${provider.wire}: NONCE MISMATCH — the provider echoed a '
          'different nonce than the one we set, so it ignored ours',
        );
      } else {
        debugPrint('[social] ${provider.wire}: nonce matches ✓');
      }
    }
  } catch (e) {
    debugPrint('[social] ${provider.wire}: could not decode token payload: $e');
  }
}

class SocialSignIn {
  const SocialSignIn._();

  /// Apple is offered on Apple platforms only.
  ///
  /// The package would also do Android and Web via a redirect flow, but that
  /// needs a Services ID and an HTTPS return URL on a domain we control — the
  /// single piece of this feature that would be domain-bound. Android users get
  /// Google instead.
  static bool get appleAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Needs the client ids AND a platform google_sign_in implements: Android,
  /// iOS, macOS and the web. Windows and Linux have no implementation at all —
  /// the platform interface's placeholder throws `UnimplementedError` from
  /// `initialize()` — so a button there could only ever end in an error.
  static bool get googleAvailable =>
      Env.googleSignInConfigured &&
      (kIsWeb ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Whether a Google sign-in has to START on Google's own rendered button.
  ///
  /// True on the web. google_sign_in 7 has no `authenticate()` there — the web
  /// plugin throws `UnimplementedError` and says to use `renderButton` —
  /// because Google Identity Services only mints an ID token from a click on
  /// its own button. No button of ours can make that call. So on the web
  /// `SocialSignInButtons` shows Google's button, and the token that click
  /// produces is handed to [google] rather than fetched by it.
  static bool get googleUsesRenderedButton => kIsWeb;

  /// Whether [forProvider] for [provider] only works right after a click on
  /// that provider's button. A caller that would otherwise skip the buttons
  /// (one provider, nothing to choose) must show them when this is true.
  static bool needsButtonTap(SocialProvider provider) =>
      provider == SocialProvider.google && googleUsesRenderedButton;

  static Future<SocialCredential> apple() async {
    // `generateNonce` ships with the package; no reason to hand-roll entropy.
    final rawNonce = generateNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        // Apple embeds this verbatim in the token's `nonce` claim. Hashed, so
        // the preimage never leaves the device until it goes to our own backend.
        nonce: sha256Hash(rawNonce),
      );

      final idToken = credential.identityToken;
      if (idToken == null) throw const SocialSignInNoToken(SocialProvider.apple);

      final name = [credential.givenName, credential.familyName]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .join(' ');

      _traceClaims(SocialProvider.apple, idToken, rawNonce);
      return SocialCredential(
        provider: SocialProvider.apple,
        idToken: idToken,
        rawNonce: rawNonce,
        authorizationCode: credential.authorizationCode,
        suggestedName: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SocialSignInCancelled();
      }
      debugPrint('[social] apple authorization failed: ${e.code} — ${e.message}');
      rethrow;
    }
  }

  static Future<SocialCredential> google() async {
    // Nothing to start on the web: Google's button already ran the flow, and
    // this only collects what it produced.
    if (googleUsesRenderedButton) return _collectWebGoogle();
    await _ensureGoogleInitialised();
    try {
      return _googleCredential(await GoogleSignIn.instance.authenticate());
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
      _logGoogleFailure(e);
      rethrow;
    }
  }

  /// The one place a Google account becomes a [SocialCredential], shared by
  /// `authenticate()` and the web button's sign-in event.
  static SocialCredential _googleCredential(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const SocialSignInNoToken(SocialProvider.google);

    final name = account.displayName?.trim();
    _traceClaims(SocialProvider.google, idToken, _googleRawNonce);
    return SocialCredential(
      provider: SocialProvider.google,
      idToken: idToken,
      // The preimage of the nonce handed to `initialize()`. See
      // [_ensureGoogleInitialised] for why this is per-launch rather than
      // per-attempt, and why omitting it is not an option.
      rawNonce: _googleRawNonce,
      suggestedName: name == null || name.isEmpty ? null : name,
    );
  }

  static void _logGoogleFailure(GoogleSignInException e) {
    // `code` is the only field that says WHICH misconfiguration this is —
    // clientConfigurationError means the ids/URL scheme/SHA-1 don't line up,
    // providerConfigurationError means Play services or Credential Manager
    // refused — and none of it survives into the copy the user sees.
    debugPrint(
      '[social] google sign-in failed: code=${e.code} '
      'description=${e.description} details=${e.details}',
    );
  }

  /// Web only: what Google's rendered button last produced — a
  /// [SocialCredential], or the error to throw in its place — parked for the
  /// [google] call that the button's `onProvider` is about to make.
  static Object? _webGoogleOutcome;
  static DateTime? _webGoogleOutcomeAt;

  /// How long a parked outcome stays collectable.
  ///
  /// Login and Linked Accounts collect it at once, inside the delivery.
  /// Profile's rename flow closes a sheet and clears the provider first, so it
  /// needs a moment. Anything older came from a click the user has since moved
  /// on from, and must not quietly become the proof for something else.
  static const Duration _webGoogleHandoff = Duration(seconds: 30);

  static final StreamController<void> _webGoogleDeliveries =
      StreamController<void>.broadcast(sync: true);

  /// Web only: fires each time Google's rendered button finishes, AFTER the
  /// outcome is parked, so a listener's `onProvider` reaches a [google] with
  /// something to return.
  ///
  /// Google's callback is page-wide, not per button. Every mounted button hears
  /// every delivery, and each must act only when it is the one on screen.
  static Stream<void> get webGoogleDeliveries => _webGoogleDeliveries.stream;

  /// Initialises Google ahead of the first tap. The web button cannot render
  /// at all until the plugin is initialised.
  static Future<void> prepareGoogle() => _ensureGoogleInitialised();

  static void _parkWebGoogle(Object outcome) {
    _webGoogleOutcome = outcome;
    _webGoogleOutcomeAt = DateTime.now();
    _webGoogleDeliveries.add(null);
  }

  static void _onWebGoogleEvent(GoogleSignInAuthenticationEvent event) {
    // A sign-out is [forgetProviders] echoing back; nothing to deliver.
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    Object outcome;
    try {
      outcome = _googleCredential(event.user);
    } catch (e) {
      outcome = e;
    }
    _parkWebGoogle(outcome);
  }

  static void _onWebGoogleError(Object error) {
    if (error is GoogleSignInException) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        _parkWebGoogle(const SocialSignInCancelled());
        return;
      }
      _logGoogleFailure(error);
    }
    _parkWebGoogle(error);
  }

  static SocialCredential _collectWebGoogle() {
    final outcome = _webGoogleOutcome;
    final at = _webGoogleOutcomeAt;
    // Taken, not read: one click is proof for exactly one request.
    _webGoogleOutcome = null;
    _webGoogleOutcomeAt = null;
    if (outcome == null ||
        at == null ||
        DateTime.now().difference(at) > _webGoogleHandoff) {
      throw StateError(
        "No Google sign-in to collect. On the web it starts on Google's own "
        'button — see SocialSignIn.needsButtonTap.',
      );
    }
    if (outcome is SocialCredential) return outcome;
    throw outcome;
  }

  static Future<SocialCredential> forProvider(SocialProvider provider) =>
      provider == SocialProvider.apple ? apple() : google();

  /// Signs out of the provider SDK, so the next tap re-prompts rather than
  /// silently reusing the last account. Best-effort: failing to clear the
  /// provider's own state must never block our sign-out.
  static Future<void> forgetProviders() async {
    try {
      if (googleAvailable) {
        // google_sign_in requires `initialize()` before any other call, and on
        // the web `signOut()` waits for one — on a restored session, where no
        // sign-in ever ran, it used to wait forever.
        await _ensureGoogleInitialised();
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      /* nothing actionable — see doc comment */
    }
  }

  /// The one initialisation, shared by everyone who asks while it runs. A
  /// bool set after the await let two callers — the web button mounting and a
  /// sign-out, say — both start one, and the plugin throws on the second.
  static Future<void>? _googleInit;

  /// The preimage behind the nonce Google echoes into every ID token it mints
  /// for this app launch. Null until [_ensureGoogleInitialised] has run.
  static String? _googleRawNonce;

  /// `initialize()` is required before any other google_sign_in call, and is
  /// idempotent from our side because of the latch.
  ///
  /// `serverClientId` is the WEB client id on BOTH platforms on purpose: it is
  /// what lands in the token's `aud`, so setting it makes the backend's
  /// allow-list a single value instead of one per platform.
  ///
  /// The web itself takes ONE id, as `clientId`, and it is that same web
  /// client — so `aud` is the same value there too and the allow-list needs
  /// nothing new. The iOS id would be worse than unused on the web: Google
  /// refuses a client that does not list the page's origin, and the web plugin
  /// asserts that `serverClientId` is left unset.
  ///
  /// THE NONCE IS NOT OPTIONAL, even though the parameter is. Google mints an
  /// ID token carrying a `nonce` claim whether or not we ask for one — Android's
  /// Credential Manager generates its own internally — and a nonce we did not
  /// choose is a nonce we can never produce the preimage for. The backend
  /// (`idToken.ts`) treats any nonce-bearing token whose preimage is missing as
  /// a failed sign-in, deliberately, because the alternative is a check that an
  /// attacker disables by leaving a field out. So the choice is not "nonce or no
  /// nonce" but "our nonce or theirs", and only ours is verifiable.
  ///
  /// Hashed on the way in, exactly like Apple: Google echoes the string it was
  /// given, so handing it `sha256(raw)` keeps the preimage on the device until
  /// it goes to our own backend, and lets the backend run one identical check
  /// for both providers.
  ///
  /// Per LAUNCH, not per attempt — `initialize()` is documented as
  /// exactly-once, and it is the only place the nonce can be set, so re-rolling
  /// it per button press would mean re-initialising into undefined behaviour.
  /// That is weaker than a per-attempt nonce and still worth having: a token
  /// minted for this same `aud` on some other device or in some earlier session
  /// carries a different nonce and cannot be replayed here.
  static Future<void> _ensureGoogleInitialised() async {
    final pending = _googleInit ??= _initialiseGoogle();
    try {
      await pending;
    } catch (_) {
      // Not cached: the next tap tries again instead of replaying this.
      if (identical(_googleInit, pending)) _googleInit = null;
      rethrow;
    }
  }

  static Future<void> _initialiseGoogle() async {
    // `generateNonce` comes from sign_in_with_apple, but there is nothing
    // Apple-specific about it — it is a cryptographically random string, and
    // reusing it keeps one source of entropy rather than two.
    _googleRawNonce = generateNonce();
    final clientId = kIsWeb ? Env.googleServerClientId : Env.googleIosClientId;
    final serverClientId = kIsWeb ? '' : Env.googleServerClientId;
    // Worth printing once: `env.local` is bundled at BUILD time, so a hot
    // restart after editing it leaves the old ids in place and every symptom
    // looks like a console misconfiguration instead of a stale binary.
    debugPrint(
      '[social] google initialize: clientId=$clientId '
      'serverClientId=$serverClientId '
      'nonce=${sha256Hash(_googleRawNonce!).substring(0, 12)}…',
    );
    await GoogleSignIn.instance.initialize(
      clientId: clientId.isEmpty ? null : clientId,
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
      nonce: sha256Hash(_googleRawNonce!),
    );
    if (googleUsesRenderedButton) {
      // For the life of the page, like the plugin it listens to.
      GoogleSignIn.instance.authenticationEvents.listen(
        _onWebGoogleEvent,
        onError: _onWebGoogleError,
      );
    }
  }
}
