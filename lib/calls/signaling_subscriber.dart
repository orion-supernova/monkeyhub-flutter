import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../backend/call_api.dart';
import '../backend/convex_client.dart';
import 'call_service.dart';

/// Wraps the live Convex subscription to `calls:signalsForUser` and feeds
/// each unconsumed signal into [CallService.handleRemoteSignal]. Marks each
/// dispatched signal as consumed so the server query stops re-delivering it.
///
/// Dispatch is strictly FIFO in server `createdAt` order: one drain loop
/// awaits each handler before the next signal runs, so a `bye` can never
/// interleave with an in-flight offer's async setup and resurrect a
/// torn-down call.
class SignalingSubscriber {
  SignalingSubscriber({required this.api, required this.service});

  final CallApi api;
  final CallService service;

  /// Oldest-first eviction cap for the dedupe set — signals are dispatched
  /// at most once per subscription lifetime, and rows GC out server-side
  /// within a minute, so 300 ids is plenty of memory.
  static const _dispatchedCap = 300;

  Subscription? _sub;
  String? _userId;
  String? _deviceId;
  final LinkedHashSet<String> _dispatched = LinkedHashSet<String>();
  final List<Map<String, dynamic>> _queue = [];
  bool _draining = false;

  Future<void> start(String userId, {String? deviceId}) async {
    if (_userId == userId && _deviceId == deviceId && _sub != null) return;
    await stop();
    _userId = userId;
    _deviceId = deviceId;
    _sub = await api.subscribeCallSignals(
      userId: userId,
      onSignals: _onSignals,
      onError: (e) => debugPrint('SignalingSubscriber error: $e'),
    );
  }

  Future<void> stop() async {
    _sub?.cancel();
    _sub = null;
    _userId = null;
    _deviceId = null;
    _dispatched.clear();
    _queue.clear();
  }

  void _markDispatched(String id) {
    _dispatched.add(id);
    while (_dispatched.length > _dispatchedCap) {
      _dispatched.remove(_dispatched.first);
    }
  }

  void _onSignals(List<Map<String, dynamic>> signals) {
    if (_userId == null) return;
    final myDevice = _deviceId;
    for (final sig in signals) {
      final id = sig['_id']?.toString();
      if (id == null || _dispatched.contains(id)) continue;
      _markDispatched(id);
      // Device-targeted filter: signals carrying a targetDeviceId only
      // apply to the device whose id matches. Siblings of the same
      // userId ignore them. Used during handoff. Still consume on the
      // server (via the drain's batch) so the row clears out.
      final target = sig['targetDeviceId'] as String?;
      final mine = target == null || myDevice == null || target == myDevice;
      _queue.add(mine ? sig : {'_id': id, '_skip': true});
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final me = _userId;
        if (me == null) return;
        final consumedIds = <String>[];
        while (_queue.isNotEmpty) {
          final sig = _queue.removeAt(0);
          final id = sig['_id']?.toString();
          if (sig['_skip'] != true) {
            try {
              await service.handleRemoteSignal(sig);
            } catch (e, st) {
              debugPrint('SignalingSubscriber dispatch failed: $e\n$st');
            }
          }
          if (id != null) consumedIds.add(id);
        }
        try {
          await api.consumeCallSignals(signalIds: consumedIds, userId: me);
        } catch (e) {
          debugPrint('consumeCallSignals(${consumedIds.length}) failed: $e');
        }
      }
    } finally {
      _draining = false;
    }
  }
}
