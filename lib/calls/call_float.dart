import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_pip.dart';
import 'widgets/call_video_fit.dart';

/// The route a call screen (1:1 or group) is pushed in.
///
/// A full-screen dialog like any other, with two exits of its own for the
/// floating call window ([CallFloat]):
///
///  * [instant]: no slide in. The window has already grown to fill the
///    screen with the call's picture, so the screen arrives under it in
///    one frame and the window hands over.
///  * [fadeAway]: leaves with a short fade instead of the slide down,
///    under the window flying out of it into its corner.
class CallScreenRoute<T> extends MaterialPageRoute<T> {
  CallScreenRoute({
    required super.builder,
    super.settings,
    this.instant = false,
  }) : super(fullscreenDialog: true);

  final bool instant;

  bool _fading = false;

  /// The window takes the picture: go with a fade, not the slide.
  void fadeAway() {
    if (_fading) return;
    _fading = true;
    controller?.reverseDuration = const Duration(milliseconds: 220);
    changedInternalState();
  }

  @override
  Duration get transitionDuration =>
      instant ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration => super.transitionDuration;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // One shape whether fading or sliding, so the screen is never rebuilt
    // when the exit changes: the slide just holds still while the fade
    // runs.
    return FadeTransition(
      opacity: _fading ? animation : kAlwaysCompleteAnimation,
      child: super.buildTransitions(
        context,
        _fading ? kAlwaysCompleteAnimation : animation,
        secondaryAnimation,
        child,
      ),
    );
  }
}

/// The call, put away but still in view: a small live picture floating
/// over every screen of the app while the call screen is minimized, the
/// way FaceTime, Telegram and Meet keep a call on screen.
///
/// What it shows is the system Picture in Picture window's picture
/// ([CallPip.spec]): the other person, whoever presents, else the first face
/// with a camera, else a name card. With no picture to show (a voice call,
/// this device sharing its own screen, which a floating copy of the call
/// would show back to everyone) there is no window, and the in-call bar at
/// the top is the way back, as before.
///
/// Flung off the side of the screen, the window is [tucked]: the call goes
/// to the bar until its screen is next opened.
///
/// Cheap by construction. The window's one renderer exists only while the
/// window is up (or about to be) and the app is on screen; the call screen
/// frees its own as it leaves, so a minimized call decodes one picture, and
/// a hidden or tucked one none here. Leaving the app hands over to the
/// system PiP; on Android, while that is up, there is no window at all.
class CallFloat extends ChangeNotifier with WidgetsBindingObserver {
  CallFloat._();

  static final CallFloat instance = CallFloat._();

  /// Test seam: the window's renderer.
  @visibleForTesting
  static RTCVideoRenderer Function() rendererFactory = RTCVideoRenderer.new;

  /// A fresh controller, for tests that should not share [instance].
  @visibleForTesting
  factory CallFloat.forTest() => CallFloat._();

  CallPip _pip = CallPip.instance;
  ValueListenable<bool>? _screenUp;
  VoidCallback? _reopen;
  bool _attached = false;

