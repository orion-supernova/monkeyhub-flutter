import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';
import 'search_field.dart' show SearchField;

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

/// The Settings hub's search bar: THE [SearchField], with its Cancel.
///
/// It used to be its own 38pt capsule with an 18pt glyph — one of four
/// search bars that had drifted apart in height, glyph and fill. Kept as a
/// name only so the hub's call site reads as what it is; everything it draws
/// is the shared field's.
class SettingsSearchField extends StatelessWidget {
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
  Widget build(BuildContext context) => SearchField(
        controller: controller,
        focusNode: focusNode,
        hintText: AppLocalizations.of(context).settingsSearchHint,
        onChanged: onChanged,
        // Top of a tab, so the iOS Cancel: it clears, puts the keyboard
        // away and brings the hub back.
        showCancel: true,
        // iOS Settings.app's 36pt capsule; Chats' search stays 44.
        compact: true,
      );
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
