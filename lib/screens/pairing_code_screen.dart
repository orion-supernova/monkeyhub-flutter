import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// URI the QR encodes. The child app also accepts the bare six digits, so a
/// parent reading them down the phone works just as well as a scan.
String pairingUri(String code) => 'monkeyhub://pair?c=$code';

/// Parent-side pairing. Mints a short-lived code, renders it as a QR *and* as
/// six readable digits, and counts down to expiry.
///
/// The code is generated here and only its hash goes to the server (see
/// `ChatApi.createPairingCode`) — the same shape as passwords, so the backend
/// never holds anything replayable.
/// Which direction this code goes: onto a device, or off one.
///
/// The mint-and-count-down UX is identical either way, so this screen carries
/// both rather than being forked. Only the mutation, the wording, and whether
/// a QR is offered differ — the release screen on the child's phone is a
/// numeric field, not a scanner.
enum CodePurpose { pair, release }

class PairingCodeScreen extends StatefulWidget {
  const PairingCodeScreen({
    super.key,
    required this.api,
    required this.guardianId,
    required this.child,
    this.purpose = CodePurpose.pair,
  });

  final ChatApi api;
  final String guardianId;
  final ChatUser child;
  final CodePurpose purpose;

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  static final _random = Random.secure();

  bool get _releasing => widget.purpose == CodePurpose.release;

  String? _code;
  DateTime? _expiresAt;
  Timer? _tick;
  bool _busy = false;
  String? _error;

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
    super.dispose();
  }

  Duration get _remaining {
    final exp = _expiresAt;
    if (exp == null) return Duration.zero;
    final left = exp.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get _expired => _expiresAt != null && _remaining == Duration.zero;

  Future<void> _mint() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Six digits, uniformly distributed across 100000–999999.
    final code = (100000 + _random.nextInt(900000)).toString();
    try {
      final mint = _releasing
          ? widget.api.createReleaseCode
          : widget.api.createPairingCode;
      final expiresAt = await mint(
        guardianId: widget.guardianId,
        childId: widget.child.id,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _code = code;
        _expiresAt = expiresAt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(
          context,
        ).destructiveSheetPairingMintError,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final code = _code;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  name: widget.child.displayName,
                  title: _releasing
                      ? AppLocalizations.of(
                          context,
                        ).destructiveSheetPairingReleaseTitle
                      : AppLocalizations.of(
                          context,
                        ).destructiveSheetPairingPairTitle,
                ),
                Expanded(
                  child: AdaptivePageBody(
                    maxWidth: ContentWidth.auth,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _releasing
                                ? AppLocalizations.of(
                                    context,
                                  ).destructiveSheetPairingReleaseInstructions(
                                    widget.child.displayName,
                                  )
                                : AppLocalizations.of(
                                    context,
                                  ).destructiveSheetPairingPairInstructions(
                                    widget.child.displayName,
                                  ),
                            style: theme.bodySoft,
                          ),
                          const SizedBox(height: 28),
                          if (code == null)
                            SizedBox(
                              height: 220,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: theme.accent,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else ...[
                            // No QR when releasing — the child's release screen
                            // is a numeric field, and a scannable release code
                            // is a code that can be grabbed off a screen.
                            if (!_releasing) ...[
                              _QrPanel(
                                data: pairingUri(code),
                                dimmed: _expired,
                              ),
                              const SizedBox(height: 24),
                            ],
                            _CodeDigits(code: code, dimmed: _expired),
                            const SizedBox(height: 18),
                            Center(
                              child: Text(
                                _expired
                                    ? AppLocalizations.of(
                                        context,
                                      ).destructiveSheetPairingCodeExpired
                                    : AppLocalizations.of(
                                        context,
                                      ).destructiveSheetPairingExpiresIn(
                                        _fmt(_remaining),
                                      ),
                                style: theme.monoTiny.copyWith(
                                  color: _expired
                                      ? theme.danger
                                      : theme.inkMuted,
                                ),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _error!,
                              style: theme.body.copyWith(color: theme.danger),
                            ),
                          ],
                          const SizedBox(height: 26),
                          GestureDetector(
                            onTap: _busy ? null : _mint,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _expired
                                    ? theme.accent
                                    : Colors.transparent,
                                border: _expired
                                    ? null
                                    : Border.all(color: theme.divider),
                                borderRadius: BorderRadius.circular(
                                  theme.radiusMd,
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                ).destructiveSheetPairingNewCodeButton,
                                style: theme.label.copyWith(
                                  letterSpacing: 2.4,
                                  color: _expired
                                      ? theme.accentInk
                                      : theme.inkSoft,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).destructiveSheetPairingOneUseNote,
                            style: theme.monoTiny.copyWith(
                              color: theme.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
            // The QR needs real contrast to scan reliably, so this panel is
            // deliberately always light — it does not follow the theme.
            color: Colors.white,
            borderRadius: BorderRadius.circular(theme.radiusLg),
          ),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
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
              width: 42,
              padding: const EdgeInsets.symmetric(vertical: 12),
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

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.title});
  final String name;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.arrow_back, size: 20, color: theme.inkSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '$title ${name.toUpperCase()}',
              style: theme.label.copyWith(letterSpacing: 2.8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
