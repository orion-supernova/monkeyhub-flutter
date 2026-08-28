import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/moment.dart';
import '../../theme/layout.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/steady_hero.dart';
import 'moment_viewer.dart';

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

  /// How far down the list we are, 0..1 — the scrubber's thumb position.
  ///
  /// Notifiers rather than `setState`: a scroll writes these on every frame,
  /// and rebuilding a grid of photographs sixty times a second to move a 40pt
  /// thumb is not a trade worth making.
  final _scrubAt = ValueNotifier<double>(0);

  /// The day currently under the top of the viewport, as a dayKey.
  ///
  /// Read off the section boxes rather than derived from the scroll offset:
  /// sections are as tall as the number of photographs in them, so an offset
  /// fraction is a decent way to *move* and a bad way to *say where you are*.
  final _scrubDay = ValueNotifier<String?>(null);

  /// Whether the scrubber is at FULL strength — the date pill showing, the
  /// thumb bright. True while the list moves and while a finger is on the rail;
  /// false a beat after both stop.
  ///
  /// Not the same as "mounted". The rail is on screen and hittable the whole
  /// time the list is long enough to be worth scrubbing, dimmed at rest. That
  /// distinction is the entire difference between a control and a decoration:
  /// the first version only existed during a scroll, so by the time you saw it
  /// there was nothing to grab, and reaching for it did nothing at all.
  final _scrubLoud = ValueNotifier<bool>(false);

  /// Whether there is enough list to be worth a fast-scroll rail. A short
  /// archive is one flick from end to end and does not want furniture.
  final _canScrub = ValueNotifier<bool>(false);

  Timer? _scrubHide;
  bool _scrubbing = false;

  /// The list's own box, read once per offset rebuild for its width — see
  /// [_rebuildDayStarts]. Nothing measures section positions through it any
  /// more; that is what [_dayStarts] replaced.
  final _listKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore(first: true);
  }

  @override
  void dispose() {
    _scrubHide?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrubAt.dispose();
    _scrubDay.dispose();
    _scrubLoud.dispose();
    _canScrub.dispose();
    super.dispose();
  }

  void _onScroll() {
    _trackScrub();
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
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _selectedDay ??= _dayKeys.isEmpty ? null : _dayKeys.first;
      });
      // After the frame this setState schedules, not before it: the scroll
      // position has no extent and the sections have no boxes until the list
      // has actually been laid out with these rows in it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measureScrub();
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

  /// Updates the thumb and the label from wherever the list has got to, and
  /// keeps the scrubber on screen for a moment after it stops.
  /// Where the rail's thumb goes, what it says, and whether it is worth having
  /// at all — WITHOUT deciding how loud it is.
  ///
  /// Split from [_trackScrub] because this half has to run once the list has
  /// laid out, not only once it has moved. It was folded in, so `_canScrub`
  /// stayed false until the first scroll — which left the rail
  /// `IgnorePointer`'d at rest, which is the whole reason reaching for it did
  /// nothing. A fast-scroller that only works after you have already scrolled
  /// is not a fast-scroller.
  void _measureScrub() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final extent = pos.maxScrollExtent;
    // Worth a rail once there is more than half a screen left to travel.
    _canScrub.value = extent > pos.viewportDimension * 0.5;
    // Pure arithmetic on the offset, so the thumb tracks the finger exactly.
    _scrubAt.value = extent <= 0 ? 0 : (pos.pixels / extent).clamp(0.0, 1.0);
    // Cheap: one render-box read and a record comparison, then an early return
    // on every frame where nothing that feeds the offsets has moved.
    _rebuildDayStarts();
    _refreshDay(pos.pixels);
  }

  /// Names the day the top of the viewport is currently inside.
  ///
  /// Synchronous, and called straight from the scroll callback, which the
  /// previous implementation could not be. It walked section render boxes, and
  /// `ScrollController` notifies from inside `setPixels` — before the viewport
  /// has laid out at the new offset — so every box it measured was still where
  /// it had been one frame earlier. Deferring the walk to a post-frame callback
  /// fixed the staleness and left the rest: a 24pt tolerance that flipped the
  /// label while the next day's header was still below the fold, and a fallback
  /// that named the newest day in the archive whenever the walk matched
  /// nothing. [_dayStarts] has none of those failure modes because it does not
  /// measure anything.
  void _refreshDay(double pixels) {
    final day = _dayAtOffset(pixels);
    if (day == null || day == _scrubDay.value) return;
    _scrubDay.value = day;
    // A tick per day crossed, so a drag down the rail feels like flicking
    // through a stack rather than sliding a slider. Only while scrubbing: an
    // ordinary fling past forty days would be a burst of buzzing.
    if (_scrubbing) HapticFeedback.selectionClick();
  }

  void _trackScrub() {
    if (!_scroll.hasClients) return;
    _measureScrub();
    // A drag on the rail keeps it loud by itself; this timer is for the
    // ordinary case of flicking the list and watching where you land.
    if (_scrubbing) return;
    _scrubLoud.value = true;
    _scrubHide?.cancel();
    _scrubHide = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_scrubbing) _scrubLoud.value = false;
    });
  }

  /// Scroll offset of the top of each day's section, in `_dayKeys` order.
  ///
  /// Computed, not measured — see [archiveSectionHeight]. Rebuilt by
  /// [_rebuildDayStarts] whenever the days, their counts, the list's width or
  /// the text scale change, which is the only time any of these numbers can
  /// move.
  List<double> _dayStarts = const [];

  /// What [_dayStarts] was built for, so a rebuild is skipped when nothing that
  /// feeds it has changed.
  ({double width, double scale, int days, int photos})? _dayStartsFor;

  /// The text scale, captured in `build` so the offset rebuild — which runs
  /// from a scroll callback — never has to touch `MediaQuery`.
  double _textScale = 1;

  void _rebuildDayStarts() {
    final box = _listKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // Every input, so a page that only ADDS photos to a day already in the list
    // invalidates the cache too — the day count alone would not have moved.
    final photos = _byDay.values.fold(0, (a, b) => a + b.length);
    final signature = (
      width: box.size.width,
      scale: _textScale,
      days: _dayKeys.length,
      photos: photos,
    );
    if (signature == _dayStartsFor) return;
    _dayStartsFor = signature;

    // The width the sections are laid out into: the list's box less its own
    // horizontal padding.
    final inner = box.size.width - _listPadLeft - _listPadRight;
    final header = archiveHeaderHeightFor(_textScale);
    final starts = <double>[];
    // The list's top padding is part of the scrollable extent, so the first
    // section starts there rather than at zero.
    var y = _listPadTop;
    for (final day in _dayKeys) {
      starts.add(y);
      y += archiveSectionHeight(
        count: _byDay[day]?.length ?? 0,
        width: inner,
        headerHeight: header,
      );
    }
    _dayStarts = starts;
  }

  /// The dayKey whose section contains scroll offset [pixels].
  ///
  /// A binary search over [_dayStarts]: the last day that has already started.
  /// No tolerance, so the label changes exactly as a section header crosses the
  /// top edge rather than 24pt early; no fallback, so it can never name a day
  /// that is nowhere near the screen.
  String? _dayAtOffset(double pixels) {
    if (_dayStarts.isEmpty) return null;
    var lo = 0;
    var hi = _dayStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_dayStarts[mid] <= pixels) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return _dayKeys[lo];
  }

  /// Scrubbing: the finger's position along the track IS the position in the
  /// list.
  ///
  /// Mapped through `maxScrollExtent` — which for a lazily built list is the
  /// delegate's estimate rather than a measurement, so a long drag can land a
  /// little off where the thumb suggested. The LABEL does not inherit that: it
  /// comes from [_dayAtOffset], which is arithmetic on where the list actually
  /// is. Being told the wrong date would be worse than landing a screen early,
  /// so the approximate half is the half that moves.
  void _scrubTo(double fraction) {
    if (!_scroll.hasClients) return;
    final extent = _scroll.position.maxScrollExtent;
    if (extent <= 0) return;
    // The jump notifies the controller, which lands in [_measureScrub], which
    // renames the day from the new offset in the same call — no frame in
    // between for the label to be wrong in.
    _scroll.jumpTo((fraction.clamp(0.0, 1.0)) * extent);
  }

  void _scrubStart() {
    _scrubbing = true;
    _scrubHide?.cancel();
    _scrubLoud.value = true;
  }

  void _scrubEnd() {
    _scrubbing = false;
    _scrubHide?.cancel();
    _scrubHide = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_scrubbing) _scrubLoud.value = false;
    });
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
    _textScale = MediaQuery.textScalerOf(context).scale(1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // `bottom: false`, with the inset moved onto the grid below — see
          // [edgeToEdgeBottom].
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              // Wider than the default reading column: this screen is a photo
              // grid, not text, so an expanded window should show more tiles
              // per row instead of the same 3-wide mobile grid parked in the
              // middle of the page — see `_DaySection`'s `LayoutBuilder`.
              maxWidth: context.isExpanded
                  ? ContentWidth.wide
                  : ContentWidth.readable,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.arrow_back,
                            color: theme.inkSoft,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.title ?? l10n.archiveScreenTitle,
                            style: theme.displaySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_dayKeys.isNotEmpty)
                    _DateRail(
                      dayKeys: _dayKeys,
                      counts: {
                        for (final e in _byDay.entries) e.key: e.value.length,
                      },
                      selected: _selectedDay,
                      onTap: _jumpTo,
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _body(theme, l10n)),
                        if (_dayKeys.isNotEmpty)
                          // Full width, not a 28pt strip. The scrub rail draws
                          // in the gutter, but its THUMB carries a date pill
                          // that reaches most of the way across the screen, and
                          // a box only has hit tests inside its own bounds. The
                          // scrubber's own Stack has no hit area of its own —
                          // only the track and the thumb do — so everywhere
                          // else the pointer falls straight through to the grid.
                          Positioned.fill(
                            child: _DateScrubber(
                              at: _scrubAt,
                              day: _scrubDay,
                              loud: _scrubLoud,
                              enabled: _canScrub,
                              onStart: _scrubStart,
                              onEnd: _scrubEnd,
                              onScrub: _scrubTo,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(dynamic theme, AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: theme.accent, strokeWidth: 2),
      );
    }
    if (_errorCode != null && _dayKeys.isEmpty) {
      return _Empty(
        icon: Icons.lock_outline,
        title: switch (_errorCode) {
          'HISTORY_PRIVATE' => l10n.archiveScreenPrivateTitle,
          'NOT_A_FRIEND' => l10n.archiveScreenNotFriendTitle,
          _ => l10n.archiveScreenErrorTitle,
        },
        body: switch (_errorCode) {
          'HISTORY_PRIVATE' => l10n.archiveScreenPrivateBody,
          'NOT_A_FRIEND' => l10n.archiveScreenNotFriendBody,
          _ => l10n.archiveScreenErrorBody,
        },
      );
    }
    if (_dayKeys.isEmpty) {
      return _Empty(
        icon: Icons.photo_camera_outlined,
        title: widget.ofUserId == null
            ? l10n.archiveScreenEmptyTitle
            : l10n.archiveScreenEmptyFriendTitle,
        body: widget.ofUserId == null
            ? l10n.archiveScreenEmptyBody
            : l10n.archiveScreenEmptyFriendBody,
      );
    }

    return ListView.builder(
      key: _listKey,
      controller: _scroll,
      // 28 on the right, not 20: that is the scrub rail's width, so the rail
      // lives entirely in the gutter and never covers a tile. A rail that has
      // to be hittable and a grid that has to be tappable cannot share the same
      // 20pt.
      padding: EdgeInsets.fromLTRB(
        _listPadLeft,
        _listPadTop,
        _listPadRight,
        edgeToEdgeBottom(context),
      ),
      // One extra row for the tail spinner / end marker.
      itemCount: _dayKeys.length + 1,
      itemBuilder: (context, i) {
        if (i == _dayKeys.length) {
          if (_loadingMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.accent,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.archiveScreenEnd,
                style: theme.monoTiny.copyWith(color: theme.inkMuted),
              ),
            ),
          );
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
            // The whole day is the run, so a picture opened from the grid can
            // be swiped through like the gallery it visually already is. The
            // tile is showing the picture, so it flies — on the same tag the
            // feed rail uses, which is safe because the two are never in the
            // same route.
            siblings: _byDay[day] ?? const [],
          ),
        );
      },
    );
  }
}

