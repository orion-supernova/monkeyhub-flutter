import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import 'call_service.dart';

/// Wraps the live Convex subscription to `calls:signalsForUser` and feeds
/// each unconsumed signal into [CallService.handleRemoteSignal]. Marks each
/// dispatched signal as consumed so the server query stops re-delivering it.
class SignalingSubscriber {
  SignalingSubscriber({required this.api, required this.service});

  final ChatApi api;
  final CallService service;

  Subscription? _sub;
  String? _userId;
  String? _deviceId;
  final Set<String> _dispatched = {};

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
  }

  void _onSignals(List<Map<String, dynamic>> signals) {
    final me = _userId;
    if (me == null) return;
    final myDevice = _deviceId;
    for (final sig in signals) {
      final id = sig['_id']?.toString();
      if (id == null || _dispatched.contains(id)) continue;
      // Device-targeted filter: signals carrying a targetDeviceId only
      // apply to the device whose id matches. Siblings of the same
      // userId ignore them. Used during handoff. Still consume on the
      // server so the row clears out.
      final target = sig['targetDeviceId'] as String?;
      if (target != null && myDevice != null && target != myDevice) {
        _dispatched.add(id);
        Future<void>(() async {
          try {
            await api.consumeCallSignal(signalId: id, userId: me);
          } catch (_) {}
        });
        continue;
      }
      _dispatched.add(id);
      // Fire-and-forget — dispatch into the service, then consume on the
      // server so the next subscription tick drops it.
      Future<void>(() async {
        await service.handleRemoteSignal(sig);
        try {
          await api.consumeCallSignal(signalId: id, userId: me);
        } catch (e) {
          debugPrint('consumeCallSignal($id) failed: $e');
        }
      });
    }
  }
}
