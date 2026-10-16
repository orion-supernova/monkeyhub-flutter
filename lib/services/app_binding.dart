import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The app's binding: Flutter's own, plus one thing it lacks — haptics on a
/// Mac.
///
/// [HapticFeedback] is a no-op on macOS: the engine's `flutter/platform`
/// handler there knows the clipboard and system sounds and answers
/// `HapticFeedback.vibrate` with "not implemented". Yet a Force Touch trackpad
/// is a perfectly good haptic engine, and the moments that click on an iPhone
/// (the card deck snapping to the next photo, a reply swipe crossing its
/// threshold, a picker detent) are exactly the ones `NSHapticFeedbackManager`
/// exists for.
///
/// Rather than route the app's several hundred `HapticFeedback.*` calls
/// through a wrapper — and make every future call site remember to use it —
/// this sits one level lower: the binary messenger. On macOS it spots the
/// `HapticFeedback.vibrate` message on its way to the engine and hands it to
/// the Runner (`monkeyhub/haptics`, MainFlutterWindow.swift) instead. Every
/// existing and future call just works. Everything that is not a haptic
/// passes straight through to Flutter's own messenger, on every platform.
///
/// The trackpad only plays a haptic while a finger is on it, which is the
/// right behaviour for free: a mouse user, or a change that arrives while
/// nobody is touching anything, feels nothing.
///
/// The same seam also **collapses doubles**, on every native platform. Shared
/// primitives (a toggle row, a filter chip) click on their own, and plenty of
/// call sites were written to click in their handlers too; two taps a
/// millisecond apart feel like a rattle, not a click. Any haptic arriving
/// within [_doubleWindow] of the previous one is dropped, so the first (the
/// primitive's, which runs before the handler) wins. The window is far below
/// the spacing of a deliberate run ([HapticRamp]'s closest taps are ~40ms
/// apart), so only same-event duplicates are ever caught.
class AppBinding extends WidgetsFlutterBinding {
  AppBinding._();

  static WidgetsBinding ensureInitialized() {
    // An on-device integration test installs its own binding before the
    // app's `main` runs; there is only ever one, so take that one. In the
    // app nothing has made one yet and this is always ours.
    if (_instance == null && !_bindingExists()) AppBinding._();
    return WidgetsBinding.instance;
  }

  static bool _bindingExists() {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static AppBinding? _instance;

  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
  }

  @override
  BinaryMessenger createBinaryMessenger() {
    final inner = super.createBinaryMessenger();
    if (kIsWeb) return inner;
    return HapticMessenger(
      inner,
      mac: defaultTargetPlatform == TargetPlatform.macOS,
    );
  }
}

/// Two haptics closer together than this are one event played twice.
const _doubleWindow = Duration(milliseconds: 20);

/// The messenger [AppBinding] installs. Public only so a test can drive it.
@visibleForTesting
class HapticMessenger implements BinaryMessenger {
  HapticMessenger(this._inner, {required this.mac});

  final BinaryMessenger _inner;

  /// True on macOS, where the haptic goes to the Runner instead of the
  /// engine (which would ignore it).
  final bool mac;

  final Stopwatch _sinceLast = Stopwatch();

  static const _platform = 'flutter/platform';
  static const _codec = JSONMethodCodec();
  static const _haptics = MethodChannel('monkeyhub/haptics');

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (channel == _platform && message != null) {
      final MethodCall call;
      try {
        call = _codec.decodeMethodCall(message);
      } catch (_) {
        return _inner.send(channel, message);
      }
      if (call.method == 'HapticFeedback.vibrate') {
        final repeat =
            _sinceLast.isRunning && _sinceLast.elapsed < _doubleWindow;
        _sinceLast
          ..reset()
          ..start();
        if (repeat) return Future.value(_codec.encodeSuccessEnvelope(null));
        if (!mac) return _inner.send(channel, message);
        // Fire and forget, like the engine would: nothing ever awaits a
        // haptic for its result, and an older Runner without the channel
        // must stay as silent as Flutter's own no-op.
        _haptics
            .invokeMethod<void>('perform', call.arguments)
            .catchError((Object _) {});
        return Future.value(_codec.encodeSuccessEnvelope(null));
      }
    }
    return _inner.send(channel, message);
  }

  @override
  // ignore: deprecated_member_use
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) =>
      // ignore: deprecated_member_use
      _inner.handlePlatformMessage(channel, data, callback);

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      _inner.setMessageHandler(channel, handler);
}
