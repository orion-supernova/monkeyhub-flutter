import 'dart:async';

import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import 'screen_share.dart';

/// The desktop question a phone never asks: which screen?
///
/// Lists every display and window the platform will let us capture, with
/// the thumbnails it hands out, and returns the pick — or null when the
/// sheet is dismissed. A window share is what the drawing overlay maps to
/// exactly (the presenter's strokes land on the window the app is), so the
/// app's own window is listed first.
Future<ScreenShareSource?> showSharePickerSheet(BuildContext context) {
  return showAdaptiveSheet<ScreenShareSource>(
    context,
    builder: (_) => const _SharePickerSheet(),
  );
}

class _SharePickerSheet extends StatefulWidget {
  const _SharePickerSheet();

  @override
  State<_SharePickerSheet> createState() => _SharePickerSheetState();
}

class _SharePickerSheetState extends State<_SharePickerSheet> {
  List<ScreenShareSource>? _sources;

  @override
  void initState() {
    super.initState();
    unawaited(ScreenShare.sources().then((s) {
      if (mounted) setState(() => _sources = s);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final sources = _sources;
    final screens = sources?.where((s) => !s.isWindow).toList() ?? const [];
    final windows = sources?.where((s) => s.isWindow).toList() ?? const [];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.screenSharePickerTitle, style: theme.displaySmall),
            const SizedBox(height: 14),
            if (sources == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (sources.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.screenSharePickerEmpty,
                  style: theme.bodySoft,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 460),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (screens.isNotEmpty) ...[
                      _Header(l10n.screenSharePickerScreens),
                      _Grid(sources: screens),
                    ],
                    if (windows.isNotEmpty) ...[
                      _Header(l10n.screenSharePickerWindows),
                      _Grid(sources: windows),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: theme.monoTiny.copyWith(color: theme.inkMuted),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.sources});
  final List<ScreenShareSource> sources;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final s in sources)
          FocusableTap(
            onTap: () => Navigator.of(context).pop(s),
            radius: theme.radiusMd,
            semanticLabel: s.name,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(s),
              child: SizedBox(
                width: 168,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      child: Container(
                        width: 168,
                        height: 105,
                        color: theme.surfaceSunken,
                        child: s.thumbnail != null
                            ? Image.memory(
                                s.thumbnail!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              )
                            : Icon(
                                s.isWindow
                                    ? Icons.web_asset_outlined
                                    : Icons.desktop_windows_outlined,
                                color: theme.inkMuted,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.name,
                      style: theme.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
