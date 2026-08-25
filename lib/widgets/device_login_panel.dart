import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/device_login_link.dart';
import '../backend/convex_client.dart' show Subscription;
import '../l10n/generated/app_localizations.dart';
import '../push/device_identity.dart';
import '../theme/theme_scope.dart';

enum _Phase { minting, waiting, exchanging, denied, error }

/// The "scan to sign in" content: hero, QR + six-digit fallback, live status,
/// and (mint/subscribe/exchange) the state machine behind it.
///
/// Deliberately Scaffold-less — this is embedded two ways: full-screen inside
/// `DeviceLoginScreen` (desktop/web windows too narrow for the side-by-side
/// layout, replacing the password form) and, wider than that, beside the
/// password form on `LoginScreen` directly. Both wrap it in their own
/// background/scroll/width chrome; this widget only owns what is common to
/// both — the request lifecycle and the panel content.
class DeviceLoginPanel extends StatefulWidget {
  const DeviceLoginPanel({super.key, required this.auth, this.onCancel});

  final AuthService auth;

  /// Back to the ordinary username/password form. Null when embedded beside
  /// that form already (wide desktop/web) — there the form itself is the way
  /// back, so a second link back to it would be redundant.
  final VoidCallback? onCancel;

  @override
  State<DeviceLoginPanel> createState() => _DeviceLoginPanelState();
}

class _DeviceLoginPanelState extends State<DeviceLoginPanel> {
  static final _random = Random.secure();

  _Phase _phase = _Phase.minting;
  String? _code;
  String? _requestId;
  DateTime? _expiresAt;
  Timer? _tick;
  Subscription? _statusSub;
  String? _error;

  /// Guards against a duplicate 'approved' delivery firing a second exchange
  /// while the first is still in flight.
  bool _exchanging = false;

