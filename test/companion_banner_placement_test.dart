import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/companion_download_banner.dart';

/// Where the download strip lives, and what that costs it.
///
/// Both properties here are about its POSITION in the tree rather than its
/// appearance, and both have already been wrong in ways nothing caught:
///
///  * it is mounted by `MaterialApp.builder`, in a Stack whose other child is
///    the navigator — so the navigator is a SIBLING and `Navigator.of(context)`
///    from here throws. It did, on the first tap anyone gave it.
///  * it participates in LAYOUT rather than floating, so it must have real
///    height when it is showing and none at all when it is not.
void main() {
  /// Deliberately WITHOUT a Navigator, and without a MaterialApp to supply one.
  ///
  /// This is the shape of the tree the banner actually lives in, and building
  /// it any other way would test a situation the widget is never in — which is
  /// exactly how the Navigator crash survived a green suite.
  Widget host(Widget child) => Localizations(
    locale: const Locale('en'),
    delegates: AppLocalizations.localizationsDelegates,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 44),
        ),
        child: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: child,
        ),
      ),
    ),
  );

  /// The banner's real parent is a Column above an `Expanded` navigator, which
  /// hands it a LOOSE height constraint. Handed a tight one instead — as a bare
  /// root would — `Material` fills the screen and the height assertions below
  /// would be measuring the test, not the widget.
  Widget inColumn(Widget child) => host(
    Column(children: [child, const Expanded(child: SizedBox.expand())]),
  );

  testWidgets('builds and lays out with no Navigator anywhere above it', (
    tester,
  ) async {
    await tester.pumpWidget(host(const CompanionDownloadBanner()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(CompanionDownloadBanner), findsOneWidget);
  });

  /// It sits in a Column above an Expanded navigator, so any height it claims
  /// while idle is height every screen in the app loses permanently.
  testWidgets('takes no height while there is nothing to report', (
    tester,
  ) async {
    await tester.pumpWidget(inColumn(const CompanionDownloadBanner()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.getSize(find.byType(CompanionDownloadBanner)).height, 0);
  });

  /// The other half of the inset bargain. `app.dart` strips `padding.top` from
  /// everything below whenever this says it is showing, so a disagreement here
  /// insets the whole app twice or not at all.
  testWidgets('agrees with the height it actually takes', (tester) async {
    await tester.pumpWidget(inColumn(const CompanionDownloadBanner()));
    await tester.pump(const Duration(milliseconds: 400));

    final height = tester.getSize(find.byType(CompanionDownloadBanner)).height;
    expect(
      CompanionDownloadBanner.isShowing,
      height > 0,
      reason: 'isShowing is what app.dart removes padding.top on; it has to '
          'mean the same thing as "this bar is covering the status strip"',
    );
  });

  /// Hidden chrome that still ate taps would be a bug nobody could find: this
  /// spans the top of every screen in the app. Tapping where the strip WOULD be
  /// has to reach whatever is behind it.
  testWidgets('lets taps through to the app while idle', (tester) async {
    var behind = 0;
    await tester.pumpWidget(
      host(
        Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => behind++,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CompanionDownloadBanner(),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tapAt(const Offset(200, 10));
    await tester.pump();

    expect(behind, 1, reason: 'the idle strip must not swallow the tap');
  });
}