/// The archive list's own padding, named because the scrub rail's arithmetic
/// depends on all four numbers and a literal in two places is a literal that
/// drifts. Right is [_DateScrubber._trackWidth] exactly, so the rail sits in
/// the gutter rather than over a tile.
const double _listPadLeft = 20;
const double _listPadTop = 8;
const double _listPadRight = 28;

/// Height of a day section's header row.
///
/// **Pinned rather than measured, and that is the point.** Everything else in a
/// section is arithmetic — square tiles, fixed spacing, a computed column count
/// — so this one line of text was the only reason a section's height could not
/// be known without laying it out. Fixing it makes [archiveSectionHeight] exact,
/// which is what lets the scrub rail name the right day from the scroll offset
/// alone instead of chasing render boxes a frame behind the finger.
///
/// Scaled and clamped the way `_DateRail` and `MomentRail` size themselves: a
/// flat number clips the label at accessibility text sizes.
double archiveHeaderHeight(BuildContext context) =>
    archiveHeaderHeightFor(MediaQuery.textScalerOf(context).scale(1));

/// [archiveHeaderHeight] for a text scale that has already been read.
///
/// The rail rebuilds its offsets from a scroll callback, where reaching into
/// `MediaQuery` would register an inherited-widget dependency outside a build.
double archiveHeaderHeightFor(double textScale) =>
    (18 * textScale).clamp(18.0, 34.0);

