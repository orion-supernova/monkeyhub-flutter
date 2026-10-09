import 'package:flutter/material.dart';

import '../../keyboard/app_shortcuts.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_scope.dart';
import '../glass_reveal.dart';
import '../glass_surface.dart';
import 'keycaps.dart';

/// The card that appears while ⌘ (Ctrl off Apple) is held: every shortcut the
/// screen on display answers, grouped, at a glance. The iPadOS
/// hold-⌘ sheet, for the same reason it exists there: shortcuts nobody can
/// find are shortcuts nobody uses, and holding the key you'd press anyway is
/// the cheapest possible way to ask.
///
/// An [OverlayEntry], never a route. A route would take focus and turn every
/// binding on the screen beneath it inactive, which would empty the very list
/// it is showing, and pressing K while it is up has to still run ⌘K.
///
/// Built once per showing from a snapshot of the registry: it only lives as
/// long as a key is held, and nothing it lists can change in that time
/// without the key being let go first.
class ShortcutPeek {
  ShortcutPeek._(this._entry, this._key);

  final OverlayEntry _entry;
  final GlobalKey<_PeekCardState> _key;

  static ShortcutPeek show(OverlayState overlay, {required List<String> sectionLabels}) {
    final key = GlobalKey<_PeekCardState>();
    late final ShortcutPeek peek;
    final entry = OverlayEntry(
      builder: (_) => _PeekCard(
        key: key,
        sectionLabels: sectionLabels,
        onGone: () => peek._remove(),
      ),
    );
    peek = ShortcutPeek._(entry, key);
    overlay.insert(entry);
    return peek;
  }

  bool _removed = false;

  /// Animates out, then removes itself.
  void hide() {
    final state = _key.currentState;
    if (state == null) {
      _remove();
    } else {
      state.leave();
    }
  }

  void _remove() {
    if (_removed) return;
    _removed = true;
    _entry.remove();
  }
}

class _PeekCard extends StatefulWidget {
  const _PeekCard({super.key, required this.sectionLabels, required this.onGone});

  final List<String> sectionLabels;
  final VoidCallback onGone;

  @override
  State<_PeekCard> createState() => _PeekCardState();
}

class _PeekCardState extends State<_PeekCard> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 120),
  )..forward();

  late final List<ShortcutDef> _defs;

  @override
  void initState() {
    super.initState();
    final reg = AppShortcutRegistry.instance;
    _defs = reg.available(ambientGroups: reg.liveGroups());
  }

  void leave() {
    _t.reverse().whenComplete(() {
      if (mounted) widget.onGone();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final groups = <ShortcutGroup, List<ShortcutDef>>{};
    for (final d in _defs) {
      (groups[d.group] ??= []).add(d);
    }
    final width = MediaQuery.sizeOf(context).width;
    // Columns as the window allows: three on a desktop window, down to one.
    final columns = (((width - 64) / 300).floor()).clamp(1, 3);
    const colWidth = 272.0;
    const gap = 28.0;

    return IgnorePointer(
      // Purely informational and gone the moment the key is let go; a click
      // that lands while it is up belongs to whatever is under it.
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, child) => GlassReveal(
              t: Curves.easeOutCubic.transform(_t.value),
              from: 0.94,
              child: child!,
            ),
            child: GlassSurface(
              radius: theme.radiusXl,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: columns * colWidth + (columns - 1) * gap,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.kbdPanelTitle, style: theme.bodyEmph),
                        const SizedBox(width: 16),
                        Keycaps.forDef(AppShortcuts.showShortcuts, size: KeycapSize.small),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: gap,
                      runSpacing: 18,
                      children: [
                        for (final g in ShortcutGroup.values)
                          if (groups[g] != null)
                            SizedBox(
                              width: colWidth,
                              child: _Group(
                                title: AppShortcuts.groupLabel(l10n, g),
                                defs: groups[g]!,
                                sectionLabels: widget.sectionLabels,
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.defs, required this.sectionLabels});

  final String title;
  final List<ShortcutDef> defs;
  final List<String> sectionLabels;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.caption.copyWith(
            color: theme.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        for (final d in defs)
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppShortcuts.label(l10n, d, sectionLabels: sectionLabels),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.body.copyWith(fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 12),
                Keycaps.forDef(d, size: KeycapSize.small),
              ],
            ),
          ),
      ],
    );
  }
}
