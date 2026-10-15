import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_errors.dart';
import 'package:monkeyhub/backend/convex_client.dart' show ServerRefusal;
import 'package:monkeyhub/backend/server_limits.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';

/// Every limit code the backend refuses with gets its own words, wherever the
/// error comes from: a thrown Convex error (wrapped in a longer string) or a
/// returned refusal.
void main() {
  final l10n = AppLocalizationsEn();

  test('each server limit maps to its own message', () {
    final cases = {
      'RATE_LIMITED': l10n.limitTooOften,
      'STORAGE_QUOTA_EXCEEDED': l10n.sendLimitStorageFull,
      'FILE_TOO_LARGE': l10n.sendLimitFileTooLarge,
      'MESSAGE_TOO_LONG': l10n.sendLimitMessageTooLong,
      'NOT_YOUR_FILE': l10n.limitNotYourFile,
      'ROOM_FULL': l10n.limitRoomFull,
      'REMOVED_FROM_ROOM': l10n.limitRemovedFromRoom,
      'TOO_MANY_ROOMS': l10n.limitTooManyRooms,
      'ROOM_NAME_TOO_LONG': l10n.limitRoomTextTooLong,
      'DEVICE_LOGIN_BUSY': l10n.limitDeviceLoginBusy,
      'TOO_MANY_MESSAGES': l10n.limitRequestMessages,
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      final thrown = Exception('[CONVEX M(x:y)] Uncaught Error: $key at handler');
      expect(serverLimitMessage(thrown, l10n), value, reason: key);
      expect(serverLimitMessage(ServerRefusal(key), l10n), value, reason: key);
    }
  });

  test('anything else is not a limit', () {
    expect(serverLimitMessage(Exception('NETWORK_DOWN'), l10n), isNull);
    expect(friendlyServerError(Exception('NETWORK_DOWN'), l10n, 'fallback'),
        'fallback');
  });

  test('screens using humanizeAuthError get limits too', () {
    expect(
      humanizeAuthError(Exception('Uncaught Error: ROOM_FULL'), l10n,
          fallback: 'generic'),
      l10n.limitRoomFull,
    );
  });
}
