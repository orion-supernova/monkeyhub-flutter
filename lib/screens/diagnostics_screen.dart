import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback;

import '../data/settings_store.dart';
import '../diagnostics/device_report.dart';
import '../diagnostics/diag_buffer.dart';
import '../diagnostics/diag_event.dart';
import '../diagnostics/diag_export.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/destructive_sheet.dart';
import '../widgets/ios_kit.dart';
import '../widgets/search_field.dart';
import '../widgets/sheet_kit.dart';
import 'diagnostics/diag_collapse.dart';
import 'diagnostics/diag_event_row.dart';
import 'diagnostics/diag_filter_sheet.dart';
import 'diagnostics/diag_palette.dart';
import '../widgets/filter_capsule.dart';
import '../widgets/desktop_scroll.dart';

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

enum _More { share, copy, delete }

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  // Created here and disposed below. The reference implementation builds one
  // inside `build` and never disposes it, leaking a controller per rebuild.
  final ScrollController _scroll = ScrollController();
  late final TextEditingController _search = TextEditingController(
    text: _filter.query,
  );

  /// The ⋯ button, for anchoring the share popover on iPad and macOS — the
  /// action sheet it opens is gone by the time the share sheet needs a rect.
  final GlobalKey _moreKey = GlobalKey();

  /// What **All** leaves out until somebody says otherwise: the two categories
  /// that bury everything else. In a real session `subscription` was 66% of
  /// the events and `frame` another 9%.
  static const defaultHidden = {DiagCat.subscription, DiagCat.frame};

  late DiagFilter _filter = DiagFilter(hidden: _savedHidden());
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
    _search.dispose();
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
        // Same reason as the problem-report path: whoever is sharing a log
        // after a crash is sharing the session that replaced it.
        previous: await DiagBuffer.instance.readFile(previous: true),
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
    showAppToast(
      context,
      AppLocalizations.of(context).diagSummaryCopied,
      tone: ToastTone.success,
    );
  }

  /// The ⋯ menu: the three things you do with a log once you have found what
  /// you were looking for. Destructive last and in red, the iOS order.
  Future<void> _openMore() async {
    // Read now: the anchor is the button, and it has to be measured while the
    // page is the thing on screen.
    final box = _moreKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final l10n = AppLocalizations.of(context);
    final pick = await showIosActionSheet<_More>(
      context,
      actions: [
        IosSheetAction(
          label: l10n.diagShareLog,
          value: _More.share,
          icon: CupertinoIcons.square_arrow_up,
        ),
        IosSheetAction(
          label: l10n.diagCopySummary,
          value: _More.copy,
          icon: CupertinoIcons.doc_on_doc,
        ),
        IosSheetAction(
          label: l10n.diagDeleteAll,
          value: _More.delete,
          icon: CupertinoIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (pick) {
      case _More.share:
        await _shareLog(origin: origin);
      case _More.copy:
        await _copySummary();
      case _More.delete:
        await _deleteAll();
      case null:
        break;
    }
  }

  Future<void> _openFilter() async {
    final next = await DiagFilterSheet.show(context, _filter);
    if (next == null || !mounted) return;
    final hiddenChanged = !setEquals(next.hidden, _filter.hidden);
    setState(() => _filter = next);
    // The sheet has a search of its own; keep the page's field telling the
    // truth about what the list is filtered by.
    if (_search.text != next.query) _search.text = next.query;
    if (hiddenChanged) _saveHidden(next.hidden);
  }

  /// The saved choice, by name — a category that no longer exists is dropped
  /// rather than failing the whole set — or [defaultHidden] if there is none.
  static Set<DiagCat> _savedHidden() {
    final names = SettingsStore.instance.diagHiddenCategories;
    if (names == null) return defaultHidden;
    return {
      for (final c in DiagCat.values)
        if (names.contains(c.name)) c,
    };
  }

  void _saveHidden(Set<DiagCat> hidden) {
    unawaited(
      SettingsStore.instance.setDiagHiddenCategories({
        for (final c in hidden) c.name,
      }),
    );
  }

  void _setHidden(Set<DiagCat> hidden) {
    setState(() => _filter = _filter.copyWith(hidden: hidden));
    _saveHidden(hidden);
  }

  /// Long press on a chip: take it out of **All**, or put it back. Undoable
  /// from the toast, since a long press is easy to make by accident.
  void _toggleHidden(DiagCat c) {
    HapticFeedback.selectionClick();
    final before = _filter.hidden;
    final hiding = !before.contains(c);
    _setHidden(hiding ? {...before, c} : ({...before}..remove(c)));
    final l10n = AppLocalizations.of(context);
    final name = diagCategoryLabel(l10n, c);
    showAppToast(
      context,
      hiding ? l10n.diagHiddenFromAll(name) : l10n.diagBackInAll(name),
      actionLabel: l10n.diagUndo,
      onAction: () {
        if (mounted) _setHidden(before);
      },
    );
  }

  Future<void> _deleteAll() async {
    final l10n = AppLocalizations.of(context);
    final go = await showConfirmSheet(
      context,
      headline: l10n.diagDeleteLogTitle,
      body: l10n.diagDeleteLogBody,
      confirmLabel: l10n.diagDelete,
    );
    if (!go || !mounted) return;
    await DiagBuffer.instance.wipe();
    if (!mounted) return;
    setState(() => _follow = true);
    showAppToast(context, l10n.diagLogDeleted, tone: ToastTone.success);
  }

  /// Anything the sheet narrows by that the page itself does not show — the
  /// severity floor and the collapse switch. Lights the Filter button, so a
  /// list that looks short for no visible reason has a visible reason.
  bool get _sheetFiltering =>
      _filter.minSev != DiagSev.trace || !_filter.collapse;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final events = _events;
    final groups = collapseEvents(events, enabled: _filter.collapse);
    final buf = DiagBuffer.instance;
    final dropped = buf.dropped;

    final page = IosPage(
      title: l10n.settingsHubDiagnostics,
      // Which binary this is, under the counts. The question it answers ("am
      // I even looking at the build I just shipped?") comes up before any
      // question the timeline below can answer, and every other signal a
      // tester has — window chrome, Dock icon, app name — reads the same for
      // an iOS build on an Apple silicon Mac as for the real macOS one.
      subtitle: '${l10n.diagEventCount(events.length, buf.length)}'
          '${_follow ? '' : ' · ${l10n.diagPaused}'}'
          '${_busy ? ' · ${l10n.diagPreparingLog}' : ''}'
          '${_build == null ? '' : '\n$_build'}',
      // Deliberately a flat colour rather than `theme.backgroundLayer` — the
      // themed backdrops include shader and gradient layers, and several of
      // them are themselves suspects for the strobe this screen exists to
      // diagnose. The screen you debug a flicker with must not be able to
      // flicker.
      flatBackground: true,
      controller: _scroll,
      actions: [
        GlassIconButton(
          icon: CupertinoIcons.line_horizontal_3_decrease,
          semanticLabel: l10n.diagFilter,
          tint: _sheetFiltering ? theme.accent : null,
          onTap: _openFilter,
        ),
        GlassIconButton(
          key: _moreKey,
          icon: CupertinoIcons.ellipsis,
          semanticLabel: l10n.diagMore,
          // Share is the slow one; a second tap mid-export would race it.
          onTap: _busy ? null : _openMore,
        ),
      ],
      slivers: [
        // A non-zero dropped count means the log starts mid-story, which
        // changes how you read everything below it — so it is its own line,
        // in red, rather than a clause in the subtitle.
        if (dropped > 0)
          _Readable(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Text(
                l10n.diagDropped(dropped),
                style: groupedMetaStyle(theme).copyWith(color: theme.danger),
              ),
            ),
          ),
        // Search and the category row stay pinned under the bar: a live log
        // is read from its bottom, and a filter you have to scroll three
        // thousand rows up to reach is not one anybody uses.
        PinnedHeaderSliver(
          child: ColoredBox(
            color: theme.background,
            child: _Toolbar(
              search: SearchField(
                controller: _search,
                hintText: l10n.diagSearchHint,
                onChanged: (q) =>
                    setState(() => _filter = _filter.copyWith(query: q)),
              ),
              // Quick focus row: tap a category to show only it, tap again to
              // clear, tap several to combine; long-press to hide it from All.
              // Each chip carries its live count.
              //
              // Not a duplicate of the filter sheet — it exists because of
              // what a real capture actually looks like. In the first session
              // off this build, `subscription` was 247 of 352 events, so the
              // useful move is almost always "show me just layout and
              // connection", and burying that behind a modal was the wrong
              // call. Only measuring it showed that.
              cats: _QuickCats(
                counts: _countsByCat(buf.snapshot()),
                selected: _filter.cats,
                hidden: _filter.hidden,
                onToggle: (c) => setState(() {
                  final next = {..._filter.cats};
                  next.contains(c) ? next.remove(c) : next.add(c);
                  _filter = _filter.copyWith(cats: next);
                }),
                onHide: _toggleHidden,
                onAll: () =>
                    setState(() => _filter = _filter.copyWith(cats: const {})),
              ),
            ),
          ),
        ),
        if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Empty(
              captured: buf.length,
              // Only hiding stands between the log and the screen — no pick,
              // no search, no severity floor.
              onlyHidden: _filter.cats.isEmpty &&
                  _filter.query.isEmpty &&
                  _filter.minSev == DiagSev.trace,
            ),
          )
        else
          // Built lazily, row by row: a flooded session is thousands of
          // events, and only the dozen on screen are ever laid out.
          _Readable(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              // Room for the Latest pill over the last row, plus the home
              // indicator — the page leaves the bottom inset to its slivers.
              72 + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverList.builder(
              itemCount: groups.length,
              itemBuilder: (context, i) => DiagEventRow(
                group: groups[i],
                previous: i == 0 ? null : groups[i - 1].last,
              ),
            ),
          ),
      ],
    );

    return Stack(
      children: [
        page,
        // Only while paused. Scrolling up in a live log parks the follow, and
        // without this the way back is a long flick through however many
        // events arrived meanwhile. A floating pill rather than a bar button —
        // it belongs next to the content it moves, and only exists while it
        // is useful.
        if (!_follow && groups.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GlassPillButton(
                  label: l10n.diagLatest,
                  icon: CupertinoIcons.arrow_down,
                  semanticLabel: l10n.diagJumpToLatest,
                  height: 40,
                  onTap: _resumeFollow,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A sliver kept to a readable column on a wide window, with [padding] inside
/// it. On a phone it is just the padding.
///
/// Measured from the sliver's own cross extent rather than the window, so it
/// is right in a desktop detail pane too.
class _Readable extends StatelessWidget {
  const _Readable({required this.sliver, required this.padding});
  final Widget sliver;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
        builder: (context, c) {
          final side = _readableInset(c.crossAxisExtent);
          return SliverPadding(
            padding: padding + EdgeInsets.symmetric(horizontal: side),
            sliver: sliver,
          );
        },
      );
}

double _readableInset(double width) =>
    math.max(0, (width - ContentWidth.readable) / 2);

/// The pinned block under the bar: search, then the category row.
///
/// The row runs full-bleed and carries the gutter as scroll padding, so chips
/// slide off the screen edge rather than vanishing at an invisible wall 16pt
/// in — the chat list's filter row does the same.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.search, required this.cats});
  final Widget search;
  final Widget cats;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final side = _readableInset(c.maxWidth);
          return Padding(
            padding: EdgeInsets.fromLTRB(side, 4, side, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: search,
                ),
                const SizedBox(height: 10),
                cats,
              ],
            ),
          );
        },
      );
}

