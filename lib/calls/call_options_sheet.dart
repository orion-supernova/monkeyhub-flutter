import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'call_models.dart';
import 'call_service.dart';

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
        return SafeArea(
          child: Container(
            decoration: theme.sheetDecoration(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.callOptionsSheetTitle,
                  style: theme.displaySmall,
                ),
                const SizedBox(height: 14),
                _OptionRow(
                  icon: Icons.speed_outlined,
                  label: l10n.settingsScreenShowNetworkStatsLabel,
                  sub: l10n.settingsScreenShowNetworkStatsBody,
                  trailing: Switch.adaptive(
                    value: store.showNetworkStats,
                    onChanged: (v) => store.setShowNetworkStats(v),
                    activeThumbColor: theme.accent,
                  ),
                ),
                if (showVideoQuality) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.settingsScreenRowVideoQuality,
                    style: theme.label,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QualityChip(
                        label: l10n.settingsScreenValueVideoQualityAuto,
                        selected:
                            store.videoQualityTier == VideoQualityTier.auto,
                        onTap: () =>
                            service.switchVideoQuality(VideoQualityTier.auto),
                      ),
                      _QualityChip(
                        label: l10n.settingsScreenValueVideoQuality1080p,
                        selected: store.videoQualityTier ==
                            VideoQualityTier.hd1080,
                        onTap: () => service
                            .switchVideoQuality(VideoQualityTier.hd1080),
                      ),
                      _QualityChip(
                        label: l10n.settingsScreenValueVideoQuality4k,
                        selected:
                            store.videoQualityTier == VideoQualityTier.uhd4k,
                        onTap: () =>
                            service.switchVideoQuality(VideoQualityTier.uhd4k),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final String sub;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.inkSoft),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.label),
              const SizedBox(height: 2),
              Text(sub, style: theme.bodySoft),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    );
  }
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.capsule,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? theme.accent : theme.ink.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.monoTiny.copyWith(
              color: selected ? theme.background : theme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
