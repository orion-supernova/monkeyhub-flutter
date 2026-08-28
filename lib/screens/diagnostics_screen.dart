import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../diagnostics/device_report.dart';
import '../diagnostics/diag_buffer.dart';
import '../diagnostics/diag_event.dart';
import '../diagnostics/diag_export.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_toast.dart';
import 'diagnostics/diag_collapse.dart';
import 'diagnostics/diag_event_row.dart';
import 'diagnostics/diag_filter_sheet.dart';
import 'diagnostics/diag_palette.dart';

/// The captured timeline.
///
/// English-only, and deliberately. It is reachable only from an unlabelled
/// gesture on a version string, so nothing here is on a path an ordinary user
/// walks — and thirty strings across twelve ARB files, for a screen whose whole
/// audience is somebody being talked through it on a phone call, would be cost
/// with no reader.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  // Created here and disposed below. The reference implementation builds one
  // inside `build` and never disposes it, leaking a controller per rebuild.
  final ScrollController _scroll = ScrollController();

  DiagFilter _filter = const DiagFilter();
  bool _follow = true;
  bool _busy = false;

  /// Rebuild ticker. The viewer listens to a REVISION COUNTER, never to the
  /// event list: during the burst this screen exists to capture, events arrive
  /// faster than a phone can lay out three thousand rows, and rebuilding per
  /// event would make the diagnostics screen its own performance bug.
  Timer? _tick;
  int _seenRevision = -1;

  /// `1.3.81 (1) · macos · macos-testflight` — see [DeviceReport.describeBuild].
  /// Null until the first gather resolves; the header simply omits the line
  /// until then rather than reserving space for it and jumping.
  String? _build;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // `gather()` is cached per launch, so this is a map lookup on every visit
    // after the first.
    DeviceReport.gather().then((d) {
      if (mounted) setState(() => _build = DeviceReport.describeBuild(d));
    });
    // 4 Hz is fast enough to read as live and slow enough to be free.
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final rev = DiagBuffer.instance.revision.value;
      if (rev != _seenRevision && mounted) {
        setState(() => _seenRevision = rev);
        if (_follow) _jumpToEnd();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Scrolling up means the user is reading something; following would yank it
    // away under them. Re-engage only when they return to the bottom.
    final atBottom = _scroll.offset >= _scroll.position.maxScrollExtent - 40;
    if (atBottom != _follow && mounted) setState(() => _follow = atBottom);
  }

  void _resumeFollow() {
    setState(() => _follow = true);
    _jumpToEnd();
  }

  void _jumpToEnd() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  List<DiagEvent> get _events =>
      DiagBuffer.instance.snapshot().where(_filter.matches).toList();

  /// Counts over the UNFILTERED buffer, so a chip's number does not change as
  /// you filter by it — otherwise selecting one category zeroes every other
  /// chip and the row stops being navigable.
  static Map<DiagCat, int> _countsByCat(List<DiagEvent> all) {
    final out = <DiagCat, int>{};
    for (final e in all) {
      out[e.cat] = (out[e.cat] ?? 0) + 1;
    }
    return out;
  }

  Future<void> _shareLog({Rect? origin}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await DiagBuffer.instance.flush();
      final events = DiagBuffer.instance.snapshot();
      final text = await DiagExport.build(
        events: events,
        dropped: DiagBuffer.instance.dropped,
      );
      await DiagExport.share(text: text, label: 'log', origin: origin);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copySummary() async {
    final text = await DiagExport.summary(
      events: DiagBuffer.instance.snapshot(),
      dropped: DiagBuffer.instance.dropped,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppToast(context, 'Summary copied', tone: ToastTone.success);
  }

  Future<void> _openFilter() async {
    final next = await DiagFilterSheet.show(context, _filter);
    if (next != null && mounted) setState(() => _filter = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final events = _events;
    final groups = collapseEvents(events, enabled: _filter.collapse);
    final buf = DiagBuffer.instance;

    return Scaffold(
      backgroundColor: theme.surface,
      // Deliberately a flat surface rather than `theme.backgroundLayer` — the
      // themed backdrops include shader and gradient layers, and several of
      // them are themselves suspects for the strobe this screen exists to
      // diagnose. The screen you debug a flicker with must not be able to
      // flicker.
      body: SafeArea(
        child: AdaptivePageBody(
          child: Column(
            children: [
              _Header(
                buildLine: _build,
                total: buf.length,
                shown: events.length,
                dropped: buf.dropped,
                following: _follow,
                busy: _busy,
                onFilter: _openFilter,
                onShare: _shareLog,
                onCopy: _copySummary,
                onClose: () => Navigator.of(context).pop(),
              ),
              _SearchBar(
                query: _filter.query,
                onChanged: (q) =>
                    setState(() => _filter = _filter.copyWith(query: q)),
              ),
              // Quick focus row: tap a category to show only it, tap again to
              // clear, tap several to combine. Each chip carries its live count.
              //
              // Not a duplicate of the filter sheet — it exists because of what
              // a real capture actually looks like. In the first session off
              // this build, `subscription` was 247 of 352 events, so the useful
              // move is almost always "show me just layout and connection", and
              // burying that behind a modal was the wrong call. Only measuring
              // it showed that.
              _QuickCats(
                counts: _countsByCat(buf.snapshot()),
                selected: _filter.cats,
                onToggle: (c) => setState(() {
                  final next = {..._filter.cats};
                  next.contains(c) ? next.remove(c) : next.add(c);
                  _filter = _filter.copyWith(cats: next);
                }),
                onAll: () =>
                    setState(() => _filter = _filter.copyWith(cats: const {})),
              ),
              Expanded(
                child: groups.isEmpty
                    ? _Empty(captured: buf.length)
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                            itemCount: groups.length,
                            itemBuilder: (context, i) => DiagEventRow(
                              group: groups[i],
                              previous: i == 0 ? null : groups[i - 1].last,
                            ),
                          ),
                          // Only while paused. Scrolling up in a live log
                          // parks the follow, and without this the way back
                          // is a long flick through however many events
                          // arrived meanwhile.
                          if (!_follow)
                            Positioned(
                              right: 12,
                              bottom: 12,
                              child: _JumpToEnd(onTap: _resumeFollow),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the list has nothing in it, and it distinguishes the two reasons.
///
/// "Nothing captured yet" and "your filter excluded everything" are completely
/// different situations — one means the feature is broken, the other means you
/// tapped a chip. A single generic empty state would leave you unable to tell.
class _Empty extends StatelessWidget {
  const _Empty({required this.captured});
  final int captured;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final nothingAtAll = captured == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              nothingAtAll ? Icons.hourglass_empty : Icons.filter_alt_off,
              size: 30,
              color: theme.inkMuted,
            ),
            const SizedBox(height: 12),
            Text(
              nothingAtAll ? 'Nothing captured yet' : 'No events match',
              style: theme.bodyEmph,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              nothingAtAll
                  ? 'Use the app for a moment and events will appear here.'
                  : 'Tap All above to clear the filter.',
              style: theme.bodySoft,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Back to live. Deliberately a floating pill rather than a header button — it
/// belongs next to the content it moves, and only exists while it is useful.
class _JumpToEnd extends StatelessWidget {
  const _JumpToEnd({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.capsule,
      semanticLabel: 'Jump to latest',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward, size: 14, color: theme.accentInk),
              const SizedBox(width: 6),
              Text(
                'Latest',
                style: theme.monoTiny.copyWith(color: theme.accentInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Always-visible search, collapsed to a hint until tapped.
///
/// Search lived only inside the filter sheet at first, which meant finding one
/// function name cost two taps and a modal. On a screen whose whole job is
/// finding a needle, that was the wrong place for it.
class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _c = TextEditingController(
    text: widget.query,
  );
  bool _open = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (!_open && _c.text.isEmpty) {
      return FocusableTap(
        onTap: () => setState(() => _open = true),
        radius: theme.radiusSm,
        semanticLabel: 'Search',
        child: GestureDetector(
          onTap: () => setState(() => _open = true),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: theme.surface,
            child: Row(
              children: [
                Icon(Icons.search, size: 15, color: theme.inkMuted),
                const SizedBox(width: 8),
                Text(
                  'Search…',
                  style: theme.monoTiny.copyWith(color: theme.inkMuted),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      color: theme.surface,
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: Row(
        children: [
          Icon(Icons.search, size: 15, color: theme.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _c,
              autofocus: true,
              style: theme.monoTiny,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: widget.onChanged,
            ),
          ),
          FocusableTap(
            onTap: _clear,
            shape: FocusRingShape.circle,
            semanticLabel: 'Clear search',
            child: GestureDetector(
              onTap: _clear,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 15, color: theme.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clear() {
    _c.clear();
    widget.onChanged('');
    setState(() => _open = false);
  }
}

/// The category row: an explicit **All**, then one chip per category that has
/// events, each carrying its colour and live count.
///
/// "All" is not decoration. The filter treats an empty selection as
/// "everything", which is the right internal model and reads as a bug on
/// screen — every chip renders unselected, so the default state looks like
/// nothing is on and the list looks unfiltered by accident. An explicit chip
/// that lights up when the set is empty says what is actually happening, and
/// gives a one-tap way back from any filter.
///
/// Categories with nothing in them are omitted rather than shown at zero:
/// eleven chips of which three are meaningful is a worse control than three.
class _QuickCats extends StatelessWidget {
  const _QuickCats({
    required this.counts,
    required this.selected,
    required this.onToggle,
    required this.onAll,
  });

  final Map<DiagCat, int> counts;
  final Set<DiagCat> selected;
  final ValueChanged<DiagCat> onToggle;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final present = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (present.isEmpty) return const SizedBox.shrink();

    final total = present.fold<int>(0, (a, e) => a + e.value);

    return Container(
      color: theme.surface,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CatChip(
              label: 'All',
              count: total,
              colour: theme.accent,
              on: selected.isEmpty,
              onTap: onAll,
            ),
            // A rule, so All reads as the reset it is rather than as one more
            // category sitting alongside the others.
            Container(
              width: 1,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: theme.divider,
            ),
            for (final e in present) ...[
              _CatChip(
                label: e.key.name,
                count: e.value,
                colour: DiagPalette.cat(e.key),
                on: selected.contains(e.key),
                onTap: () => onToggle(e.key),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.count,
    required this.colour,
    required this.on,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color colour;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.capsule,
      semanticLabel: '$label $count',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          decoration: BoxDecoration(
            color: on ? colour.withValues(alpha: 0.16) : theme.surfaceRaised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on ? colour : theme.divider,
              width: on ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The dot is what makes the row scannable, and it is the same hue
              // the timeline uses for that category — so a chip and the rows it
              // selects are visibly the same thing.
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.monoTiny.copyWith(
                  color: on ? theme.ink : theme.inkSoft,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: theme.monoTiny.copyWith(color: theme.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.buildLine,
    required this.total,
    required this.shown,
    required this.dropped,
    required this.following,
    required this.busy,
    required this.onFilter,
    required this.onShare,
    required this.onCopy,
    required this.onClose,
  });

  /// Which binary this is. Null while it is still being gathered.
  final String? buildLine;
  final int total;
  final int shown;
  final int dropped;
  final bool following;
  final bool busy;
  final VoidCallback onFilter;
  final void Function({Rect? origin}) onShare;
  final VoidCallback onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('DIAGNOSTICS', style: theme.label),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$shown/$total'
                  '${dropped > 0 ? ' · $dropped dropped' : ''}'
                  '${following ? '' : ' · paused'}',
                  style: theme.monoTiny.copyWith(
                    // A non-zero dropped count means the log starts mid-story,
                    // which changes how you read everything above it.
                    color: dropped > 0 ? theme.danger : theme.inkMuted,
                  ),
                ),
              ),
              _Action(
                icon: Icons.filter_list,
                label: 'Filter',
                onTap: onFilter,
              ),
              _Action(
                icon: Icons.copy_all_outlined,
                label: 'Copy summary',
                onTap: onCopy,
              ),
              _ShareAction(busy: busy, onShare: onShare),
              _Action(icon: Icons.close, label: 'Close', onTap: onClose),
            ],
          ),
          // Which binary this is, under the counts. The question it answers
          // ("am I even looking at the build I just shipped?") comes up before
          // any question the timeline below can answer, and every other signal
          // a tester has — window chrome, Dock icon, app name — reads the same
          // for an iOS build on an Apple silicon Mac as for the real macOS one.
          if (buildLine != null) ...[
            const SizedBox(height: 4),
            Text(
              buildLine!,
              style: theme.monoTiny.copyWith(color: theme.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // BOTH wrappers, per FocusableTap's doc comment: it binds Enter/Space and
    // the semantics but registers no gesture recognizer, so the bare detector
    // is what makes this answer a touch at all.
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.circle,
      semanticLabel: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: 18, color: theme.inkSoft),
        ),
      ),
    );
  }
}

/// Share needs the button's global rect for iPad/macOS popover anchoring, so it
/// cannot use the plain [_Action] shape.
class _ShareAction extends StatelessWidget {
  const _ShareAction({required this.busy, required this.onShare});
  final bool busy;
  final void Function({Rect? origin}) onShare;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Builder(
      builder: (context) {
        void go() {
          final box = context.findRenderObject() as RenderBox?;
          final origin = box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size;
          onShare(origin: origin);
        }

        return FocusableTap(
          onTap: busy ? null : go,
          shape: FocusRingShape.circle,
          semanticLabel: 'Share log',
          child: GestureDetector(
            onTap: busy ? null : go,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.accent,
                      ),
                    )
                  : Icon(Icons.ios_share, size: 18, color: theme.accent),
            ),
          ),
        );
      },
    );
  }
}
