import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../data/games_store.dart';
import '../../data/records_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/daily_game.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/game_records.dart';
import '../../widgets/game_tile.dart';
import '../../widgets/ios_kit.dart';

import '../feed/puzzle_screen.dart';
import 'queens_screen.dart';
import 'sudoku_screen.dart';
import 'tango_screen.dart';
import 'zip_screen.dart';
import '../../l10n/text_case.dart';

/// The games hub — today's five boards, and how you did on each.
///
/// The four new dailies sit beside the symbol-code puzzle rather than replacing
/// it: it is the one this app already had, it is ranked by guesses instead of
/// seconds, and it belongs on the same shelf. Five tiles, one shelf, one day.
///
/// Every tile draws the **real board** for today, small and inert, from the
/// same painter that draws the playable one. That is why this screen looks
/// different every morning instead of showing five fixed icons — and it is also
/// the honest preview: what you see on the tile is the puzzle you are about to
/// open.
class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({
    super.key,
    required this.feedApi,
    required this.userId,
  });

  /// Handed through to the symbol-code puzzle, which submits guesses on the
  /// Feed's own API rather than the games one.
  final FeedApi feedApi;

  final String userId;

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  @override
  void initState() {
    super.initState();
    GamesStore.instance.addListener(_onChange);
    FeedStore.instance.addListener(_onChange);
    GamesStore.instance.load(widget.userId);
    RecordsStore.instance.load(widget.userId);
  }

  @override
  void dispose() {
    GamesStore.instance.removeListener(_onChange);
    FeedStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    // A board finished behind this screen changes every tile's status and the
    // count in the header, so the hub catches up on the way back rather than
    // showing a stale "not played" over a puzzle just solved.
    GamesStore.instance.load(widget.userId);
    // …and a solve may just have set a record.
    RecordsStore.instance.load(widget.userId, force: true);
  }

  void _openGame(DailyGame game) {
    _open(switch (game) {
      DailyGame.queens => QueensScreen(userId: widget.userId),
      DailyGame.tango => TangoScreen(userId: widget.userId),
      DailyGame.zip => ZipScreen(userId: widget.userId),
      DailyGame.sudoku => SudokuScreen(userId: widget.userId),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = GamesStore.instance;
    final left = FeedStore.instance.gamesLeft;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // `bottom: false`, with the inset moved onto the list below — see
          // [edgeToEdgeBottom].
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              // The tile grid below already grows past 3 columns once there's
              // room for it — the default readable column caps that growth at
              // exactly the width mobile already used, which is the shape this
              // screen looked like before this widened.
              maxWidth: context.isExpanded
                  ? ContentWidth.wide
                  : ContentWidth.readable,
              child: CustomScrollView(
                // iOS pull-to-refresh: the bounce is what reveals the
                // spinner, so it is asked for on every platform here.
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: () {
                      HapticFeedback.lightImpact();
                      return Future.wait([
                        GamesStore.instance.load(widget.userId, force: true),
                        RecordsStore.instance.load(widget.userId, force: true),
                      ]);
                    },
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      edgeToEdgeBottom(context),
                    ),
                    sliver: SliverList.list(children: [
                    if (Navigator.of(context).canPop())
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: GlassBackButton(),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.gamesHubTitle,
                      style: theme.displayLarge.copyWith(letterSpacing: 0.37),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.gamesHubSubtitle,
                      style: theme.bodySoft.copyWith(color: theme.inkMuted),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        label: sentenceCaseOf(context, l10n.gamesRemaining(left)),
                        tone: left == 0 ? theme.success : theme.accent,
                        icon: left == 0
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.game_controller_solid,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (store.error != null && !store.boards.ready)
                      _Trouble(
                        onRetry: () =>
                            GamesStore.instance.load(widget.userId, force: true),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Two columns on a phone, growing with the width
                          // there's actually room for — the tiles are square
                          // boards, so a fixed count would either crush them on
                          // a handset or leave a wide desktop pane stuck at the
                          // same 3 phone-size tiles it started with. Capped at
                          // 5: that's every tile this screen has, so a 6th
                          // column would only ever be empty.
                          const gap = 12.0;
                          const tileTarget = 150.0;
                          final columns = ((constraints.maxWidth + gap) /
                                  (tileTarget + gap))
                              .floor()
                              .clamp(2, 5);
                          final width =
                              (constraints.maxWidth - gap * (columns - 1)) /
                              columns;
                          // The code puzzle leads, ahead of the four boards.
                          //
                          // It is the game this app had first and the one the
                          // daily nudge names, so the tile a person lands on
                          // after tapping that notification should be the first
                          // thing under their thumb rather than the last. It is
                          // also the order the Feed's own games strip already
                          // used (see GamesStrip) — the shelf and the hub
                          // disagreeing about which game comes first was the
                          // inconsistency, and this settles it in the strip's
                          // favour.
                          final tiles = <Widget>[
                            CodePuzzleTile(
                              key: const ValueKey('tile_code'),
                              puzzle: FeedStore.instance.puzzle,
                              width: width,
                              onTap: () => _open(
                                PuzzleScreen(
                                  feedApi: widget.feedApi,
                                  userId: widget.userId,
                                ),
                              ),
                            ),
                            for (final game in DailyGame.values)
                              GameTile(
                                key: ValueKey('tile_${game.wire}'),
                                game: game,
                                boards: store.boards,
                                result: FeedStore.instance.games[game],
                                rank: store.standings.rankOf(
                                  game,
                                  widget.userId,
                                ),
                                width: width,
                                onTap: () => _openGame(game),
                              ),
                          ];
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (var i = 0; i < tiles.length; i++)
                                TweenAnimationBuilder<double>(
                                  key: tiles[i].key,
                                  tween: Tween(begin: 0, end: 1),
                                  duration: motion.stagger(
                                    theme.motionMed,
                                    i,
                                    strideMs: 60,
                                  ),
                                  // Pops in on an overshoot, one after the
                                  // other — the shelf being dealt out.
                                  curve: motion.c(Curves.easeOutBack),
                                  builder: (context, v, child) =>
                                      Transform.scale(
                                        scale: 0.86 + 0.14 * v,
                                        child: Opacity(
                                          opacity: v.clamp(0.0, 1.0),
                                          child: child,
                                        ),
                                      ),
                                  child: tiles[i],
                                ),
                            ],
                          );
                        },
                      ),
                    // Below the shelf: today's games first, then how everyone
                    // has ever done at them.
                    const SizedBox(height: 30),
                    RecordsSection(viewerId: widget.userId),
                  ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when today's boards could not be fetched at all.
///
/// Distinct from an empty hub, because those are not the same thing: a board
/// that never loaded is a network problem the player can retry, and rendering
/// five blank tiles for it says "there are no games today" instead.
class _Trouble extends StatelessWidget {
  const _Trouble({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return GroupedSection(
      margin: EdgeInsets.zero,
      children: [
        GroupedRow(
          icon: CupertinoIcons.wifi_exclamationmark,
          tone: TileTone.orange,
          title: sentenceCaseOf(context, l10n.gamesLoadFailed),
          chevron: false,
          onTap: onRetry,
          trailing: Text(
            sentenceCaseOf(context, l10n.gamesRetry),
            style: theme.body.copyWith(color: theme.accent),
          ),
        ),
      ],
    );
  }
}
