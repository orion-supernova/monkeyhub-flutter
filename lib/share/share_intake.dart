import 'dart:async' show unawaited;
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'shared_payload.dart';

/// This device's side of "share into MonkeyHub".
///
/// One channel, `monkeyhub/share`, installed natively on both platforms:
///
///   * **Android** — `ShareTargetActivity` receives `ACTION_SEND` /
///     `ACTION_SEND_MULTIPLE`, copies the content out of the sender's provider
///     and relaunches us.
///   * **iOS** — the Share Extension writes into the App Group container and
///     opens `monkeyhub://share`; `AppDelegate` reads the container.
///
/// The delivery contract is the one the notifications channel already uses, and
/// for the same reason: a share is very often *the launch*, so the payload
/// exists before Dart has a handler to give it to. Native queues, Dart calls
/// [start] once, and everything after that arrives live.
///
/// ### Staging
///
/// Between "the user picked a chat" and "the room is on screen and can send"
/// there is a route push, so the payload has to sit somewhere that is neither
/// widget nor navigator. [stageFor] parks it under a room id and
/// [takeStagedFor] hands it to whichever `RoomScreen` mounts for that room —
/// the same one-shot hand-off `UiSelectionStore` uses for a notification tap.
///
/// A [ChangeNotifier] rather than a plain store, and that is not decoration:
/// on desktop a share opens a room by SELECTING it, and selecting the room that
/// is already selected is a no-op — no rebuild, no new `RoomScreen`, and a
/// payload that would sit staged forever. Sharing into the chat you are looking
/// at is an entirely ordinary thing to do. So a mounted room listens as well as
/// checking on mount, and both doors go through [takeStagedFor].
/// Never disposed: it is a process-lifetime singleton, and its only listeners
/// are `RoomScreen`s that remove themselves.
class ShareIntake extends ChangeNotifier {
  ShareIntake._();
  static final ShareIntake instance = ShareIntake._();

  static const MethodChannel _channel = MethodChannel('monkeyhub/share');

  bool _started = false;

  /// Where a completed share should land. Installed by `app.dart` once the
  /// navigator exists; a payload that arrives first waits in [_pending].
  void Function(SharedPayload payload)? onShare;

  /// A share that arrived before [onShare] was installed — the cold-start case,
  /// which for this feature is the *normal* case.
  SharedPayload? _pending;

  /// Payload waiting for a specific room's screen to mount. One at a time: a
  /// second share cannot be in flight while the first is still being placed.
  String? _stagedRoomId;
  SharedPayload? _staged;

  /// Only iOS and Android have a share sheet to be in. Web's Web Share Target
  /// API needs a service-worker manifest entry rather than a channel, and
  /// desktop has no equivalent at all — [start] is a no-op there rather than a
  /// `MissingPluginException` at launch.
  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Installs the handler and drains anything native has been holding.
  ///
  /// Safe to call more than once; only the first call does anything.
  Future<void> start() async {
    if (_started || !isSupported) return;
    _started = true;
    _channel.setMethodCallHandler(_onCall);
    try {
      final raw = await _channel.invokeMethod<Object?>('takePendingShare');
      final payload = SharedPayload.fromChannel(raw);
      if (payload != null) _deliver(payload);
    } on MissingPluginException {
      // A platform build that predates the native half. Nothing to drain.
    } catch (e) {
      debugPrint('share: takePendingShare failed: $e');
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method != 'onShare') return null;
    final payload = SharedPayload.fromChannel(call.arguments);
    if (payload != null) _deliver(payload);
    return null;
  }

  void _deliver(SharedPayload payload) {
    final handler = onShare;
    if (handler == null) {
      _pending = payload;
      return;
    }
    handler(payload);
  }

  /// Puts [payload] back on the shelf.
  ///
  /// The handler decides it cannot act yet — no navigator, or nobody signed in
  /// — and hands the share back rather than dropping it. Distinct from a share
  /// that arrived with no handler at all only in who noticed; [flushPending]
  /// replays either.
  void hold(SharedPayload payload) => _pending = payload;

  /// Whether a share is waiting to be placed. Read by the sign-in path, which
  /// has no other way to tell a login that followed a share from an ordinary
  /// one.
  bool get hasPending => _pending != null;

  /// Replays a share that landed before the app was ready to place it.
  ///
  /// Called from `app.dart` when the navigator mounts AND when sign-in
  /// completes: a share tapped on a signed-out install has to survive the whole
  /// login detour, exactly like an invite link does.
  void flushPending() {
    final pending = _pending;
    if (pending == null) return;
    final handler = onShare;
    if (handler == null) return;
    _pending = null;
    handler(pending);
  }

  /// Parks [payload] for [roomId]'s screen to pick up.
  ///
  /// Notifies, so a `RoomScreen` that is ALREADY on screen for that room takes
  /// it now rather than waiting for a mount that is never going to happen.
  void stageFor(String roomId, SharedPayload payload) {
    _stagedRoomId = roomId;
    _staged = payload;
    notifyListeners();
  }

  /// Hands over (and clears) the payload staged for [roomId], if any.
  SharedPayload? takeStagedFor(String roomId) {
    if (_stagedRoomId != roomId) return null;
    final out = _staged;
    _stagedRoomId = null;
    _staged = null;
    return out;
  }

  /// Deletes the copies the platform made once they are on their way.
  ///
  /// Both platforms stage into a cache directory the OS may reclaim whenever it
  /// likes, so this is tidiness rather than correctness — but a shared 4K video
  /// is 200 MB of somebody's phone, and "the OS will get to it" is not a good
  /// enough answer for something we chose to write.
  ///
  /// Fire-and-forget on purpose: the bytes are already in the send queue by the
  /// time this runs, and a failed unlink must never surface as a failed send.
  void disposeItems(Iterable<SharedItem> items) {
    for (final item in items) {
      if (item.path.isEmpty) continue;
      unawaited(File(item.path).delete().catchError((Object e) {
        debugPrint('share: could not delete staged ${item.path}: $e');
        return File(item.path);
      }));
    }
  }

  /// Test seam. Feeds a payload as though it had come from the platform.
  @visibleForTesting
  void debugDeliver(SharedPayload payload) => _deliver(payload);

  @visibleForTesting
  void debugReset() {
    _started = false;
    _pending = null;
    _staged = null;
    _stagedRoomId = null;
    onShare = null;
  }
}
