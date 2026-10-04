import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_result_actions.dart';

void main() {
  Widget host(double width, List<String> labels) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: GameResultActions(actions: [
                  for (final (i, l) in labels.indexed)
                    GameResultAction(
                      icon: CupertinoIcons.bell_fill,
                      label: l,
                      onTap: () {},
                      prominent: i == 1,
                    ),
                ]),
              ),
            ),
          ),
        ),
      );

  // The Turkish result card: both labels ended in "…" at phone width.
  testWidgets('labels too long for half width stack instead of truncating',
      (tester) async {
    await tester.pumpWidget(host(300, ['Sonucu kopyala', 'Arkadaşlara söyle']));
    final copy = tester.getCenter(find.text('Sonucu kopyala'));
    final tell = tester.getCenter(find.text('Arkadaşlara söyle'));
    expect(copy.dy, isNot(tell.dy), reason: 'stacked, one per row');
    expect(tell.dy, lessThan(copy.dy), reason: 'the prominent action leads');
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      expect(t.overflow, isNot(TextOverflow.ellipsis));
    }
  });

  testWidgets('short labels share a row', (tester) async {
    await tester.pumpWidget(host(360, ['Copy', 'Tell']));
    expect(
      tester.getCenter(find.text('Copy')).dy,
      tester.getCenter(find.text('Tell')).dy,
    );
  });
}
