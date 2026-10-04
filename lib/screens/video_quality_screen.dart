import 'package:flutter/material.dart';

import '../calls/call_models.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';

/// Resolution ceiling for outgoing video, on both the 1:1 and group call
/// paths. See [SettingsStore.videoQualityTier] / `videoQualityPresets` for
/// what each tier actually negotiates.
class VideoQualityScreen extends StatelessWidget {
  const VideoQualityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final current = SettingsStore.instance.videoQualityTier;
        GroupedRow option(VideoQualityTier tier, String title, String sub) =>
            GroupedRow.choice(
              title: title,
              subtitle: sub,
              selected: current == tier,
              onTap: () {
                pickFeedback();
                SettingsStore.instance.setVideoQualityTier(tier);
              },
            );
        // The explanation is a sentence, so it sits under the large title as
        // the page's subtitle — set as a 17pt section header it wrapped to
        // two bold lines.
        return IosPage(
          title: l10n.videoQualityScreenTitle,
          subtitle: l10n.videoQualityScreenSubtitle,
          children: [
            GroupedSection(
              footer: l10n.videoQualityScreenFootnote,
              children: [
                option(
                  VideoQualityTier.auto,
                  l10n.settingsScreenValueVideoQualityAuto,
                  l10n.videoQualityScreenAutoSubtitle,
                ),
                option(
                  VideoQualityTier.hd1080,
                  l10n.settingsScreenValueVideoQuality1080p,
                  l10n.videoQualityScreenHd1080Subtitle,
                ),
                option(
                  VideoQualityTier.uhd4k,
                  l10n.settingsScreenValueVideoQuality4k,
                  l10n.videoQualityScreenUhd4kSubtitle,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
