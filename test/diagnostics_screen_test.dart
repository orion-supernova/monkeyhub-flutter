import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/diagnostics/diag_buffer.dart';
import 'package:monkeyhub/diagnostics/diag_event.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/diagnostics_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/l10n/text_case.dart';

/// The viewer's category row, as somebody reading a flooded log uses it.
///
/// The subtitle's `shown of total` is the assertion throughout: it counts exactly
/// the events the list is showing, whatever collapsing does to the rows.
void main() {
  final buf = DiagBuffer.instance;

  setUp(() {
    buf.resetForTest();
    void add(DiagCat cat, int n) {
      for (var i = 0; i < n; i++) {
        buf.add(cat: cat, sev: DiagSev.info, event: 'e', name: '${cat.name}$i');
      }
    }

    add(DiagCat.subscription, 5);
    add(DiagCat.frame, 2);
    add(DiagCat.api, 3);
    add(DiagCat.connection, 1);
  });

  Future<void> open(WidgetTester t) async {
    // Haptics are awaited by nothing here, but an unmocked platform channel
    // still logs; keep the run quiet and deterministic.
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(() => t.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await t.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiagnosticsScreen(),
      ),
    ));
    await t.pump();
  }

  /// Saves the hidden set. Through `runAsync`: the keychain write is a real
  /// platform-channel round trip, and awaited in the fake-async test zone its
  /// reply never arrives.
  Future<void> hide(WidgetTester t, Set<String> names) => t.runAsync(
        () => SettingsStore.instance.setDiagHiddenCategories(names),
      );

  /// A chip in the category row, never an event row that happens to carry
  /// the same word — the row is the only horizontal scroller on the screen.
  Finder chip(String label) => find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text(label),
      );

  /// Brings a chip into view first: the row scrolls sideways, and the test
  /// font's square glyphs make every label wider than the real face would.
  Future<Finder> visible(WidgetTester t, String label) async {
    final f = chip(label);
    await t.ensureVisible(f);
    await t.pump();
    return f;
  }

  /// The page subtitle's `shown of total` — it shares its line with the
  /// build string once that resolves, hence `textContaining`.
  Finder shown(String n) => find.textContaining('$n of 11 events');

  /// Delete all lives in the ⋯ menu, behind a confirm.
  Future<void> openDeleteConfirm(WidgetTester t) async {
    await t.tap(find.byIcon(CupertinoIcons.ellipsis));
    await t.pumpAndSettle();
    await t.tap(find.text('Delete all'));
    await t.pumpAndSettle();
  }

  /// Ends the test cleanly: toasts live for seconds, and the viewer's ticker
  /// runs until the screen is gone.
  Future<void> close(WidgetTester t) async {
    await t.pump(const Duration(seconds: 8));
    await t.pumpWidget(const SizedBox());
  }

  // Runs first, while this file's SettingsStore has never been told anything:
  // the out-of-the-box default is under test here.
  testWidgets('a first open leaves subscription and frame out of All',
      (t) async {
    await open(t);

    expect(shown('4'), findsOneWidget,
        reason: '3 api + 1 connection');

    await close(t);
  });

  testWidgets('tapping a hidden category shows exactly it', (t) async {
    await hide(t, {'subscription', 'frame'});
    await open(t);

    await t.tap(await visible(t, 'Slow frames'));
    await t.pump();
    expect(shown('2'), findsOneWidget);

    await t.tap(await visible(t, 'All'));
    await t.pump();
    expect(shown('4'), findsOneWidget);

    await close(t);
  });

  testWidgets('a long press puts a category back into All, and it sticks',
      (t) async {
    await hide(t, {'subscription', 'frame'});
    await open(t);

    await t.longPress(await visible(t, 'Slow frames'));
    await t.pump();

    expect(shown('6'), findsOneWidget);
    // The category by its screen name, never the enum's (`frame`).
    expect(find.text('Slow frames back in All'), findsOneWidget);
    expect(SettingsStore.instance.diagHiddenCategories, {'subscription'});

    // The next visit starts from the choice, not the default.
    await close(t);
    await open(t);
    expect(shown('6'), findsOneWidget);

    await close(t);
  });

  testWidgets("the toast's Undo takes a long press back", (t) async {
    await hide(t, {'subscription', 'frame'});
    await open(t);

    await t.longPress(await visible(t, 'Server calls'));
    await t.pump();
    expect(shown('1'), findsOneWidget);

    // The toast springs down from the top; let it land before tapping it.
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Undo'));
    await t.pump();
    expect(shown('4'), findsOneWidget);
    expect(SettingsStore.instance.diagHiddenCategories,
        {'subscription', 'frame'});

    await close(t);
  });

  testWidgets('delete all empties the log, after a confirm', (t) async {
    await open(t);

    await openDeleteConfirm(t);
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();

    expect(buf.length, 0);
    expect(find.text('Nothing captured yet'), findsOneWidget);

    await close(t);
  });

  testWidgets('backing out of the confirm keeps everything', (t) async {
    await open(t);

    await openDeleteConfirm(t);
    final l10n = AppLocalizations.of(t.element(find.text('Delete')));
    // The iOS action sheet sets its labels in sentence case.
    await t.tap(find.text(sentenceCase(l10n.destructiveSheetCancelButtonLabel)));
    await t.pumpAndSettle();

    expect(buf.length, 11);

    await close(t);
  });
}
