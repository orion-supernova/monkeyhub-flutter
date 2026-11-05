import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/view/art/stages/stages.dart';
import 'package:monkeyhub/fight/view/fight_stage_picker.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
  supportedLocales: AppLocalizations.supportedLocales,
  home: ThemeScope(controller: ThemeController(BasicTheme.midnight()), child: Scaffold(body: Center(child: child))),
);

void main() {
  testWidgets('tapping a stage card reports its id; Random reports -1', (tester) async {
    int? picked;
    await tester.pumpWidget(_host(FightStagePicker(selected: 0, onPick: (i) => picked = i)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('fight_stage_2')));
    expect(picked, 2);
    await tester.tap(find.byKey(const ValueKey('fight_stage_-1')));
    expect(picked, kFightStageRandom);
  });

  testWidgets('read-only shows only the chosen stage and ignores taps', (tester) async {
    int? picked;
    await tester.pumpWidget(_host(FightStagePicker(selected: 3, onPick: (i) => picked = i, readOnly: true)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Aurora Shrine'), findsOneWidget);
    expect(find.text('Rooftop'), findsNothing);
    await tester.tap(find.text('Aurora Shrine'));
    expect(picked, isNull);
  });

  test('stage ids clamp and Random resolves to a real stage', () {
    expect(fightStageOf(99), 0);
    expect(fightStageOf(-1), 0);
    for (var i = 0; i < 40; i++) {
      final id = fightStageResolve(kFightStageRandom);
      expect(id, inInclusiveRange(0, kFightStages.length - 1));
    }
    expect(fightStageResolve(4), 4);
  });
}
