import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/chat_games/game_start_sheet.dart';
import 'package:monkeyhub/chat_games/play_style.dart';
import 'package:monkeyhub/games/how_to/chat_guides.dart';
import 'package:monkeyhub/games/how_to/daily_guides.dart';
import 'package:monkeyhub/games/how_to/how_to_play.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The how-to-play guide with motion ON: the demos loop on a real ticker, so
/// these pump fixed frames rather than settling.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HowToPlaySeen.resetForTest();
  });

  Widget host(void Function(BuildContext) open) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> frames(WidgetTester tester, Duration total) async {
    for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> playThrough(
    WidgetTester tester,
    HowToPlayGuide Function(AppLocalizations) build,
    String reason,
  ) async {
    late HowToPlayGuide guide;
    await tester.pumpWidget(host((context) {
      guide = build(AppLocalizations.of(context));
      showHowToPlay(context, guide);
    }));
    await tester.tap(find.text('open'));
    await tester.pump();
    for (var i = 0; i < guide.steps.length; i++) {
      expect(find.text(guide.steps[i].text), findsOneWidget, reason: '$reason step $i');
      await frames(tester, guide.steps[i].demo.period);
      expect(tester.takeException(), isNull, reason: '$reason step $i');
      if (i < guide.steps.length - 1) {
        await tester.tap(find.text('Next'));
        await frames(tester, const Duration(milliseconds: 600));
      }
    }
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('every chat game guide plays, with every mode page', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final game in const [
      'tictactoe', 'connectfour', 'checkers', 'reversi', 'dots', 'chess',
      'liarsdice', 'imposter', 'race',
    ]) {
      await playThrough(
        tester,
        (l10n) => chatGuide(
          l10n,
          game,
          modes: const [PlayStyle.turns, PlayStyle.live],
          group: true,
          voice: true,
        ),
        game,
      );
    }
  });

  test('party games get no Turns pages; bots get no mode pages', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final party = chatGuide(l10n, 'liarsdice', modes: const [PlayStyle.turns, PlayStyle.live]);
    expect(party.steps.where((s) => s.text == l10n.howToTurns1), isEmpty);
    expect(party.steps.where((s) => s.text == l10n.howToLive1), hasLength(1));
    final bot = chatGuide(l10n, 'chess');
    expect(bot.steps.where((s) => s.chip != null), isEmpty);
    final dm = chatGuide(l10n, 'checkers', modes: const [PlayStyle.live]);
    expect(dm.steps.where((s) => s.text == l10n.howToLive3), isEmpty);
  });

  testWidgets('a game page in the start sheet opens its guide', (tester) async {
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Reduced motion, so the sheet settles.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(
          body: StartGameSheet(isDm: true, initialGame: 'checkers'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game_how_to')));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.howToCheckers1), findsOneWidget);
  });

  testWidgets('every daily guide plays every step without throwing',
      (tester) async {
    // A phone, where the whole guide fits above the pinned button.
    tester.view.physicalSize = const Size(393, 852) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final game in [...DailyGame.values, null]) {
      late HowToPlayGuide guide;
      await tester.pumpWidget(host((context) {
        guide = dailyGuide(AppLocalizations.of(context), game);
        showHowToPlay(context, guide);
      }));
      await tester.tap(find.text('open'));
      await tester.pump();
      for (var i = 0; i < guide.steps.length; i++) {
        expect(find.text(guide.steps[i].text), findsOneWidget,
            reason: '${game?.wire ?? 'code'} step $i');
        // One full loop of this step's demo, seam included.
        await frames(tester, guide.steps[i].demo.period);
        expect(tester.takeException(), isNull);
        if (i < guide.steps.length - 1) {
          await tester.tap(find.text('Next'));
          await frames(tester, const Duration(milliseconds: 600));
        }
      }
      // The last step offers a replay, which goes back to the first.
      expect(find.text('Watch again'), findsOneWidget);
      await tester.tap(find.text('Watch again'));
      await frames(tester, const Duration(milliseconds: 600));
      expect(find.text(guide.steps.first.text), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await frames(tester, const Duration(milliseconds: 600));
      expect(find.text('Got it'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('showHowToPlayOnce shows a guide once per device',
      (tester) async {
    var shown = <bool>[];
    await tester.pumpWidget(host((context) async {
      shown.add(await showHowToPlayOnce(
        context,
        dailyGuide(AppLocalizations.of(context), DailyGame.tango),
      ));
    }));
    await tester.tap(find.text('open'));
    await tester.pump();
    await frames(tester, const Duration(milliseconds: 600));
    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await frames(tester, const Duration(milliseconds: 600));
    expect(shown, [true]);

    await tester.tap(find.text('open'));
    await frames(tester, const Duration(milliseconds: 600));
    expect(find.text('Got it'), findsNothing);
    expect(shown, [true, false]);

    // And it sticks on disk, not just in memory.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('howToPlay.seen.daily.tango'), isTrue);
  });
}
