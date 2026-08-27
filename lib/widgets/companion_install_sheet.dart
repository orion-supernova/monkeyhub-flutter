/// The moment somebody meets a companion.
///
/// ── What this sheet is actually for ────────────────────────────────────────
///
/// It is asking for several hundred megabytes. That is a large ask inside a
/// chat app, and the only thing that makes it a reasonable one is the reason —
/// so the reason is the content of the sheet, not a footnote under a button.
/// Three lines, each of which is a fact rather than a claim: it runs here, it
/// sends nothing, it works with no signal.
///
/// What is deliberately NOT here: the model's name, its parameter count, its
/// quantisation, the word "LLM", and any mention of LiteRT. A person deciding
/// whether to let Sebastian translate their messages does not benefit from any
/// of it, and every one of those words moves the sheet from "meet someone" to
/// "configure something". The one place the technical name does appear is
/// Marlowe's shelf, in small type, for the reader who goes looking.
///
/// ── Sheet, panel, screen ───────────────────────────────────────────────────
///
/// [CompanionInstallPanel] is the part that installs. [showCompanionInstallSheet]
/// is that panel plus an introduction — the right shape when the user tapped
/// TRANSLATE on a bubble and has never heard of Sebastian. The companion's own
/// settings screen embeds the panel BARE, because that screen has already shown
/// the portrait, the name and the blurb; opening the sheet on top of it showed
/// every one of them a second time.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../companions/brain_manager.dart';
import '../companions/brain_spec.dart';
import '../companions/companion.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';

/// Offers to install [companion]'s brain, and stays open until it is done.
///
/// Returns true when the brain is ready by the time the sheet closes —
/// including when it was already installed and the sheet never really had a
/// job. Callers use that to decide whether to carry straight on with what the
/// user originally tapped, which is the whole reason this returns anything: a
/// person who tapped Translate, waited out a download, and then had to tap
/// Translate again would rightly wonder what the wait was for.
Future<bool> showCompanionInstallSheet(
  BuildContext context, {
  required Companion companion,
  required BrainSpec brain,
}) async {
  final result = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _CompanionInstallSheet(companion: companion, brain: brain),
  );
  final installed = result ?? BrainManager.instance.isInstalled(brain);

  // Dismissing the sheet does not stop the download — `BrainManager` owns it
  // and this sheet only ever watched. But a panel vanishing the instant you
  // swipe it away looks precisely like a cancel, and the user is left unsure
  // whether several hundred megabytes are still moving.
  //
  // So the one moment the question actually gets asked is the moment it gets
  // answered, and the answer names where to go and look.
  if (!installed &&
      BrainManager.instance.stateOf(brain).isBusy &&
      context.mounted) {
    showAppToast(
      context,
      AppLocalizations.of(context)
          .companionInstallContinuesInBackground(companion.displayName),
    );
  }
  return installed;
}

class _CompanionInstallSheet extends StatelessWidget {
  const _CompanionInstallSheet({required this.companion, required this.brain});

  final Companion companion;
  final BrainSpec brain;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      decoration: theme.sheetDecoration(),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            CompanionInstallPanel(
              companion: companion,
              brain: brain,
              // The introduction, which is the entire reason this is a sheet
              // and not just the panel. Off on the settings screen, which has
              // already made it.
              showIdentity: true,
              // Closing the sheet once the brain has landed, after a beat long
              // enough for the ring to be seen completing. A several-minute
              // download that ends in a flicker reads as a failure.
              onInstalled: () => Navigator.of(context).maybePop(true),
            ),
          ],
        ),
      ),
    );
  }
}

/// The part that installs: hero ring, the three assurances, and whatever
/// action the current state affords.
///
/// Stateful only to hold its [BrainManager] subscription — every byte of state
/// it renders belongs to the manager, which is what lets the sheet and the
/// settings screen show the same download at the same time without either
/// owning it.
class CompanionInstallPanel extends StatefulWidget {
  const CompanionInstallPanel({
    super.key,
    required this.companion,
    required this.brain,
    this.showIdentity = false,
    this.onInstalled,
  });

  final Companion companion;
  final BrainSpec brain;

  /// Draws the mark, the name and the blurb above the action. True in the
  /// sheet, where the user may be meeting this companion for the first time;
  /// false on the companion's own screen, which has said all of it already.
  final bool showIdentity;

