import '../l10n/generated/app_localizations.dart';

/// Human copy for a refusal from one of the server's limits, or null when
/// [error] is something else.
///
/// The backend enforces its own limits (rate limits in `rateLimit.ts`, upload
/// caps and quotas in `files.ts`, room caps in `roomAdmin.ts`, message length
/// in `messages.ts`) and refuses with a stable code. A screen that would
/// otherwise say "couldn't do that" asks here first, so a person who hits a
/// limit is told which one and what to do, instead of retrying something that
/// will fail the same way. Matched by substring, like `humanizeAuthError`,
/// because Convex wraps thrown errors in a longer string.
String? serverLimitMessage(Object error, AppLocalizations l10n) {
  final s = error.toString();
  if (s.contains('STORAGE_QUOTA_EXCEEDED')) return l10n.sendLimitStorageFull;
  if (s.contains('FILE_TOO_LARGE')) return l10n.sendLimitFileTooLarge;
  if (s.contains('MESSAGE_TOO_LONG')) return l10n.sendLimitMessageTooLong;
  if (s.contains('NOT_YOUR_FILE')) return l10n.limitNotYourFile;
  if (s.contains('ROOM_FULL')) return l10n.limitRoomFull;
  if (s.contains('REMOVED_FROM_ROOM')) return l10n.limitRemovedFromRoom;
  if (s.contains('TOO_MANY_ROOMS')) return l10n.limitTooManyRooms;
  if (s.contains('ROOM_NAME_TOO_LONG') ||
      s.contains('ROOM_DESCRIPTION_TOO_LONG')) {
    return l10n.limitRoomTextTooLong;
  }
  if (s.contains('DEVICE_LOGIN_BUSY')) return l10n.limitDeviceLoginBusy;
  if (s.contains('TOO_MANY_MESSAGES')) return l10n.limitRequestMessages;
  if (s.contains('TOO_MANY_ATTEMPTS')) return l10n.authErrorTooManyAttempts;
  if (s.contains('RATE_LIMITED')) return l10n.limitTooOften;
  return null;
}

/// [serverLimitMessage], or [fallback] when the error is not a limit.
String friendlyServerError(
  Object error,
  AppLocalizations l10n,
  String fallback,
) =>
    serverLimitMessage(error, l10n) ?? fallback;
