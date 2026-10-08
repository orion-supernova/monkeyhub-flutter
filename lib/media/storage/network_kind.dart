import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'storage_kinds.dart';

/// Which network the device is on right now: the one fact every
/// auto-download rule, every data usage counter and the calls data saver
/// branch on.
///
/// Read synchronously ([current]) because the callers are a message tile
/// deciding whether to fetch and a byte counter mid-download; neither can
/// await. Starts as Wi-Fi, the permissive guess, and corrects itself within a
/// frame of [start].
///
/// Cellular wins a tie. A phone reporting both (tethering, Wi-Fi assist) is
/// one whose user can be billed for what moves, and the rules exist for them.
class NetworkKindMonitor extends ChangeNotifier {
  NetworkKindMonitor._();
  static final NetworkKindMonitor instance = NetworkKindMonitor._();

  NetKind _current = NetKind.wifi;
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  NetKind get current => _current;

  /// Whether [start] has run. Auto-download waits for it: until the network
  /// is known, nothing is fetched on a guess.
  bool get started => _sub != null;
  bool get offline => _offline;

  void start() {
    if (_sub != null || kIsWeb) return;
    try {
      final c = Connectivity();
      unawaited(c.checkConnectivity().then(_apply, onError: (_) {}));
      _sub = c.onConnectivityChanged.listen(_apply, onError: (_) {});
    } catch (e) {
      // No plugin (a widget test, an unsupported desktop): stay on Wi-Fi.
      debugPrint('NetworkKindMonitor unavailable: $e');
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final next = results.contains(ConnectivityResult.mobile)
        ? NetKind.cellular
        : NetKind.wifi;
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (next == _current && offline == _offline) return;
    _current = next;
    _offline = offline;
    notifyListeners();
  }

  @visibleForTesting
  void debugSet(NetKind kind) {
    _current = kind;
    notifyListeners();
  }
}