  /// Fired once the brain is installed. The sheet closes itself with it; the
  /// settings screen passes null, because it has somewhere to stay.
  final VoidCallback? onInstalled;

  @override
  State<CompanionInstallPanel> createState() => _CompanionInstallPanelState();
}

class _CompanionInstallPanelState extends State<CompanionInstallPanel> {
  BrainManager get _manager => BrainManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManager);
    // The panel can be opened onto a brain whose real state nobody has checked
    // yet. Refresh rather than assume absent, or a user who already has it is
    // offered a download they have made.
    _manager.refresh();
  }

  @override
  void dispose() {
    _manager.removeListener(_onManager);
    super.dispose();
  }

  void _onManager() {
    if (!mounted) return;
    setState(() {});
    final done = widget.onInstalled;
    if (done != null && _manager.isInstalled(widget.brain)) {
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) done();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final state = _manager.stateOf(widget.brain);
    final installed = state.status == BrainStatus.installed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showIdentity) ...[
          Center(
            child: _Hero(
              companion: widget.companion,
              theme: theme,
              motion: motion,
              progress: state.isBusy ? state.fraction : (installed ? 1 : null),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child:
                Text(widget.companion.displayName, style: theme.displayMedium),
          ),
          const SizedBox(height: 8),
          Text(
            widget.companion.blurb(l10n),
            textAlign: TextAlign.center,
            style: theme.body.copyWith(color: theme.inkSoft),
          ),
          const SizedBox(height: 22),
        ] else if (state.isBusy || state.status == BrainStatus.paused) ...[
          // No hero on the settings screen, so the ring has nowhere to live —
          // a bar carries the same information in a fraction of the height,
          // and the screen already shows who this is.
          _ProgressBar(theme: theme, fraction: state.fraction, motion: motion),
          const SizedBox(height: 14),
        ],
        // Present in every state including mid-download, because the download
        // is exactly when somebody wonders what they agreed to.
        _Assurance(
          theme: theme,
          icon: Icons.phone_iphone,
          label: l10n.companionAssuranceOnDevice,
        ),
        _Assurance(
          theme: theme,
          icon: Icons.lock_outline,
          label: l10n.companionAssurancePrivate,
        ),
        _Assurance(
          theme: theme,
          icon: Icons.wifi_off,
          label: l10n.companionAssuranceOffline,
        ),
        const SizedBox(height: 22),
        _action(context, theme, l10n, state),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    AppTheme theme,
    AppLocalizations l10n,
    BrainState state,
  ) {
    switch (state.status) {
      case BrainStatus.installed:
        return _StatusLine(
          theme: theme,
          text: l10n.companionInstallReady(widget.companion.displayName),
          accent: true,
        );

      case BrainStatus.queued:
        return Column(
          children: [
            _StatusLine(theme: theme, text: l10n.companionInstallQueued),
            const SizedBox(height: 10),
            _TextButton(
              theme: theme,
              label: l10n.companionInstallCancel,
              onTap: () => _manager.cancel(widget.brain),
            ),
          ],
        );

      case BrainStatus.downloading:
        return Column(
          children: [
            _StatusLine(
              theme: theme,
              // Bytes, not a percentage. A percentage on a several-minute
              // download tells you nothing you can act on; "104 MB of 328 MB"
              // is a number somebody can weigh against their data plan and
              // their remaining storage.
              text: l10n.companionInstallProgress(
                _mib(state.receivedBytes),
                _mib(state.totalBytes),
              ),
            ),
            const SizedBox(height: 10),
            // PAUSE is the primary stop, because it is the reversible one.
            // Cancel lives one step further in, on the paused state, where
            // the amount about to be thrown away is written next to it.
            _TextButton(
              theme: theme,
              label: l10n.companionInstallPause,
              onTap: () => _manager.pause(widget.brain),
            ),
          ],
        );

      case BrainStatus.paused:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusLine(
              theme: theme,
              text: l10n.companionInstallPausedAt(
                _mib(state.receivedBytes),
                _mib(state.totalBytes),
              ),
            ),
            const SizedBox(height: 14),
            _PrimaryButton(
              theme: theme,
              label: l10n.companionInstallResume,
              onTap: () => _manager.install(widget.brain),
            ),
            const SizedBox(height: 4),
            _TextButton(
              theme: theme,
              label: l10n.companionInstallDiscard,
              onTap: () => _manager.cancel(widget.brain),
            ),
          ],
        );

      case BrainStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _failureText(l10n, state.failure),
              textAlign: TextAlign.center,
              style: theme.caption.copyWith(color: theme.danger),
            ),
            const SizedBox(height: 14),
            _PrimaryButton(
              theme: theme,
              label: l10n.companionInstallRetry,
              // Awaited: acknowledging re-reads the disk, and a failed
              // download usually still HAS its bytes — a dropped connection
              // keeps them. Installing before that lands would start from
              // zero and throw the resume away, which is the one thing this
              // whole change exists to prevent.
              onTap: () async {
                await _manager.acknowledgeFailure(widget.brain);
                await _manager.install(widget.brain);
              },
            ),
          ],
        );

      case BrainStatus.absent:
        // The size lives ON the button, not beside it. It is a term of the
        // agreement, and the place a term of an agreement belongs is inside
        // the thing you press to agree.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrimaryButton(
              theme: theme,
              label: l10n.companionInstallAction(widget.brain.sizeLabel),
              onTap: () => _manager.install(widget.brain),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.companionInstallOneTime,
              textAlign: TextAlign.center,
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
          ],
        );
    }
  }

  String _failureText(AppLocalizations l10n, BrainInstallFailure? failure) =>
      switch (failure) {
        BrainInstallFailure.storage => l10n.companionInstallFailedStorage,
        BrainInstallFailure.network => l10n.companionInstallFailedNetwork,
        // Worth its own sentence rather than "couldn't finish": the bytes were
        // received and then rejected, the partial has already been thrown
        // away, and the retry genuinely does start clean. Saying so is the
        // difference between a user retrying with hope and retrying with
        // suspicion.
        BrainInstallFailure.integrity => l10n.companionInstallFailedIntegrity,
        _ => l10n.companionInstallFailedUnknown,
      };

  /// Whole binary megabytes, to match what every OS storage screen reports.
  static String _mib(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';
}

