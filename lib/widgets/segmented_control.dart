import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/spring.dart';
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

  // The measured layout and what it was measured for.
  Object? _layoutKey;
  ({double font, List<double> widths}) _layout =
      (font: _SegmentLabel.baseSize, widths: const []);

  ({double font, List<double> widths}) _layoutCached(
    BuildContext context,
    AppTheme theme,
    double inner,
  ) {
    final key = Object.hashAll([
      inner,
      theme.id,
      MediaQuery.textScalerOf(context),
      for (final s in segments) ...[s.label, s.icon != null, s.badge],
    ]);
    if (key != _layoutKey || _layout.widths.length != segments.length) {
      _layoutKey = key;
      _layout = _measure(context, theme, inner);
    }
    return _layout;
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
          final layout = _layoutCached(context, theme, inner);
          final fontSize = layout.font;
          final widths = layout.widths;
          final lefts = <double>[0];
          for (var i = 0; i < n - 1; i++) {
            lefts.add(lefts.last + widths[i]);
          }
          int at(double dx) {
            final x = dx - inset;
            for (var i = n - 1; i >= 0; i--) {
              if (x >= lefts[i]) return i;
            }
            return 0;
          }
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
                    Positioned.fill(
                      child: _SpringThumb(
                        left: lefts[index],
                        width: widths[index],
                        calm: motion.calm,
                        decoration: BoxDecoration(
                          color: thumb,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: theme.isLight
                              ? const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
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
                          width: widths[i],
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

  /// Segment widths sized to their labels — UISegmentedControl's
  /// `apportionsSegmentWidthsByContent` — with ONE font size for all of them.
  ///
  /// Equal fifths gave "Ses" as much room as "Kaydedilenler", which then
  /// could not fit its fifth and shrank on its own while its neighbours stayed
  /// at 15: five labels in two sizes, which read as a bug. Here every label is
  /// measured at 15; if they all fit, the spare width is shared out evenly;
  /// if not, the whole row steps down together (to 12 at most), as iOS
  /// shrinks the whole control rather than one segment.
  ({double font, List<double> widths}) _measure(
    BuildContext context,
    AppTheme theme,
    double inner,
  ) {
    final n = segments.length;
    if (!inner.isFinite || inner <= 0) {
      return (font: _SegmentLabel.baseSize, widths: List.filled(n, 0));
    }
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    double textWidth(String label, double size) {
      final p = TextPainter(
        text: TextSpan(
          text: label,
          // The selected weight: the wider of the two, so a label does not
          // outgrow its segment when the thumb lands on it.
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
      return w;
    }

    double chrome(IosSegment<T> s) =>
        _SegmentLabel.padH * 2 + (s.icon != null ? 20 : 0) + (s.badge ? 10 : 0);
    final labels = [for (final s in segments) sentenceCaseOf(context, s.label)];

    var size = _SegmentLabel.baseSize;
    List<double> natural() => [
          for (var i = 0; i < n; i++)
            textWidth(labels[i], size).ceilToDouble() + chrome(segments[i]),
        ];
    var widths = natural();
    var total = widths.fold<double>(0, (a, b) => a + b);
    while (total > inner && size > _SegmentLabel.fitFloorSize) {
      size -= 0.5;
      widths = natural();
      total = widths.fold<double>(0, (a, b) => a + b);
    }
    if (total <= inner) {
      final extra = (inner - total) / n;
      widths = [for (final w in widths) w + extra];
    } else {
      // Even 12pt does not fit (huge text scale): scale the widths to the
      // track; FitLabel wraps or shrinks what is left over.
      final k = inner / total;
      widths = [for (final w in widths) w * k];
    }
    return (font: size, widths: widths);
  }
}


/// The sliding thumb: left edge and width on two retargetable [Spring]s (the
/// tab-bar lens feel, stiffness 500 / damping 32 ≈ response 0.28, ratio 0.72),
/// so a tap mid-slide keeps its velocity instead of restarting a curve. Snaps
/// under calm motion.
class _SpringThumb extends StatefulWidget {
  const _SpringThumb({
    required this.left,
    required this.width,
    required this.calm,
    required this.decoration,
  });

  final double left;
  final double width;
  final bool calm;
  final Decoration decoration;

  @override
  State<_SpringThumb> createState() => _SpringThumbState();
}

class _SpringThumbState extends State<_SpringThumb>
    with SingleTickerProviderStateMixin {
  static const _response = 0.28;
  static const _ratio = 0.72;

  late final Spring _left =
      Spring(response: _response, ratio: _ratio, value: widget.left);
  late final Spring _width =
      Spring(response: _response, ratio: _ratio, value: widget.width);
  late final Ticker _ticker = createTicker(_onTick);
  Duration? _last;

  void _onTick(Duration elapsed) {
    final last = _last;
    _last = elapsed;
    final dt = last == null
        ? 1 / 60
        : (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    _left.tick(dt);
    _width.tick(dt);
    if (_left.atRest && _width.atRest) {
      _ticker.stop();
      _last = null;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(_SpringThumb old) {
    super.didUpdateWidget(old);
    if (widget.calm) {
      _left.snap(widget.left);
      _width.snap(widget.width);
      return;
    }
    _left.retarget(widget.left);
    _width.retarget(widget.width);
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = widget.calm;
    return Stack(
      children: [
        Positioned(
          left: calm ? widget.left : _left.value,
          width: calm ? widget.width : _width.value.clamp(0.0, double.infinity),
          top: 0,
          bottom: 0,
          child: DecoratedBox(decoration: widget.decoration),
        ),
      ],
    );
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
  /// The smallest the shared size steps down to before the row compresses.
  static const fitFloorSize = 12.0;
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
