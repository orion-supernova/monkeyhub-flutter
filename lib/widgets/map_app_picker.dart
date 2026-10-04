import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/maps_handoff.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import 'settings_pickers.dart' show GroupedFooter;

enum MapOpenResult { opened, cancelled, failed }

/// One chooser for every location surface. Remember only a successful launch;
/// an uninstalled default returns to the chooser instead of redirecting silently.
Future<MapOpenResult> openMapLocation(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String? label,
}) async {
  if (!MapsHandoff.validCoordinates(latitude, longitude)) {
    return MapOpenResult.failed;
  }
  final store = SettingsStore.instance;
  var apps = await MapsHandoff.availableApps();
  var unavailable = false;
  final defaultId = store.mapAppId;
  final preferred = apps.where((app) => app.id == defaultId).firstOrNull;
  if (defaultId != null) {
    if (preferred != null &&
        await MapsHandoff.launch(
          preferred,
          latitude: latitude,
          longitude: longitude,
          label: label,
        )) {
      return MapOpenResult.opened;
    }
    unavailable = true;
    apps = apps.where((app) => app.id != defaultId).toList();
  }
  while (apps.isNotEmpty) {
    if (!context.mounted) return MapOpenResult.cancelled;
    FocusManager.instance.primaryFocus?.unfocus();
    final pick = await showAdaptiveSheet<({MapApp app, bool remember})>(
      context,
      builder: (_) => MapAppPicker(apps: apps, unavailable: unavailable),
    );
    if (pick == null) return MapOpenResult.cancelled;
    final opened = await MapsHandoff.launch(
      pick.app,
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
    if (opened) {
      if (pick.remember) await store.setMapApp(pick.app.id, pick.app.name);
      return MapOpenResult.opened;
    }
    // App removal or a launch failure between discovery and selection.
    unavailable = true;
    apps = apps.where((app) => app.id != pick.app.id).toList();
  }
  return MapOpenResult.failed;
}

class MapAppPicker extends StatefulWidget {
  const MapAppPicker({super.key, required this.apps, this.unavailable = false});
  final List<MapApp> apps;
  final bool unavailable;
  @override
  State<MapAppPicker> createState() => _MapAppPickerState();
}

class _MapAppPickerState extends State<MapAppPicker> {
  bool _remember = false;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SheetFrame(
      title: l.mapAppsChoose,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.unavailable) GroupedFooter(l.mapAppsUnavailable),
            if (widget.apps.every((app) => app.id == 'browser'))
              GroupedFooter(l.mapAppsNoInstalled),
            GroupedSection(
              children: [
                for (final app in widget.apps)
                  GroupedRow(
                    icon: app.id == 'browser'
                        ? CupertinoIcons.globe
                        : CupertinoIcons.map,
                    tone: TileTone.teal,
                    title: app.id == 'browser' ? l.mapAppsBrowser : app.name,
                    onTap: () => Navigator.of(
                      context,
                    ).pop((app: app, remember: _remember)),
                  ),
              ],
            ),
            GroupedSection(
              children: [
                GroupedRow.toggle(
                  icon: CupertinoIcons.checkmark_circle,
                  tone: TileTone.gray,
                  title: l.mapAppsRemember,
                  value: _remember,
                  onChanged: (value) => setState(() => _remember = value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
