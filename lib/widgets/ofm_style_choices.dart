import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import 'ios_kit.dart';
import 'settings_pickers.dart' show pickFeedback;

/// How OpenFreeMap maps look: one row per style, the chosen one ticked.
/// Shared by the full-screen map's settings sheet and Settings › Maps.
class OfmStyleChoices extends StatelessWidget {
  const OfmStyleChoices({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = SettingsStore.instance;
    String label(OfmStyle s) => switch (s) {
      OfmStyle.liberty => l.ofmStyleLiberty,
      OfmStyle.bright => l.ofmStyleBright,
      OfmStyle.positron => l.ofmStylePositron,
      OfmStyle.dark => l.ofmStyleDark,
      OfmStyle.fiord => l.ofmStyleFiord,
    };
    TileTone tone(OfmStyle s) => switch (s) {
      OfmStyle.liberty => TileTone.green,
      OfmStyle.bright => TileTone.orange,
      OfmStyle.positron => TileTone.gray,
      OfmStyle.dark => TileTone.indigo,
      OfmStyle.fiord => TileTone.blue,
    };
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => GroupedSection(
        header: l.mapOfmStyleHeader,
        children: [
          for (final s in OfmStyle.values)
            GroupedRow.choice(
              icon: CupertinoIcons.map_fill,
              tone: tone(s),
              title: label(s),
              selected: store.ofmStyle == s,
              onTap: () {
                pickFeedback();
                store.setOfmStyle(s);
              },
            ),
        ],
      ),
    );
  }
}
