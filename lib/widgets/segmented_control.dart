import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
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
    this.badge = false,
  });

  final T value;
  final String label;

  /// A 6pt accent dot after the label: something new behind this segment
  /// (unseen saves). Visual only — say it in [semanticLabel] too.
  final bool badge;

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
///
/// Stateful for smoothness, not for data: the thumb moves from local state
/// the instant you tap, and [onChanged] is delivered a frame later, so the
/// slide's first frame is never the same frame as the caller's (often heavy)
/// content swap. A drag moves only the thumb and commits once, on release —
/// it used to fire [onChanged] on every segment it crossed. The shared label
/// size is measured once per width / labels / text scale, not every build.
class IosSegmentedControl<T> extends StatefulWidget {
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
  State<IosSegmentedControl<T>> createState() => _IosSegmentedControlState<T>();
}

class _IosSegmentedControlState<T> extends State<IosSegmentedControl<T>> {
  /// Where the thumb is drawn. Leads [IosSegmentedControl.value] by a frame
  /// on a tap, and by a whole gesture on a drag.
  int? _shown;
  bool _dragging = false;

  // The measured shared font size and what it was measured for.
  Object? _fontKey;
  double _fontSize = _SegmentLabel.baseSize;

  List<IosSegment<T>> get segments => widget.segments;

  int get _valueIndex => segments.indexWhere((s) => s.value == widget.value);

  @override
  void didUpdateWidget(IosSegmentedControl<T> old) {
    super.didUpdateWidget(old);
    // Follow the caller once it has caught up with the thumb (or moved the
    // value itself). An unrelated rebuild in the frame between a tap and its
    // deferred commit must not snap the thumb back.
    if (!_dragging &&
        (old.value != widget.value || _shown == _valueIndex)) {
      _shown = null;
    }
  }

  void _commit(int i) {
    final onChanged = widget.onChanged;
    if (onChanged == null || i < 0 || i >= segments.length) return;
    if (i == _valueIndex) return;
    final value = segments[i].value;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) onChanged(value);
    });
  }

  void _show(int i) {
    if ((_shown ?? _valueIndex) == i) return;
    HapticFeedback.selectionClick();
    setState(() => _shown = i);
  }

  void _tap(int i) {
    if (widget.onChanged == null) return;
    _show(i);
    _commit(i);
  }

  double _sharedFontSizeCached(BuildContext context, AppTheme theme, double each) {
    final key = Object.hashAll([
      each,
      theme.id,
      MediaQuery.textScalerOf(context),
      for (final s in segments) ...[s.label, s.icon != null, s.badge],
    ]);
    if (key != _fontKey) {
      _fontKey = key;
      _fontSize = _sharedFontSize(context, theme, each);
    }
    return _fontSize;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final enabled = widget.onChanged != null;
    final n = segments.length;
    final index = _shown ?? _valueIndex;
    final track = theme.ink.withValues(alpha: theme.isLight ? 0.07 : 0.10);
    // Light: the white thumb of iOS. Dark: a lifted grey (iOS's #636366
    // role), mixed from the theme's ink so a tinted dark theme keeps its hue.
    final thumb = theme.isLight
        ? Colors.white
        : Color.alphaBlend(theme.ink.withValues(alpha: 0.24), theme.surface);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: LayoutBuilder(
        builder: (context, box) {
          const inset = IosSegmentedControl._inset;
          final inner = box.maxWidth - inset * 2;
          final each = inner / n;
          final fontSize = _sharedFontSizeCached(context, theme, each);
          int at(double dx) => ((dx - inset) / each).floor().clamp(0, n - 1);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: enabled ? (d) => _tap(at(d.localPosition.dx)) : null,
            onHorizontalDragStart: enabled ? (_) => _dragging = true : null,
            onHorizontalDragUpdate:
                enabled ? (d) => _show(at(d.localPosition.dx)) : null,
            onHorizontalDragEnd: enabled
                ? (_) {
                    _dragging = false;
                    final i = _shown;
                    if (i != null) _commit(i);
                  }
                : null,
            onHorizontalDragCancel: enabled ? () => _dragging = false : null,
            child: Container(
              padding: const EdgeInsets.all(inset),
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
                            onTap: enabled ? () => _tap(i) : null,
                            selected: i == index,
                            semanticLabel: segments[i].semanticLabel ??
                                sentenceCaseOf(context, segments[i].label),
                            shape: FocusRingShape.capsule,
                            radius: 999,
                            child: _SegmentLabel(
                              segment: segments[i],
                              selected: i == index,
                              fontSize: fontSize,
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

  /// One size for every label, the largest at which each segment's longest
  /// word fits its segment. Shrinking each label on its own left five Turkish
  /// tabs at 1.3× in four different sizes — "Ses" at 15, "Kaydedilenler" at
  /// 9 — which read as a bug, not as a fit. iOS shrinks the whole control.
  double _sharedFontSize(BuildContext context, AppTheme theme, double each) {
    if (!each.isFinite) return _SegmentLabel.baseSize;
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    var size = _SegmentLabel.baseSize;
    for (final seg in segments) {
      final room = each -
          _SegmentLabel.padH * 2 -
          (seg.icon != null ? 20 : 0) -
          (seg.badge ? 10 : 0);
      final words = sentenceCaseOf(context, seg.label).split(RegExp(r'\s+'));
      for (final word in words) {
        if (word.isEmpty) continue;
        while (size > _SegmentLabel.floorSize) {
          final p = TextPainter(
            text: TextSpan(
              text: word,
              // The selected weight: the wider of the two, so a label does
              // not outgrow its segment when the thumb lands on it.
              style: theme.body.copyWith(
                fontSize: size,
                letterSpacing: -0.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: dir,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = p.width;
          p.dispose();
          if (w <= room) break;
          size -= 0.5;
        }
      }
    }
    return size;
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({
    required this.segment,
    required this.selected,
    required this.fontSize,
  });
  final IosSegment<T> segment;
  final bool selected;

  /// Shared by every segment — see [IosSegmentedControl._sharedFontSize].
  final double fontSize;

  static const baseSize = 15.0;
  static const floorSize = 10.0;
  static const padH = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final style = theme.body.copyWith(
      fontSize: fontSize,
      height: 1.2,
      letterSpacing: -0.2,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      color: selected ? theme.ink : theme.inkSoft,
    );
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: padH, vertical: 6),
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
                  // Words already fit at [fontSize]; this only covers a
                  // label too long for two lines.
                  minFontSize: fontSize < 11 ? fontSize : 11,
                ),
              ),
              if (segment.badge) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
