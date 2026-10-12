import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/turn_board.dart';
import '../widgets/ios_kit.dart';

/// Where a turn by turn game stands, under its board, for a seated player:
/// whose move it is, how long is left, and what happens next.
///
/// Three faces, cross-faded in place:
///
///  * **your move** — make it, then send it; no rush, and how long is left.
///  * **staged** — the move is on the board but not sent: Undo, or Send.
///    Sending is what posts it into the chat, so it is the big button.
///  * **waiting** — we will ping you; Nudge once the other side has been
///    quiet long enough, or when it will be possible.
///
/// The clock line is the same on all three, so "a turn lasts two days" never
/// has to be learnt from a forfeit.
class TurnPanel extends StatelessWidget {
  const TurnPanel({
    super.key,
    required this.match,
    required this.viewerId,
    required this.staged,
    required this.notation,
    required this.timeLeft,
    required this.canNudge,
    required this.sending,
    required this.sent,
    required this.onUndo,
    required this.onSend,
    required this.onNudge,
  });

  final ChatMatch match;
  final String viewerId;

  /// A move is on the board, not sent.
  final bool staged;

  /// The staged move in words ("e2 → e4"), when it has any.
  final String? notation;

  /// "18 hours left", or null when there is no clock to show.
  final String? timeLeft;
  final bool canNudge;
  final bool sending;

  /// The move landed: the Send button turns into a tick for a beat before
  /// the screen closes.
  final bool sent;
  final VoidCallback onUndo;
  final VoidCallback onSend;
  final VoidCallback? onNudge;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final mySeat = match.seatOf(viewerId);
    final mine = staged || match.isTurnOf(viewerId);
    final turnSeat = staged ? mySeat : match.turnSeat;
    final palette = SeatPalette(theme, gameId: match.game);
    final tone = turnSeat == null || turnSeat < 0
        ? theme.inkMuted
        : palette.fill(turnSeat);

    final String title;
    final String body;
    if (staged) {
      title = notation ?? l10n.chatGameYourMove;
      body = l10n.chatGameMvStagedHint;
    } else if (mine) {
      title = l10n.chatGameYourMove;
      body = l10n.chatGameMvYourTurnSub;
    } else {
      final t = match.turnSeat;
      title = t == null ? '' : l10n.chatGameWaitingFor(match.seats[t].name);
      body = l10n.chatGameMvWaitingSub;
    }
    final face = staged ? 'staged' : mine ? 'mine' : 'waiting';

    return AnimatedContainer(
      duration: motion.d(theme.motionFast),
      curve: theme.motionCurve,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        // The accent, not the seat colour: a red seat's wash read as an
        // error state around the one button the player should press.
        color: mine
            ? theme.accent.withValues(alpha: 0.10)
            : theme.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(theme.radiusLg),
        border: Border.all(
          color: mine
              ? theme.accent.withValues(alpha: 0.30)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: AnimatedSize(
        duration: motion.d(const Duration(milliseconds: 260)),
        curve: theme.motionCurve,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: motion.d(const Duration(milliseconds: 220)),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: Column(
            key: ValueKey(face),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _Beacon(color: tone, live: mine && !staged),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      // Notation is case-sensitive: "f1 → b5", never "F1".
                      staged && notation != null
                          ? title
                          : sentenceCaseOf(context, title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyEmph.copyWith(
                        color: theme.ink,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  if (timeLeft != null) _Clock(text: timeLeft!),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                sentenceCaseOf(context, body),
                style: theme.bodySoft.copyWith(color: theme.inkSoft),
              ),
              if (staged) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    SheetActionButton(
                      label: l10n.chatGameMvUndo,
                      icon: CupertinoIcons.arrow_uturn_left,
                      tonal: true,
                      expand: false,
                      onTap: sending || sent ? null : onUndo,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SheetActionButton(
                        label: sent
                            ? l10n.chatGameMvSending
                            : l10n.chatGameMvSend,
                        icon: sent
                            ? CupertinoIcons.checkmark_alt
                            : CupertinoIcons.paperplane_fill,
                        busy: sending && !sent,
                        // The commit plays its own, heavier haptic.
                        haptic: false,
                        onTap: sent ? null : onSend,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  sentenceCaseOf(context, l10n.chatGameMvForfeitNote),
                  style: groupedMetaStyle(theme).copyWith(
                    color: theme.inkMuted,
                    fontSize: 12,
                  ),
                ),
                if (!mine) ...[
                  const SizedBox(height: 12),
                  if (canNudge)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SheetActionButton(
                        label: l10n.chatGameNudge,
                        icon: CupertinoIcons.bell_fill,
                        tonal: true,
                        expand: false,
                        onTap: onNudge,
                      ),
                    )
                  else
                    Text(
                      sentenceCaseOf(context, l10n.chatGameMvNudgeLater),
                      style: groupedMetaStyle(theme).copyWith(
                        color: theme.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The seat colour's dot. Breathes while the move is the viewer's, the one
/// state where something is being asked of them; still otherwise.
class _Beacon extends StatefulWidget {
  const _Beacon({required this.color, required this.live});

  final Color color;
  final bool live;

  @override
  State<_Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<_Beacon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Beacon old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.live && !MotionScope.of(context).calm;
    if (run && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 14,
    height: 14,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.live)
                Container(
                  width: 10 + 4 * t,
                  height: 10 + 4 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.30 * (1 - t) + 0.1),
                  ),
                ),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Clock extends StatelessWidget {
  const _Clock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: theme.ink.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.clock, size: 13, color: theme.inkSoft),
          const SizedBox(width: 4),
          Text(
            sentenceCaseOf(context, text),
            style: groupedMetaStyle(theme).copyWith(
              color: theme.inkSoft,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
