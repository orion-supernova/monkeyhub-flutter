import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/device_login_link.dart';
import '../keyboard/dismiss_keyboard_on_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/code_field.dart';
import '../widgets/ios_kit.dart';
import '../widgets/prominent_button.dart';
import '../widgets/sheet_kit.dart' show SheetActionButton;
import '../l10n/text_case.dart';

enum _Stage { entry, confirm, done }

/// Phone-side of "scan to sign in": approves (or denies) a QR/short-code
/// sign-in request shown on a signed-out web or desktop client.
///
/// Reachable only from a signed-in, non-child profile — see
/// `profile_screen.dart`. Mirrors `ChildPairScreen`'s scan-or-type layout,
/// but adds one step that screen doesn't need: this hands out a full account
/// session, not a supervised child one, so it stops at an explicit
/// "approve this device?" confirmation naming what's asking — the phishing
/// resistance the whole feature rests on — before ever calling
/// `respondToDeviceLoginRequest`.
class DeviceLoginScanScreen extends StatefulWidget {
  const DeviceLoginScanScreen({
    super.key,
    required this.auth,
    this.initialRequestId,
  });

  final AuthService auth;

  /// A request id that arrived before this screen did — the desktop QR scanned
  /// with the phone's own Camera app, routed here by `DeepLinkService`. Skips
  /// straight to the "approve this device?" confirmation.
  ///
  /// It skips the SCANNER, never the confirmation. The confirmation naming the
  /// device that is asking is the whole phishing resistance of this feature,
  /// and an id that arrived from outside the app is precisely the one that has
  /// to keep it: anyone can put a QR in front of a camera.
  final String? initialRequestId;

  @override
  State<DeviceLoginScanScreen> createState() => _DeviceLoginScanScreenState();
}

class _DeviceLoginScanScreenState extends State<DeviceLoginScanScreen> {
  final _manual = TextEditingController();
  MobileScannerController? _scanner;

  _Stage _stage = _Stage.entry;
  bool _scanning = false;
  bool _busy = false;
  String? _error;
  String? _deviceInfo;

  /// Whichever identifier produced the pending [_deviceInfo] — exactly one
  /// is set, and it is what `respondToDeviceLoginRequest` is called with.
  String? _pendingRequestId;
  String? _pendingCode;

  /// True once approval succeeded, so the terminal screen can say so instead
  /// of "request denied".
  bool _approved = false;

