import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/gallery_tray.dart';

/// The camera's recents tray moves in ONE swipe each way.
///
/// It used to take two: the dim behind the sheet was inserted ahead of it the
/// moment the sheet rose off the strip, and the unkeyed Stack rebuilt the sheet
/// under the finger, killing the drag halfway. The spring settling back onto
/// the strip removed the dim again, so the next swipe died the same way.
///
/// No photo library in a test: the tray reads as denied, which still has the
/// grabber and the sheet, and those are what moves.
void main() {
  late List<bool> full;
  late List<GalleryTrayStop> settles;

  Future<GalleryTrayController> pump(WidgetTester tester) async {
    full = [];
    settles = [];
    final controller = GalleryTrayController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: GalleryTray(
              controller: controller,
              anchor: 160,
              onPick: (_) async {},
              onFullChanged: full.add,
              onSettle: settles.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Denied puts the strip away (and a stop is remembered across tests):
    // start every test from the strip.
    controller.collapse();
    await tester.pumpAndSettle();
    expect(settles.last, GalleryTrayStop.strip);
    return controller;
  }

  /// An unhurried drag, so it is the distance that decides, not a flick.
  Future<void> slowDrag(WidgetTester tester, Offset from, double dy) async {
    final gesture = await tester.startGesture(from);
    const steps = 30;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, dy / steps));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('one slow swipe up from the strip opens the full gallery', (
    tester,
  ) async {
    await pump(tester);
    final grabber = tester.getCenter(find.bySemanticsLabel('Recent photos'));
    await slowDrag(tester, grabber, -220);
    expect(settles.last, GalleryTrayStop.full);
    expect(full.last, isTrue);
  });

  testWidgets('one slow swipe down from full goes back to the strip', (
    tester,
  ) async {
    final controller = await pump(tester);
    controller.expand();
    await tester.pumpAndSettle();
    expect(full.last, isTrue);
    final grabber = tester.getCenter(find.bySemanticsLabel('Recent photos'));
    await slowDrag(tester, grabber, 220);
    expect(settles.last, GalleryTrayStop.strip);
    expect(full.last, isFalse);
  });

  testWidgets('a short nudge falls back to where it started', (tester) async {
    await pump(tester);
    final grabber = tester.getCenter(find.bySemanticsLabel('Recent photos'));
    await slowDrag(tester, grabber, -60);
    expect(settles.last, GalleryTrayStop.strip);
    expect(full, isNot(contains(true)));
  });

  testWidgets('a flick up opens it however short', (tester) async {
    await pump(tester);
    final grabber = tester.getCenter(find.bySemanticsLabel('Recent photos'));
    await tester.flingFrom(grabber, const Offset(0, -80), 900);
    await tester.pumpAndSettle();
    expect(settles.last, GalleryTrayStop.full);
  });
}