/// The exact height of one day's section: header, gap, photo grid, and the
/// separation before the next day.
///
/// Mirrors `_DaySection.build` and `_archiveColumns` — the grid is a
/// `SliverGridDelegateWithFixedCrossAxisCount` with no `childAspectRatio`, so
/// tiles are square, and `shrinkWrap: true` lays every row out at once, so a
/// section reaches its full height the moment it is built. There is nothing
/// lazy left to estimate.
///
/// The same trade `room_content_screen`'s `_revealInGrid` already makes: a grid
/// whose geometry is known is worth computing rather than measuring.
double archiveSectionHeight({
  required int count,
  required double width,
  required double headerHeight,
}) {
  final columns = archiveColumns(width);
  final tile = (width - _gridSpacing * (columns - 1)) / columns;
  final rows = (count / columns).ceil();
  final grid = rows == 0 ? 0.0 : rows * tile + (rows - 1) * _gridSpacing;
  return headerHeight + _headerToGrid + grid + _sectionGap;
}

/// Tiles per row at [width]. Shared by the grid that draws them and the rail
/// that has to predict them.
int archiveColumns(double width) =>
    ((width + _gridSpacing) / (_tileTarget + _gridSpacing))
        .floor()
        .clamp(3, 7);

const double _gridSpacing = 8;
const double _tileTarget = 150;
const double _headerToGrid = 12;
const double _sectionGap = 26;

