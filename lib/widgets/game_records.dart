import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../data/games_store.dart';
import '../data/records_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/game_record.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'sheet_kit.dart';
import 'skeleton_rows.dart';
import 'ios_kit.dart';
import 'medal_disc.dart';
import 'odometer_number.dart';
import 'score_row.dart';
import '../l10n/text_case.dart';

/// All-time records — the surfaces that show them.
///
/// Three pieces, one store ([RecordsStore]):
///
///  * [RecordsSection], on the leaderboard: every game's record as a row on
///    "Today", or one game's as a [RecordHero] on that game's board.
///  * [showRecordsSheet], the whole board for one game: the record as a hero
///    with the cheering under it, then everyone else's best.
///  * [AllTimeLink], beside each game's TODAY standings, so the question
///    "is that good?" is one tap from the answer.

/// A game's name as its tile spells it.
String recordGameName(AppLocalizations l10n, RecordGame game) => switch (game) {
      RecordGame.code => l10n.gameCodeName,
      RecordGame.queens => l10n.gameQueensName,
      RecordGame.tango => l10n.gameTangoName,
      RecordGame.zip => l10n.gameZipName,
      RecordGame.sudoku => l10n.gameSudokuName,
    };

/// The small "ALL-TIME ›" beside a TODAY standings header.
class AllTimeLink extends StatelessWidget {
  const AllTimeLink({super.key, required this.game, required this.viewerId});

  final RecordGame game;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The shared text link — accent, trailing chevron, the iOS "See all".
    return TextLinkButton(
      label: l10n.recordsLabel,
      icon: CupertinoIcons.chevron_forward,
      onTap: () => showRecordsSheet(context, game: game, viewerId: viewerId),
    );
  }
}

/// The leaderboard's ALL-TIME block.
///
/// On "Today", one [_RecordRow] per game: the holder's face with the gold
/// medal set into it, the game, who holds it and your own best beside, and
/// the time. On a game's board ([only]), that one record as a [RecordHero]:
/// the place on the page where the number to beat deserves the most weight.
///
/// Distinguishes "not answered yet" (a skeleton the shape of the real rows)
/// from "answered and empty": an empty board on a slow network must not read
/// as "nobody has ever played".
class RecordsSection extends StatelessWidget {
  const RecordsSection({
    super.key,
    required this.viewerId,
    this.only,
    this.onPlay,
  });

  final String viewerId;

  /// Just this game's record, as a hero; every game's as rows when null.
  final RecordGame? only;

