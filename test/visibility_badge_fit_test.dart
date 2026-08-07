import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/visibility_badge.dart';

/// The badge slot in a room grid tile is under 90px wide, and a translated
/// label doesn't care: Turkish "HERKESE AÇIK" alone measures ~90px and pushed
/// the pill 17px past its constraints. The pill has to survive that slot in
/// every language, and survive it without stranding a screen reader on a
/// wordless icon.
void main() {
  Widget host(double width, {Locale locale = const Locale('tr')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.centerLeft,
              child: VisibilityBadge(isPublic: true, dense: true),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a squeezed slot drops the label instead of overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(host(87));
    expect(tester.takeException(), isNull);

    expect(
      find.descendant(
        of: find.byType(VisibilityBadge),
        matching: find.byType(Text),
      ),
      findsNothing,
      reason: 'no label fits in 87px of Turkish, so only the icon should show',
    );
    expect(
      tester.getSize(find.byType(VisibilityBadge)).width,
      lessThanOrEqualTo(87),
    );
  });

  testWidgets('the dropped label is still announced', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(87));

    final loc = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(
      find.bySemanticsLabel(loc.enterPublicRoomVisibilityPublicLabel),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('a slot with room keeps the words', (tester) async {
    await tester.pumpWidget(host(300));
    expect(tester.takeException(), isNull);

    final loc = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(
      find.text(loc.enterPublicRoomVisibilityPublicLabel),
      findsOneWidget,
    );
  });

  testWidgets('an unbounded slot keeps the words too', (tester) async {
    // A Row/scroll parent hands the badge infinite width; measuring against
    // that must not read as "doesn't fit".
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: const [VisibilityBadge(isPublic: true, dense: true)],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final loc = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(loc.enterPublicRoomVisibilityPublicLabel), findsOneWidget);
  });
}