/// The scrub rail's date pill.
///
/// Keyed because the day it names is also drawn as a section header inside the
/// list, so "find the text" is ambiguous exactly when the two agree — which is
/// the state every test of this is trying to assert.
@visibleForTesting
const Key archiveScrubberPillKey = Key('archive-scrubber-pill');

/// A dayKey ("YYYY-MM-DD") as a localized date that always carries its year.
///
/// `formatFullDate` — "Friday, August 28, 2026" — is what the section headers
/// used, and on a phone it ellipsized: the part that fell off the end was the
/// year, which is the one thing a reader browsing an ARCHIVE cannot infer from
/// context. `formatMediumDate` is short enough to survive but drops the year
/// entirely, so the two are composed.
///
/// Composed rather than formatted through `intl`, which is only a transitive
/// dependency here and is not worth promoting to a direct one for a date
/// string. `MaterialLocalizations` supplies both halves already localized.
String archiveDayLabel(BuildContext context, String dayKey) {
  final date = archiveDay(dayKey);
  if (date == null) return dayKey;
  final l = MaterialLocalizations.of(context);
  return '${l.formatMediumDate(date)} · ${l.formatYear(date)}';
}

/// Parses a dayKey, or null when it is not one.
DateTime? archiveDay(String dayKey) {
  final parts = dayKey.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return null;
  return DateTime(parts[0]!, parts[1]!, parts[2]!);
}

