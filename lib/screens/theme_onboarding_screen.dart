import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/sheet_buttons.dart';

/// The first thing a new install shows, before sign-in: how the app should
/// look.
///
/// Before the login screen rather than after it on purpose. The login screen is
/// the first screen with any character, and meeting it in a theme you would
/// never have picked — Midnight on a phone set to light mode, say — is a worse
/// first impression than one question asked first. It is also the only moment
/// the question is free: nothing is loaded, nobody is waiting.
///
/// Every choice is written straight to [SettingsStore], and the app re-themes
/// around it — so this screen IS the preview. Nothing here is applied later.
/// CONTINUE only records that the question has been answered; the defaults
/// (follow the device, Daylight by day and Midnight by night) are an answer
/// too, which is why there is no separate skip.
class ThemeOnboardingScreen extends StatelessWidget {
  const ThemeOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: AnimatedBuilder(
                animation: SettingsStore.instance,
                builder: (context, _) => _Body(theme: theme, l10n: l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.theme, required this.l10n});

  final AppTheme theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final store = SettingsStore.instance;
    final mode = store.appearanceMode;
    final all = ThemeController.all;
    final platform = MediaQuery.platformBrightnessOf(context);

    void setMode(AppearanceMode next) =>
        store.setAppearanceMode(next, current: theme.id);

    final content = <Widget>[
      const SizedBox(height: 28),
      Row(
        children: [
          theme.brandMark(size: 34),
          const Spacer(),
        ],
      ),
      const SizedBox(height: 22),
      Text(l10n.onboardingThemeTitle, style: theme.displayHero),
      const SizedBox(height: 10),
      Row(
        children: [
          Container(width: 18, height: 1, color: theme.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.onboardingThemeBody, style: theme.caption)),
        ],
      ),
      const SizedBox(height: 26),
      AppearanceModeSwitch(mode: mode, onChanged: setMode),
      const SizedBox(height: 26),
      AnimatedSwitcher(
        duration: theme.motionMed,
        switchInCurve: theme.motionEntrance,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SizeTransition(
            sizeFactor: anim,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: mode == AppearanceMode.system
            ? Column(
                key: const ValueKey('pair'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StripLabel(
                    icon: Icons.light_mode_outlined,
                    text: l10n.appearanceLightSlot,
                    now: platform == Brightness.light ? l10n.appearanceNow : null,
                  ),
                  ThemeStrip(
                    themes: [for (final t in all) if (t.isLight) t],
                    selectedId: store.lightThemeId,
                    onSelect: (t) =>
                        store.setSlotTheme(Brightness.light, t.id),
                  ),
                  const SizedBox(height: 18),
                  _StripLabel(
                    icon: Icons.dark_mode_outlined,
                    text: l10n.appearanceDarkSlot,
                    now: platform == Brightness.dark ? l10n.appearanceNow : null,
                  ),
                  ThemeStrip(
                    themes: [for (final t in all) if (!t.isLight) t],
                    selectedId: store.darkThemeId,
                    onSelect: (t) => store.setSlotTheme(Brightness.dark, t.id),
                  ),
                ],
              )
            : Column(
                key: const ValueKey('fixed'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StripLabel(
                    icon: Icons.palette_outlined,
                    text: l10n.onboardingThemeYourTheme,
                  ),
                  ThemeStrip(
                    themes: all,
                    selectedId: theme.id,
                    onSelect: (t) => store.setThemeId(t.id),
                  ),
                ],
              ),
      ),
      const SizedBox(height: 24),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: content,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, 8, 22, edgeToEdgeBottom(context, 18)),
          child: SheetPrimaryButton(
            label: l10n.onboardingThemeContinue,
            onTap: () {
              HapticFeedback.mediumImpact();
              store.markThemeOnboarded();
            },
          ),
        ),
      ],
    );
  }
}

class _StripLabel extends StatelessWidget {
  const _StripLabel({required this.icon, required this.text, this.now});

  final IconData icon;
  final String text;

  /// NOW, on the half of the pair the device is in.
  final String? now;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.inkSoft),
        const SizedBox(width: 6),
        Text(text, style: theme.label.copyWith(letterSpacing: 1.8)),
        if (now != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.accentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              now!,
              style: theme.monoTiny.copyWith(
                color: theme.accent,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ],
    );
  }
}
