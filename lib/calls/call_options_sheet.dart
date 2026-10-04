import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
import 'call_models.dart';

export 'call_models.dart' show CallOptionsController;

/// In-call counterpart to the Settings screen's Calls section — the same
/// two settings ([SettingsStore.showNetworkStats],
/// [SettingsStore.videoQualityTier]), reachable from inside the call
/// itself via the control bar's tune icon, so neither has to be a
/// Settings-only affordance. Both write straight to [SettingsStore]; the
/// video-quality row additionally applies live via
/// [CallOptionsController.switchVideoQuality] when a camera is already being
/// sent — the 1:1 call and the group call each implement it, so this one
/// sheet is "More" in both trays.
class CallOptionsSheet extends StatelessWidget {
  const CallOptionsSheet({
    super.key,
    required this.service,
    required this.showVideoQuality,
  });

  /// The call to apply a tier change to — a `CallService` or a
  /// `GroupCallService`.
  final CallOptionsController service;

  /// False for a voice call — there's no video to size, so the row is
  /// omitted rather than shown disabled.
  final bool showVideoQuality;

  @override
  Widget build(BuildContext context) {
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
                GroupedHeader(l10n.settingsScreenRowVideoQuality),
                // Three exclusive tiers: the shared segmented control, the
                // iOS shape for one choice among a few, in place of chips.
                IosSegmentedControl<VideoQualityTier>(
                  value: quality,
                  onChanged: (t) {
                    if (t == quality) return;
                    service.switchVideoQuality(t);
                  },
                  segments: [
                    IosSegment(
                      value: VideoQualityTier.auto,
                      label: l10n.settingsScreenValueVideoQualityAuto,
                    ),
                    IosSegment(
                      value: VideoQualityTier.hd1080,
                      label: l10n.settingsScreenValueVideoQuality1080p,
                    ),
                    IosSegment(
                      value: VideoQualityTier.uhd4k,
                      label: l10n.settingsScreenValueVideoQuality4k,
                    ),
                  ],
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
