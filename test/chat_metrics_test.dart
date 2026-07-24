import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/layout.dart';

/// [ChatMetrics.forPane] is a pure function, so the whole responsive contract
/// can be pinned without building a widget tree. These tests exist mainly to
/// catch the two failure modes that motivated the pane-derived rewrite: a
/// bubble wider than the pane it sits in, and a column narrower than the space
/// available to it.
void main() {
  ChatMetrics compact(double w) => ChatMetrics.forPane(w, WindowClass.compact);
  ChatMetrics wide(double w) => ChatMetrics.forPane(w, WindowClass.expanded);

  group('phones are untouched', () {
    test('a 390pt phone keeps its 0.72 bubble and 240/320/280 media', () {
      final m = compact(390);
      expect(m.paneWidth, 390); // not quantized on compact
      expect(m.columnWidth, 390); // fills
      expect(m.columnFillsPane, isTrue); // ChatColumn is a passthrough
      expect(m.bubbleMaxWidth, closeTo(280.8, 0.01)); // 390 * 0.72, as before
      expect(m.mediaMaxWidth, ChatMetrics.mediaMin); // clamped to the old 240
      expect(m.linkPreviewWidth, ChatMetrics.linkMin); // the old 320
      expect(m.videoMaxWidth, ChatMetrics.videoMin); // the old 280
    });

    test('every real phone width stays on the old media literals', () {
      // 320 (SE) through 430 (Pro Max) — anything wider is a desktop window,
      // where letting media grow a little is the point.
      for (final w in const [320.0, 375.0, 390.0, 414.0, 428.0, 430.0]) {
        final m = compact(w);
        expect(m.bubbleMaxWidth, closeTo(w * 0.72, 0.01), reason: 'at $w');
        expect(m.mediaMaxWidth, ChatMetrics.mediaMin, reason: 'at $w');
        expect(m.linkPreviewWidth, ChatMetrics.linkMin, reason: 'at $w');
        expect(m.videoMaxWidth, ChatMetrics.videoMin, reason: 'at $w');
      }
    });
  });

  group('wide panes', () {
    test('quantizes DOWN so the column never exceeds the real pane', () {
      expect(wide(1000).paneWidth, 992);
      expect(wide(1023).paneWidth, 992);
      expect(wide(1024).paneWidth, 1024);
    });

    test('fills the pane below surfaceMax, then caps', () {
      expect(wide(576).columnWidth, 576);
      expect(wide(576).columnFillsPane, isTrue);
      expect(wide(992).columnWidth, 992);
      expect(wide(1472).columnWidth, ChatMetrics.surfaceMax);
      expect(wide(1472).columnFillsPane, isFalse);
    });

    test('the 1024px-window case that started this: pane ~580', () {
      // window 1024 - 84 (side rail) - 360 (room list) - 0.5 (divider)
      final m = wide(579.5);
      expect(m.paneWidth, 576);
      // Was a flat 560 in a 580px pane — 97% of it, edge to edge.
      expect(m.bubbleMaxWidth, closeTo(241.9, 0.1));
      expect(m.bubbleMaxWidth / m.paneWidth, lessThan(0.45));
    });

    test('bubble saturates at bubbleMax on big monitors', () {
      expect(wide(992).bubbleMaxWidth, ChatMetrics.bubbleMax);
      expect(wide(1472).bubbleMaxWidth, ChatMetrics.bubbleMax);
      expect(wide(2112).bubbleMaxWidth, ChatMetrics.bubbleMax);
      // The cap is a wrap point, not a width: it must stay well short of the
      // column so a sent and a received bubble still read as a conversation.
      expect(ChatMetrics.bubbleMax, lessThan(ChatMetrics.surfaceMax * 0.4));
    });

    test('media grows with the bubble but stays inside it', () {
      final m = wide(1472);
      expect(m.mediaMaxWidth, greaterThan(ChatMetrics.mediaMin));
      expect(m.linkPreviewWidth, greaterThanOrEqualTo(ChatMetrics.linkMin));
      expect(m.videoMaxWidth, greaterThan(ChatMetrics.videoMin));
      expect(m.mediaMaxWidth, lessThanOrEqualTo(m.bubbleMaxWidth));
      expect(m.linkPreviewWidth, lessThanOrEqualTo(m.bubbleMaxWidth));
      expect(m.videoMaxWidth, lessThanOrEqualTo(m.bubbleMaxWidth));
    });
  });

  group('invariants across the whole range', () {
    test('column fits the pane, bubble fits the column, both monotonic', () {
      ChatMetrics? prev;
      for (var w = 320.0; w <= 3000; w += 8) {
        final m = wide(w);
        expect(m.columnWidth, lessThanOrEqualTo(w),
            reason: 'column must fit the pane at $w');
        expect(m.bubbleMaxWidth, lessThanOrEqualTo(m.columnWidth),
            reason: 'bubble must fit the column at $w');
        if (prev != null) {
          expect(m.columnWidth, greaterThanOrEqualTo(prev.columnWidth));
          expect(m.bubbleMaxWidth, greaterThanOrEqualTo(prev.bubbleMaxWidth));
        }
        prev = m;
      }
    });

    test('identity is stable within a quantum — the rebuild gate', () {
      // ChatMetricsScope.updateShouldNotify compares by value, so equal
      // metrics across a drag mean zero rebuilds.
      expect(wide(900), wide(915)); // same 32px bucket
      expect(wide(900), isNot(wide(940))); // next bucket, column really moved
      // Past surfaceMax every consumed value saturates, so an arbitrarily
      // large drag compares equal and rebuilds nothing.
      expect(wide(1600), wide(1900));
      expect(wide(1600).hashCode, wide(1900).hashCode);
      // ...but the pane crossing surfaceMax does flip columnFillsPane, which
      // changes whether ChatColumn is a passthrough.
      expect(wide(1152), isNot(wide(1216)));
    });
  });
}
