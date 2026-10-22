import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/push/device_identity.dart';

/// The per-install device proof: minted once, kept, and sent to the sign-in
/// mutations and nothing else.
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

class _FakeCv extends Fake implements ConvexBackend {
  final Map<String, Map<String, dynamic>> sent = {};
  static const _auth = {
    'userId': 'u',
    'username': 'n',
    'name': 'n',
    'token': 't',
  };

  @override
  Future<dynamic> mutation(String name, Map<String, dynamic> args) async {
    sent[name] = args;
    return name == 'auth:logout' ? null : _auth;
  }

  @override
  Future<dynamic> action(String name, Map<String, dynamic> args) async {
    sent[name] = args;
    return _auth;
  }
}

void main() {
  late _MemoryStorage storage;

  setUp(() {
    storage = _MemoryStorage();
    FlutterSecureStoragePlatform.instance = storage;
    DeviceIdentity.resetCacheForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  });

  test('64 lowercase hex chars, generated once and persisted', () async {
    final a = await DeviceIdentity.ensureSecret();
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(await DeviceIdentity.ensureSecret(), a);
    expect(storage.items['monkeyhub.device_secret'], a);
    // A relaunch (cold cache) reads the same one back rather than minting.
    DeviceIdentity.resetCacheForTest();
    expect(await DeviceIdentity.ensureSecret(), a);
    expect(await DeviceIdentity.ensure(), isNot(a));
  });

  test('every sign-in call carries it; no other call does', () async {
    final cv = _FakeCv();
    final api = ChatApi(cv);
    final secret = await DeviceIdentity.ensureSecret();
    const cred = SocialCredential(provider: SocialProvider.apple, idToken: 'x');

    await api.login(username: 'a', password: 'b');
    await api.signup(username: 'a', name: 'a', password: 'b', recoveryKeyHash: 'h');
    await api.resetPassword(username: 'a', recoveryKey: 'k', newPassword: 'p');
    await api.socialSignIn(cred);
    await api.completeSocialSignUp(credential: cred, username: 'a');
    await api.linkSocialToExistingAccount(credential: cred, username: 'a', password: 'p');
    await api.exchangeDeviceLoginRequest('r');
    await api.redeemPairingCode(code: 'c', deviceId: 'd', platform: 'ios');
    await api.logout(userId: 'u');

    const signIns = {
      'auth:login',
      'auth:signup',
      'auth:resetPasswordWithRecoveryKey',
      'socialAuth:signIn',
      'socialAuth:completeSignUp',
      'socialAuth:linkExistingAccount',
      'deviceLogin:exchangeDeviceLoginRequest',
      'family:redeemPairingCode',
    };
    for (final name in signIns) {
      expect(cv.sent[name]?['deviceSecret'], secret, reason: name);
    }
    expect(cv.sent['auth:logout']!.containsKey('deviceSecret'), isFalse);
    expect(cv.sent['auth:logout']!['deviceId'], isNotNull);
  });
}
