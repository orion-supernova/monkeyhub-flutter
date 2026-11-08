import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/ui_kit.dart';
import '../ui/kits/material/material_kit_theme.dart';
import '../ui/kits/shader/shader_skin.dart';
import '../theme/app_theme.dart';
import '../ui/native/native_control.dart';
import 'odometer_number.dart';
import 'spring_press.dart';

/// THE filter chip: a soft neutral capsule at rest, solid accent when on —
/// the Apple Music filter treatment. The chat list's facet row and the
/// diagnostics categories both draw this, so a filter looks like a filter
/// wherever it is.
class FilterCapsule extends StatelessWidget {
  const FilterCapsule({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.showZeroCount = false,
    this.leading,
    this.faded = false,
    this.onLongPress,
    this.semanticLabel,
    this.activeColor,
    this.activeInk,
  });

  /// The fill when [active], in place of the accent: a point category wears
  /// its own colour.
  final Color? activeColor;

  /// The label's colour on [activeColor].
  final Color? activeInk;

  final String label;
  final bool active;
  final VoidCallback? onTap;

  /// Shown after the label in tabular figures. A zero is dimmed into the
  /// label rather than printed, unless [showZeroCount].
  final int? count;
  final bool showZeroCount;

  /// A small mark before the label — a category's colour dot, say.
  final Widget? leading;

  /// Half-strength while not [active]: a filter that is set aside.
  final bool faded;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => KitSwitch(
    glass: _glass,
    material: _material,
    shader: _shader,
    // A real iOS 26 glass capsule; a colour mark or a custom fill keeps the
    // Flutter skin, which can draw them.
    liquid: NativeControl.readyIn(context) &&
            leading == null &&
            activeColor == null
        ? _liquid
        : null,
  );

