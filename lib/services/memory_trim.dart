import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../diagnostics/diag_log.dart';
import '../ui/foundation/caps.dart';

/// Gives memory back while nobody is looking at the app.
///
/// Measured 2026-11-26: a Mac build left with its window hidden (⌘W) for
/// hours sat at a 479 MB footprint, peak 1.67 GB, ~0% CPU. About 280 MB of it
/// was GPU memory (Impeller's render-target and texture caches, IOSurfaces,
/// decoded images) that nothing ever released. On iOS and Android the OS's
/// memory warning reaches the engine, which drops those caches and runs a
/// Dart GC. Flutter's DESKTOP embedders never forward one, so a desktop
/// process that lives for days in the background kept its busiest moment's
/// caches forever.
///
/// What a trim does, cheapest first:
/// 1. clears the decoded-image cache (images still on screen stay; they are
///    held by their widgets, not by the cache) and caps it low until the app
///    is looked at again, so traffic arriving while hidden can't refill it;
/// 2. runs every registered [register] hook: in-memory caches outside the
///    image cache (map snapshots, map tiles);
/// 3. on macOS, asks the engine to purge (`monkeyhub/memory` `purgeEngine`,
///    macos/Runner/MainFlutterWindow.swift): a Dart GC plus Impeller's caches,
///    the same purge iOS gets from a memory warning.
///
/// When:
/// - desktop window hidden (closed to the Dock/tray, minimised): after
///   [_hiddenDelay], so a quick ⌘W and back stays instant;
/// - desktop window behind other apps (`inactive`): after [_inactiveDelay];
/// - phone/tablet backgrounded (`paused`): right away, because iOS suspends
///   within seconds and a smaller suspended app is the one jetsam keeps;
/// - any OS memory warning ([didHaveMemoryPressure]); the macOS runner now
///   sends one too (it listens to the kernel's memory-pressure source).
///
/// Web is left alone: Flutter web reports `hidden` for a mere window blur, and
/// the browser owns the tab's memory anyway.
class MemoryTrim with WidgetsBindingObserver {
  MemoryTrim._();
  static final MemoryTrim instance = MemoryTrim._();

  static const _channel = MethodChannel('monkeyhub/memory');

  static const _hiddenDelay = Duration(seconds: 30);
  static const _inactiveDelay = Duration(minutes: 5);

  /// The decoded-image budget while trimmed. Enough for the avatars of a few
  /// rows a message arriving in the background re-sorts into view.
  static const _trimmedImageBytes = 16 << 20;

  /// The foreground decoded-image budget. Flutter's own default (100 MB);
  /// named here so a trim has something to restore.
  static const foregroundImageBytes = 100 << 20;

  final List<VoidCallback> _hooks = [];
  Timer? _timer;
  bool _installed = false;
  bool _trimmed = false;

  /// Once, from `main`, after the binding exists.
  void install() {
    if (_installed) return;
    _installed = true;
    PaintingBinding.instance.imageCache.maximumSizeBytes = foregroundImageBytes;
    WidgetsBinding.instance.addObserver(this);
  }

  /// [clear] drops an in-memory cache. Run on every trim; must be cheap,
  /// synchronous and safe to call with work in flight (drop references,
  /// never dispose something a widget may still be painting).
  void register(VoidCallback clear) => _hooks.add(clear);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    _timer?.cancel();
    _timer = null;
    switch (state) {
      case AppLifecycleState.resumed:
        _restore();
      case AppLifecycleState.inactive:
        // On a phone `inactive` is a Control Centre swipe, not walking away.
        if (Caps.nativeDesktop) {
          _timer = Timer(_inactiveDelay, () => trim('inactive'));
        }
      case AppLifecycleState.hidden:
        if (Caps.nativeDesktop) {
          _timer = Timer(_hiddenDelay, () => trim('hidden'));
        }
      case AppLifecycleState.paused:
        if (Caps.nativeMobile) {
          trim('paused');
        } else {
          _timer = Timer(_hiddenDelay, () => trim('paused'));
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void didHaveMemoryPressure() {
    // The framework has already cleared the image cache; this adds the rest.
    // No engine purge from here: every platform that delivers this message
    // purged the engine itself just before sending it.
    trim('pressure', purgeEngine: false);
  }

  /// Drops every cache it knows about. [why] goes to the diagnostics log.
  void trim(String why, {bool purgeEngine = true}) {
    _timer?.cancel();
    _timer = null;
    final cache = PaintingBinding.instance.imageCache;
    final before = cache.currentSizeBytes;
    cache.clear();
    cache.maximumSizeBytes = _trimmedImageBytes;
    _trimmed = true;
    for (final hook in _hooks) {
      try {
        hook();
      } catch (e) {
        debugPrint('MemoryTrim hook failed: $e');
      }
    }
    if (purgeEngine && Caps.macOS) {
      unawaited(
        _channel.invokeMethod<bool>('purgeEngine').catchError((_) => false),
      );
    }
    DiagLog.lifecycle(
      'memory trim ($why): image cache ${before >> 20} MB dropped, '
      '${_hooks.length} hooks',
    );
  }

  void _restore() {
    if (!_trimmed) return;
    _trimmed = false;
    PaintingBinding.instance.imageCache.maximumSizeBytes = foregroundImageBytes;
  }
}
