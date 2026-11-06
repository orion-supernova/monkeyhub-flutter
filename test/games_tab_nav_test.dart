import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/models/game_catalog.dart';
import 'package:monkeyhub/models/puzzle.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_tile.dart';
import 'package:monkeyhub/widgets/games_strip.dart';

/// Games became a tab and Discover stopped being one (Nov 2026): Discover is
/// a page off the chat list, and the games moved off the Feed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nav order', () {
    tearDown(() => SettingsStore.instance.setShowCallsTab(true));

    test('Calls leads, Games sits between Feed and Settings, no Discover', () {
      expect(navOrder, [
        HomeSection.calls,
        HomeSection.chat,
        HomeSection.feed,
        HomeSection.games,
        HomeSection.settings,
      ]);
      expect(
        navDestinations(AppLocalizationsEn()).map((d) => d.label),
        ['Calls', 'Chat', 'Feed', 'Games', 'Settings'],
      );
    });

    test('with Calls off the bar is four, Games still in it', () async {
      await SettingsStore.instance.setShowCallsTab(false);
      expect(navOrder, [
        HomeSection.chat,
        HomeSection.feed,
        HomeSection.games,
        HomeSection.settings,
      ]);
    });

    test('a fresh install opens on Chats, not the first tab', () {
      expect(HomeSection.parse(null), HomeSection.chat);
    });
  });

  testWidgets('shelves: one sideways row per tier, every game on one',
      (tester) async {
    final day = ((jsonDecode(File('test/fixtures/daily_games.json')
            .readAsStringSync()) as Map)['days'] as List)
        .first as Map<String, dynamic>;
    final boards = DailyBoards.fromJson({
      'dayKey': day['dayKey'],
      for (final g in DailyGame.values) g.wire: (day[g.wire] as Map)['board'],
    });
    tester.view.physicalSize = const Size(402, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: GamesStrip(
                shelves: true,
                inset: 16,
                boards: boards,
                results: const {},
                onOpen: (_) {},
                puzzle: const PuzzleState(),
                onOpenPuzzle: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // One horizontal scroller per tier, no bot tile (the bot is inline on the
    // tab, not a tile).
    final rows = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(rows, findsNWidgets(GameTier.values.length));
    expect(find.byType(GameTile), findsNWidgets(DailyGame.values.length));
    expect(find.byKey(const ValueKey('strip_bots')), findsNothing);

    // Each game sits on its own tier's shelf.
    for (final game in DailyGame.values) {
      final tile = find.byKey(ValueKey('strip_${game.wire}'));
      final shelf = rows.at(GameTier.values.indexOf(tierOf(game)));
      expect(
        find.descendant(of: shelf, matching: tile),
        findsOneWidget,
        reason: '${game.wire} on the ${tierOf(game)} shelf',
      );
    }
  });
}
