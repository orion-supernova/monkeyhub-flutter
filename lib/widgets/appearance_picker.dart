import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';

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

  /// The theme being previewed. Distinct from the one the preview sits on.
  final AppTheme candidate;
  final double width;
  final bool selected;

  /// A word in the corner — NOW, LIGHT, DARK. Null for none.
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final outer = ThemeScope.of(context);
    final t = candidate;
    final height = width / 0.64;
    final radius = width * 0.17;

    final phone = AnimatedContainer(
      duration: outer.motionFast,
      curve: outer.motionCurve,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected ? outer.accent : outer.divider,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: outer.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        // Inside the stroke, so the corners of the screen never cut across it.
        padding: EdgeInsets.all(selected ? 2 : 1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 2),
          child: ColoredBox(
            color: t.background,
            child: Padding(
              padding: EdgeInsets.all(width * 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(t: t, width: width),
                  const Spacer(),
                  _Bubble(t: t, mine: false, fraction: 0.62, width: width),
                  SizedBox(height: width * 0.05),
                  _Bubble(t: t, mine: true, fraction: 0.5, width: width),
                  SizedBox(height: width * 0.05),
                  _Bubble(t: t, mine: false, fraction: 0.4, width: width),
                  SizedBox(height: width * 0.08),
                  Container(
                    height: width * 0.12,
                    decoration: BoxDecoration(
                      color: t.surfaceSunken,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: t.divider),
                    ),
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.all(width * 0.02),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final framed = Stack(
      clipBehavior: Clip.none,
      children: [
        phone,
        if (badge != null)
          Positioned(
            top: -7,
            left: 0,
            right: 0,
            child: Center(child: _Badge(text: badge!)),
          ),
        if (selected)
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: outer.accent,
                shape: BoxShape.circle,
                border: Border.all(color: outer.background, width: 2),
              ),
              child: Icon(Icons.check, size: 12, color: outer.accentInk),
            ),
          ),
      ],
    );

    final labelled = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        framed,
        const SizedBox(height: 8),
        SizedBox(
          width: width + 12,
          child: Text(
            t.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: outer.monoTiny.copyWith(
              color: selected ? outer.accent : outer.inkSoft,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: labelled,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.t, required this.width});
  final AppTheme t;
  final double width;

  @override
  Widget build(BuildContext context) {
    final dot = width * 0.13;
    return Row(
      children: [
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: t.avatarGradient(7)),
          ),
        ),
        SizedBox(width: width * 0.05),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(t.ink, 0.7),
              SizedBox(height: width * 0.025),
              _line(t.inkMuted, 0.45),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(Color c, double fraction) => FractionallySizedBox(
        widthFactor: fraction,
        alignment: Alignment.centerLeft,
        child: Container(
          height: width * 0.035,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.t,
    required this.mine,
    required this.fraction,
    required this.width,
  });

  final AppTheme t;
  final bool mine;
  final double fraction;
  final double width;

  @override
  Widget build(BuildContext context) {
    final deco = t.messageBubbleDecoration(isMine: mine, ephemeral: false);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction,
        child: Container(
          height: width * 0.12,
          decoration: BoxDecoration(
            color: deco.color ?? (mine ? t.accent : t.surfaceRaised),
            gradient: deco.gradient,
            border: deco.border,
            borderRadius: BorderRadius.circular(width * 0.06),
          ),
        ),
      ),
    );
  }
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
        style: outer.monoTiny.copyWith(
          color: outer.accentInk,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Match device, or one theme — the first question, as two cards.
///
/// Cards rather than a two-word segmented control, because the two options
/// need their one line of explanation to be chosen between: "Match device"
/// alone does not say that the app will go dark at night.
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
              icon: Icons.brightness_auto_outlined,
              title: l10n.appearanceMatchDevice,
              sub: l10n.appearanceMatchDeviceSub,
              selected: mode == AppearanceMode.system,
              onTap: () => pick(AppearanceMode.system),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeCard(
              icon: Icons.palette_outlined,
              title: l10n.appearanceOneTheme,
              sub: l10n.appearanceOneThemeSub,
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
          decoration: BoxDecoration(
            color: selected ? theme.accentSoft : theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            border: Border.all(
              color: selected ? theme.accent : theme.divider,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? theme.accent : theme.inkSoft,
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: theme.motionFast,
                    opacity: selected ? 1 : 0,
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: theme.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: theme.bodyEmph.copyWith(fontSize: 15)),
              const SizedBox(height: 3),
              Text(sub, style: theme.caption),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two halves of the device-following pair, side by side, with NOW on the
/// one showing. Tapping a half calls [onTapSlot] with its brightness.
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
                  isLight ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 13,
                  color: theme.inkSoft,
                ),
                const SizedBox(width: 5),
                Text(
                  isLight ? l10n.appearanceLightSlot : l10n.appearanceDarkSlot,
                  style: theme.label.copyWith(letterSpacing: 1.6),
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
      height: previewWidth / 0.64 + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        clipBehavior: Clip.none,
        itemCount: themes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
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
    );
  }
}
