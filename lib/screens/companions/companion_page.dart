/// Chrome and parts shared by the three Companions screens.
///
/// Extracted rather than duplicated because the brain row in particular is
/// genuinely the same control in two places with different framing: on Marlowe's
/// shelf it is one of several and carries a tier name; on Sebastian's screen it
/// is the only one and carries his. A second copy of its five-state install
/// machine would drift from this one within a release.
library;

import 'package:flutter/material.dart';

import '../../companions/brain_manager.dart';
import '../../companions/brain_spec.dart';
import '../../companions/companion.dart';
import '../../companions/device_capability.dart';
import '../../companions/sebastian.dart';
import '../../data/settings_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/account_kit.dart';
import '../../widgets/ios_kit.dart';

/// The house settings-detail page: background layer, back arrow, big title,
/// accent rule, caption, then content. Copied in shape from `LanguageScreen`
/// and the other pickers so Companions does not read as a screen from a
/// different app.
class CompanionPage extends StatelessWidget {
  const CompanionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IosPage(
        title: title,
        subtitle: subtitle,
        slivers: readableSlivers(context, children),
      );
}

class CompanionCard extends StatelessWidget {
  const CompanionCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // A grouped block: the theme's grouped fill, no border.
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// All-caps section label, matching Settings' own.
class CompanionSectionLabel extends StatelessWidget {
  const CompanionSectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // An inset-grouped section header: sentence case, small, muted.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
      child: Text(
        label,
        style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
      ),
    );
  }
}

/// The human tier name for one of Marlowe's brains.
///
/// Shared rather than private to the shelf, because the Companions hub now
/// prints it too — and a hub that called the same download something different
/// from the screen behind it would be worse than a hub that said nothing.
///
/// Switched on the id rather than read from [BrainSpec.label], because the
/// label is a constant in a Dart file and this string is on screen. A shelf
/// reading "Swift / Balanced / Deep" inside a Turkish UI would be the only
/// untranslated text in the app that is not a proper noun. Falls back to the
/// raw label for a brain added to the catalog without a matching string —
/// visible, English, and obviously a gap, which is what a fallback should be.
String marloweTierName(AppLocalizations l10n, BrainSpec brain) =>
    switch (brain.id) {
      'qwen3-1.7b-int4' => l10n.marloweBrainTierSwift,
      'gemma-4-e2b' => l10n.marloweBrainTierBalanced,
      'qwen3.5-4b-int4' => l10n.marloweBrainTierDeep,
      _ => brain.label,
    };

