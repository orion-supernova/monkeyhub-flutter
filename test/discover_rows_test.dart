import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/discover_rows.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// Discover previews five of each list and sends the rest to a full-list
/// screen, so the header's count and the see-all row are the only things
/// telling you how much you haven't seen. Both have to be honest.
void main() {
  Widget host(Widget child, {double width = 375}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );

  group('section header', () {
    testWidgets('prints the total beside the label', (tester) async {
      await tester.pumpWidget(
        host(const DiscoverSectionHeader(label: 'PUBLIC ROOMS', count: '87')),
      );
      expect(find.text('PUBLIC ROOMS'), findsOneWidget);
      expect(find.text('87'), findsOneWidget);
    });

    testWidgets('shows no number at all while a fetch is in flight', (
      tester,
    ) async {
      // An empty count is how "still looking" is told apart from "looked,
      // found nothing" — a bare 0 during the first flight would be a lie.
      await tester.pumpWidget(
        host(const DiscoverSectionHeader(label: 'PUBLIC ROOMS', count: '')),
      );
      expect(find.text('PUBLIC ROOMS'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('see-all row', () {
    testWidgets('names the true total, not the preview length', (tester) async {
      await tester.pumpWidget(host(SeeAllRow(total: 87, onTap: () {})));
      expect(find.text('see all 87'), findsOneWidget);
    });

    testWidgets('is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        host(SeeAllRow(total: 24, onTap: () => tapped = true)),
      );
      await tester.tap(find.text('see all 24'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('fits the 360pt desktop column', (tester) async {
      await tester.pumpWidget(
        host(SeeAllRow(total: 1234, onTap: () {}), width: 360),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('an empty section is one quiet line', (tester) async {
    await tester.pumpWidget(host(const DiscoverEmptyLine('inbox quiet')));
    expect(find.text('inbox quiet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
