import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import '../ui/foundation/ui_kit.dart';
import '../ui/native/native_control.dart';
import '../ui/kits/material/material_kit_theme.dart';

/// Continuous 0..1 control.
///
/// Hand-rolled rather than a Material [Slider], for the same reason the camera
/// editor's brush-size control is: that widget paints hover and focus overlays
/// and carries a Material theme this app does not use anywhere. Reports a 0..1
/// position and takes one back; the caller decides what the number means, which
/// is what lets one widget drive dials measured in sigma, points and alpha.
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onReset,
    this.enabled = true,
  });

  /// Position in 0..1.
  final double value;
  final ValueChanged<double> onChanged;

  /// Double-tap to restore the standard value, when the caller has one.
  final VoidCallback? onReset;

  final bool enabled;

  static const _track = 3.0;
  static const _thumb = 18.0;

  @override
  Widget build(BuildContext context) => KitSwitch(
        glass: _glass,
        material: _material,
        liquid: NativeControl.readyIn(context) ? _liquid : null,
      );

  /// The [UiKit.liquid] skin: the system slider, 0..1 continuous.
  Widget _liquid(BuildContext context) => GestureDetector(
        onDoubleTap: enabled ? onReset : null,
        child: NativeControl(
          size: const Size(double.infinity, 34),
          gestures: {
            Factory<HorizontalDragGestureRecognizer>(
              HorizontalDragGestureRecognizer.new,
            ),
          },
          spec: NativeSpec.slider(value: value.clamp(0.0, 1.0), enabled: enabled),
          onEvent: (event, v) {
            if (event == 'changed' && v is num) onChanged(v.toDouble());
          },
        ),
      );

  /// The [UiKit.material] skin: the Material 3 [Slider], still reporting a
  /// 0..1 position, still double-tap to reset.
  Widget _material(BuildContext context) => MaterialKitScope(
        child: GestureDetector(
          onDoubleTap: enabled ? onReset : null,
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      );

  Widget _glass(BuildContext context) {
    final theme = ThemeScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The thumb's centre can only travel between its own two radii, so the
        // position maps into that inner span rather than the full width.
        final span = math.max(1.0, width - _thumb);

        void report(double dx) {
          if (!enabled) return;
          onChanged(((dx - _thumb / 2) / span).clamp(0.0, 1.0));
        }

        final t = value.clamp(0.0, 1.0);
        final centre = _thumb / 2 + span * t;
        final accent = theme.accent.withValues(alpha: enabled ? 1 : 0.4);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // On tap *up*, not down. onTapDown fires the moment a finger lands,
          // before the gesture arena has decided whether this is a tap on the
          // slider or the start of a vertical scroll past it — so in a scrolling
          // panel it moved the dial every time you flicked the list from a
          // slider. onTapUp only fires once the tap has actually won.
          //
          // The horizontal drag callbacks need no such guard: they only fire
          // after beating the enclosing vertical scrollable in the arena, which
          // a vertical drag never lets happen.
          onTapUp: (d) => report(d.localPosition.dx),
          onHorizontalDragStart: (d) => report(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
          onDoubleTap: enabled ? onReset : null,
          child: SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: theme.divider,
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  width: centre,
                  child: Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                ),
                Positioned(
                  left: centre - _thumb / 2,
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 2),
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
