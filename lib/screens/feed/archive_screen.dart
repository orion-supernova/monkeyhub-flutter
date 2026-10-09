import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/moment.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/steady_hero.dart';
import '../../widgets/filter_capsule.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/photo_chrome.dart' show MediaPlayDisc;

import 'moment_viewer.dart';
import '../../l10n/text_case.dart';
import '../../widgets/desktop_scroll.dart';

/// Everything you have kept, by day.
///
/// A moment drops off friends' boards after 24 hours but the row and its blob
/// survive — so without this screen the archive was a promise nothing
/// delivered. You could post something you liked and then never see it again,
/// which is the opposite of what "kept forever" is supposed to mean.
///
/// The date rail across the top is the point. Scrolling a flat list back
/// through months is not browsing, it is scrubbing; a row of days you can flick
/// through and jump into is. Days are derived from what has actually loaded, so
/// the rail never offers a date with nothing behind it.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({
    super.key,
    required this.api,
    required this.feedApi,
    required this.userId,
    this.ofUserId,
    this.title,
  });

  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  /// Null means the viewer's own archive, which is always complete. A friend's
  /// is gated on their history setting and can come back empty or refused.
  final String? ofUserId;

  final String? title;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final _scroll = ScrollController();
  final _dayKeys = <String>[];
  final _byDay = <String, List<Moment>>{};

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _errorCode;
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore(first: true);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || !_hasMore) return;
    final pos = _scroll.position;
    // 600px of runway, so the next page is usually already in by the time the
    // user gets there rather than being a visible stall at the bottom.
    if (pos.pixels > pos.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _loadMore({bool first = false}) async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      if (first) _loading = true;
    });
    try {
      final page = await widget.feedApi.archive(
        userId: widget.userId,
        ofUserId: widget.ofUserId,
        // Cursor is the oldest row we hold. Timestamp cursors, not offsets —
        // a new post landing mid-scroll would shift every offset by one and
        // silently duplicate a row.
        beforeTimestamp: _oldest?.millisecondsSinceEpoch,
        limit: 40,
      );
      if (!mounted) return;
      setState(() {
        for (final m in page.items) {
          final list = _byDay.putIfAbsent(m.dayKey, () {
            _dayKeys.add(m.dayKey);
            return <Moment>[];
          });
          // Guard against a duplicate arriving across a page boundary.
          if (!list.any((x) => x.id == m.id)) list.add(m);
        }
        // Sorted, not left in arrival order.
        //
        // `feed:archive` pages by `createdAt` descending, but a row is filed
        // under its `dayKey` — which is the AUTHOR's local day, not an instant
        // (see `Moment.dayKey`). The two disagree the moment a zone does: a
        // friend who flies east, or anyone either side of a DST shift, produces
        // moments whose instants descend while their day keys interleave, and
        // the days then come out shuffled.
        //
        // `YYYY-MM-DD` sorts chronologically as a string, so this is also the
        // comparison that keeps a malformed key from throwing.
        _dayKeys.sort((a, b) => b.compareTo(a));
        for (final day in _dayKeys) {
          _byDay[day]?.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _selectedDay ??= _dayKeys.isEmpty ? null : _dayKeys.first;
      });
      // After the frame this setState schedules: the scroll position has no
      // extent until the list has been laid out with these rows in it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _topUp();
      });
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      setState(() {
        _loading = false;
        _loadingMore = false;
        _hasMore = false;
        _errorCode = ['HISTORY_PRIVATE', 'NOT_A_FRIEND']
            .firstWhere(s.contains, orElse: () => 'UNKNOWN');
      });
    }
  }

  /// Fetches the next page when the one that just landed did not fill the
  /// screen.
  ///
  /// Pagination hangs off [_onScroll], which only fires when the list MOVES —
  /// so a first page shorter than the viewport left the archive with no way to
  /// ask for the second. It was reachable only by dragging into the overscroll
  /// bounce, which produces just enough scroll activity to trip the runway
  /// check: days that existed, that the screen knew about, and that you had to
  /// discover by pulling on a list that looked finished.
  ///
  /// Terminates on its own: each call consumes a page, so either `hasMore` goes
  /// false or the content grows past the viewport and the ordinary scroll-based
  /// path takes over.
  void _topUp() {
    if (!mounted || !_hasMore || _loadingMore || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent > pos.viewportDimension * 0.5) return;
    _loadMore();
  }

  DateTime? get _oldest {
    DateTime? out;
    for (final list in _byDay.values) {
      for (final m in list) {
        if (out == null || m.createdAt.isBefore(out)) out = m.createdAt;
      }
    }
    return out;
  }

  void _jumpTo(String dayKey) {
    setState(() => _selectedDay = dayKey);
    final index = _dayKeys.indexOf(dayKey);
    if (index < 0) return;
    // Scroll rather than filter: filtering hides the neighbouring days, and
    // "look around" was the request. Jumping keeps everything reachable.
    final key = _sectionKeys[dayKey];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  final _sectionKeys = <String, GlobalKey>{};

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // The shared pushed page: back chevron, large title at the standard
    // inset, and the page's own scroll controller so pagination still hangs
    // off it.
    return IosPage(
      title: sentenceCaseOf(context, widget.title ?? l10n.archiveScreenTitle),
      controller: _scroll,
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            // Wider than the default reading column: this screen is a photo
            // grid, not text, so an expanded window shows more tiles per row
            // instead of the same 3-wide mobile grid parked in the middle of
            // the page — see `_DaySection`'s `LayoutBuilder`.
            final maxWidth =
                context.isExpanded ? ContentWidth.wide : ContentWidth.readable;
            final side = ((constraints.crossAxisExtent - maxWidth) / 2)
                .clamp(0.0, double.infinity);
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: SliverMainAxisGroup(
                slivers: [
                  if (_dayKeys.isNotEmpty)
                    // Pinned under the bar: the rail is how you jump between
                    // days, so it has to be there wherever you have scrolled.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _RailHeader(
                        height: MediaQuery.textScalerOf(context)
                            .scale(34)
                            .clamp(34.0, 60.0) + 16,
                        fill: theme.background,
                        child: _DateRail(
                          dayKeys: _dayKeys,
                          selected: _selectedDay,
                          onTap: _jumpTo,
                        ),
                      ),
                    ),
                  ..._body(theme, l10n),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _body(AppTheme theme, AppLocalizations l10n) {
    if (_loading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CupertinoActivityIndicator(color: theme.inkMuted),
          ),
        ),
      ];
    }
    if (_errorCode != null && _dayKeys.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
              child: EmptyState(
                icon: CupertinoIcons.lock_fill,
                title: switch (_errorCode) {
                  'HISTORY_PRIVATE' => l10n.archiveScreenPrivateTitle,
                  'NOT_A_FRIEND' => l10n.archiveScreenNotFriendTitle,
                  _ => l10n.archiveScreenErrorTitle,
                },
                message: switch (_errorCode) {
                  'HISTORY_PRIVATE' => l10n.archiveScreenPrivateBody,
                  'NOT_A_FRIEND' => l10n.archiveScreenNotFriendBody,
                  _ => l10n.archiveScreenErrorBody,
                },
              ),
            ),
          ),
        ),
      ];
    }
    if (_dayKeys.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
              child: EmptyState(
                icon: CupertinoIcons.camera,
                title: widget.ofUserId == null
                    ? l10n.archiveScreenEmptyTitle
                    : l10n.archiveScreenEmptyFriendTitle,
                message: widget.ofUserId == null
                    ? l10n.archiveScreenEmptyBody
                    : l10n.archiveScreenEmptyFriendBody,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, edgeToEdgeBottom(context)),
        sliver: SliverList.builder(
          // One extra row for the tail spinner / end marker.
          itemCount: _dayKeys.length + 1,
          itemBuilder: (context, i) {
            if (i == _dayKeys.length) {
              if (_loadingMore) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CupertinoActivityIndicator(color: theme.inkMuted),
                  ),
                );
              }
              return EmptyLine(l10n.archiveScreenEnd);
            }
            final day = _dayKeys[i];
            return _DaySection(
              key: _sectionKeys.putIfAbsent(day, GlobalKey.new),
              dayKey: day,
              moments: _byDay[day] ?? const [],
              api: widget.api,
              onOpen: (m) => showMomentViewer(
                context,
                moment: m,
                api: widget.api,
                feedApi: widget.feedApi,
                userId: widget.userId,
                // The whole day is the run, so a picture opened from the grid
                // can be swiped through like the gallery it visually already
                // is. The tile is showing the picture, so it flies — on the
                // same tag the feed rail uses, which is safe because the two
                // are never in the same route.
                siblings: _byDay[day] ?? const [],
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// Pins the date rail under the page bar, on a solid page fill once the grid
/// scrolls underneath, so it never shows through the chips.
class _RailHeader extends SliverPersistentHeaderDelegate {
  _RailHeader({required this.height, required this.fill, required this.child});

  final double height;
  final Color fill;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  // Transparent at rest, so the theme's backdrop runs unbroken behind the
  // chips; the solid fill only arrives once the grid is scrolling under them.
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(
        color: overlaps ? fill : fill.withValues(alpha: 0),
        child: child,
      );

  @override
  bool shouldRebuild(_RailHeader old) =>
      old.height != height || old.fill != fill || old.child != child;
}

/// A dayKey ("YYYY-MM-DD") as a localized date that always carries its year.
///
/// `formatFullDate` — "Friday, August 28, 2026", "28 Ağustos 2026 Cuma" — the
/// long form, spelled out. It once ellipsized in a one-line header beside a
/// rule, losing the year, which is the one thing a reader browsing an ARCHIVE
/// cannot infer from context; so for a while this composed the medium date
/// with the year instead. That read as a stamp ("4 Eki Paz · 2026"), and the
/// header now wraps to two lines, so the full date has room to be a date.
///
/// `MaterialLocalizations` rather than `intl`, which is only a transitive
/// dependency here and is not worth promoting to a direct one for a date
/// string.
String archiveDayLabel(BuildContext context, String dayKey) {
  final date = archiveDay(dayKey);
  if (date == null) return dayKey;
  return MaterialLocalizations.of(context).formatFullDate(date);
}

/// Parses a dayKey, or null when it is not one.
DateTime? archiveDay(String dayKey) {
  final parts = dayKey.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return null;
  return DateTime(parts[0]!, parts[1]!, parts[2]!);
}

/// The horizontal strip of days.
class _DateRail extends StatelessWidget {
  const _DateRail({
    required this.dayKeys,
    required this.selected,
    required this.onTap,
  });

  final List<String> dayKeys;
  final String? selected;
  final void Function(String dayKey) onTap;

  @override
  Widget build(BuildContext context) {
    return HorizontalWheelScroll(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // Vertical room for the focus ring, which paints outside its child's
        // bounds and is otherwise clipped by this scroll view.
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemCount: dayKeys.length,
        itemBuilder: (context, i) => Padding(
          key: ValueKey(dayKeys[i]),
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: FilterCapsule(
              label: _chipLabel(context, dayKeys[i]),
              active: dayKeys[i] == selected,
              onTap: () => onTap(dayKeys[i]),
              // Spoken, not spelled: "2026-08-28" is read out as digits.
              semanticLabel: archiveDayLabel(context, dayKeys[i]),
            ),
          ),
        ),
      ),
    );
  }

  /// One line, localized: "Oct 4" this year, the medium date (which carries
  /// the year) for any other. The old three-line "04 / 10.26 / 9" stamp was
  /// hard to read, and its count only repeated the section header's.
  static String _chipLabel(BuildContext context, String dayKey) {
    final date = archiveDay(dayKey);
    if (date == null) return dayKey;
    final l = MaterialLocalizations.of(context);
    return date.year == DateTime.now().year
        ? l.formatShortMonthDay(date)
        : l.formatMediumDate(date);
  }
}

