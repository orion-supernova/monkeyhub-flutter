import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/session_guard.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/backend/chat_api.dart';

/// The repair for a device whose keychain and token disagree about who it is.
///
/// That state was reachable because the session used to be five separate
/// keychain items written in sequence: a write that failed partway left one
/// account's token beside another account's userId and username. `functions.ts`
/// resolves identity from the TOKEN, so such a device went on operating as the
/// newer account while every screen rendered the older one's name — and the
/// profile fetch that should have corrected it asked using the stale userId,
/// got `null` for a deleted row, and threw the answer away.
///
/// Storing the session as one item stops new splits. [AuthService.reconcile]
/// is what heals the installs that already have one.
class _FakeApi extends Fake implements ChatApi {
  _FakeApi(this._answer);

  final Session? Function() _answer;
  int calls = 0;

  @override
  Future<Session?> whoami() async {
    calls++;
    return _answer();
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
  late _MemoryStorage keychain;
  final store = SessionStore.instance;

  setUp(() async {
    keychain = _MemoryStorage();
    FlutterSecureStoragePlatform.instance = keychain;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await store.clearSession();
    SessionGuard.instance.reset();
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<AuthService> signedInAs({
    required String userId,
    required String username,
    required _FakeApi api,
  }) async {
    await store.saveSession(
      userId: userId,
      username: username,
      name: username,
      token: 't-real',
    );
    final auth = AuthService(api);
    await auth.restore();
    return auth;
  }

  test('a device that already agrees with the server is left alone', () async {
    final api = _FakeApi(
      () => Session(userId: 'u-lulu', username: 'lulu', name: 'lulu'),
    );
    final auth = await signedInAs(
      userId: 'u-lulu',
      username: 'lulu',
      api: api,
    );

    var notified = 0;
    auth.addListener(() => notified++);
    await auth.reconcile();

    expect(api.calls, 1);
    expect(auth.session!.username, 'lulu');
    // No listener churn for a no-op: every screen rebuilds on this.
    expect(notified, 0);
  });

  /// THE case. The keychain says `goksu` — an account that has since been
  /// deleted — while the token belongs to `lulu`.
  test('a split identity adopts the account the token belongs to', () async {
    final api = _FakeApi(
      () => Session(userId: 'u-lulu', username: 'lulu', name: 'Lulu'),
    );
    final auth = await signedInAs(
      userId: 'u-goksu',
      username: 'goksu',
      api: api,
    );
    expect(auth.session!.username, 'goksu');

    await auth.reconcile();

    expect(auth.session!.username, 'lulu');
    expect(auth.session!.userId, 'u-lulu');

    // And it is repaired on disk, not just in memory — otherwise the next cold
    // start would show `goksu` all over again.
    final reloaded = await store.loadSession();
    expect(reloaded!.username, 'lulu');
    expect(reloaded.userId, 'u-lulu');
    // The token was never in question; it is what was right all along.
    expect(store.token, 't-real');
  });

  test('a network failure changes nothing and does not sign anyone out',
      () async {
    final api = _FakeApi(() => throw StateError('offline'));
    final auth = await signedInAs(
      userId: 'u-lulu',
      username: 'lulu',
      api: api,
    );

    await auth.reconcile();

    // "Ask again next launch", not "sign out". The token is not in doubt here,
    // only the name attached to it.
    expect(auth.session, isNotNull);
    expect(auth.session!.username, 'lulu');
  });

  test('a signed-out app has nothing to reconcile', () async {
    final api = _FakeApi(
      () => Session(userId: 'u-lulu', username: 'lulu', name: 'lulu'),
    );
    final auth = AuthService(api);
    await auth.restore();

    await auth.reconcile();

    expect(api.calls, 0);
  });

  /// A null own-profile has TWO causes and they want opposite outcomes, so the
  /// backstop asks rather than assumes. This is the benign one: the account is
  /// fine, the keychain userId had drifted. Signing this device out would be a
  /// regression — it works, it is only mislabelled.
  test('an empty own-profile from a stale id repairs instead of signing out',
      () async {
    final api = _FakeApi(
      () => Session(userId: 'u-lulu', username: 'lulu', name: 'Lulu'),
    );
    final auth = await signedInAs(
      userId: 'u-goksu',
      username: 'goksu',
      api: api,
    );

    var lost = 0;
    SessionGuard.instance.onSessionLost = () => lost++;
    addTearDown(() => SessionGuard.instance.onSessionLost = null);

    auth.onSelfProfileMissing();
    await pumpEventQueue();

    expect(lost, 0);
    expect(auth.session!.username, 'lulu');
  });

  /// The other cause: the account really is gone. `whoami` throws
  /// SESSION_REVOKED from the transport layer, where `ConvexBackend` reports
  /// it to `SessionGuard` — so the sign-out happens on the server's word.
  test('an empty own-profile from a deleted account ends in a sign-out',
      () async {
    final api = _FakeApi(() => throw StateError('SESSION_REVOKED'));
    final auth = await signedInAs(
      userId: 'u-goksu',
      username: 'goksu',
      api: api,
    );

    var lost = 0;
    SessionGuard.instance.onSessionLost = () => lost++;
    addTearDown(() => SessionGuard.instance.onSessionLost = null);

    // Standing in for `ConvexBackend`, which is what calls this on a real
    // failed request — `reconcile` deliberately swallows the error itself.
    auth.onSelfProfileMissing();
    await pumpEventQueue();
    SessionGuard.instance.noteError(StateError('SESSION_REVOKED'));

    expect(lost, 1);
    // Latched: a dead account fails every screen's fetch in the same frame,
    // and five simultaneous sign-outs would fight the navigator.
    SessionGuard.instance.noteError(StateError('SESSION_REVOKED'));
    expect(lost, 1);
  });
}
