import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/pull_reveal_panel.dart';
import 'package:monkeyhub/widgets/search_field.dart';

/// How much room the pull-down reveal takes.
///
/// The panel used to be clipped against a fixed 190pt upper bound, so it was
/// 190pt tall whether or not it had an Archived Chats row to show — an account
/// with nothing archived got a band of dead space under the search field. It
/// now reveals a fraction of its own natural height instead, which is what
/// these tests hold onto: the panel is exactly as tall as what's in it, and it
/// grows only when the archived row actually appears.
const firstRow = Key('first-chat-row');

void main() {
  /// The panel's own bottom inset — the only gap that belongs under the last
  /// thing in it, and what separates the search field from the filter row
  /// beneath it (`_PullRevealPanel`'s EdgeInsets.fromLTRB(20, 4, 20, 18)).
  const bottomPadding = 18.0;

  Widget host({required int archivedCount, required bool open}) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      // In a ListView, exactly where the real one lives: the slot is laid out
      // with an unbounded main axis there, which is the constraint a
      // measured-height panel has to survive and a fixed-height one never met.
      child: Scaffold(
        body: ListView(
          children: [
            PullRevealSlot(
              dragExtent: 0,
              dragThreshold: 64,
              dragging: false,
              open: open,
              searchCtrl: TextEditingController(),
              onSearchChanged: (_) {},
              onClearSearch: () {},
              archivedCount: archivedCount,
              onOpenArchived: () {},
              onCollapse: () {},
            ),
            // Stands in for the first chat row. How far down the list this
            // starts IS the space the panel takes — and it's the only way to
            // read that in the closed case, where the zero-extent slot is
            // culled by the sliver before a finder can measure it.
            const SizedBox(key: firstRow, height: 20),
          ],
        ),
      ),
    ),
  );

  testWidgets('nothing archived: the panel ends right under the search field', (
    tester,
  ) async {
    await tester.pumpWidget(host(archivedCount: 0, open: true));
    await tester.pumpAndSettle();

    final slot = tester.getRect(find.byType(PullRevealSlot));
    final search = tester.getRect(find.byType(SearchField));
    expect(slot.bottom - search.bottom, closeTo(bottomPadding, 0.5));
  });

  testWidgets('an archived folder row is what makes the panel taller', (
    tester,
  ) async {
    await tester.pumpWidget(host(archivedCount: 0, open: true));
    await tester.pumpAndSettle();
    final withoutRow = tester.getSize(find.byType(PullRevealSlot)).height;

    await tester.pumpWidget(host(archivedCount: 3, open: true));
    await tester.pumpAndSettle();
    final withRow = tester.getSize(find.byType(PullRevealSlot)).height;

    expect(withRow, greaterThan(withoutRow));
    // And the row it grew for is actually inside the revealed area, not
    // hanging past the clip.
    final slot = tester.getRect(find.byType(PullRevealSlot));
    final archivedRow = tester.getRect(find.textContaining('3'));
    expect(archivedRow.bottom, lessThanOrEqualTo(slot.bottom));
  });

  testWidgets('closed and not being dragged, it takes no space at all', (
    tester,
  ) async {
    await tester.pumpWidget(host(archivedCount: 3, open: false));
    await tester.pumpAndSettle();

    final list = tester.getRect(find.byType(ListView));
    expect(tester.getRect(find.byKey(firstRow)).top, list.top);
  });
}
