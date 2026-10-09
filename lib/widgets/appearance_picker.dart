import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show groupedMetaStyle, groupedTitleStyle;
import 'spring_press.dart';
import 'desktop_scroll.dart';

/// The pieces the first-launch picker and the theme screen are both built
/// from, so the two can never describe the same choice two different ways.

/// A theme, drawn as a tiny phone: its background, a header, two bubbles and a
/// composer, in its own colours.
///
/// Built from plain boxes rather than by mounting the real screens under a
/// nested [ThemeScope]: a strip of thirteen of these has to scroll at 120Hz,
/// and the one question it answers — what will this look like — is answered by
/// the palette and the shapes, not by the typography.
class ThemeMiniPreview extends StatelessWidget {
  const ThemeMiniPreview({
    super.key,
    required this.candidate,
    this.width = 92,
    this.selected = false,
    this.badge,
    this.onTap,
  });

  final AppTheme candidate;
  final double width;
  final bool selected;

  /// A small tag over the top edge — NOW, on the half of a light/dark pair the
  /// device is showing.
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final outer = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final t = candidate;
    final height = width / 0.64;
    final radius = width * 0.2;
    const ring = 2.5;
    const gap = 3.0;

    // A phone showing this theme's chat list as it really is now: a large
    // title, a few rows (face, name, preview, inset hairline) and the floating
    // bar — not a generic stack of bubbles, which is not the first thing
    // anyone sees in the app.
    final screen = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: t.background)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                width * 0.09,
                width * 0.12,
                width * 0.09,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FractionallySizedBox(
                    widthFactor: 0.48,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: width * 0.07,
                      decoration: BoxDecoration(
                        color: t.ink,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  SizedBox(height: width * 0.07),
                  for (var i = 0; i < 4; i++)
                    _Row(t: t, width: width, seed: i, unread: i == 0, last: i == 3),
                ],
              ),
            ),
            Positioned(
              left: width * 0.14,
              right: width * 0.14,
              bottom: width * 0.07,
              child: Container(
                height: width * 0.13,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    t.ink.withValues(alpha: 0.08),
                    t.surface,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: width * 0.05,
                        height: width * 0.05,
                        decoration: BoxDecoration(
                          color: i == 0 ? t.accent : t.inkMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final framed = SizedBox(
      width: width + 2 * (ring + gap),
      height: height + 2 * (ring + gap),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // The chosen one wears a ring with a gap, never a glow.
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: motion.d(const Duration(milliseconds: 180)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + ring + gap),
                border: Border.all(color: outer.accent, width: ring),
              ),
            ),
          ),
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              // A full point, not a half: at 0.5 the light previews (Ivory,
              // Paper, Bloom) still vanished into a cream or white page.
              border: Border.all(
                color: outer.ink.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: screen,
          ),
          if (badge != null)
            Positioned(
              top: -4,
              left: 0,
              right: 0,
              child: Center(child: _Badge(text: badge!)),
            ),
          Positioned(
            right: -3,
            bottom: -3,
            child: AnimatedScale(
              scale: selected ? 1 : 0,
              duration: motion.d(const Duration(milliseconds: 420)),
              curve: selected ? Curves.elasticOut : Curves.easeIn,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: outer.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: outer.background, width: 2),
                ),
                child: Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 13,
                  color: outer.accentInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final labelled = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        framed,
        const SizedBox(height: 6),
        SizedBox(
          width: width + 12,
          child: Text(
            t.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedMetaStyle(outer).copyWith(
              color: selected ? outer.ink : outer.inkSoft,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return labelled;
    return FocusableTap(
      onTap: onTap!,
      semanticLabel: t.name,
      selected: selected,
      radius: radius,
      // The shared spring, watching the pointer; the tap stays this
      // detector's, inside the focus ring that carries `selected`.
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SpringPress.passive(scale: 0.94, child: labelled),
      ),
    );
  }
}

/// One chat row in miniature.
class _Row extends StatelessWidget {
  const _Row({
    required this.t,
    required this.width,
    required this.seed,
    required this.unread,
    required this.last,
  });

  final AppTheme t;
  final double width;
  final int seed;
  final bool unread;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final face = width * 0.15;
    final hue = t.avatarGradient(seed * 7 + 3).first;
    return Padding(
      padding: EdgeInsets.only(bottom: width * 0.035),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: face,
                height: face,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(hue, Colors.white, 0.2)!, hue],
                  ),
                ),
              ),
              SizedBox(width: width * 0.05),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(t.ink, 0.55 - seed * 0.06),
                    SizedBox(height: width * 0.022),
                    _line(t.inkMuted, 0.85 - seed * 0.08),
                  ],
                ),
              ),
              SizedBox(width: width * 0.04),
              Container(
                width: width * 0.055,
                height: width * 0.055,
                decoration: BoxDecoration(
                  color: unread ? t.bubbleFill(isMine: true) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          if (!last) ...[
            SizedBox(height: width * 0.035),
            Padding(
              padding: EdgeInsets.only(left: face + width * 0.05),
              child: Container(
                height: 0.5,
                color: t.ink.withValues(alpha: 0.12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(Color c, double fraction) => FractionallySizedBox(
        widthFactor: fraction.clamp(0.2, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(
          height: width * 0.032,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final outer = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: outer.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: groupedMetaStyle(outer).copyWith(
          color: outer.accentInk,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class AppearanceModeSwitch extends StatelessWidget {
  const AppearanceModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final AppearanceMode mode;
  final ValueChanged<AppearanceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void pick(AppearanceMode m) {
      if (m == mode) return;
      HapticFeedback.selectionClick();
      onChanged(m);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ModeCard(
              icon: CupertinoIcons.circle_lefthalf_fill,
              title: l10n.appearanceMatchDevice,
              sub: l10n.appearanceMatchDeviceSubtitle,
              selected: mode == AppearanceMode.system,
              onTap: () => pick(AppearanceMode.system),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeCard(
              icon: CupertinoIcons.paintbrush_fill,
              title: l10n.appearanceOneTheme,
              sub: l10n.appearanceOneThemeSubtitle,
              selected: mode == AppearanceMode.fixed,
              onTap: () => pick(AppearanceMode.fixed),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: title,
      selected: selected,
      radius: theme.radiusLg,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          curve: theme.motionCurve,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          // Filled, never outlined: the chosen card takes a wash of the
          // accent and the other stays a plain grouped surface, the way an
          // iOS picker marks its selection.
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    theme.accent.withValues(alpha: 0.16),
                    theme.surface,
                  )
                : Color.alphaBlend(
                    theme.ink.withValues(alpha: 0.04),
                    theme.surface,
                  ),
            borderRadius: BorderRadius.circular(theme.radiusXl.clamp(10, 22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected ? theme.accent : theme.inkSoft,
                  ),
                  const Spacer(),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: MotionScope.of(context).d(
                      const Duration(milliseconds: 420),
                    ),
                    curve: selected ? Curves.elasticOut : Curves.easeIn,
                    child: Icon(
                      CupertinoIcons.checkmark_alt_circle_fill,
                      size: 20,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: groupedTitleStyle(theme).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: groupedMetaStyle(theme).copyWith(height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeSlotPair extends StatelessWidget {
  const ThemeSlotPair({
    super.key,
    required this.light,
    required this.dark,
    required this.platform,
    required this.onTapSlot,
    this.previewWidth = 104,
  });

  final AppTheme light;
  final AppTheme dark;

  /// The device's brightness right now — which half gets NOW.
  final Brightness platform;
  final ValueChanged<Brightness> onTapSlot;
  final double previewWidth;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    Widget half(Brightness slot) {
      final isLight = slot == Brightness.light;
      return Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLight ? CupertinoIcons.sun_max : CupertinoIcons.moon,
                  size: 14,
                  color: theme.inkSoft,
                ),
                const SizedBox(width: 5),
                Text(
                  isLight ? l10n.appearanceLightSlot : l10n.appearanceDarkSlot,
                  style: groupedMetaStyle(theme).copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ThemeMiniPreview(
              candidate: isLight ? light : dark,
              width: previewWidth,
              selected: platform == slot,
              badge: platform == slot ? l10n.appearanceNow : null,
              onTap: () => onTapSlot(slot),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [half(Brightness.light), half(Brightness.dark)],
    );
  }
}

/// A scrolling row of [ThemeMiniPreview]s, one of them chosen.
class ThemeStrip extends StatelessWidget {
  const ThemeStrip({
    super.key,
    required this.themes,
    required this.selectedId,
    required this.onSelect,
    this.previewWidth = 84,
  });

  final List<AppTheme> themes;
  final String selectedId;
  final ValueChanged<AppTheme> onSelect;
  final double previewWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // The preview, its caption, and room for the badge and the check to
      // overhang without being clipped by the list.
      height: previewWidth / 0.64 + 58,
      child: HorizontalWheelScroll(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
          clipBehavior: Clip.none,
          itemCount: themes.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final t = themes[i];
            return ThemeMiniPreview(
              candidate: t,
              width: previewWidth,
              selected: t.id == selectedId,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(t);
              },
            );
          },
        ),
      ),
    );
  }
}
