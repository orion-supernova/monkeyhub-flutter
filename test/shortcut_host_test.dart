import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/keyboard/app_shortcuts.dart';
import 'package:monkeyhub/keyboard/escape_to_pop.dart';
import 'package:monkeyhub/keyboard/shortcut_host.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/shortcuts/command_palette.dart';

class _FakeRepo extends Fake implements ChatRepository {
  @override
  List<ChatRoom> get activeRooms => const [];
}

void main() {
  setUp(() => AppShortcutRegistry.instance.reset());
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  Widget app(GlobalKey<NavigatorState> nav, Widget home) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          navigatorKey: nav,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Same stack as the app's builder.
          builder: (_, child) => ShortcutHost(
            navigatorKey: nav,
            repo: _FakeRepo(),
            onOpenRoom: (_) {},
            child: EscapeToPop(navigatorKey: nav, child: child!),
          ),
          home: Scaffold(body: home),
        ),
      );

  Future<void> chord(WidgetTester t, LogicalKeyboardKey key, {bool shift = false}) async {
    await t.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(key);
    if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await t.pump();
  }

  testWidgets('a bound chord runs its handler', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    var hits = 0;
    await tester.pumpWidget(app(
      nav,
      ShortcutBindings(
        bindings: {AppShortcuts.jumpToLatest: () => hits++},
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ));
    await tester.pump();
    await chord(tester, LogicalKeyboardKey.keyJ);
    expect(hits, 1);
  }, variant: mac);

  testWidgets('the newest active binding wins, and a covered route is off', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final log = <String>[];
    await tester.pumpWidget(app(
      nav,
      ShortcutBindings(
        bindings: {AppShortcuts.search: () => log.add('list')},
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => ShortcutBindings(
        bindings: {AppShortcuts.searchInChat: () => log.add('room')},
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ));
    await tester.pumpAndSettle();
    await chord(tester, LogicalKeyboardKey.keyF);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    await chord(tester, LogicalKeyboardKey.keyF);
    expect(log, ['room', 'list']);
  }, variant: mac);

  testWidgets('a bare key never fires while typing', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    var plays = 0;
    final field = TextEditingController();
    await tester.pumpWidget(app(
      nav,
      ShortcutBindings(
        bindings: {AppShortcuts.playPause: () => plays++},
        child: TextField(controller: field, autofocus: true),
      ),
    ));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(plays, 0);
  }, variant: mac);

  testWidgets('holding ⌘ shows the peek, letting go hides it', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(
      nav,
      ShortcutBindings(
        bindings: {AppShortcuts.jumpToLatest: () {}},
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ));
    await tester.pump();
    final l10n = AppLocalizations.of(nav.currentContext!);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text(l10n.kbdJumpToLatest), findsOneWidget, reason: 'no wait');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text(l10n.kbdJumpToLatest), findsNothing);
  }, variant: mac);

  testWidgets('a chord pressed during the hold calls the peek off', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    var hits = 0;
    await tester.pumpWidget(app(
      nav,
      ShortcutBindings(
        bindings: {AppShortcuts.jumpToLatest: () => hits++},
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ));
    await tester.pump();
    final l10n = AppLocalizations.of(nav.currentContext!);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump(const Duration(seconds: 1));
    expect(hits, 1);
    expect(find.text(l10n.kbdJumpToLatest), findsNothing);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
  }, variant: mac);

  testWidgets('the peek still shows after ⌘W hid the window mid-chord', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(
      nav,
      ShortcutBindings(
        bindings: {AppShortcuts.jumpToLatest: () {}},
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ));
    await tester.pump();
    final l10n = AppLocalizations.of(nav.currentContext!);

    // ⌘W: the menu orders the window out between W's down and its up, so
    // W's up goes to no window. ⌘'s comes back as a modifier resync.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    // Back from the Dock.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(HardwareKeyboard.instance.logicalKeysPressed, contains(LogicalKeyboardKey.keyW),
        reason: 'the stale W this guards against');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text(l10n.kbdJumpToLatest), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.pumpAndSettle();
  }, variant: mac);

  testWidgets('the peek lists the window keys, and ⌘W gives way to a chat', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(
      nav,
      const Focus(autofocus: true, child: SizedBox.expand()),
    ));
    await tester.pump();
    final l10n = AppLocalizations.of(nav.currentContext!);

    Future<void> peek(void Function() check) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      check();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
    }

    await peek(() {
      expect(find.text(l10n.kbdGroupApp), findsOneWidget);
      expect(find.text(l10n.kbdQuit), findsOneWidget);
      expect(find.text(l10n.kbdHideApp), findsOneWidget);
      expect(find.text(l10n.kbdCloseWindow), findsOneWidget);
    });
    // ⌘Q is the Mac menu's to run, never this host's.
    expect(AppShortcutRegistry.instance.isBound(AppShortcuts.quit), isFalse);

    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => ShortcutBindings(
        bindings: {AppShortcuts.closeChat: () {}},
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      ),
    ));
    await tester.pumpAndSettle();
    await peek(() {
      expect(find.text(l10n.kbdCloseChat), findsOneWidget);
      expect(find.text(l10n.kbdCloseWindow), findsNothing);
      expect(find.text(l10n.kbdQuit), findsOneWidget);
    });
  }, variant: mac);

  testWidgets('Windows and Linux: Ctrl+Q is bound, Alt+F4 is listed', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(
      nav,
      const Focus(autofocus: true, child: SizedBox.expand()),
    ));
    await tester.pump();
    final reg = AppShortcutRegistry.instance;
    expect(reg.isBound(AppShortcuts.quit), isTrue);
    final listed = reg.available(ambientGroups: reg.liveGroups());
    expect(listed, containsAll([AppShortcuts.quit, AppShortcuts.closeWindowAltF4]));
    expect(listed, isNot(contains(AppShortcuts.closeWindow)));
    expect(listed, isNot(contains(AppShortcuts.hideApp)));
    expect(AppShortcuts.quit.chords.single.caps(), ['Ctrl', 'Q']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  test('phones and tablets list no window keys', () {
    for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = p;
      final reg = AppShortcutRegistry.instance;
      expect(
        reg.available(ambientGroups: reg.liveGroups()).where((d) => d.group == ShortcutGroup.app),
        isEmpty,
        reason: '$p',
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('⌘K opens the palette and Esc closes it', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(
      nav,
      const Focus(autofocus: true, child: SizedBox.expand()),
    ));
    await tester.pump();
    final l10n = AppLocalizations.of(nav.currentContext!);
    await chord(tester, LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.text(l10n.kbdPaletteHint), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text(l10n.kbdPaletteHint), findsNothing);
  }, variant: mac);

  test('a listed-only key gives way to a live binding on the same chord', () {
    final reg = AppShortcutRegistry.instance;
    final viewer = {ShortcutGroup.viewer};
    expect(reg.available(ambientGroups: viewer), contains(AppShortcuts.viewerPrevious));
    final t = reg.bind(AppShortcuts.seekBackward, () {}, () => true);
    final listed = reg.available(ambientGroups: viewer);
    expect(listed, contains(AppShortcuts.seekBackward));
    expect(listed, isNot(contains(AppShortcuts.viewerPrevious)));
    expect(listed, contains(AppShortcuts.viewerNext));
    reg.unbind(t);
  });

  test('palette ranking: prefix, then word start, then anywhere, then gaps', () {
    expect(paletteScore('Family', 'fam'), greaterThan(paletteScore('My Family', 'fam')!));
    expect(paletteScore('My Family', 'fam'), greaterThan(paletteScore('Infamy', 'fam')!));
    expect(paletteScore('Infamy', 'fam'), greaterThan(paletteScore('Fun at me', 'fam')!));
    expect(paletteScore('Şükrü', 'sukru'), isNotNull);
    expect(paletteScore('Family', 'xyz'), isNull);
  });
}