/// The fast-scroll rail down the right edge of the archive.
///
/// An archive is the one list in this app that can be genuinely long — years
/// of days, forty moments at a time — and a flick-and-wait scroll through it is
/// not browsing, it is scrubbing. The date rail across the top answers "take me
/// to that day" for the days that have loaded; this answers "take me a long way,
/// and tell me where I am on the way" without needing them named first.
///
/// Deliberately not a `Scrollbar`. Flutter's is interactive and correctly
/// styled, and it can say nothing at all about *what* you are scrolling past —
/// which on a list keyed by date is the only question worth answering.
///
/// **On screen the whole time the list is long enough to want it**, dimmed at
/// rest and bright while it is being used. The first version faded in only
/// while the list was already moving, which is a control you cannot reach: by
/// the time it appeared your finger was on the grid, and reaching for it where
/// it had just been did nothing, because it was neither drawn nor hittable.
/// A fast-scroller has to be somewhere before you decide to use it.
class _DateScrubber extends StatelessWidget {
  const _DateScrubber({
    required this.at,
    required this.day,
    required this.loud,
    required this.enabled,
    required this.onStart,
    required this.onEnd,
    required this.onScrub,
  });

  final ValueListenable<double> at;
  final ValueListenable<String?> day;

  /// Full strength: the date pill out, the thumb bright.
  final ValueListenable<bool> loud;

  /// Whether there is enough list to scrub at all.
  final ValueListenable<bool> enabled;

  final VoidCallback onStart;
  final VoidCallback onEnd;
  final void Function(double fraction) onScrub;

