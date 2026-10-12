import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';

/// The two ways a chat game is played, as the player meets them: everyone at
/// once, or one move at a time whenever each of you gets to it.
///
/// One colour and one glyph each, used everywhere the difference is shown
/// (the start sheet's tiles, its mode cards), so "the pink bolt" means live
/// on every screen it appears on.
enum PlayStyle { live, turns }

extension PlayStyleLook on PlayStyle {
  IconData get icon => switch (this) {
    PlayStyle.live => CupertinoIcons.bolt_fill,
    PlayStyle.turns => CupertinoIcons.hourglass,
  };

  TileTone get tone => switch (this) {
    PlayStyle.live => TileTone.pink,
    PlayStyle.turns => TileTone.indigo,
  };

  Color color(AppTheme theme) => tileColor(theme, tone);

  String badge(AppLocalizations l10n) => switch (this) {
    PlayStyle.live => l10n.chatGameModeLive,
    PlayStyle.turns => l10n.chatGameBadgeTurns,
  };
}

/// A filled capsule naming a [PlayStyle]: its glyph and word in white on its
/// colour. Small enough to sit two abreast under a tile's name.
class PlayStyleBadge extends StatelessWidget {
  const PlayStyleBadge(this.style, {super.key});

  final PlayStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final c = style.color(theme);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 2, 8, 2),
      decoration: BoxDecoration(
        // A slight top-to-bottom lift so the pill reads as a sticker rather
        // than a flat swatch; both stops are the same hue.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(c, Colors.white, 0.14)!, c],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              sentenceCaseOf(context, style.badge(l10n)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(
                fontSize: 11.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A [PlayStyle] spelled out: its tile, its name, and the two lines that say
/// what playing that way actually means (live pauses when someone leaves;
/// turns get two days a move, with reminders and a nudge).
///
/// With [onTap] it is one option of a choice, and [selected] rings it in its
/// colour with a check; without, it is the only way this game is played and
/// simply explains it.
class PlayStyleCard extends StatelessWidget {
  const PlayStyleCard({
    super.key,
    required this.style,
    this.selected = false,
    this.onTap,
  });

  final PlayStyle style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final c = style.color(theme);
    final on = selected || onTap == null;
    final title = switch (style) {
      PlayStyle.live => l10n.chatGameLiveTitle,
      PlayStyle.turns => l10n.chatGameTurnsTitle,
    };
    final lines = switch (style) {
      PlayStyle.live => [
        (CupertinoIcons.person_2_fill, l10n.chatGameLiveNow),
        (CupertinoIcons.pause_circle_fill, l10n.chatGameLivePause),
      ],
      PlayStyle.turns => [
        (CupertinoIcons.chat_bubble_2_fill, l10n.chatGameTurnsAnytime),
        (CupertinoIcons.bell_fill, l10n.chatGameTurnsClock),
      ],
    };
    final card = AnimatedContainer(
      duration: motion.d(theme.motionFast),
      curve: theme.motionCurve,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          c.withValues(alpha: on ? (theme.isLight ? 0.10 : 0.16) : 0.0),
          sheetGroupFill(theme),
        ),
        borderRadius: BorderRadius.circular(groupedRadius(theme) + 2),
        border: Border.all(
          color: selected ? c : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ToneTile(icon: style.icon, tone: style.tone, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, bottom: 6),
                  child: Text(
                    sentenceCaseOf(context, title),
                    style: theme.bodyEmph.copyWith(
                      fontSize: 17,
                      color: theme.ink,
                    ),
                  ),
                ),
                for (final (icon, line) in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(icon, size: 13, color: c),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            line,
                            style: groupedMetaStyle(theme).copyWith(
                              color: theme.inkSoft,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            _Check(on: selected, color: c),
          ],
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return card;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SpringPress(
        onTap: tap,
        scale: 0.97,
        semanticLabel: '$title. ${lines.map((l) => l.$2).join(' ')}',
        child: card,
      ),
    );
  }
}

/// The radio mark: an empty ring, or a filled disc with a tick that pops in.
class _Check extends StatelessWidget {
  const _Check({required this.on, required this.color});

  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return AnimatedContainer(
      duration: motion.d(theme.motionFast),
      curve: theme.motionCurve,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? color : Colors.transparent,
        border: Border.all(
          color: on ? color : theme.inkMuted.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: motion.d(theme.motionMed),
        curve: Curves.easeOutBack,
        child: const Icon(
          CupertinoIcons.checkmark_alt,
          size: 15,
          color: Colors.white,
        ),
      ),
    );
  }
}
