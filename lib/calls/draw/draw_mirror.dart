import 'dart:convert' show utf8;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'draw_channel.dart';
import 'draw_model.dart';
import 'draw_wire.dart';

/// The drawing, carried past the edge of the app while this device shares
/// its screen.
///
/// The strokes the others draw land in [DrawModel] and are painted by
/// `ScreenShareOverlay`, a Flutter layer over the app. That layer is only
/// visible while the app is: the moment the presenter goes to the home
/// screen, or to the app they are showing, Flutter stops drawing and the
/// strokes — about exactly what is on screen now — go unseen by the one
/// person they were for. So while the app is out of sight the drawing is
/// handed to the platform, which can still show it:
///
///  * **Android** paints it in a click-through system overlay over whatever
///    is on the display (the "display over other apps" access, which the
///    presenter grants once — see [overlayAllowed]). The overlay maps the
///    frame onto the display exactly as the in-app layer maps it onto the
///    window, so a circle drawn around an icon is around that icon.
///  * **iOS** has no way to draw over another app. What it has is
///    Picture in Picture, which a call may start by itself as the app
///    leaves the screen: a small board showing a still of the shared screen
///    with the strokes over it, live.
///
/// The data never leaves the device: the strokes already arrive here over
/// the call's data channels, and the mirror passes the same bytes through
/// to the native side — no re-encode, nothing on the network. It sends
/// nothing at all while the app is in front, where Flutter draws.
///
/// The protocol on [_opsChannel], one binary message each:
///
///  * `0x01` reset — drop every stroke.
///  * `0x02` ops — `[u8 authorLen][author utf8][draw batch]`, a peer's ops
///    exactly as they came off the wire.
///  * `0x03` stroke — `[u8 authorLen][author utf8][i32 endedAgoMs]`
///    `[draw batch]`: one stroke already in progress at the hand-off, so a
///    line drawn a second before the presenter left is still there after.
///    `endedAgoMs` is −1 while the finger is still down.
///  * `0x04` visible — `[u8 0|1]`: whether the native side should show the
///    drawing (the app is out of sight) or hold off (Flutter has it).
class DrawMirror with WidgetsBindingObserver {
  DrawMirror({
    required this.model,
    required this.channels,
    @visibleForTesting bool? supported,
  }) : supported = supported ??
            (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  final DrawModel model;
  final DrawChannels channels;

  /// Whether this platform has a native side at all. Elsewhere every call
  /// is a no-op: desktop shares are watched on the call screen's stage.
  final bool supported;

  static const MethodChannel _control = MethodChannel('monkeyhub/draw_mirror');
  static const BasicMessageChannel<ByteData?> _opsChannel =
      BasicMessageChannel<ByteData?>('monkeyhub/draw_mirror/ops', BinaryCodec());

  static const int _msgReset = 0x01;
  static const int _msgOps = 0x02;
  static const int _msgStroke = 0x03;
  static const int _msgVisible = 0x04;

  /// Android: whether the overlay is allowed. Null until asked, and on
  /// platforms where it does not apply. Re-read every time the app comes
  /// back to the front — that is where a grant made in Settings shows up.
  final ValueNotifier<bool?> overlayAllowed = ValueNotifier<bool?>(null);

  bool _running = false;
  bool _visible = false;

  bool get running => _running;

  /// Whether the native side is the one drawing right now. For tests.
  @visibleForTesting
  bool get debugVisible => _visible;

  /// The share is on the air. [trackId] is the local screen track, which
  /// the iOS board takes its still of the screen from; [idleText] is what
  /// it says while nobody is drawing.
  Future<void> start({String? trackId, required String idleText}) async {
    if (!supported || _running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      final r = await _control.invokeMethod<bool>('arm', {
        'trackId': trackId,
        'idleText': idleText,
      });
      if (_running && !kIsWeb && Platform.isAndroid) overlayAllowed.value = r;
    } catch (e) {
      debugPrint('DrawMirror.arm: $e');
    }
    if (!_running) return;
    // A share started from the background is not a thing, but a lifecycle
    // that moved while arm was in flight is.
    _sync(WidgetsBinding.instance.lifecycleState);
  }

  /// The share is over: the native side lets go of everything.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _setVisible(false);
    overlayAllowed.value = null;
    try {
      await _control.invokeMethod<void>('disarm');
    } catch (e) {
      debugPrint('DrawMirror.disarm: $e');
    }
  }

