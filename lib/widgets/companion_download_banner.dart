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
///
/// The chrome itself lives in [CompanionStrip], shared with the room's
/// translate bar. Everything below is about WHICH download to report and what
/// to call it; nothing below decides what it looks like.
library;

import 'package:flutter/material.dart';

import '../companions/brain_manager.dart';
import '../companions/brain_spec.dart';
import '../companions/companion.dart';
import '../l10n/generated/app_localizations.dart';
import '../screens/companions/companion_page.dart' show companionByteLabel;
import '../screens/companions/marlowe_screen.dart';
import '../screens/companions/sebastian_screen.dart';
import '../theme/theme_scope.dart';
import 'companion_strip.dart';

class CompanionDownloadBanner extends StatelessWidget {
  const CompanionDownloadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BrainManager.instance,
      builder: (context, _) {
        final pending = _pending();
        // This subtree sits above the root navigator, outside any Scaffold, so
        // it inherits no text style. Without an explicit one Flutter paints its
        // debug yellow underlines.
        return Material(
          color: Colors.transparent,
          child: DefaultTextStyle(
            style: ThemeScope.of(context).body,
            child: _strip(context, pending),
          ),
        );
      },
    );
  }

  Widget _strip(BuildContext context, (BrainSpec, BrainState)? pending) {
    if (pending == null) {
      return const CompanionStrip(
        visible: false,
        companion: Companion.sebastian,
        message: '',
      );
    }
    final (brain, state) = pending;
    final l10n = AppLocalizations.of(context);
    final companion = _companionFor(brain);
    final paused = state.status == BrainStatus.paused;

    return CompanionStrip(
      visible: true,
      companion: companion,
      safeAreaTop: true,
      // The name and the bytes, then the percentage. The bytes are what a
      // person checks against their own sense of how big the download was; the
      // percentage is what makes it read as PROGRESS rather than as a number
      // that might be stuck.
      message: paused
          ? l10n.companionBannerPaused(
              companion.displayName,
              companionByteLabel(state.receivedBytes),
              companionByteLabel(state.totalBytes),
            )
          : l10n.companionBannerDownloading(
              companion.displayName,
              companionByteLabel(state.receivedBytes),
              companionByteLabel(state.totalBytes),
            ),
      detail: '${(state.fraction * 100).round()}%',
      progress: state.fraction,
      muted: paused,
      semanticLabel: l10n.companionsScreenTitle,
      // The action, not a dismissal. Pausing and resuming are reachable from
      // here because the alternative is a strip that reports a state it gives
      // you no way to change; DISCARD deliberately is not, because a
      // destructive tap does not belong on a banner that spans every screen.
      actionLabel:
          paused ? l10n.companionInstallResume : l10n.companionInstallPause,
      onAction: () => paused
          ? BrainManager.instance.install(brain)
          : BrainManager.instance.pause(brain),
      onTap: () => _open(context, companion),
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

  /// Whoever this brain belongs to. Companions can share one in principle —
  /// see [BrainCatalog.companionsUsing] — and naming the first is right
  /// because the banner is identifying a download, not assigning blame.
  Companion _companionFor(BrainSpec brain) =>
      BrainCatalog.companionsUsing(brain).firstOrNull ?? Companion.sebastian;

  /// Opens the screen belonging to whoever is downloading.
  ///
  /// It used to open a Companions hub that sat between Settings and the two
  /// residents. That hub is gone — Settings lists them directly now — so this
  /// goes where the hub's only useful tap went anyway, one screen sooner. Root
  /// navigator, because this strip lives above it and there is no other
  /// navigator in scope.
  void _open(BuildContext context, Companion companion) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => switch (companion) {
          Companion.sebastian => const SebastianScreen(),
          Companion.marlowe => const MarloweScreen(),
        },
      ),
    );
  }
}
