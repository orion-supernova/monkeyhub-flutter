import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wraps the native side of screen-capture protection.
///
/// On Android, "active" sets WindowManager.LayoutParams.FLAG_SECURE on the
/// window — Android then blocks screenshots and screen-recording at the OS
/// level (no overlay needed; the app simply renders as black to capturers).
///
/// On iOS there's no equivalent FLAG_SECURE. We listen to UIScreen.isCaptured
/// changes and surface them as [isBeingCaptured] so a Flutter overlay can
/// hide content while a recording or AirPlay mirror is active.
///
/// Two ways protection becomes active:
///   1. **User preference** — global toggle in Settings → PRIVACY.
///   2. **Scoped overrides** — e.g. ephemeral-room screens push a scope on
///      entry and pop on exit. While ANY scope is open, protection is on
///      regardless of the user preference. Scopes guarantee that the very
///      thing ephemeral rooms exist to prevent (someone screenshotting a
///      vanishing message) can't bypass protection just because the user
///      forgot to toggle the setting.
class CaptureProtection extends ChangeNotifier {
  CaptureProtection._();
  static final CaptureProtection instance = CaptureProtection._();

  static const _methods = MethodChannel('monkeyhub/capture');
  static const _events = EventChannel('monkeyhub/capture/events');

  bool _userEnabled = false;
  int _scopeCount = 0;
  bool _isBeingCaptured = false;
  bool _appliedNative = false;
  StreamSubscription? _sub;

  bool get userEnabled => _userEnabled;

  /// True when protection is currently active for any reason.
  bool get active => _userEnabled || _scopeCount > 0;

  /// iOS only — true while a screen recording or AirPlay mirror is active.
  /// Always false on Android (FLAG_SECURE pre-empts the need for it).
  bool get isBeingCaptured => _isBeingCaptured;

  bool get _supported => Platform.isIOS || Platform.isAndroid;

  /// Subscribe to native capture events. Safe to call multiple times.
  Future<void> ensureListening() async {
    if (_sub != null || !_supported) return;
    if (!Platform.isIOS) return; // Android event stream is a stub.
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        final next = event == true;
        if (next == _isBeingCaptured) return;
        _isBeingCaptured = next;
        notifyListeners();
      },
      onError: (e) => debugPrint('capture stream error: $e'),
    );
  }

  /// User toggled the global preference. Persisted by SettingsStore; this
  /// only updates the in-memory state + native flag.
  Future<void> setUserEnabled(bool v) async {
    if (_userEnabled == v) return;
    _userEnabled = v;
    notifyListeners();
    await _reconcileNative();
  }

  /// Open a scope that forces protection ON regardless of the user
  /// preference. Returns a token-free counter — every push must be matched
  /// by a pop. Safe to nest.
  Future<void> pushScope() async {
    _scopeCount++;
    notifyListeners();
    await _reconcileNative();
  }

  Future<void> popScope() async {
    if (_scopeCount == 0) return;
    _scopeCount--;
    notifyListeners();
    await _reconcileNative();
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