  /// Opens a game, for a record nobody holds yet.
  final ValueChanged<RecordGame>? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: RecordsStore.instance,
      builder: (context, _) {
        final store = RecordsStore.instance;
        final board = store.board;
        final one = only;
        final Widget body;
        if (!store.answered && store.error == null) {
          body = ClipRRect(
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
            child: ColoredBox(
              color: groupedFill(theme),
              child: SkeletonRows(
                count: one == null ? RecordGame.values.length : 1,
                avatarSize: kPersonRowAvatar,
              ),
            ),
          );
        } else if (!store.answered) {
          body = _Retry(onRetry: () => store.load(viewerId, force: true));
        } else if (one != null) {
          body = RecordHero(
            game: one,
            board: board,
            viewerId: viewerId,
            onPlay: onPlay == null ? null : () => onPlay!(one),
          );
        } else if (board.isEmpty) {
          body = EmptyLine(l10n.recordsEmpty);
        } else {
          body = GroupedSection(
            margin: EdgeInsets.zero,
            children: [
              for (final g in RecordGame.values)
                _RecordRow(
                  game: g,
                  board: board,
                  viewerId: viewerId,
                  onPlay: onPlay == null ? null : () => onPlay!(g),
                ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The page's shared shelf header, on the title's 20pt edge over
            // a card at 16. What a record is lives at the foot of the sheet.
            PageSectionHeader(
              l10n.recordsLabel,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            ),
            AnimatedSwitcher(
              duration: MotionScope.of(context).d(theme.motionFast),
              child: KeyedSubtree(
                key: ValueKey((store.answered, one)),
                child: body,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A record holder's face: their picture with the gold medal set into it,
/// the podium's "coin on the face". Bottom centre on a big face, the lower
/// right on a row's 40pt one. Nobody holding it is an [EmptyFace].
class RecordFace extends StatelessWidget {
  const RecordFace({
    super.key,
    required this.holder,
    required this.board,
    required this.viewerId,
    required this.size,
    required this.ring,
  });

  final GameRecordRow? holder;
  final RecordBoard board;
  final String viewerId;
  final double size;

  /// The fill behind the face, cut around the medal.
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final h = holder;
    if (h == null) return EmptyFace(size: size);
    final big = size >= 56;
    final medal = big ? 24.0 : 18.0;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PlayerFace(
            userId: h.userId,
            label: h.userId == viewerId ? l10n.momentRailYouLabel : h.name,
            size: size,
            storageId: board.avatars[h.userId],
          ),
          Positioned(
            left: big ? (size - medal) / 2 : null,
            right: big ? null : -3,
            bottom: big ? -8 : -3,
            child: MedalDisc(rank: 1, medal: true, size: medal, border: ring),
          ),
        ],
      ),
    );
  }
}

/// One game's record as a row on "Today": the holder's face, the game, who
/// holds it (and your own best beside it, the gap worth chasing), the time.
class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.game,
    required this.board,
    required this.viewerId,
    this.onPlay,
  });

  final RecordGame game;
  final RecordBoard board;
  final String viewerId;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final holder = board.holderOf(game);
    final mine = board.mineFor(game, viewerId);
    final name = sentenceCaseOf(context, recordGameName(l10n, game));
    final holderName = holder == null
        ? null
        : (holder.userId == viewerId
            ? sentenceCaseOf(context, l10n.momentRailYouLabel)
            : holder.name);
    final subtitle = holder == null
        ? sentenceCaseOf(context, l10n.recordsNoneYet)
        : [
            holderName!,
            if (mine != null && holder.userId != viewerId)
              l10n.recordsYourBest(game.formatBest(mine.best)),
          ].join(' · ');

    return PersonRow(
      avatar: RecordFace(
        holder: holder,
        board: board,
        viewerId: viewerId,
        size: kPersonRowAvatar,
        ring: groupedFill(theme),
      ),
      title: name,
      subtitle: subtitle,
      semanticLabel: holder == null
          ? '$name: ${l10n.recordsNoneYet}'
          : l10n.recordsHolderSemantic(
              name,
              game.formatBest(holder.best),
              holderName!,
            ),
      onTap: holder == null
          ? onPlay
          : () => showRecordsSheet(context, game: game, viewerId: viewerId),
      trailing: holder == null
          ? (onPlay == null
              ? null
              : RowPillButton(
                  label: l10n.leaderboardPlay,
                  filled: true,
                  onTap: onPlay,
                ))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScoreText(game.formatBest(holder.best)),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 15,
                  color: theme.inkMuted,
                ),
              ],
            ),
    );
  }
}

