import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/composer_format_toolbar.dart';
import 'package:monkeyhub/widgets/mention_text_controller.dart';

/// Where FORMAT sits in the composer's selection toolbar, and whether it is
/// there at all.
///
/// Position is the whole point of the item: both the Cupertino and Material
/// toolbars paginate their overflow, and with a live selection the native
/// items alone (Cut/Copy/Paste/Select All, plus Look Up / Search Web / Share
/// on iOS) already fill a phone-width bar. A trailing FORMAT is the first
/// thing pushed behind the chevron, which buries the feature it exists to
/// surface — so index 0 is asserted, not just membership.
///
/// Asserted structurally against `buttonItems` rather than by hit-testing
/// rendered buttons: which native items exist varies by platform and by
/// clipboard state, and none of that should be able to fail this test.
void main() {
  late MentionTextController controller;

  setUp(() => controller = MentionTextController(text: 'format this text'));
  tearDown(() => controller.dispose());

  /// ThemeScope goes ABOVE MaterialApp, mirroring `app.dart:922`, and that
  /// placement is load-bearing rather than incidental: the selection toolbar
  /// is an entry in the Navigator's root Overlay, so a ThemeScope mounted
  /// inside `home:` is *below* it and the chip row's `ThemeScope.of` throws.
  Widget host() => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextField(
              controller: controller,
              contextMenuBuilder: buildComposerContextMenu,
            ),
          ),
        ),
      );

  /// Focuses the field, applies [selection], and raises the toolbar.
  Future<void> showToolbar(WidgetTester tester, TextSelection selection) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byType(TextField));
    await tester.pump();
    controller.selection = selection;
    await tester.pump();
    tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
    // Two pumps: one to mount the toolbar route, one for _ComposerContextMenu
    // to build its first frame.
    await tester.pump();
    await tester.pump();
  }

  List<ContextMenuButtonItem> items(WidgetTester tester) =>
      tester
          .widget<AdaptiveTextSelectionToolbar>(
            find.byType(AdaptiveTextSelectionToolbar),
          )
          .buttonItems ??
      const [];

  testWidgets('Format is the first item when text is selected',
      (tester) async {
    await showToolbar(
      tester,
      const TextSelection(baseOffset: 0, extentOffset: 6),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final labels = [for (final i in items(tester)) i.label];

    expect(labels, isNotEmpty);
    expect(
      labels.first,
      l10n.formatToolbarFormatLabel,
      reason: 'FORMAT must lead the bar — any later position can be '
          'paginated behind the toolbar overflow on a narrow phone. Got '
          '$labels',
    );
  });

  testWidgets('a collapsed selection offers no Format item', (tester) async {
    await showToolbar(tester, const TextSelection.collapsed(offset: 3));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      [for (final i in items(tester)) i.label],
      isNot(contains(l10n.formatToolbarFormatLabel)),
      reason: 'formatting is selection-applied; there is nothing to format at '
          'a caret',
    );
  });

  testWidgets('tapping Format swaps the bar for the chip row', (tester) async {
    await showToolbar(
      tester,
      const TextSelection(baseOffset: 0, extentOffset: 6),
    );

    // Invoke through the item rather than by tapping a rendered button, for
    // the same platform-independence reason the assertions above use.
    items(tester).first.onPressed!();
    await tester.pump();

    expect(
      tester
          .widget<AdaptiveTextSelectionToolbar>(
            find.byType(AdaptiveTextSelectionToolbar),
          )
          .buttonItems,
      isNull,
      reason: 'the chip row is `children:`, not `buttonItems:`',
    );
    // Bold/Italic/Strikethrough/Underline draw themselves; the three icon
    // chips are the cheapest structural proof the row mounted.
    expect(find.text('B'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('U'), findsOneWidget);
  });
}
