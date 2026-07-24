import 'dart:async';
import 'dart:convert';

import 'package:convex_flutter/convex_flutter.dart' as cv;

import '../env.dart';

/// Thin wrapper around [cv.ConvexClient] that decodes JSON results and
/// surfaces typed errors. v02's auth model does not use JWTs — every
/// call passes `userId` as a parameter, so we don't touch setAuth here.
///
/// Initialization is lazy and idempotent: every API call awaits
/// [_ensureInitialized], so a sign-in tap will retry init if the boot-time
/// attempt failed (e.g. transient network or FFI race).
class ConvexBackend {
  ConvexBackend._();
  static final ConvexBackend instance = ConvexBackend._();

  Future<void>? _initFuture;
  Object? _initError;

  /// Returns null on success, or the underlying init error.
  Future<Object?> initialize() async {
    try {
      await _ensureInitialized();
      return null;
    } catch (e) {
      return e;
    }
  }

  Future<void> _ensureInitialized() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    try {
      await cv.ConvexClient.initialize(
        cv.ConvexConfig(
          deploymentUrl: Env.convexUrl,
          clientId: Env.clientId,
        ),
      );
      _initError = null;
    } catch (e) {
      _initError = e;
      // Reset so the next call retries fresh instead of returning the failed
      // future indefinitely.
      _initFuture = null;
      rethrow;
    }
  }

  Object? get initError => _initError;

  cv.ConvexClient get _c => cv.ConvexClient.instance;

  Future<dynamic> query(String name, Map<String, dynamic> args) async {
    await _ensureInitialized();
    final raw = await _c.query(name, args);
    return _decode(raw);
  }

  Future<dynamic> mutation(String name, Map<String, dynamic> args) async {
    await _ensureInitialized();
    final raw = await _c.mutation(name: name, args: args);
    return _decode(raw);
  }

  Future<dynamic> action(String name, Map<String, dynamic> args) async {
    await _ensureInitialized();
    final raw = await _c.action(name: name, args: args);
    return _decode(raw);
  }

  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    await _ensureInitialized();
    // The web client silently drops subscriptions registered before the
    // WebSocket finishes connecting (native queues them and replays on
    // connect). On a restored session, attach() subscribes before the socket
    // is up, which left the room list empty until a fresh login. Wait
    // (bounded) for the connection before registering.
    await _awaitConnected();
    final handle = await _c.subscribe(
      name: name,
      args: args,
      onUpdate: (raw) {
        try {
          onData(_decode(raw));
        } catch (e) {
          onError?.call(e);
        }
      },
      onError: (msg, value) => onError?.call(ConvexError(msg, value)),
    );
    return Subscription._(handle);
  }

  /// Resolve once the socket is connected, or after [timeout] regardless — so
  /// a still-down socket never blocks a subscription forever (the caller's
  /// onError path and the client's own reconnect handle that case). No-op when
  /// already connected, which is the steady state after the first connect.
  ///
  /// Polls [isConnected] rather than listening to [connectionState] so that the
  /// concurrent attach() calls on boot (each subscribing several queries) can't
  /// collide on a single-subscription stream.
  Future<void> _awaitConnected({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    const step = Duration(milliseconds: 100);
    var waited = Duration.zero;
    while (!isConnected && waited < timeout) {
      await Future.delayed(step);
      waited += step;
    }
  }

  Stream<bool> get connectionState =>
      _c.connectionState.map((s) => s == cv.WebSocketConnectionState.connected);

  bool get isConnected {
    try {
      return _c.isConnected;
    } catch (_) {
      return false;
    }
  }

  dynamic _decode(String raw) {
    if (raw.isEmpty || raw == 'null') return null;
    return jsonDecode(raw);
  }
}

class Subscription {
  Subscription._(this._handle);
  final cv.SubscriptionHandle _handle;
  void cancel() => _handle.cancel();
}

class ConvexError implements Exception {
  ConvexError(this.message, [this.value]);
  final String message;
  final String? value;
  @override
  String toString() => 'ConvexError($message${value == null ? '' : ': $value'})';
}
