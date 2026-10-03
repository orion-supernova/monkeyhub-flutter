import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import 'call_models.dart';
import 'call_service.dart';
import '../l10n/text_case.dart';

/// In-call counterpart to the Settings screen's Calls section — the same
/// two settings ([SettingsStore.showNetworkStats],
/// [SettingsStore.videoQualityTier]), reachable from inside the call
/// itself via the control bar's tune icon, so neither has to be a
/// Settings-only affordance. Both write straight to [SettingsStore]; the
/// video-quality row additionally applies live via
/// [CallService.switchVideoQuality] when a video call is already underway.
class CallOptionsSheet extends StatelessWidget {
  const CallOptionsSheet({
    super.key,
    required this.service,
    required this.showVideoQuality,
  });

  final CallService service;

  /// False for a voice call — there's no video to size, so the row is
  /// omitted rather than shown disabled.
  final bool showVideoQuality;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final store = SettingsStore.instance;
        // The decoration reaches the bottom edge; the home-indicator inset
        // is padding INSIDE it. A SafeArea outside the decorated box left a
        // transparent band under the sheet.
        final quality = store.videoQualityTier;
        return SheetFrame(
          title: l10n.callOptionsSheetTitle,
          leading: const SheetCloseButton(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetGroup(
                children: [
                  GroupedRow.toggle(
                    icon: CupertinoIcons.speedometer,
                    tone: TileTone.teal,
                    title: l10n.settingsHubCallStats,
                    subtitle: l10n.settingsHubCallStatsSubtitle,
                    value: store.showNetworkStats,
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      store.setShowNetworkStats(v);
                    },
                  ),
                ],
              ),
              if (showVideoQuality) ...[
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
                  child: Text(
                    sentenceCaseOf(context, l10n.settingsScreenRowVideoQuality),
                    style: theme.bodySoft.copyWith(
                      fontSize: 13,
                      color: theme.inkMuted,
                    ),
                  ),
                ),
                // Three exclusive tiers: a segmented control, the iOS shape
                // for one choice among a few, in place of three chips.
                SizedBox(
                  width: double.infinity,
                  child: CupertinoSlidingSegmentedControl<VideoQualityTier>(
                    groupValue: quality,
                    backgroundColor: theme.ink.withValues(alpha: 0.08),
                    thumbColor: theme.isLight
                        ? Colors.white
                        : Color.alphaBlend(
                            theme.ink.withValues(alpha: 0.12),
                            theme.surfaceRaised,
                          ),
                    onValueChanged: (t) {
                      if (t == null || t == quality) return;
                      HapticFeedback.selectionClick();
                      service.switchVideoQuality(t);
                    },
                    children: {
                      for (final (t, label) in [
                        (
                          VideoQualityTier.auto,
                          l10n.settingsScreenValueVideoQualityAuto,
                        ),
                        (
                          VideoQualityTier.hd1080,
                          l10n.settingsScreenValueVideoQuality1080p,
                        ),
                        (
                          VideoQualityTier.uhd4k,
                          l10n.settingsScreenValueVideoQuality4k,
                        ),
                      ])
                        t: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            sentenceCaseOf(context, label),
                            maxLines: 1,
                            style: theme.body.copyWith(
                              fontSize: 14,
                              fontWeight: quality == t
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: quality == t ? theme.ink : theme.inkSoft,
                            ),
                          ),
                        ),
                    },
                  ),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
