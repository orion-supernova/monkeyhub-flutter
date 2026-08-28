import 'dart:async';

import 'package:flutter/foundation.dart'
    show ValueListenable, setEquals, visibleForTesting;
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

  /// The days the rail currently lights — see [_daysInView].
  final _litDays = <String>{};

  /// The horizontal day rail's own scroller, so the topmost lit chip can be
  /// kept in view as the grid scrolls past it — see [_revealChip].
  final _railScroll = ScrollController();

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
    _railScroll.dispose();
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
        // Sorted, not left in arrival order.
        //
        // `feed:archive` pages by `createdAt` descending, but a row is filed
        // under its `dayKey` — which is the AUTHOR's local day, not an instant
        // (see `Moment.dayKey`). The two disagree the moment a zone does: a
        // friend who flies east, or anyone either side of a DST shift, produces
        // moments whose instants descend while their day keys interleave. The
        // list took arrival order literally, so those days came out shuffled —
        // and a date rail over a list that is not in date order is wrong no
        // matter how exactly it is measured.
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
      // After the frame this setState schedules, not before it: the scroll
      // position has no extent and the sections have no boxes until the list
      // has actually been laid out with these rows in it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _measureScrub();
        _topUp();
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
  /// Every day with any part of its section on screen.
  ///
  /// The rail lights all of them rather than exactly one. On a short archive
  /// the last days can never reach the top edge — there is nothing left below
  /// them to scroll through — so a single highlight either stalls partway down
  /// the list or has to be faked with a screenful of blank or a jump. Four days
  /// visible at once is not a question with one answer, and saying so is more
  /// honest than picking.
  ///
  /// Bounds come from the framework: [_dayOffsets] for each start, the next
  /// day's start for the end, and the scroll extent for the last one.
  Set<String> _daysInView(ScrollPosition pos) {
    final contentEnd = pos.maxScrollExtent + pos.viewportDimension;
    final top = pos.pixels;
    final bottom = top + pos.viewportDimension;
    final out = <String>{};
    for (var i = 0; i < _dayKeys.length; i++) {
      final start = _dayOffsets[_dayKeys[i]];
      if (start == null) continue;
      final end = i + 1 < _dayKeys.length
          ? (_dayOffsets[_dayKeys[i + 1]] ?? contentEnd)
          : contentEnd;
      if (start < bottom && end > top) out.add(_dayKeys[i]);
    }
    return out;
  }

  void _refreshDay(double pixels) {
    if (_scroll.hasClients) {
      final lit = _daysInView(_scroll.position);
      if (!setEquals(lit, _litDays)) {
        setState(() {
          _litDays
            ..clear()
            ..addAll(lit);
        });
      }
    }
    final day = _dayAtOffset(pixels);
    if (day == null || day == _scrubDay.value) return;
    _scrubDay.value = day;
    // The rail scrolls to follow the topmost day on screen, which is the one
    // the pinned header is naming.
    if (day != _selectedDay) {
      setState(() => _selectedDay = day);
      _revealChip(day);
    }
    // A tick per day crossed, so a drag down the rail feels like flicking
    // through a stack rather than sliding a slider. Only while scrubbing: an
    // ordinary fling past forty days would be a burst of buzzing.
    if (_scrubbing) HapticFeedback.selectionClick();
  }

  /// Keeps the active chip on screen as the list moves under it.
  ///
  /// Analytic rather than `ensureVisible`: the chips are a fixed width in a
  /// fixed-pitch row, so where one sits is arithmetic — the same reasoning
  /// `MediaFilmstrip` gives for its own strip. A highlighted chip scrolled off
  /// the end of the rail is a highlight nobody can see.
  void _revealChip(String dayKey) {
    if (!_railScroll.hasClients) return;
    final i = _dayKeys.indexOf(dayKey);
    if (i < 0) return;
    final pos = _railScroll.position;
    final target =
        i * _chipPitch + _chipWidth / 2 - pos.viewportDimension / 2;
    final clamped = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    // Only when it has genuinely gone: nudging the rail on every day boundary
    // would drag it under the reader's thumb while they scroll the grid.
    final chipStart = i * _chipPitch;
    if (chipStart >= pos.pixels &&
        chipStart + _chipWidth <= pos.pixels + pos.viewportDimension) {
      return;
    }
    _railScroll.animateTo(
      clamped,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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

  /// Where each day's section begins, in scroll offset.
  ///
  /// **Reported by the layout system, not predicted.** Every day is wrapped in
  /// a `SliverLayoutBuilder`, and `SliverConstraints.precedingScrollExtent` is
  /// the framework telling that sliver exactly how much scrollable content sits
  /// above it. It is the same number three earlier attempts tried to derive
  /// from tile sizes, spacings, column counts and header metrics — except this
  /// one cannot be wrong, because it is what the viewport actually laid out.
  ///
  /// Scroll-invariant, so reading it from a scroll callback is not a stale
  /// read: a section's position only moves when the CONTENT changes, and when
  /// that happens the sliver is laid out again and writes a new value here.
  final _dayOffsets = <String, double>{};

  /// The dayKey whose section the top of the viewport is inside.
  ///
  /// The last day that has started. With a pinned header this is also, by
  /// construction, the day whose header is currently stuck to the top edge —
  /// so the pill, the chips and the header a reader is looking at cannot
  /// disagree with each other.
  String? _dayAtOffset(double pixels) {
    String? best;
    for (final day in _dayKeys) {
      final start = _dayOffsets[day];
      // Not laid out yet, so not on screen, so not the answer.
      if (start == null) continue;
      if (start <= pixels) {
        best = day;
      } else {
        break;
      }
    }
    return best ?? (_dayKeys.isEmpty ? null : _dayKeys.first);
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
    // Nothing to scroll, or so little that the runway check would fire on the
    // very first touch anyway.
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
    final start = _dayOffsets[dayKey];
    if (start == null || !_scroll.hasClients) return;
    // The framework's own offset for that section, so this lands on the day's
    // header rather than near it. Scroll rather than filter: filtering hides
    // the neighbouring days, and "look around" was the request.
    _scroll.animateTo(
      start.clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

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
                      controller: _railScroll,
                      dayKeys: _dayKeys,
                      counts: {
                        for (final e in _byDay.entries) e.key: e.value.length,
                      },
                      lit: _litDays,
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

    final header = archiveHeaderHeight(context);

    return CustomScrollView(
      key: _listKey,
      controller: _scroll,
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: _listPadTop)),
        for (final day in _dayKeys)
          // One `SliverLayoutBuilder` per day, for the one number that matters:
          // `precedingScrollExtent` is the framework saying exactly where this
          // day begins. Three earlier attempts predicted that from tile sizes
          // and header metrics and were wrong in a different way each time.
          //
          // `SliverMainAxisGroup` is what makes the header STICK to the top for
          // the length of its own day and then hand over — the same behaviour
          // `sectionHeadersPinToVisibleBounds` gives a UICollectionView and a
          // sticky-header decoration gives a RecyclerView. The date on screen
          // is the section header itself, so it cannot drift from the content
          // underneath it: there is nothing in between to be out of step.
          SliverLayoutBuilder(
            builder: (context, constraints) {
              _dayOffsets[day] = constraints.precedingScrollExtent;
              final moments = _byDay[day] ?? const <Moment>[];
              final inner =
                  constraints.crossAxisExtent - _listPadLeft - _listPadRight;
              return SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DayHeader(
                      dayKey: day,
                      count: moments.length,
                      extent: header,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      _listPadLeft,
                      0,
                      _listPadRight,
                      _sectionGap,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: archiveColumns(inner),
                        mainAxisSpacing: _gridSpacing,
                        crossAxisSpacing: _gridSpacing,
                      ),
                      itemCount: moments.length,
                      itemBuilder: (context, i) => _ArchiveTile(
                        // Identity, never index.
                        key: ValueKey(moments[i].id),
                        moment: moments[i],
                        api: widget.api,
                        index: i,
                        onTap: () => showMomentViewer(
                          context,
                          moment: moments[i],
                          api: widget.api,
                          feedApi: widget.feedApi,
                          userId: widget.userId,
                          // The whole day is the run, so a picture opened from
                          // the grid can be swiped through like the gallery it
                          // visually already is.
                          siblings: moments,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: edgeToEdgeBottom(context)),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: _loadingMore
                    ? CircularProgressIndicator(
                        color: theme.accent,
                        strokeWidth: 2,
                      )
                    : Text(
                        l10n.archiveScreenEnd,
                        style: theme.monoTiny.copyWith(color: theme.inkMuted),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One day's header, pinned to the top for the length of its own section.
///
/// The date a reader sees IS this widget — there is no second copy of the
/// answer computed somewhere else that could disagree with it. Opaque, because
/// a pinned header has photographs scrolling underneath it.
class _DayHeader extends SliverPersistentHeaderDelegate {
  const _DayHeader({
    required this.dayKey,
    required this.count,
    required this.extent,
  });

  final String dayKey;
  final int count;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = ThemeScope.of(context);
    return Container(
      color: theme.background,
      padding: const EdgeInsets.fromLTRB(
        _listPadLeft,
        0,
        _listPadRight,
        _headerToGrid,
      ),
      alignment: Alignment.bottomLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              // NOT uppercased: Dart's toUpperCase is locale-independent and
              // would turn a Turkish 'i' into 'I' instead of 'İ'.
              archiveDayLabel(context, dayKey),
              style: theme.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: theme.divider)),
          const SizedBox(width: 8),
          Text('$count', style: theme.monoTiny),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DayHeader old) =>
      old.dayKey != dayKey || old.count != count || old.extent != extent;
}

/// The scrub rail's date pill./// The scrub rail's date pill.
///
/// Keyed because the day it names is also drawn as a section header inside the
/// list, so "find the text" is ambiguous exactly when the two agree — which is
/// the state every test of this is trying to assert.
@visibleForTesting
const Key archiveScrubberPillKey = Key('archive-scrubber-pill');

/// A chip in the day rail, keyed by which day it is and whether it is lit.
///
/// Keyed for the same reason as the pill: on a short archive the scrub rail is
/// hidden — there is nothing to fast-scroll — so the chips are the ONLY thing
/// naming the days you are looking at, and a test of that has to be able to
/// find them. Lit-ness is in the key rather than a separate marker because
/// several chips are lit at once and a shared key would collide.
@visibleForTesting
Key archiveChipKey(String dayKey, {required bool lit}) =>
    ValueKey('archive-chip-${lit ? 'lit' : 'dim'}-$dayKey');

/// The archive's own padding and grid metrics, named because the header, the
/// grid and the scrub rail all have to agree on them.
const double _listPadLeft = 20;
const double _listPadTop = 8;

/// Right is [_DateScrubber._trackWidth] exactly, so the rail sits in the gutter
/// rather than over a tile.
const double _listPadRight = 28;

const double _gridSpacing = 8;
const double _tileTarget = 150;
const double _headerToGrid = 12;
const double _sectionGap = 26;

/// Height of a day's pinned header.
///
/// A `SliverPersistentHeader` has to declare its extent, so this is a layout
/// constant the framework consumes rather than a number anything predicts.
/// Scaled and clamped the way `_DateRail` and `MomentRail` size themselves: a
/// flat number clips the label at accessibility text sizes.
double archiveHeaderHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(30).clamp(30.0, 48.0);

/// Tiles per row at [width].
int archiveColumns(double width) =>
    ((width + _gridSpacing) / (_tileTarget + _gridSpacing))
        .floor()
        .clamp(3, 7);

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
                  child: _Thumb(
                    day: day,
                    loud: loud,
                    theme: theme,
                    // A grab, not a jump: the finger has taken hold of the grip
                    // where it already is, so the drag starts from the thumb's
                    // current position and follows the deltas from there.
                    // Handing a local y straight to the track would teleport
                    // the list on touch-down.
                    grabAt: fraction * travel + _thumbHeight / 2,
                    onStart: onStart,
                    onEnd: onEnd,
                    scrubToY: scrubToY,
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
/// **The date pill is a label, and only the grip takes the gesture.** Making
/// the whole thumb draggable was tempting — the pill is the part that looks
/// like a handle — but the pill is as wide as a date, so its hit box reached
/// most of the way across the screen and swallowed drags meant for the
/// photographs underneath it. A fast-scroller that eats the ordinary scroll is
/// a worse trade than one you have to aim at.
///
/// So the grip gets a proper target instead: [_gripHit] wide, which is a
/// comfortable thumb rather than the 4pt line it draws, and all of it inside
/// the gutter the grid already leaves empty.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.day,
    required this.loud,
    required this.theme,
    required this.grabAt,
    required this.onStart,
    required this.onEnd,
    required this.scrubToY,
  });

  final ValueListenable<String?> day;
  final ValueListenable<bool> loud;
  final dynamic theme;
  final double grabAt;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final void Function(double y) scrubToY;

  /// Hit width of the grip. Apple's minimum target is 44; the line it paints is
  /// 4, and the difference is the whole reason reaching for this used to miss.
  static const _gripHit = 40.0;

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
            // Ignored, deliberately: see the class doc.
            IgnorePointer(
              child: ValueListenableBuilder<String?>(
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
            ),
            _ScrubGestures(
              grabAt: grabAt,
              onStart: onStart,
              onEnd: onEnd,
              scrubToY: scrubToY,
              child: SizedBox(
                width: _gripHit,
                height: _DateScrubber._thumbHeight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    width: isLoud ? 5 : 4,
                    height: _DateScrubber._thumbHeight,
                    decoration: BoxDecoration(
                      // Dimmed rather than hidden at rest: visible enough to
                      // say "there is a rail here", quiet enough not to be a
                      // stripe down the side of every photograph.
                      color: theme.accent.withValues(
                        alpha: isLoud ? 1.0 : 0.45,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The horizontal strip of days.
/// Chip width and the pitch between two of them, named because [_revealChip]
/// has to predict where a chip is without measuring it.
const double _chipWidth = 56;
const double _chipGap = 8;
const double _chipPitch = _chipWidth + _chipGap;

class _DateRail extends StatelessWidget {
  const _DateRail({
    required this.controller,
    required this.dayKeys,
    required this.counts,
    required this.lit,
    required this.onTap,
  });

  final ScrollController controller;
  final List<String> dayKeys;
  final Map<String, int> counts;
  /// Every day with part of its section on screen — see [_daysInView].
  final Set<String> lit;
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
        controller: controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        // Vertical room for FocusableTap's ring, which paints outside its
        // child's bounds and is otherwise clipped by this scroll view.
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        itemCount: dayKeys.length,
        itemBuilder: (context, i) => Padding(
          key: ValueKey(dayKeys[i]),
          padding: const EdgeInsets.only(right: _chipGap),
          child: _DayChip(
            key: archiveChipKey(dayKeys[i], lit: lit.contains(dayKeys[i])),
            dayKey: dayKeys[i],
            count: counts[dayKeys[i]] ?? 0,
            active: lit.contains(dayKeys[i]),
            onTap: () => onTap(dayKeys[i]),
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    super.key,
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
          width: _chipWidth,
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
