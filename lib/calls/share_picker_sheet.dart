import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/ios_kit.dart';
import '../widgets/sheet_kit.dart';
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
    return SheetFrame(
      title: l10n.screenSharePickerTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sources == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (sources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.screenSharePickerEmpty,
                  style: groupedFooterStyle(theme),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 460),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (screens.isNotEmpty) ...[
                    GroupedHeader(l10n.screenSharePickerScreens),
                    _Grid(sources: screens),
                  ],
                  if (windows.isNotEmpty) ...[
                    GroupedHeader(l10n.screenSharePickerWindows),
                    _Grid(sources: windows),
                  ],
                ],
              ),
            ),
        ],
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
          SpringPress(
            onTap: () => Navigator.of(context).pop(s),
            semanticLabel: s.name,
            scale: 0.95,
            child: SizedBox(
              width: 168,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      (groupedRadius(theme) * 0.7).clamp(6.0, 14.0),
                    ),
                    child: Container(
                      width: 168,
                      height: 105,
                      color: sheetGroupFill(theme),
                      child: s.thumbnail != null
                          ? Image.memory(
                              s.thumbnail!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            )
                          : Icon(
                              s.isWindow
                                  ? CupertinoIcons.macwindow
                                  : CupertinoIcons.desktopcomputer,
                              color: theme.inkMuted,
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.name,
                    style: groupedMetaStyle(theme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
