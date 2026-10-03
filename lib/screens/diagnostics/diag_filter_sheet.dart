import 'package:flutter/material.dart';

import '../../diagnostics/diag_event.dart';
import '../../keyboard/focusable_tap.dart';
import '../../theme/theme_scope.dart';

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
    final theme = ThemeScope.of(context);
    return showModalBottomSheet<DiagFilter>(
      context: context,
      backgroundColor: theme.surfaceRaised,
      isScrollControlled: true,
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter', style: theme.bodyEmph.copyWith(fontSize: 20, color: theme.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              style: theme.body,
              decoration: InputDecoration(
                hintText: 'Search name, detail, body…',
                hintStyle: theme.bodySoft,
                isDense: true,
              ),
              onChanged: (v) => setState(() => _f = _f.copyWith(query: v)),
            ),
            const SizedBox(height: 14),
            Text('Category', style: theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in DiagCat.values)
                  _Chip(
                    label: c.name,
                    on: _f.cats.contains(c),
                    onTap: () => setState(() {
                      final next = {..._f.cats};
                      next.contains(c) ? next.remove(c) : next.add(c);
                      _f = _f.copyWith(cats: next);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // The same switch as a long press on a chip in the row above the
            // timeline — here so it can be found without knowing the gesture.
            Text('Hidden from All', style: theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in DiagCat.values)
                  _Chip(
                    label: c.name,
                    on: _f.hidden.contains(c),
                    onTap: () => setState(() {
                      final next = {..._f.hidden};
                      next.contains(c) ? next.remove(c) : next.add(c);
                      _f = _f.copyWith(hidden: next);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Minimum severity', style: theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final s in DiagSev.values)
                  _Chip(
                    label: s.name,
                    on: _f.minSev == s,
                    onTap: () => setState(() => _f = _f.copyWith(minSev: s)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _Chip(
              label: 'collapse repeats',
              on: _f.collapse,
              onTap: () =>
                  setState(() => _f = _f.copyWith(collapse: !_f.collapse)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Chip(
                  label: 'reset',
                  on: false,
                  // Resets the view, not the preference: what All leaves out
                  // is a standing choice, and has its own section above.
                  onTap: () => setState(() {
                    _f = DiagFilter(hidden: _f.hidden);
                    _search.clear();
                  }),
                ),
                const Spacer(),
                _Chip(
                  label: 'apply',
                  on: true,
                  onTap: () => Navigator.of(context).pop(_f),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Bare GestureDetector plus FocusableTap, never a Material chip — this app
    // registers no ink or ripple anywhere.
    return FocusableTap(
      onTap: onTap,
      radius: theme.radiusSm,
      semanticLabel: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          // Filled capsules, the chat list's filter chips — no outline.
          decoration: BoxDecoration(
            color: on
                ? theme.accent.withValues(alpha: 0.18)
                : theme.ink.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.monoTiny.copyWith(
              color: on ? theme.accent : theme.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
