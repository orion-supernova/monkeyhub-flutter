import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../data/records_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/game_record.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'sheet_kit.dart';
import 'skeleton_rows.dart';
import 'ios_kit.dart';
import 'meta_text.dart';
import '../l10n/text_case.dart';

/// All-time records — the surfaces that show them.
///
/// Three pieces, one store ([RecordsStore]):
///
///  * [RecordsSection], on the games hub: every game's record holder in one
///    glance, with your own best under it. The "proper place" for an all-time
///    board is beside the games themselves, not a screen of its own that
///    nobody would find.
///  * [showRecordsSheet], the whole board for one game, where friends react.
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

/// The hub's ALL-TIME block: one row per game, holder and your own best.
///
/// Reads the store; the hub asks it to load. Distinguishes "not answered yet"
/// (a skeleton the shape of the real rows) from "answered and empty" — an
/// empty records board on a slow network must not read as "nobody has ever
/// played".
class RecordsSection extends StatelessWidget {
  const RecordsSection({super.key, required this.viewerId});

  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: RecordsStore.instance,
      builder: (context, _) {
        final store = RecordsStore.instance;
        final board = store.board;
        final Widget body;
        if (!store.answered && store.error == null) {
          body = const SkeletonRows(count: 5, avatarSize: 28, circular: false);
        } else if (!store.answered) {
          body = _Retry(onRetry: () => store.load(viewerId, force: true));
        } else if (board.isEmpty) {
          body = EmptyLine(l10n.recordsEmpty);
        } else {
          body = ClipRRect(
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
            child: ColoredBox(
              color: groupedFill(theme),
              child: Column(
                children: [
                  for (var i = 0; i < RecordGame.values.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Container(
                          height: 1 / MediaQuery.devicePixelRatioOf(context),
                          color: theme.ink.withValues(alpha: 0.10),
                        ),
                      ),
                    _SectionRow(
                      game: RecordGame.values[i],
                      board: board,
                      viewerId: viewerId,
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The page's shared shelf header, like the hub's other sections.
            PageSectionHeader(l10n.recordsLabel),
            // Body face, never the theme's caption (tracked mono on the
            // character themes).
            Text(
              sentenceCaseOf(context, l10n.recordsBlurb),
              style: groupedFooterStyle(theme),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: theme.motionFast,
              child: KeyedSubtree(
                key: ValueKey(store.answered),
                child: body,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.game,
    required this.board,
    required this.viewerId,
  });

  final RecordGame game;
  final RecordBoard board;
  final String viewerId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final holder = board.holderOf(game);
    final mine = board.mineFor(game, viewerId);
    final name = recordGameName(l10n, game);
    final holderName = holder == null
        ? null
        : (holder.userId == viewerId ? l10n.momentRailYouLabel : holder.name);
    void open() => showRecordsSheet(context, game: game, viewerId: viewerId);

    return SpringPress(
      onTap: open,
      scale: PressSpec.scaleSmall,
      semanticLabel: holder == null
          ? '$name: ${l10n.recordsNoneYet}'
          : l10n.recordsHolderSemantic(
              name,
              game.formatBest(holder.best),
              holderName!,
            ),
      focusRadius: theme.radiusMd,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentenceCaseOf(context, name),
                      style: groupedTitleStyle(theme),
                    ),
                    const SizedBox(height: 3),
                    if (holder == null)
                      Text(
                        sentenceCaseOf(context, l10n.recordsNoneYet),
                        style: groupedSubtitleStyle(theme),
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.rosette,
                            size: 13,
                            color: theme.accent,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              holderName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: groupedSubtitleStyle(theme).copyWith(
                                color: holder.userId == viewerId
                                    ? theme.accent
                                    : theme.inkSoft,
                              ),
                            ),
                          ),
                          if (holder.reactionCount > 0) ...[
                            const SizedBox(width: 8),
                            _ReactionSummary(row: holder, compact: true),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (holder != null)
                    Text(
                      game.formatBest(holder.best),
                      style: _bestStyle(theme, theme.ink),
                    ),
                  // Your own best, when the record is somebody else's — the
                  // number worth chasing is the gap between the two.
                  if (mine != null && holder?.userId != viewerId) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.recordsYourBest(game.formatBest(mine.best)),
                      style: metaText(theme, color: theme.inkMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_forward, size: 15, color: theme.inkMuted),
            ],
          ),
        ),
    );
  }
}

/// A record time or guess count: the body face at 17 with tabular figures, so
/// the column lines up without the theme's monospace (tracked terminal digits
/// on the character themes).
TextStyle _bestStyle(AppTheme theme, Color color) => theme.bodyEmph.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.normal,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Every friend's best at [game], with the reactions on each.
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
  /// The row whose reaction choices are open. One at a time: a list where
  /// every row can sprout a palette at once is a list nobody can read.
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    // The game's name in the bar like every sheet's title, "All-time" under
    // it, the shared × leading.
    return SheetFrame(
      title: sentenceCaseOf(context, recordGameName(l10n, widget.game)),
      subtitle: sentenceCaseOf(context, l10n.recordsLabel),
      showClose: true,
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: AnimatedBuilder(
          animation: RecordsStore.instance,
          builder: (context, _) {
            final store = RecordsStore.instance;
            final rows = store.board.rowsFor(widget.game);
            final Widget body;
            if (!store.answered && store.error == null) {
              body = const SkeletonRows(count: 4, avatarSize: 28, circular: false);
            } else if (!store.answered) {
              body = _Retry(
                onRetry: () => store.load(widget.viewerId, force: true),
              );
            } else if (rows.isEmpty) {
              body = EmptyLine(l10n.recordsEmpty);
            } else {
              body = ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  // A hairline from the name, past the rank column.
                  separatorBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Container(
                      height: 1 / MediaQuery.devicePixelRatioOf(context),
                      color: theme.ink.withValues(alpha: 0.10),
                    ),
                  ),
                  itemBuilder: (context, i) => _RecordRow(
                    row: rows[i],
                    game: widget.game,
                    viewerId: widget.viewerId,
                    palette: store.board.palette,
                    picking: _picking == rows[i].recordId,
                    onTogglePicker: () => setState(() {
                      _picking =
                          _picking == rows[i].recordId ? null : rows[i].recordId;
                    }),
                    onReact: (emoji) => _react(rows[i], emoji),
                  ),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  sentenceCaseOf(context, l10n.recordsBlurb),
                  style: groupedFooterStyle(theme),
                ),
                const SizedBox(height: 10),
                AnimatedSize(
                  duration: theme.motionFast,
                  curve: theme.motionEntrance,
                  alignment: Alignment.topCenter,
                  child: body,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.row,
    required this.game,
    required this.viewerId,
    required this.palette,
    required this.picking,
    required this.onTogglePicker,
    required this.onReact,
  });

  final GameRecordRow row;
  final RecordGame game;
  final String viewerId;
  final List<String> palette;
  final bool picking;
  final VoidCallback onTogglePicker;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isMe = row.userId == viewerId;
    final name = isMe ? l10n.momentRailYouLabel : row.name;
    final date = DateTime.tryParse(row.dayKey);
    final details = [
      if (date != null)
        // The full date, spelled out: the medium one abbreviates both the
        // weekday and the month ("1 Eki Per") and reads as a stamp. The meta
        // line wraps to two lines, so the long form has the room.
        l10n.recordsSetOn(MaterialLocalizations.of(context).formatFullDate(date)),
      l10n.recordsSolves(row.solves),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: row.rank == 1
                    ? Icon(CupertinoIcons.rosette, size: 18, color: theme.accent)
                    : Text('${row.rank}', style: groupedMetaStyle(theme)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isMe
                          ? theme.bodyEmph.copyWith(color: theme.accent)
                          : theme.body,
                    ),
                    const SizedBox(height: 2),
                    // Two lines before it gives up: in Turkish at large text
                    // one line cut the solve count to "12 ç…".
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: groupedMetaStyle(theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                game.formatBest(row.best),
                style: _bestStyle(
                  theme,
                  row.rank == 1 ? theme.ink : theme.inkSoft,
                ),
              ),
              // Friends' rows only: your own record is for them to cheer.
              if (!isMe)
                _ReactButton(
                  mine: row.mine,
                  active: picking,
                  semanticLabel: l10n.recordsReactSemantic(name),
                  onTap: onTogglePicker,
                )
              else
                // The same slot, empty, so every time sits in one column.
                const SizedBox(width: _kReactSlot),
            ],
          ),
          if (row.reactionCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 6),
              child: _ReactionSummary(row: row),
            ),
          AnimatedSize(
            duration: theme.motionFast,
            curve: theme.motionEntrance,
            alignment: Alignment.topCenter,
            child: picking
                ? Padding(
                    padding: const EdgeInsets.only(left: 28, top: 8),
                    child: _Palette(
                      palette: palette,
                      mine: row.mine,
                      onPick: onReact,
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

/// The emoji on a record and how many chose each; under it, who.
class _ReactionSummary extends StatelessWidget {
  const _ReactionSummary({required this.row, this.compact = false});
  final GameRecordRow row;

  /// Just the counts, for the hub's one-line rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final chips = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final r in row.reactions.take(compact ? 3 : 6))
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 7,
              vertical: compact ? 1 : 2,
            ),
            decoration: BoxDecoration(
              color: r.emoji == row.mine
                  ? quietFill(theme)
                  : theme.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${r.emoji} ${r.count}',
              style: groupedMetaStyle(theme).copyWith(
                color: theme.inkSoft,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
    if (compact || row.reactors.isEmpty) return chips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        const SizedBox(height: 4),
        Text(
          [
            for (final r in row.reactors)
              if (r.name.isNotEmpty) '${r.name} ${r.emoji}',
          ].join('  ·  '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: groupedMetaStyle(theme),
        ),
      ],
    );
  }
}

/// Width of the react button's slot at the end of a record row.
const double _kReactSlot = 44;

class _ReactButton extends StatelessWidget {
  const _ReactButton({
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
    return Semantics(
      selected: active,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: semanticLabel,
        focusShape: FocusRingShape.circle,
        focusRadius: 18,
        child: SizedBox(
          width: _kReactSlot,
          height: 40,
          child: Center(
            child: AnimatedContainer(
              duration: theme.motionFast,
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active || mine != null
                    ? quietFill(theme)
                    : theme.ink.withValues(alpha: 0.07),
              ),
              child: mine != null
                  ? Text(mine!, style: const TextStyle(fontSize: 16))
                  : Icon(
                      CupertinoIcons.smiley,
                      size: 17,
                      color: theme.inkSoft,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The reactions a record can be given. Tapping the one already chosen takes
/// it back off.
class _Palette extends StatelessWidget {
  const _Palette({
    required this.palette,
    required this.mine,
    required this.onPick,
  });

  final List<String> palette;
  final String? mine;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final emoji in palette)
          Semantics(
            selected: emoji == mine,
            child: SpringPress(
              onTap: () => onPick(emoji),
              semanticLabel: emoji,
              focusShape: FocusRingShape.circle,
              focusRadius: 20,
              child: AnimatedContainer(
                duration: theme.motionFast,
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emoji == mine
                      ? quietFill(theme)
                      : theme.ink.withValues(alpha: 0.07),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
      ],
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