/// What the companions cost, in the only unit anyone cares about.
///
/// Counts a shared brain once — a spec on two shelves is one file on disk, so a
/// naive sum would report 656 MB for 328 MB. See [BrainManager.installedBytes].
///
/// Lives here rather than on a screen because the Settings section that lists
/// the companions is now the place that prints it, and the number belongs to
/// the group rather than to either resident.
class CompanionStorageLine extends StatelessWidget {
  const CompanionStorageLine({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bytes = BrainManager.instance.installedBytes;
    return Row(
      children: [
        Icon(Icons.sd_storage_outlined, size: 14, color: theme.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            bytes == 0
                ? l10n.companionStorageEmpty
                : l10n.companionStorageUsed(companionByteLabel(bytes)),
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// Bytes as the number an OS storage screen would show.
///
/// Binary megabytes, so "328 MB" here and "328 MB" in iOS Settings are the same
/// file. Shared because four surfaces print it — the storage line, the download
/// strip, the status line and [BrainSpec.sizeLabel] — and four roundings are
/// how the same download comes to be 328 MB in one place and 344 MB in another.
String companionByteLabel(int bytes) {
  const mib = 1024 * 1024;
  if (bytes >= 1024 * mib) {
    return '${(bytes / (1024 * mib)).toStringAsFixed(1)} GB';
  }
  return '${(bytes / mib).round()} MB';
}

/// The one line that says what a companion is currently doing, or what is
/// stopping it.
///
/// Shared rather than per-screen because it is now asked in two places at once
/// — the Settings section and whatever screen you open from it — and two
/// answers to "is Sebastian on?" that could disagree is a bug with no symptom
/// until somebody notices the two disagreeing. It used to be exactly that:
/// `_CompanionsScreenState._sebastianStatus` and the settings screen's own
/// `_companionsLabel` were separate implementations of the same question.
///
/// Ordered by what is BLOCKING first, then by what is happening. A download in
/// flight outranks everything, including "off": it is the only state with a
/// number that moves, and a row that said "Off" while 300 MB were arriving
/// would be describing the setting rather than the device.
String companionStatusLine(Companion companion, AppLocalizations l10n) {
  // The short form, not [AppLocalizations.companionUnsupportedPlatform]: this
  // is a right-hand value column, and the long sentence belongs on the screen
  // that has room to explain.
  if (!Sebastian.instance.isAvailable) {
    return l10n.settingsScreenCompanionsUnavailable;
  }

  // Whichever of this companion's brains is moving right now. Sebastian has
  // exactly one; Marlowe has three and only ever installs one at a time.
  for (final brain in BrainCatalog.forCompanion(companion)) {
    final state = BrainManager.instance.stateOf(brain);
    if (state.status == BrainStatus.downloading ||
        state.status == BrainStatus.queued) {
      return l10n.settingsScreenCompanionsDownloading(
        (state.fraction * 100).round(),
      );
    }
    if (state.status == BrainStatus.paused) {
      return l10n.companionInstallPausedAt(
        companionByteLabel(state.receivedBytes),
        companionByteLabel(state.totalBytes),
      );
    }
  }

  return switch (companion) {
    Companion.sebastian => _sebastianStatus(l10n),
    Companion.marlowe => _marloweStatus(l10n),
  };
}

String _sebastianStatus(AppLocalizations l10n) {
  final s = Sebastian.instance;
  if (!s.isInstalled) return l10n.companionStatusNotInstalled;
  if (!s.isEnabled) return l10n.companionStatusOff;
  return l10n.companionStatusTranslatingInto(s.targetLanguage.autonym);
}

/// Names the brain Marlowe would actually load rather than counting the ones on
/// disk. "2 downloads ready" answers a question nobody asked; what somebody
/// glancing at this row wants to know is which of the three is doing the
/// thinking.
String _marloweStatus(AppLocalizations l10n) {
  final active = activeMarloweBrain();
  if (active == null) return l10n.companionStatusNoBrain;
  return l10n.companionStatusUsingBrain(marloweTierName(l10n, active));
}

/// The brain Marlowe would load right now: the stored choice if it is on disk,
/// else the first installed row of the shelf.
///
/// Shared with `MarloweScreen` so the shelf's badge and every status line that
/// names a tier resolve the same way. Two resolutions of "which brain is
/// active" is how a screen ends up badging one row and describing another.
BrainSpec? activeMarloweBrain() {
  final chosen = BrainCatalog.byId(SettingsStore.instance.marloweBrainId);
  if (chosen != null && BrainManager.instance.isInstalled(chosen)) {
    return chosen;
  }
  for (final b in BrainCatalog.marloweBrains) {
    if (BrainManager.instance.isInstalled(b)) return b;
  }
  return null;
}

/// What to call one of Sebastian's two brains.
///
/// SR and JR rather than a tier ladder or a model name. Marlowe's shelf is a
/// choice the user makes and its rows are named for what the choice is about
/// (Swift, Balanced, Deep); Sebastian's is not a choice — the device decides —
/// so his rows are named for who they are. He is one companion, and these are
/// the same person with more or less of him on the phone.
///
/// Not routed through l10n, for the same reason [Companion.displayName] is not:
/// a name that changed language when the UI did would stop being a name.
String sebastianTierName(BrainSpec brain) =>
    brain.id == BrainCatalog.sebastianFallback.id
        ? 'Sebastian Jr.'
        : 'Sebastian Sr.';

/// Why this device cannot run [brain], or null when it can.
///
/// Names the requirement rather than the verdict. "Needs 4 GB of memory" is
/// something a person can check against their own phone and act on next time;
/// "unavailable" is a door with no handle.
String? brainUnavailableReason(BrainSpec brain, AppLocalizations l10n) {
  if (DeviceCapability.instance.canRun(brain)) return null;
  final need = brain.minRamMb;
  if (need == null) return l10n.companionUnsupportedPlatform;
  return l10n.companionBrainNeedsMemory(_memoryLabel(need));
}

/// A memory requirement, in the units people describe phones in.
///
/// Whole gigabytes, and NOT [companionByteLabel]: that one is for file sizes,
/// where a tenth of a gigabyte is a real difference worth printing. Nobody
/// says their phone has 4.0 GB of RAM.
String _memoryLabel(int mb) =>
    mb >= 1024 ? '${(mb / 1024).round()} GB' : '$mb MB';

/// Companions other than [self] whose shelf also lists [brain].
///
/// Empty with today's catalog — the shelves deliberately no longer overlap,
/// see [BrainCatalog.marloweBrains]. It is wired anyway because the failure it
/// prevents is silent: before this existed, removing Sebastian from HIS screen
/// deleted a brain Marlowe was set to think with, and nothing on either screen
/// said the two were the same file on disk. Marlowe's screen guarded it and
/// Sebastian's did not, which is the worst shape a guard can have.
///
/// Any future overlap now surfaces the same way on both sides: a note on the
/// row, and the other companion named in the confirm sheet.
List<Companion> otherCompanionsUsing(BrainSpec brain, Companion self) => [
      for (final c in BrainCatalog.companionsUsing(brain))
        if (c != self) c,
    ];

/// One brain, with its whole install lifecycle.
///
/// [name] and [detail] are supplied by the caller rather than read off the
/// spec, because the two callers describe the same object completely
/// differently: Marlowe's shelf names the tier and prints the model's real name
/// underneath; Sebastian's screen says only how much disk he is using. See the
/// note on `Companion.brainsAreUserChosen`.
class BrainRow extends StatelessWidget {
  const BrainRow({
    super.key,
    required this.brain,
    required this.name,
    required this.detail,
    this.selected,
    this.onSelect,
    this.onRemove,
    this.sharedWith = const [],
    this.unavailableReason,
  });

  final BrainSpec brain;
  final String name;
  final String detail;

  /// Null when this row is not part of a choice — Sebastian's single brain.
  /// Non-null renders the selection dot.
  final bool? selected;
  final VoidCallback? onSelect;

  /// Null hides the remove affordance.
  final VoidCallback? onRemove;

  /// Why this device cannot run these weights, or null when it can.
  ///
  /// Shown rather than hidden, deliberately. A shelf that silently omitted the
  /// better brain would leave somebody on the smaller one with no idea a better
  /// one exists, or why they are not being offered it — and "my phone cannot
  /// hold it" is a perfectly good answer that they are entitled to.
  ///
  /// It dims the row and replaces the install action: there is nothing to press
  /// and offering a button that could only fail would be worse than saying so.
  final String? unavailableReason;

  /// Other companions that also use these weights, from
  /// [otherCompanionsUsing]. Non-empty draws a line saying so, because a
  /// download the user thinks belongs to one companion quietly belonging to
  /// two is exactly the thing they should not have to discover by deleting it.
  final List<Companion> sharedWith;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: BrainManager.instance,
      builder: (context, _) {
        final manager = BrainManager.instance;
        final state = manager.stateOf(brain);
        final isSelected = selected ?? false;
        final unavailable = unavailableReason != null;

        return GestureDetector(
          onTap: !unavailable && state.status == BrainStatus.installed
              ? onSelect
              : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: isSelected && !unavailable
                  ? theme.accent.withValues(alpha: 0.12)
                  : theme.surface,
              border: Border.all(
                color: isSelected
                    ? theme.accent.withValues(alpha: 0.4)
                    : theme.divider,
              ),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (selected != null) ...[
                      _SelectionDot(
                        theme: theme,
                        on: isSelected,
                        dimmed: state.status != BrainStatus.installed,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: unavailable
                                      ? theme.bodyEmph
                                          .copyWith(color: theme.inkMuted)
                                      : theme.bodyEmph,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Beside the NAME rather than in the trailing
                              // slot, which belongs to the action. A badge
                              // that sat where REMOVE sits would be a label
                              // in a column of buttons, and would push the
                              // one affordance the row has off the edge on a
                              // narrow screen.
                              if (isSelected &&
                                  state.status == BrainStatus.installed) ...[
                                const SizedBox(width: 8),
                                _InUseBadge(theme: theme, label: l10n.companionBrainInUse),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The reason instead of the size. What this row is
                            // for, on a device that cannot run it, is saying
                            // why — the download figure is answering a
                            // question nobody can act on.
                            unavailableReason ?? detail,
                            style: theme.caption
                                .copyWith(color: theme.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (unavailable)
                      Icon(Icons.block, size: 16, color: theme.inkMuted)
                    else
                      _Trailing(
                        theme: theme,
                        l10n: l10n,
                        brain: brain,
                        state: state,
                        onRemove: onRemove,
                      ),
                  ],
                ),
                if (sharedWith.isNotEmpty &&
                    state.status == BrainStatus.installed) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.link, size: 12, color: theme.inkMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.companionBrainAlsoUsedBy(
                            sharedWith.first.displayName,
                          ),
                          style:
                              theme.caption.copyWith(color: theme.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ],
                if (state.status == BrainStatus.downloading ||
                    state.status == BrainStatus.paused) ...[
                  const SizedBox(height: 12),
                  _ProgressLine(theme: theme, fraction: state.fraction),
                ],
                if (state.status == BrainStatus.paused) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.companionInstallPausedAt(
                            _mib(state.receivedBytes),
                            _mib(state.totalBytes),
                          ),
                          style: theme.caption.copyWith(color: theme.inkMuted),
                        ),
                      ),
                      // The destructive option, offered only HERE — beside the
                      // number it destroys. On a running download it would be
                      // an invitation to lose progress by mis-tapping.
                      GestureDetector(
                        onTap: () => BrainManager.instance.cancel(brain),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                          child: Text(
                            l10n.companionInstallDiscard,
                            style: theme.caption.copyWith(color: theme.danger),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (state.status == BrainStatus.failed) ...[
                  const SizedBox(height: 10),
                  Text(
                    switch (state.failure) {
                      BrainInstallFailure.storage =>
                        l10n.companionInstallFailedStorage,
                      BrainInstallFailure.network =>
                        l10n.companionInstallFailedNetwork,
                      BrainInstallFailure.integrity =>
                        l10n.companionInstallFailedIntegrity,
                      _ => l10n.companionInstallFailedUnknown,
                    },
                    style: theme.caption.copyWith(color: theme.danger),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Whole binary megabytes, matching every OS storage screen.
String _mib(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

class _Trailing extends StatelessWidget {
  const _Trailing({
    required this.theme,
    required this.l10n,
    required this.brain,
    required this.state,
    required this.onRemove,
  });

  final AppTheme theme;
  final AppLocalizations l10n;
  final BrainSpec brain;
  final BrainState state;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final manager = BrainManager.instance;
    switch (state.status) {
      case BrainStatus.installed:
        if (onRemove == null) {
          return Icon(Icons.check_circle, size: 18, color: theme.accent);
        }
        return _SmallAction(
          theme: theme,
          label: l10n.companionBrainRemove,
          onTap: onRemove,
          destructive: true,
        );

      case BrainStatus.downloading:
        // PAUSE, not cancel. A running download's primary affordance should be
        // the reversible one — cancel is still reachable, from the paused
        // state, where the consequence ("throw away 104 MB") is legible
        // because the number is on screen next to it.
        return _SmallAction(
          theme: theme,
          label: l10n.companionInstallPause,
          onTap: () => manager.pause(brain),
        );

      case BrainStatus.queued:
        return _SmallAction(
          theme: theme,
          label: l10n.companionInstallCancel,
          onTap: () => manager.cancel(brain),
        );

      case BrainStatus.paused:
        return _SmallAction(
          theme: theme,
          label: l10n.companionInstallResume,
          onTap: manager.isInstallingAny ? null : () => manager.install(brain),
          leading: Icons.play_arrow,
        );

      case BrainStatus.failed:
        return _SmallAction(
          theme: theme,
          label: l10n.companionInstallRetry,
          onTap: () async {
            await manager.acknowledgeFailure(brain);
            await manager.install(brain);
          },
        );

      case BrainStatus.absent:
        // Disabled, not hidden, while another brain is downloading. Hiding it
        // would look like the row had become uninstallable; greying it says
        // "wait your turn", which is what is actually happening. See
        // [BrainManager.install] for why installs are serialised.
        final busy = manager.isInstallingAny;
        return _SmallAction(
          theme: theme,
          label: brain.sizeLabel,
          onTap: busy ? null : () => manager.install(brain),
          leading: Icons.arrow_downward,
        );
    }
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.theme,
    required this.label,
    required this.onTap,
    this.leading,
    this.destructive = false,
  });

  final AppTheme theme;
  final String label;
  final VoidCallback? onTap;
  final IconData? leading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = !enabled
        ? theme.inkMuted.withValues(alpha: 0.45)
        : (destructive ? theme.danger : theme.accent);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.capsule,
      radius: 999,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                Icon(leading, size: 13, color: ink),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: theme.caption.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The all-caps chip on the row that is actually running.
///
/// Same shape and register as `LanguageScreen`'s ACTIVE badge, deliberately —
/// this is the identical question ("which of these is live?") and answering it
/// two different ways in two settings screens is how an app stops feeling like
/// one app.
class _InUseBadge extends StatelessWidget {
  const _InUseBadge({required this.theme, required this.label});

  final AppTheme theme;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.monoTiny.copyWith(
          color: theme.accentInk,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({
    required this.theme,
    required this.on,
    required this.dimmed,
  });

  final AppTheme theme;
  final bool on;

  /// A brain that isn't installed can't be chosen, and the dot says so rather
  /// than looking like an option that refuses to respond.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = dimmed ? theme.inkMuted.withValues(alpha: 0.4) : theme.accent;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? color : theme.inkMuted, width: 1.5),
        color: on ? color : Colors.transparent,
      ),
      child: on ? Icon(Icons.check, size: 10, color: theme.accentInk) : null,
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.theme, required this.fraction});

  final AppTheme theme;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 3,
        color: theme.inkMuted.withValues(alpha: 0.18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(color: theme.accent),
          ),
        ),
      ),
    );
  }
}
