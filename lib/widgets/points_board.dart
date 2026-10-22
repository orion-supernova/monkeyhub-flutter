import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/feed_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/moment.dart';
import '../screens/feed/points_explainer.dart' show PointsExplainerButton;
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'meta_text.dart';
import 'moment_rail.dart';
import 'odometer_number.dart';
import 'remote_image.dart';
import 'score_row.dart';
import 'sheet_kit.dart';

/// The points board: who is winning today, and the newest few points.
///
/// **Text-first, on purpose.** A point is a sentence ("washed the car, it
/// rained at four") and a photo is optional garnish, so a point row leads
/// with its caption and shows a picture only as a small thumbnail.
///
/// Two grouped cards, the way every scoreboard in the app now looks: the
/// standings as [ScoreRow]s (faces, shared places for ties, the tags each
/// person scored in), then the newest [inline] points and a "See all" row
/// opening the whole list ([showPointsSheet]), then "Add a point". With the
/// lists capped, the button is never more than a short glance down.
class PointsBoard extends StatelessWidget {
  const PointsBoard({
    super.key,
    required this.points,
    required this.viewerId,
    required this.api,
    required this.onAdd,
    required this.onOpen,
    this.inline = 3,
    this.standings = 5,
  });

  /// Tagged moments only ([FeedStore.points]), newest first.
  final List<Moment> points;
  final String viewerId;
  final ChatApi api;
  final VoidCallback onAdd;

  /// Opens a point. The rect is the row's own place on screen: a point has
  /// no picture to fly to the viewer, so the card grows out of the row.
  final void Function(Moment moment, Rect? origin) onOpen;

  /// Points shown on the board itself; the rest are one tap away.
  final int inline;

  /// Standings rows shown; the viewer is pinned under them if lower.
  final int standings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tallies = MomentTally.from(points);

    final add = SheetActionButton(
      label: l10n.pointsBoardAdd,
      icon: CupertinoIcons.add,
      tonal: true,
      onTap: onAdd,
    );

    if (tallies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmptyLine(
            l10n.feedBoardStandingsEmpty,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          const SizedBox(height: 6),
          add,
        ],
      );
    }

    final shown = points.take(inline).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Standings(
          tallies: tallies,
          points: points,
          viewerId: viewerId,
          max: standings,
        ),
        const SizedBox(height: 12),
        GroupedSection(
          margin: EdgeInsets.zero,
          children: [
            for (var i = 0; i < shown.length; i++)
              PointRow(
                key: ValueKey('pt_${shown[i].id}'),
                moment: shown[i],
                viewerId: viewerId,
                api: api,
                index: i,
                onTap: (origin) => onOpen(shown[i], origin),
              ),
            if (points.length > shown.length)
              GroupedRow(
                title: sentenceCaseOf(context, l10n.pageSectionSeeAll),
                value: '${points.length}',
                chevron: true,
                onTap: () => showPointsSheet(
                  context,
                  viewerId: viewerId,
                  api: api,
                  onOpen: onOpen,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        add,
      ],
    );
  }
}

/// Who is winning today: [ScoreRow]s with faces, ties sharing a place, the
/// tags each person scored in and their total, in a grouped card.
///
/// Rows are `AnimatedPositioned` keyed by person over fixed slots, so a
/// point landing mid-look SLIDES the affected rows past each other rather
/// than redrawing the list in a new order. The hairlines belong to the
/// slots, not the rows, so they hold still while the rows move.
class _Standings extends StatelessWidget {
  const _Standings({
    required this.tallies,
    required this.points,
    required this.viewerId,
    required this.max,
  });

  final List<MomentTally> tallies;
  final List<Moment> points;
  final String viewerId;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);

    // Names and faces come off the moments themselves (newest first, so a
    // face is the latest one they posted with): the author projection is
    // denormalized onto every row precisely so no screen resolves a user.
    final names = <String, String>{};
    final faces = <String, String?>{};
    for (final m in points) {
      names.putIfAbsent(m.userId, () => m.nameIn(context));
      faces.putIfAbsent(m.userId, () => m.avatarIn(context));
    }

    final places = MomentTally.placesOf(tallies);
    final top = tallies.length < max ? tallies.length : max;
    final me = tallies.indexWhere((t) => t.userId == viewerId);
    final rowHeight =
        MediaQuery.textScalerOf(context).scale(56).clamp(56.0, 84.0);

    Widget row(int i) => _TallyRow(
          tally: tallies[i],
          place: places[i],
          name: names[tallies[i].userId] ?? '',
          face: faces[tallies[i].userId],
          isViewer: tallies[i].userId == viewerId,
        );

    final inset = kPersonRowTextInset + kPersonRowLead;
    return ClipRRect(
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      child: ColoredBox(
        color: groupedFill(theme),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: rowHeight * top,
              child: Stack(
                children: [
                  for (var i = 1; i < top; i++)
                    Positioned(
                      top: rowHeight * i,
                      left: inset,
                      right: 0,
                      height: hairline,
                      child: ColoredBox(
                        color: theme.ink.withValues(alpha: 0.10),
                      ),
                    ),
                  for (var i = 0; i < top; i++)
                    AnimatedPositioned(
                      key: ValueKey('rank_${tallies[i].userId}'),
                      duration: motion.d(theme.motionMed),
                      curve: motion.c(theme.motionEntrance),
                      top: i * rowHeight,
                      left: 0,
                      right: 0,
                      height: rowHeight,
                      child: Center(child: row(i)),
                    ),
                ],
              ),
            ),
            // Below the shown rows: the viewer, pinned, so the board always
            // answers "where am I".
            if (me >= top) ...[
              Container(
                height: hairline,
                color: theme.ink.withValues(alpha: 0.10),
              ),
              row(me),
            ],
          ],
        ),
      ),
    );
  }
}

