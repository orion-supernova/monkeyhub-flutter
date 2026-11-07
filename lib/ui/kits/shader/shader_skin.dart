import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/services.dart' show TextCapitalization, TextInputAction, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lgw;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    hide GlassButtonGroup;

import '../../../data/settings_store.dart';
import '../../../data/shader_glass_config.dart';
import '../../../theme/low_power.dart';
import '../../../theme/perf_tier.dart';
import '../../../theme/theme_scope.dart';
import 'shader_engine.dart';

/// Shared plumbing for the [UiKit.shader] skins of every component: which
/// glass settings to wear, which quality tier, and the package theme that
/// makes its own widgets (button, switch, slider, tab bar...) draw as iOS 27
/// glass in the app's light or dark.
///
/// A component keeps its behaviour (haptic, hover hint, semantics, shortcut)
/// and only asks this for pixels. The interactive effects (jelly press,
/// glow, stretch) follow Settings › Glass › Interactive glass.
abstract final class ShaderSkin {
  /// A pill: the shape of every labelled button.
  static const LiquidShape capsule = LiquidRoundedRectangle(borderRadius: 999);

  /// The user's dials, live.
  static ShaderGlassConfig get config => SettingsStore.instance.shaderGlass;

  /// Settings › Glass › Interactive glass.
  static bool get interactive => SettingsStore.instance.glassInteractive;

  /// Whether the page under [context] is light.
  static bool isLight(BuildContext context) =>
      ThemeScope.of(context).background.computeLuminance() > 0.5;

  /// The premium lens on every control, as Swirl ships it: the lightweight
  /// shader draws a hairline white rim that reads as a border, not as iOS
  /// glass. Low-tier devices and power saving keep the lightweight one.
  static GlassQuality get quality => heroQuality;

  /// The tab bar is one surface per screen, so it is allowed the premium lens
  /// (real refraction, the iOS 27 look) on every device that is not low-tier
  /// or saving power.
  static GlassQuality get heroQuality => (Perf.low || LowPowerMode.active)
      ? GlassQuality.standard
      : GlassQuality.premium;

  /// Clear iOS 27 glass tuned by the dials, for the page under [context].
  /// [tint] is a solid wash (a control that is on).
  static LiquidGlassSettings settings(BuildContext context, {Color? tint}) {
    ShaderGlassEngine.ensureStarted();
    return config.settings(
      isLight: isLight(context),
      color: tint,
      lowPower: LowPowerMode.active || Perf.low,
    );
  }

  /// The package theme for this subtree: iOS 27 optics in the page's
  /// brightness, with the press effects on or off.
  static Widget themed(BuildContext context, Widget child) {
    ShaderGlassEngine.ensureStarted();
    return GlassTheme(
      data: GlassThemeData.ios27(
        brightness: isLight(context) ? Brightness.light : Brightness.dark,
        interaction: interactive
            ? const GlassInteractionSettings()
            : const GlassInteractionSettings(
                stretch: 0,
                interactionScale: 1,
                anchorStretch: false,
              ),
      ),
      child: child,
    );
  }

  /// Press-effect behaviour for widgets that take one directly.
  static GlassInteractionBehavior get behavior => interactive
      ? GlassInteractionBehavior.full
      : GlassInteractionBehavior.none;

  /// The package's own button, drawn as clear shader glass: jelly press and
  /// glow when Interactive glass is on. [child] is laid centred over the
  /// glass; [width] / [height] size it (null hugs the child). [enabled] defaults
  /// to "has a tap"; pass true with a null tap for a busy button, which must
  /// not dim.
  static Widget button(
    BuildContext context, {
    required Widget child,
    required VoidCallback? onTap,
    String label = '',
    LiquidShape shape = const LiquidOval(),
    double? width,
    double? height,
    Color? tint,
    bool? enabled,
  }) {
    final on = interactive;
    return themed(
      context,
      GlassButton.custom(
        width: width,
        height: height,
        shape: shape,
        label: label,
        enabled: enabled ?? onTap != null,
        onTap: onTap ?? () {},
        useOwnLayer: true,
        quality: quality,
        settings: settings(context, tint: tint),
        interactionScale: on ? null : 1.0,
        stretch: on ? 0.5 : 0,
        glowRadius: on ? null : 0,
        child: child,
      ),
    );
  }

  /// One capsule of merged glass holding [slots], the package's own button
  /// group: the shell takes the press jelly, every slot its own tap. Each
  /// slot's [widget] is drawn as given (a glyph, a label, a lit disc).
  static Widget group(
    BuildContext context, {
    required List<({Widget widget, VoidCallback? onTap, String label})> slots,
  }) {
    return themed(
      context,
      lgw.GlassButtonGroup.icons(
        useOwnLayer: true,
        quality: quality,
        settings: settings(context),
        borderRadius: 22,
        itemPadding: const EdgeInsets.all(3),
        items: [
          for (final s in slots)
            lgw.GlassButtonGroupItem(
              icon: s.widget,
              onTap: s.onTap,
              label: s.label,
              enabled: s.onTap != null,
            ),
        ],
      ),
    );
  }

