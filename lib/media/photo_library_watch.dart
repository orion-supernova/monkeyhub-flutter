import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodCall;
import 'package:photo_manager/photo_manager.dart';

/// The photo library changing under an open picker: a screenshot, a photo
/// saved from another app, one deleted in Photos. None of those take the app
/// to the background, so a resume reload never hears about them.
///
/// One native observer for every picker on screen, started with the first
/// listener and stopped with the last. A burst of changes (iOS reports a
/// screenshot two or three times as it settles) reaches listeners once,
/// [_settle] after the last.
class PhotoLibraryWatch {
  PhotoLibraryWatch._();

  static final _listeners = <VoidCallback>[];
  static Timer? _debounce;
  static const _settle = Duration(milliseconds: 250);

  /// Calls [onChange] after the library changes, until the returned
  /// function is called.
  static VoidCallback listen(VoidCallback onChange) {
    _listeners.add(onChange);
    if (_listeners.length == 1) _start();
    return () {
      if (!_listeners.remove(onChange)) return;
      if (_listeners.isEmpty) _stop();
    };
  }

  static void _onNative(MethodCall _) {
    _debounce?.cancel();
    _debounce = Timer(_settle, () {
      for (final l in List.of(_listeners)) {
        l();
      }
    });
  }

  static void _start() {
    try {
      PhotoManager.addChangeCallback(_onNative);
      unawaited(
        PhotoManager.startChangeNotify().catchError((Object e) {
          debugPrint('[photo_watch] start: $e');
        }),
      );
    } catch (e) {
      // No plugin (a test): nothing will change, and nothing needs to.
      debugPrint('[photo_watch] start: $e');
    }
  }

  static void _stop() {
    _debounce?.cancel();
    _debounce = null;
    try {
      PhotoManager.removeChangeCallback(_onNative);
      unawaited(
        PhotoManager.stopChangeNotify().catchError((Object e) {
          debugPrint('[photo_watch] stop: $e');
        }),
      );
    } catch (e) {
      debugPrint('[photo_watch] stop: $e');
    }
  }
}
