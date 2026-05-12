import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/app.dart';

void main() {
  testWidgets('MonkeyHub app boots without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const MonkeyHubApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
