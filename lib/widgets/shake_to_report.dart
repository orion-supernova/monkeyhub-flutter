import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../diagnostics/shake_detector.dart';
import '../l10n/generated/app_localizations.dart';
import '../keyboard/focusable_tap.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/report_problem_screen.dart';
import '../theme/theme_scope.dart';

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
  const ShakeToReport({super.key, required this.auth});

  final AuthService auth;

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
    showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: ThemeScope.of(ctx).surfaceRaised,
      builder: (_) => const _ShakeSheet(),
    ).then((open) {
      _sheetOpen = false;
      if (open != true) return;
      nav.push(
        MaterialPageRoute(
          builder: (_) => ReportProblemScreen(auth: widget.auth),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportProblemShakeTitle, style: t.displaySmall),
            const SizedBox(height: 6),
            Text(l10n.reportProblemShakeBody, style: t.bodySoft),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    label: l10n.reportProblemShakeDismiss,
                    filled: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SheetButton(
                    label: l10n.reportProblemShakeOpen,
                    filled: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      radius: theme.radiusMd,
      semanticLabel: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? theme.accent : theme.surface,
            border: Border.all(color: filled ? theme.accent : theme.divider),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.body.copyWith(
              color: filled ? theme.accentInk : theme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
