import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';
import 'search_field.dart' show searchFieldDecoration;

/// One thing Settings search can find: a hub row, or a setting that lives one
/// page down (Profile visibility inside the account page, say).
///
/// Either opens a page ([onOpen]) or IS the control ([liveRow]) — a switch
/// found by search works right there in the results, the way iOS Settings
/// shows a found toggle rather than a link to it.
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.id,
    required this.title,
    required this.breadcrumb,
    required this.icon,
    required this.tone,
    this.keywords = '',
    this.englishText = '',
    this.onOpen,
    this.liveRow,
  }) : assert(onOpen != null || liveRow != null);

  final String id;
  final String title;

  /// Where it lives — "Appearance › Glass" — shown under the title so a hit
  /// one level down still says how to get there by hand.
  final String breadcrumb;
  final IconData icon;
  final TileTone tone;

  /// Localized synonyms, comma separated ("dark, light, night, …").
  final String keywords;

  /// The English title and keywords, matched too: people type "debug" or
  /// "glass" whatever language the app is in.
  final String englishText;
  final VoidCallback? onOpen;
  final Widget Function()? liveRow;

  bool matches(String query) {
    final tokens = normalizeForSearch(query)
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty);
    if (tokens.isEmpty) return false;
    final hay = normalizeForSearch(
      '$title $breadcrumb $keywords $englishText',
    );
    return tokens.every(hay.contains);
  }
}

/// Lower case with the common Latin diacritics folded away, so "dil" finds
/// "Dİl" and "telechargement" finds "téléchargement".
String normalizeForSearch(String s) {
  const from = 'ıİşŞğĞçÇöÖüÜéèêëÉÈáàâäãÁÀÂÄÃíìîïÍóòôõÓúùûÚñÑåÅ';
  const to = 'iissggccoouueeeeeeaaaaaaaaaaiiiiiooooouuuunnaa';
  final b = StringBuffer();
  for (final ch in s.characters) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().toLowerCase();
}

/// The iOS Settings search capsule: magnifier, field, a clear button while
/// there is text, and Cancel beside it while searching.
class SettingsSearchField extends StatefulWidget {
  const SettingsSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  State<SettingsSearchField> createState() => _SettingsSearchFieldState();
}

class _SettingsSearchFieldState extends State<SettingsSearchField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_changed);
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_changed);
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _cancel() {
    widget.controller.clear();
    widget.onChanged('');
    widget.focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final searching =
        widget.focusNode.hasFocus || widget.controller.text.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: searchFieldDecoration(theme),
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: Row(
              children: [
                Icon(CupertinoIcons.search, size: 18, color: theme.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    onChanged: widget.onChanged,
                    textInputAction: TextInputAction.search,
                    autocorrect: false,
                    cursorColor: theme.accent,
                    style: groupedTitleStyle(theme),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: l10n.settingsSearchHint,
                      hintStyle: groupedValueStyle(theme),
                    ),
                  ),
                ),
                if (widget.controller.text.isNotEmpty)
                  SpringPress(
                    onTap: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                    semanticLabel: MaterialLocalizations.of(
                      context,
                    ).deleteButtonTooltip,
                    focusShape: FocusRingShape.circle,
                    scale: 0.86,
                    haptic: false,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 18,
                        color: theme.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Cancel slides in beside the field while searching, as in iOS.
        AnimatedSize(
          duration: motion.d(const Duration(milliseconds: 260)),
          curve: Curves.easeOutCubic,
          child: searching
              ? Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: TextLinkButton(
                    label: l10n.acctCancel,
                    onTap: _cancel,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// The flat result list: every match as one grouped block, rising in on a
/// gentle spring, or a quiet "No results" line.
class SettingsSearchResults extends StatelessWidget {
  const SettingsSearchResults({
    super.key,
    required this.entries,
    required this.query,
  });

  final List<SettingsSearchEntry> entries;
  final String query;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    final hits = [for (final e in entries) if (e.matches(query)) e];
    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
        child: Text(
          l10n.settingsSearchNoResults(query.trim()),
          textAlign: TextAlign.center,
          style: groupedValueStyle(theme),
        ),
      );
    }
    // The block rises in once when results first appear; later keystrokes
    // just reflow it. Rows stay bare GroupedRows so the section's hairlines
    // keep their inset to the text.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.d(const Duration(milliseconds: 380)),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
      ),
      child: GroupedSection(
        children: [for (final e in hits) _row(e)],
      ),
    );
  }

  Widget _row(SettingsSearchEntry e) {
    final live = e.liveRow;
    if (live != null) return live();
    return GroupedRow(
      icon: e.icon,
      tone: e.tone,
      title: e.title,
      subtitle: e.breadcrumb,
      onTap: e.onOpen,
    );
  }
}
