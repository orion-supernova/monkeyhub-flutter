import 'package:flutter/material.dart';

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
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _selectedDay ??= _dayKeys.isEmpty ? null : _dayKeys.first;
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
          SafeArea(
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
                  Expanded(child: _body(theme, l10n)),
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
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
            // The grid tile is showing the picture, so it flies. Same tag as the
            // feed rail uses; the two are never in the same route, so they can
            // never collide.
            heroTag: m.thumbStorageId == null
                ? null
                : momentMediaHeroTag(m.id),
          ),
        );
      },
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
    // and formatted: the day chip is a compact D/M stamp, and every locale
    // reads two numbers the same way. The full localized date is on the
    // section header below, where there is room for it.
    final dayNum = parts.length == 3 ? parts[2] : dayKey;
    final monthNum = parts.length == 3 ? parts[1] : '';

    return FocusableTap(
      onTap: onTap,
      semanticLabel: dayKey,
      selected: active,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          width: 54,
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
                monthNum,
                style: theme.monoTiny.copyWith(
                  color: active ? theme.accentInk : theme.inkMuted,
                ),
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
    final parts = dayKey.split('-').map(int.tryParse).toList();
    final date = parts.length == 3 && !parts.contains(null)
        ? DateTime(parts[0]!, parts[1]!, parts[2]!)
        : null;
    // MaterialLocalizations rather than intl, which is only a transitive
    // dependency here. NOT uppercased: Dart's toUpperCase is locale-independent
    // and would turn a Turkish 'i' into 'I' instead of 'İ'.
    final label = date == null
        ? dayKey
        : MaterialLocalizations.of(context).formatFullDate(date);

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
