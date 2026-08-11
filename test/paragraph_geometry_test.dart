import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/paragraph_geometry.dart';

/// [paragraphRectsFor] on its own, against a real laid-out paragraph.
///
/// Testing the function rather than either widget that uses it: the seam
/// fixes and the descend-to-the-paragraph walk are the parts that are easy to
/// get wrong and impossible to see from outside a `CustomPaint`.
void main() {
  const style = TextStyle(fontSize: 16, color: Color(0xFF000000));

  /// Lays out [span] at [width] and returns the geometry for [ranges].
  ///
  /// The probe is a `Positioned.fill` sibling of the paragraph — exactly the
  /// arrangement both real callers use — so the host box it measures against
  /// is the one they'd actually pass.
  Future<List<List<Rect>>> measure(
    WidgetTester tester, {
    required InlineSpan span,
    required List<({int start, int end})> ranges,
    double width = 400,
    double insetX = 0,
    double insetY = 0,
    Widget Function(Widget text)? wrap,
  }) async {
    final paragraphKey = GlobalKey();
    final hostKey = GlobalKey();
    final Widget text = Text.rich(span, key: paragraphKey);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: width,
            child: Stack(
              children: [
                wrap == null ? text : wrap(text),
                Positioned.fill(child: SizedBox.expand(key: hostKey)),
              ],
            ),
          ),
        ),
      ),
    );

    return paragraphRectsFor(
      paragraphKey: paragraphKey,
      host: hostKey.currentContext!.findRenderObject() as RenderBox,
      ranges: ranges,
      insetX: insetX,
      insetY: insetY,
    );
  }

  testWidgets('a range on one line is one group of one rect', (tester) async {
    final out = await measure(
      tester,
      span: const TextSpan(text: 'hello there world', style: style),
      ranges: const [(start: 6, end: 11)],
    );

    expect(out, hasLength(1));
    expect(out.single, hasLength(1));
    expect(out.single.single.width, greaterThan(0));
    expect(out.single.single.height, greaterThan(0));
  });

  testWidgets('one group per range, in the order asked for', (tester) async {
    final out = await measure(
      tester,
      span: const TextSpan(text: 'alpha beta gamma delta', style: style),
      ranges: const [(start: 0, end: 5), (start: 11, end: 16)],
    );

    expect(out, hasLength(2));
    expect(out[0].single.left, lessThan(out[1].single.left));
  });

  testWidgets('a wrapped range yields one rect per line, same height',
      (tester) async {
    final out = await measure(
      tester,
      // Narrow enough that this cannot sit on one line at 16px.
      width: 120,
      span: const TextSpan(
        text: 'wrap me across several distinct lines please',
        style: style,
      ),
      ranges: const [(start: 0, end: 43)],
    );

    final rects = out.single;
    expect(rects.length, greaterThanOrEqualTo(2));
    for (final r in rects) {
      expect(r.height, closeTo(rects.first.height, 0.01));
    }
    // Distinct lines, top to bottom, never overlapping vertically.
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].bottom - 0.01));
    }
  });

  testWidgets('style boundaries inside a range coalesce into one rect',
      (tester) async {
    // Three runs on one line. `getBoxesForSelection` returns a box per run,
    // and painting them separately leaves hairline seams between the words.
    final out = await measure(
      tester,
      span: const TextSpan(style: style, children: [
        TextSpan(text: 'aaa'),
        TextSpan(text: 'bbb', style: TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: 'ccc'),
      ]),
      ranges: const [(start: 0, end: 9)],
    );

    expect(
      out.single,
      hasLength(1),
      reason: 'three same-line boxes must fuse; got ${out.single}',
    );
  });

  testWidgets('a negative inset grows each rect by twice its magnitude',
      (tester) async {
    const span = TextSpan(text: 'measure this bit', style: style);
    const ranges = [(start: 8, end: 12)];

    final plain = await measure(tester, span: span, ranges: ranges);
    final grown = await measure(
      tester,
      span: span,
      ranges: ranges,
      insetX: -3.5,
      insetY: -1,
    );

    expect(grown.single.single.width, closeTo(plain.single.single.width + 7, 0.01));
    expect(grown.single.single.height, closeTo(plain.single.single.height + 2, 0.01));
  });

  testWidgets('a positive inset that would invert a rect drops it',
      (tester) async {
    final out = await measure(
      tester,
      span: const TextSpan(text: 'tiny', style: style),
      ranges: const [(start: 0, end: 1)],
      insetX: 400,
    );
    expect(out.single, isEmpty);
  });

  testWidgets('the paragraph is found behind a wrapping render object',
      (tester) async {
    // `Text` wraps ITSELF in a MouseRegion under a SelectionArea, so the key's
    // render object stops being the paragraph. A single cast returns null
    // there, the veil stops mounting, and spoilers render as readable text.
    final out = await measure(
      tester,
      span: const TextSpan(text: 'behind a proxy box', style: style),
      ranges: const [(start: 0, end: 6)],
      wrap: (text) => Padding(padding: EdgeInsets.zero, child: text),
    );

    expect(out.single, hasLength(1));
    expect(out.single.single.width, greaterThan(0));
  });

  testWidgets('an unmounted key measures to nothing, not to garbage',
      (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final out = paragraphRectsFor(
      paragraphKey: GlobalKey(),
      host: tester.renderObject<RenderBox>(find.byType(SizedBox)),
      ranges: const [(start: 0, end: 1)],
    );
    expect(out, isEmpty);
  });

  testWidgets('no ranges measures to nothing', (tester) async {
    final out = await measure(
      tester,
      span: const TextSpan(text: 'nothing asked for', style: style),
      ranges: const [],
    );
    expect(out, isEmpty);
  });
}