  /// The package's switch: a glass thumb that lifts and refracts while held,
  /// 64 x 28 like iOS 26. The caller plays the haptic (the app's rule is
  /// "after the change", so a switch that turns haptics off stays silent).
  static Widget toggle(
    BuildContext context, {
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final sw = themed(
      context,
      GlassSwitch(
        value: value,
        onChanged: onChanged ?? (_) {},
        width: 64,
        height: 28,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        useOwnLayer: true,
        quality: heroQuality,
        settings: settings(context),
        enableHaptics: false,
      ),
    );
    return onChanged == null
        ? IgnorePointer(child: Opacity(opacity: 0.5, child: sw))
        : sw;
  }

  /// The package's slider over [min]..[max], a glass thumb that lifts as it is
  /// dragged. Null [onChanged] disables it.
  static Widget slider(
    BuildContext context, {
    required double value,
    required ValueChanged<double>? onChanged,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return themed(
      context,
      GlassSlider(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        useOwnLayer: true,
        quality: heroQuality,
        settings: settings(context),
        interactionBehavior: behavior,
      ),
    );
  }

  /// The package's segmented control: a glass well with a lens that slides
  /// (and stretches while dragged) under the picked label.
  static Widget segmented(
    BuildContext context, {
    required List<String> labels,
    required int selected,
    required ValueChanged<int>? onSelected,
    required TextStyle selectedStyle,
    required TextStyle unselectedStyle,
  }) {
    final seg = themed(
      context,
      GlassSegmentedControl(
        segments: [for (final l in labels) GlassSegment(label: l)],
        selectedIndex: selected,
        onSegmentSelected: onSelected ?? (_) {},
        height: 32,
        useOwnLayer: true,
        quality: heroQuality,
        settings: settings(context),
        interactionBehavior: behavior,
        selectedTextStyle: selectedStyle,
        unselectedTextStyle: unselectedStyle,
      ),
    );
    return onSelected == null
        ? IgnorePointer(child: Opacity(opacity: 0.5, child: seg))
        : seg;
  }

  /// The package's text field: a glass well (50pt capsule for one line, a
  /// rounded box for several) whose rim lights while it has focus.
  static Widget textField(
    BuildContext context, {
    required TextEditingController controller,
    required TextStyle style,
    required TextStyle hintStyle,
    FocusNode? focusNode,
    String? placeholder,
    Widget? leading,
    Widget? trailing,
    bool obscure = false,
    int? minLines,
    int? maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool enabled = true,
    bool autofocus = false,
    bool autocorrect = true,
    bool enableSuggestions = true,
    Iterable<String>? autofillHints,
    Brightness? keyboardAppearance,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    final multi = (maxLines ?? 2) > 1;
    return themed(
      context,
      GlassTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        prefixIcon: leading,
        suffixIcon: trailing,
        obscureText: obscure,
        minLines: minLines,
        maxLines: obscure ? 1 : (maxLines ?? 12),
        maxLength: maxLength,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        autofillHints: autofillHints,
        keyboardAppearance: keyboardAppearance,
        enabled: enabled,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textStyle: style,
        placeholderStyle: hintStyle,
        height: multi ? null : 50,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: multi ? 14 : 0),
        shape: LiquidRoundedRectangle(borderRadius: multi ? 22 : 25),
        useOwnLayer: true,
        quality: quality,
        settings: settings(context),
        interactionBehavior: behavior,
      ),
    );
  }

  /// The package's search bar: a glass capsule with the magnifier and its own
  /// clear button.
  static Widget searchBar(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required double height,
    required TextStyle style,
    required TextStyle hintStyle,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    String? clearLabel,
  }) {
    return themed(
      context,
      GlassSearchBar(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        height: height,
        textStyle: style,
        placeholderStyle: hintStyle,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        clearButtonSemanticLabel: clearLabel,
        useOwnLayer: true,
        quality: quality,
        settings: settings(context),
      ),
    );
  }

  /// The package's pull-down button: the glass disc morphs into a glass menu
  /// of [items] (built with [menuItem] and [menuDivider]).
  static Widget pullDown(
    BuildContext context, {
    required Widget icon,
    required double size,
    required String semanticLabel,
    required List<Widget> items,
  }) {
    return themed(
      context,
      GlassPullDownButton(
        icon: icon,
        items: items,
        semanticLabel: semanticLabel,
        menuSemanticLabel: semanticLabel,
        buttonWidth: size,
        buttonHeight: size,
        settings: settings(context),
        quality: quality,
      ),
    );
  }

  /// One row of a glass menu.
  static Widget menuItem({
    required String title,
    required VoidCallback onTap,
    IconData? icon,
    Color? iconColor,
    bool destructive = false,
    bool checked = false,
  }) =>
      GlassMenuItem(
        title: title,
        onTap: onTap,
        icon: icon == null ? null : Icon(icon),
        iconColor: iconColor,
        isDestructive: destructive,
        isSelected: checked,
        trailing:
            checked ? const Icon(CupertinoIcons.checkmark, size: 16) : null,
      );

  /// The hairline between menu groups.
  static Widget menuDivider() => const GlassMenuDivider();

  /// The surface of a floating sheet: clear iOS 27 glass washed with the
  /// page's own sheet colour so text on it stays legible, with a heavier frost
  /// than a button. The sheet's content paints over it without a fill of its
  /// own under this kit (see `SheetPanel`).
  static Widget sheet(
    BuildContext context, {
    required double radius,
    required Color fill,
    required Widget child,
  }) {
    final base = settings(context, tint: fill.withValues(alpha: 0.74));
    return themed(
      context,
      AdaptiveGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        settings: base.copyWith(frost: base.frost + 8),
        quality: quality,
        allowElevation: true,
        child: child,
      ),
    );
  }
}
