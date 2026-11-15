import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/location_map_preview.dart';

/// On iOS and macOS the location card gets an Apple Maps picture
/// (`MKMapSnapshotter`, through `monkeyhub/map_snapshot`) under its marker.
/// Everywhere else, and whenever the snapshot fails, the drawn graticule card
/// stays: a failed map must never leave an empty rectangle.
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

  testWidgets('Android never calls the channel', (tester) async {
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          called = true;
          return png;
        });

    await tester.pumpWidget(card(lat: 20, lng: 20));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.byType(Image), findsNothing);
  });
}
