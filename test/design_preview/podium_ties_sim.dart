// The leaderboard on mock boards with big ties, to run on a simulator and
// swipe the shared podium seats by hand:
//
//   flutter run -d <simulator> -t test/design_preview/podium_ties_sim.dart
//
// Queens: 2 tied for gold, 10 tied at bronze. Tango: 1 gold, 10 at silver.
// Zip: 12 tied for gold. Turkish, the basic theme. Talks to no server.
import 'package:flutter/material.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/data/records_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/game_record.dart';
import 'package:monkeyhub/screens/games/leaderboard_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import '../fakes/fake_games_api.dart';
import 'ties_fixture.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GamesStore.instance.api =
      FakeGamesApi(tieBoardsPayload, standingsAnswer: tieStandings);
  RecordsStore.instance.api = FakeGamesApi(tieBoardsPayload)
    ..records = RecordBoard(games: const {});
  final theme = ThemeController.byId('basic');
  runApp(
    ThemeScope(
      controller: ThemeController(theme),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: theme.background,
        ),
        home: ColoredBox(
          color: theme.background,
          child: DefaultTextStyle(
            style: theme.body,
            child: LeaderboardScreen(
              feedApi: FeedApi(ConvexBackend.instance),
              userId: 'u1',
              initialTab: 2,
            ),
          ),
        ),
      ),
    ),
  );
}
