import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/keyboard/app_shortcuts.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/viewer_chrome.dart';

/// What this pins: **the gallery on a desk behaves like a desk's viewer.**
///
///  * A trackpad's two-finger sideways swipe at fit pages, as in Photos, and
///    pans once the picture is zoomed (the audit's worry was that the zoom
///    layer would claim the swipe and the pager would never move).
///  * ⌘/Ctrl+wheel zooms around the cursor; the plain wheel pages at fit.
///  * ⌘= / ⌘0 reach the page on screen.
///  * A mouse click on the black around the picture closes; on the picture
///    it does nothing.
///  * The edge chevrons arrive with the mouse, are missing at the ends of the
///    set, and page; the chrome leaves after the mouse has been still.
class _FakeApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

void main() {
  final api = _FakeApi();
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  ChatMessage photo(String id) => ChatMessage(
        id: id,
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'Ada',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.image,
        mediaStorageId: 'stor_$id',
        mediaWidth: 1200,
        mediaHeight: 900,
      );

  Widget host(Widget home) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  /// Opens a three-photo pager on [start] in a 1280x800 window. Returns the
  /// list of messages the reader has settled on, and the pop result.
  Future<(List<String>, Future<ChatMessage?>)> open(
    WidgetTester tester, {
    int start = 0,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    })));
    final seen = <String>[];
    final result = MediaPagerScreen.open(
      ctx,
      items: [photo('a'), photo('b'), photo('c')],
      initialIndex: start,
      api: api,
      onPageChanged: (m) => seen.add(m.id),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return (seen, result);
  }

  Future<void> trackpadSwipe(WidgetTester tester, Offset by) async {
    final pad = TestPointer(7, PointerDeviceKind.trackpad);
    const at = Offset(640, 400);
    await tester.sendEventToBinding(pad.panZoomStart(at));
    for (var i = 1; i <= 10; i++) {
      await tester.sendEventToBinding(pad.panZoomUpdate(at, pan: by * (i / 10)));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await tester.sendEventToBinding(pad.panZoomEnd());
    await tester.pumpAndSettle();
  }

  Future<void> wheel(WidgetTester tester, double dy, {Offset at = const Offset(640, 400)}) async {
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(at));
    await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
    await tester.pumpAndSettle();
  }

  testWidgets('a trackpad swipe at fit pages', (tester) async {
    final (seen, _) = await open(tester);
    await trackpadSwipe(tester, const Offset(-400, 0));
    expect(seen, ['b']);
  }, variant: mac);

  testWidgets('zoomed, a trackpad swipe pans and ⌘0 gives paging back',
      (tester) async {
    final (seen, _) = await open(tester);
    expect(AppShortcutRegistry.instance.invoke(AppShortcuts.zoomIn), isTrue);
    await tester.pumpAndSettle();
    await trackpadSwipe(tester, const Offset(-400, 0));
    expect(seen, isEmpty, reason: 'zoomed: the swipe moves inside the photo');
    expect(AppShortcutRegistry.instance.invoke(AppShortcuts.zoomFit), isTrue);
    await tester.pumpAndSettle();
    await trackpadSwipe(tester, const Offset(-400, 0));
    expect(seen, ['b']);
  }, variant: mac);

  testWidgets('⌘+wheel zooms, the plain wheel pages', (tester) async {
    final (seen, _) = await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await wheel(tester, -200);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    // Zoomed: the pager is locked, so the plain wheel pans and never pages.
    await wheel(tester, 40);
    expect(seen, isEmpty);
    expect(AppShortcutRegistry.instance.invoke(AppShortcuts.zoomFit), isTrue);
    await tester.pumpAndSettle();
    await wheel(tester, 40);
    expect(seen, ['b']);
  }, variant: mac);

  testWidgets('a click on the black closes, a click on the picture does not',
      (tester) async {
    final (_, result) = await open(tester);
    // The 4:3 picture is centred in 1280x800: about 1067 wide.
    await tester.tapAt(const Offset(640, 400), kind: PointerDeviceKind.mouse);
    // Past the double-click window, which the click waits out.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(MediaPagerScreen), findsOneWidget);
    await tester.tapAt(const Offset(40, 400), kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(MediaPagerScreen), findsNothing);
    expect((await result)?.id, 'a');
  }, variant: mac);

  testWidgets('chevrons come with the mouse, stop at the ends, and page',
      (tester) async {
    final (seen, _) = await open(tester);
    double opacityOf(IconData icon) => tester
        .widget<AnimatedOpacity>(find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(AnimatedOpacity),
        ).first)
        .opacity;
    expect(opacityOf(CupertinoIcons.chevron_right), 0,
        reason: 'no mouse yet');
    final mouse = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(600, 300)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opacityOf(CupertinoIcons.chevron_right), 1);
    expect(opacityOf(CupertinoIcons.chevron_left), 0, reason: 'first photo');
    await tester.tap(find.byIcon(CupertinoIcons.chevron_right),
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(seen, ['b']);
    // Still for 2.5s: the chrome and the chevrons leave.
    await tester.sendEventToBinding(mouse.hover(const Offset(600, 500)));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(opacityOf(CupertinoIcons.chevron_right), 0);
  }, variant: mac);

  testWidgets('save is top right with its shortcut in the hint',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    })));
    MediaPagerScreen.open(
      ctx,
      items: [photo('a')],
      initialIndex: 0,
      api: api,
      actions: MediaPagerActions(
        onShare: (_) async => true,
        onSave: (_) async => true,
      ),
    );
    await tester.pumpAndSettle();
    final save = find.byIcon(CupertinoIcons.arrow_down_to_line);
    expect(save, findsOneWidget);
    expect(tester.getCenter(save).dy, lessThan(100), reason: 'top bar');
    expect(
      find.byWidgetPredicate(
          (w) => w is ViewerChromeButton && w.tooltip == 'Save  ⌘S'),
      findsOneWidget,
    );
    expect(AppShortcutRegistry.instance.isBound(AppShortcuts.saveMedia), isTrue);
    expect(AppShortcutRegistry.instance.isBound(AppShortcuts.playPause), isFalse,
        reason: 'a photo has nothing to play');
  }, variant: mac);
}
