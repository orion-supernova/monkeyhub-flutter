import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/maps_handoff.dart';
import '../widgets/ios_kit.dart';
import '../widgets/map_engine.dart';
import '../widgets/ofm_style_choices.dart';
import '../widgets/settings_pickers.dart';

class MapAppsScreen extends StatefulWidget {
  const MapAppsScreen({super.key});
  @override
  State<MapAppsScreen> createState() => _MapAppsScreenState();
}

class _MapAppsScreenState extends State<MapAppsScreen>
    with WidgetsBindingObserver {
  List<MapApp>? _apps;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Android: learn whether Google Maps can be used, for the footnote.
    if (MapEngines.googleReady == null) {
      MapEngines.resolve().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final apps = await MapsHandoff.availableApps();
    if (mounted) setState(() => _apps = apps);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: SettingsStore.instance,
    builder: (context, _) {
      final store = SettingsStore.instance;
      final l = AppLocalizations.of(context);
      final apps = _apps;
      final missing =
          store.mapAppId != null &&
          apps != null &&
          !apps.any((app) => app.id == store.mapAppId);
      return SettingsPage(
        title: l.mapAppsTitle,
        children: [
          GroupedFooter(l.mapAppsSubtitle),
          GroupedSection(
            children: [
              GroupedRow.choice(
                icon: CupertinoIcons.question_circle,
                tone: TileTone.gray,
                title: l.mapAppsAskEveryTime,
                selected: store.mapAppId == null,
                onTap: () {
                  pickFeedback();
                  store.setMapApp(null, null);
                },
              ),
              if (apps != null)
                for (final app in apps)
                  GroupedRow.choice(
                    icon: app.id == 'browser'
                        ? CupertinoIcons.globe
                        : CupertinoIcons.map,
                    tone: TileTone.teal,
                    title: app.id == 'browser' ? l.mapAppsBrowser : app.name,
                    selected: store.mapAppId == app.id,
                    onTap: () {
                      pickFeedback();
                      store.setMapApp(app.id, app.name);
                    },
                  ),
            ],
          ),
          if (apps == null) const Center(child: CupertinoActivityIndicator()),
          if (missing) GroupedFooter(l.mapAppsUnavailable),
          if (apps != null && apps.every((app) => app.id == 'browser'))
            GroupedFooter(l.mapAppsNoInstalled),
          ..._mapSource(store, l),
        ],
      );
    },
  );

  /// Which maps draw shared locations. Only where the OS has maps of its own;
  /// elsewhere OpenFreeMap is the only source and there is nothing to choose.
  List<Widget> _mapSource(SettingsStore store, AppLocalizations l) {
    final system = MapEngines.systemName;
    // OpenFreeMap's look, wherever OpenFreeMap is what draws.
    final ofmShown =
        system == null || store.mapSource == MapSource.openFreeMap;
    if (system == null) return const [OfmStyleChoices()];
    return [
      GroupedSection(
        header: l.mapSourceSection,
        children: [
          GroupedRow.choice(
            icon: CupertinoIcons.map_fill,
            tone: TileTone.blue,
            title: system,
            selected: store.mapSource == MapSource.system,
            onTap: () {
              pickFeedback();
              store.setMapSource(MapSource.system);
            },
          ),
          GroupedRow.choice(
            icon: CupertinoIcons.globe,
            tone: TileTone.green,
            title: 'OpenFreeMap',
            selected: store.mapSource == MapSource.openFreeMap,
            onTap: () {
              pickFeedback();
              store.setMapSource(MapSource.openFreeMap);
            },
          ),
        ],
      ),
      GroupedFooter(
        store.mapSource == MapSource.system && MapEngines.googleReady == false
            ? '${l.mapSourceFooter}\n${l.mapSourceGoogleUnavailable}'
            : l.mapSourceFooter,
      ),
      if (ofmShown) const OfmStyleChoices(),
    ];
  }
}
