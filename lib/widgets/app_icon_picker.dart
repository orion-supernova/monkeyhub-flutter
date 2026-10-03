import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'app_brand_mark.dart' show canonicalLogoId;
import 'brand_icon_canvas.dart';
import 'monkey_collection.dart';
import '../services/launcher_icon_names.dart' show kBorrowedIconThemeIds;

/// The choice that means "let the icon follow the theme" ([LogoMode.auto]).
/// Every other choice is a concrete icon id: [canonicalLogoId], a monkey
/// collection id, or a theme id.
const String kMatchThemeIcon = '__match_theme__';

/// What the store currently resolves to, as a picker choice.
String currentIconChoice(SettingsStore store) => switch (store.logoMode) {
      LogoMode.auto => kMatchThemeIcon,
      LogoMode.alwaysDefault => canonicalLogoId,
      LogoMode.manual => store.manualLogoThemeId ?? canonicalLogoId,
    };

/// Writes a picker choice back to the store.
///
/// The MonkeyHub mark is [LogoMode.alwaysDefault] rather than a manual pick of
/// it: the two resolve to the same icon, but "always the MonkeyHub icon" is
/// the sentence the person chose, and it survives the mark's id changing.
Future<void> applyIconChoice(SettingsStore store, String choice) async {
  if (choice == kMatchThemeIcon) {
    await store.setLogoMode(LogoMode.auto);
  } else if (choice == canonicalLogoId) {
    await store.setLogoMode(LogoMode.alwaysDefault);
  } else {
    await store.setManualLogoThemeId(choice);
    await store.setLogoMode(LogoMode.manual);
  }
}

/// The edge-to-edge art of [choice] at [size] — what the launcher shows, with
/// no inner rounding or shadow, ready to drop into a squircle. "Match theme"
/// resolves against [store] the way the launcher does.
Widget appIconArt(SettingsStore store, String choice, double size) {
  if (choice == kMatchThemeIcon) {
    final followed = ThemeController.byId(store.themeIdFor(Brightness.dark));
    return BrandIconCanvas(theme: followed, size: size);
  }
  if (choice == canonicalLogoId) {
    return CanonicalIconCanvas(backdrop: const Color(0xFF0E0E10), size: size);
  }
  final variant = monkeyVariantById(choice);
  if (variant != null) return MonkeyIconCanvas(variant: variant, size: size);
  return BrandIconCanvas(theme: ThemeController.byId(choice), size: size);
}

/// The app-icon picker: a home-screen-like grid of real icons in squircle
/// masks, under three short headings.
///
/// Shared by the first-run icon step and Settings › App Icon, so the icon a
/// person picks on day one looks exactly like the one they find later.
class AppIconPicker extends StatelessWidget {
  const AppIconPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.current,
  });

  /// The highlighted choice — see [currentIconChoice].
  final String selected;
  final ValueChanged<String> onSelect;

  /// The icon on the home screen right now, tagged "Current" so a person can
  /// always find their way back to it. Null hides the tag.
  final String? current;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.instance;
    // The icon "Match theme" would show today: the fixed theme, or the dark
    // half of the pair (see SettingsStore._iconThemeId for why dark).
    final followed = ThemeController.byId(store.themeIdFor(Brightness.dark));

    _IconSpec spec(
      String id,
      String label,
      Widget Function(double) art, {
      IconData? badge,
    }) =>
        _IconSpec(id: id, label: label, art: art, badge: badge);

    final top = [
      spec(
        kMatchThemeIcon,
        l10n.appIconMatchTheme,
        (s) => BrandIconCanvas(theme: followed, size: s),
        // Without a mark it is indistinguishable from that theme's own tile
        // further down; the arrows say "this one changes".
        badge: CupertinoIcons.arrow_2_circlepath,
      ),
      spec(
        canonicalLogoId,
        'MonkeyHub',
        (s) => CanonicalIconCanvas(backdrop: const Color(0xFF0E0E10), size: s),
      ),
    ];
    final collection = [
      for (final v in monkeyCollection)
        spec(v.id, v.displayName, (s) => MonkeyIconCanvas(variant: v, size: s)),
    ];
    final themes = [
      for (final t in ThemeController.all)
        // A theme still borrowing another's launcher icon has no icon of its
        // own to offer.
        if (!kBorrowedIconThemeIds.contains(t.id))
          spec(t.id, t.name, (s) => BrandIconCanvas(theme: t, size: s)),
    ];

    Widget grid(List<_IconSpec> specs) => _IconGrid(
          specs: specs,
          selected: selected,
          current: current,
          onSelect: onSelect,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        grid(top),
        const SizedBox(height: 22),
        _Heading(text: l10n.appIconSectionCollection, theme: theme),
        grid(collection),
        const SizedBox(height: 22),
        _Heading(text: l10n.appIconSectionThemes, theme: theme),
        grid(themes),
      ],
    );
  }
}

