import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/server_directory.dart';
import 'package:monkeyhub/backend/server_endpoint.dart';
import 'package:monkeyhub/backend/server_store.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/self_host_badge.dart';

/// The badge floats above every route in the app, permanently, in the corner
/// where close buttons and call controls live. Three properties keep that from
/// being a bug in itself, and all three are the kind an unrelated edit can
/// quietly break: it must vanish entirely on the ordinary server, it must take
/// taps only on the shape it paints, and it must tell the home server apart
/// from somebody's own box.
/// The window every coordinate in this file is measured against.
const _surface = Size(390, 700);

/// A representative status-bar inset. Everything about the badge's placement is
/// expressed relative to it, so the taps have to be too.
const _statusBar = 47.0;

void main() {
  const selfHosted = ServerEndpoint(deploymentUrl: 'https://chat.example.com');
  final homeserver = KnownHosts.endpointFor(ServerRole.homeserver);
  final primary = KnownHosts.endpointFor(ServerRole.primary);

  Widget scene({
    SelfHostBadgeStyle? style,
    VoidCallback? onBadgeTap,
    VoidCallback? onBackgroundTap,
  }) {
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
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBackgroundTap,
                  child: const SizedBox.expand(),
                ),
                SelfHostBadge(style: style, onTap: onBadgeTap),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Size the WINDOW, not just the MediaQuery, then pump.
  ///
  /// Every corner assertion below is an absolute coordinate against a
  /// right-anchored widget. On the harness's default 800x600 window the badge
  /// sits 410pt from where those taps land, so "the corner tap fell through"
  /// passes for entirely the wrong reason — an earlier version of this file did
  /// exactly that and was green.
  Future<void> mount(WidgetTester tester, Widget widget) async {
    await tester.binding.setSurfaceSize(_surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(widget);
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ServerStore.instance.resetForTest();
  });

  group('when to draw at all', () {
    testWidgets('draws nothing on the bundled deployment', (tester) async {
      await mount(tester, scene());
      // Zero-sized, not merely invisible: a stock install must pay nothing at
      // all for a state it is not in.
      expect(tester.getSize(find.byType(SelfHostBadge)), Size.zero);
    });

    testWidgets('draws nothing when explicitly on the primary', (tester) async {
      ServerStore.instance.setForTest(primary);
      await mount(tester, scene(style: SelfHostBadgeStyle.pill));
      expect(tester.getSize(find.byType(SelfHostBadge)), Size.zero);
    });
  });

  group('what it says', () {
    testWidgets('names the home server, not the host', (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene(style: SelfHostBadgeStyle.pill));
      // The address is noise here — every user is on the same one, and what
      // they need is the fact that it is temporary.
      expect(find.text('Serving from homeserver'), findsOneWidget);
      expect(find.text(KnownHosts.homeserverHost), findsNothing);
    });

    testWidgets('names the host when it is somebody\'s own', (tester) async {
      ServerStore.instance.setForTest(selfHosted);
      await mount(tester, scene(style: SelfHostBadgeStyle.pill));
      // Here the address IS the useful fact: it is the only thing separating
      // one self-hosted install from another.
      expect(find.text('chat.example.com'), findsOneWidget);
    });

    testWidgets('the ribbon carries the short form', (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene(style: SelfHostBadgeStyle.ribbon));
      expect(find.text('HOMESERVER'), findsOneWidget);
    });
  });

  group('what it does with pointers', () {
    for (final endpoint in [homeserver, selfHosted]) {
      final role = KnownHosts.roleOf(endpoint.deploymentUrl).name;

      testWidgets('the $role pill opens on a tap', (tester) async {
        ServerStore.instance.setForTest(endpoint);
        var opened = false;
        await mount(
          tester,
          scene(
            style: SelfHostBadgeStyle.pill,
            onBadgeTap: () => opened = true,
          ),
        );
        await tester.tap(find.byType(SelfHostBadge));
        await tester.pump();
        expect(opened, isTrue);
      });

      testWidgets('the $role ribbon opens on a tap of the band', (
        tester,
      ) async {
        ServerStore.instance.setForTest(endpoint);
        var opened = false;
        await mount(
          tester,
          scene(
            style: SelfHostBadgeStyle.ribbon,
            onBadgeTap: () => opened = true,
          ),
        );
        // Dead centre of the band: the ribbon's centre line crosses the
        // corner's bisector _fromCorner points in, which for a 128pt square
        // puts it here.
        await tester.tapAt(const Offset(390 - 45, 45));
        await tester.pump();
        expect(opened, isTrue);
      });

      testWidgets('the $role ribbon lets the extreme corner through', (
        tester,
      ) async {
        ServerStore.instance.setForTest(endpoint);
        var opened = false;
        var background = false;
        await mount(
          tester,
          scene(
            style: SelfHostBadgeStyle.ribbon,
            onBadgeTap: () => opened = true,
            onBackgroundTap: () => background = true,
          ),
        );
        // The very corner pixel, where a close button or a call control would
        // sit. The band is inset from it, and everything the band does not
        // cover has to fall through to the route underneath.
        await tester.tapAt(const Offset(390 - 3, 3));
        await tester.pump();
        expect(opened, isFalse);
        expect(
          background,
          isTrue,
          reason: 'the badge floats above every route — a corner tap it eats '
              'is a tap the close button underneath it never gets',
        );
      });

      // The badge is drawn in the status-bar strip so it can be seen. The
      // reachable part of it is what is BELOW that strip, and at the sizes this
      // started at that was a sliver — which is the whole reason the ribbon and
      // the chip are as large as they are, and the reason the chip carries an
      // invisible skirt. These two assert the target survives the next person
      // who decides the badge looks a bit heavy.
      testWidgets('the $role pill is reachable below the status bar', (
        tester,
      ) async {
        ServerStore.instance.setForTest(endpoint);
        var opened = false;
        await mount(
          tester,
          scene(
            style: SelfHostBadgeStyle.pill,
            onBadgeTap: () => opened = true,
          ),
        );
        await tester.tapAt(const Offset(390 - 40, _statusBar + 8));
        await tester.pump();
        expect(opened, isTrue);
      });

      testWidgets('the $role ribbon is reachable below the status bar', (
        tester,
      ) async {
        ServerStore.instance.setForTest(endpoint);
        var opened = false;
        await mount(
          tester,
          scene(
            style: SelfHostBadgeStyle.ribbon,
            onBadgeTap: () => opened = true,
          ),
        );
        await tester.tapAt(const Offset(390 - 22, _statusBar + 10));
        await tester.pump();
        expect(opened, isTrue);
      });

      testWidgets('the $role pill lets the space beside it through', (
        tester,
      ) async {
        ServerStore.instance.setForTest(endpoint);
        var opened = false;
        var background = false;
        await mount(
          tester,
          scene(
            style: SelfHostBadgeStyle.pill,
            onBadgeTap: () => opened = true,
            onBackgroundTap: () => background = true,
          ),
        );
        // Well clear of the chip and its skirt, which together reach about
        // 15pt past the status bar.
        await tester.tapAt(const Offset(390 - 30, 140));
        await tester.pump();
        expect(opened, isFalse);
        expect(background, isTrue);
      });
    }
  });

  group('previews', () {
    for (final style in SelfHostBadgeStyle.values) {
      testWidgets('the ${style.name} preview builds at thumbnail size', (
        tester,
      ) async {
        final controller = ThemeController(ThemeController.byId('basic'));
        await mount(
          tester,
          ThemeScope(
            controller: controller,
            child: MaterialApp(
              home: Center(
                child: SelfHostBadgePreview(style: style, label: 'HOMESERVER'),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byType(SelfHostBadgePreview));
        expect(size.width, SelfHostBadgePreview.width);
        expect(size.height, SelfHostBadgePreview.height);
      });
    }
  });
}