/// A record time or guess count: the body face with tabular figures, so a
/// column of them lines up without the theme's monospace (tracked terminal
/// digits on the character themes). [size] 17 in a row, 34 on a hero.
TextStyle _bestStyle(AppTheme theme, Color color, {double size = 17}) =>
    theme.bodyEmph.copyWith(
      fontSize: size,
      fontWeight: size > 20 ? FontWeight.w700 : FontWeight.w600,
      fontStyle: FontStyle.normal,
      height: size > 20 ? 1.05 : null,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// One game's record, big: the holder's face with the gold medal, the time
/// in large figures, who holds it and when.
///
/// The record's own hero rather than a second podium: a podium is three
/// people racing today, this is one number to beat, ever, and drawn the
/// same way the page would say the same thing twice.
///
/// On the page ([sheet] false) the card opens the sheet, with the cheers as
/// a tally and "See all". In the sheet it carries the cheering itself: the
/// palette, one tap, and the faces of who cheered.
class RecordHero extends StatelessWidget {
  const RecordHero({
    super.key,
    required this.game,
    required this.board,
    required this.viewerId,
    this.sheet = false,
    this.onPlay,
    this.onCheer,
  });

  final RecordGame game;
  final RecordBoard board;
  final String viewerId;
  final bool sheet;

  /// Opens the game, for a record nobody holds yet.
  final VoidCallback? onPlay;

  /// Cheers the holder (in the sheet).
  final ValueChanged<String>? onCheer;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final fill = sheet ? sheetGroupFill(theme) : groupedFill(theme);
    final holder = board.holderOf(game);
    final mine = board.mineFor(game, viewerId);
    final yours = holder?.userId == viewerId;
    final date = holder == null ? null : DateTime.tryParse(holder.dayKey);

    final String? meta;
    if (holder == null) {
      meta = null;
    } else if (sheet && date != null) {
      // The full date, spelled out: the medium one abbreviates both the
      // weekday and the month ("1 Eki Per") and reads as a stamp.
      meta = l10n.recordsSetOn(
        MaterialLocalizations.of(context).formatFullDate(date),
      );
    } else if (!yours && mine != null) {
      meta = l10n.recordsYourBest(game.formatBest(mine.best));
    } else {
      meta = null;
    }

    final top = Row(
      children: [
        RecordFace(
          holder: holder,
          board: board,
          viewerId: viewerId,
          size: 64,
          ring: fill,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (holder == null)
                Text(
                  sentenceCaseOf(context, l10n.recordsNoneYet),
                  style: groupedHeaderStyle(theme)
                      .copyWith(color: theme.inkMuted),
                )
              else ...[
                Text(
                  game.formatBest(holder.best),
                  maxLines: 1,
                  style: _bestStyle(theme, theme.ink, size: 34),
                ),
                const SizedBox(height: 4),
                Text(
                  yours
                      ? sentenceCaseOf(context, l10n.momentRailYouLabel)
                      : holder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: groupedTitleStyle(theme).copyWith(
                    fontWeight: FontWeight.w600,
                    color: yours ? theme.accent : null,
                  ),
                ),
              ],
              if (meta != null) ...[
                const SizedBox(height: 2),
                Text(
                  sentenceCaseOf(context, meta),
                  maxLines: 2,
                  style: groupedMetaStyle(theme)
                      .copyWith(color: theme.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final List<Widget> foot;
    if (holder == null) {
      foot = [
        if (onPlay != null)
          Align(
            alignment: Alignment.centerLeft,
            child: RowPillButton(
              label: l10n.leaderboardPlay,
              filled: true,
              onTap: onPlay,
            ),
          ),
      ];
    } else if (!sheet) {
      foot = [
        Row(
          children: [
            Expanded(child: ReactionTally(row: holder, pills: true)),
            TextLinkButton(
              label: l10n.pageSectionSeeAll,
              icon: CupertinoIcons.chevron_forward,
              onTap: () =>
                  showRecordsSheet(context, game: game, viewerId: viewerId),
            ),
          ],
        ),
      ];
    } else {
      foot = [
        // You do not cheer yourself: your own record shows only who did.
        if (!yours) ...[
          _hairline(context),
          const SizedBox(height: 12),
          _CheerButton(
            palette: board.palette,
            mine: holder.mine,
            onPick: (e) => onCheer?.call(e),
            semanticName: holder.name,
          ),
        ],
        if (holder.reactors.isNotEmpty) ...[
          const SizedBox(height: 12),
          CheererStack(row: holder, board: board, viewerId: viewerId),
        ],
      ];
    }

    final card = Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Room for the medal set into the face's lower edge.
          Padding(padding: const EdgeInsets.only(bottom: 8), child: top),
          if (foot.isNotEmpty) ...[const SizedBox(height: 8), ...foot],
        ],
      ),
    );
    if (sheet || holder == null) return card;
    return SpringPress(
      onTap: () => showRecordsSheet(context, game: game, viewerId: viewerId),
      scale: PressSpec.scaleSmall,
      focusRadius: groupedRadius(theme),
      semanticLabel: l10n.recordsHolderSemantic(
        sentenceCaseOf(context, recordGameName(l10n, game)),
        game.formatBest(holder.best),
        yours ? l10n.momentRailYouLabel : holder.name,
      ),
      child: card,
    );
  }

  static Widget _hairline(BuildContext context) => Container(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        color: ThemeScope.of(context).ink.withValues(alpha: 0.10),
      );
}

/// The emoji on a record and how many chose each. As [pills] on the hero,
/// each in a quiet capsule with its count rolling; as plain text, the top
/// three, for a row's subtitle ([tallyText]).
class ReactionTally extends StatelessWidget {
  const ReactionTally({super.key, required this.row, this.pills = false});

  final GameRecordRow row;
  final bool pills;

  /// "🔥 2  👏 1", the top three, or null with none.
  static String? tallyText(GameRecordRow row) => row.reactions.isEmpty
      ? null
      : [for (final r in row.reactions.take(3)) '${r.emoji} ${r.count}']
          .join('  ');

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (row.reactions.isEmpty) return const SizedBox.shrink();
    final style = groupedMetaStyle(theme).copyWith(
      fontWeight: FontWeight.w600,
      color: theme.inkSoft,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (!pills) return Text(tallyText(row)!, style: style);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final r in row.reactions.take(6))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: quietFill(theme),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.emoji, style: style),
                const SizedBox(width: 4),
                OdometerNumber(value: r.count, style: style),
              ],
            ),
          ),
      ],
    );
  }
}

