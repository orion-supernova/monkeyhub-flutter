import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../diagnostics/shake_detector.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/report_problem_screen.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'sheet_kit.dart' show SheetActionButton, SheetFrame, SheetRise;

/// Mounts the shake listener and shows the confirm sheet.
///
/// Renders nothing — it lives in the app-wide overlay stack purely so the
/// listener's lifetime matches the app's.
///
/// A shake NEVER opens the report form directly. It offers. The users here are
/// children, phones get waved about, and being dumped into a form you did not
/// ask for is worse than not having the shortcut at all. [ShakeDetector] already
/// requires three separate spikes inside 1.2 s; this sheet is the second gate.
class ShakeToReport extends StatefulWidget {
  const ShakeToReport({super.key, required this.auth, required this.api});

  final AuthService auth;

  /// Threaded through purely to hand to [ReportProblemScreen], which needs it to
  /// upload and post the report. This widget makes no calls of its own.
  final ChatApi api;

  @override
  State<ShakeToReport> createState() => _ShakeToReportState();
}

class _ShakeToReportState extends State<ShakeToReport> {
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: start() probes the platform channel before subscribing,
    // so it is async, and nothing here needs to wait for the answer.
    unawaited(ShakeDetector.instance.start(_onShake));
  }

  @override
  void dispose() {
    ShakeDetector.instance.stop();
    super.dispose();
  }

  void _onShake() {
    // One sheet at a time, and never on top of whatever full-screen thing is
    // already up — a shake during an incoming call must not put a bug-report
    // prompt over the answer button.
    if (_sheetOpen) return;
    final nav = rootNavigatorKey.currentState;
    final ctx = rootNavigatorKey.currentContext;
    if (nav == null || ctx == null) return;

    _sheetOpen = true;
    showAdaptiveSheet<bool>(
      ctx,
      builder: (_) => const _ShakeSheet(),
    ).then((open) {
      _sheetOpen = false;
      if (open != true) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) =>
              ReportProblemScreen(auth: widget.auth, api: widget.api),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _ShakeSheet extends StatelessWidget {
  const _ShakeSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = ThemeScope.of(context);
    return SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          Center(
            child: SheetRise(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.ink.withValues(alpha: 0.08),
                ),
                child: Icon(CupertinoIcons.ant_fill, size: 26, color: t.ink),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.reportProblemShakeTitle,
            textAlign: TextAlign.center,
            style: t.bodyEmph.copyWith(fontSize: 20, color: t.ink),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.reportProblemShakeBody,
            textAlign: TextAlign.center,
            style: t.bodySoft.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: 20),
          SheetActionButton(
            label: l10n.reportProblemShakeOpen,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          SheetActionButton(
            label: l10n.reportProblemShakeDismiss,
            tonal: true,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