  /// Starts following the call's picture and whether its screen is up.
  /// [reopen] asks for the call screen back (the in-call bar's "Return").
  void attach({
    required ValueListenable<bool> screenUp,
    required VoidCallback reopen,
    CallPip? pip,
  }) {
    _reopen = reopen;
    if (_attached) return;
    _attached = true;
    _pip = pip ?? CallPip.instance;
    _screenUp = screenUp;
    _pip.onRestore = restoreFromSystemPip;
    _pip.spec.addListener(_sync);
    _pip.inPip.addListener(_sync);
    screenUp.addListener(_sync);
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  bool _tucked = false;

  /// The screen is still up and the window is taking over from it.
  bool _minimizing = false;
  bool _launchReady = false;
  Rect? _launchFrom;

  /// The window has grown into the screen, which is coming up under it.
  bool _handingOff = false;
  bool _landed = false;
  bool _instantPush = false;
  int _handoff = 0;

  bool _onScreen = true;

  /// The system PiP window is growing back into the app: the call screen is
  /// on its way up instantly, and the floating window must not flash over
  /// whatever screen the app was on in the meantime.
  bool _restoring = false;

  RTCVideoRenderer? _renderer;
  bool _rendererReady = false;
  MediaStream? _bound;

  /// The window wants the floor while the call screen is away: there is a
  /// picture to float and it was not flung away. The in-call bar stands
  /// down while it is true.
  final ValueNotifier<bool> wanted = ValueNotifier<bool>(false);

  /// What the window shows; null: no window.
  CallPipSpec? get spec {
    final s = _pip.spec.value;
    if (s == null || _pip.inPip.value) return null;
    return s;
  }

  /// The window was flung off the side: the call is in the bar.
  bool get tucked => _tucked;

  /// A minimize is under way (the window is warming up over the screen).
  bool get minimizing => _minimizing;

  bool get _screenIsUp => _screenUp?.value ?? false;

  /// The window is on screen (or flying).
  bool get visible =>
      wanted.value &&
      !_restoring &&
      (_handingOff ||
          (_minimizing ? _launchReady : !_screenIsUp));

  /// The handed-over screen has its picture up: the window can go.
  bool get handoffLanded => _landed;

  /// The renderer, once it can draw; null otherwise.
  RTCVideoRenderer? get renderer => _rendererReady ? _renderer : null;

  /// A live picture is bound and has its first frame.
  bool get hasPicture {
    final r = renderer;
    if (r == null || _bound == null) return false;
    final v = r.value;
    return v.width > 0 && v.height > 0;
  }

  /// The picture's displayed size, null before its first frame.
  Size? get videoSize => hasPicture ? displayedVideoSize(_renderer!.value) : null;

  /// Where the window should fly from as it next appears (taken once).
  Rect? takeLaunchFrom() {
    final r = _launchFrom;
    _launchFrom = null;
    return r;
  }

  /// Whether the next call screen push should arrive without its slide
  /// (taken once): the window covers the screen already.
  bool takeInstantPush() {
    final v = _instantPush;
    _instantPush = false;
    return v;
  }

  /// The call screen is going away: float the call if there is a picture.
  /// Resolves true once the window has its first frame (or gave up waiting
  /// for one) and is on screen over [from]; the caller then fades the
  /// screen out from under it. False: no window, leave as before.
  Future<bool> minimize({Rect? from}) async {
    if (!wanted.value) return false;
    _minimizing = true;
    _launchReady = false;
    _launchFrom = from;
    _sync();
    final s = spec;
    if (s != null && !s.videoOff && s.trackId != null) {
      // A picture to fly: wait for it, so the window never covers the
      // screen with an empty frame. Rarely more than a few frames.
      for (var i = 0; i < 20 && !hasPicture && _minimizing; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }
    if (!_minimizing) return false;
    _launchReady = true;
    notifyListeners();
    return true;
  }

  /// The window grew to fill the screen: put the call screen back under
  /// it, then let the window go once that has its picture.
  void expand() {
    if (_handingOff) return;
    _handingOff = true;
    _landed = false;
    _instantPush = true;
    final id = ++_handoff;
    notifyListeners();
    _reopen?.call();
    final streamId = spec?.stream?.id;
    // Checked every 16 ms: up to a second in all, and with the screen up,
    // a beat (16 checks) for one with no feed of this stream to draw (a
    // grid laying out, a shared screen).
    var ticks = 0;
    var upTicks = 0;
    void check() {
      if (id != _handoff || !_handingOff) return;
      ticks++;
      if (_screenIsUp) upTicks++;
      final shown = upTicks > 0 &&
          (CallFeedAnchors.showing(streamId) || upTicks > 16);
      if (shown || ticks > 60) {
        _landed = true;
        notifyListeners();
        return;
      }
      Timer(const Duration(milliseconds: 16), check);
    }

    Timer(const Duration(milliseconds: 16), check);
  }

  /// The user tapped the system Picture in Picture window: they want the
  /// call, not wherever the app was. iOS grows the window back to fill the
  /// screen and then fades it out, so the call screen has to be up, with no
  /// slide, before that ends; otherwise the picture filled the screen, then
  /// the chat it was minimized over appeared from under it. Resolves once
  /// the screen is up and has drawn a frame (or after [timeout]), which is
  /// when the native side lets the window go.
  Future<void> restoreFromSystemPip({
    Duration timeout = const Duration(milliseconds: 600),
  }) async {
    _tucked = false;
    if (_screenIsUp) return;
    _restoring = true;
    _instantPush = true;
    notifyListeners();
    try {
      _reopen?.call();
      final up = Completer<void>();
      void check() {
        if (_screenIsUp && !up.isCompleted) up.complete();
      }

      final screenUp = _screenUp;
      screenUp?.addListener(check);
      check();
      try {
        await up.future.timeout(timeout, onTimeout: () {});
      } finally {
        screenUp?.removeListener(check);
      }
      if (_screenIsUp) {
        // The route is pushed; let its first frame reach the screen.
        await WidgetsBinding.instance.endOfFrame
            .timeout(const Duration(milliseconds: 150), onTimeout: () {});
      } else {
        // Nothing came up (no navigator yet): never leave the next push
        // instant by accident.
        _instantPush = false;
      }
    } finally {
      _restoring = false;
      _sync();
    }
  }

  /// The window has faded off the handed-over screen.
  void endHandoff() {
    _handingOff = false;
    _landed = false;
    // Never consumed when no screen came up (the call ended under it).
    _instantPush = false;
    _sync();
  }

  /// The window was flung off the side.
  void tuck() {
    _tucked = true;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Inactive is still on screen (Control Centre, a system sheet).
    final on = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (on == _onScreen) return;
    _onScreen = on;
    _sync();
  }

  void _sync() {
    final up = _screenIsUp;
    if (!up) _minimizing = false;
    // The screen is back: the next minimize floats again.
    if (up && !_minimizing && !_handingOff) _tucked = false;
    final w = spec != null && !_tucked;
    if (!w) _minimizing = false;
    if (wanted.value != w) wanted.value = w;
    _syncRenderer();
    notifyListeners();
  }

  void _syncRenderer() {
    final s = spec;
    final needed = visible || _minimizing;
    final picture = s != null && !s.videoOff && s.trackId != null
        ? s.stream
        : null;
    if (!needed || !_onScreen) {
      _release();
      return;
    }
    if (picture == null) {
      // The window stays, as a name card: keep the renderer for the
      // picture's return, just stop decoding into it.
      if (_bound != null) {
        _bound = null;
        _renderer?.srcObject = null;
      }
      return;
    }
    if (!identical(picture, _bound)) unawaited(_bind(picture));
  }

  Future<void> _bind(MediaStream stream) async {
    _bound = stream;
    var r = _renderer;
    if (r == null) {
      r = rendererFactory();
      _renderer = r;
      _rendererReady = false;
      try {
        await r.initialize();
      } catch (e) {
        debugPrint('CallFloat.initialize: $e');
        if (identical(_renderer, r)) _renderer = null;
        return;
      }
      if (!identical(_renderer, r)) {
        await r.dispose();
        return;
      }
      _rendererReady = true;
      r.addListener(notifyListeners);
    }
    if (!identical(_bound, stream)) return;
    r.srcObject = stream;
    notifyListeners();
  }

  void _release() {
    final r = _renderer;
    final ready = _rendererReady;
    _renderer = null;
    _rendererReady = false;
    _bound = null;
    // Still initializing: [_bind] finds it orphaned when that lands and
    // disposes it there; disposing it here too would do it twice.
    if (r != null && ready) {
      r.removeListener(notifyListeners);
      r.srcObject = null;
      unawaited(r.dispose());
    }
  }

  @visibleForTesting
  void debugReset() {
    if (_attached) {
      _pip.spec.removeListener(_sync);
      _pip.inPip.removeListener(_sync);
      _screenUp?.removeListener(_sync);
      WidgetsBinding.instance.removeObserver(this);
      if (_pip.onRestore == restoreFromSystemPip) _pip.onRestore = null;
    }
    _attached = false;
    _restoring = false;
    _screenUp = null;
    _reopen = null;
    _tucked = false;
    _minimizing = false;
    _launchReady = false;
    _launchFrom = null;
    _handingOff = false;
    _landed = false;
    _instantPush = false;
    _onScreen = true;
    _release();
    wanted.value = false;
  }
}
