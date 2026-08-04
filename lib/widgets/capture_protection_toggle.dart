import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../privacy/capture_protection.dart';
import '../theme/theme_scope.dart';

class CaptureProtectionToggle extends StatefulWidget {
  const CaptureProtectionToggle({super.key});

  @override
  State<CaptureProtectionToggle> createState() => _CaptureProtectionToggleState();
}

class _CaptureProtectionToggleState extends State<CaptureProtectionToggle> {
  Future<void> _toggle(bool v) async {
    await SettingsStore.instance.setCaptureProtection(v);
    await CaptureProtection.instance.setUserEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final on = SettingsStore.instance.captureProtection;
        return GestureDetector(
          onTap: () => _toggle(!on),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  on ? Icons.shield_outlined : Icons.shield_moon_outlined,
                  size: 16,
                  color: on ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).countBadgeCaptureProtectionLabel,
                        style: theme.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        on
                            ? (!kIsWeb && Platform.isAndroid)
                                ? AppLocalizations.of(context).countBadgeCaptureProtectionOnAndroidBody
                                : AppLocalizations.of(context).countBadgeCaptureProtectionOnIosBody
                            : AppLocalizations.of(context).countBadgeCaptureProtectionOffBody,
                        style: theme.bodySoft,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).countBadgeCaptureProtectionForcedNote,
                        style: theme.bodySoft.copyWith(color: theme.accent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: on,
                  onChanged: _toggle,
                  activeThumbColor: theme.accent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
