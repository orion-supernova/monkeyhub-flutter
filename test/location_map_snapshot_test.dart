import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/location_map_preview.dart';
import 'package:monkeyhub/widgets/open_free_map_snapshot.dart';

/// On iOS and macOS the location card gets an Apple Maps picture
/// (`MKMapSnapshotter`, through `monkeyhub/map_snapshot`) under its marker;
/// everywhere else, OpenFreeMap tiles drawn in Dart, with their required
/// credit. Whenever the map fails, the drawn graticule card stays: a failed
/// map must never leave an empty rectangle.
void main() {
  const channel = MethodChannel('monkeyhub/map_snapshot');
  // A 1×1 transparent PNG stands in for the map.
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  Widget card({double lat = 41.0082, double lng = 28.9784}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 300,
        height: 162,
        child: LocationMapPreview(
          theme: BasicTheme.midnight(),
          latitude: lat,
          longitude: lng,
          accuracyM: 20,
        ),
      ),
    ),
  );

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('iOS asks MapKit for the view and shows the picture', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return png;
        });

    await tester.pumpWidget(card());
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    final args = calls.single.arguments as Map;
    expect(args['latitude'], 41.0082);
    expect(args['width'], 300);
    expect(args['height'], 162);
    expect(args['dark'], isTrue); // Midnight is a dark theme.
    expect(find.byType(Image), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a failed snapshot keeps the drawn card', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    await tester.pumpWidget(card(lat: 10, lng: 10));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android draws OpenFreeMap, credits it, and never asks MapKit', (
    tester,
  ) async {
    var mapKit = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          mapKit = true;
          return png;
        });
    final requested = <String>[];
    OpenFreeMapSnapshot.client = MockClient((request) async {
      final url = request.url.toString();
      requested.add(url);
      if (url.endsWith('/planet')) {
        return http.Response(
          jsonEncode({
            'tiles': ['https://tiles.openfreemap.org/planet/test/{z}/{x}/{y}.pbf'],
          }),
          200,
        );
      }
      if (url.contains('/styles/')) {
        return http.Response(
          jsonEncode({
            'version': 8,
            'sources': {
              'openmaptiles': {'type': 'vector'},
            },
            'layers': [
              {
                'id': 'bg',
                'type': 'background',
                'paint': {'background-color': '#f8f4f0'},
              },
            ],
          }),
          200,
        );
      }
      if (url.endsWith('.pbf')) return http.Response.bytes(const [], 200);
      return http.Response('', 404); // No sprite: icons are optional.
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(card(lat: 20, lng: 20));
      for (var i = 0; i < 50 && find.byType(Image).evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(milliseconds: 300));

    expect(mapKit, isFalse);
    expect(requested.any((u) => u.contains('/styles/dark')), isTrue);
    expect(requested.any((u) => u.endsWith('.pbf')), isTrue);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text(OpenFreeMapSnapshot.attribution), findsOneWidget);
  });

  testWidgets('Android offline keeps the drawn card', (tester) async {
    OpenFreeMapSnapshot.client = MockClient(
      (_) async => http.Response('', 503),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(card(lat: 30, lng: 30));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.text(OpenFreeMapSnapshot.attribution), findsNothing);
  });
}
