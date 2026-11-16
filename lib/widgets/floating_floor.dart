import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../theme/theme_scope.dart';

/// A page whose bottom action FLOATS over its scrolling content.
///
/// The alternative, a `Column` of `[Expanded(scroller), Padding(button)]`,
/// gives the button a band of its own: the content is sliced off in a straight
/// line above it and nothing ever shows below it. That band is what this
/// replaces. Here the page fills the whole height, scrolls underneath the
/// action and on to the edge of the glass, and only dims softly on the way
/// down so the action stays readable.
///
/// The page is told about the floor through `MediaQuery`: inside [child] the
/// bottom padding is the height the floor covers (home indicator included), so
/// a scroller that pads its end with `edgeToEdgeBottom(context, base)` comes
/// to rest clear of the action without knowing it is there.
///
/// The dim is a painted gradient. It is not a blur (a `BackdropFilter` over a
/// scrolling page is a full-width blur every frame) and not a `ShaderMask`
/// (an offscreen layer every frame).
class FloatingFloor extends StatefulWidget {
  const FloatingFloor({
    super.key,
    required this.child,
    required this.floor,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 16),
  });

  /// The page, laid out at full height.
  final Widget child;

  /// The floating action: one button, or a short column of them.
  final Widget floor;

  /// Around [floor]. The home indicator inset is added to its bottom.
  final EdgeInsets padding;

  @override
  State<FloatingFloor> createState() => _FloatingFloorState();
}

class _FloatingFloorState extends State<FloatingFloor> {
  /// Measured after the first layout; until then, one standard button.
  double? _floorHeight;

  void _onFloorHeight(double h) {
    if (!mounted || h == _floorHeight) return;
    setState(() => _floorHeight = h);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.padding.bottom;
    final padding = widget.padding.copyWith(
      bottom: widget.padding.bottom + inset,
    );
    final floorHeight = _floorHeight ?? padding.vertical + 52;
    final background = ThemeScope.of(context).background;
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(bottom: floorHeight),
            ),
            child: widget.child,
          ),
        ),
        // Starts clear a little above the action and never reaches opaque:
        // what is under the floor stays visible, only quieter.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: floorHeight + 40,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    background.withValues(alpha: 0),
                    background.withValues(alpha: 0.62),
                    background.withValues(alpha: 0.86),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ReportHeight(
            onHeight: _onFloorHeight,
            child: Padding(padding: padding, child: widget.floor),
          ),
        ),
      ],
    );
  }
}

/// Reports its child's laid-out height, after the frame that produced it.
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final h = size.height;
    if (h == _reported) return;
    _reported = h;
    // Not during layout: the listener rebuilds the page above us.
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(h));
  }
}
