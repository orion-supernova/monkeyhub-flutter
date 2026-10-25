import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/device_login_link.dart';
import '../keyboard/dismiss_keyboard_on_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../platform.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/code_field.dart';
import '../widgets/glass_hud.dart';
import '../widgets/glass_progress_dialog.dart' show ProgressRing;
import '../widgets/ios_kit.dart';
import '../widgets/liquid_glass.dart' show GlassTone;
import '../widgets/prominent_button.dart';
import '../widgets/scan_frame_overlay.dart';
import '../widgets/sheet_kit.dart';

/// Builds the camera layer. Injected by tests and design previews, where
/// `MobileScanner` cannot run; null uses the real scanner.
typedef ScanCameraBuilder = Widget Function(
  BuildContext context,
  void Function(BarcodeCapture capture) onDetect,
);

/// Phone-side of "link a device": approves (or denies) a QR/short-code
/// sign-in request shown on a signed-out web or desktop client.
///
/// Laid out the way Signal's "Scan QR Code" is: the camera runs full bleed
/// with a viewfinder in the middle, a glass back button and a centred title
/// float over it, and a card at the bottom says what to scan. "Enter code
/// instead" grows that card into the six-digit field (a camera-less phone,
/// desktop or web window starts there). A recognised code snaps the
/// viewfinder shut and opens the "Finish linking" sheet, where the person
/// reads what is asking and approves or denies.
///
/// Reachable only from a signed-in, non-child profile. This hands out a full
/// account session, not a supervised child one, so it always stops at the
/// explicit confirmation naming what is asking — the phishing resistance the
/// whole feature rests on — before `respondToDeviceLoginRequest`. There is
/// deliberately no biometric/PIN gate in front: the app has no re-auth
/// primitive for it to be honest about.
class DeviceLoginScanScreen extends StatefulWidget {
  const DeviceLoginScanScreen({
    super.key,
    required this.auth,
    this.initialRequestId,
    this.cameraSupported,
    this.cameraBuilder,
    this.startWithCode = false,
  });

  final AuthService auth;

  /// A request id that arrived before this screen did — the desktop QR scanned
  /// with the phone's own Camera app, routed here by `DeepLinkService`. Goes
  /// straight to the "Finish linking" sheet.
  ///
  /// It skips the SCANNER, never the confirmation. The confirmation naming the
  /// device that is asking is the whole phishing resistance of this feature,
  /// and an id that arrived from outside the app is precisely the one that has
  /// to keep it: anyone can put a QR in front of a camera.
  final String? initialRequestId;

  /// Whether to offer the camera at all. Null: everywhere but web/desktop.
  final bool? cameraSupported;

  /// Replaces the camera layer (tests, previews).
  final ScanCameraBuilder? cameraBuilder;

  /// Open with the code field already expanded (previews).
  final bool startWithCode;

  @override
  State<DeviceLoginScanScreen> createState() => _DeviceLoginScanScreenState();
}

class _DeviceLoginScanScreenState extends State<DeviceLoginScanScreen> {
  final _manual = TextEditingController();
  MobileScannerController? _scanner;

  late bool _codeMode;
  bool _cameraFailed = false;
  bool _detected = false;
  bool _busy = false;
  String? _error;

  /// Guards against the scanner firing the same QR repeatedly while a peek is
  /// already in flight — mirrors `ChildPairScreen._consumed`.
  bool _consumed = false;

  bool get _cameraOn => (widget.cameraSupported ?? !isWebOrDesktop) && !_cameraFailed;

  @override
  void initState() {
    super.initState();
    final supported = widget.cameraSupported ?? !isWebOrDesktop;
    // No camera to offer: the typed code is the whole screen.
    _codeMode = widget.startWithCode || !supported;
    if (supported && widget.cameraBuilder == null) {
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );
    }
    final seeded = widget.initialRequestId;
    // After the first frame: `_peek` presents a sheet and calls setState.
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

  void _onDetect(BarcodeCapture capture) {
    if (_consumed || _busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final requestId = parseDeviceLoginRequestId(raw);
      if (requestId == null) continue;
      _consumed = true;
      HapticFeedback.mediumImpact();
      setState(() => _detected = true);
      _peek(requestId: requestId);
      return;
    }
  }

  void _toast(String message, {ToastTone tone = ToastTone.danger}) {
    if (!mounted) return;
    showAppToast(context, message, tone: tone);
  }

