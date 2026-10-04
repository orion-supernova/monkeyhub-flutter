import 'package:flutter/widgets.dart';

/// A short label that must never be cut: it wraps to [maxLines], and when even
/// that is not enough it shrinks — never an ellipsis, never a word broken in
/// the middle.
///
/// Built for the places a label lives in a box it does not choose: a quick-
/// action tile a quarter of the screen wide, a segment of a segmented control.
/// "Mesaj g…" and "Görünt…" on the member sheet, "Her" clipped against the mute
/// sheet's divider: both were a label asked to fit a width a translator never
/// saw. Shrinking a step is what iOS does there (`adjustsFontSizeToFitWidth`),
/// and it only happens in the rare language/text-size pair that needs it.
///
/// [FittedBox] is not the answer on its own: it lays the text out on ONE line
/// at unbounded width and then scales the whole picture, so a two-word label
/// that would have wrapped comfortably comes out tiny instead. This measures
/// the real wrap first and only then gives up size, one half-point at a time,
/// down to [minFontSize].
class FitLabel extends StatelessWidget {
  const FitLabel(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 2,
    this.minFontSize = 10,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final double minFontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        var size = style.fontSize ?? 14;
        if (width.isFinite) {
          while (size > minFontSize &&
              !_fits(style.copyWith(fontSize: size), width, scaler, dir)) {
            size -= 0.5;
          }
          // Still a word wider than the box at the floor: the engine would
          // break it mid-word ("Kaydedi / lenler" in five Turkish tabs at
          // 1.3×). Lay the label out at its longest word's width, so lines
          // only ever break between words, and scale that picture down to
          // fit. The last resort, for a language/text-size pair nobody
          // designed for — smaller beats broken.
          final floor = style.copyWith(fontSize: size);
          final longest = _longestWord(floor, scaler, dir);
          if (longest > width) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: longest.ceilToDouble(),
                child: Text(
                  text,
                  textAlign: textAlign,
                  maxLines: maxLines,
                  overflow: TextOverflow.clip,
                  style: floor,
                ),
              ),
            );
          }
        }
        return Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          // Clip, not ellipsis: at [minFontSize] with an absurd text scale
          // something has to give, and a clipped pixel reads better than a
          // "…" that hides which button this is.
          overflow: TextOverflow.clip,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }

  double _longestWord(TextStyle s, TextScaler scaler, TextDirection dir) {
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final p = TextPainter(
        text: TextSpan(text: word, style: s),
        textDirection: dir,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (p.width > widest) widest = p.width;
      p.dispose();
    }
    return widest;
  }

  bool _fits(TextStyle s, double width, TextScaler scaler, TextDirection dir) {
    // Every word on its own must fit, or the engine breaks it mid-word.
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final p = TextPainter(
        text: TextSpan(text: word, style: s),
        textDirection: dir,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      if (w > width) return false;
    }
    final p = TextPainter(
      text: TextSpan(text: text, style: s),
      textDirection: dir,
      textScaler: scaler,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final exceeded = p.didExceedMaxLines;
    p.dispose();
    return !exceeded;
  }
}
