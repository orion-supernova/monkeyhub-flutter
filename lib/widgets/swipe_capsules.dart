import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

/// One button revealed by a swipe: a chat row's Pin / Mute / Archive, or the
/// swipe-up fork's Vanish / Talk.
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// The iOS 26 capsule a swipe reveals: a rounded, coloured button with its
/// icon over its label, whose contents fade in as it grows.
///
/// ONE implementation, shared by the chat list's row swipe (capsules growing
/// sideways out of the row's edge) and the chat's swipe-up (capsules growing
/// upward out of the composer's edge). It paints into whatever box it is
/// given, so the caller owns the axis it grows along and passes [extent], the
/// size along that axis, which drives the fade-in and the label.
class SwipeCapsule extends StatelessWidget {
  const SwipeCapsule({
    super.key,
    required this.action,
    required this.extent,
    required this.onTap,
    this.maxRadius = 18,
  });

  final SwipeAction action;

  /// How far the capsule has grown along its growth axis, in points. The icon
  /// fades in over 28 to 58 and the label joins past 56.
  final double extent;

  final ValueChanged<SwipeAction> onTap;

  /// The corner radius ceiling; a capsule too small for it is fully round.
  final double maxRadius;

  /// The radius a capsule [extent] points long wears.
  static double radiusFor(double extent, {double maxRadius = 18}) =>
      math.min(maxRadius, extent / 2);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final w = extent;
    final radius = radiusFor(w, maxRadius: maxRadius);
    return FocusableTap(
      onTap: () => onTap(action),
      semanticLabel: action.label,
      radius: radius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(action),
        child: Container(
          decoration: BoxDecoration(
            color: action.color,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              child: Opacity(
                opacity: ((w - 28) / 30).clamp(0.0, 1.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(action.icon, size: 20, color: Colors.white),
                    if (w > 56) ...[
                      const SizedBox(height: 3),
                      Text(
                        action.label,
                        maxLines: 1,
                        // 13 on the body face: the caption slot is tracked
                        // mono on character themes.
                        style: theme.bodySoft.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
