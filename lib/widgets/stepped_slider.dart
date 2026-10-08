import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show groupedMetaStyle;
import 'value_slider.dart';

/// A [ValueSlider] that can only rest on a few labelled stops: Low / Medium /
/// High, 1 GB / 5 GB / 20 GB / No Limit.
///
/// The labels sit above the track, each over the point its stop lands on, so
/// the scale reads like a ruler; the current one is drawn in ink, the rest
/// muted. Dragging moves stop to stop with a selection tick on each, and the
/// thumb glides between them rather than jumping. [index] may be null for a
/// value no stop describes (a customised preset): the thumb then rests at the
/// middle of the track with no label lit, and any drag lands it on a stop.
class SteppedSlider extends StatelessWidget {
  const SteppedSlider({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.enabled = true,
  }) : assert(labels.length >= 2);

  final List<String> labels;
  final int? index;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final n = labels.length;
    final at = index;
    final position = at == null ? 0.5 : at / (n - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            // Labels share the slider's own geometry: the thumb's centre
            // travels between its radii, so each label is centred over that
            // inner span's stop, the end ones pinned to the edges.
            const inset = 9.0;
            final span = c.maxWidth - inset * 2;
            return SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < n; i++)
                    _label(theme, i, n, inset + span * i / (n - 1), c.maxWidth),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(end: position),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ValueSlider(
            value: v,
            enabled: enabled,
            onChanged: (t) {
              final next = (t * (n - 1)).round();
              if (next == at) return;
              HapticFeedback.selectionClick();
              onChanged(next);
            },
          ),
        ),
      ],
    );
  }

  Widget _label(AppTheme theme, int i, int n, double x, double width) {
    final active = i == index;
    final style = groupedMetaStyle(theme).copyWith(
      color: active ? theme.ink : theme.inkMuted,
      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
    );
    final text = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 160),
      style: style,
      child: Text(labels[i], maxLines: 1),
    );
    if (i == 0) return Positioned(left: 0, child: text);
    if (i == n - 1) return Positioned(right: 0, child: text);
    // Centred on its stop: a box as wide as the space either side allows.
    final room = (x < width - x ? x : width - x) * 2;
    return Positioned(
      left: x - room / 2,
      width: room,
      child: Center(child: text),
    );
  }
}
