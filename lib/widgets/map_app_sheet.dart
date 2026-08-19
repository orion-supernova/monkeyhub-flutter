import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/map_apps.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';

/// Asks which maps application a shared location should open in.
///
/// Shown only when the answer is genuinely in doubt — see [maybeChoose]. On a
/// phone with one maps app this sheet never appears, because a chooser with a
/// single row is a tap the user didn't need to make.
///
/// Rows are brand names with no icons. Bundling vendor logos would mean
/// shipping a dozen trademarked marks, each under its own usage terms, to save
/// a reader who is scanning for the word "Waze" nothing at all; the monogram
/// gives the list enough shape to scan without pretending to be an app grid.
class MapAppSheet extends StatelessWidget {
  const MapAppSheet({super.key, required this.apps});

  /// The installed apps, in [kMapAppCatalog] order. [kBrowserFallback] is
  /// appended by this widget rather than by the caller, so every presentation
  /// of the sheet offers the same escape hatch.
  final List<MapApp> apps;

  /// Presents the chooser when there is a choice to present.
  ///
  /// Returns the app to open, or null if the user dismissed it. The two
  /// short-circuits matter as much as the sheet:
  ///
  ///  * **No detected apps** returns null without showing anything, so the
  ///    caller falls through to its existing handoff chain rather than
  ///    offering a sheet whose only row is "browser".
  ///  * **Exactly one detected app** returns it directly. A modal asking a
  ///    question with one answer is a worse experience than the default
  ///    behaviour it replaced.
  static Future<MapApp?> maybeChoose(
    BuildContext context,
    List<MapApp> apps,
  ) async {
    if (apps.isEmpty) return null;
    if (apps.length == 1) return apps.first;
    return showAdaptiveSheet<MapApp>(
      context,
      builder: (_) => MapAppSheet(apps: apps),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.mapAppSheetTitle, style: theme.displaySmall),
            const SizedBox(height: 12),
            for (final app in apps)
              _MapAppRow(
                app: app,
                onTap: () => Navigator.of(context).pop(app),
              ),
            // Separated from the installed apps because it is a different kind
            // of answer: everything above leaves for an app the user chose to
            // have, this leaves for a web page.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.ink.withValues(alpha: 0.08),
              ),
            ),
            _MapAppRow(
              app: kBrowserFallback,
              subtitle: l10n.mapAppSheetBrowser,
              onTap: () => Navigator.of(context).pop(kBrowserFallback),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapAppRow extends StatelessWidget {
  const _MapAppRow({required this.app, required this.onTap, this.subtitle});

  final MapApp app;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: app.name,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        // Opaque so the whole row is the target, including the gap between the
        // monogram and the name — a 44pt row that only responds on its text is
        // a 44pt row in appearance only.
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  // Brand names here are all Latin-script, so one character
                  // reads as a monogram rather than as a truncation.
                  app.name.characters.first.toUpperCase(),
                  style: theme.label.copyWith(color: theme.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(app.name, style: theme.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.bodySoft),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_outward,
                size: 16,
                color: theme.ink.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
