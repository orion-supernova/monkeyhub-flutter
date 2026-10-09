import 'package:flutter/material.dart';

import '../../keyboard/app_shortcuts.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_scope.dart';
import '../adaptive_sheet.dart';
import '../search_field.dart';
import '../sheet_kit.dart';
import 'keycaps.dart';

/// The full list of keyboard shortcuts, searchable. Opened with ⌘/ and from
/// Settings.
///
/// Lists the WHOLE catalog, not just what the screen beneath answers: this is
/// the place someone goes to learn what exists. What the screen beneath does
/// answer is drawn at full strength and runs on click; the rest is dimmed,
/// under a heading that says where it applies ("In a chat", "Calls").
///
/// What runs on click is snapshotted before the panel opens. Once it is up,
/// the panel's own route is the current one and every binding beneath it has
/// gone inactive, so asking the registry then would find nothing.
Future<void> showShortcutsPanel(
  BuildContext context, {
  required List<String> sectionLabels,
}) async {
  final reg = AppShortcutRegistry.instance;
  final live = <ShortcutDef, bool>{
    for (final d in AppShortcuts.all) d: !d.ambient && reg.isBound(d),
  };
  final picked = await showAdaptiveSheet<ShortcutDef>(
    context,
    useRootNavigator: true,
    maxWidth: 520,
    builder: (_) => _ShortcutsPanel(live: live, sectionLabels: sectionLabels),
  );
  // After the pop, so the binding's route is current again when it runs.
  if (picked != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => reg.invoke(picked));
  }
}

class _ShortcutsPanel extends StatefulWidget {
  const _ShortcutsPanel({required this.live, required this.sectionLabels});

  final Map<ShortcutDef, bool> live;
  final List<String> sectionLabels;

  @override
  State<_ShortcutsPanel> createState() => _ShortcutsPanelState();
}

class _ShortcutsPanelState extends State<_ShortcutsPanel> {
  final _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final q = _q.trim().toLowerCase();
    final groups = <ShortcutGroup, List<ShortcutDef>>{};
    for (final d in AppShortcuts.all) {
      if (!d.offeredHere) continue;
      final label = AppShortcuts.label(l10n, d, sectionLabels: widget.sectionLabels);
      if (label.isEmpty) continue;
      if (q.isNotEmpty &&
          !label.toLowerCase().contains(q) &&
          !AppShortcuts.groupLabel(l10n, d.group).toLowerCase().contains(q) &&
          !d.chords.any((c) => c.caps().join().toLowerCase().contains(q))) {
        continue;
      }
      (groups[d.group] ??= []).add(d);
    }
    final modifier = KeyCombo.appleModifiers ? '⌘' : 'Ctrl';

    return SheetFrame(
      title: l10n.kbdPanelTitle,
      showClose: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            controller: _query,
            hintText: l10n.kbdPanelSearchHint,
            autofocus: true,
            showCancel: false,
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.6).clamp(240, 560),
            ),
            child: groups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      l10n.kbdPanelEmpty,
                      textAlign: TextAlign.center,
                      style: theme.bodySoft,
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final g in ShortcutGroup.values)
                        if (groups[g] != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
                            child: Text(
                              AppShortcuts.groupLabel(l10n, g),
                              style: theme.caption.copyWith(
                                color: theme.inkMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final d in groups[g]!)
                            _Row(
                              def: d,
                              label: AppShortcuts.label(l10n, d, sectionLabels: widget.sectionLabels),
                              live: widget.live[d] ?? false,
                            ),
                        ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.kbdPeekHint(modifier),
            textAlign: TextAlign.center,
            style: theme.caption.copyWith(color: theme.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.def, required this.label, required this.live});

  final ShortcutDef def;
  final String label;

  /// Answered by the screen beneath: full strength, and a click runs it.
  final bool live;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _hover ? theme.ink.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(
                fontSize: 14,
                color: widget.live || widget.def.ambient ? theme.ink : theme.inkMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Every chord, not just the first: ⌃⇥ is as real as ⌥⌘↓.
          for (var i = 0; i < widget.def.chords.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Keycaps(widget.def.chords[i], size: KeycapSize.small),
          ],
        ],
      ),
    );
    if (!widget.live) return row;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: FocusableTap(
        onTap: () => Navigator.of(context).pop(widget.def),
        semanticLabel: widget.label,
        radius: 8,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(widget.def),
          child: row,
        ),
      ),
    );
  }
}