  Future<void> _peek({String? requestId, String? code}) async {
    if (_busy) return;
    final userId = widget.auth.session?.userId;
    if (userId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    String? deviceInfo;
    try {
      deviceInfo = await widget.auth.api.peekDeviceLoginRequest(
        callerId: userId,
        requestId: requestId,
        code: code,
      );
    } catch (e) {
      if (!mounted) return;
      final message = _humanize(e);
      setState(() {
        _error = message;
        _consumed = false;
        _detected = false;
      });
      _manual.clear();
      _toast(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (deviceInfo == null || !mounted) return;

    // Let the viewfinder's snap read before the sheet covers it.
    final calm = MotionScope.of(context).calm;
    if (!calm && _detected) {
      await Future<void>.delayed(const Duration(milliseconds: 360));
      if (!mounted) return;
    }
    await _presentFinish(deviceInfo, requestId: requestId, code: code);
  }

  /// The "Finish linking" sheet. Resolves the whole flow: approve pops this
  /// screen and celebrates on the page underneath; deny pops it with a quiet
  /// toast; dismissing the sheet just returns to scanning.
  Future<void> _presentFinish(
    String deviceInfo, {
    String? requestId,
    String? code,
  }) async {
    final nav = Navigator.of(context);
    // Held across the awaits: the toast outlives this screen, which is popped
    // before it is shown (its overlay is the app's, not the screen's).
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    final userId = widget.auth.session?.userId;
    if (userId == null) return;

    final result = await showAdaptiveSheet<_Decision>(
      context,
      builder: (sheetContext) => FinishLinkingSheet(
        deviceInfo: deviceInfo,
        respond: (approve) async {
          try {
            await widget.auth.api.respondToDeviceLoginRequest(
              callerId: userId,
              approve: approve,
              requestId: requestId,
              code: code,
            );
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop(
                approve ? _Decision.approved : _Decision.denied,
              );
            }
            return null;
          } catch (e) {
            final message = humanizeAuthError(
              e,
              l10n,
              fallback: l10n.deviceLoginScanScreenGenericError,
            );
            if (sheetContext.mounted) {
              showAppToast(sheetContext, message, tone: ToastTone.danger);
            }
            return message;
          }
        },
      ),
    );
    if (!mounted) return;
    switch (result) {
      case _Decision.approved:
        // The check plays over the scanner, then the screen leaves and the
        // Devices page underneath says it once more, quietly.
        await showGlassHud(
          context,
          icon: CupertinoIcons.checkmark_alt,
          success: true,
          label: l10n.deviceLinkLinkedHud,
        );
        if (nav.mounted) nav.pop();
        toast.show(l10n.deviceLinkLinkedToast, tone: ToastTone.success);
      case _Decision.denied:
        nav.pop();
        toast.show(l10n.deviceLoginScanScreenDeniedConfirmation);
      case null:
        // Sheet dismissed without an answer: scan again.
        if (!mounted) return;
        setState(() {
          _consumed = false;
          _detected = false;
          _error = null;
        });
        _manual.clear();
    }
  }

  String _humanize(Object e) => humanizeAuthError(
        e,
        AppLocalizations.of(context),
        fallback: AppLocalizations.of(context).deviceLoginScanScreenGenericError,
      );

  Widget _camera(BuildContext context) {
    final theme = ThemeScope.of(context);
    final builder = widget.cameraBuilder;
    if (builder != null) return builder(context, _onDetect);
    final controller = _scanner;
    if (controller == null || !_cameraOn) return const SizedBox.shrink();
    return MobileScanner(
      controller: controller,
      onDetect: _onDetect,
      // A denied or missing camera must not dead-end this screen: fall back
      // to the typed code, with the reason said once.
      errorBuilder: (context, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_cameraFailed) {
            setState(() {
              _cameraFailed = true;
              _codeMode = true;
            });
          }
        });
        return Container(
          color: theme.surfaceSunken,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context).childPairScreenNoCameraMessage,
            style: theme.bodySoft,
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final calm = MotionScope.of(context).calm;
    final cameraOn = _cameraOn;
    // The camera is a dark stage; without one the page's own surface is.
    final stage = cameraOn ? const Color(0xFF050507) : theme.background;
    final titleInk = cameraOn ? Colors.white : theme.ink;

    return DismissKeyboardOnTap(
      child: Scaffold(
        backgroundColor: stage,
        // The card lifts above the keyboard by hand: the camera must not
        // resize and re-letterbox under it.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraOn) Positioned.fill(child: _camera(context)),
            if (cameraOn)
              // A faint scrim so the glass chrome and the card read on a
              // bright scene.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                        ],
                        stops: const [0, 0.3, 1],
                      ),
                    ),
                  ),
                ),
              ),
            if (cameraOn)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: calm ? Duration.zero : const Duration(milliseconds: 250),
                    opacity: _codeMode ? 0.0 : 1.0,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 120 + media.padding.bottom),
                      child: Center(
                        child: ScanFrameOverlay(
                          active: !_codeMode && !_busy,
                          detected: _detected,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: media.padding.top + 4,
              left: 12,
              right: 12,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GlassBackButton(
                      tone: cameraOn ? GlassTone.media : GlassTone.app,
                      closes: false,
                    ),
                  ),
                  Text(
                    l10n.deviceLinkScanTitle,
                    style: theme.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: titleInk,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: kSheetInset,
              right: kSheetInset,
              bottom: sheetBottomLift(media.padding.bottom) +
                  media.viewInsets.bottom,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _BottomCard(
                    codeMode: _codeMode,
                    canScan: cameraOn,
                    busy: _busy,
                    error: _error,
                    manual: _manual,
                    onManualComplete: (code) => _peek(code: code),
                    onToggle: () => setState(() {
                      _codeMode = !_codeMode;
                      _error = null;
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Decision { approved, denied }

/// The floating card under the camera. Its two faces swap with a crossfade
/// while [AnimatedSize] grows the card between them on a springy curve — the
/// "morph" from the scan prompt into the code field.
class _BottomCard extends StatelessWidget {
  const _BottomCard({
    required this.codeMode,
    required this.canScan,
    required this.busy,
    required this.error,
    required this.manual,
    required this.onManualComplete,
    required this.onToggle,
  });

  final bool codeMode;
  final bool canScan;
  final bool busy;
  final String? error;
  final TextEditingController manual;
  final ValueChanged<String> onManualComplete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final calm = MotionScope.of(context).calm;
    final radius = sheetRadius(theme);

    final face = codeMode
        ? Column(
            key: const ValueKey('code'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.deviceLinkEnterCodeTitle,
                textAlign: TextAlign.center,
                style: theme.body.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.deviceLinkEnterCodeBody,
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 16),
              CodeField(
                controller: manual,
                onCompleted: onManualComplete,
                enabled: !busy,
              ),
              if (busy) ...[
                const SizedBox(height: 14),
                const Center(child: ProgressRing(size: 24, strokeWidth: 2.5)),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                FormErrorBanner(error!),
              ],
              if (canScan) ...[
                const SizedBox(height: 12),
                SheetActionButton(
                  key: const ValueKey('scan-instead'),
                  label: l10n.deviceLinkScanInstead,
                  tonal: true,
                  onTap: busy ? null : onToggle,
                ),
              ],
            ],
          )
        : Column(
            key: const ValueKey('scan'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    CupertinoIcons.qrcode_viewfinder,
                    size: 30,
                    color: theme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.deviceLinkScanInstruction,
                textAlign: TextAlign.center,
                style: theme.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 18),
              SheetActionButton(
                key: const ValueKey('enter-code'),
                label: l10n.deviceLinkEnterCodeInstead,
                tonal: true,
                onTap: onToggle,
              ),
            ],
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: sheetFill(theme),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: AnimatedSize(
        duration: calm ? Duration.zero : const Duration(milliseconds: 460),
        curve: Curves.easeOutBack,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: calm ? Duration.zero : const Duration(milliseconds: 220),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.bottomCenter,
            children: [...previous, ?current],
          ),
          child: face,
        ),
      ),
    );
  }
}