  /// The width of the list's right gutter, exactly — see the padding on the
  /// `ListView` this sits over. Wide enough to hit with a thumb, and narrow
  /// enough to fit in the margin rather than over a photograph.
  static const _trackWidth = 28.0;
  static const _thumbHeight = 42.0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: enabled,
      builder: (context, on, child) => IgnorePointer(
        // A short archive is one flick end to end; a rail there is furniture
        // that also eats the right edge of the grid.
        ignoring: !on,
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: child,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = (constraints.maxHeight - _thumbHeight).clamp(1.0, 1e6);

          void scrubToY(double y) =>
              onScrub(((y - _thumbHeight / 2) / travel).clamp(0.0, 1.0));

          // Two hit regions, one gesture path, and NEITHER of them is this
          // Stack — it spans the screen so the pill's box fits inside it, and a
          // Stack with only positioned children hit-tests nothing of its own,
          // so the grid underneath keeps every pointer that misses both.
          //
          // The track is the 28pt gutter: a drag or a tap anywhere down it
          // scrubs, which is what a rail you can see the length of is for. The
          // THUMB is the second, because the pill is what people reach for —
          // it is the only part of this that looks like a handle. It paints
          // far outside the track, which `Clip.none` allows, but
          // `RenderBox.hitTest` gates on the parent's own size before it
          // descends: as a child of the 28pt box the pill was visible and
          // completely inert.
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: _trackWidth,
                child: _ScrubGestures(
                  onStart: onStart,
                  onEnd: onEnd,
                  scrubToY: scrubToY,
                  child: const SizedBox.expand(),
                ),
              ),
              ValueListenableBuilder<double>(
                valueListenable: at,
                builder: (context, fraction, _) => Positioned(
                  top: fraction * travel,
                  right: 6,
                  child: _ScrubGestures(
                    // A grab, not a jump: the finger has taken hold of the
                    // thumb where it already is, so the drag starts from the
                    // thumb's current position and follows the deltas from
                    // there. Handing the pill's local y to the track would
                    // teleport the list on touch-down.
                    grabAt: fraction * travel + _thumbHeight / 2,
                    onStart: onStart,
                    onEnd: onEnd,
                    scrubToY: scrubToY,
                    child: _Thumb(day: day, loud: loud, theme: theme),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The scrub gesture, mounted twice: once over the rail, once over the thumb.
///
/// One widget so the two cannot drift into behaving differently — the thumb
/// used to have no gesture at all, and bolting a second copy of seven handlers
/// onto it is how that becomes two subtly different controls.
///
/// [offsetY] converts a drag that starts inside the thumb back into the track's
/// coordinate space. A `localPosition` is relative to whichever box received
/// the pointer, so without it a grab on the pill would report 20-odd points and
/// fling the list to the top.
class _ScrubGestures extends StatefulWidget {
  const _ScrubGestures({
    required this.onStart,
    required this.onEnd,
    required this.scrubToY,
    required this.child,
    this.grabAt,
  });

  final VoidCallback onStart;
  final VoidCallback onEnd;

  /// Called with a position in the TRACK's coordinate space.
  final void Function(double y) scrubToY;

  final Widget child;

  /// Non-null on the thumb: where on the track the thumb currently sits, so a
  /// drag that begins on it continues from there rather than from wherever
  /// inside the pill the finger happened to land.
  final double? grabAt;

  @override
  State<_ScrubGestures> createState() => _ScrubGesturesState();
}

class _ScrubGesturesState extends State<_ScrubGestures> {
  /// The running position of the drag, in track space.
  ///
  /// State, not a local in `build`: the pill rebuilds on every frame of a
  /// scrub — its own label changes — and a local would be reset to zero
  /// underneath the finger each time.
  double _y = 0;

  void _start(double localY) {
    widget.onStart();
    _y = widget.grabAt ?? localY;
    // Only the track commits on touch-down. A grab on the thumb should not
    // move anything until the finger does.
    if (widget.grabAt == null) widget.scrubToY(_y);
  }

  @override
  Widget build(BuildContext context) {
    final onThumb = widget.grabAt != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (d) => _start(d.localPosition.dy),
      onVerticalDragUpdate: (d) {
        // Deltas, not absolute positions: the thumb travels with the finger
        // instead of snapping its centre under it.
        _y += d.delta.dy;
        widget.scrubToY(_y);
      },
      onVerticalDragEnd: (_) => widget.onEnd(),
      onVerticalDragCancel: widget.onEnd,
      // A tap anywhere on the rail jumps there. Not on the thumb, where a tap
      // means "I have hold of this", not "go somewhere else".
      onTapDown: onThumb ? null : (d) => _start(d.localPosition.dy),
      onTapUp: onThumb ? null : (_) => widget.onEnd(),
      onTapCancel: onThumb ? null : widget.onEnd,
      child: widget.child,
    );
  }
}

/// The grip, with the date it is currently over spilling out to its left.
///
/// The date pill is the loud half: it is a running commentary on a gesture in
/// progress, and leaving it parked over the grid when nothing is moving would
/// be a permanent label for a scroll position nobody is changing.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.day, required this.loud, required this.theme});

  final ValueListenable<String?> day;
  final ValueListenable<bool> loud;
  final dynamic theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _DateScrubber._thumbHeight,
      child: ValueListenableBuilder<bool>(
        valueListenable: loud,
        builder: (context, isLoud, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: day,
            builder: (context, dayKey, _) {
              if (dayKey == null || !isLoud) return const SizedBox.shrink();
              return Container(
                key: archiveScrubberPillKey,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  archiveDayLabel(context, dayKey),
                  // accentInk on an accent fill, never white — NeonNight's
                  // accent is pure yellow and Graphite's is near-white.
                  style: theme.monoTiny.copyWith(color: theme.accentInk),
                  maxLines: 1,
                ),
              );
            },
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: isLoud ? 5 : 4,
            height: _DateScrubber._thumbHeight,
            decoration: BoxDecoration(
              // Dimmed rather than hidden at rest: still visible enough to say
              // "there is a rail here", quiet enough not to be a stripe down
              // the side of every photograph.
              color: theme.accent.withValues(alpha: isLoud ? 1.0 : 0.45),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// The horizontal strip of days.
class _DateRail extends StatelessWidget {
  const _DateRail({
    required this.dayKeys,
    required this.counts,
    required this.selected,
    required this.onTap,
  });

  final List<String> dayKeys;
  final Map<String, int> counts;
  final String? selected;
  final void Function(String dayKey) onTap;

  @override
  Widget build(BuildContext context) {
    // Scaled and clamped: a horizontal list imposes its cross-axis height as a
    // hard constraint, so a flat number clips the label at accessibility sizes.
    // Base accounts for the chip's three text lines (day/month/count, ~58px
    // at 1.4x line-height) plus its own padding, border and the rail's own
    // padding (~30px overhead) — 92 is that budget with a few px to spare.
    final height = MediaQuery.textScalerOf(context).scale(92).clamp(92.0, 124.0);
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // Vertical room for FocusableTap's ring, which paints outside its
        // child's bounds and is otherwise clipped by this scroll view.
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        itemCount: dayKeys.length,
        itemBuilder: (context, i) => Padding(
          key: ValueKey(dayKeys[i]),
          padding: const EdgeInsets.only(right: 8),
          child: _DayChip(
            dayKey: dayKeys[i],
            count: counts[dayKeys[i]] ?? 0,
            active: dayKeys[i] == selected,
            onTap: () => onTap(dayKeys[i]),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.dayKey,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String dayKey;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final parts = dayKey.split('-');
    // Rendered from the key's own digits rather than parsed into a DateTime
    // and formatted: the chip is a compact numeric stamp, and every locale
    // reads digits the same way. The month and the year share a line so the
    // chip stays three lines tall — an archive that runs back years was
    // offering "28 / 08" and no way to tell which August that was.
    final dayNum = parts.length == 3 ? parts[2] : dayKey;
    final year = parts.isEmpty || parts[0].length != 4
        ? ''
        : parts[0].substring(2);
    final stamp = parts.length == 3 ? '${parts[1]}.$year' : '';

    return FocusableTap(
      onTap: onTap,
      // Spoken, not spelled: "2026-08-28" is read out as a string of digits.
      semanticLabel: archiveDayLabel(context, dayKey),
      selected: active,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          // Two more points than before, for the ".26" the stamp grew.
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? theme.accent : theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: active ? theme.accent : theme.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                dayNum,
                style: theme.monoLarge.copyWith(
                  fontSize: 17,
                  // accentInk on an accent fill, never white.
                  color: active ? theme.accentInk : theme.ink,
                ),
              ),
              Text(
                stamp,
                style: theme.monoTiny.copyWith(
                  color: active ? theme.accentInk : theme.inkMuted,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: theme.monoTiny.copyWith(
                  color: active
                      ? theme.accentInk.withValues(alpha: 0.75)
                      : theme.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      padding: const EdgeInsets.only(bottom: _sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed height, so this section's total is arithmetic rather than
          // something only a layout pass knows — see [archiveHeaderHeight].
          SizedBox(
            height: archiveHeaderHeight(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: theme.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Container(height: 1, color: theme.divider)),
                const SizedBox(width: 8),
                Text('${moments.length}', style: theme.monoTiny),
              ],
            ),
          ),
          const SizedBox(height: _headerToGrid),
          // Tile count follows the width it's actually given rather than a
          // flat 3 — a fixed count either crushes tiles on a handset (were it
          // any higher) or leaves a wide desktop pane at the same 3 phone-size
          // tiles per row it started with (were it any lower).
          LayoutBuilder(
            builder: (context, constraints) {
              // The one place this is decided, so the scrub rail can predict
              // it — see [archiveColumns].
              final columns = archiveColumns(constraints.maxWidth);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: _gridSpacing,
                  crossAxisSpacing: _gridSpacing,
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
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: moment.caption ?? '',
        radius: theme.radiusMd,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
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
                Container(
                  decoration: BoxDecoration(
                    color: theme.surfaceSunken,
                    borderRadius: BorderRadius.circular(theme.radiusMd),
                    border: Border.all(color: theme.divider),
                  ),
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.topLeft,
                  child: Text(
                    moment.caption ?? '',
                    style: theme.monoTiny,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (moment.mediaKind == MomentMedia.video)
                Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    size: 22,
                    color: theme.ink.withValues(alpha: 0.85),
                  ),
                ),
              if (moment.tag != null)
                Positioned(
                  left: 4,
                  top: 4,
                  child: MomentTagChip(tag: moment.tag!, dense: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shape every empty and refused state on this screen takes.
class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.accentSoft,
                borderRadius: BorderRadius.circular(theme.radiusLg),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: theme.accent),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.displaySmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
