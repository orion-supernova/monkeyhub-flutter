import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../privacy/capture_protection.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show groupedRadius;
import 'sheet_kit.dart' show sentenceCaseOf;

/// Renders a full-screen blur shield when screen capture is detected AND
/// the user has enabled protection. iOS only — Android handles capture
/// blocking at the OS level via FLAG_SECURE, so this widget short-circuits
/// to nothing on Android.
class CaptureShield extends StatelessWidget {
  const CaptureShield({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CaptureProtection.instance,
      builder: (context, _) {
        final cp = CaptureProtection.instance;
        if (!cp.active || !cp.isBeingCaptured) {
          return const SizedBox.shrink();
        }
        final theme = ThemeScope.of(context);
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      // An iOS alert platter: raised fill, generous corners,
                      // no outline.
                      decoration: BoxDecoration(
                        color: theme.surfaceRaised,
                        borderRadius: BorderRadius.circular(groupedRadius(theme)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.eye_slash_fill,
                              size: 32, color: theme.accent),
                          const SizedBox(height: 12),
                          Text(
                            sentenceCaseOf(
                              context,
                              AppLocalizations.of(context).countBadgeProtectedLabel,
                            ),
                            style: theme.bodyEmph.copyWith(color: theme.ink),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context).countBadgeCaptureShieldActiveBody,
                            style: theme.bodySoft,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.of(context).countBadgeCaptureShieldReassurance,
                            style: theme.bodySoft.copyWith(
                              fontSize: 13,
                              color: theme.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
