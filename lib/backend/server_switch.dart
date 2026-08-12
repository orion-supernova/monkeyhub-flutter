import 'package:flutter/foundation.dart';

import '../diagnostics/diag_log.dart';
import 'convex_client.dart';
import 'server_endpoint.dart';
import 'server_store.dart';

/// How far a switch got, and whether the app ended up somewhere usable.
enum ServerSwitchOutcome {
  /// Connected to the requested server. The app is signed out and sitting on
  /// the login screen of the new backend.
  switched,

  /// The requested server could not be initialized, and the app was put back on
  /// the one it came from. The session is still gone — see [ServerSwitch.apply].
  rolledBack,

  /// The new server failed AND the old one refused to come back. The rarest
  /// outcome and the only genuinely bad one; the boot screen takes over.
  stranded,

  /// Asked to switch to the server already in use, or asked while a switch was
  /// already running. Nothing happened.
  unchanged,

  /// This handset may not move — see [ServerSwitch._canSwitch]. Nothing
  /// happened, and the session is untouched.
  refused,
}

/// Moves a running app from one Convex deployment to another.
///
/// ───────── why this is not just a setter ─────────
///
/// A deployment URL looks like a preference and behaves like an identity. Every
/// id the app holds — userId, roomId, messageId, storage id, the push device
/// row, the cached avatar URLs — was minted by ONE backend and means nothing to
/// any other. Writing the new URL and reconnecting would leave a signed-in
/// session whose userId does not exist on the server now being asked about it:
/// not an error state the app has, just a permanently empty, permanently
/// "loading" one.
///
/// So the switch is a sequence, and its order is the whole design:
///
///  1. **Detach against the OLD server, while it is still reachable.** Signing
///     out deletes this device's push row (so nothing addressed to the old
///     account can reach the handset again), gets the final mutations onto the
///     wire, cancels every subscription and clears the on-disk media caches.
///     Doing this after the socket moved would aim all of it at a stranger's
///     backend.
///  2. **Persist the choice**, so a crash between here and step 3 comes back on
///     the server the user asked for rather than silently on the old one.
///  3. **Rebuild the transport** ([ConvexBackend.rebind]).
///  4. **Roll back if step 3 failed**, because the alternative is an app that
///     cannot reach anything and whose only settings screen lives behind a
///     socket that will not open.
///
/// Step 1 is not undone by a rollback, and deliberately so. Sign-out is
/// destructive by design — the push row on the old server is already gone — and
/// pretending otherwise would mean holding a session open across a teardown
/// that has already happened. The user signs back in; that is the cost of a bad
/// URL, and [ServerProbe] exists to make paying it rare.
class ServerSwitch extends ChangeNotifier {
  ServerSwitch._();
  static final ServerSwitch instance = ServerSwitch._();

  /// Everything that must happen against the deployment being left, installed
  /// by `app.dart` because only it holds the session, the repository and the
  /// caches. Awaited, and bounded by [_detachBudget].
  Future<void> Function()? _detach;

  /// Called once a new transport exists, so the app can restart connection
  /// health against it. Also installed by `app.dart`.
  void Function()? _onRebound;

  /// Whether this handset is allowed to move at all.
  ///
  /// False on a supervised child device, and the reason is [_detach]: a child
  /// cannot sign themselves out — that is the whole point of a supervised
  /// device, and [AuthService.signOut] refuses. Switching anyway would leave a
  /// live child session, pinned to a family that exists on the OLD deployment,
  /// pointed at a backend that has never heard of either.
  ///
  /// The UI hides every route in for children already; this is the backstop
  /// behind the one route it cannot hide, the boot-error escape hatch.
  bool Function()? _canSwitch;

  /// Wire the app's teardown and restart into the switch. Called once, from
  /// `_MonkeyHubAppState.initState`.
  void install({
    required Future<void> Function() detach,
    required void Function() onRebound,
    required bool Function() canSwitch,
  }) {
    _detach = detach;
    _onRebound = onRebound;
    _canSwitch = canSwitch;
  }

  /// Whether a switch is possible right now. Read by the UI so it can hide the
  /// controls rather than offer a button that silently refuses.
  bool get allowed => _canSwitch?.call() ?? true;

  /// A wedged secure-storage write or a `logout` mutation against a server that
  /// has already gone away must not be able to strand the user mid-switch. Past
  /// this, the teardown is abandoned and the switch proceeds — the local half
  /// of sign-out has its own, shorter timeout inside [AuthService.signOut].
  static const _detachBudget = Duration(seconds: 12);

  bool _busy = false;

  /// Whether a switch is in flight. The server screen disables its own controls
  /// on this, and the app shows a blocking scrim — a half-applied switch is the
  /// one state with no sensible UI.
  bool get busy => _busy;

  /// What the last [apply] was doing when it was last observed, for the
  /// progress line. Null when idle.
  ServerSwitchPhase? _phase;
  ServerSwitchPhase? get phase => _phase;

  /// Point the app at [target].
  ///
  /// [target] must already be normalized (see [normalizeServerUrl]); passing
  /// raw user input would persist a URL the client cannot build a socket from.
  /// Pass null to return to the bundled default.
  Future<ServerSwitchOutcome> apply(ServerEndpoint? target) async {
    final store = ServerStore.instance;
    final previous = store.custom;
    if (target == previous) return ServerSwitchOutcome.unchanged;
    if (_busy) return ServerSwitchOutcome.unchanged;
    if (!allowed) {
      DiagLog.connection('server-switch', 'refused (supervised device)');
      return ServerSwitchOutcome.refused;
    }

    _busy = true;
    _set(ServerSwitchPhase.detaching);
    DiagLog.connection(
      'server-switch',
      'leaving ${_host(store.deploymentUrl)}',
    );
    try {
      // 1 ── unwind against the server being left.
      try {
        await _detach?.call().timeout(_detachBudget);
      } catch (e) {
        // Best-effort by design. A server that has already moved, or a device
        // that is offline, cannot be told about a sign-out — and refusing to
        // switch because of that would trap someone on a deployment that no
        // longer exists, which is one of the reasons to switch in the first
        // place.
        DiagLog.connection('server-switch', 'detach incomplete: $e');
      }

      // 2 ── persist before reconnecting.
      _set(ServerSwitchPhase.saving);
      if (target == null) {
        await store.useBundled();
      } else {
        await store.use(target);
      }

      // 3 ── new transport.
      _set(ServerSwitchPhase.connecting);
      final err = await ConvexBackend.instance.rebind();
      if (err == null) {
        _onRebound?.call();
        DiagLog.connection('server-switch', 'now on ${store.host}');
        return ServerSwitchOutcome.switched;
      }

      // 4 ── put it back.
      DiagLog.connection('server-switch', 'target failed, rolling back: $err');
      _set(ServerSwitchPhase.rollingBack);
      if (previous == null) {
        await store.useBundled();
      } else {
        await store.use(previous);
      }
      final backErr = await ConvexBackend.instance.rebind();
      if (backErr == null) {
        _onRebound?.call();
        return ServerSwitchOutcome.rolledBack;
      }
      DiagLog.connection('server-switch', 'rollback failed too: $backErr');
      return ServerSwitchOutcome.stranded;
    } finally {
      _busy = false;
      _set(null);
    }
  }

  void _set(ServerSwitchPhase? p) {
    _phase = p;
    notifyListeners();
  }

  static String _host(String url) => Uri.tryParse(url)?.host ?? '?';
}

/// The four steps of [ServerSwitch.apply], for the progress line. Named after
/// what is happening to the user's data, not after the code doing it.
enum ServerSwitchPhase { detaching, saving, connecting, rollingBack }
