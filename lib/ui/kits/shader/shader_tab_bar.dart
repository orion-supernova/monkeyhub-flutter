import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../data/glass_config.dart';
import '../../../data/settings_store.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../screens/navigation/destinations.dart';
import '../../../theme/theme_scope.dart';
import '../../../widgets/count_badge.dart';
import 'shader_skin.dart';

/// The [UiKit.shader] bottom bar: the package's own [GlassTabBar.bottom], with
/// the per-tab pill widths patch (`indicatorItemWidths`, see the vendored
/// package's PATCHES.md).
///
/// Native iOS hugs the selected tab's content: a short label gets a narrow
/// pill and a long one a wide pill. The package gives every tab the same slot,
/// so each pill is measured from its label (it follows the language and the
/// text size) and the end tabs are widened to sit the same gap from the bar's
/// ends as from its top and bottom. Same recipe as Swirl's
/// `package_glass_tab_bar.dart`.
///
/// Behaviour matches `PillBottomNav`: the same destinations, badges and
/// placement (a [Positioned], so it goes straight in the shell's `Stack`), a
/// selection tick on change.
class ShaderTabBar extends StatelessWidget {
  const ShaderTabBar({
    super.key,
    required this.active,
    required this.onSelect,
    required this.badges,
  });

  final HomeSection active;
  final ValueChanged<HomeSection> onSelect;
  final Map<HomeSection, int> badges;

  static const double barHeight = 64;

  /// How far the whole tab row is inset from the bar's ends. Native sits the
  /// first icon about this far in, so its pill has the same room on both sides.
  static const double tabInset = 13;

  /// How far the pressed lens grows past the resting pill on each side.
  static const double _expandX = 16;

  /// Space between the selected label and the pill's ends, on each side.
  static const double _pillPadX = 22;

  /// The gap the package leaves between the pill and the bar's top and
  /// bottom. The end tabs' pills leave the same gap at the side.
  static const double _pillEdgeGap = 4;

  /// A short label still gets a pill at least this wide.
  static const double _pillMinWidth = 78;

  static const double _labelFontSize = 10;

  /// One pill width per tab, in logical pixels. Public for the layout test.
  @visibleForTesting
  static List<double> pillWidths(
    List<double> labelWidths,
    double barWidth,
  ) {
    final count = labelWidths.length;
    final endCentre = tabInset + (barWidth - 2 * tabInset) / count / 2;
    final endWidth = 2 * (endCentre - _pillEdgeGap);
    final widths = [
      for (final w in labelWidths)
        () {
          final content = w < 26 ? 26.0 : w;
          final width = content + 2 * _pillPadX;
          return width < _pillMinWidth ? _pillMinWidth : width;
        }(),
    ];
    if (widths.first < endWidth) widths[0] = endWidth;
    if (widths.last < endWidth) widths[count - 1] = endWidth;
    return widths;
  }

  List<double> _labelWidths(BuildContext context, List<NavDest> dests) {
    final style = DefaultTextStyle.of(context).style.copyWith(
          fontSize: _labelFontSize,
          fontWeight: FontWeight.w500,
        );
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    return [
      for (final d in dests)
        () {
          final painter = TextPainter(
            text: TextSpan(text: d.label, style: style),
            textDirection: dir,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w;
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final dests = navDestinations(AppLocalizations.of(context));
    final profile = SettingsStore.instance.glass;
    final geo = profile.geometry;
    final margin = geo.of(kBarMargin);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final barBottom = navBottomKeepOut(safeBottom) + geo.of(kBarBottom);
    final selected = dests.indexWhere((d) => d.section == active);
    final dark = !ShaderSkin.isLight(context);
    final glass = ShaderSkin.barSettings(context);

    Widget bar = LayoutBuilder(
      builder: (context, box) {
        final tabs = GlassTabBar.bottom(
          tabs: [
            for (final d in dests)
              GlassTab(
                icon: Icon(d.icon),
                label: d.label,
                semanticLabel: (badges[d.section] ?? 0) > 0
                    ? '${d.label}, ${badges[d.section]}'
                    : d.label,
              ),
          ],
          selectedIndex: selected < 0 ? 0 : selected,
          onTabSelected: (i) {
            HapticFeedback.selectionClick();
            onSelect(dests[i].section);
          },
          horizontalPadding: 0,
          verticalPadding: 0,
          barHeight: barHeight,
          iconSize: 26,
          labelFontSize: _labelFontSize,
          selectedIconColor: theme.accent,
          selectedLabelColor: theme.accent,
          unselectedIconColor: theme.inkSoft,
          unselectedLabelColor: theme.inkSoft,
          indicatorExpansion:
              const EdgeInsets.symmetric(horizontal: _expandX, vertical: 8),
          indicatorItemWidths:
              pillWidths(_labelWidths(context, dests), box.maxWidth),
          tabPadding: const EdgeInsets.symmetric(horizontal: tabInset),
          quality: ShaderSkin.heroQuality,
          settings: glass,
          interactionBehavior: ShaderSkin.behavior,
        );
        // The package's tabs carry no badge: lay the app's count over the
        // icon of each tab that has one, on the same slot grid the bar uses.
        final count = dests.length;
        final slot = (box.maxWidth - 2 * tabInset) / count;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            tabs,
            for (var i = 0; i < count; i++)
              if ((badges[dests[i].section] ?? 0) > 0)
                Positioned(
                  top: 6,
                  left: tabInset + slot * (i + 0.5) + 6,
                  child: IgnorePointer(
                    child: CountBadge.tab(count: badges[dests[i].section]!),
                  ),
                ),
          ],
        );
      },
    );
    bar = GlassTheme(
      data: GlassThemeData.ios27(
        brightness: dark ? Brightness.dark : Brightness.light,
        interaction: ShaderSkin.interactive
            ? const GlassInteractionSettings()
            : const GlassInteractionSettings(
                stretch: 0,
                interactionScale: 1,
                anchorStretch: false,
              ),
      ),
      child: bar,
    );
    return Positioned(
      left: margin,
      right: margin,
      bottom: barBottom,
      child: bar,
    );
  }
}
