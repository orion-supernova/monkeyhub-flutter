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
      return SocialCredential(
        provider: SocialProvider.google,
        idToken: idToken,
        // Deliberately no nonce. google_sign_in 7.x takes the nonce in
        // `initialize()`, not per attempt, so a per-sign-in nonce would mean
        // re-initialising the plugin on every button press. The backend treats a
        // token with no `nonce` claim as acceptable, and the protection that
        // actually matters here — a token minted for a DIFFERENT app being
        // replayed at ours — is the audience check, which is unaffected.
        //
        // Note the backend cannot be tricked by simply omitting this: if a token
        // does carry a nonce, the preimage becomes mandatory.
        suggestedName: name == null || name.isEmpty ? null : name,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SocialSignInCancelled();
      }
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

  /// `initialize()` is required before any other google_sign_in call, and is
  /// idempotent from our side because of the latch.
  ///
  /// `serverClientId` is the WEB client id on BOTH platforms on purpose: it is
  /// what lands in the token's `aud`, so setting it makes the backend's
  /// allow-list a single value instead of one per platform.
  static Future<void> _ensureGoogleInitialised() async {
    if (_googleInitialised) return;
    await GoogleSignIn.instance.initialize(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId:
          Env.googleServerClientId.isEmpty ? null : Env.googleServerClientId,
    );
    _googleInitialised = true;
  }
}
