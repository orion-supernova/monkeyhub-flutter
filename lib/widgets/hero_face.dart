import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'account_kit.dart' show AvatarPop;
import 'hero_dock.dart';
import 'photo_chrome.dart';
import 'remote_image.dart';
import 'spring_press.dart';
import 'steady_hero.dart';

/// The circle at the head of a [HeroPage]: a person's profile, a DM's info, a
/// group's info. One widget so the three cannot drift: they had each grown
/// their own copy, with different badges, spinners and tap rules.
///
/// What differs between them is passed in, nothing else: the picture
/// ([face]), what a tap on it does ([onTap]), and whether there is a camera
/// badge ([onBadge]). The circle docks into the bar as the page scrolls
/// ([HeroDockAvatar]), pops in once ([AvatarPop]), and flies to the
/// fullscreen viewer when [heroTag] is set.
class HeroFace extends StatelessWidget {
  const HeroFace({
    super.key,
    required this.face,
    this.size = kHeroFaceSize,
    this.heroTag,
    this.onTap,
    this.tapLabel,
    this.onBadge,
    this.badgeLabel,
    this.busy = false,
  });

  /// The picture, drawn at [size] (a [UserAvatar], a room's photo, a monogram).
  final Widget face;
  final double size;

  /// Set when [face] is a real picture that can open full screen: the circle
  /// becomes the flight's source. Null for a lettered placeholder, which has
  /// nothing to fly to.
  final Object? heroTag;

  /// A tap on the circle. Null takes no tap.
  final VoidCallback? onTap;
  final String? tapLabel;

  /// The camera badge at the bottom right, for whoever may change the picture.
  /// Null draws no badge. It and the circle may well do the same thing (your
  /// own profile): two ways in, one sheet.
  final VoidCallback? onBadge;
  final String? badgeLabel;

  /// A new picture is on its way: a dim and a spinner over the circle.
  final bool busy;

  /// How far the badge hangs past the circle.
  static const double badgeOverhang = 2;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hasBadge = onBadge != null;
    final extent = hasBadge ? size + badgeOverhang : size;
    final tag = heroTag;
    Widget circle = tag == null ? face : SteadyHero(tag: tag, child: face);
    if (onTap != null) {
      circle = FocusableTap(
        onTap: onTap,
        shape: FocusRingShape.circle,
        semanticLabel: tapLabel,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: circle,
        ),
      );
    }
    // Sized to the overhang rather than the circle: RenderBox.hitTest bails
    // before descending when the point is outside `size`, and Clip.none only
    // affects painting, so a badge hanging out of a circle-sized box could be
    // seen and not tapped.
    return HeroDockAvatar(
      diameter: size,
      extent: extent,
      child: AvatarPop(
        child: SizedBox.square(
          dimension: extent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(left: 0, top: 0, width: size, height: size, child: circle),
              if (busy)
                Positioned(
                  left: 0,
                  top: 0,
                  width: size,
                  height: size,
                  // Never swallows a tap meant for the badge.
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      child: Center(
                        child: PhotoSpinner(
                          size: 26,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasBadge)
                Positioned(
                  right: 0,
                  bottom: 0,
                  // Fades as the circle starts for the bar: a badge shrunk to
                  // a speck would be a target nobody can hit.
                  child: HeroDockFade(
                    child: SpringPress(
                      onTap: busy ? null : onBadge,
                      semanticLabel: badgeLabel,
                      focusShape: FocusRingShape.circle,
                      scale: 0.88,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.background, width: 3),
                        ),
                        child: Icon(
                          CupertinoIcons.camera_fill,
                          size: 14,
                          color: theme.accentInk,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hero circle's diameter on every page that has one.
const double kHeroFaceSize = 104;

/// [HeroPage.expandedPhoto] for a picture in storage: pulling the page down
/// grows the circle into it, full width. Null when there is no real picture
/// ([storageId] null or empty), which keeps the plain rubber band.
Widget Function(BuildContext, Size)? heroPullPhoto({
  required String? storageId,
  required ChatApi? api,
  double size = kHeroFaceSize,
}) {
  final id = storageId;
  if (id == null || id.isEmpty || api == null) return null;
  return (context, box) => RemoteImage(
        storageId: id,
        api: api,
        width: box.width,
        height: box.height,
        placeholderDecodeWidth:
            (size * MediaQuery.devicePixelRatioOf(context)).round(),
      );
}
