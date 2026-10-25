import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/device_login_link.dart';
import '../backend/convex_client.dart' show Subscription;
import '../l10n/generated/app_localizations.dart';
import '../push/device_identity.dart';
import '../theme/theme_scope.dart';
import 'app_brand_mark.dart';
import 'glass_progress_dialog.dart' show ProgressRing;
import 'ios_kit.dart';
import 'labeled_field.dart' show FormErrorBanner;

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
    try {
      final deviceInfo = await DeviceIdentity.displayName();
      final req = await widget.auth.api.createDeviceLoginRequest(
        deviceInfo: deviceInfo,
      );
      if (!mounted) return;
      setState(() {
        _code = req.code;
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
        Text(
          l10n.deviceLoginScanTitleIos,
          style: theme.displayLarge.copyWith(letterSpacing: 0.37),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.deviceLoginScreenIntro,
          style: theme.bodySoft.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 28),
        _DeviceLoginBody(
          phase: _phase,
          code: _code,
          requestId: _requestId,
          expired: expired,
        ),
        const SizedBox(height: 18),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waiting is the only state with something still moving; a
              // spinner next to "denied" or "expired" would lie about that.
              if (!expired &&
                  (_phase == _Phase.minting ||
                      _phase == _Phase.waiting ||
                      _phase == _Phase.exchanging)) ...[
                const ProgressRing(size: 16, strokeWidth: 2),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  _statusLine(l10n, expired: expired),
                  textAlign: TextAlign.center,
                  style: groupedFooterStyle(theme).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: (_phase == _Phase.denied ||
                            _phase == _Phase.error ||
                            expired)
                        ? theme.danger
                        : theme.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null && _phase == _Phase.error) ...[
          const SizedBox(height: 12),
          FormErrorBanner(_error!),
        ],
        if (expired || _phase == _Phase.denied || _phase == _Phase.error) ...[
          const SizedBox(height: 20),
          SheetActionButton(
            label: AppLocalizations.of(context).destructiveSheetPairingNewCodeButton,
            onTap: _mint,
          ),
        ],
        if (widget.onCancel != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextLinkButton(
              label: l10n.loginScreenUsePasswordInstead,
              onTap: widget.onCancel,
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
    final dimmed = expired || phase == _Phase.denied || phase == _Phase.error;
    if (code == null || requestId == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    return Column(
      children: [
        _QrPanel(data: deviceLoginUri(requestId!), dimmed: dimmed),
        const SizedBox(height: 6),
        OrDivider(label: AppLocalizations.of(context).childPairScreenOrDivider),
        const SizedBox(height: 6),
        _CodeDigits(code: code!, dimmed: dimmed),
      ],
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.data, required this.dimmed});
  final String data;
  final bool dimmed;

  static const double _qr = 196;
  static const double _mark = 46;

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
            // white, a soft card whatever the theme.
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              (groupedRadius(theme) * 1.15).clamp(14.0, 30.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: data,
                version: QrVersions.auto,
                size: _qr,
                backgroundColor: Colors.white,
                // The mark covers the middle: the highest correction level
                // keeps it scanning with that much of the code hidden.
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
              Container(
                width: _mark + 12,
                height: _mark + 12,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: const CanonicalLogo(size: _mark),
                ),
              ),
            ],
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
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // Softer than a grouped row: a faint ink wash, generous radius.
                color: theme.ink.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(
                  (groupedRadius(theme) * 0.7).clamp(8.0, 18.0),
                ),
              ),
              child: Text(
                d,
                // 20: the display step of the scale (22 was off it).
                style: theme.displaySmall.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
