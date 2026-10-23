import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_errors.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/session_guard.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';

/// After a ban signs the device out, the banned token is lent to
/// `auth:deleteAccount` and nothing else, until the user moves on.
class _FakeApi extends Fake implements ChatApi {
  String? deletedUserId;

  /// When set, the token path is refused with this error.
  Object? tokenPathError;
  String? provedWithPassword;
  @override
  Future<void> deleteAccount({required String userId}) async {
    if (tokenPathError != null) throw tokenPathError!;
    deletedUserId = userId;
  }

  @override
  Future<void> deleteSuspendedAccountWithPassword({
    required String username,
    required String password,
  }) async => provedWithPassword = '$username:$password';
}

class _MemoryStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> items = {};
  @override
  Future<String?> read({required String key, required Map<String, String> options}) async => items[key];
  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async => items[key] = value;
  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async => items.containsKey(key);
  @override
  Future<void> delete({required String key, required Map<String, String> options}) async => items.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async => items.clear();
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => items;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final guard = SessionGuard.instance;
  final store = SessionStore.instance;
  late _FakeApi api;
  late AuthService auth;

  setUp(() async {
    FlutterSecureStoragePlatform.instance = _MemoryStorage();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await store.clearSession();
    store.discardOutgoingToken();
    guard.reset();
    await store.saveSession(userId: 'u-1', username: 'bad', name: 'bad', token: 't-banned');
    api = _FakeApi();
    auth = AuthService(api);
    await auth.restore();
    guard.onSessionLost = () => auth.forceSignOut();
  });

  tearDown(() => guard.onSessionLost = null);

  String? tokenFor(String fn) =>
      guard.attachedToken(fn, live: store.token, outgoing: store.outgoingToken);

  Future<void> ban() async {
    guard.noteError(Exception('ACCOUNT_SUSPENDED'), carried: 't-banned', live: 't-banned');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('after a ban only deleteAccount carries the banned token', () async {
    await ban();
    expect(auth.session, isNull);
    expect(tokenFor('auth:deleteAccount'), 't-banned');
    expect(tokenFor('rooms:list'), isNull);
    expect(tokenFor('auth:logout'), 't-banned');
  });

  test('without a ban, deleteAccount gets no outgoing token', () async {
    await auth.signOut();
    expect(tokenFor('auth:deleteAccount'), isNull);
  });

  test('a plain revocation does not unlock it either', () async {
    guard.noteError(Exception('SESSION_REVOKED'), carried: 't-banned', live: 't-banned');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(tokenFor('auth:deleteAccount'), isNull);
  });

  test('dismissing the notice drops the token', () async {
    await ban();
    guard.dismissSuspension();
    expect(tokenFor('auth:deleteAccount'), isNull);
    expect(store.outgoingToken, isNull);
  });

  test('deleteSuspendedAccount sends the banned id and clears the offer', () async {
    await ban();
    await auth.deleteSuspendedAccount();
    expect(api.deletedUserId, 'u-1');
    expect(guard.suspensionPending, isFalse);
    expect(tokenFor('auth:deleteAccount'), isNull);
  });

  test('signing in again ends the offer', () async {
    await ban();
    await store.saveSession(userId: 'u-2', username: 'ok', name: 'ok', token: 't-new');
    guard.reset();
    expect(tokenFor('auth:deleteAccount'), 't-new');
    expect(store.outgoingToken, isNull);
    await expectLater(auth.deleteSuspendedAccount(), throwsStateError);
  });

  test('a proof the user typed wins over the held token of another account', () async {
    await ban();
    // The held token is account u-1's; the form carries another account's proof.
    await auth.deleteSuspendedAccount(username: 'other', password: 'pw');
    expect(api.provedWithPassword, 'other:pw');
    expect(api.deletedUserId, isNull);
    expect(guard.suspensionPending, isFalse);
  });

  test('a garbage-collected ban token with no proof asks for one', () async {
    await ban();
    api.tokenPathError = Exception('SESSION_UNKNOWN');
    await expectLater(auth.deleteSuspendedAccount(), throwsStateError);
    expect(guard.suspensionPending, isTrue); // a proof can still follow
    expect(api.provedWithPassword, isNull);
  });

  test('a network failure on the token path stays retryable', () async {
    await ban();
    api.tokenPathError = Exception('socket closed');
    await expectLater(auth.deleteSuspendedAccount(), throwsA(isA<Exception>()));
    expect(api.provedWithPassword, isNull);
    expect(guard.suspensionPending, isTrue);
    api.tokenPathError = null;
    await auth.deleteSuspendedAccount();
    expect(api.deletedUserId, 'u-1');
  });

  test('the guard remembers the banned username for the confirm sheet', () async {
    await ban();
    expect(guard.suspendedUsername, 'bad');
    guard.dismissSuspension();
    expect(guard.suspendedUsername, isNull);
  });

  test('after the app restarted, only the proof path exists', () async {
    // No ban noted: nothing pending, no token.
    await auth.deleteSuspendedAccount(username: 'bad', password: 'pw');
    expect(api.provedWithPassword, 'bad:pw');
    expect(api.deletedUserId, isNull);
  });

  group('suspendedDeleteOutcome', () {
    final l10n = AppLocalizationsEn();
    SuspendedDeleteOutcome of(String e) =>
        suspendedDeleteOutcome(Exception(e), l10n);

    test('final refusals carry their own copy and no retry', () {
      for (final code in ['LAST_GUARDIAN', 'CHILD_MUST_PAIR', 'CHILD_NOT_ALLOWED']) {
        final o = of('Uncaught Error: $code at handler');
        expect(o.next, SuspendedDeleteNext.final_, reason: code);
        expect(o.message, isNot(l10n.authSuspendedDeleteFailed), reason: code);
      }
      expect(of('LAST_GUARDIAN').message, l10n.authErrorLastGuardian);
    });

    test('a wrong password is correctable, not retried blindly', () {
      expect(of('ServerRefusal: WRONG_PASSWORD').next, SuspendedDeleteNext.edit);
      expect(of('ServerRefusal: WRONG_PASSWORD').message, l10n.authErrorWrongPassword);
    });

    test('an expired provider token asks for a fresh sheet', () {
      final o = of('Uncaught Error: SOCIAL_TOKEN_INVALID');
      expect(o.next, SuspendedDeleteNext.signInAgain);
      expect(o.message, l10n.authSuspendedDeleteSignInAgain);
    });

    test('only an unrecognised failure (network) offers Try again', () {
      final o = of('socket closed');
      expect(o.next, SuspendedDeleteNext.retry);
      expect(o.message, l10n.authSuspendedDeleteFailed);
    });
  });
}
