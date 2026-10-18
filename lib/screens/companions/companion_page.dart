/// Chrome and parts shared by the three Companions screens.
///
/// Extracted rather than duplicated because the brain row in particular is
/// genuinely the same control in two places with different framing: on Marlowe's
/// shelf it is one of several and carries a tier name; on Sebastian's screen it
/// is the only one and carries his. A second copy of its five-state install
/// machine would drift from this one within a release.
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../companions/brain_manager.dart';
import '../../companions/brain_spec.dart';
import '../../companions/companion.dart';
import '../../companions/device_capability.dart';
import '../../companions/sebastian.dart';
import '../../transcripts/transcript_model.dart';
import '../../transcripts/voice_transcriber.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/text_case.dart';
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

/// The introduction at the top of every companion's screen: the mark, the
/// longer pitch, and, for a companion that has one, a line in his own voice.
///
/// Shared so the three screens open the same way; it was a private widget on
/// one screen and a copy of it inline on another.
class CompanionPortrait extends StatelessWidget {
  const CompanionPortrait({super.key, required this.companion, this.quote});

  final Companion companion;

  /// A personality line under the pitch, already in quotation marks.
  final String? quote;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final line = quote;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompanionMark(
          companion: companion,
          size: 48,
          foreground: theme.accentInk,
          background: theme.accent,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companion.blurb(l10n),
                style: theme.body.copyWith(color: theme.inkSoft),
              ),
              if (line != null) ...[
                const SizedBox(height: 8),
                Text(
                  line,
                  style: groupedSubtitleStyle(theme).copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
///
/// Includes Bartleby's speech model and transcripts, which live outside the
/// brain store: a total under a list that names him has to count him.
class CompanionStorageLine extends StatefulWidget {
  const CompanionStorageLine({super.key});

  @override
  State<CompanionStorageLine> createState() => _CompanionStorageLineState();
}

class _CompanionStorageLineState extends State<CompanionStorageLine> {
  int _speechBytes = 0;

  @override
  void initState() {
    super.initState();
    VoiceTranscriber.instance.modelInstalled.addListener(_loadSpeech);
    _loadSpeech();
  }

  @override
  void dispose() {
    VoiceTranscriber.instance.modelInstalled.removeListener(_loadSpeech);
    super.dispose();
  }

  Future<void> _loadSpeech() async {
    final b = await TranscriptStore.instance.bytesUsed();
    if (mounted && b != _speechBytes) setState(() => _speechBytes = b);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bytes = BrainManager.instance.installedBytes + _speechBytes;
    return Row(
      children: [
        Icon(CupertinoIcons.tray_full, size: 15, color: theme.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            bytes == 0
                ? l10n.companionStorageEmpty
                : l10n.companionStorageUsed(companionByteLabel(bytes)),
            // The footer step on the body face — the caption slot is
            // tracked typewriter on a character theme.
            style: groupedFooterStyle(theme),
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
  // Bartleby has no brain: his own download and his own platform test.
  if (companion == Companion.bartleby) return _bartlebyStatus(l10n);

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
    Companion.bartleby => _bartlebyStatus(l10n),
  };
}

/// Ordered like the others: blocked, then moving, then what he will use.
///
/// Callers that show this line listen to [VoiceTranscriber.download] and
/// [VoiceTranscriber.modelInstalled]; see [bartlebyStatusListenable].
String _bartlebyStatus(AppLocalizations l10n) {
  final t = VoiceTranscriber.instance;
  if (!t.supported) return l10n.settingsScreenCompanionsUnavailable;
  final dl = t.download.value;
  if (dl != null) {
    return l10n.settingsScreenCompanionsDownloading((dl.fraction * 100).round());
  }
  if (t.modelInstalledNow ?? false) return l10n.bartlebyStatusEveryLanguage;
  // Without the model he still works where the OS already knows the
  // language. Only Apple platforms have that.
  if (t.hasBuiltIn) return l10n.bartlebyStatusBuiltInOnly;
  return l10n.companionStatusNoBrain;
}

/// What changes [companionStatusLine] for Bartleby.
Listenable get bartlebyStatusListenable => Listenable.merge([
      VoiceTranscriber.instance.download,
      VoiceTranscriber.instance.modelInstalled,
    ]);

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
        final selectable =
            !unavailable && state.status == BrainStatus.installed;

        // A row of a grouped block (the caller supplies the block — see
        // [GroupedSection]), not a bordered card of its own: the shelf used
        // to be the one stack of outlined cards on a page of grouped
        // blocks. Leading selection circle, 17pt name, 15pt detail,
        // trailing action pill; notes under it at the meta step.
        final row = Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selected != null) ...[
                    // A brain that isn't installed can't be chosen, and the
                    // circle says so rather than looking like an option
                    // that refuses to respond.
                    SelectionCheck(
                      picked: isSelected,
                      enabled: state.status == BrainStatus.installed,
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
                                style: groupedTitleStyle(theme).copyWith(
                                  color: unavailable ? theme.inkMuted : null,
                                ),
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
                              _InUseBadge(
                                theme: theme,
                                label: l10n.companionBrainInUse,
                              ),
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
                          style: groupedSubtitleStyle(theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (unavailable)
                    Icon(CupertinoIcons.nosign, size: 17, color: theme.inkMuted)
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
                    Icon(CupertinoIcons.link, size: 13, color: theme.inkMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.companionBrainAlsoUsedBy(
                          sharedWith.first.displayName,
                        ),
                        style: groupedMetaStyle(theme),
                      ),
                    ),
                  ],
                ),
              ],
              if (state.status == BrainStatus.downloading ||
                  state.status == BrainStatus.paused) ...[
                const SizedBox(height: 12),
                CompanionProgressLine(fraction: state.fraction),
              ],
              if (state.status == BrainStatus.paused) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.companionInstallPausedAt(
                          _mib(state.receivedBytes),
                          _mib(state.totalBytes),
                        ),
                        style: groupedMetaStyle(theme),
                      ),
                    ),
                    // The destructive option, offered only HERE — beside the
                    // number it destroys. On a running download it would be
                    // an invitation to lose progress by mis-tapping.
                    TextLinkButton(
                      label: l10n.companionInstallDiscard,
                      destructive: true,
                      fontSize: 15,
                      onTap: () => BrainManager.instance.cancel(brain),
                    ),
                  ],
                ),
              ],
              if (state.status == BrainStatus.failed) ...[
                const SizedBox(height: 8),
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
                  style: groupedMetaStyle(theme).copyWith(color: theme.danger),
                ),
              ],
            ],
          ),
        );
        if (!selectable || onSelect == null) return row;
        return SpringPress(
          onTap: onSelect,
          semanticLabel: name,
          scale: 0.98,
          child: row,
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
    // Every action is the shared row pill (15/w600 on a quiet capsule) —
    // it was a private `_SmallAction` in the caption slot.
    switch (state.status) {
      case BrainStatus.installed:
        if (onRemove == null) {
          return Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 20,
            color: theme.accent,
          );
        }
        return RowPillButton(
          label: l10n.companionBrainRemove,
          onTap: onRemove,
          destructive: true,
        );

      case BrainStatus.downloading:
        // PAUSE, not cancel. A running download's primary affordance should be
        // the reversible one — cancel is still reachable, from the paused
        // state, where the consequence ("throw away 104 MB") is legible
        // because the number is on screen next to it.
        return RowPillButton(
          label: l10n.companionInstallPause,
          onTap: () => manager.pause(brain),
        );

      case BrainStatus.queued:
        return RowPillButton(
          label: l10n.companionInstallCancel,
          onTap: () => manager.cancel(brain),
        );

      case BrainStatus.paused:
        return RowPillButton(
          label: l10n.companionInstallResume,
          onTap: manager.isInstallingAny ? null : () => manager.install(brain),
        );

      case BrainStatus.failed:
        return RowPillButton(
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
        return RowPillButton(
          label: brain.sizeLabel,
          semanticLabel: l10n.companionInstallAction(brain.sizeLabel),
          onTap: busy ? null : () => manager.install(brain),
        );
    }
  }
}

/// The chip on the row that is actually running: an accent capsule at the
/// meta step (13/w600 on the body face, sentence case).
///
/// Same shape and register as `LanguageScreen`'s active badge, deliberately —
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        sentenceCaseOf(context, label),
        style: groupedMetaStyle(theme).copyWith(
          color: theme.accentInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The thin accent bar under a row that is downloading. Shared by the brain
/// rows and Bartleby's speech model row.
class CompanionProgressLine extends StatelessWidget {
  const CompanionProgressLine({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
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
