import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/location_picker_screen.dart';
import 'package:monkeyhub/services/location_service.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/location_share_sheet.dart';
import 'package:monkeyhub/widgets/map_engine.dart';
import 'package:monkeyhub/widgets/open_free_map_snapshot.dart';

/// "Choose a place": the pin is fixed in the middle and the map moves under
/// it; "Send this location" sends wherever the map came to rest.
void main() {
  const channel = MethodChannel('monkeyhub/map_snapshot');

  setUp(() {
    MapEngines.debugReset();
    // Android without Google Maps: the OpenFreeMap map, tiles offline.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'search' || call.method == 'nearby') return [];
          return false;
        });
    OpenFreeMapSnapshot.client = MockClient((_) async => http.Response('', 503));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('sends where the map came to rest', (tester) async {
    LocationShareChoice? picked;
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => picked = await LocationPickerScreen.open(
                  context,
                  start: LocationFix(
                    latitude: 41,
                    longitude: 29,
                    timestamp: DateTime(2026),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);

    // Drag the map; the pin stays put, so the place under it changes.
    await tester.drag(find.byType(FlutterMap), const Offset(-120, 80));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send this location'));
    await tester.pumpAndSettle();
    final place = picked?.place;
    expect(place, isNotNull);
    expect(
      const Distance().as(
        LengthUnit.Meter,
        const LatLng(41, 29),
        LatLng(place!.latitude, place.longitude),
      ),
      greaterThan(20),
    );
  });

  testWidgets('opens on you: current location and live are one tap away', (
    tester,
  ) async {
    LocationShareChoice? picked;
    Future<void> open() async {
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async =>
                      picked = await LocationPickerScreen.open(
                        context,
                        start: LocationFix(
                          latitude: 41,
                          longitude: 29,
                          accuracyM: 5,
                          timestamp: DateTime(2026),
                        ),
                      ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Accurate to 5 m'), findsOneWidget);
    await tester.tap(find.text('Send current location'));
    await tester.pumpAndSettle();
    expect(picked?.place, isNull);
    expect(picked?.isLive, isFalse);

    picked = null;
    await open();
    await tester.tap(find.text('Share live location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('For 1 hour'));
    await tester.pumpAndSettle();
    expect(picked?.isLive, isTrue);
  });
}