  @override
  void initState() {
    super.initState();
    _mint();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final exp = _expiresAt;
    if (exp == null) return Duration.zero;
    final left = exp.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Purely local, exactly like `PairingCodeScreen._expired` — no server
  /// round trip needed to know a clock has run out, and no subscription
  /// update will arrive on wall-clock time alone (Convex queries re-run on
  /// data changes, not on the passage of time).
  bool get _locallyExpired =>
      _expiresAt != null && _phase == _Phase.waiting && _remaining == Duration.zero;

  Future<void> _mint() async {
    _statusSub?.cancel();
    _statusSub = null;
    setState(() {
      _phase = _Phase.minting;
      _error = null;
      _code = null;
      _requestId = null;
      _expiresAt = null;
      _exchanging = false;
    });
    // Six digits, uniformly distributed across 100000–999999 — same
    // distribution `PairingCodeScreen` uses.
    final code = (100000 + _random.nextInt(900000)).toString();
    try {
      final deviceInfo = await DeviceIdentity.displayName();
      final req = await widget.auth.api.createDeviceLoginRequest(
        deviceInfo: deviceInfo,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _code = code;
        _requestId = req.requestId;
        _expiresAt = req.expiresAt;
        _phase = _Phase.waiting;
      });
      _statusSub = await widget.auth.api.subscribeDeviceLoginStatus(
        requestId: req.requestId,
        onStatus: _onStatus,
        onError: (e) => debugPrint('[deviceLogin] status sub error: $e'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = _humanize(e);
      });
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    switch (status) {
      case 'pending':
        break; // steady state — nothing to do
      case 'approved':
        _exchange();
      case 'denied':
        _statusSub?.cancel();
        _statusSub = null;
        setState(() => _phase = _Phase.denied);
      case 'expired':
      case 'invalid':
      case 'consumed':
        // 'consumed' with no local exchange in flight means this request was
        // spent some other way (a stray retry, a second tab) — same dead end
        // as 'expired'/'invalid' from here.
        if (_exchanging) return;
        _statusSub?.cancel();
        _statusSub = null;
        setState(() {
          _phase = _Phase.error;
          _error = AppLocalizations.of(context).deviceLoginScreenGenericError;
        });
    }
  }

  Future<void> _exchange() async {
    if (_exchanging) return;
    _exchanging = true;
    setState(() => _phase = _Phase.exchanging);
    _statusSub?.cancel();
    _statusSub = null;
    try {
      final res = await widget.auth.api.exchangeDeviceLoginRequest(_requestId!);
      await widget.auth.completeDeviceLogin(res);
      // On success `AuthService.isSignedIn` flips and the app shell swaps
      // this screen out from above — nothing more to do here.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = _humanize(e);
      });
    }
  }

  String _humanize(Object e) => humanizeAuthError(
        e,
        AppLocalizations.of(context),
        fallback: AppLocalizations.of(context).deviceLoginScreenGenericError,
      );

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final expired = _locallyExpired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: theme.displayHero,
            children: [
              TextSpan(
                text: l10n.deviceLoginScreenHeroMuted,
                style: theme.displayHero.copyWith(color: theme.inkMuted),
              ),
              TextSpan(text: l10n.deviceLoginScreenHeroInk),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(l10n.deviceLoginScreenIntro, style: theme.bodySoft),
        const SizedBox(height: 28),
        _DeviceLoginBody(
          phase: _phase,
          code: _code,
          requestId: _requestId,
          expired: expired,
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            _statusLine(l10n, expired: expired),
            style: theme.monoTiny.copyWith(
              color: (_phase == _Phase.denied || _phase == _Phase.error || expired)
                  ? theme.danger
                  : theme.inkMuted,
            ),
          ),
        ),
        if (_error != null && _phase == _Phase.error) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: theme.danger.withValues(alpha: 0.12),
              border: Border(left: BorderSide(color: theme.danger, width: 2)),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Text(_error!, style: theme.body.copyWith(color: theme.danger)),
          ),
        ],
        if (expired || _phase == _Phase.denied || _phase == _Phase.error) ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _mint,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              child: Text(
                AppLocalizations.of(context).destructiveSheetPairingNewCodeButton,
                style: theme.label.copyWith(
                  letterSpacing: 2.4,
                  color: theme.accentInk,
                ),
              ),
            ),
          ),
        ],
        if (widget.onCancel != null) ...[
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: widget.onCancel,
              child: Text(
                l10n.loginScreenUsePasswordInstead,
                style: theme.monoTiny.copyWith(color: theme.inkMuted),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _statusLine(AppLocalizations l10n, {required bool expired}) {
    if (expired) return l10n.destructiveSheetPairingCodeExpired;
    switch (_phase) {
      case _Phase.minting:
        return l10n.deviceLoginScreenWaiting;
      case _Phase.waiting:
        return l10n.destructiveSheetPairingExpiresIn(_fmt(_remaining));
      case _Phase.exchanging:
        return l10n.deviceLoginScreenApproved;
      case _Phase.denied:
        return l10n.deviceLoginScreenDenied;
      case _Phase.error:
        return l10n.deviceLoginScreenGenericError;
    }
  }
}

/// The QR + six-digit-code panel, or a loading/placeholder state while a
/// fresh request is minting.
class _DeviceLoginBody extends StatelessWidget {
  const _DeviceLoginBody({
    required this.phase,
    required this.code,
    required this.requestId,
    required this.expired,
  });

  final _Phase phase;
  final String? code;
  final String? requestId;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final dimmed = expired || phase == _Phase.denied || phase == _Phase.error;
    if (code == null || requestId == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Column(
      children: [
        _QrPanel(data: deviceLoginUri(requestId!), dimmed: dimmed),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: theme.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                AppLocalizations.of(context).childPairScreenOrDivider,
                style: theme.monoTiny,
              ),
            ),
            Expanded(child: Container(height: 1, color: theme.divider)),
          ],
        ),
        const SizedBox(height: 20),
        _CodeDigits(code: code!, dimmed: dimmed),
      ],
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.data, required this.dimmed});
  final String data;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: AnimatedOpacity(
        duration: theme.motionFast,
        opacity: dimmed ? 0.25 : 1,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            // Needs real contrast to scan reliably — deliberately always
            // light, same as `PairingCodeScreen`'s QR panel.
            color: Colors.white,
            borderRadius: BorderRadius.circular(theme.radiusLg),
          ),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeDigits extends StatelessWidget {
  const _CodeDigits({required this.code, required this.dimmed});
  final String code;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedOpacity(
      duration: theme.motionFast,
      opacity: dimmed ? 0.3 : 1,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final d in code.split(''))
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 34,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.surfaceSunken,
                border: Border.all(color: theme.divider),
                borderRadius: BorderRadius.circular(theme.radiusMd),
              ),
              child: Text(d, style: theme.monoLarge),
            ),
        ],
      ),
    );
  }
}