/// Shown when the list has nothing in it, and it distinguishes the reasons.
///
/// "Nothing captured yet" and "your filter excluded everything" are completely
/// different situations — one means the feature is broken, the other means you
/// tapped a chip. A single generic empty state would leave you unable to tell.
/// The third, [onlyHidden], is the one a fresh session hits: so far there are
/// only events in the categories All leaves out, and "tap All" would be no
/// help — All is already on.
class _Empty extends StatelessWidget {
  const _Empty({required this.captured, required this.onlyHidden});
  final int captured;
  final bool onlyHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nothingAtAll = captured == 0;
    final String title;
    final String hint;
    if (nothingAtAll) {
      title = l10n.diagEmptyNothingTitle;
      hint = l10n.diagEmptyNothingHint;
    } else if (onlyHidden) {
      title = l10n.diagEmptyHiddenTitle;
      hint = l10n.diagEmptyHiddenHint;
    } else {
      title = l10n.diagEmptyNoMatchTitle;
      hint = l10n.diagEmptyNoMatchHint;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 64),
        child: EmptyState(
          icon: nothingAtAll
              ? CupertinoIcons.hourglass
              : onlyHidden
              ? CupertinoIcons.eye_slash
              : CupertinoIcons.line_horizontal_3_decrease,
          title: title,
          message: hint,
          compact: true,
        ),
      ),
    );
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
///
/// Hidden categories sit at the END, dimmed, still counting — so what All is
/// holding back, and how much of it, stays in view. All's own count is what
/// it actually shows.
class _QuickCats extends StatelessWidget {
  const _QuickCats({
    required this.counts,
    required this.selected,
    required this.hidden,
    required this.onToggle,
    required this.onHide,
    required this.onAll,
  });

