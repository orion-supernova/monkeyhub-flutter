import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/text_case.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'fit_label.dart';

/// One option of an [IosSegmentedControl].
class IosSegment<T> {
  const IosSegment({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  final T value;
  final String label;

  /// An optional Cupertino glyph before the label.
  final IconData? icon;
  final String? semanticLabel;
}

/// THE segmented control: a soft capsule track with a sliding thumb under the
/// picked option — UISegmentedControl in the iOS 26 shape.
///
/// Five hand-rolled copies preceded it (call options, group call, Discover,
/// mute, sticker maker, profile visibility…), at 14pt with thumbs at three
/// alphas. Segments are equal widths, as on iOS. Labels are 15pt and never
/// clipped: a label too long for its segment wraps to two lines, then
/// shrinks a step at a time ([FitLabel]) — the mute sheet's Turkish "Her
/// zaman" was cut to "Her" against the divider.
///
/// Tap a segment, or drag the thumb across. Keyboard: each segment is a
/// focus stop. A null [onChanged] draws the control disabled. No spring
/// press — iOS segments don't dip; the thumb's slide is the feedback.
class IosSegmentedControl<T> extends StatelessWidget {
  const IosSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  }) : assert(segments.length >= 2);

  final List<IosSegment<T>> segments;

  /// The picked value. One not in [segments] shows no thumb.
  final T value;
  final ValueChanged<T>? onChanged;

  static const _inset = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final enabled = onChanged != null;
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value);
    final track = theme.ink.withValues(alpha: theme.isLight ? 0.07 : 0.10);
    // Light: the white thumb of iOS. Dark: a lifted grey (iOS's #636366
    // role), mixed from the theme's ink so a tinted dark theme keeps its hue.
    final thumb = theme.isLight
        ? Colors.white
        : Color.alphaBlend(theme.ink.withValues(alpha: 0.24), theme.surface);

    void pick(int i) {
      if (!enabled || i < 0 || i >= n || i == index) return;
      HapticFeedback.selectionClick();
      onChanged!(segments[i].value);
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: LayoutBuilder(
        builder: (context, box) {
          final inner = box.maxWidth - _inset * 2;
          final each = inner / n;
          int at(double dx) => ((dx - _inset) / each).floor().clamp(0, n - 1);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled ? (d) => pick(at(d.localPosition.dx)) : null,
            onHorizontalDragUpdate:
                enabled ? (d) => pick(at(d.localPosition.dx)) : null,
            child: Container(
              padding: const EdgeInsets.all(_inset),
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                children: [
                  if (index >= 0)
                    AnimatedPositioned(
                      duration: motion.d(const Duration(milliseconds: 300)),
                      curve: Curves.easeOutCubic,
                      left: each * index,
                      width: each,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: thumb,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: theme.isLight
                              ? const [
                                  BoxShadow(
                                    color: Color(0x1F000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        SizedBox(
                          width: each,
                          child: FocusableTap(
                            onTap: enabled ? () => pick(i) : null,
                            selected: i == index,
                            semanticLabel: segments[i].semanticLabel ??
                                sentenceCaseOf(context, segments[i].label),
                            shape: FocusRingShape.capsule,
                            radius: 999,
                            child: _SegmentLabel(
                              segment: segments[i],
                              selected: i == index,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({required this.segment, required this.selected});
  final IosSegment<T> segment;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final style = theme.body.copyWith(
      fontSize: 15,
      height: 1.2,
      letterSpacing: -0.2,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? theme.ink : theme.inkSoft,
    );
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: 15, color: style.color),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: FitLabel(
                  sentenceCaseOf(context, segment.label),
                  style: style,
                  maxLines: 2,
                  minFontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
