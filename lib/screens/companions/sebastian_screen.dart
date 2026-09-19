/// Settings › Companions › Sebastian.
///
/// Four things, in the order somebody needs them: is he here, is he on, what
/// language does he work into, and how do I get rid of him.
///
/// Conspicuously absent: any way to choose what he thinks with. That is the
/// decision this design does not hand over — see
/// [Companion.brainsAreUserChosen]. The single mention of the machinery is a
/// storage figure, because disk is the one cost the user is genuinely
/// entitled to see.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../companions/brain_manager.dart';
import '../../companions/brain_spec.dart';
import '../../companions/companion.dart';
import '../../companions/sebastian.dart';
import '../../companions/translation/language.dart';
import '../../companions/translation/translation_cache.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/companion_install_sheet.dart';
import '../../widgets/destructive_sheet.dart';
import 'companion_page.dart';

class SebastianScreen extends StatefulWidget {
  const SebastianScreen({super.key});

  @override
  State<SebastianScreen> createState() => _SebastianScreenState();
}

class _SebastianScreenState extends State<SebastianScreen> {
  static const _companion = Companion.sebastian;

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

  Sebastian get _sebastian => Sebastian.instance;

  Future<void> _setEnabled(bool on) async {
    await SettingsStore.instance.setSebastianEnabled(on);
    if (!on) {
      // Switching him off has to actually stop him: drop the queue, drop the
      // handles, and give back the several hundred megabytes of resident
      // weights. A toggle that only changed what a getter returns would leave
      // a translation finishing into a bubble nobody is watching.
      await _sebastian.reset();
    }
  }

  Future<void> _setLanguage(String? code) async {
    await SettingsStore.instance.setTranslationTarget(code);
    // Every handle is keyed by the OLD target language and will never be read
    // again; every queued job is aimed at it. Clearing both is not an
    // optimisation, it is the difference between changing the setting and
    // changing what is on screen.
    await _sebastian.reset();
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    // The guard Marlowe's screen has always had, which this one was missing —
    // deleting from here used to be able to take a brain another companion
    // was set to think with, silently. See [otherCompanionsUsing].
    final shared = otherCompanionsUsing(_sebastian.brain, _companion);
    final confirmed = await showConfirmSheet(
      context,
      headline: l10n.companionRemoveTitle(_companion.displayName),
      body: shared.isEmpty
          ? l10n.companionRemoveMessage(_sebastian.brain.sizeLabel)
          : '${l10n.companionRemoveMessage(_sebastian.brain.sizeLabel)} '
              '${l10n.companionBrainSharedWarning(shared.first.displayName)}',
      confirmLabel: l10n.companionRemoveConfirm,
    );
    if (!confirmed || !mounted) return;
    await BrainManager.instance.uninstall(_sebastian.brain);
    await _sebastian.reset(clearCache: true);
  }

  /// Both of his brains, including one this device cannot run.
  ///
  /// Still not a picker — see [Companion.brainsAreUserChosen]; there is nothing
  /// here to select and the device has already decided. It is a statement. A
  /// shelf that quietly omitted the bigger brain would leave somebody on the
  /// smaller one with no idea a better one exists or why they are not being
  /// offered it, which reads as the feature being worse than it is rather than
  /// as their phone being smaller than it needs. "Needs 4 GB of memory" is
  /// something a person can check against their own handset.
  ///
  /// Rendered whether or not anything is installed yet, which is the case that
  /// was missing: the person deciding whether to spend a gigabyte is the one
  /// who most needs to know there are two.
  List<Widget> _shelf(AppLocalizations l10n) => [
        for (final brain in BrainCatalog.sebastianBrains)
          BrainRow(
            brain: brain,
            name: sebastianTierName(brain),
            sharedWith: otherCompanionsUsing(brain, _companion),
            // Installed: where it is and what it costs. Otherwise: what this
            // one is FOR.
            //
            // Not the size — the download button beside it is already labelled
            // with exactly that, so printing it here put the same figure on the
            // row twice and told the reader nothing about the difference
            // between the two rows, which is the only thing they are being
            // shown two of them to understand.
            detail: BrainManager.instance.isInstalled(brain)
                ? l10n.sebastianBrainDetail(brain.sizeLabel)
                : (brain.id == BrainCatalog.sebastianFallback.id
                    ? l10n.sebastianTierJuniorDetail
                    : l10n.sebastianTierSeniorDetail),
            unavailableReason: brainUnavailableReason(brain, l10n),
            // Only the one he is actually running can be removed. Offering it
            // on a row with nothing behind it would be a button that cannot
            // work.
            onRemove: BrainManager.instance.isInstalled(brain) &&
                    brain.id == _sebastian.brain.id
                ? _remove
                : null,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final installed = _sebastian.isInstalled;
    final available = _sebastian.isAvailable;

    return CompanionPage(
      // Lowercase with a full stop, matching `language.` and every other
      // settings detail screen. A name is still a name in lower case.
      title: '${_companion.displayName.toLowerCase()}.',
      subtitle: _companion.tagline(l10n),
      children: [
        _Portrait(companion: _companion, theme: theme, l10n: l10n),
        const SizedBox(height: 24),

        if (!available)
          CompanionCard(
            children: [
              Text(
                l10n.companionUnsupportedPlatform,
                style: theme.body.copyWith(color: theme.inkSoft),
              ),
            ],
          )
        else if (!installed) ...[
          // The panel, NOT the sheet. This screen has already drawn the
          // portrait and the blurb directly above; opening the sheet here
          // showed the reader his name, his face and his three assurances a
          // second time, stacked on the first. See the header of
          // `companion_install_sheet.dart`.
          CompanionInstallPanel(
            companion: _companion,
            brain: _sebastian.brain,
          ),
          // The shelf sits under the panel here too, and this is where it
          // matters most: somebody deciding whether to spend a gigabyte is
          // exactly the person entitled to know there are two of him and which
          // one their phone can hold. The panel offers whichever one they are
          // getting; this says what the other is and why it is not on offer.
          const SizedBox(height: 24),
          CompanionSectionLabel(l10n.companionSectionStorage),
          ..._shelf(l10n),
        ] else ...[
          CompanionSectionLabel(l10n.companionSectionGeneral),
          CompanionCard(
            padding: EdgeInsets.zero,
            children: [
              _SwitchRow(
                theme: theme,
                label: l10n.sebastianEnableLabel,
                detail: l10n.sebastianEnableDetail,
                value: _sebastian.isEnabled,
                onChanged: _setEnabled,
              ),
            ],
          ),
          const SizedBox(height: 24),
          CompanionSectionLabel(l10n.sebastianLanguageSection),
          _LanguagePicker(
            current: SettingsStore.instance.translationTarget,
            resolved: _sebastian.targetLanguage,
            // Which brain is actually going to be asked, so the picker can
            // admit where it is out of its depth.
            brain: _sebastian.brain,
            onPick: _setLanguage,
          ),
          const SizedBox(height: 24),
          CompanionSectionLabel(l10n.companionSectionStorage),
          ..._shelf(l10n),
          _CacheLine(theme: theme, l10n: l10n, onCleared: _onChange),
        ],
      ],
    );
  }
}

/// The introduction: mark, name, and the longer pitch.
class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.companion,
    required this.theme,
    required this.l10n,
  });

  final Companion companion;
  final AppTheme theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
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
          child: Text(
            companion.blurb(l10n),
            style: theme.body.copyWith(color: theme.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.theme,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final AppTheme theme;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.body),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.caption.copyWith(color: theme.inkMuted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              // The tap a native switch gives; `Switch.adaptive` has none.
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            activeTrackColor: theme.accent,
          ),
        ],
      ),
    );
  }
}

