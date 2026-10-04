import 'package:flutter/cupertino.dart'
    show CupertinoIcons, CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/maps_handoff.dart';
import '../widgets/ios_kit.dart';
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
        ],
      );
    },
  );
}
