/// Settings › Companions › Marlowe.
///
/// ── An honest shelf for someone who hasn't started work ────────────────────
///
/// Marlowe's skills are not built yet. This screen ships anyway, and it is not a
/// placeholder — it is the part of Marlowe that is genuinely useful before
/// do anything: the shelf.
///
/// The reasoning is the download. These brains run from 932 MB to 2.6 GB;
/// nobody wants to meet that ask at the moment they first want something from
/// them, over whatever connection they happen to be on. Letting somebody put a
/// brain on the shelf tonight, on wi-fi, is a real thing this screen does for
/// them today.
///
/// What it must not do is pretend. The header says plainly that the skills are
/// still arriving. There is no chat field, no "ask Marlowe anything", nothing
/// that would take a tap and give nothing back.
///
/// Unlike Sebastian, Marlowe gets a real choice of brain, and that asymmetry is
/// deliberate — see [Companion.brainsAreUserChosen]. Translation has one right
/// answer at this size; open-ended help does not, and the size/quality trade
/// is one no companion can make on the user's behalf.
library;

import 'package:flutter/material.dart';

import '../../companions/brain_manager.dart';
import '../../companions/brain_spec.dart';
import '../../companions/companion.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/destructive_sheet.dart';
import 'companion_page.dart';

class MarloweScreen extends StatefulWidget {
  const MarloweScreen({super.key});

  @override
  State<MarloweScreen> createState() => _MarloweScreenState();
}

class _MarloweScreenState extends State<MarloweScreen> {
  static const _companion = Companion.marlowe;

  @override
  void initState() {
    super.initState();
    BrainManager.instance.addListener(_onChange);
    SettingsStore.instance.addListener(_onChange);
    BrainManager.instance.refresh();
  }

  @override
  void dispose() {
    BrainManager.instance.removeListener(_onChange);
    SettingsStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  /// Which brain Marlowe is set to think with.
  ///
  /// Falls back to the first INSTALLED one rather than to the first in the
  /// catalog, so a user who installs exactly one brain never has to also
  /// select it. Nothing installed resolves to null, which is what the empty
  /// state reads.
  ///
  /// Delegates rather than repeating the resolution: the Settings status line
  /// names the same tier, and a second copy of "which one is active" is how a
  /// screen ends up badging one row while describing another.
  BrainSpec? get _active => activeMarloweBrain();

  Future<void> _remove(BrainSpec brain) async {
    final l10n = AppLocalizations.of(context);
    final shared = _sharedWith(brain);
    final confirmed = await showConfirmSheet(
      context,
      headline: l10n.companionBrainRemoveTitle(marloweTierName(l10n, brain)),
      // Names whoever else is about to lose it. Appended rather than replacing
      // the size line — how much disk this frees is still the main thing being
      // asked about.
      body: shared.isEmpty
          ? l10n.companionRemoveMessage(brain.sizeLabel)
          : '${l10n.companionRemoveMessage(brain.sizeLabel)} '
              '${l10n.companionBrainSharedWarning(shared.first.displayName)}',
      confirmLabel: l10n.companionRemoveConfirm,
    );
    if (!confirmed || !mounted) return;
    await BrainManager.instance.uninstall(brain);
    if (SettingsStore.instance.marloweBrainId == brain.id) {
      await SettingsStore.instance.setMarloweBrainId(null);
    }
  }

  /// Who else loses these weights if they go. See [otherCompanionsUsing].
  List<Companion> _sharedWith(BrainSpec brain) =>
      otherCompanionsUsing(brain, _companion);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final active = _active;

    return CompanionPage(
      // The companion's own name as the large title, the way a Contacts card
      // is titled by the person.
      title: _companion.displayName,
      subtitle: _companion.tagline(l10n),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompanionMark(
              companion: _companion,
              size: 48,
              foreground: theme.accentInk,
              background: theme.accent,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _companion.blurb(l10n),
                style: theme.body.copyWith(color: theme.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Said once, plainly, at the top — not as a badge on every row and not
        // buried at the bottom where somebody would find it after downloading
        // two gigabytes.
        _ComingSoonNote(theme: theme, l10n: l10n),
        const SizedBox(height: 26),
        CompanionSectionLabel(l10n.compBrain),
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
          child: Text(
            l10n.marloweBrainsCaption,
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
        ),
        for (final brain in BrainCatalog.marloweBrains)
          BrainRow(
            brain: brain,
            name: marloweTierName(l10n, brain),
            // The one place in the app that admits what the brain really is.
            // Small type, under a human-readable tier, for the reader who
            // came looking — see the note at the top of
            // [showCompanionInstallSheet] for why it is nowhere else.
            detail: '${brain.sizeLabel} · ${brain.technicalName} · ${brain.license}',
            selected: active?.id == brain.id,
            onSelect: () => SettingsStore.instance.setMarloweBrainId(brain.id),
            onRemove: () => _remove(brain),
            sharedWith: _sharedWith(brain),
          ),
      ],
    );
  }
}

class _ComingSoonNote extends StatelessWidget {
  const _ComingSoonNote({required this.theme, required this.l10n});

  final AppTheme theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule, size: 15, color: theme.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.marloweSkillsComingSoon,
              style: theme.caption.copyWith(color: theme.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
