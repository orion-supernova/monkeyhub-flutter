import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/session_guard.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/backend/chat_api.dart';

/// After a ban signs the device out, the banned token is lent to
/// `auth:deleteAccount` and nothing else, until the user moves on.
class _FakeApi extends Fake implements ChatApi {
  String? deletedUserId;
  @override
  Future<void> deleteAccount({required String userId}) async =>
      deletedUserId = userId;
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
}
