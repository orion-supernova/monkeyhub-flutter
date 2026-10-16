import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/view_once_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/dust_dissolve.dart';
import 'package:monkeyhub/widgets/viewer_chrome.dart';

/// The view-once viewer's chrome behaves like the gallery's: a tap on the
/// picture hides it, another brings it back, it never sits on the picture
/// as a solid band, and the × still burns the photo.
void main() {
  Uint8List png() => Uint8List.fromList(
      img.encodePng(img.Image(width: 30, height: 60)));

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  double chromeOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find
          .ancestor(
            of: find.byType(ViewerTopBar),
            matching: find.byType(AnimatedOpacity),
          )
          .first)
      .opacity;

  bool chromeIgnored(WidgetTester tester) => tester
      .widget<IgnorePointer>(find
          .ancestor(
            of: find.byType(ViewerTopBar),
            matching: find.byType(IgnorePointer),
          )
          .first)
      .ignoring;

  Future<int Function()> open(WidgetTester tester) async {
    var burns = 0;
    await tester.pumpWidget(host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => ViewOnceViewer.open(
            context,
            bytes: png(),
            onBurn: () => burns++,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    return () => burns;
  }

  testWidgets('a tap hides the chrome and another brings it back', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(ViewOnceBadge), findsOneWidget);
    expect(chromeOpacity(tester), 1);
    expect(chromeIgnored(tester), isFalse);
    // A scrim over the picture, never the solid band.
    expect(tester.widget<ViewerTopBar>(find.byType(ViewerTopBar)).band,
        isFalse);

    await tester.tapAt(const Offset(400, 500));
    await pumpFor(tester, const Duration(milliseconds: 200));
    expect(chromeOpacity(tester), 0);
    expect(chromeIgnored(tester), isTrue);

    await tester.tapAt(const Offset(400, 500));
    await pumpFor(tester, const Duration(milliseconds: 200));
    expect(chromeOpacity(tester), 1);
    expect(chromeIgnored(tester), isFalse);
  });

  testWidgets('the × still burns the picture', (tester) async {
    final burns = await open(tester);
    await tester.tap(find.byType(ViewerChromeButton));
    await tester.pump();
    expect(burns(), 1);
    expect(
      tester.widget<DustDissolve>(find.byType(DustDissolve)).active,
      isTrue,
    );
    await pumpFor(
      tester,
      DustDissolve.defaultDuration + const Duration(milliseconds: 400),
    );
    expect(find.byType(ViewOnceViewer), findsNothing);
    expect(burns(), 1);
  });
}
