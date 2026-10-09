import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/composer_keys.dart';
import 'package:monkeyhub/widgets/mention_text_controller.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_context_menu.dart';
import 'package:monkeyhub/widgets/message_hover_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The pointer and keyboard half of the transcript: the right-click menu, the
/// hover strip, drag-select, and the composer's own keys. Everything here runs
/// with the platform overridden to macOS, because every one of these is gated
/// to a physical-keyboard / pointer platform and inert on a phone.
void main() {
  final api = ChatApi(ConvexBackend.instance);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A test on a Mac. The variant restores the platform afterwards, which a
  /// bare assignment to the override would not.
  void desk(String name, WidgetTesterCallback body) => testWidgets(
        name,
        body,
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );

  ChatMessage msg(
    String id,
    String text, {
    List<FormattingEntity>? formatting,
  }) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: 'ana',
        senderName: 'ana',
        content: text,
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.text,
        status: MessageStatus.sent,
        formatting: formatting,
      );

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  final caps = MessageCapabilities.none.copyWith(
    canReply: true,
    canEdit: true,
    canCopy: true,
    canDelete: true,
    canViewReceipts: true,
  );

  group('pointer menu', () {
    Future<Future<MessageActionResult?>> open(WidgetTester tester) async {
      await tester.pumpWidget(host(const SizedBox(width: 600, height: 500)));
      final ctx = tester.element(find.byType(Scaffold));
      final result = showMessageContextMenu(
        context: ctx,
        position: const Offset(100, 80),
        capabilities: caps,
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      return result;
    }

    Future<void> close(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('opens at the pointer with the shared rows, INFO included',
        (tester) async {
      await open(tester);
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      // Down and to the right of the click.
      final menu = tester.getTopLeft(find
          .ancestor(of: find.text('Reply'), matching: find.byType(Positioned))
          .first);
      expect(menu.dx, closeTo(101, 0.5));
      expect(menu.dy, closeTo(81, 0.5));
    });

    testWidgets('arrow keys and Enter choose a row', (tester) async {
      final result = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await close(tester);
      expect((await result)?.action, MessageAction.edit);
    });

    testWidgets('typing a letter moves to the row it starts', (tester) async {
      final result = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await close(tester);
      expect((await result)?.action, MessageAction.info);
    });

    testWidgets('Esc and a click outside both close with nothing',
        (tester) async {
      var result = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await close(tester);
      expect(await result, isNull);

      result = await open(tester);
      await tester.tapAt(const Offset(560, 460));
      await close(tester);
      expect(await result, isNull);
    });

    testWidgets('an emoji resolves as a reaction', (tester) async {
      final result = await open(tester);
      await tester.tap(find.text('🔥'));
      await close(tester);
      expect((await result)?.emoji, '🔥');
    });
  });

  testWidgets('INFO sits after SELECT and only when receipts are offered',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    List<MessageAction> rows(bool receipts) => messageActionSpecs(
          l10n: l10n,
          capabilities: MessageCapabilities.none.copyWith(
            canSelect: true,
            canDelete: true,
            canViewReceipts: receipts,
          ),
          isPinned: false,
          isSaved: false,
          isTranslated: false,
          hasFileName: false,
        ).map((s) => s.action).toList();
    expect(rows(false), [MessageAction.select, MessageAction.delete]);
    expect(rows(true),
        [MessageAction.select, MessageAction.info, MessageAction.delete]);
  });

  group('bubble pointer input on macOS', () {
    Widget bubble(
      ChatMessage m, {
      VoidCallback? onLongPress,
      VoidCallback? onDoubleTap,
      void Function(Offset)? onContextMenu,
      MessageHoverTarget? hover,
    }) =>
        SizedBox(
          width: 500,
          child: MessageBubble(
            message: m,
            now: DateTime(2026, 3, 1, 12),
            currentUserId: 'me',
            api: api,
            showAvatarSlot: false,
            onLongPress: onLongPress,
            onDoubleTap: onDoubleTap,
            onContextMenu: onContextMenu,
            hover: hover,
          ),
        );

    desk('right-click opens the pointer menu, not the long-press one',
        (tester) async {
      Offset? at;
      var longPresses = 0;
      await tester.pumpWidget(host(bubble(
        msg('a', 'hello there'),
        onLongPress: () => longPresses++,
        onContextMenu: (p) => at = p,
      )));
      final target = tester.getCenter(find.textContaining('hello there'));
      final g = await tester.startGesture(target,
          kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
      // Fires on the way down, as a native menu opens.
      expect(at, target);
      await g.up();
      await tester.pump(const Duration(seconds: 1));
      expect(longPresses, 0);
      // The selection area inside never got to select a word under it.
      expect(find.byType(SelectionArea), findsOneWidget);
    });

    desk('a mouse hold does not open the long-press menu',
        (tester) async {
      var longPresses = 0;
      await tester.pumpWidget(host(bubble(
        msg('a', 'hello there'),
        onLongPress: () => longPresses++,
      )));
      final g = await tester.startGesture(
          tester.getCenter(find.textContaining('hello there')),
          kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(seconds: 1));
      await g.up();
      expect(longPresses, 0);
    });

    desk('double-click is not the action menu on a keyboard platform',
        (tester) async {
      var doubles = 0;
      await tester.pumpWidget(host(bubble(
        msg('a', 'hello there'),
        onDoubleTap: () => doubles++,
      )));
      final at = tester.getCenter(find.textContaining('hello there'));
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(doubles, 0);
    });

    desk('text is selectable, spoilers never are, phones never are',
        (tester) async {
      await tester.pumpWidget(host(bubble(msg('a', 'plain words'))));
      expect(find.byType(SelectionArea), findsOneWidget);

      await tester.pumpWidget(host(bubble(msg('b', 'secret words',
          formatting: const [
            FormattingEntity(start: 0, end: 6, type: FormattingType.spoiler),
          ]))));
      expect(find.byType(SelectionArea), findsNothing);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(host(bubble(msg('c', 'plain words'))));
      expect(find.byType(SelectionArea), findsNothing);
    });

    test('a copied selection drops the stamp placeholder', () {
      expect(plainSelectionText('hello there￼'), 'hello there');
      expect(plainSelectionText('a￼b  '), 'ab');
    });

    desk('hover shows the strip after the dwell and hides on leave',
        (tester) async {
      final hover = MessageHoverController();
      addTearDown(hover.dispose);
      var builds = 0;
      await tester.pumpWidget(host(MessageHoverScope(
        controller: hover,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(builder: (context) {
              builds++;
              return bubble(
                msg('a', 'hello there'),
                hover: MessageHoverTarget(
                  id: 'a',
                  isMine: false,
                  onReply: () {},
                  onMore: (_) {},
                ),
              );
            }),
            const SizedBox(height: 200),
          ],
        ),
      )));
      final buildsBefore = builds;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(590, 590));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.textContaining('hello there')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(hover.shownId, isNull, reason: 'still inside the dwell');
      await tester.pump(const Duration(milliseconds: 100));
      expect(hover.shownId, 'a');
      await tester.pump();
      expect(find.byType(MessageHoverStrip), findsOneWidget);
      expect(builds, buildsBefore, reason: 'hovering must not rebuild a row');

      await mouse.moveTo(const Offset(590, 590));
      await tester.pump(const Duration(milliseconds: 300));
      expect(hover.shownId, isNull);
    });
  });

  group('composer keys on macOS', () {
    Future<MentionTextController> pump(
      WidgetTester tester, {
      bool Function()? onEditLast,
      String text = '',
    }) async {
      final c = MentionTextController(text: text);
      addTearDown(c.dispose);
      await tester.pumpWidget(host(SizedBox(
        width: 400,
        child: ComposerKeys(
          controller: c,
          onEditLast: onEditLast,
          child: TextField(controller: c, autofocus: true),
        ),
      )));
      await tester.pump();
      return c;
    }

    desk('↑ in an empty field edits the last message', (tester) async {
      var edits = 0;
      await pump(tester, onEditLast: () {
        edits++;
        return true;
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(edits, 1);
    });

    desk('↑ with a draft stays the caret\'s', (tester) async {
      var edits = 0;
      await pump(tester, text: 'draft', onEditLast: () {
        edits++;
        return true;
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      expect(edits, 0);
    });

    desk('⌘B bolds the selection', (tester) async {
      final c = await pump(tester, text: 'make this bold');
      c.selection = const TextSelection(baseOffset: 10, extentOffset: 14);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(c.selectionHas(FormattingType.bold, c.selection), isTrue);
      expect(c.text, 'make this bold');
    });

    desk('⌘V that the clipboard declines pastes text as before',
        (tester) async {
      final asked = Completer<void>();
      final c = MentionTextController();
      addTearDown(c.dispose);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': 'pasted'};
          }
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(host(SizedBox(
        width: 400,
        child: ComposerKeys(
          controller: c,
          onPasteMedia: () async {
            asked.complete();
            return false;
          },
          child: TextField(controller: c, autofocus: true),
        ),
      )));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      await tester.pump();
      expect(asked.isCompleted, isTrue);
      expect(c.text, 'pasted');
    });
  });
}
