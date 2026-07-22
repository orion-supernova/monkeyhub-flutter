import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';

/// URI the QR encodes. The child app also accepts the bare six digits, so a
/// parent reading them down the phone works just as well as a scan.
String pairingUri(String code) => 'monkeyhub://pair?c=$code';

/// Parent-side pairing. Mints a short-lived code, renders it as a QR *and* as
/// six readable digits, and counts down to expiry.
///
/// The code is generated here and only its hash goes to the server (see
/// `ChatApi.createPairingCode`) — the same shape as passwords, so the backend
/// never holds anything replayable.
class PairingCodeScreen extends StatefulWidget {
  const PairingCodeScreen({
    super.key,
    required this.api,
    required this.guardianId,
    required this.child,
  });

  final ChatApi api;
  final String guardianId;
  final ChatUser child;

  @override
  State<PairingCodeScreen> createState() => _PairingCodeScreenState();
}

class _PairingCodeScreenState extends State<PairingCodeScreen> {
  static final _random = Random.secure();

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
      final expiresAt = await widget.api.createPairingCode(
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
      setState(() => _error = 'Couldn\'t make a code — try again.');
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
                _Header(name: widget.child.displayName),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'On ${widget.child.displayName}\'s phone, open MonkeyHub '
                          'and scan this — or type the numbers.',
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
                          _QrPanel(data: pairingUri(code), dimmed: _expired),
                          const SizedBox(height: 24),
                          _CodeDigits(code: code, dimmed: _expired),
                          const SizedBox(height: 18),
                          Center(
                            child: Text(
                              _expired
                                  ? 'this code has expired'
                                  : 'expires in ${_fmt(_remaining)}',
                              style: theme.monoTiny.copyWith(
                                color: _expired ? theme.danger : theme.inkMuted,
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
                              color: _expired ? theme.accent : Colors.transparent,
                              border: _expired
                                  ? null
                                  : Border.all(color: theme.divider),
                              borderRadius:
                                  BorderRadius.circular(theme.radiusMd),
                            ),
                            child: Text(
                              'NEW CODE',
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
                          'One use only. Making a new code cancels the old one.',
                          style: theme.monoTiny.copyWith(color: theme.inkMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
  const _Header({required this.name});
  final String name;

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
              'PAIR ${name.toUpperCase()}',
              style: theme.label.copyWith(letterSpacing: 2.8),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
