import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';

/// Picker for the app's display language: the device's language first, then
/// every language the app ships, as one checked list — iOS's own Language
/// page.
///
/// [SettingsStore.localeCode] is null for "follow the system language" —
/// picking English or Turkish here pins the app regardless of the device,
/// which matters on a shared family handset where members read different
/// languages.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  /// (locale code, autonym) for every language the app ships. Each name is
  /// written in its own language, the way iOS lists them — someone looking for
  /// their language reads it in their language.
  static List<(String, String)> _languages(AppLocalizations l10n) => [
        ('en', l10n.languageValueEnglish),
        ('tr', l10n.languageValueTurkish),
        ('es', l10n.languageValueSpanish),
        ('fr', l10n.languageValueFrench),
        ('pt', l10n.languageValuePortuguese),
        ('pt_BR', l10n.languageValuePortugueseBrazil),
        ('sv', l10n.languageValueSwedish),
        ('ar', l10n.languageValueArabic),
        ('zh', l10n.languageValueChinese),
        ('hi', l10n.languageValueHindi),
        ('ko', l10n.languageValueKorean),
        ('ja', l10n.languageValueJapanese),
      ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final current = SettingsStore.instance.localeCode;
        void set(String? code) {
          pickFeedback();
          SettingsStore.instance.setLocaleCode(code);
        }

        return SettingsPage(
          title: l10n.settingsHubLanguage,
          children: [
            GroupedSection(
              children: [
                GroupedRow.choice(
                  title: l10n.languageSystemLabel,
                  selected: current == null,
                  onTap: () => set(null),
                ),
              ],
            ),
            GroupedSection(
              footer: l10n.languagePageFooter,
              children: [
                for (final (code, name) in _languages(l10n))
                  GroupedRow.choice(
                    title: name,
                    selected: current == code,
                    onTap: () => set(code),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
