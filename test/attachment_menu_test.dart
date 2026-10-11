@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/attachment_menu.dart';
import 'package:monkeyhub/widgets/glass_surface.dart';
import 'package:monkeyhub/widgets/ios_kit.dart' show SpringPress;

/// The "+" menu grows out of the button, over the composer, and its rows ride
/// the whole reveal without being rebuilt. That last one was a visible
/// flicker: the glass dropped its fade wrapper the frame the reveal landed,
/// which remounted every row, and they replayed their entrance from blank.
void main() {
  const anchor = Rect.fromLTWH(12, 780, 40, 40);

  Future<BuildContext> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold();
        }),
      ),
    ));
    return ctx;
  }

  Future<void> frames(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 20) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('rows survive the reveal', (tester) async {
    final ctx = await pump(tester);
    showAttachmentMenu(ctx, anchor: anchor);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final early = tester.element(find.byType(SpringPress).first);
    await frames(tester, 800);
    expect(identical(tester.element(find.byType(SpringPress).first), early),
        isTrue,
        reason: 'a row remounted mid-reveal replays its entrance: a flicker');
  });

  testWidgets('it opens over the button, corner on corner', (tester) async {
    final ctx = await pump(tester);
    showAttachmentMenu(ctx, anchor: anchor);
    await tester.pump();
    await frames(tester, 800);
    final menu = tester.getRect(find.byType(GlassSurface));
    expect(menu.left, anchor.left);
    expect(menu.bottom, anchor.bottom);
  });

  testWidgets('one Gallery row where the picker shows photos and videos',
      (tester) async {
    final ctx = await pump(tester);
    showAttachmentMenu(ctx, anchor: anchor, unifiedGallery: true);
    await tester.pump();
    await frames(tester, 800);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Photo'), findsNothing);
    expect(find.text('Video'), findsNothing);
  });

  testWidgets('Photo and Video stay apart by default', (tester) async {
    final ctx = await pump(tester);
    showAttachmentMenu(ctx, anchor: anchor);
    await tester.pump();
    await frames(tester, 800);
    expect(find.text('Gallery'), findsNothing);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Video'), findsOneWidget);
  });
}
