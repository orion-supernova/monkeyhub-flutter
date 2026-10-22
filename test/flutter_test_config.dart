import 'dart:async';

import 'package:monkeyhub/widgets/user_avatar.dart';

/// Applies to every test in this directory.
///
/// Avatars lease presence from a store that coalesces with a timer, and the
/// widget binding fails a test that ends with a timer pending. So by default a
/// test avatar leases nothing and shows the status its user carries; the tests
/// that are about presence install a private store (see
/// user_avatar_presence_test.dart).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  presenceStoreForWidgets = null;
  await testMain();
}
