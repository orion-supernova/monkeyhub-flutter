import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The sign-in hero used to say "welcome back." to everyone, including a phone
/// that had never been signed into. These cover the marker that tells the two
/// apart — and, above all, that signing out does not reset it.
///
/// Flat in-memory keychain. Unlike device_identity_test's double this one
/// ignores the accessibility class, because none of these assertions turn on it.
class _MemoryStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> items = {};

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => items[key];

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => items[key] = value;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => items.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => items.remove(key);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      items.clear();

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => items;
}

void main() {
  late _MemoryStorage storage;
  final store = SessionStore.instance;

  setUp(() async {
    storage = _MemoryStorage();
    FlutterSecureStoragePlatform.instance = storage;
    // SessionStore is a singleton and caches both markers in memory, so a
    // reload against the fresh keychain is what resets it between tests.
    await store.loadSession();
  });

  tearDown(() async {
    storage.items.clear();
    await store.loadSession();
  });

  test('a device that has never signed in is not a returning one', () {
    expect(store.hasSignedInBefore, isFalse);
  });

  test('signing in marks the device', () async {
    await store.saveSession(userId: 'u1', username: 'murat', name: 'Murat');

    expect(store.hasSignedInBefore, isTrue);
  });

  test('the marker survives a sign-out', () async {
    await store.saveSession(userId: 'u1', username: 'murat', name: 'Murat');

    await store.clearSession();

    // The point of the whole marker: "welcome back" must still be true on the
    // next launch. clearSession deliberately leaves this key alone.
    expect(store.hasSignedInBefore, isTrue);
    await store.loadSession();
    expect(store.hasSignedInBefore, isTrue);
  });

  test('the marker survives a relaunch with no session left to restore', () async {
    await store.saveSession(userId: 'u1', username: 'murat', name: 'Murat');
    await store.clearSession();

    // loadSession returns null here and returns it early — the marker is read
    // before that happens, or the login screen would never see it.
    expect(await store.loadSession(), isNull);
    expect(store.hasSignedInBefore, isTrue);
  });

  test('the hero greets a first-time device without claiming it is back',
      () async {
    // Asserted on the strings rather than a pumped LoginScreen: that screen
    // needs a live AuthService and a Convex client, and the branch under test
    // is the string choice, not the render.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(l10n.loginScreenSignInHeroMuted, 'welcome\n');
    expect(l10n.loginScreenSignInHeroInk, 'back.');
    expect(l10n.loginScreenSignInFirstHeroMuted, 'hello\n');
    expect(l10n.loginScreenSignInFirstHeroInk, 'there.');
  });

  test('every locale ships both hero variants, and they differ', () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      final returning =
          l10n.loginScreenSignInHeroMuted + l10n.loginScreenSignInHeroInk;
      final first = l10n.loginScreenSignInFirstHeroMuted +
          l10n.loginScreenSignInFirstHeroInk;
      expect(first, isNotEmpty, reason: '$locale has no first-run hero');
      expect(
        first,
        isNot(returning),
        reason: '$locale greets a new device identically to a returning one',
      );
      expect(
        l10n.loginScreenSignInFirstHeroMuted,
        endsWith('\n'),
        reason: '$locale dropped the line break between the two halves',
      );
    }
  });

  // The redesigned hero is a title and a subtitle per mode; the first-run /
  // returning split has to survive the move in every language.
  test('every locale greets a new device differently from a returning one',
      () async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.loginTitleFirst, isNotEmpty, reason: '$locale');
      expect(
        l10n.loginTitleFirst,
        isNot(l10n.loginTitleReturning),
        reason: '$locale greets a new device as a returning one',
      );
      expect(
        l10n.loginSubtitleFirst,
        isNot(l10n.loginSubtitleSignIn),
        reason: '$locale',
      );
    }
  });
}