class _IconSpec {
  const _IconSpec({
    required this.id,
    required this.label,
    required this.art,
    this.badge,
  });
  final String id;
  final String label;
  final Widget Function(double size) art;
  final IconData? badge;
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.theme});
  final String text;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text(
          text,
          style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
        ),
      );
}

/// Four columns, like a phone's home screen.
class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.specs,
    required this.selected,
    required this.current,
    required this.onSelect,
  });

  final List<_IconSpec> specs;
  final String selected;
  final String? current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 4;
        const gap = 14.0;
        final cell = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: [
            for (final s in specs)
              SizedBox(
                width: cell,
                child: AppIconTile(
                  label: s.label,
                  art: s.art,
                  badge: s.badge,
                  selected: s.id == selected,
                  current: s.id == current,
                  onTap: () => onSelect(s.id),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One icon: the art in an iOS squircle, a ring when chosen, the name under it.
class AppIconTile extends StatefulWidget {
  const AppIconTile({
    super.key,
    required this.label,
    required this.art,
    required this.selected,
    required this.onTap,
    this.current = false,
    this.badge,
  });

  final String label;
  final Widget Function(double size) art;

  /// A small glyph pinned to the icon's top-left corner.
  final IconData? badge;
  final bool selected;
  final bool current;
  final VoidCallback onTap;

  @override
  State<AppIconTile> createState() => _AppIconTileState();
}

class _AppIconTileState extends State<AppIconTile> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // The ring sits outside the icon with a gap, the way iOS marks the
        // chosen alternate icon; the icon shrinks to make room for both.
        const ring = 2.5;
        const gap = 3.0;
        final outer = constraints.maxWidth.clamp(0.0, 76.0);
        final icon = outer - 2 * (ring + gap);
        // ContinuousRectangleBorder needs roughly twice the radius of a plain
        // rounded rect to read the same; 0.45 × size lands on the iOS icon
        // squircle.
        final squircle = ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(icon * 0.45),
        );
        final ringShape = ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(outer * 0.45),
        );

        final tile = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: outer,
              height: outer,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    opacity: widget.selected ? 1 : 0,
                    duration: motion.d(const Duration(milliseconds: 180)),
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: ringShape.copyWith(
                          side: BorderSide(color: theme.accent, width: ring),
                        ),
                      ),
                      child: SizedBox(width: outer, height: outer),
                    ),
                  ),
                  Container(
                    width: icon,
                    height: icon,
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      shape: squircle,
                      shadows: [
                        // Centred and soft: an offset shadow under a light
                        // icon reads as a grey lip, not as depth.
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: widget.art(icon),
                  ),
                  if (widget.badge != null)
                    Positioned(
                      left: -2,
                      top: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.surfaceRaised,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.background, width: 2),
                        ),
                        child: Icon(widget.badge, size: 13, color: theme.ink),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: AnimatedScale(
                      scale: widget.selected ? 1 : 0,
                      duration: motion.d(const Duration(milliseconds: 420)),
                      curve: widget.selected ? Curves.elasticOut : Curves.easeIn,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.background, width: 2),
                        ),
                        child: Icon(
                          CupertinoIcons.checkmark_alt,
                          size: 13,
                          color: theme.accentInk,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.caption.copyWith(
                fontSize: 12,
                color: widget.selected ? theme.ink : theme.inkSoft,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (widget.current)
              Text(
                l10n.appIconCurrent,
                maxLines: 1,
                style: theme.caption.copyWith(
                  fontSize: 11,
                  color: theme.inkMuted,
                ),
              ),
          ],
        );

        return FocusableTap(
          onTap: widget.onTap,
          semanticLabel: widget.label,
          selected: widget.selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _set(true),
            onTapUp: (_) => _set(false),
            onTapCancel: () => _set(false),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _down ? 0.92 : 1,
              duration: motion.d(
                _down
                    ? const Duration(milliseconds: 90)
                    : const Duration(milliseconds: 460),
              ),
              curve: _down ? Curves.easeOut : Curves.elasticOut,
              child: tile,
            ),
          ),
        );
      },
    );
  }
}
