import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/reaction_bubble.dart';

void main() {
  group('HangingReactions', () {
    testWidgets('climbs over the box above without leaving a gap', (tester) async {
      var bubbleTaps = 0;
      var chipTaps = 0;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => bubbleTaps++,
                child: const SizedBox(key: Key('bubble'), width: 100, height: 40),
              ),
              HangingReactions(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => chipTaps++,
                  child: const SizedBox(key: Key('chip'), width: 30, height: 24),
                ),
              ),
              const SizedBox(key: Key('next'), width: 10, height: 10),
            ],
          ),
        ),
      ));

      final chip = tester.getRect(find.byKey(const Key('chip')));
      expect(chip.top, 40 - kReactionOverlap);
      // The next row starts where the chip ends — no reserved gap.
      expect(tester.getTopLeft(find.byKey(const Key('next'))).dy, chip.bottom);

      // A tap in the overlapped strip goes to the chip, not the bubble.
      await tester.tapAt(Offset(10, 40 - kReactionOverlap / 2));
      expect(chipTaps, 1);
      expect(bubbleTaps, 0);

      // Above the overlap, the bubble still owns its own taps.
      await tester.tapAt(const Offset(10, 20));
      expect(bubbleTaps, 1);
    });
  });

  group('quickPillEmojis', () {
    test('the quick six when nothing outside them is mine', () {
      expect(quickPillEmojis({}), hasLength(6));
      expect(quickPillEmojis({'👍'}), quickPillEmojis({}));
    });

    test('my other reactions take the trailing unselected slots', () {
      final out = quickPillEmojis({'🔥', '🤯', '🫠'});
      expect(out, hasLength(6));
      expect(out, containsAll(['🔥', '🤯', '🫠']));
      // 🔥 is a quick one I chose, so it keeps its slot.
      expect(out.first, '👍');
    });
  });
}
