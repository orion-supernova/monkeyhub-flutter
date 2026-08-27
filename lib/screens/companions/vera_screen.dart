/// Settings › Companions › Vera.
///
/// ── An honest shelf for someone who hasn't started work ────────────────────
///
/// Vera's skills are not built yet. This screen ships anyway, and it is not a
/// placeholder — it is the part of her that is genuinely useful before she can
/// do anything: the shelf.
///
/// The reasoning is the download. Her brains are between 328 MB and 1.9 GB;
/// nobody wants to meet that ask at the moment they first want something from
/// her, over whatever connection they happen to be on. Letting somebody put a
/// brain on the shelf tonight, on wi-fi, is a real thing this screen does for
/// them today.
///
/// What it must not do is pretend. The header says plainly that her skills are
/// still arriving. There is no chat field, no "ask Vera anything", nothing
/// that would take a tap and give nothing back.
///
/// Unlike Sebastian she gets a real choice of brain, and that asymmetry is
/// deliberate — see [Companion.brainsAreUserChosen]. Translation has one right
/// answer at this size; open-ended help does not, and the size/quality trade
/// is one she cannot make on the user's behalf.
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

class VeraScreen extends StatefulWidget {
  const VeraScreen({super.key});

  @override
  State<VeraScreen> createState() => _VeraScreenState();
}

class _VeraScreenState extends State<VeraScreen> {
  static const _companion = Companion.vera;

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

  /// Which brain she is set to think with.
  ///
  /// Falls back to the first INSTALLED one rather than to the first in the
  /// catalog, so a user who installs exactly one brain never has to also
  /// select it. Nothing installed resolves to null, which is what the empty
  /// state reads.
  BrainSpec? get _active {
    final chosen = BrainCatalog.byId(SettingsStore.instance.veraBrainId);
    if (chosen != null && BrainManager.instance.isInstalled(chosen)) {
      return chosen;
    }
    for (final b in BrainCatalog.veraBrains) {
      if (BrainManager.instance.isInstalled(b)) return b;
    }
    return null;
  }

  Future<void> _remove(BrainSpec brain) async {
    final l10n = AppLocalizations.of(context);
    final shared = _sharedWith(brain);
    final confirmed = await showConfirmSheet(
      context,
      headline: l10n.companionBrainRemoveTitle(_tierName(l10n, brain)),
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
    if (SettingsStore.instance.veraBrainId == brain.id) {
      await SettingsStore.instance.setVeraBrainId(null);
    }
  }

  /// Who else loses these weights if they go. See [otherCompanionsUsing].
  List<Companion> _sharedWith(BrainSpec brain) =>
      otherCompanionsUsing(brain, _companion);

  /// The human tier name for [brain].
  ///
  /// Switched on the id rather than read from [BrainSpec.label], because the
  /// label is a constant in a Dart file and this string is on screen. A shelf
  /// reading "Swift / Balanced / Deep" inside a Turkish UI would be the only
  /// untranslated text in the app that is not a proper noun.
  ///
  /// Falls back to the raw label for a brain added to the catalog without a
  /// matching string — visible, English, and obviously a gap, which is what a
  /// fallback should be.
  String _tierName(AppLocalizations l10n, BrainSpec brain) =>
      switch (brain.id) {
        'qwen3-1.7b-int4' => l10n.veraBrainTierSwift,
        'gemma-4-e2b' => l10n.veraBrainTierBalanced,
        'qwen3.5-4b-int4' => l10n.veraBrainTierDeep,
        _ => brain.label,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final active = _active;

    return CompanionPage(
      // Lowercase with a full stop, matching `language.` and every other
      // settings detail screen. A name is still a name in lower case.
      title: '${_companion.displayName.toLowerCase()}.',
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
        CompanionSectionLabel(l10n.veraBrainsSection),
        Padding(
          padding: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
          child: Text(
            l10n.veraBrainsCaption,
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
        ),
        for (final brain in BrainCatalog.veraBrains)
          BrainRow(
            brain: brain,
            name: _tierName(l10n, brain),
            // The one place in the app that admits what the brain really is.
            // Small type, under a human-readable tier, for the reader who
            // came looking — see the note at the top of
            // [showCompanionInstallSheet] for why it is nowhere else.
            detail: '${brain.sizeLabel} · ${brain.technicalName} · ${brain.license}',
            selected: active?.id == brain.id,
            onSelect: () => SettingsStore.instance.setVeraBrainId(brain.id),
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
              l10n.veraSkillsComingSoon,
              style: theme.caption.copyWith(color: theme.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
