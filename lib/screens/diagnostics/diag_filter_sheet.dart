import 'package:flutter/material.dart';

import '../../diagnostics/diag_event.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/search_field.dart';
import '../../widgets/sheet_kit.dart';

/// What the viewer is currently showing.
///
/// Held in memory only. The reference implementation persists its filter — and
/// persists it by enum INDEX, so reordering the enum silently rewrites every
/// saved filter into a different one. Not worth inheriting for a screen you
/// open twice.
class DiagFilter {
  const DiagFilter({
    this.cats = const {},
    this.hidden = const {},
    this.minSev = DiagSev.trace,
    this.query = '',
    this.collapse = true,
  });

  /// The categories picked to look at. Empty means **All** rather than
  /// "nothing" — the common case is no pick at all, and it should not require
  /// selecting all eleven categories.
  final Set<DiagCat> cats;

  /// Left out of **All**, and only of All. A category too loud to read around
  /// — `subscription` was two thirds of a real session — is hidden until it is
  /// picked, and picking it shows exactly it: asking for `frame` by name is
  /// never answered with nothing. That is what lets one set of chips both keep
  /// the noise out by default and go straight to it on a tap.
  final Set<DiagCat> hidden;
  final DiagSev minSev;
  final String query;
  final bool collapse;

  bool matches(DiagEvent e) {
    if (cats.isNotEmpty) {
      if (!cats.contains(e.cat)) return false;
    } else if (hidden.contains(e.cat)) {
      return false;
    }
    if (e.sev.index < minSev.index) return false;
    if (query.isEmpty) return true;
    return e.searchHaystack.contains(query.toLowerCase());
  }

  DiagFilter copyWith({
    Set<DiagCat>? cats,
    Set<DiagCat>? hidden,
    DiagSev? minSev,
    String? query,
    bool? collapse,
  }) => DiagFilter(
    cats: cats ?? this.cats,
    hidden: hidden ?? this.hidden,
    minSev: minSev ?? this.minSev,
    query: query ?? this.query,
    collapse: collapse ?? this.collapse,
  );
}

class DiagFilterSheet extends StatefulWidget {
  const DiagFilterSheet({super.key, required this.initial});

  final DiagFilter initial;

  static Future<DiagFilter?> show(BuildContext context, DiagFilter initial) {
    return showAdaptiveSheet<DiagFilter>(
      context,
      // Tall enough to reach the status bar on a phone.
      useSafeArea: true,
      builder: (_) => DiagFilterSheet(initial: initial),
    );
  }

  @override
  State<DiagFilterSheet> createState() => _DiagFilterSheetState();
}

class _DiagFilterSheetState extends State<DiagFilterSheet> {
  late DiagFilter _f = widget.initial;
  late final TextEditingController _search = TextEditingController(
    text: widget.initial.query,
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// `warn` reads as a level in a log and as a typo in a sentence; the rows
  /// say what each floor lets through instead.
  static String _sevTitle(DiagSev s) => switch (s) {
    DiagSev.trace => 'Trace',
    DiagSev.debug => 'Debug',
    DiagSev.info => 'Info',
    DiagSev.warn => 'Warning',
    DiagSev.error => 'Error',
  };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Category PICKING is not here: the chip row over the timeline does it,
    // counts and all, and a second list of the same eleven names under this
    // one read as the same control twice. A pick made there survives this
    // sheet untouched — it rides along in [_f].
    return SheetFrame(
      title: 'Filter',
      confirm: SheetConfirm(
        label: 'Apply',
        onTap: () => Navigator.of(context).pop(_f),
      ),
      // Pinned, so the sheet does not jump as the keyboard comes and goes,
      // and so its rows scroll inside it rather than off the top.
      maxHeightFraction: 0.9,
      padding: EdgeInsets.zero,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        children: [
          SearchField(
            controller: _search,
            hintText: 'Search name, detail, body',
            onChanged: (v) => setState(() => _f = _f.copyWith(query: v)),
          ),
          const SizedBox(height: 24),
          SheetGroup(
            header: 'Minimum severity',
            children: [
              for (final s in DiagSev.values)
                GroupedRow.choice(
                  title: _sevTitle(s),
                  subtitle: s == DiagSev.trace ? 'Everything' : null,
                  selected: _f.minSev == s,
                  onTap: () => setState(() => _f = _f.copyWith(minSev: s)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // The same switch as a long press on a chip in the row above the
          // timeline — here so it can be found without knowing the gesture.
          SheetGroup(
            header: 'Hidden from All',
            children: [
              for (final c in DiagCat.values)
                GroupedRow.toggle(
                  title: c.name,
                  value: _f.hidden.contains(c),
                  onChanged: (on) => setState(() {
                    final next = {..._f.hidden};
                    on ? next.add(c) : next.remove(c);
                    _f = _f.copyWith(hidden: next);
                  }),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Text(
              'Left out of All until picked on the chip row. Long-press a '
              'chip there for the same switch.',
              style: groupedFooterStyle(theme),
            ),
          ),
          const SizedBox(height: 24),
          SheetGroup(
            children: [
              GroupedRow.toggle(
                title: 'Collapse repeats',
                subtitle: 'Fold a run of the same event into one row',
                value: _f.collapse,
                onChanged: (v) => setState(() => _f = _f.copyWith(collapse: v)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SheetGroup(
            children: [
              GroupedRow(
                title: 'Reset filter',
                chevron: false,
                // Resets the view, not the preference: what All leaves out
                // is a standing choice, and has its own section above.
                onTap: () => setState(() {
                  _f = DiagFilter(hidden: _f.hidden);
                  _search.clear();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