/// The settings screen's stand-in for the hero ring.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.theme,
    required this.fraction,
    required this.motion,
  });

  final AppTheme theme;
  final double fraction;
  final MotionScope motion;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction),
        duration: motion.d(const Duration(milliseconds: 260)),
        curve: motion.c(theme.motionCurve),
        builder: (context, value, _) => Container(
          height: 5,
          color: theme.inkMuted.withValues(alpha: 0.18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(color: theme.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// The monogram, with the download drawn around it.
///
/// The progress arc lives on the companion's own mark rather than in a bar
/// somewhere else on the sheet, so the thing filling up IS the person
/// arriving. It is also the only progress indicator on screen, which keeps the
/// sheet from looking like a download manager.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.companion,
    required this.theme,
    required this.motion,
    required this.progress,
  });

  final Companion companion;
  final AppTheme theme;
  final MotionScope motion;

  /// Null before anything starts — the ring is then a plain resting circle.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    const size = 92.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress ?? 0),
            duration: motion.d(const Duration(milliseconds: 320)),
            curve: motion.c(theme.motionCurve),
            builder: (context, value, _) => CustomPaint(
              size: const Size.square(size),
              painter: _RingPainter(
                progress: progress == null ? 0 : value,
                track: theme.inkMuted.withValues(alpha: 0.18),
                arc: theme.accent,
              ),
            ),
          ),
          CompanionMark(
            companion: companion,
            size: 58,
            foreground: theme.accentInk,
            background: theme.accent,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.arc,
  });

  final double progress;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 3.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      // From twelve o'clock, clockwise — the direction every progress ring on
      // both platforms turns.
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.arc != arc || old.track != track;
}

class _Assurance extends StatelessWidget {
  const _Assurance({
    required this.theme,
    required this.icon,
    required this.label,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 15, color: theme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.body.copyWith(color: theme.inkSoft),
              ),
            ),
          ],
        ),
      );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.theme,
    required this.text,
    this.accent = false,
  });

  final AppTheme theme;
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: theme.body.copyWith(
          color: accent ? theme.accent : theme.inkSoft,
          fontWeight: accent ? FontWeight.w600 : null,
        ),
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final AppTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.rounded,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.bodyEmph.copyWith(color: theme.accentInk),
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final AppTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.rounded,
      radius: theme.radiusSm,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.body.copyWith(color: theme.inkMuted),
          ),
        ),
      ),
    );
  }
}
