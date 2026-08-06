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
    this.minSev = DiagSev.trace,
    this.query = '',
    this.collapse = true,
  });

  /// Empty means "everything" rather than "nothing" — the common case is no
  /// filter at all, and it should not require selecting all eleven categories.
  final Set<DiagCat> cats;
  final DiagSev minSev;
  final String query;
  final bool collapse;

  bool matches(DiagEvent e) {
    if (cats.isNotEmpty && !cats.contains(e.cat)) return false;
    if (e.sev.index < minSev.index) return false;
    if (query.isEmpty) return true;
    return e.searchHaystack.contains(query.toLowerCase());
  }

  DiagFilter copyWith({
    Set<DiagCat>? cats,
    DiagSev? minSev,
    String? query,
    bool? collapse,
  }) => DiagFilter(
    cats: cats ?? this.cats,
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
            Text('FILTER', style: theme.label),
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
            Text('CATEGORY', style: theme.monoTiny),
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
            Text('MINIMUM SEVERITY', style: theme.monoTiny),
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
                  onTap: () => setState(() {
                    _f = const DiagFilter();
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
          decoration: BoxDecoration(
            color: on ? theme.accent.withValues(alpha: 0.18) : theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(color: on ? theme.accent : theme.divider),
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
