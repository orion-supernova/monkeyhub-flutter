import 'dart:async';

import 'package:monkeyhub/push/push_manager.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

/// Applies to every test in this directory.
///
/// Avatars lease presence from a store that coalesces with a timer, and the
/// widget binding fails a test that ends with a timer pending. So by default a
/// test avatar leases nothing and shows the status its user carries; the tests
/// that are about presence install a private store (see
/// user_avatar_presence_test.dart).
///
/// Platform identity comes from `Caps`, which reads `defaultTargetPlatform`
/// (android under flutter_test), not the host OS. So mobile-only native paths
/// are live in tests; the push inbox is the one every room open awaits, and
/// with no native side its channel never answers. Tests start with an empty
/// inbox; a test about the inbox installs its own reader.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  presenceStoreForWidgets = null;
  PushManager.debugInboxReader = emptyPushInbox;
  // flutter_test reports android, where Automatic means the Material kit.
  // Widget tests are written against the glass reference kit; a kit test
  // pins its kit with UiKitScope(kit:) or picks one in the store.
  UiKits.debugAutomatic = UiKit.glass;
  await testMain();
}

Future<List<Map<String, String>>> emptyPushInbox() async => const [];
