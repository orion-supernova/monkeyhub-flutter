import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;
import 'spring_press.dart';

/// The one big button on a first-run or sign-in screen: a full-width accent
/// capsule with sentence-case text, the iOS 26 `.glassProminent` shape.
///
/// No glow and no letter-spaced capitals — the old buttons shouted. It springs
/// on press, and while [busy] it trades its label for a spinner without
/// changing size, so nothing under it moves.
class ProminentButton extends StatelessWidget {
  const ProminentButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null && !busy;
    // Disabled is a neutral capsule with muted text, iOS-style — never a
    // washed-out accent, which on a dark page is a navy slab.
    final disabled = onTap == null;
    final fill = disabled ? quietFill(theme) : theme.accent;
    final ink = disabled ? theme.inkMuted : theme.accentInk;
    return SpringPress(
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              onTap!();
            }
          : null,
      // Its own, heavier haptic above: the one big commit on the screen.
      haptic: false,
      scale: 0.97,
      semanticLabel: label,
      focusShape: FocusRingShape.capsule,
      focusRadius: 999,
      child: AnimatedContainer(
        duration: theme.motionFast,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          // A hairline of light along the top edge, the lit rim glass
          // buttons have, rather than a coloured glow underneath.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(fill, Colors.white, 0.10)!,
              fill,
            ],
          ),
        ),
        child: busy
            ? CupertinoActivityIndicator(color: ink)
            : Text(
                label,
                style: theme.bodyEmph.copyWith(
                  fontSize: 17,
                  color: ink,
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }
}
