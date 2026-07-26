import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';

/// The bubble outline is the one piece of chat geometry with no visible call
/// site: the widget hands a `ShapeDecoration` to a `Container` and everything
/// after that is a path. These pin the parts that are easy to get subtly wrong
/// and impossible to notice in a diff.
void main() {
  final theme = BasicTheme.midnight();

  BubbleShape shapeFor({
    required BubbleStyle style,
    required bool isMine,
    bool firstInRun = true,
    bool lastInRun = true,
  }) =>
      theme.bubbleShape(
        isMine: isMine,
        ephemeral: false,
        style: style,
        firstInRun: firstInRun,
        lastInRun: lastInRun,
      );

  double large() {
    final authored = theme
        .messageBubbleDecoration(isMine: true, ephemeral: false)
        .borderRadius!
        .resolve(TextDirection.ltr);
    return [
      authored.topLeft.x,
      authored.topRight.x,
      authored.bottomLeft.x,
      authored.bottomRight.x,
    ].reduce((a, b) => a > b ? a : b);
  }

  double small() {
    final authored = theme
        .messageBubbleDecoration(isMine: true, ephemeral: false)
        .borderRadius!
        .resolve(TextDirection.ltr);
    return [
      authored.topLeft.x,
      authored.topRight.x,
      authored.bottomLeft.x,
      authored.bottomRight.x,
    ].reduce((a, b) => a < b ? a : b);
  }

  group('run position', () {
    test('only the row that closes a run carries the tail', () {
      expect(shapeFor(style: BubbleStyle.tailed, isMine: true).tail, isTrue);
      expect(
        shapeFor(style: BubbleStyle.tailed, isMine: true, lastInRun: false).tail,
        isFalse,
      );
      expect(
        shapeFor(
                style: BubbleStyle.tailed,
                isMine: true,
                firstInRun: false,
                lastInRun: false)
            .tail,
        isFalse,
      );
    });

    test('the tail-less styles never draw one', () {
      for (final style in [
        BubbleStyle.soft,
        BubbleStyle.pill,
        BubbleStyle.slab
      ]) {
        expect(shapeFor(style: style, isMine: true).tail, isFalse);
      }
    });

    test('the sender-side corners tighten inside a run, the far side never',
        () {
      final middle = shapeFor(
        style: BubbleStyle.tailed,
        isMine: true,
        firstInRun: false,
        lastInRun: false,
      ).radii;
      expect(middle.topRight.x, small(), reason: 'sender top tightens');
      expect(middle.bottomRight.x, small(), reason: 'sender bottom tightens');
      expect(middle.topLeft.x, large(), reason: 'far side stays round');
      expect(middle.bottomLeft.x, large(), reason: 'far side stays round');
    });

    test('incoming mirrors outgoing', () {
      final mine = shapeFor(
        style: BubbleStyle.tailed,
        isMine: true,
        firstInRun: false,
      ).radii;
      final theirs = shapeFor(
        style: BubbleStyle.tailed,
        isMine: false,
        firstInRun: false,
      ).radii;
      expect(theirs.topLeft, mine.topRight);
      expect(theirs.topRight, mine.topLeft);
      expect(theirs.bottomLeft, mine.bottomRight);
      expect(theirs.bottomRight, mine.bottomLeft);
    });

    test('a bubble on its own is fully round on the sender side, with a tail',
        () {
      final single = shapeFor(style: BubbleStyle.tailed, isMine: true);
      expect(single.tail, isTrue);
      expect(single.radii.topRight.x, large());
      expect(single.radii.bottomRight.x, large());
    });
  });

  group('tail gutter', () {
    test('only the tailed style reserves one', () {
      expect(theme.bubbleTailGutter(BubbleStyle.tailed), greaterThan(0));
      expect(theme.bubbleTailGutter(BubbleStyle.soft), 0);
      expect(theme.bubbleTailGutter(BubbleStyle.pill), 0);
      expect(theme.bubbleTailGutter(BubbleStyle.slab), 0);
    });

    test('is reserved on every row of a run, tail or not', () {
      // This is what keeps the bodies of a run flush with one another — only
      // the hook itself reaches into the strip.
      final closing = shapeFor(style: BubbleStyle.tailed, isMine: true);
      final middle = shapeFor(
        style: BubbleStyle.tailed,
        isMine: true,
        firstInRun: false,
        lastInRun: false,
      );
      expect(middle.tailWidth, closing.tailWidth);
    });

    test('insets the child on the sender side only', () {
      final side = theme
              .messageBubbleDecoration(isMine: true, ephemeral: false)
              .border is Border
          ? (theme.messageBubbleDecoration(isMine: true, ephemeral: false).border
                  as Border)
              .top
              .width
          : 0.0;
      final mine = shapeFor(style: BubbleStyle.tailed, isMine: true);
      final insets = mine.dimensions.resolve(TextDirection.ltr);
      expect(insets.right, side + mine.tailWidth);
      expect(insets.left, side);

      final theirs = shapeFor(style: BubbleStyle.tailed, isMine: false);
      final theirInsets = theirs.dimensions.resolve(TextDirection.ltr);
      expect(theirInsets.left, side + theirs.tailWidth);
      expect(theirInsets.right, side);
    });
  });

  group('outline', () {
    const rect = Rect.fromLTWH(0, 0, 200, 44);

    test('the body stops at the gutter and only the hook crosses it', () {
      final closing = shapeFor(style: BubbleStyle.tailed, isMine: true);
      final middle = shapeFor(
        style: BubbleStyle.tailed,
        isMine: true,
        lastInRun: false,
      );
      expect(closing.getOuterPath(rect).getBounds().right,
          closeTo(rect.right, 0.5));
      expect(
        middle.getOuterPath(rect).getBounds().right,
        closeTo(rect.right - middle.tailWidth, 0.5),
      );
    });

    test('an incoming bubble hangs its tail off the left instead', () {
      final closing = shapeFor(style: BubbleStyle.tailed, isMine: false);
      final middle = shapeFor(
        style: BubbleStyle.tailed,
        isMine: false,
        lastInRun: false,
      );
      // The hook reaches the left edge; the body's own left edge sits a
      // gutter in, on every row of the run.
      expect(closing.getOuterPath(rect).getBounds().left,
          closeTo(rect.left, 0.5));
      expect(
        middle.getOuterPath(rect).getBounds().left,
        closeTo(rect.left + middle.tailWidth, 0.5),
      );
      expect(closing.getOuterPath(rect).getBounds().right,
          closeTo(rect.right, 0.5));
    });

    test('stays inside its rect even when the radius exceeds the height', () {
      // `pill` asks for a radius far larger than a one-line bubble is tall.
      final pill = shapeFor(style: BubbleStyle.pill, isMine: true);
      const short = Rect.fromLTWH(0, 0, 60, 20);
      final bounds = pill.getOuterPath(short).getBounds();
      expect(bounds.width, lessThanOrEqualTo(short.width + 0.01));
      expect(bounds.height, lessThanOrEqualTo(short.height + 0.01));
    });

    test('degenerate rects do not throw', () {
      final mine = shapeFor(style: BubbleStyle.tailed, isMine: true);
      expect(() => mine.getOuterPath(Rect.zero), returnsNormally);
      expect(
        () => mine.getOuterPath(const Rect.fromLTWH(0, 0, 2, 2)),
        returnsNormally,
      );
    });
  });

  test('identical shapes compare equal, so bubbles do not repaint per frame',
      () {
    expect(
      shapeFor(style: BubbleStyle.tailed, isMine: true),
      shapeFor(style: BubbleStyle.tailed, isMine: true),
    );
    expect(
      shapeFor(style: BubbleStyle.tailed, isMine: true),
      isNot(shapeFor(style: BubbleStyle.tailed, isMine: true, lastInRun: false)),
    );
  });

  test('slab and pill ignore run position entirely', () {
    for (final style in [BubbleStyle.pill, BubbleStyle.slab]) {
      expect(
        shapeFor(style: style, isMine: true, firstInRun: false),
        shapeFor(style: style, isMine: true),
        reason: '$style should look the same on every row',
      );
    }
  });
}
