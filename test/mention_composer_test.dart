import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/mention_session.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/widgets/mention_picker.dart';
import 'package:monkeyhub/widgets/mention_text_controller.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The @-picker, driven through a real composer.
///
/// Both composers are covered, for the reason `chat_composer_test.dart` already
/// gives: which one is built is a call-site decision keyed off the user's chat
/// style, so a change reaching only one of them ships broken for half the users.
///
/// The load-bearing test here is "Enter still sends with the picker closed".
/// `MentionKeyboardNav` sits inside `SubmitOnEnter` and both want the return
/// key; get that nesting backwards and Enter sends the message instead of
/// taking the highlighted name, which is the kind of break that looks fine in a
/// screenshot.
void main() {
  // `SubmitOnEnter` is gated on `isPhysicalKeyboardPlatform`, which reads
  // `defaultTargetPlatform` — under `flutter test` that is Android, where the
  // return key is the only way to type a newline and Enter-to-send is
  // deliberately off. Pretend to be a desktop so the key path under test
  // actually exists.
  //
  // Set and cleared inside the body rather than in setUp/tearDown: the test
  // binding asserts every foundation debug variable is unset when the body
  // returns, which is earlier than tearDown runs.
  void testDesktop(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  ChatUser user(String id, String username, {String name = '', String? role}) =>
      ChatUser(id: id, username: username, name: name, role: role);

  final roster = [
    user('u1', 'murat', name: 'Murat Koc', role: 'owner'),
    user('u2', 'maria', name: 'Maria Lopez'),
    user('u3', 'zed', name: 'Zed Zephyr'),
  ];

  /// A composer plus its picker, wired the way the room screen wires them.
  Widget host({
    required MentionTextController controller,
    required MentionSession session,
    required bool classic,
    required VoidCallback onSend,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: session,
              builder: (_, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.isOpen) MentionPicker(session: session),
                  if (classic)
                    ChatComposerClassic(
                      controller: controller,
                      ephemeral: false,
                      onSend: onSend,
                      mention: session,
                    )
                  else
                    ChatComposerLiquid(
                      controller: controller,
                      ephemeral: false,
                      onSend: onSend,
                      mention: session,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final classic in [true, false]) {
    final label = classic ? 'classic' : 'liquid';
    group(label, () {
      late MentionTextController controller;
      late MentionSession session;
      var sends = 0;

      Future<void> pump(WidgetTester tester) async {
        sends = 0;
        controller = MentionTextController();
        session = MentionSession(
          controller: controller,
          roster: () => roster,
          selfUserId: 'me',
          allowEveryone: () => true,
        );
        await tester.pumpWidget(
          host(
            controller: controller,
            session: session,
            classic: classic,
            onSend: () => sends++,
          ),
        );
        await tester.pumpAndSettle();
      }

      /// Types into the field the way a keyboard would, so the controller's
      /// listener — which is what drives the picker — actually runs.
      Future<void> type(WidgetTester tester, String text) async {
        await tester.tap(find.byType(TextField));
        await tester.pump();
        tester.testTextInput.enterText(text);
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
        await tester.pumpAndSettle();
      }

      testDesktop('an @ opens the list with every member on it', (
        tester,
      ) async {
        await pump(tester);
        await type(tester, '@');

        expect(find.byType(MentionPicker), findsOneWidget);
        expect(find.text('Murat Koc'), findsOneWidget);
        expect(find.text('Maria Lopez'), findsOneWidget);
        expect(find.text('Zed Zephyr'), findsOneWidget);
        // The room's owner sorts first and says so.
        expect(find.text('OWNER'), findsOneWidget);
      });

      testDesktop('typing narrows it', (tester) async {
        await pump(tester);
        await type(tester, '@mar');

        expect(find.text('Maria Lopez'), findsOneWidget);
        expect(find.text('Zed Zephyr'), findsNothing);
      });

      testDesktop('a query nobody matches closes it', (tester) async {
        await pump(tester);
        await type(tester, '@qqqq');
        expect(find.byType(MentionPicker), findsNothing);
      });

      testDesktop('tapping a row inserts the handle and closes the list', (
        tester,
      ) async {
        await pump(tester);
        await type(tester, '@mar');
        await tester.tap(find.text('Maria Lopez'));
        await tester.pumpAndSettle();

        expect(controller.text, '@maria ');
        expect(controller.mentions.single.userId, 'u2');
        // Accepting must not leave the list up — "@maria " still reads as a
        // search for "maria" and would otherwise spring straight back open.
        expect(find.byType(MentionPicker), findsNothing);
      });

      testDesktop('an email address does not open it', (tester) async {
        await pump(tester);
        await type(tester, 'write to bob@mar');
        expect(find.byType(MentionPicker), findsNothing);
      });

      testDesktop('@everyone is offered and commits', (tester) async {
        await pump(tester);
        await type(tester, '@every');
        expect(find.text('Everyone'), findsOneWidget);

        await tester.tap(find.text('Everyone'));
        await tester.pumpAndSettle();
        expect(controller.text, '@everyone ');
        expect(controller.everyone, isTrue);
        expect(controller.mentions, isEmpty);
      });

      testDesktop('editing a committed handle drops the mention', (
        tester,
      ) async {
        await pump(tester);
        await type(tester, '@mar');
        await tester.tap(find.text('Maria Lopez'));
        await tester.pumpAndSettle();
        expect(controller.mentions, hasLength(1));

        // No longer that person's handle, so no longer that person's mention.
        controller.text = '@mari ';
        await tester.pumpAndSettle();
        expect(controller.mentions, isEmpty);
      });

      testDesktop('arrow keys move the selection and Enter takes it', (
        tester,
      ) async {
        await pump(tester);
        await type(tester, '@m');
        // Owner first, so row 0 is Murat; one step down is Maria.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(controller.text, '@maria ');
        // The Enter that picked a name must NOT also have sent the message.
        expect(sends, 0);
      });

      testDesktop('Escape closes it without touching the text', (tester) async {
        await pump(tester);
        await type(tester, '@mar');
        expect(find.byType(MentionPicker), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();

        expect(find.byType(MentionPicker), findsNothing);
        expect(controller.text, '@mar');
        // And it stays shut for this @ rather than reopening on the next frame.
        await tester.pumpAndSettle();
        expect(find.byType(MentionPicker), findsNothing);
      });

      testDesktop('the list opens flat under touch, and only shows an armed '
          'row once a key is pressed', (tester) async {
        await pump(tester);
        // Force the touch reading a phone would have: the soft keyboard's
        // input never flips the highlight mode, because it does not travel as
        // key events.
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTouch;
        await type(tester, '@m');

        Iterable<Color?> rowFills() => tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(MentionPicker),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.color);

        // Nothing is filled — the top entry must not read as already chosen.
        expect(rowFills().where((c) => c != null), isEmpty);

        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Now exactly one row carries the armed fill.
        expect(rowFills().where((c) => c != null), hasLength(1));

        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      });

      testDesktop('with the picker closed, Enter still sends', (tester) async {
        await pump(tester);
        await type(tester, 'hello');
        expect(find.byType(MentionPicker), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(sends, 1);
      });

      testDesktop('a composer with no session behaves exactly as before', (
        tester,
      ) async {
        var taps = 0;
        final plain = TextEditingController();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ThemeScope(
              controller: ThemeController(BasicTheme.midnight()),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: classic
                      ? ChatComposerClassic(
                          controller: plain,
                          ephemeral: false,
                          onSend: () => taps++,
                        )
                      : ChatComposerLiquid(
                          controller: plain,
                          ephemeral: false,
                          onSend: () => taps++,
                        ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(TextField));
        await tester.pump();
        tester.testTextInput.enterText('@murat');
        await tester.pumpAndSettle();

        expect(find.byType(MentionPicker), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    });
  }
}
