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

import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
import '../../widgets/account_kit.dart' show SoftNote;
import '../../widgets/ios_kit.dart';
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
      // The companion's own name as the large title, the way a Contacts card
      // is titled by the person.
      title: _companion.displayName,
      subtitle: _companion.tagline(l10n),
      children: [
        const CompanionPortrait(companion: _companion),
        const SizedBox(height: 24),

        if (!available)
          SoftNote(
            icon: CupertinoIcons.info_circle,
            text: l10n.companionUnsupportedPlatform,
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
          GroupedSection(header: l10n.compStorage, children: _shelf(l10n)),
        ] else ...[
          // Grouped blocks throughout, like every settings page — the
          // switch, the languages and the shelf were bordered cards of
          // their own (thirty of them for the languages).
          GroupedSection(
            header: l10n.compGeneral,
            children: [
              GroupedRow.toggle(
                title: l10n.sebastianEnableLabel,
                subtitle: l10n.sebastianEnableDetail,
                value: _sebastian.isEnabled,
                onChanged: (v) {
                  // The tap a native switch gives.
                  HapticFeedback.lightImpact();
                  _setEnabled(v);
                },
              ),
            ],
          ),
          _LanguagePicker(
            current: SettingsStore.instance.translationTarget,
            resolved: _sebastian.targetLanguage,
            // Which brain is actually going to be asked, so the picker can
            // admit where it is out of its depth.
            brain: _sebastian.brain,
            onPick: _setLanguage,
          ),
          GroupedSection(
            header: l10n.compStorage,
            margin: const EdgeInsets.only(bottom: 4),
            children: _shelf(l10n),
          ),
          _CacheLine(theme: theme, l10n: l10n, onCleared: _onChange),
        ],
      ],
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
    final l10n = AppLocalizations.of(context);
    // One grouped block of choice rows — the flag leads the autonym as a
    // landmark, the check marks the pick. Not routed through the language
    // screen's own rows: these carry a per-brain warning.
    return GroupedSection(
      header: l10n.compTranslateInto,
      children: [
        GroupedRow.choice(
          title: '${resolved.flag}  ${l10n.sebastianLanguageFollowApp}',
          subtitle: resolved.autonym,
          selected: current == null,
          onTap: () => onPick(null),
        ),
        for (final lang in kTranslationLanguages)
          GroupedRow.choice(
            title: '${lang.flag}  ${lang.autonym}',
            // Named, not hidden. A language this brain does not publish is
            // still offered — see [BrainSpec.languages] for why removing it
            // would be the worse regression — but somebody choosing it is
            // entitled to know before they wonder why the results read oddly.
            subtitle: brain.covers(lang.code)
                ? null
                : l10n.sebastianLanguageUnlisted,
            selected: current == lang.code,
            onTap: () => onPick(lang.code),
          ),
      ],
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
    // A footer under the shelf: the count in footer type, the shared text
    // action to drop it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.sebastianCacheCount(count),
              style: groupedFooterStyle(theme),
            ),
          ),
          TextLinkButton(
            label: l10n.sebastianCacheClear,
            fontSize: 15,
            onTap: () async {
              await TranslationCache.instance.clear();
              await Sebastian.instance.reset();
              if (mounted) setState(() {});
              widget.onCleared();
            },
          ),
        ],
      ),
    );
  }
}
