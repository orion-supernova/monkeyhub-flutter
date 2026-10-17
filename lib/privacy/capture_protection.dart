import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

/// Wraps the native side of screen-capture protection.
///
/// On Android, "active" sets WindowManager.LayoutParams.FLAG_SECURE on the
/// window — Android then blocks screenshots and screen-recording at the OS
/// level (no overlay needed; the app simply renders as black to capturers).
///
/// On iOS there's no FLAG_SECURE: the window is drawn inside a secure text
/// field's canvas, which the system leaves out of screenshots, recordings
/// and mirroring (CaptureGuard, ios/Runner/SceneDelegate.swift). We also
/// listen to UIScreen.isCaptured and surface it as [isBeingCaptured], so a
/// Flutter overlay still hides content during a recording if that guard
/// could not install.
///
/// macOS sets `NSWindow.sharingType = .none`; Windows sets
/// `WDA_EXCLUDEFROMCAPTURE` display affinity.
///
/// There is no preference. Protection is on exactly while a **scope** is
/// open: an ephemeral room, a view-once photo, a playing voice or video note
/// pushes one on entry and pops it on exit. Outside those, screenshots work
/// normally; inside them there is nothing to switch off, because blocking the
/// capture is the whole point of a vanishing message.
class CaptureProtection extends ChangeNotifier {
  CaptureProtection._();
  static final CaptureProtection instance = CaptureProtection._();

  static const _methods = MethodChannel('monkeyhub/capture');
  static const _events = EventChannel('monkeyhub/capture/events');

  int _scopeCount = 0;
  bool _isBeingCaptured = false;
  bool _appliedNative = false;
  StreamSubscription? _sub;

  /// Protection is lifted while this device is SHARING its screen — the
  /// flag blanks our own outgoing capture as thoroughly as anyone else's.
  /// Broadcasting the screen is the user's deliberate act, so for the
  /// share's duration the window is unprotected, and the instant the share
  /// ends it is protected again exactly as before. The preference and the
  /// scopes are untouched underneath; only the resolution changes.
  bool _suspended = false;
  bool get suspended => _suspended;

  /// True when protection is currently active for any reason.
  bool get active => _scopeCount > 0 && !_suspended;

  /// Whether a scope — an ephemeral room on screen — is what makes
  /// protection active right now. The share flow warns about this one.
  bool get scopeActive => _scopeCount > 0;

  void suspend() {
    if (_suspended) return;
    _suspended = true;
    _notifyDeferred();
    unawaited(_reconcileNative());
  }

  void resume() {
    if (!_suspended) return;
    _suspended = false;
    _notifyDeferred();
    unawaited(_reconcileNative());
  }

  /// iOS only — true while a screen recording or AirPlay mirror is active.
  /// Always false on Android (FLAG_SECURE pre-empts the need for it).
  bool get isBeingCaptured => _isBeingCaptured;

  // kIsWeb is const, so on web the `&&` short-circuits before Platform.*
  // (dart:io) — which throws on web. Neutralizes the whole capture path
  // (ensureListening / push/popScope all gate on _supported).
  bool get _supported => platformProtects;

  /// Whether this platform can block screen capture at all.
  ///
  /// Linux has no mechanism (any X11 client can read the screen, and
  /// Wayland's capture portal has no exclusion hint), and a browser cannot
  /// stop a screenshot. Both say so instead of pretending; see CaptureNotice.
  static bool get platformProtects =>
      debugPlatformProtectsOverride ??
      (!kIsWeb &&
          (Platform.isIOS || Platform.isAndroid || Platform.isMacOS || Platform.isWindows));

  /// Tests run on a desktop host; this lets one stand in for the browser.
  @visibleForTesting
  static bool? debugPlatformProtectsOverride;

  /// Subscribe to native capture events. Safe to call multiple times.
  Future<void> ensureListening() async {
    if (_sub != null || !_supported) return;
    if (!Platform.isIOS) return; // Android event stream is a stub.
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        final next = event == true;
        if (next == _isBeingCaptured) return;
        _isBeingCaptured = next;
        _notifyDeferred();
      },
      onError: (e) => debugPrint('capture stream error: $e'),
    );
  }

  /// Open a scope that turns protection ON. A token-free counter — every
  /// push must be matched by a pop. Safe to nest.
  Future<void> pushScope() async {
    _scopeCount++;
    _notifyDeferred();
    await _reconcileNative();
  }

  Future<void> popScope() async {
    if (_scopeCount == 0) return;
    _scopeCount--;
    _notifyDeferred();
    await _reconcileNative();
  }

  /// Schedule a listener notification for after the current build/dispose
  /// phase. Callers can fire push/pop from initState, dispose, or other
  /// locked contexts without tripping the "tree locked" assertion that
  /// AnimatedBuilder listeners (see CaptureShield) would otherwise raise.
  void _notifyDeferred() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    }
  }

  Future<void> _reconcileNative() async {
    if (!_supported) return;
    final want = active;
    if (want == _appliedNative) return;
    _appliedNative = want;
    try {
      await _methods.invokeMethod('setEnabled', {'enabled': want});
    } catch (e) {
      // Best effort; revert in-memory marker so a future retry works.
      _appliedNative = !want;
      debugPrint('capture setEnabled failed: $e');
    }
  }
}
