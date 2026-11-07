import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/chat_games/go_live.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Going live from a turn by turn duel: the row's side of it, and the three
/// widgets (offer, question, ignite) drawing without throwing.
void main() {
  ChatMatch row(Map<String, dynamic> extra) => ChatMatch.fromJson({
    'id': 'm1',
    'roomId': 'r1',
    'game': 'tictactoe',
    'mode': 'async',
    'status': 'active',
    'seats': [
      {'userId': 'a', 'name': 'Ada'},
      {'userId': 'b', 'name': 'Bob'},
    ],
    'state': 's',
    'seq': 3,
    'turnSeat': 1,
    'createdBy': 'a',
    'createdAt': 0,
    ...extra,
  })!;

  test('parses a request and a decline; an older server reads as none', () {
    final m = row({
      'liveRequest': {'seat': 0, 'at': 1000},
      'liveDeclined': {'seat': 1, 'at': 500},
    });
    expect(m.liveRequestSeat, 0);
    expect(m.liveRequestAt, DateTime.fromMillisecondsSinceEpoch(1000));
    expect(m.liveDeclinedSeat, 1);
    final old = row({});
    expect(old.liveRequestSeat, isNull);
    expect(old.liveDeclinedAt, isNull);
  });

  test('only a seated player of an active async duel may ask', () {
    expect(row({}).canAskLive('a'), isTrue);
    expect(row({}).canAskLive('b'), isTrue);
    expect(row({}).canAskLive('z'), isFalse);
    expect(row({'mode': 'live'}).canAskLive('a'), isFalse);
    expect(row({'status': 'finished'}).canAskLive('a'), isFalse);
    expect(row({'status': 'paused'}).canAskLive('a'), isFalse);
    expect(row({'game': 'liarsdice'}).canAskLive('a'), isFalse);
  });

  test('a fresh decline hides the offer from the decliner only', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final m = row({'liveDeclined': {'seat': 0, 'at': now}});
    expect(m.canAskLive('a'), isFalse);
    expect(m.canAskLive('b'), isTrue);
    final old = row({
      'liveDeclined': {
        'seat': 0,
        'at': now - kLiveRequestCooldown.inMilliseconds - 1000,
      },
    });
    expect(old.canAskLive('a'), isTrue);
  });

  Widget host(Widget child, {bool calm = false}) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: calm),
      child: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          body: RepaintBoundary(
            key: const Key('shot'),
            child: Container(
              color: const Color(0xFF101014),
              padding: const EdgeInsets.all(16),
              child: Align(alignment: Alignment.topCenter, child: child),
            ),
          ),
        ),
      ),
    ),
  );

  const ada = MatchSeat(userId: 'a', name: 'Ada');
  const bob = MatchSeat(userId: 'b', name: 'Bob');

  Future<void> shot(WidgetTester tester, String name) async {
    if (Platform.environment['GO_LIVE_PNG'] == null) return;
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
    final image = boundary.toImageSync(pixelRatio: 2);
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.png),
    );
    File('${Platform.environment['GO_LIVE_PNG']}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('the question draws for the asker and the asked, and ticks', (
    tester,
  ) async {
    var cancelled = 0;
    var accepted = 0;
    for (final mine in [true, false]) {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 360,
            child: LiveRequestCard(
              roomId: 'r1',
              asker: ada,
              asked: bob,
              viewerIsAsker: mine,
              remaining: const Duration(seconds: 30),
              busy: false,
              onCancel: () => cancelled++,
              onAccept: mine ? null : () => accepted++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        find.textContaining(mine ? 'Bob' : 'Ada'),
        findsWidgets,
      );
      await shot(tester, mine ? 'asker' : 'asked');
      await tester.tap(find.text(mine ? 'Cancel' : 'Decline'));
      if (!mine) await tester.tap(find.text('Play live'));
    }
    expect(cancelled, 2);
    expect(accepted, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('calm motion keeps the question still', (tester) async {
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 360,
          child: LiveRequestCard(
            roomId: 'r1',
            asker: ada,
            asked: bob,
            viewerIsAsker: true,
            remaining: const Duration(seconds: 30),
            busy: false,
            onCancel: () {},
          ),
        ),
        calm: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'calm');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the ignite plays once and reports done', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 360,
          height: 360,
          child: LiveIgnite(label: 'Live', onDone: () => done++),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await shot(tester, 'ignite_200');
    await tester.pump(const Duration(milliseconds: 250));
    await shot(tester, 'ignite_450');
    await tester.pump(const Duration(milliseconds: 1000));
    expect(done, 1);
    expect(find.text('LIVE'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
