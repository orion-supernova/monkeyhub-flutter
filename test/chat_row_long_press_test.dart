import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/interaction.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_row_action_menu.dart';

/// The *beat* a chat-list row answers on, as opposed to what its menu then
/// offers.
///
/// A chat row and a message bubble are the same gesture on two kinds of row, so
/// they hold for the same length of time and buzz the same way. The row used to
/// sit on the platform default (500ms, silent) while the bubble had been tuned
/// to 400ms with a medium impact, and the difference was felt as the list being
/// stickier and deader than the transcript. These tests pin the row to
/// [kActionMenuLongPress] from both sides — it must not open a frame early
/// either, or the constant stops meaning anything and an ordinary tap starts
/// tripping the menu.
///
/// Two rules for anything added here:
///
///  * **Never `pumpAndSettle` with the finger still down.** The menu animates
///    in under a live pointer, and a future hold that keeps a ticker alive
///    would turn that into a ten-minute timeout rather than a failure. Use
///    [frames] while a gesture is live.
///  * **Never spend wall clock to see the menu.** A bare `pump()` builds the
///    frame the freshly-inserted overlay entry needs without advancing the
///    fake clock a millisecond — and an assertion that pumps a *generous*
///    amount of time to find the menu would pass just as happily against the
///    untouched 500ms default this change exists to get off.
void main() {
  final l10n = AppLocalizationsEn();

  /// Advance the menu's entrance by [count] frames of real time. Only ever
  /// after the assertion that cares when it opened.
  Future<void> frames(WidgetTester tester, [int count = 20]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<List<String>> pumpRow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // HapticFeedback goes out over the platform channel as a `vibrate` call
    // carrying its impact weight, so this is the only place the buzz is
    // observable from a widget test.
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final anchorKey = GlobalKey();
    // A bare box stands in for RoomCard/RoomGridTile: what is under test is the
    // recognizer around the row, and the real cards need a repository, an api
    // and a room apiece to say the same thing.
    Widget row(BuildContext context) => const SizedBox(
      height: 72,
      width: 360,
      child: ColoredBox(color: Color(0xFF202020)),
    );

    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ChatRowLongPress(
                key: anchorKey,
                onLongPress: () => showChatRowActionMenu(
                  context: anchorKey.currentContext!,
                  anchorKey: anchorKey,
                  previewBuilder: row,
                  isPinned: false,
                  isArchived: false,
                  // This file is about the HOLD, not the menu's contents —
                  // an unmuted, mutable room is simply the case that offers
                  // the most rows, and the finder below keys off PIN CHAT
                  // either way.
                  isMuted: false,
                  canMute: true,
                  // This file never taps the preview — see the dedicated
                  // test below for that.
                  onOpenRoom: () {},
                ),
                child: Builder(builder: row),
              ),
            ),
          ),
        ),
      ),
    );
    return haptics;
  }

  // Finders re-run on every use, so one is enough for the whole file.
  final menu = find.text(l10n.chatRowActionMenuPinLabel);

  testWidgets('the menu is still shut a frame short of the shared hold', (
    tester,
  ) async {
    final haptics = await pumpRow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ChatRowLongPress)),
    );
    await tester.pump(kActionMenuLongPress - const Duration(milliseconds: 16));
    await tester.pump();

    expect(
      menu,
      findsNothing,
      reason:
          'a hold shorter than kActionMenuLongPress is not a long press — if '
          'this fires, the row is opening its menu out from under taps',
    );
    expect(haptics, isEmpty, reason: 'and it has not buzzed yet either');

    await gesture.up();
    await tester.pump();
  });

  testWidgets('one frame past it, the menu is open and the finger has been '
      'told', (tester) async {
    final haptics = await pumpRow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ChatRowLongPress)),
    );
    await tester.pump(kActionMenuLongPress + const Duration(milliseconds: 16));
    await tester.pump();

    expect(menu, findsOneWidget);
    expect(
      haptics,
      ['HapticFeedbackType.mediumImpact'],
      reason:
          'the same weight the bubble fires, and on the trigger rather than '
          'once the overlay has finished animating in — the buzz is what tells '
          'a finger the hold took',
    );

    await gesture.up();
    await frames(tester, 4);
  });

  testWidgets('the platform default would be too late for it', (tester) async {
    // Guards the change itself rather than its constant: were someone to drop
    // ChatRowLongPress and go back to a plain GestureDetector, the two tests
    // above would still pass against a redefined kActionMenuLongPress. This
    // one is written against Flutter's own 500ms, so it only passes while the
    // row is genuinely quicker than the platform.
    await pumpRow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ChatRowLongPress)),
    );
    await tester.pump(kLongPressTimeout - const Duration(milliseconds: 16));
    await tester.pump();

    expect(
      menu,
      findsOneWidget,
      reason: "open before Flutter's untouched 500ms would have fired",
    );
    expect(
      kActionMenuLongPress,
      lessThan(kLongPressTimeout),
      reason: 'which is the whole point of naming the constant',
    );

    await gesture.up();
    await frames(tester, 4);
  });

  testWidgets('tapping the lifted preview opens the room, not a menu row', (
    tester,
  ) async {
    // Deliberately not `pumpRow`: this test needs the menu's own returned
    // Future, which that helper doesn't expose, and duplicating the small
    // setup here keeps the three timing-sensitive tests above untouched.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final anchorKey = GlobalKey();
    Widget row(BuildContext context) => const SizedBox(
      height: 72,
      width: 360,
      child: ColoredBox(color: Color(0xFF202020)),
    );

    Future<ChatRowAction?>? result;
    var openedRoom = false;
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ChatRowLongPress(
                key: anchorKey,
                onLongPress: () {
                  result = showChatRowActionMenu(
                    context: anchorKey.currentContext!,
                    anchorKey: anchorKey,
                    previewBuilder: row,
                    isPinned: false,
                    isArchived: false,
                    isMuted: false,
                    canMute: true,
                    onOpenRoom: () => openedRoom = true,
                  );
                },
                child: Builder(builder: row),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ChatRowLongPress)),
    );
    await tester.pump(kActionMenuLongPress + const Duration(milliseconds: 16));
    await tester.pump();
    await gesture.up();
    await frames(tester);

    expect(menu, findsOneWidget, reason: 'the menu should be open by now');

    // The overlay paints above everything in the root Overlay, so a tap at
    // the row's own on-screen rect lands on the LIFTED copy sitting on top
    // of it — same as a reader tapping what they see, not the row
    // underneath it. That copy is a sibling widget tree, not a descendant of
    // the `ChatRowLongPress` this coordinate is taken from, which is exactly
    // why the hit isn't found "on" that finder — silencing rather than fixing
    // is correct here.
    await tester.tap(find.byType(ChatRowLongPress), warnIfMissed: false);
    // pumpAndSettle rather than frames() here: no pointer is held down (the
    // tap already released) and the flight's own two controllers are
    // finite — nothing here can spin forever the way a live gesture could.
    await tester.pumpAndSettle();

    expect(
      openedRoom,
      isTrue,
      reason:
          'onOpenRoom fires directly from the flight, not through the '
          'resolved action below',
    );
    expect(
      await result,
      ChatRowAction.open,
      reason:
          'tapping the preview should open the room, the same shortcut a '
          'plain tap on the row already gives',
    );
  });
}