  /// Guards against the scanner firing the same QR repeatedly while a peek is
  /// already in flight — mirrors `ChildPairScreen._consumed`.
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    final seeded = widget.initialRequestId;
    // After the first frame: `_peek` calls setState on failure, and the
    // confirm stage renders from state this build has not produced yet.
    if (seeded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _peek(requestId: seeded);
      });
    }
  }

  @override
  void dispose() {
    _manual.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    setState(() {
      _error = null;
      _scanning = true;
      _consumed = false;
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    });
  }

  void _stopScanning() {
    _scanner?.dispose();
    setState(() {
      _scanner = null;
      _scanning = false;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_consumed || _busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final requestId = parseDeviceLoginRequestId(raw);
      if (requestId == null) continue;
      _consumed = true;
      HapticFeedback.mediumImpact();
      _stopScanning();
      _peek(requestId: requestId);
      return;
    }
  }

  Future<void> _peek({String? requestId, String? code}) async {
    if (_busy) return;
    final userId = widget.auth.session?.userId;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final deviceInfo = await widget.auth.api.peekDeviceLoginRequest(
        callerId: userId,
        requestId: requestId,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _deviceInfo = deviceInfo;
        _pendingRequestId = requestId;
        _pendingCode = code;
        _stage = _Stage.confirm;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _humanize(e);
        _consumed = false;
      });
      _manual.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(bool approve) async {
    if (_busy) return;
    final userId = widget.auth.session?.userId;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.api.respondToDeviceLoginRequest(
        callerId: userId,
        approve: approve,
        requestId: _pendingRequestId,
        code: _pendingCode,
      );
      if (!mounted) return;
      setState(() {
        _approved = approve;
        _stage = _Stage.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _stage = _Stage.entry;
      _error = null;
      _deviceInfo = null;
      _pendingRequestId = null;
      _pendingCode = null;
      _consumed = false;
    });
    _manual.clear();
  }

  String _humanize(Object e) => humanizeAuthError(
        e,
        AppLocalizations.of(context),
        fallback: AppLocalizations.of(context).deviceLoginScanScreenGenericError,
      );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DismissKeyboardOnTap(
        child: Stack(
          children: [
            theme.backgroundLayer(context),
            // See home_screen: the bottom inset leaves a dead strip of
            // background under the scroller, which reads as a solid bar. The
            // list clears the home indicator with its own padding instead.
            SafeArea(
              bottom: false,
              child: AdaptivePageBody(
                child: Column(
                  children: [
                    _Header(onClose: () => Navigator.of(context).maybePop()),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          8,
                          28,
                          edgeToEdgeBottom(context, 32),
                        ),
                        child: switch (_stage) {
                          _Stage.entry => _EntryBody(
                              scanning: _scanning,
                              scanner: _scanner,
                              busy: _busy,
                              error: _error,
                              manual: _manual,
                              onDetect: _onDetect,
                              onStartScanning: _startScanning,
                              onStopScanning: _stopScanning,
                              onManualComplete: (code) => _peek(code: code),
                            ),
                          _Stage.confirm => _ConfirmBody(
                              deviceInfo: _deviceInfo ?? '',
                              busy: _busy,
                              error: _error,
                              onApprove: () => _respond(true),
                              onDeny: () => _respond(false),
                            ),
                          _Stage.done => _DoneBody(approved: _approved, onScanAnother: _reset),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: [
          GlassBackButton(onTap: onClose),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context).profileScreenScanToSignInLabel,
              style: theme.bodyEmph.copyWith(color: theme.ink),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryBody extends StatelessWidget {
  const _EntryBody({
    required this.scanning,
    required this.scanner,
    required this.busy,
    required this.error,
    required this.manual,
    required this.onDetect,
    required this.onStartScanning,
    required this.onStopScanning,
    required this.onManualComplete,
  });

  final bool scanning;
  final MobileScannerController? scanner;
  final bool busy;
  final String? error;
  final TextEditingController manual;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onStartScanning;
  final VoidCallback onStopScanning;
  final ValueChanged<String> onManualComplete;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.deviceLoginScanTitleIos,
          style: theme.displayLarge.copyWith(letterSpacing: 0.37),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.deviceLoginScanScreenIntro,
          style: theme.bodySoft.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 28),
        if (scanning && scanner != null)
          _ScannerPanel(controller: scanner!, onDetect: onDetect, onCancel: onStopScanning)
        else
          GestureDetector(
            onTap: busy ? null : onStartScanning,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                color: quietFill(theme),
                borderRadius: BorderRadius.circular(groupedRadius(theme)),
              ),
              child: Column(
                children: [
                  Icon(
                    CupertinoIcons.qrcode_viewfinder,
                    size: 34,
                    color: theme.accent,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    sentenceCaseOf(
                      context,
                      l10n.deviceLoginScanScreenScanButtonLabel,
                    ),
                    style: theme.bodyEmph.copyWith(color: theme.accent),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Container(height: 1, color: theme.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.childPairScreenOrDivider,
                style: theme.bodySoft.copyWith(
                  fontSize: 13,
                  color: theme.inkMuted,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: theme.divider)),
          ],
        ),
        const SizedBox(height: 22),
        CodeField(controller: manual, onCompleted: onManualComplete, enabled: !busy),
        if (busy) ...[
          const SizedBox(height: 20),
          const Center(child: CupertinoActivityIndicator()),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(error!),
        ],
      ],
    );
  }
}

class _ScannerPanel extends StatelessWidget {
  const _ScannerPanel({required this.controller, required this.onDetect, required this.onCancel});

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
          child: SizedBox(
            height: 260,
            child: MobileScanner(
              controller: controller,
              onDetect: onDetect,
              // A denied or missing camera must not dead-end this screen —
              // the typed path below still works.
              errorBuilder: (context, error) => Container(
                color: theme.surfaceSunken,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.of(context).childPairScreenNoCameraMessage,
                  style: theme.bodySoft,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onCancel,
          child: Text(
            sentenceCaseOf(
              context,
              AppLocalizations.of(context).childPairScreenStopScanning,
            ),
            style: theme.body.copyWith(fontSize: 15, color: theme.accent),
          ),
        ),
      ],
    );
  }
}

/// "Approve this device?" — the confirmation step that carries this whole
/// feature's phishing resistance. [deviceInfo] is exactly what the desktop
/// or web client reported about itself; there is no way for this screen to
/// verify it beyond displaying it, so the person reading it is the actual
/// control.
class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.deviceInfo,
    required this.busy,
    required this.error,
    required this.onApprove,
    required this.onDeny,
  });

  final String deviceInfo;
  final bool busy;
  final String? error;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          l10n.deviceLoginConfirmTitleIos,
          style: theme.displayLarge.copyWith(letterSpacing: 0.37),
        ),
        const SizedBox(height: 18),
        // The device exactly as it described itself — the one thing the
        // person has to read, so it gets a grouped row of its own.
        GroupedSection(
          margin: EdgeInsets.zero,
          children: [
            GroupedRow(
              icon: CupertinoIcons.desktopcomputer,
              tone: TileTone.blue,
              title: deviceInfo,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.deviceLoginScanScreenConfirmBody(deviceInfo),
            style: theme.bodySoft.copyWith(
              fontSize: 13,
              height: 1.35,
              color: theme.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 28),
        ProminentButton(
          label: sentenceCaseOf(context, l10n.deviceLoginScanScreenApproveButton),
          busy: busy,
          onTap: busy ? null : onApprove,
        ),
        const SizedBox(height: 10),
        SheetActionButton(
          label: l10n.deviceLoginScanScreenDenyButton,
          tonal: true,
          onTap: busy ? null : onDeny,
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(error!),
        ],
      ],
    );
  }
}

class _DoneBody extends StatelessWidget {
  const _DoneBody({required this.approved, required this.onScanAnother});
  final bool approved;
  final VoidCallback onScanAnother;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Icon(
          approved
              ? CupertinoIcons.checkmark_seal_fill
              : CupertinoIcons.xmark_circle_fill,
          size: 56,
          color: approved ? theme.success : theme.inkMuted,
        ),
        const SizedBox(height: 16),
        Text(
          approved
              ? l10n.deviceLoginScanScreenSuccess
              : l10n.deviceLoginScanScreenDeniedConfirmation,
          style: theme.bodyEmph.copyWith(fontSize: 20, color: theme.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: onScanAnother,
            child: Text(
              sentenceCaseOf(context, l10n.deviceLoginScanScreenScanButtonLabel),
              style: theme.body.copyWith(fontSize: 15, color: theme.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(groupedRadius(theme) * 0.6),
      ),
      child: Text(message, style: theme.body.copyWith(color: theme.danger)),
    );
  }
}
