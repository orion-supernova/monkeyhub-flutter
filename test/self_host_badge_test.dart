import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/server_directory.dart';
import 'package:monkeyhub/backend/server_endpoint.dart';
import 'package:monkeyhub/backend/server_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/self_host_badge.dart';

/// The window every coordinate in this file is measured against.
const _surface = Size(390, 700);

/// A representative status-bar inset. The ribbon's placement is expressed
/// relative to it, so the assertions have to be too.
const _statusBar = 47.0;

/// The mark says which server this install is on, permanently, on every screen.
///
/// It used to be a BAR across the top that took its own height out of the
/// layout, and that height is what this file mostly exists to talk about. The
/// bar was fine on a chat list and wrong on every screen whose design is that
/// the content is the screen: 26pt plus a status inset off the viewport meant
/// a screenshot no longer fit the photo send-preview and was pillarboxed. It is
/// a corner ribbon now, and the properties worth pinning changed with it:
///
///  * it vanishes entirely on the ordinary deployment;
///  * it takes NO layout height — nothing below it moves, which is the whole
///    reason for the change;
///  * it clears the status-bar glyphs rather than hiding under them;
///  * it never prints the operator's address.
void main() {
  const selfHosted = ServerEndpoint(deploymentUrl: 'https://chat.example.com');
  final homeserver = KnownHosts.endpointFor(ServerRole.homeserver);
  final primary = KnownHosts.endpointFor(ServerRole.primary);

  /// The app's root arrangement in miniature: the ribbon over everything, and
  /// content that keeps the full height of the window.
  Widget scene() {
    final controller = ThemeController(ThemeController.byId('basic'));
    return MediaQuery(
      data: const MediaQueryData(
        size: _surface,
        padding: EdgeInsets.only(top: _statusBar),
      ),
      child: ThemeScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ServerMarkBanner(
              child: Scaffold(
                body: SafeArea(child: Container(key: const Key('content'))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Size the WINDOW, not just the MediaQuery, then pump.
  ///
  /// The assertions below are absolute coordinates. An earlier version of this
  /// file left the harness at its default 800x600 and was green for entirely
  /// the wrong reason.
  Future<void> mount(WidgetTester tester, Widget widget) async {
    await tester.binding.setSurfaceSize(_surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(widget);
  }

  Finder ribbon() => find.byType(Banner);

  /// What the ribbon actually says.
  ///
  /// Read off the widget rather than found in the tree: [Banner] paints its
  /// message with a `TextPainter` inside a `CustomPaint`, so there is no `Text`
  /// for `find.text` to match — which is also why nothing here can assert the
  /// absence of a string by searching for it.
  String? mark(WidgetTester tester) => ribbon().evaluate().isEmpty
      ? null
      : tester.widget<Banner>(ribbon()).message;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ServerStore.instance.resetForTest();
  });

  group('when to draw at all', () {
    testWidgets('draws nothing on the bundled deployment', (tester) async {
      await mount(tester, scene());
      expect(ribbon(), findsNothing);
      expect(ServerMarkBanner.isShowing, isFalse);
    });

    testWidgets('draws nothing when explicitly on the primary', (tester) async {
      ServerStore.instance.setForTest(primary);
      await mount(tester, scene());
      expect(ribbon(), findsNothing);
    });
  });

  group('it costs the app no height', () {
    testWidgets('content still starts at the status inset, not below a bar', (
      tester,
    ) async {
      // THE regression this whole change exists to fix. The bar used to sit
      // above everything and push the app down by its own height plus the
      // status inset; a screen whose design is "the content IS the screen" —
      // the photo send-preview, every fullscreen viewer — silently lost 73pt
      // of viewport and letterboxed anything shaped like the display.
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());

      expect(ribbon(), findsOneWidget, reason: 'the mark is up');
      expect(
        tester.getTopLeft(find.byKey(const Key('content'))).dy,
        _statusBar,
        reason: 'the SafeArea inset, and nothing more',
      );
    });

    testWidgets('and the marked app is laid out exactly like an unmarked one', (
      tester,
    ) async {
      await mount(tester, scene());
      final unmarked = tester.getRect(find.byKey(const Key('content')));

      ServerStore.instance.setForTest(homeserver);
      await tester.pump();

      expect(tester.getRect(find.byKey(const Key('content'))), unmarked);
    });
  });

  group('where it sits', () {
    testWidgets('in the top-RIGHT corner, out of a back button\'s way', (
      tester,
    ) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());

      final rect = tester.getRect(ribbon());
      expect(rect.right, moreOrLessEquals(_surface.width, epsilon: 0.5));
      expect(rect.top, moreOrLessEquals(0, epsilon: 0.5),
          reason: 'the corner of what it wraps, exactly like the debug banner');
    });

    testWidgets('lets taps through to whatever is under it', (tester) async {
      // It lands in the corner full-screen routes put a control in — the
      // editor's crop and rotate buttons, for two — so it must never eat a
      // tap. Flutter paints it as a FOREGROUND painter, which does not
      // hit-test, and this fails if that ever stops being true.
      ServerStore.instance.setForTest(homeserver);
      var tapped = false;
      await tester.binding.setSurfaceSize(_surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: _surface,
            padding: EdgeInsets.only(top: _statusBar),
          ),
          child: ThemeScope(
            controller: ThemeController(ThemeController.byId('basic')),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: ServerMarkBanner(
                child: Scaffold(
                  body: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => tapped = true,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Straight through the middle of the ribbon.
      await tester.tapAt(Offset(_surface.width - 20, 20));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('what it says', () {
    testWidgets("never prints the home server's address", (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());
      // The operator's deployment URL is infrastructure. It appearing on every
      // user's screen is the bug this asserts against, not a cosmetic detail.
      expect(mark(tester), 'HOME');
      expect(mark(tester), isNot(contains('walhallaa')));
    });

    testWidgets('names the role rather than the host, either way', (
      tester,
    ) async {
      // The bar had room for a hostname; a ribbon does not, and the Server
      // screen already shows it. This is the deliberate trade, pinned so a
      // future edit does not put an address back on a 95pt diagonal.
      ServerStore.instance.setForTest(selfHosted);
      await mount(tester, scene());
      expect(mark(tester), 'SELF');
      expect(mark(tester), isNot(contains('example.com')));
    });

    testWidgets("says self-hosted when the user typed the operator's address", (
      tester,
    ) async {
      // Same host as the home server, opposite meaning: this install was
      // pointed here by hand, so it is not the operator's arrangement.
      ServerStore.instance.setForTest(homeserver, pinned: true);
      await mount(tester, scene());
      expect(mark(tester), 'SELF');
    });

    testWidgets('the label is short enough for the ribbon', (tester) async {
      // Flutter lays the message out across `_kBottomOffset * 2` — about 97pt
      // — and does not ellipsise: a label that outgrows it does not truncate,
      // it spills off the ribbon.
      //
      // Asserted as a character count rather than a measured width on purpose.
      // Under flutter_test the font is a fixed-width fallback where every
      // glyph is a full em, so measuring here answers a question about the
      // test harness rather than about the shipped typeface. The count is the
      // bound the arb descriptions state, and it is the one a translator can
      // actually act on.
      for (final endpoint in [homeserver, selfHosted]) {
        ServerStore.instance.setForTest(endpoint);
        await mount(tester, scene());
        expect(mark(tester)!.length, lessThanOrEqualTo(8),
            reason: '"${mark(tester)}" will not fit on the diagonal');
      }
    });
  });

  group('keeping up with the store', () {
    testWidgets('appears without the parent being rebuilt', (tester) async {
      // The bug this exists for: the app mounts this high in the tree, where
      // rebuilds are rare, so a build method that read the store only when its
      // parent rebuilt stayed frozen at whatever it rendered first — two
      // relaunches to catch up, in practice. Nothing here rebuilds the tree;
      // only the store changes.
      await mount(tester, scene());
      expect(ribbon(), findsNothing);

      ServerStore.instance.setForTest(homeserver);
      await tester.pump();
      expect(mark(tester), 'HOME');
    });

    testWidgets('goes away the same way', (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());
      expect(ribbon(), findsOneWidget);

      ServerStore.instance.setForTest(null);
      await tester.pump();
      expect(ribbon(), findsNothing);
    });

    testWidgets('re-labels when the role changes under it', (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());
      expect(mark(tester), 'HOME');

      ServerStore.instance.setForTest(selfHosted);
      await tester.pump();
      expect(mark(tester), 'SELF');
    });
  });
}
