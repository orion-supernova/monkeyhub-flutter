import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'diag_buffer.dart';
import 'diag_event.dart';
import 'diag_gate.dart';
import 'diag_log.dart';
import 'frame_watch.dart';

/// Installs every global capture hook. Called once, early in `main()`.
///
/// Everything here is installed unconditionally but captures nothing until
/// [DiagLog.enabled] flips, so install order does not have to race the gate.
class DiagBoot {
  const DiagBoot._();

  static bool _installed = false;

  static Future<void> install() async {
    if (_installed) return;
    _installed = true;

    // 1. Take a reference to the real debugPrint BEFORE replacing it. Every
    //    internal failure message goes here. Routing them through the override
    //    instead would mean a failing capture reports through capture, fails
    //    again, reports again — a loop, in the middle of whatever else is
    //    already going wrong.
    final original = debugPrint;
    DiagLog.rawPrint = original;
    DiagBuffer.instance.onInternalError = (m) => original('[diag] $m');

    // 2. Override the global. This picks up all ~192 existing debugPrint call
    //    sites across ~41 files — ConvexBackend.reconnect, ConnectionHealth,
    //    _asyncSessionAttach and the rest — without editing any of them, and
    //    those lines already carry exactly the context a triager wants.
    //    Forward first so console output in development is unchanged.
    debugPrint = (String? message, {int? wrapWidth}) {
      original(message, wrapWidth: wrapWidth);
      if (message != null) DiagLog.captureLine(message);
    };

    // 3. Framework errors. CHAINED, not replaced — dropping the default
    //    handler would silence the red screen and the console dump, making
    //    development worse in exchange for a log nobody is reading yet.
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      DiagLog.error(
        'flutter',
        details.exception,
        stack: details.stack,
        name: details.library,
      );
      priorOnError?.call(details);
    };

    // 4. Unhandled async errors that never reach a Flutter widget.
    //    Returning false keeps the platform's own reporting intact.
    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      DiagLog.error('uncaught', error, stack: stack);
      return false;
    };

    FrameWatch.instance.install();

    // 5. Last run's file becomes `previous`, so a crash leaves its evidence
    //    exactly one file away, then apply the cached verdict. Cached first and
    //    network later is the whole design: the device this runs on may have no
    //    working socket, and that is precisely when the log matters.
    await DiagBuffer.instance.rollSessions();
    await DiagGate.instance.loadCached();

    if (DiagLog.enabled) {
      DiagLog.add(
        cat: DiagCat.device,
        sev: DiagSev.info,
        event: 'boot',
        detail: 'diagnostics active',
      );
    }
  }
}
