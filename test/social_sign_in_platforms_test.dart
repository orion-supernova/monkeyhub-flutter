import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';

/// Where Google sign-in is offered, and how it has to start.
///
/// google_sign_in implements Android, iOS, macOS and the web only. Everywhere
/// else its placeholder throws `UnimplementedError`, which is what the web used
/// to show too, from `authenticate()` — so both halves are pinned here.
void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GOOGLE_SERVER_CLIENT_ID=test-client-id');
  });

  test('offered only where google_sign_in has an implementation', () {
    final offered = <TargetPlatform>[];
    try {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        if (SocialSignIn.googleAvailable) offered.add(platform);
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(offered, unorderedEquals([
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]));
  });

  test('natively, no provider waits on a click on its own button', () {
    // The web answers true for Google — see googleUsesRenderedButton. A native
    // build that did too would leave the rename flow showing a pointless sheet.
    expect(SocialSignIn.googleUsesRenderedButton, isFalse);
    for (final provider in SocialProvider.values) {
      expect(SocialSignIn.needsButtonTap(provider), isFalse);
    }
  });
}
