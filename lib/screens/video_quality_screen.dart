import 'package:flutter/material.dart';

import '../calls/call_models.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// Resolution ceiling for outgoing video, on both the 1:1 and group call
/// paths. See [SettingsStore.videoQualityTier] / `videoQualityPresets` for
/// what each tier actually negotiates.
class VideoQualityScreen extends StatefulWidget {
  const VideoQualityScreen({super.key});

  @override
  State<VideoQualityScreen> createState() => _VideoQualityScreenState();
}

class _VideoQualityScreenState extends State<VideoQualityScreen> {
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

  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _set(VideoQualityTier v) =>
      SettingsStore.instance.setVideoQualityTier(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final current = SettingsStore.instance.videoQualityTier;
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
                  Text(
                    l10n.videoQualityScreenTitle,
                    style: theme.displayMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 18, height: 1, color: theme.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.videoQualityScreenSubtitle,
                          style: theme.caption,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _QualityRow(
                    label: l10n.settingsScreenValueVideoQualityAuto,
                    sub: l10n.videoQualityScreenAutoSubtitle,
                    active: current == VideoQualityTier.auto,
                    onTap: () => _set(VideoQualityTier.auto),
                  ),
                  const SizedBox(height: 10),
                  _QualityRow(
                    label: l10n.settingsScreenValueVideoQuality1080p,
                    sub: l10n.videoQualityScreenHd1080Subtitle,
                    active: current == VideoQualityTier.hd1080,
                    onTap: () => _set(VideoQualityTier.hd1080),
                  ),
                  const SizedBox(height: 10),
                  _QualityRow(
                    label: l10n.settingsScreenValueVideoQuality4k,
                    sub: l10n.videoQualityScreenUhd4kSubtitle,
                    active: current == VideoQualityTier.uhd4k,
                    onTap: () => _set(VideoQualityTier.uhd4k),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.videoQualityScreenFootnote,
                    style: theme.monoTiny.copyWith(color: theme.inkMuted),
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

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.label,
    required this.sub,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      selected: active,
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
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
                    const SizedBox(height: 4),
                    Text(sub, style: theme.monoTiny),
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
                      l10n.pinnedBannerActiveBadge,
                      style: theme.monoTiny.copyWith(color: theme.accent),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
