import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/location_share.dart';
import 'package:monkeyhub/screens/location_map_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/map_engine.dart';
import 'package:monkeyhub/widgets/open_free_map_snapshot.dart';

/// The full-screen map a location bubble opens. The point of it for live
/// shares: new fixes arrive here by themselves, where a maps app only ever
/// got the one coordinate it was opened with.
void main() {
  const channel = MethodChannel('monkeyhub/map_snapshot');
  final now = DateTime(2026, 11, 15, 12);

  setUp(() {
    MapEngines.debugReset();
    // Android with no Google Maps: the OpenFreeMap map, tiles offline.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    OpenFreeMapSnapshot.client = MockClient((_) async => http.Response('', 503));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: child,
    ),
  );

  testWidgets('a live share moves on the map without another tap', (
    tester,
  ) async {
    final share = ValueNotifier(
      LocationShare(
        latitude: 41.0,
        longitude: 29.0,
        accuracyM: 15,
        liveExpiresAt: now.add(const Duration(minutes: 30)),
        liveUpdatedAt: now,
      ),
    );
    var opened = 0;
    await tester.pumpWidget(
      host(
        LocationMapScreen(
          share: share,
          clock: () => now,
          title: 'Zeynep',
          onOpenInMaps: (_) async => opened++,
        ),
      ),
    );
    await tester.pump();

    MarkerLayer markerLayer() => tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer().markers.single.point.latitude, 41.0);

    share.value = LocationShare(
      latitude: 41.01,
      longitude: 29.02,
      accuracyM: 12,
      liveExpiresAt: now.add(const Duration(minutes: 30)),
      liveUpdatedAt: now,
    );
    await tester.pump();
    expect(markerLayer().markers.single.point.latitude, 41.01);
    expect(markerLayer().markers.single.point.longitude, 29.02);

    await tester.tap(find.text('Open in maps'));
    await tester.pump();
    expect(opened, 1);

    // Ending the share while open says so in the bar.
    share.value = LocationShare(
      latitude: 41.01,
      longitude: 29.02,
      liveExpiresAt: now.add(const Duration(minutes: 30)),
      liveEndedAt: now,
    );
    await tester.pump();
    expect(find.textContaining('ended'), findsOneWidget);
    expect(find.text(OpenFreeMapSnapshot.attribution), findsOneWidget);
  });
}
