import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart';

/// Client-side SHA-256, matching v02's `SecurityUtils.hashPassword` /
/// CryptoKit usage. The Convex backend stores and compares these hashes
/// directly — it never sees a plaintext password, room passphrase, pairing
/// code, or recovery phrase.
///
/// Lives in its own leaf file (rather than in `chat_api.dart`, which re-exports
/// it for the twelve call sites there) so that `lib/auth/recovery_phrase.dart`
/// can hash without pulling in the Convex FFI client and dotenv. That keeps
/// `test/recovery_phrase_test.dart` a plain `test()` with no Flutter binding —
/// which matters, because that file is the tripwire protecting every account's
/// recovery phrase and it must never be the slow or flaky one.
String sha256Hash(String input) => sha256.convert(utf8.encode(input)).toString();