/// "Finish linking": names the device that is asking, then approve (accent
/// capsule) or deny. The one thing the person has to read is the device
/// exactly as it described itself — there is no way to verify it beyond
/// displaying it, so the reader is the actual control.
class FinishLinkingSheet extends StatefulWidget {
  const FinishLinkingSheet({
    super.key,
    required this.deviceInfo,
    required this.respond,
  });

  final String deviceInfo;

  /// Sends the answer. Returns an error message to show, or null on success
  /// (the caller closes the sheet itself).
  final Future<String?> Function(bool approve) respond;

  @override
  State<FinishLinkingSheet> createState() => _FinishLinkingSheetState();
}

class _FinishLinkingSheetState extends State<FinishLinkingSheet> {
  bool? _pending;
  String? _error;

  Future<void> _go(bool approve) async {
    if (_pending != null) return;
    setState(() {
      _pending = approve;
      _error = null;
    });
    final err = await widget.respond(approve);
    if (mounted) {
      setState(() {
        _pending = null;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final busy = _pending != null;
    return PopScope(
      canPop: !busy,
      child: SheetFrame(
        title: l10n.deviceLinkFinishTitle,
        showClose: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GroupedSection(
              margin: EdgeInsets.zero,
              children: [
                GroupedRow(
                  icon: CupertinoIcons.desktopcomputer,
                  tone: TileTone.blue,
                  title: widget.deviceInfo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                l10n.deviceLoginScanScreenConfirmBody(widget.deviceInfo),
                style: groupedFooterStyle(theme),
              ),
            ),
            const SizedBox(height: 20),
            ProminentButton(
              label: l10n.deviceLoginScanScreenApproveButton,
              busy: _pending == true,
              onTap: busy ? null : () => _go(true),
            ),
            const SizedBox(height: 10),
            SheetActionButton(
              label: l10n.deviceLoginScanScreenDenyButton,
              tonal: true,
              busy: _pending == false,
              onTap: busy ? null : () => _go(false),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              FormErrorBanner(_error!),
            ],
          ],
        ),
      ),
    );
  }
}
