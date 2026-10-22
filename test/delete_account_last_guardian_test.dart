import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_errors.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/session_guard.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// A sole guardian deleting their account is refused server-side with
/// `LAST_GUARDIAN`. The account still exists then, so the device must stay
/// signed in and the message must say what to do.
class _FakeApi extends Fake implements ChatApi {
  _FakeApi(this.error);
  final Object? error;

  @override
  Future<void> deleteAccount({required String userId}) async {
    if (error != null) throw error!;
  }
}

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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStoragePlatform.instance = _MemoryStorage();
    await SessionStore.instance.clearSession();
    SessionGuard.instance.reset();
  });

  Future<AuthService> signedIn(Object? error) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await SessionStore.instance.saveSession(
      userId: 'u-1',
      username: 'mum',
      name: 'mum',
      token: 't-real',
    );
    final auth = AuthService(_FakeApi(error));
    await auth.restore();
    return auth;
  }

  test('LAST_GUARDIAN refusal rethrows and stays signed in', () async {
    final auth = await signedIn(Exception('Uncaught Error: LAST_GUARDIAN'));
    await expectLater(auth.deleteAccount(), throwsException);
    expect(auth.session, isNotNull);
    expect(SessionStore.instance.token, 't-real');
  });

  test('a dropped connection still signs out (ambiguous outcome)', () async {
    final auth = await signedIn(Exception('socket closed'));
    await expectLater(auth.deleteAccount(), throwsException);
    expect(auth.session, isNull);
  });

  test('a lost session still signs out', () async {
    final auth = await signedIn(Exception('SESSION_REVOKED'));
    await expectLater(auth.deleteAccount(), throwsException);
    expect(auth.session, isNull);
  });

  test('success signs out', () async {
    final auth = await signedIn(null);
    await auth.deleteAccount();
    expect(auth.session, isNull);
  });

  testWidgets('LAST_GUARDIAN maps to the specific message', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            l10n = AppLocalizations.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    final msg = humanizeAuthError(
      Exception('Uncaught Error: LAST_GUARDIAN'),
      l10n,
      fallback: 'generic',
    );
    expect(msg, l10n.authErrorLastGuardian);
    expect(msg, isNot('generic'));
    expect(msg, contains('guardian'));
  });
}