/// The reactions a record can be given, all six in one row: one tap sends,
/// a tap on the one already chosen takes it back. The chosen one wears the
/// accent ring, and gives a small pop on the frame it is picked.
class CheerBar extends StatefulWidget {
  const CheerBar({
    super.key,
    required this.palette,
    required this.mine,
    required this.onPick,
    required this.semanticName,
    this.compact = false,
  });

  final List<String> palette;
  final String? mine;
  final ValueChanged<String> onPick;

  /// Whose record, for VoiceOver.
  final String semanticName;

  /// The smaller discs that open under a row in the sheet.
  final bool compact;

  @override
  State<CheerBar> createState() => _CheerBarState();
}

class _CheerBarState extends State<CheerBar> {
  /// The emoji just picked and how many picks so far, so each pick pops once.
  (String, int)? _pop;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final disc = widget.compact ? 34.0 : 40.0;
    final glyph = widget.compact ? 17.0 : 20.0;
    return Semantics(
      label: l10n.recordsReactSemantic(widget.semanticName),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final emoji in widget.palette)
            Semantics(
              selected: emoji == widget.mine,
              child: SpringPress(
                onTap: () {
                  if (!motion.calm) {
                    setState(() => _pop = (emoji, (_pop?.$2 ?? 0) + 1));
                  }
                  widget.onPick(emoji);
                },
                semanticLabel: emoji,
                focusShape: FocusRingShape.circle,
                focusRadius: disc / 2,
                child: AnimatedContainer(
                  duration: motion.d(theme.motionFast),
                  width: disc,
                  height: disc,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: emoji == widget.mine
                        ? quietFill(theme)
                        : theme.ink.withValues(alpha: 0.07),
                    border: Border.all(
                      color: emoji == widget.mine
                          ? theme.accent
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: _pop?.$1 == emoji
                      ? TweenAnimationBuilder<double>(
                          key: ValueKey(_pop),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 260),
                          curve: theme.motionEntrance,
                          builder: (_, t, child) => Transform.scale(
                            // Up to 1.18 at the middle, home at the end.
                            scale: 1 + 0.18 * (1 - (2 * t - 1).abs()),
                            child: child,
                          ),
                          child: Text(emoji, style: TextStyle(fontSize: glyph)),
                        )
                      : Text(emoji, style: TextStyle(fontSize: glyph)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Cheer" until it is pressed, then the six emoji to cheer with: a record
/// is cheered on purpose, and a row of emoji that sends on the first touch
/// sends by accident. Wears the chosen emoji once there is one, and folds
/// away again after a pick.
class _CheerButton extends StatefulWidget {
  const _CheerButton({
    required this.palette,
    required this.mine,
    required this.onPick,
    required this.semanticName,
  });

  final List<String> palette;
  final String? mine;
  final ValueChanged<String> onPick;
  final String semanticName;

  @override
  State<_CheerButton> createState() => _CheerButtonState();
}

class _CheerButtonState extends State<_CheerButton> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final mine = widget.mine;
    final label = sentenceCaseOf(context, l10n.recordsCheer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RowPillButton(
            label: mine == null ? label : '$mine  $label',
            // Filled until you have cheered: the one thing to do here.
            filled: mine == null,
            semanticLabel: l10n.recordsReactSemantic(widget.semanticName),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _open = !_open);
            },
          ),
        ),
        AnimatedSize(
          duration: motion.d(theme.motionFast),
          curve: theme.motionEntrance,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: CheerBar(
                    palette: widget.palette,
                    mine: mine,
                    semanticName: widget.semanticName,
                    onPick: (e) {
                      setState(() => _open = false);
                      widget.onPick(e);
                    },
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

/// Who cheered a record, as faces: the newest three, overlapping, each with
/// their emoji at its corner, and "Mert, Selin and 3 more". A tap lays the
/// whole list out in place.
class CheererStack extends StatefulWidget {
  const CheererStack({
    super.key,
    required this.row,
    required this.board,
    required this.viewerId,
  });

  final GameRecordRow row;
  final RecordBoard board;
  final String viewerId;

  @override
  State<CheererStack> createState() => _CheererStackState();
}

class _CheererStackState extends State<CheererStack> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final you = sentenceCaseOf(context, l10n.momentRailYouLabel);
    final people = [
      for (final r in widget.row.reactors)
        (
          id: r.userId,
          name: r.userId == widget.viewerId ? you : r.name,
          emoji: r.emoji,
        ),
    ];
    if (people.isEmpty) return const SizedBox.shrink();
    final named = people.take(2).map((p) => p.name).join(', ');
    final more = people.length - 2;
    final line = more > 0 ? '$named ${l10n.recordsCheersMore(more)}' : named;
    const face = 22.0;
    const step = face - 6;
    final shown = people.take(3).toList();
    final ring = sheetGroupFill(theme);

    return SpringPress(
      onTap: () => setState(() => _open = !_open),
      scale: PressSpec.scaleSmall,
      haptic: false,
      semanticLabel: line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: step * (shown.length - 1) + face + 4,
                height: face + 4,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = shown.length - 1; i >= 0; i--)
                      Positioned(
                        left: step * i,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration:
                              BoxDecoration(shape: BoxShape.circle, color: ring),
                          child: PlayerFace(
                            userId: shown[i].id,
                            label: shown[i].name,
                            size: face,
                            storageId: widget.board.avatars[shown[i].id],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: groupedMetaStyle(theme).copyWith(color: theme.inkSoft),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: motion.d(theme.motionFast),
            curve: theme.motionEntrance,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final p in people)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              '${p.emoji}  ${p.name}',
                              style: groupedMetaStyle(theme)
                                  .copyWith(color: theme.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

/// Every friend's best at [game], with the cheering on each.
///
/// Refreshes the board as it opens: this is reached from a game screen, very
/// often straight after a solve that may just have set a record, and the sheet
/// is exactly where somebody goes to see whether it did.
Future<void> showRecordsSheet(
  BuildContext context, {
  required RecordGame game,
  required String viewerId,
}) {
  HapticFeedback.selectionClick();
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (_) => _RecordsSheet(game: game, viewerId: viewerId),
  );
}

class _RecordsSheet extends StatefulWidget {
  const _RecordsSheet({required this.game, required this.viewerId});
  final RecordGame game;
  final String viewerId;

  @override
  State<_RecordsSheet> createState() => _RecordsSheetState();
}

class _RecordsSheetState extends State<_RecordsSheet> {
  /// The row whose cheer bar is open. One at a time: a list where every row
  /// can sprout six emoji at once is a list nobody can read.
  String? _picking;

  @override
  void initState() {
    super.initState();
    RecordsStore.instance.load(widget.viewerId, force: true);
  }

  Future<void> _react(GameRecordRow row, String emoji) async {
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    setState(() => _picking = null);
    final error = await RecordsStore.instance.toggleReaction(row, emoji);
    if (error != null) toast.show(l10n.recordsReactFailed, tone: ToastTone.danger);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    // The game's name in the bar like every sheet's title, "All-time" under
    // it, the shared × leading.
    return SheetFrame(
      title: sentenceCaseOf(context, recordGameName(l10n, widget.game)),
      subtitle: sentenceCaseOf(context, l10n.recordsLabel),
      showClose: true,
      padding: EdgeInsets.zero,
      // As tall as its rows, and the list runs to the bottom edge under
      // the home indicator rather than stopping above a solid foot.
      scrollsUnderInset: true,
      child: AnimatedBuilder(
        animation: RecordsStore.instance,
        builder: (context, _) {
          final store = RecordsStore.instance;
          final board = store.board;
          final rows = board.rowsFor(widget.game);
          final List<Widget> content;
          if (!store.answered && store.error == null) {
            content = [
              ClipRRect(
                borderRadius: BorderRadius.circular(groupedRadius(theme)),
                child: ColoredBox(
                  color: sheetGroupFill(theme),
                  child: const SkeletonRows(
                    count: 4,
                    avatarSize: kPersonRowAvatar,
                  ),
                ),
              ),
            ];
          } else if (!store.answered) {
            content = [
              _Retry(onRetry: () => store.load(widget.viewerId, force: true)),
            ];
          } else if (rows.isEmpty) {
            content = [EmptyLine(l10n.recordsEmpty)];
          } else {
            // The holder is the hero and only the hero; the group starts at
            // second place.
            final rest = rows.skip(1).toList();
            content = [
              SheetRise(
                child: RecordHero(
                  game: widget.game,
                  board: board,
                  viewerId: widget.viewerId,
                  sheet: true,
                  onCheer: (e) => _react(rows.first, e),
                ),
              ),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 16),
                SheetRise(
                  index: 1,
                  child: SheetGroup(
                    children: [
                      for (final row in rest)
                        _CheerableRow(
                          key: ValueKey(row.recordId),
                          row: row,
                          game: widget.game,
                          board: board,
                          viewerId: widget.viewerId,
                          open: _picking == row.recordId,
                          onToggle: () => setState(() {
                            _picking =
                                _picking == row.recordId ? null : row.recordId;
                          }),
                          onPick: (e) => _react(row, e),
                        ),
                    ],
                  ),
                ),
              ],
            ];
          }
          // ONE scroller: the rows, the hero and the blurb in a single list,
          // so a drag never has to choose between two.
          return ListView(
            shrinkWrap: true,
            padding: sheetListPadding(context),
            children: [
              ...content,
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  sentenceCaseOf(context, l10n.recordsBlurb),
                  style: groupedMetaStyle(theme)
                      .copyWith(color: theme.inkMuted),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A friend's best in the sheet, as every scoreboard row looks ([ScoreRow]),
/// with their cheers as its second line, and a small cheer button by the
/// time. Like the record's own "Cheer", the emoji wait behind the button:
/// nothing sends on a stray touch. Your own row keeps the button's slot
/// empty, so every time sits in one column; you do not cheer yourself.
class _CheerableRow extends StatelessWidget implements GroupedInsetRow {
  const _CheerableRow({
    super.key,
    required this.row,
    required this.game,
    required this.board,
    required this.viewerId,
    required this.open,
    required this.onToggle,
    required this.onPick,
  });

  final GameRecordRow row;
  final RecordGame game;
  final RecordBoard board;
  final String viewerId;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onPick;

  @override
  double get groupedInset => kPersonRowTextInset + kPersonRowLead;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isMe = row.userId == viewerId;
    final best = game.formatBest(row.best);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ScoreRow(
          rank: row.rank,
          medal: row.rank <= 3,
          userId: row.userId,
          name: row.name,
          isViewer: isMe,
          streak: GamesStore.instance.standings.streakOf(row.userId, game.daily),
          semantics: best,
          subtitle: ReactionTally.tallyText(row),
          avatarStorageId: board.avatars[row.userId],
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(best, style: _bestStyle(theme, theme.inkSoft)),
              const SizedBox(width: 8),
              if (isMe)
                const SizedBox(width: _kCheerSlot)
              else
                _RowCheerButton(
                  mine: row.mine,
                  active: open,
                  semanticLabel: l10n.recordsReactSemantic(row.name),
                  onTap: onToggle,
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: motion.d(theme.motionFast),
          curve: theme.motionEntrance,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kPersonRowTextInset + kPersonRowLead,
                    0,
                    14,
                    12,
                  ),
                  child: CheerBar(
                    palette: board.palette,
                    mine: row.mine,
                    onPick: onPick,
                    semanticName: row.name,
                    compact: true,
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

/// Width of a row's cheer button.
const double _kCheerSlot = 32;

/// A row's cheer button: a smiley until you have cheered, your emoji after.
/// It opens the six; it never sends one itself.
class _RowCheerButton extends StatelessWidget {
  const _RowCheerButton({
    required this.mine,
    required this.active,
    required this.semanticLabel,
    required this.onTap,
  });

  final String? mine;
  final bool active;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final chosen = mine;
    return Semantics(
      selected: active,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: semanticLabel,
        focusShape: FocusRingShape.circle,
        focusRadius: _kCheerSlot / 2,
        child: AnimatedContainer(
          duration: motion.d(theme.motionFast),
          width: _kCheerSlot,
          height: _kCheerSlot,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active || chosen != null
                ? quietFill(theme)
                : theme.ink.withValues(alpha: 0.07),
            border: Border.all(
              color: active ? theme.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: chosen != null
              ? Text(chosen, style: const TextStyle(fontSize: 15))
              : Icon(CupertinoIcons.smiley, size: 17, color: theme.inkSoft),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            sentenceCaseOf(context, l10n.recordsLoadFailed),
            style: groupedSubtitleStyle(theme),
          ),
        ),
        TextLinkButton(label: l10n.gamesRetry, onTap: onRetry),
      ],
    );
  }
}
