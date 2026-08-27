/// The strip that will not go away until a companion has finished arriving.
///
/// ── Why this is not dismissable ────────────────────────────────────────────
///
/// A brain is between 328 MB and 2.6 GB. That is a download somebody can start
/// and then genuinely lose: they close the sheet, go back to chatting, and
/// twenty minutes later have no idea whether it is still running, whether it
/// failed, or whether they cancelled it by swiping something away. There was
/// no ambient sign of it anywhere.
///
/// A dismissable banner would not fix that, it would postpone it by one tap —
/// and the state it is reporting genuinely does not go away when you stop
/// looking. So it stays until the download reaches an end state: finished,
/// discarded, or failed.
///
/// It stays for a PAUSED download too, which is the deliberate part. Pausing
/// is not finishing: several hundred megabytes are still sitting there
/// half-written, and the banner is what stops that from being forgotten until
/// somebody wonders where their storage went. It offers to continue rather
/// than nagging in the abstract.
///
/// ── Where it lives ─────────────────────────────────────────────────────────
///
/// The same top slot as [ConnectionBanner] and [ActiveCallPill] — a Column
/// above the root navigator, where every child collapses to zero height when
/// it has nothing to say. That is what makes it genuinely global rather than
/// per-screen, and why it must be zero-height AND non-hit-testable when idle:
/// it spans the top of every screen in the app.
library;

import 'package:flutter/material.dart';

import '../companions/brain_manager.dart';
import '../companions/brain_spec.dart';
import '../companions/companion.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/companions/companions_screen.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

class CompanionDownloadBanner extends StatelessWidget {
  const CompanionDownloadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BrainManager.instance,
      builder: (context, _) {
        final pending = _pending();
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: pending == null
              // Zero-height AND nothing to hit-test. This sits across the top
              // of every screen in the app; a hidden strip that still ate
              // taps would be a bug nobody could find.
              ? const SizedBox(width: double.infinity, height: 0)
              : _Strip(brain: pending.$1, state: pending.$2),
        );
      },
    );
  }

  /// The one download worth a banner, or null.
  ///
  /// At most one brain is ever downloading (see [BrainManager.install]), but a
  /// second can be paused at the same time — so this prefers whatever is
  /// actively moving and falls back to the paused one. Reporting a paused
  /// download while another is running would describe the less urgent of the
  /// two.
  (BrainSpec, BrainState)? _pending() {
    final manager = BrainManager.instance;
    BrainSpec? paused;
    for (final brain in BrainCatalog.all) {
      final state = manager.stateOf(brain);
      if (state.status == BrainStatus.downloading ||
          state.status == BrainStatus.queued) {
        return (brain, state);
      }
      if (state.status == BrainStatus.paused) paused ??= brain;
    }
    if (paused != null) return (paused, manager.stateOf(paused));
    return null;
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.brain, required this.state});

  final BrainSpec brain;
  final BrainState state;

  /// Whoever this brain belongs to. Companions can share one in principle —
  /// see [BrainCatalog.companionsUsing] — and naming the first is right
  /// because the banner is identifying a download, not assigning blame.
  Companion get _companion =>
      BrainCatalog.companionsUsing(brain).firstOrNull ?? Companion.sebastian;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final paused = state.status == BrainStatus.paused;

    return Material(
      color: Colors.transparent,
      // This subtree sits above the root navigator, outside any Scaffold, so
      // it inherits no text style. Without an explicit one Flutter paints its
      // debug yellow underlines.
      child: DefaultTextStyle(
        style: theme.body,
        child: SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: () => _open(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.12),
                border: Border(
                  bottom:
                      BorderSide(color: theme.accent.withValues(alpha: 0.22)),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
                    child: Row(
                      children: [
                        CompanionMark(
                          companion: _companion,
                          size: 16,
                          foreground: theme.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            paused
                                ? l10n.companionBannerPaused(
                                    _companion.displayName,
                                    _mib(state.receivedBytes),
                                    _mib(state.totalBytes),
                                  )
                                : l10n.companionBannerDownloading(
                                    _companion.displayName,
                                    _mib(state.receivedBytes),
                                    _mib(state.totalBytes),
                                  ),
                            style: theme.caption.copyWith(color: theme.accent),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // The action, not a dismissal. Pausing and resuming are
                        // reachable from here because the alternative is a
                        // strip that reports a state it gives you no way to
                        // change; DISCARD deliberately is not, because a
                        // destructive tap does not belong on a banner that
                        // spans every screen.
                        _Action(
                          theme: theme,
                          label: paused
                              ? l10n.companionInstallResume
                              : l10n.companionInstallPause,
                          onTap: () => paused
                              ? BrainManager.instance.install(brain)
                              : BrainManager.instance.pause(brain),
                        ),
                      ],
                    ),
                  ),
                  // Rides the strip's own bottom border rather than being a bar
                  // of its own — the same trick RoomTranslateBar uses, and at
                  // one and a half points tall it reads as progress without
                  // adding a row.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: state.fraction),
                      duration: motion.d(const Duration(milliseconds: 260)),
                      curve: motion.c(theme.motionCurve),
                      builder: (context, value, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value.clamp(0.0, 1.0),
                          child: Container(
                            height: 1.5,
                            color: paused
                                ? theme.accent.withValues(alpha: 0.45)
                                : theme.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens the Companions hub.
  ///
  /// The hub rather than the companion's own screen: the banner may be showing
  /// a brain that belongs to whichever companion, and one predictable
  /// destination is worth more than a clever one. Root navigator, because this
  /// strip lives above it and there is no other navigator in scope.
  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const CompanionsScreen()),
    );
  }

  static String _mib(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';
}

class _Action extends StatelessWidget {
  const _Action({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  final AppTheme theme;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // Horizontal padding IS the tap target — the strip is too short to
        // supply one vertically, and this word is small.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.caption.copyWith(
            color: theme.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