  /// The [UiKit.liquid] skin: a native glass capsule, tinted when on.
  Widget _liquid(BuildContext context) {
    final n = count;
    final showCount = n != null && (n > 0 || showZeroCount);
    final text = showCount ? '$label  $n' : label;
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      // Filters sit at the top of a scrolling list (and in a sideways row):
      // a native button would take every touch that lands on it, so a drag
      // that started on a capsule scrolled nothing. The glass only draws;
      // the tap is Flutter's, and a tap recognizer never claims a drag, so
      // both scrolls win from anywhere on the row.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : _tap,
        onLongPress: onLongPress,
        child: NativeControl(
          // Wears the native chip's colours, so the hand-over between them
          // (a covered or fading moment) is not a restyle.
          standIn: _NativeLook(
            child: FlutterSkinsOnly(child: Builder(builder: build)),
          ),
          size: nativeButtonSize(context, text, height: 32),
          spec: NativeSpec.button(
            label: text,
            prominent: active,
            enabled: onTap != null || active,
            height: 32,
            passthrough: true,
          ),
        ),
      ),
    );
  }

  /// The [UiKit.material] skin: a Material 3 [FilterChip] (tonal when on,
  /// outlined at rest, a check when on and there is no [leading] mark).
  Widget _material(BuildContext context) {
    final theme = ThemeScope.of(context);
    final scheme = MaterialKitTheme.of(theme).colorScheme;
    final n = count;
    final empty = n == 0;
    final showCount = n != null && (n > 0 || showZeroCount);
    final on = activeColor;
    final ink = active
        ? (activeInk ?? (on != null ? theme.accentInk : scheme.onSecondaryContainer))
        : (empty ? scheme.outline : scheme.onSurfaceVariant);
    final chip = FilterChip(
      selected: active,
      onSelected: onTap == null ? null : (_) => _tap(),
      showCheckmark: leading == null,
      avatar: leading,
      selectedColor: on ?? scheme.secondaryContainer,
      checkmarkColor: ink,
      labelStyle: theme.bodySoft.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: ink,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label)),
          if (showCount) ...[
            const SizedBox(width: 6),
            OdometerNumber(
              value: n,
              style: theme.bodySoft.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: ink.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
    return MaterialKitScope(
      child: Semantics(
        button: true,
        selected: active,
        enabled: onTap != null,
        label: semanticLabel ?? label,
        excludeSemantics: true,
        child: Opacity(
          opacity: faded && !active ? 0.5 : 1,
          child: GestureDetector(
            onLongPress: onLongPress,
            child: chip,
          ),
        ),
      ),
    );
  }

  Widget _glass(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return FocusableTap(
      onTap: onTap == null ? null : _tap,
      semanticLabel: semanticLabel ?? label,
      selected: active,
      shape: FocusRingShape.capsule,
      radius: 999,
      inset: 2,
      // The chip dips on the press like every other control, and turning a
      // filter on or off clicks: it reshapes the list under the finger.
      child: SpringPress.passive(
        child: GestureDetector(
          onTap: onTap == null ? null : _tap,
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: faded && !active ? 0.5 : 1,
            child: AnimatedContainer(
              duration: motion.d(theme.motionFast),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 34),
              padding: EdgeInsets.fromLTRB(leading == null ? 14 : 11, 0, 14, 0),
              decoration: BoxDecoration(
                color: active
                    ? (activeColor ?? theme.accent)
                    : theme.ink.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
              ),
              // Hugs its label (a Container `alignment` would stretch the
              // capsule across a Wrap); centred in whatever height it is given.
              child: _content(context, theme, motion),
            ),
          ),
        ),
      ),
    );
  }

  /// The leading mark, label and count, shared by the glass and shader skins.
  Widget _content(BuildContext context, AppTheme theme, MotionScope motion) {
    final onFill = activeInk ?? theme.accentInk;
    final n = count;
    final empty = n == 0;
    final showCount = n != null && (n > 0 || showZeroCount);
    return Center(
      widthFactor: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 6),
          ],
          // Flexible + clip: a capsule squeezed by its slot (or mid-resize)
          // trims its label by a sub-pixel instead of throwing an overflow;
          // clip, not ellipsis, so a rounding sliver never shows a "…".
          Flexible(
            child: AnimatedDefaultTextStyle(
            duration: motion.d(theme.motionFast),
            style: theme.bodySoft.copyWith(
              fontSize: 15,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: -0.2,
              color: active
                  ? onFill
                  // A filter matching nothing is dimmed rather than
                  // hidden — a row that reshuffled itself every time a
                  // count hit zero would be impossible to aim at.
                  : _NativeLook.of(context)
                      // A native glass chip's label is the tint.
                      ? theme.accent
                      : (empty ? theme.inkMuted : theme.inkSoft),
            ),
            child: Text(label,
                maxLines: 1, softWrap: false, overflow: TextOverflow.clip),
            ),
          ),
          if (showCount) ...[
            const SizedBox(width: 5),
            // Rolls as the count moves under a live list.
            OdometerNumber(
              value: n,
              // The body face, not the caption slot (tracked mono on
              // a character theme).
              style: theme.bodySoft.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: active
                    ? onFill.withValues(alpha: 0.75)
                    : theme.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The [UiKit.shader] skin: the package's glass button as a capsule, tinted
  /// when on. Same label, count, leading mark, haptic and semantics.
  Widget _shader(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Semantics(
      button: true,
      selected: active,
      enabled: onTap != null,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Opacity(
          opacity: faded && !active ? 0.5 : 1,
          child: ShaderSkin.button(
            context,
            shape: ShaderSkin.capsule,
            tint: active ? (activeColor ?? theme.accent) : null,
            enabled: true,
            onTap: onTap == null ? () {} : _tap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(leading == null ? 14 : 11, 0, 14, 0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 34),
                child: _content(context, theme, motion),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _tap() {
    HapticFeedback.selectionClick();
    onTap?.call();
  }
}

/// Marks a [FilterCapsule] drawn as a native chip's stand-in: it takes the
/// native chip's label colour.
class _NativeLook extends InheritedWidget {
  const _NativeLook({required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_NativeLook>() != null;

  @override
  bool updateShouldNotify(_NativeLook old) => false;
}