class _TallyRow extends StatelessWidget {
  const _TallyRow({
    required this.tally,
    required this.place,
    required this.name,
    required this.face,
    required this.isViewer,
  });

  final MomentTally tally;
  final int place;
  final String name;
  final String? face;
  final bool isViewer;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final tags = [
      for (final tag in MomentTag.values)
        if (tally.of(tag) > 0) tag,
    ];
    return ScoreRow(
      rank: place,
      medal: tally.total > 0,
      userId: tally.userId,
      name: name,
      isViewer: isViewer,
      avatarStorageId: face,
      semantics: '${tally.total}',
      // Which categories they scored in, so a row says what KIND of day
      // they had rather than only how loud it was.
      extra: tags.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < tags.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Icon(
                    MomentTagChip.iconFor(tags[i]),
                    key: ValueKey('${tally.userId}_${tags[i].wire}'),
                    size: 13,
                    color: momentTagColor(theme, tags[i]),
                  ),
                ],
              ],
            ),
      trailing: OdometerNumber(
        value: tally.total,
        // The score's own style, so the digits roll in place and line up
        // with every other board's.
        style: groupedTitleStyle(theme).copyWith(
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// One point: the poster's face wearing the category, the caption as the
/// row's title (the line of text IS the point), "who · category · when"
/// under it, and the photo as a thumbnail when there is one.
class PointRow extends StatelessWidget {
  const PointRow({
    super.key,
    required this.moment,
    required this.viewerId,
    required this.api,
    required this.onTap,
    this.index = 0,
  });

  final Moment moment;
  final String viewerId;
  final ChatApi api;

  /// Handed this row's own screen rect; see [PointsBoard.onOpen].
  final void Function(Rect? origin) onTap;

  /// Its place in the list, for the entrance stagger.
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tag = moment.tag;
    if (tag == null) return const SizedBox.shrink();
    final mine = moment.userId == viewerId;
    final tagLabel = MomentTagChip.labelFor(l10n, tag);
    // Verb agreement makes a single interpolated template impossible in
    // Turkish, Japanese, Korean and others; two keys, one per person.
    final who = mine
        ? l10n.pointLineSelf(tagLabel)
        : l10n.pointLineOther(moment.nameIn(context), tagLabel);
    final caption = moment.caption?.trim() ?? '';
    final title = caption.isEmpty ? who : caption;
    final subtitle = [
      if (caption.isNotEmpty) who,
      relativeAgo(l10n, moment.createdAt),
    ].join(' · ');
    final thumb = moment.thumbStorageId;

    return _Entrance(
      index: index,
      child: Builder(
        builder: (context) => PersonRow(
          avatar: PlayerFace(
            userId: moment.userId,
            label: mine ? l10n.momentRailYouLabel : moment.nameIn(context),
            size: kPersonRowAvatar,
            storageId: moment.avatarIn(context),
            dot: !moment.mine && !moment.seen,
            badge: Icon(
              MomentTagChip.iconFor(tag),
              size: 11,
              color: momentTagColor(theme, tag),
            ),
          ),
          title: title,
          titleMaxLines: 2,
          subtitle: subtitle,
          semanticLabel: '$who. $caption',
          onTap: () => onTap(tapOriginRect(context)),
          trailing: thumb == null ? null : _Thumb(storageId: thumb, api: api),
        ),
      ),
    );
  }
}

/// A 36pt picture on a row's trailing edge.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.storageId, required this.api});

  final String storageId;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return RemoteImage(
      storageId: storageId,
      api: api,
      width: 36,
      height: 36,
      borderRadius: BorderRadius.circular(theme.radiusSm),
    );
  }
}

/// A row's first appearance: risen and faded in, staggered by [index].
/// Keyed by identity upstream, so only a NEW row plays it.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    if (motion.calm) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 40),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 8),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: child,
    );
  }
}

/// Every point today, newest first, in a sheet; what "See all" opens.
/// Reads the board live, so a point landing while it is open appears.
Future<void> showPointsSheet(
  BuildContext context, {
  required String viewerId,
  required ChatApi api,
  required void Function(Moment moment, Rect? origin) onOpen,
}) {
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (_) => _PointsSheet(
      viewerId: viewerId,
      api: api,
      onOpen: onOpen,
    ),
  );
}

class _PointsSheet extends StatelessWidget {
  const _PointsSheet({
    required this.viewerId,
    required this.api,
    required this.onOpen,
  });

  final String viewerId;
  final ChatApi api;
  final void Function(Moment moment, Rect? origin) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.feedBoardStandingsLabel),
      showClose: true,
      padding: EdgeInsets.zero,
      // Tall, and the list runs to the bottom edge under the home
      // indicator: a long list, not a card with a solid foot.
      maxHeightFraction: 0.92,
      scrollsUnderInset: true,
      child: ListenableBuilder(
        listenable: FeedStore.instance,
        builder: (context, _) {
          final points = FeedStore.instance.points;
          return ListView(
            padding: sheetListPadding(context),
            children: [
              SheetRise(
                child: SheetGroup(
                  children: [
                    for (final m in points)
                      PointRow(
                        key: ValueKey('pts_${m.id}'),
                        moment: m,
                        viewerId: viewerId,
                        api: api,
                        onTap: (origin) => onOpen(m, origin),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: PointsExplainerButton(),
              ),
            ],
          );
        },
      ),
    );
  }
}
