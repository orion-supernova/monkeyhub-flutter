import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'web_notifier.dart';

/// Whether the person is actually looking at MonkeyHub right now.
///
/// Stronger than "the app is running", and that gap is the whole point of the
/// predicate. On mobile the two nearly coincide — a backgrounded app is
/// suspended within seconds and stops receiving anything. On web and desktop
/// they come apart for hours: a background tab keeps its socket, and on macOS
/// the process is deliberately kept alive with its window hidden, because it IS
/// the delivery path (macos/Runner/MainFlutterWindow.swift). "Still connected"
/// there says nothing about whether anyone is watching.
///
/// Two things read this, and they are the two halves of the same rule:
///
///  * [MessageAlerts] — whether a new message deserves a ping.
///  * [ChatRepository] — whether the open room's read cursor may advance. A
///    room marked read by a process nobody is sitting at is a message the
///    person never saw, an app icon that never badges for it, and a SEEN
///    receipt sent to the sender on their behalf.
///
/// `resumed` and nothing else: `inactive` means visible-but-not-frontmost —
/// a window in the corner of another app's screen, which is not reading. Web
/// asks the document directly, because a browser tab can be frontmost in a
/// window that isn't.
///
/// A null lifecycle state means Flutter has not delivered its first lifecycle
/// message yet, which in practice only happens in the moments after launch —
/// when the app is, by definition, on screen. Counted as present so a cold
/// start doesn't open holding back a read it should take.
bool get viewerIsPresent {
  if (kIsWeb) return WebNotifier.isFocused;
  final state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}