/// One day's worth: a localized header, then a grid.
class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.dayKey,
    required this.moments,
    required this.api,
    required this.onOpen,
  });

  final String dayKey;
  final List<Moment> moments;
  final ChatApi api;
  final void Function(Moment) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // NOT uppercased: Dart's toUpperCase is locale-independent and would turn a
    // Turkish 'i' into 'I' instead of 'İ'.
    final label = archiveDayLabel(context, dayKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  sentenceCaseOf(context, label),
                  style: theme.displaySmall.copyWith(color: theme.ink),
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              Text('${moments.length}', style: groupedMetaStyle(theme)),
            ],
          ),
          const SizedBox(height: 12),
          // Tile count follows the width it's actually given rather than a
          // flat 3 — a fixed count either crushes tiles on a handset (were it
          // any higher) or leaves a wide desktop pane at the same 3 phone-size
          // tiles per row it started with (were it any lower).
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              const tileTarget = 150.0;
              final columns = ((constraints.maxWidth + spacing) /
                      (tileTarget + spacing))
                  .floor()
                  .clamp(3, 7);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                ),
                itemCount: moments.length,
                itemBuilder: (context, i) => _ArchiveTile(
                  // Identity, never index.
                  key: ValueKey(moments[i].id),
                  moment: moments[i],
                  api: api,
                  index: i,
                  onTap: () => onOpen(moments[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    super.key,
    required this.moment,
    required this.api,
    required this.index,
    required this.onTap,
  });

  final Moment moment;
  final ChatApi api;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final thumbId = moment.thumbStorageId;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 25),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) =>
          Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      child: SpringPress(
        onTap: onTap,
        haptic: false,
        scale: PressSpec.scaleSmall,
        semanticLabel: moment.caption ?? '',
        focusRadius: theme.radiusMd,
        child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbId != null)
                // The picture flies to the viewer — see [momentMediaHeroTag].
                SteadyHero(
                  tag: momentMediaHeroTag(moment.id),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                    child: RemoteImage(
                      storageId: thumbId,
                      api: api,
                      fit: BoxFit.cover,
                      // One axis only — passing both squashes the bitmap before
                      // `fit` runs. The shared constant, not a number of its
                      // own: the viewer reuses this exact decode as the flight's
                      // backdrop and a different width is a different cache
                      // entry.
                      decodeWidth: momentThumbDecodeWidth,
                    ),
                  ),
                )
              else
                // Words only: the tag rides INLINE above the caption, never
                // floated over it — pinned to the corner it sat on the first
                // letters of every caption ("W̶ashed", "R̶an").
                Container(
                  decoration: BoxDecoration(
                    color: groupedFill(theme),
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                  ),
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (moment.tag != null) ...[
                        MomentTagChip(tag: moment.tag!, dense: true),
                        const SizedBox(height: 6),
                      ],
                      // As many whole lines as the tile has room for, then an
                      // ellipsis. `TextOverflow.fade` with no line cap never
                      // faded vertically here: the last line was sliced
                      // through the middle by the tile's bottom edge.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final style = groupedMetaStyle(theme).copyWith(
                              color: theme.inkSoft,
                            );
                            final line = MediaQuery.textScalerOf(context)
                                .scale(
                                  (style.fontSize ?? 13) *
                                      (style.height ?? 1.25),
                                );
                            return Text(
                              moment.caption ?? '',
                              style: style,
                              maxLines: math.max(
                                1,
                                (box.maxHeight / line).floor(),
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (moment.mediaKind == MomentMedia.video)
                const Center(child: MediaPlayDisc(size: 36)),
              // Over a picture the corner is free, so the badge stays there.
              if (moment.tag != null && thumbId != null)
                Positioned(
                  left: 4,
                  top: 4,
                  child: MomentTagChip(tag: moment.tag!, dense: true),
                ),
            ],
          ),
      ),
    );
  }
}
