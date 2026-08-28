import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// Picker for the app's display language. Mirrors the other settings
/// picker screens (see reply_style_screen.dart): a lowercase display
/// heading, a caption, and a stack of selectable cards.
///
/// [SettingsStore.localeCode] is null for "follow the system language" —
/// picking English or Turkish here pins the app regardless of the device,
/// which matters on a shared family handset where members read different
/// languages.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    SettingsStore.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _set(String? code) => SettingsStore.instance.setLocaleCode(code);

  /// (locale code, autonym) for every language the app ships, in the order
  /// shown below the SYSTEM card. `null` is reserved for SYSTEM itself, so
  /// it's never a key here. Codes match SettingsStore.localeCode /
  /// AppLocalizations.supportedLocales exactly, including the region suffix
  /// on 'pt_BR' — see app.dart's locale-parsing comment for why that one
  /// needs a region.
  // RTL layout (Arabic) and CJK/Arabic/Devanagari font glyph coverage
  // (bundled fonts are Latin-subset, so ar/zh/hi/ko/ja fall back to system
  // fonts) haven't had their own visual verification pass yet — content is
  // complete and correct, but worth a look before leaning on them hard.
  List<(String, String)> _languages(AppLocalizations l10n) => [
    ('en', l10n.languageOptionEnglish),
    ('tr', l10n.languageOptionTurkish),
    ('es', l10n.languageOptionSpanish),
    ('fr', l10n.languageOptionFrench),
    ('pt', l10n.languageOptionPortuguese),
    ('pt_BR', l10n.languageOptionPortugueseBrazil),
    ('sv', l10n.languageOptionSwedish),
    ('ar', l10n.languageOptionArabic),
    ('zh', l10n.languageOptionChinese),
    ('hi', l10n.languageOptionHindi),
    ('ko', l10n.languageOptionKorean),
    ('ja', l10n.languageOptionJapanese),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = SettingsStore.instance.localeCode;
    final languages = _languages(l10n);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  14,
                  20,
                  edgeToEdgeBottom(context, 40),
                ),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.inkSoft,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.languageScreenTitle, style: theme.displayMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 18, height: 1, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.languageScreenSubtitle,
                          style: theme.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _LanguageCard(
                    label: l10n.languageOptionSystem,
                    sub: l10n.languageOptionSystemSub,
                    active: current == null,
                    activeLabel: l10n.languageScreenActiveBadge,
                    onTap: () => _set(null),
                  ),
                  for (final (code, label) in languages) ...[
                    const SizedBox(height: 14),
                    _LanguageCard(
                      label: label,
                      sub: null,
                      active: current == code,
                      activeLabel: l10n.languageScreenActiveBadge,
                      onTap: () => _set(code),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.sub,
    required this.active,
    required this.activeLabel,
    required this.onTap,
  });
  final String label;
  final String? sub;
  final bool active;
  final String activeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(
            color: active ? theme.accent : theme.divider,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.25),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.label),
                  if (sub != null) ...[
                    const SizedBox(height: 6),
                    Text(sub!, style: theme.monoTiny),
                  ],
                ],
              ),
            ),
            if (active)
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    activeLabel,
                    style: theme.monoTiny.copyWith(color: theme.accent),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
