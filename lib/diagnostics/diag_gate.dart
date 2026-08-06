import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../push/device_identity.dart';
import 'diag_buffer.dart';
import 'diag_log.dart';

/// Decides whether this device may capture diagnostics and open the viewer.
///
/// The verdict comes from the backend (`diagnostics:isEnabled`), keyed on the
/// device id, so a device is unlocked by running one CLI command — no build, no
/// release, no asking the user to sideload anything.
///
/// **The cached verdict is applied first and the network check is an
/// afterthought**, which is the opposite of how a feature flag usually works
/// and is deliberate. The bug this exists to diagnose looks like a connectivity
/// fault; a gate that needed a live socket to open would be shut in exactly the
/// situation it was built for.
class DiagGate {
  DiagGate._();
  static final DiagGate instance = DiagGate._();

  /// How long a successful check is trusted before we bother the server again.
  /// Same skip-if-fresh shape the presence heartbeat uses server-side.
  static const Duration _refreshAfter = Duration(hours: 6);

  bool _enabled = false;
  int? _expiresAt;
  String? _label;
  int _checkedAt = 0;
  bool _hasStoredSession = false;

  /// Bumped when the verdict changes, so the settings entry point can re-render
  /// without polling.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Whether capture is currently running.
  bool get enabled => _enabled;

  /// Whether the hidden entry point should respond at all.
  ///
  /// Deliberately wider than [enabled]: once a device has captured anything, the
  /// viewer and the export stay reachable even after the allowlist entry expires.
  /// Otherwise the phone throws the evidence away at the exact moment you ask
  /// for it.
  bool get viewerReachable => _enabled || _hasStoredSession;

  String? get label => _label;
  int? get expiresAt => _expiresAt;

  Future<File?> _cacheFile() async {
    if (kIsWeb) return null;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/diagnostics');
      if (!await dir.exists()) await dir.create(recursive: true);
      return File('${dir.path}/gate.json');
    } catch (_) {
      return null;
    }
  }

  /// Reads the last known verdict and applies it. Call before `runApp` so the
  /// first frame is already capturing — a bug that fires during startup is
  /// otherwise invisible.
  Future<void> loadCached() async {
    if (kIsWeb) return;
    try {
      final session = await DiagBuffer.instance.sessionFile();
      final previous = await DiagBuffer.instance.previousFile();
      _hasStoredSession =
          (session != null && await session.exists()) ||
          (previous != null && await previous.exists());

      final f = await _cacheFile();
      if (f == null || !await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _expiresAt = j['expiresAt'] as int?;
      _label = j['label'] as String?;
      _checkedAt = j['checkedAt'] as int? ?? 0;
      final wasEnabled = j['enabled'] as bool? ?? false;
      _apply(wasEnabled && !_isExpired);
    } catch (_) {
      // A corrupt cache means "not unlocked", which is the safe reading.
    }
  }

  bool get _isExpired {
    final exp = _expiresAt;
    return exp != null && DateTime.now().millisecondsSinceEpoch > exp;
  }

  /// Re-checks with the backend, at most once per [_refreshAfter].
  ///
  /// [check] is injected rather than importing `ConvexBackend` here — it keeps
  /// this class unit-testable, and it keeps the dependency pointing the right
  /// way (app wiring knows about diagnostics; diagnostics does not know about
  /// the backend client).
  ///
  /// A failed check NEVER downgrades the cached verdict. On the target device
  /// the socket may be broken, and losing capture because the check could not
  /// complete would be precisely backwards.
  Future<void> refresh(
    Future<Map<String, dynamic>?> Function(String deviceId) check, {
    bool force = false,
  }) async {
    if (kIsWeb) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _checkedAt < _refreshAfter.inMilliseconds) {
      // Still apply expiry locally even when we skip the round trip, so an
      // expired window closes on time without needing the network.
      if (_enabled && _isExpired) _apply(false);
      return;
    }
    try {
      final deviceId = await DeviceIdentity.ensure();
      final res = await check(deviceId);
      if (res == null) return;
      _enabled = res['enabled'] as bool? ?? false;
      _expiresAt = (res['expiresAt'] as num?)?.toInt();
      _label = res['label'] as String?;
      _checkedAt = now;
      _apply(_enabled && !_isExpired);
      await _persist();
    } catch (_) {
      // Keep the cached verdict. See the doc comment.
    }
  }

  void _apply(bool value) {
    if (DiagLog.enabled == value && _enabled == value) return;
    _enabled = value;
    DiagLog.enabled = value;
    revision.value++;
  }

  Future<void> _persist() async {
    try {
      final f = await _cacheFile();
      if (f == null) return;
      await f.writeAsString(
        jsonEncode({
          'enabled': _enabled,
          'expiresAt': _expiresAt,
          'label': _label,
          'checkedAt': _checkedAt,
        }),
        flush: true,
      );
    } catch (_) {
      // Losing the cache costs one extra round trip next launch.
    }
  }

  /// Turns capture off locally and forgets the cached verdict. The backend row
  /// is the source of truth, so this is a local opt-out, not a revocation.
  Future<void> disableLocally() async {
    _apply(false);
    _checkedAt = 0;
    await _persist();
  }

  /// Test seam.
  void applyForTest({
    required bool enabled,
    int? expiresAt,
    bool hasStoredSession = false,
    int checkedAt = 0,
  }) {
    _expiresAt = expiresAt;
    _checkedAt = checkedAt;
    _hasStoredSession = hasStoredSession;
    _apply(enabled && !_isExpired);
  }
}