  /// Android: takes the presenter to the system page that grants the
  /// overlay. The answer arrives as [overlayAllowed] on the way back.
  Future<void> requestOverlay() async {
    if (!supported) return;
    try {
      await _control.invokeMethod<void>('requestOverlayPermission');
    } catch (e) {
      debugPrint('DrawMirror.requestOverlay: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    _sync(state);
    if (state == AppLifecycleState.resumed && Platform.isAndroid) {
      _refreshPermission();
    }
  }

  Future<void> _refreshPermission() async {
    try {
      final r = await _control.invokeMethod<bool>('overlayPermission');
      if (_running) overlayAllowed.value = r;
    } catch (e) {
      debugPrint('DrawMirror.overlayPermission: $e');
    }
  }

  /// Out of sight is `hidden` or `paused`, not `inactive`: a pulled-down
  /// shade or a system dialog leaves the app on screen with Flutter still
  /// drawing, and two copies of every line would be one too many.
  void _sync(AppLifecycleState? state) {
    final away = state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    _setVisible(away);
  }

  void _setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      _send(Uint8List.fromList(const [_msgReset]));
      handOff();
      channels.onInbound = _forward;
      _send(Uint8List.fromList(const [_msgVisible, 1]));
    } else {
      if (channels.onInbound == _forward) channels.onInbound = null;
      _send(Uint8List.fromList(const [_msgVisible, 0]));
    }
  }

  /// Every stroke still alive, so the native side picks the drawing up
  /// where Flutter put it down.
  @visibleForTesting
  void handOff() {
    final now = model.clock();
    for (final s in model.strokes) {
      if (s.length == 0) continue;
      final ended = s.endedAt;
      final ago = ended == null ? -1 : now.difference(ended).inMilliseconds;
      final batch = encodeDrawBatch([
        StrokeBegin(
          strokeId: s.id,
          argb: s.color.toARGB32(),
          width: s.width,
          // A copy: the view is over a buffer the stroke may still grow.
          points: Float32List.fromList(s.points),
        ),
      ]);
      final author = _authorBytes(s.author);
      final b = BytesBuilder(copy: false)
        ..addByte(_msgStroke)
        ..addByte(author.length)
        ..add(author);
      final age = ByteData(4)..setInt32(0, ago, Endian.little);
      b
        ..add(age.buffer.asUint8List())
        ..add(batch);
      _send(b.takeBytes());
    }
  }

  void _forward(String peerId, Uint8List bytes) {
    final author = _authorBytes(peerId);
    final out = Uint8List(2 + author.length + bytes.length)
      ..[0] = _msgOps
      ..[1] = author.length
      ..setRange(2, 2 + author.length, author)
      ..setRange(2 + author.length, 2 + author.length + bytes.length, bytes);
    _send(out);
  }

  /// A key, not a name: only ever compared, so a clip that splits a
  /// character is harmless.
  static Uint8List _authorBytes(String author) {
    final b = utf8.encode(author);
    return b.length <= 0xFF ? b : Uint8List.sublistView(b, 0, 0xFF);
  }

  void _send(Uint8List bytes) {
    try {
      _opsChannel
          .send(ByteData.sublistView(bytes))
          .catchError((Object e) {
        debugPrint('DrawMirror.send: $e');
        return null;
      });
    } catch (e) {
      debugPrint('DrawMirror.send: $e');
    }
  }

  void dispose() {
    if (_running) {
      _running = false;
      WidgetsBinding.instance.removeObserver(this);
      if (channels.onInbound == _forward) channels.onInbound = null;
      _visible = false;
      _control.invokeMethod<void>('disarm').catchError((Object _) {});
    }
    overlayAllowed.dispose();
  }
}
