import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/services/map_apps.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/map_app_sheet.dart';

/// When the chooser appears, and when it deliberately doesn't.
///
/// The sheet itself is the easy half. The half worth testing is the two cases
/// where it must NOT appear: a modal that asks a question with one possible
/// answer is strictly worse than the behaviour it replaced, and a modal offering
/// only "open in a browser" is worse still — the caller has a perfectly good
/// platform handoff to fall through to.
void main() {
  MapApp app(String id) => kMapAppCatalog.firstWhere((a) => a.id == id);

  late MapApp? result;
  late bool completed;

  // ThemeScope wraps MaterialApp, matching lib/app.dart. The nesting is
  // load-bearing rather than incidental: the chooser is pushed as a route, so
  // a ThemeScope placed inside `home:` sits BELOW the Navigator and the sheet
  // builds outside it. Getting this backwards fails with
  // "ThemeScope.of() called with no ThemeScope ancestor" — in the test only,
  // which is exactly why the harness has to mirror the real tree.
  Widget host(List<MapApp> apps) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                result = await MapAppSheet.maybeChoose(context, apps);
                completed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    result = null;
    completed = false;
  });

  Future<void> tapOpen(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('no detected apps shows nothing and answers null', (t) async {
    await t.pumpWidget(host(const []));
    await tapOpen(t);

    expect(find.byType(MapAppSheet), findsNothing);
    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('exactly one app opens it without asking', (t) async {
    await t.pumpWidget(host([app('google')]));
    await tapOpen(t);

    expect(find.byType(MapAppSheet), findsNothing);
    expect(result?.id, 'google');
  });

  testWidgets('two apps ask, and list both plus a browser row', (t) async {
    await t.pumpWidget(host([app('apple'), app('google')]));
    await tapOpen(t);

    expect(find.byType(MapAppSheet), findsOneWidget);
    expect(find.text('Apple Maps'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    // The escape hatch is added by the sheet, not by the caller, so it is
    // present on every presentation.
    expect(find.text(kBrowserFallback.name), findsOneWidget);
  });

  testWidgets('picking a row answers with that app', (t) async {
    await t.pumpWidget(host([app('apple'), app('google')]));
    await tapOpen(t);
    await t.tap(find.text('Google Maps'));
    await t.pumpAndSettle();

    expect(result?.id, 'google');
    expect(find.byType(MapAppSheet), findsNothing);
  });

  testWidgets('the browser row answers with the fallback', (t) async {
    await t.pumpWidget(host([app('apple'), app('google')]));
    await tapOpen(t);
    await t.tap(find.text(kBrowserFallback.name));
    await t.pumpAndSettle();

    expect(result?.id, kBrowserFallback.id);
  });

  testWidgets('dismissing answers null rather than a default', (t) async {
    await t.pumpWidget(host([app('apple'), app('google')]));
    await tapOpen(t);
    // Tap the barrier above the sheet.
    await t.tapAt(const Offset(400, 40));
    await t.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('rows carry no yellow-underline debug text', (t) async {
    // Sheet content sits under a route, not under the app's own Material, so a
    // Text without a DefaultTextStyle ancestor renders Flutter's debug
    // fallback. Every row must resolve a real style.
    await t.pumpWidget(host([app('apple'), app('google')]));
    await tapOpen(t);

    final texts = t.widgetList<Text>(find.byType(Text));
    for (final text in texts) {
      final style = text.style;
      if (style == null) continue;
      expect(
        style.decoration,
        isNot(TextDecoration.underline),
        reason: 'row text fell back to Flutter debug styling',
      );
    }
  });
}
