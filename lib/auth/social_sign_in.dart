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
library;

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

  static bool get googleAvailable => Env.googleSignInConfigured;

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
    await _ensureGoogleInitialised();
    try {
      final account = await GoogleSignIn.instance.authenticate();
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
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
      // `code` is the only field that says WHICH misconfiguration this is —
      // clientConfigurationError means the ids/URL scheme/SHA-1 don't line up,
      // providerConfigurationError means Play services or Credential Manager
      // refused — and none of it survives into the copy the user sees.
      debugPrint(
        '[social] google sign-in failed: code=${e.code} '
        'description=${e.description} details=${e.details}',
      );
      rethrow;
    }
  }

  static Future<SocialCredential> forProvider(SocialProvider provider) =>
      provider == SocialProvider.apple ? apple() : google();

  /// Signs out of the provider SDK, so the next tap re-prompts rather than
  /// silently reusing the last account. Best-effort: failing to clear the
  /// provider's own state must never block our sign-out.
  static Future<void> forgetProviders() async {
    try {
      if (googleAvailable) await GoogleSignIn.instance.signOut();
    } catch (_) {
      /* nothing actionable — see doc comment */
    }
  }

  static bool _googleInitialised = false;

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
    if (_googleInitialised) return;
    // `generateNonce` comes from sign_in_with_apple, but there is nothing
    // Apple-specific about it — it is a cryptographically random string, and
    // reusing it keeps one source of entropy rather than two.
    _googleRawNonce = generateNonce();
    // Worth printing once: `env.local` is bundled at BUILD time, so a hot
    // restart after editing it leaves the old ids in place and every symptom
    // looks like a console misconfiguration instead of a stale binary.
    debugPrint(
      '[social] google initialize: clientId=${Env.googleIosClientId} '
      'serverClientId=${Env.googleServerClientId} '
      'nonce=${sha256Hash(_googleRawNonce!).substring(0, 12)}…',
    );
    await GoogleSignIn.instance.initialize(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId:
          Env.googleServerClientId.isEmpty ? null : Env.googleServerClientId,
      nonce: sha256Hash(_googleRawNonce!),
    );
    _googleInitialised = true;
  }
}
