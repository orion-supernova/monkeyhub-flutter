import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/chat_bottom_inset.dart';

/// The measure-and-spend mechanism under the room's floating composer, on its
/// own. `composer_multiline_inset_test.dart` proves the room uses it correctly;
/// this proves the parts behave, including the ones that only ever misbehave
/// mid-animation or under a profiler:
///
///  * the reservation is the LARGER of where the chrome is and where it is
///    going, which is what makes it right in both directions — see
///    [ChatChromeHeight];
///  * an unchanged reservation must cost NOTHING, because the chrome relayouts
///    on every frame of a growth and a listenable that fired on equal values
///    would rebuild the transcript ten times for one new line;
///  * the first frame must spend the estimate, not zero, or every room opens
///    with its newest message in the wrong place and corrects itself;
///  * a null chrome must not even add a listener, which is what keeps the
///    classic chat style exactly as cheap as it was.
void main() {
  /// Mounts a chrome of [drawn] painted height around a child of [target]
  /// natural height — the two heights an `AnimatedSize` mid-flight has.
  Future<void> mount(
    WidgetTester t,
    ChatBottomInset inset, {
    required double drawn,
    required double target,
  }) =>
      t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: MeasureChatBottomInset(
              inset: inset,
              which: ChatChromeHeight.drawn,
              // Stands in for AnimatedSize: sizes itself, lets the child take
              // its own height, clips the difference.
              child: SizedBox(
                height: drawn,
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  maxHeight: double.infinity,
                  child: MeasureChatBottomInset(
                    inset: inset,
                    which: ChatChromeHeight.target,
                    child: SizedBox(height: target, width: 200),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets(
      'reserves the larger of where the chrome is and where it is going',
      (t) async {
    final inset = ChatBottomInset();
    addTearDown(inset.dispose);

    await mount(t, inset, drawn: 60, target: 60);
    expect(inset.height, 60,
        reason: 'published at the END of the frame it was measured in — the '
            'transcript then reads it on the next one');

    // Mid-GROW: the field has wrapped, the glass has not caught up. Reserving
    // the drawn height here is what used to leave the newest bubble behind it.
    await mount(t, inset, drawn: 80, target: 142);
    expect(inset.height, 142);

    await mount(t, inset, drawn: 142, target: 142);
    expect(inset.height, 142);

    // Mid-SHRINK: the field is back to one line, the glass is still on its way
    // down. Reserving the target here would drop the transcript underneath it.
    await mount(t, inset, drawn: 110, target: 60);
    expect(inset.height, 110);

    await mount(t, inset, drawn: 60, target: 60);
    expect(inset.height, 60, reason: 'and it lands exactly where it started');
  });

  testWidgets('an unchanged reservation notifies nobody', (t) async {
    final inset = ChatBottomInset();
    addTearDown(inset.dispose);
    var notifications = 0;
    inset.addListener(() => notifications++);

    await mount(t, inset, drawn: 60, target: 60);
    expect(notifications, 1);

    // Five frames of a grow animation: the glass creeps up under a target that
    // already covers it. Every one of these is a real measurement, and not one
    // of them changes what the transcript must reserve.
    await mount(t, inset, drawn: 60, target: 142);
    final afterTarget = notifications;
    for (final drawn in [70.0, 90.0, 110.0, 125.0, 138.0]) {
      await mount(t, inset, drawn: drawn, target: 142);
    }
    expect(notifications, afterTarget,
        reason: 'the whole grow animation must be free once the room is open');
  });

  testWidgets('the estimate stands in until the first measurement lands',
      (t) async {
    final inset = ChatBottomInset();
    addTearDown(inset.dispose);
    final seen = <double>[];

    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ChatBottomInsetBuilder(
          chrome: (inset: inset, estimate: 94),
          builder: (context, value, _) {
            seen.add(value);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(seen, [94]);

    inset.report(ChatChromeHeight.drawn, 131);
    await t.pump();
    expect(seen.last, 131,
        reason: 'the measurement supersedes the estimate for good');
  });

  testWidgets('a null chrome spends nothing and listens to nothing', (t) async {
    double? seen;

    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ChatBottomInsetBuilder(
          chrome: null,
          builder: (context, value, _) {
            seen = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(seen, 0);
    expect(find.byType(ListenableBuilder), findsNothing,
        reason: 'the classic style must not pay for a listener it never reads');
  });

  testWidgets('the passthrough child survives an inset change', (t) async {
    final inset = ChatBottomInset();
    addTearDown(inset.dispose);
    var childBuilds = 0;

    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ChatBottomInsetBuilder(
          chrome: (inset: inset, estimate: 60),
          builder: (context, value, child) =>
              Padding(padding: EdgeInsets.only(bottom: value), child: child),
          child: Builder(builder: (context) {
            childBuilds++;
            return const SizedBox.shrink();
          }),
        ),
      ),
    );
    expect(childBuilds, 1);

    inset.report(ChatChromeHeight.target, 140);
    await t.pump();
    expect(childBuilds, 1,
        reason:
            'the pills carry their own animations and have no business being '
            'rebuilt because somebody typed a line');
  });

  testWidgets('a swapped inset is brought up to date, not left blank',
      (t) async {
    final first = ChatBottomInset();
    final second = ChatBottomInset();
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget host(ChatBottomInset inset) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: MeasureChatBottomInset(
              inset: inset,
              which: ChatChromeHeight.drawn,
              child: const SizedBox(height: 60, width: 200),
            ),
          ),
        );

    await t.pumpWidget(host(first));
    expect(first.height, 60);

    // Same render object, new inset: the height is unchanged, so anything that
    // deduplicated on the height alone would leave the new one blank and the
    // transcript spending an estimate forever.
    await t.pumpWidget(host(second));
    expect(second.height, 60);
  });
}
