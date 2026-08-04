import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = SettingsStore.instance.localeCode;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
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
                  const SizedBox(height: 14),
                  _LanguageCard(
                    label: l10n.languageOptionEnglish,
                    sub: null,
                    active: current == 'en',
                    activeLabel: l10n.languageScreenActiveBadge,
                    onTap: () => _set('en'),
                  ),
                  const SizedBox(height: 14),
                  _LanguageCard(
                    label: l10n.languageOptionTurkish,
                    sub: null,
                    active: current == 'tr',
                    activeLabel: l10n.languageScreenActiveBadge,
                    onTap: () => _set('tr'),
                  ),
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
