import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/matches_api.dart';
import 'package:monkeyhub/data/matches_store.dart';
import 'package:monkeyhub/fight/core/core.dart';
import 'package:monkeyhub/fight/view/art/stages/stages.dart';
import 'package:monkeyhub/fight/view/fight_online_screen.dart';
import 'package:monkeyhub/fight/view/fight_stage_picker.dart';
import 'package:monkeyhub/games/catalog.dart' show isFreeFighter;
import 'package:monkeyhub/fight/view/fighter_portrait.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// The lobby's live picks: each seat publishes its fighter (the host also its
/// stage) to the match, debounced, and draws what the other seat published.

final String? shotDir = Platform.environment['FIGHT_SHOTS'];

class _Api extends Fake implements MatchesApi {
  void Function(ChatMatch?)? push;
  final sent = <({int? pick, int? stage})>[];
  bool refuse = false;

  @override
  Future<void Function()> watch(String userId, String matchId, void Function(ChatMatch?) onData, {void Function(Object)? onError}) async {
    push = onData;
    return () {};
  }

  @override
  Future<void Function()> watchHistory(String userId, String matchId, void Function(MatchHistory?) onData, {void Function(Object)? onError}) async => () {};

  @override
  Future<void> beat(String userId, String matchId) async {}

  @override
  Future<void> away(String userId, String matchId) async {}

  @override
  Future<void> leave(String userId, String matchId) async {}

  @override
  Future<void> setPick(String userId, String matchId, {int? pick, int? stage}) async {
    if (refuse) throw Exception('Could not find public function for matches:setPick');
    sent.add((pick: pick, stage: stage));
  }
}

ChatMatch _lobby({int? hostPick, int? hostStage, int? guestPick}) => ChatMatch.fromJson({
  'id': 'm1',
  'roomId': 'r1',
  'game': 'fight',
  'mode': 'live',
  'status': 'lobby',
  'seq': 0,
  'createdBy': 'host',
  'createdAt': 0,
  'seats': [
    {'userId': 'host', 'name': 'murat', 'ready': false, 'pick': ?hostPick, 'stage': ?hostStage},
    {'userId': 'guest', 'name': 'zeynep', 'ready': false, 'pick': ?guestPick},
  ],
})!;

Widget _app(String userId, ChatMatch initial, Key key) => MaterialApp(
  localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
  supportedLocales: AppLocalizations.supportedLocales,
  home: ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: RepaintBoundary(key: key, child: FightOnlineScreen(matchId: 'm1', userId: userId, initial: initial)),
  ),
);

int? _rightCardChar(WidgetTester tester) => tester.widgetList<FightSeatCard>(find.byType(FightSeatCard)).last.charId;

void main() {
  late _Api api;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = _Api();
    MatchesStore.instance.api = api;
  });

  testWidgets('the guest watches the host pick a fighter and a stage', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(_app('guest', _lobby(), key));
    await tester.pump(const Duration(milliseconds: 50));

    // Nothing published yet: the old hidden card, and the old line of text.
    expect(_rightCardChar(tester), isNull);
    expect(find.byType(FightStagePicker), findsNothing);

    api.push!(_lobby(hostPick: 3, hostStage: 2));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_rightCardChar(tester), 3);
    final stage = tester.widget<FightStagePicker>(find.byType(FightStagePicker));
    expect(stage.readOnly, isTrue);
    expect(stage.selected, 2);

    api.push!(_lobby(hostPick: 7, hostStage: kFightStageRandom));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_rightCardChar(tester), 7);
    expect(tester.widget<FightStagePicker>(find.byType(FightStagePicker)).selected, kFightStageRandom);
    expect(tester.takeException(), isNull);

    if (shotDir != null) {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(shotDir!).createSync(recursive: true);
        File('$shotDir/lobby_guest_live.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a seat publishes its choice once it settles, not per tap', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app('guest', _lobby(), GlobalKey()));
    await tester.pump(const Duration(milliseconds: 50));

    // Sitting down publishes what is already chosen.
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.sent, hasLength(1));
    final first = api.sent.single.pick!;
    expect(api.sent.single.stage, isNull, reason: 'the stage is the host\'s');
    api.push!(_lobby(guestPick: first));
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.sent, hasLength(1), reason: 'the match already shows it');

    // Three quick taps across the grid: one write, the last fighter. Free
    // fighters only: a locked one opens the unlock sheet instead of picking.
    final others = [for (final c in roster) if (c.id != first && isFreeFighter(c.id)) c.id].take(3).toList();
    for (final id in others) {
      await tester.tap(find.byKey(ValueKey('fight_char_$id')));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.sent, hasLength(2));
    expect(api.sent.last.pick, others.last);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a server without live picks is asked once, then left alone', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    api.refuse = true;
    await tester.pumpWidget(_app('host', _lobby(), GlobalKey()));
    await tester.pump(const Duration(milliseconds: 500));
    api.refuse = false;
    api.push!(_lobby());
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.sent, isEmpty);
    expect(find.byType(FighterPortrait), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
