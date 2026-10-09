import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../data/games_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'chat_list_row.dart' show MonogramAvatar;
import 'ios_kit.dart';
import 'medal_disc.dart';
import 'moment_rail.dart' show MomentUnseenDot;
import 'remote_image.dart';
import 'streak_badge.dart';

/// THE row of every scoreboard: the leaderboard under its podium, a game's
/// "today's times", the code's scoreboard. One shape everywhere, so a person
/// looks the same wherever their score is: rank, face, name with their
/// streak flame, and the score on the trailing edge.
///
/// The rank is a medal for a podium place ([medal]) and a plain numeral
/// otherwise. A [PersonRow] underneath, so the hairlines, the 56pt height
/// and the viewer's accent are the people rows' own.
class ScoreRow extends StatelessWidget implements GroupedInsetRow {
  const ScoreRow({
    super.key,
    required this.rank,
    required this.userId,
    required this.name,
    required this.isViewer,
    required this.trailing,
    required this.semantics,
    this.medal = false,
    this.streak = 0,
    this.extra,
    this.subtitle,
    this.onTap,
    this.avatarStorageId,
  });

  final int rank;
  final String userId;

  /// Ignored for the viewer, who is "You".
  final String name;
  final bool isViewer;

  /// The score: a time, "4/6", the solved dots.
  final Widget trailing;

  /// The score read aloud, after the place and the name.
  final String semantics;

  /// Gold, silver or bronze in place of the numeral.
  final bool medal;
  final int streak;

  /// A small glyph before the score (a hint was used).
  final Widget? extra;

  /// A second line under the name (the cheers on a record).
  final String? subtitle;
  final VoidCallback? onTap;

  /// See [PlayerFace.storageId].
  final String? avatarStorageId;

  @override
  double get groupedInset => kPersonRowTextInset + kPersonRowLead;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final label =
        isViewer ? sentenceCaseOf(context, l10n.momentRailYouLabel) : name;
    final more = extra;
    return PersonRow(
      emphasis: isViewer,
      lead: medal && rank <= 3
          ? MedalDisc(rank: rank, medal: true, size: 22)
          : Text('$rank', style: scoreRankStyle(theme)),
      avatar: PlayerFace(
        userId: userId,
        label: label,
        size: kPersonRowAvatar,
        storageId: avatarStorageId,
      ),
      title: label,
      subtitle: subtitle,
      onTap: onTap,
      titleTrailing: streak >= 2 ? StreakBadge(streak) : null,
      // One announcement: "4. Selin, 3 of 5 solved, 3 day streak".
      semanticLabel: [
        '$rank. $label',
        semantics,
        if (streak >= 2) l10n.streakDays(streak),
      ].join(', '),
      trailing: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (more != null) ...[more, const SizedBox(width: 8)],
            trailing,
          ],
        ),
      ),
    );
  }
}

/// A rank numeral in a score row's lead slot; a dash for "not on it yet".
TextStyle scoreRankStyle(AppTheme theme) => groupedMetaStyle(theme).copyWith(
      fontWeight: FontWeight.w600,
      color: theme.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// A score on a row's trailing edge: a time or "4/6", tabular so a column of
/// them lines up. [muted] for a board not solved; [large] for the podium.
class ScoreText extends StatelessWidget {
  const ScoreText(this.text, {super.key, this.muted = false, this.large = false});

  final String text;
  final bool muted;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(
      text,
      style: groupedTitleStyle(theme).copyWith(
        fontSize: large ? 15 : null,
        fontWeight: FontWeight.w600,
        color: muted ? theme.inkMuted : theme.ink,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// A player's face on a scoreboard: their profile picture when they let
/// friends see it, the monogram otherwise and while the picture loads.
///
/// The pictures come with the standings ([GameStandings.avatars]), so a board
/// needs no lookup of its own and a code-only scorer gets a face too.
class PlayerFace extends StatelessWidget {
  const PlayerFace({
    super.key,
    required this.userId,
    required this.label,
    required this.size,
    this.storageId,
    this.badge,
    this.dot = false,
  });

  final String userId;

  /// A small disc at the lower right: a point's category, a missed game.
  final Widget? badge;

  /// The unseen dot at the upper right.
  final bool dot;

  /// The picture, when the caller holds it: the records board carries its
  /// own, for holders who have not played today. Otherwise today's standings.
  final String? storageId;

  /// The name the monogram takes its letter from.
  final String label;
  final double size;

  static final _api = ChatApi(ConvexBackend.instance);

  @override
  Widget build(BuildContext context) {
    final storageId =
        this.storageId ?? GamesStore.instance.standings.avatars[userId];
    final monogram = MonogramAvatar(label: label, seed: userId, size: size);
    final face = storageId == null
        ? monogram
        : Stack(
            fit: StackFit.expand,
            children: [
              monogram,
              RemoteImage(
                storageId: storageId,
                api: _api,
                width: size,
                height: size,
                borderRadius: BorderRadius.circular(size),
              ),
            ],
          );
    final mark = badge;
    if (mark == null && !dot) {
      return SizedBox.square(dimension: size, child: face);
    }
    final theme = ThemeScope.of(context);
    final disc = size * 0.5;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          face,
          if (mark != null)
            Positioned(
              right: -3,
              bottom: -3,
              width: disc,
              height: disc,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: quietFillOver(theme),
                  border: Border.all(color: groupedFill(theme), width: 1.5),
                ),
                child: mark,
              ),
            ),
          if (dot)
            const Positioned(top: -2, right: -2, child: MomentUnseenDot(size: 9)),
        ],
      ),
    );
  }
}

/// A face nobody has: the outline of one in the quiet fill. An untaken
/// podium place and a record nobody holds yet are the same empty seat.
class EmptyFace extends StatelessWidget {
  const EmptyFace({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: quietFill(ThemeScope.of(context)),
        ),
      );
}

/// The quiet fill, made opaque over the grouped card, for a badge that sits
/// on top of a face and must not let the picture show through.
Color quietFillOver(AppTheme theme) =>
    Color.alphaBlend(quietFill(theme), groupedFill(theme));
