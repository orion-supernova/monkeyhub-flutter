import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/edge_bleed.dart';

/// A row that has to reach the edges of a list that is padded away from them.
///
/// The unread band in a transcript is the case. `width: double.infinity` inside
/// `ListView(padding: …)` only ever fills the padded box, so the band stopped
/// 20pt short at each end and read as one more object floating in the column
/// rather than a rule drawn across the conversation.
///
/// The second test is the reason this is a `FractionallySizedBox` and not the
/// `OverflowBox` anyone would reach for first: an `OverflowBox` is sized by its
/// parent, and the height constraint a sliver hands a row is unbounded.
void main() {
  const pad = EdgeInsets.fromLTRB(20, 8, 20, 8);
  const marker = Key('band');

  Widget host({
    EdgeInsets padding = pad,
    EdgeInsets bleed = pad,
    double width = 400,
  }) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Center(
            child: SizedBox(
              width: width,
              height: 800,
              child: ListView(
                padding: padding,
                children: [
                  const SizedBox(height: 40),
                  EdgeBleed(
                    bleed: bleed,
                    child: Container(
                      key: marker,
                      width: double.infinity,
                      height: 24,
                      color: const Color(0xFF00FF00),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('the child spans the list, padding and all', (tester) async {
    await tester.pumpWidget(host());
    final list = tester.getRect(find.byType(ListView));
    final band = tester.getRect(find.byKey(marker));
    expect(band.left, moreOrLessEquals(list.left));
    expect(band.right, moreOrLessEquals(list.right));
    expect(band.width, moreOrLessEquals(400));
  });

  testWidgets('the row itself keeps the height its child asked for', (tester) async {
    await tester.pumpWidget(host());
    // The OverflowBox failure mode: sized by the parent, which in a sliver is
    // unbounded, so this would be Infinity — or an assertion, not a number.
    final bled = tester.getRect(find.byType(EdgeBleed));
    expect(bled.height, 24);
    expect(bled.width, moreOrLessEquals(360), reason: 'the ROW stays padded');
  });

  testWidgets('an asymmetric bleed still lands flush on both sides', (tester) async {
    const lopsided = EdgeInsets.fromLTRB(40, 8, 8, 8);
    await tester.pumpWidget(host(padding: lopsided, bleed: lopsided));
    final list = tester.getRect(find.byType(ListView));
    final band = tester.getRect(find.byKey(marker));
    expect(band.left, moreOrLessEquals(list.left));
    expect(band.right, moreOrLessEquals(list.right));
  });

  testWidgets('nothing to escape is a passthrough', (tester) async {
    await tester.pumpWidget(host(padding: EdgeInsets.zero, bleed: EdgeInsets.zero));
    final band = tester.getRect(find.byKey(marker));
    expect(band.width, moreOrLessEquals(400));
    expect(find.byType(FractionallySizedBox), findsNothing);
  });
}
