import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_icon_picker.dart';
import '../widgets/ios_kit.dart';

/// Settings › App Icon: the same home-screen grid the first-run icon step
/// shows, so the icon picked on day one is found in exactly the same place
/// later.
///
/// A tap applies at once — the header mark re-renders and the launcher icon
/// swaps (on iOS with the system's own notice) — there is no save step.
class LogoScreen extends StatelessWidget {
  const LogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final footnote = theme.caption.copyWith(
      fontSize: 13,
      height: 1.35,
      color: theme.inkMuted,
    );
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final store = SettingsStore.instance;
        return IosPage(
          title: l10n.appIconScreenTitle,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            AppIconPicker(
              selected: currentIconChoice(store),
              onSelect: (id) => applyIconChoice(store, id),
            ),
            const SizedBox(height: 22),
            Text(l10n.appIconMatchFooter, style: footnote),
            if (ios) ...[
              const SizedBox(height: 8),
              Text(l10n.onboardingIconIosNote, style: footnote),
            ],
          ],
        );
      },
    );
  }
}
