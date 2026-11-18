import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/account_kit.dart';
import 'package:monkeyhub/widgets/hero_dock.dart';
import 'package:monkeyhub/widgets/hero_face.dart';

/// A docked hero piece is drawn in the page's overlay and moved into place.
/// It must take taps where it is drawn: the profile and room avatars (photo
/// sheet) and the editable name all live in these pieces. The move used to sit
/// inside an Opacity, whose hit box stayed at the page's top left, so every
/// tap on them fell through (2026-11-18).
void main() {
  testWidgets('the docked avatar takes a tap where it is drawn', (tester) async {
    var taps = 0;
    const key = Key('face');
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HeroPage(
            title: 'Someone',
            hero: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: HeroDockAvatar(
                  diameter: 100,
                  child: GestureDetector(
                    key: key,
                    onTap: () => taps++,
                    child: const ColoredBox(
                      color: Colors.red,
                      child: SizedBox.square(dimension: 100),
                    ),
                  ),
                ),
              ),
            ),
            children: const [SizedBox(height: 40)],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Drawn away from the page's top left, or this would pass by accident.
    final centre = tester.getCenter(find.byKey(key));
    expect(centre.dx, greaterThan(100));
    expect(centre.dy, greaterThan(100));

    await tester.tapAt(centre);
    await tester.pump(const Duration(milliseconds: 500));
    expect(taps, 1);
  });

  testWidgets('HeroFace: the circle and the camera badge both take taps',
      (tester) async {
    var circle = 0;
    var badge = 0;
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HeroPage(
            title: 'Me',
            hero: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: HeroFace(
                  face: const ColoredBox(
                    key: Key('face'),
                    color: Colors.red,
                    child: SizedBox.square(dimension: kHeroFaceSize),
                  ),
                  onTap: () => circle++,
                  onBadge: () => badge++,
                ),
              ),
            ),
            children: const [SizedBox(height: 40)],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tapAt(tester.getCenter(find.byKey(const Key('face'))));
    await tester.pump(const Duration(milliseconds: 500));
    expect(circle, 1);

    // The badge sits at the circle's bottom right.
    final rect = tester.getRect(find.byKey(const Key('face')));
    await tester.tapAt(rect.bottomRight - const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(badge, 1);
    expect(circle, 1);
  });
}
