import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/bulk_action_bar.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The transcript's multi-select, from both ends.
///
/// The bar half is the same `FocusableTap` + bare `GestureDetector` contract
/// `pinned_banner_tap_test.dart` guards: wrapping alone produces a button that
/// looks right and does nothing. It also pins the *disabled* case, which is the
/// one that matters here — FORWARD dims rather than disappears when the
/// selection is over `messages:forwardToRoom`'s cap, and a dimmed button that
/// still fires would send eleven messages into a call that refuses them.
///
/// The menu half pins that SELECT is the way in at all. It is offered on
/// messages that are not yours and cannot be forwarded, because the bar it
/// opens is what decides which of the two actions apply.
void main() {
  // ThemeScope ABOVE the app, not inside `home`: the action menu inserts its
  // overlay entry on the ROOT overlay, which is a sibling of `home` rather than
  // a descendant, and a scope nested any deeper is invisible from up there.
  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 500, child: child),
            ),
          ),
        ),
      );

  group('the selection bar', () {
    testWidgets('says how many are picked, and every button fires',
        (tester) async {
      var cancels = 0;
      var forwards = 0;
      var deletes = 0;
      await tester.pumpWidget(host(TranscriptSelectionBar(
        count: 3,
        onCancel: () => cancels++,
        onForward: () => forwards++,
        onDelete: () => deletes++,
        canForward: true,
        canDelete: true,
      )));

      expect(find.text('3 selected'), findsOneWidget);

      await tester.tap(find.text('Forward'));
      await tester.tap(find.text('Delete'));
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(forwards, 1);
      expect(deletes, 1);
      expect(cancels, 1);
    });

    testWidgets('a refused action is visible but inert', (tester) async {
      var forwards = 0;
      var deletes = 0;
      await tester.pumpWidget(host(TranscriptSelectionBar(
        count: 11,
        onCancel: () {},
        // Over the forward cap, and holding someone else's message.
        onForward: () => forwards++,
        onDelete: () => deletes++,
        canForward: false,
        canDelete: false,
      )));

      expect(find.text('Forward'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Forward'), warnIfMissed: false);
      await tester.tap(find.text('Delete'), warnIfMissed: false);
      await tester.pump();

      expect(forwards, 0);
      expect(deletes, 0);
    });

    testWidgets('deselecting the last message keeps the bar, inert',
        (tester) async {
      var forwards = 0;
      await tester.pumpWidget(host(TranscriptSelectionBar(
        count: 0,
        onCancel: () {},
        onForward: () => forwards++,
        onDelete: () {},
        // Both true: with nothing picked the bar must refuse anyway, or
        // clearing a selection to correct a mistake would leave live buttons
        // acting on an empty list.
        canForward: true,
        canDelete: true,
      )));

      expect(find.text('Select messages'), findsOneWidget);
      await tester.tap(find.text('Forward'), warnIfMissed: false);
      await tester.pump();
      expect(forwards, 0);
    });
  });

  group('the long-press menu', () {
    /// Pumps the menu anchored on a box, and hands back the future so a test
    /// can read what the user picked.
    Future<Future<MessageActionResult?>> open(
      WidgetTester tester, {
      required bool isMine,
      required bool canForward,
      required bool canSelect,
    }) async {
      final anchor = GlobalKey();
      late BuildContext ctx;
      await tester.pumpWidget(host(Builder(builder: (c) {
        ctx = c;
        return SizedBox(key: anchor, width: 200, height: 60);
      })));

      final result = showMessageActionMenu(
        context: ctx,
        anchorKey: anchor,
        bubbleBuilder: (_) => const SizedBox(width: 200, height: 60),
        isMine: isMine,
        capabilities: MessageCapabilities.none.copyWith(
          canReply: true,
          canForward: canForward,
          canCopy: true,
          canSelect: canSelect,
          canViewProfile: !isMine,
          canDelete: isMine,
          canReport: !isMine,
        ),
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('offers SELECT on a message that is not yours',
        (tester) async {
      final result = await open(
        tester,
        isMine: false,
        // A view-once photo, say: nothing to forward, still something to pick.
        canForward: false,
        canSelect: true,
      );

      expect(find.text('SELECT'), findsOneWidget);
      expect(find.text('FORWARD'), findsNothing);

      await tester.tap(find.text('SELECT'));
      await tester.pumpAndSettle();
      expect((await result)?.action, MessageAction.select);
    });

    testWidgets('offers FORWARD beside REPLY', (tester) async {
      final result = await open(
        tester,
        isMine: true,
        canForward: true,
        canSelect: true,
      );

      expect(find.text('FORWARD'), findsOneWidget);
      await tester.tap(find.text('FORWARD'));
      await tester.pumpAndSettle();
      expect((await result)?.action, MessageAction.forward);
    });

    testWidgets('neither row is offered when the caller opts out',
        (tester) async {
      final result = await open(
        tester,
        isMine: true,
        canForward: false,
        canSelect: false,
      );

      expect(find.text('FORWARD'), findsNothing);
      expect(find.text('SELECT'), findsNothing);

      // Resolved through a row that IS offered, so the overlay entry doesn't
      // outlive the test — and so the two absences above are read against a
      // menu that was genuinely built, not one that failed to open.
      await tester.tap(find.text('COPY'));
      await tester.pumpAndSettle();
      expect((await result)?.action, MessageAction.copy);
    });
  });
}