  final Map<DiagCat, int> counts;
  final Set<DiagCat> selected;
  final Set<DiagCat> hidden;
  final ValueChanged<DiagCat> onToggle;
  final ValueChanged<DiagCat> onHide;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final present = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        final byHidden = (hidden.contains(a.key) ? 1 : 0)
            .compareTo(hidden.contains(b.key) ? 1 : 0);
        return byHidden != 0 ? byHidden : b.value.compareTo(a.value);
      });
    if (present.isEmpty) return const SizedBox.shrink();

    final total = present
        .where((e) => !hidden.contains(e.key))
        .fold<int>(0, (a, e) => a + e.value);

    // The chat list's filter row sizes its chips the same way: scaled with the
    // text so a large type setting never clips a label, capped so it never
    // eats the log.
    final height =
        MediaQuery.textScalerOf(context).scale(32).clamp(32.0, 56.0);
    return SizedBox(
      height: height,
      child: HorizontalWheelScroll(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CatChip(
                label: l10n.diagAll,
                count: total,
                on: selected.isEmpty,
                onTap: onAll,
              ),
              // A rule, so All reads as the reset it is rather than as one more
              // category sitting alongside the others.
              Container(
                width: 0.5,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: theme.divider,
              ),
              for (final e in present) ...[
                _CatChip(
                  label: diagCategoryLabel(l10n, e.key),
                  count: e.value,
                  colour: DiagPalette.cat(e.key),
                  on: selected.contains(e.key),
                  hidden: hidden.contains(e.key),
                  onTap: () => onToggle(e.key),
                  onLongPress: () => onHide(e.key),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One capsule of the category row — the chat list's filter chip (soft
/// neutral at rest, solid accent when chosen, 15pt body label, 13pt count),
/// plus the two things only this row needs: the category's hue as a dot, and
/// a dimmed, crossed-eye state for a category hidden from All.
class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
    this.colour,
    this.hidden = false,
    this.onLongPress,
  });

  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;

  /// The category's hue. Null on All, which is no category.
  final Color? colour;

  /// Left out of All. Dimmed until picked; the eye stays either way, since a
  /// picked hidden category is still hidden the moment All is back.
  final bool hidden;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final c = colour;
    return FilterCapsule(
      label: label,
      active: on,
      onTap: onTap,
      onLongPress: onLongPress,
      count: count,
      showZeroCount: true,
      faded: hidden,
      semanticLabel: hidden
          ? AppLocalizations.of(context).diagChipHiddenSemanticLabel(label, count)
          : AppLocalizations.of(context).diagChipSemanticLabel(label, count),
      // The dot is what makes the row scannable, and it is the same hue the
      // timeline uses for that category — so a chip and the rows it selects
      // are visibly the same thing. A hidden category keeps the hue on a
      // crossed-out eye instead.
      leading: c == null
          ? null
          : hidden
              ? Icon(CupertinoIcons.eye_slash_fill, size: 13, color: c)
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    // On the accent fill a hue can sit too close to it to
                    // read; a hairline of the chip's ink keeps it a dot.
                    border: on
                        ? Border.all(color: theme.accentInk, width: 1)
                        : null,
                  ),
                ),
    );
  }
}
