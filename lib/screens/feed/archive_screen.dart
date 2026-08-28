import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
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

  /// The list's own viewport, so the day label can be measured against the top
  /// of the SCROLLER rather than the top of the screen — see [_dayAtTop].
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
    _queueDayRefresh();
  }

  /// True while a day refresh is already scheduled for after this frame.
  bool _dayRefreshQueued = false;

  /// Recomputes the label AFTER the frame, never during the scroll callback.
  ///
  /// **This is the whole accuracy bug.** `ScrollController` notifies its
  /// listeners from inside `setPixels`, which is before the viewport has laid
  /// out at the new offset — so every section box [_dayAtTop] measures is still
  /// where it was one frame ago. Reading it there does not give a slightly
  /// stale answer, it gives the PREVIOUS position's answer, and on a flick or a
  /// scrub that is a whole screen out of date. Coalesced with a flag, because a
  /// fling delivers dozens of notifications per frame and each one would
  /// otherwise queue its own callback.
  void _queueDayRefresh() {
    if (_dayRefreshQueued) return;
    _dayRefreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dayRefreshQueued = false;
      if (!mounted) return;
      final day = _dayAtTop();
      if (day == null || day == _scrubDay.value) return;
      _scrubDay.value = day;
      // A tick per day crossed, so a drag down the rail feels like flicking
      // through a stack rather than sliding a slider. Only while scrubbing:
      // an ordinary fling past forty days would be a burst of buzzing.
      if (_scrubbing) HapticFeedback.selectionClick();
    });
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

  /// The dayKey of the section the viewport's top edge is currently inside.
  ///
  /// Walks the laid-out section boxes, which is exact and costs one
  /// `localToGlobal` per day on screen — the list holds a page of forty
  /// moments, so that is a handful of days, not hundreds.
  ///
  /// Measured against [_listKey], the SCROLLER's own box, not against this
  /// State's context. That context is the whole screen, and the list starts
  /// well below it — under the title row and the date rail — so comparing
  /// section positions to it put the origin ~150pt too high: every section read
  /// as "still below the fold", nothing ever matched, and the label sat on the
  /// fallback (the first day of the archive) almost all the time. It looked
  /// like the date was simply wrong, which it was.
  String? _dayAtTop() {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.hasSize) return null;
    final top = listBox.localToGlobal(Offset.zero).dy;
    String? best;
    for (final day in _dayKeys) {
      final ctx = _sectionKeys[day]?.currentContext;
      final box = ctx?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      // The last section that has already started by the time we reach the
      // top edge — i.e. the one the reader is actually looking at.
      if (y - top <= 24) {
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
  /// Mapped through `maxScrollExtent`, which for a list of unequal sections is
  /// approximate — but the label above the thumb is read from the sections
  /// themselves, so what it says is always true even where the thumb is only
  /// roughly right. That is the trade every fast-scroller makes, and it is the
  /// right way round: being told the wrong date would be worse than landing a
  /// screen early.
  void _scrubTo(double fraction) {
    if (!_scroll.hasClients) return;
    final extent = _scroll.position.maxScrollExtent;
    if (extent <= 0) return;
    // The jump notifies the controller, which lands in [_measureScrub] and
    // schedules the label for after the frame — see [_queueDayRefresh].
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
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
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
      padding: EdgeInsets.fromLTRB(20, 8, 28, edgeToEdgeBottom(context)),
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

          return SizedBox(
            width: _trackWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (d) {
                onStart();
                scrubToY(d.localPosition.dy);
              },
              onVerticalDragUpdate: (d) => scrubToY(d.localPosition.dy),
              onVerticalDragEnd: (_) => onEnd(),
              onVerticalDragCancel: onEnd,
              // A tap anywhere on the rail jumps there too, which is the whole
              // point of a rail you can see the length of.
              onTapDown: (d) {
                onStart();
                scrubToY(d.localPosition.dy);
              },
              onTapUp: (_) => onEnd(),
              onTapCancel: onEnd,
              child: ValueListenableBuilder<double>(
                valueListenable: at,
                builder: (context, fraction, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: fraction * travel,
                      right: 6,
                      child: _Thumb(day: day, loud: loud, theme: theme),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