/// Target-language picker.
///
/// Opens with a "follow the app" row, exactly like [LanguageScreen]'s SYSTEM
/// card and for the same reason: it is the right answer for most people, it is
/// the default, and making it a row rather than an absence means the state is
/// visible instead of inferred.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.current,
    required this.resolved,
    required this.brain,
    required this.onPick,
  });

  /// The brain that will actually be asked. Its publisher's language list is
  /// what decides whether a row carries a warning — see [BrainSpec.covers].
  final BrainSpec brain;

  /// The stored preference — null for "follow the app".
  final String? current;

  /// What that actually resolves to right now, for the follow-the-app row's
  /// subtitle.
  final TranslationLanguage resolved;

  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _LanguageRow(
          theme: theme,
          flag: resolved.flag,
          label: l10n.sebastianLanguageFollowApp,
          detail: resolved.autonym,
          selected: current == null,
          onTap: () => onPick(null),
        ),
        for (final lang in kTranslationLanguages)
          _LanguageRow(
            theme: theme,
            flag: lang.flag,
            label: lang.autonym,
            // Named, not hidden. A language this brain does not publish is
            // still offered — see [BrainSpec.languages] for why removing it
            // would be the worse regression — but somebody choosing it is
            // entitled to know before they wonder why the results read oddly.
            detail: brain.covers(lang.code)
                ? null
                : l10n.sebastianLanguageUnlisted,
            selected: current == lang.code,
            onTap: () => onPick(lang.code),
          ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.theme,
    required this.flag,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final AppTheme theme;

  /// A landmark, never the thing naming the language — see
  /// [TranslationLanguage.flag]. The autonym beside it does the identifying.
  final String flag;
  final String label;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: selected ? theme.accent.withValues(alpha: 0.12) : theme.surface,
          border: Border.all(
            color: selected ? theme.accent.withValues(alpha: 0.4) : theme.divider,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            // Fixed width so thirty rows of flags line up into a column the
            // eye can run down. Emoji vary in advance width, and ragged
            // landmarks are worse than no landmarks.
            SizedBox(
              width: 26,
              child: Text(flag, style: theme.body),
            ),
            Expanded(child: Text(label, style: theme.body)),
            if (detail != null) ...[
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  detail!,
                  style: theme.caption.copyWith(color: theme.inkMuted),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                ),
              ),
            ],
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check, size: 15, color: theme.accent),
            ],
          ],
        ),
      ),
    );
  }
}

/// How many translations are being kept, and the way to drop them.
///
/// Worth a row of its own because it is the only part of this feature that
/// accumulates over time without the user doing anything, and because "why
/// does this message translate instantly and that one doesn't" has an answer
/// that lives here.
class _CacheLine extends StatefulWidget {
  const _CacheLine({
    required this.theme,
    required this.l10n,
    required this.onCleared,
  });

  final AppTheme theme;
  final AppLocalizations l10n;
  final VoidCallback onCleared;

  @override
  State<_CacheLine> createState() => _CacheLineState();
}

class _CacheLineState extends State<_CacheLine> {
  @override
  void initState() {
    super.initState();
    TranslationCache.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l10n = widget.l10n;
    final count = TranslationCache.instance.count;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.sebastianCacheCount(count),
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await TranslationCache.instance.clear();
              await Sebastian.instance.reset();
              if (mounted) setState(() {});
              widget.onCleared();
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Text(
                l10n.sebastianCacheClear,
                style: theme.caption.copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
