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

/// A representative status-bar inset. The bar's whole contract is expressed
/// relative to it, so the assertions have to be too.
const _statusBar = 47.0;

/// The bar says which server this is, permanently, on every screen. Three
/// properties keep that from being a bug in itself, and each is the kind an
/// unrelated edit can quietly break:
///
///  * it vanishes entirely on the ordinary deployment;
///  * it never prints the operator's address, only a server the user chose;
///  * the bar takes its height out of the layout, and the app below is inset
///    exactly once.
void main() {
  const selfHosted = ServerEndpoint(deploymentUrl: 'https://chat.example.com');
  final homeserver = KnownHosts.endpointFor(ServerRole.homeserver);
  final primary = KnownHosts.endpointFor(ServerRole.primary);

  /// The app's root arrangement in miniature: a bar that takes height, and
  /// everything else underneath with the top inset already spent.
  Widget scene({VoidCallback? onTap, VoidCallback? onBackgroundTap}) {
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
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  SelfHostBar(onTap: onTap),
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: SelfHostBar.consumesTopInset,
                      child: Stack(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onBackgroundTap,
                            child: SafeArea(
                              child: Container(key: const Key('content')),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Size the WINDOW, not just the MediaQuery, then pump.
  ///
  /// The bar's height is measured against a specific inset, and the taps below
  /// are absolute coordinates. An earlier version of this file left the harness
  /// at its default 800x600 and was green for entirely the wrong reason.
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
      // Zero-height, not merely invisible: a stock install must pay nothing at
      // all for a state it is not in — least of all vertical space.
      expect(tester.getSize(find.byType(SelfHostBar)), Size.zero);
    });

    testWidgets('draws nothing when explicitly on the primary', (tester) async {
      ServerStore.instance.setForTest(primary);
      await mount(tester, scene());
      expect(tester.getSize(find.byType(SelfHostBar)), Size.zero);
    });
  });

  group('what it says', () {
    testWidgets("never prints the home server's address", (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());
      expect(find.text('Serving from homeserver'), findsOneWidget);
      // The operator's deployment URL is infrastructure. It appearing on every
      // user's screen is the bug this asserts against, not a cosmetic detail.
      expect(find.textContaining('walhallaa'), findsNothing);
    });

    testWidgets('prints the address when the user chose it', (tester) async {
      ServerStore.instance.setForTest(selfHosted);
      await mount(tester, scene());
      expect(find.text('chat.example.com'), findsOneWidget);
    });

    testWidgets('the label is not truncated at a phone width', (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());
      // The chip this replaced capped itself at 170pt and ellipsised the
      // sentence into "Serving from home…". A full-width bar has the room; this
      // fails the moment something narrows it again.
      final text = tester.widget<Text>(find.text('Serving from homeserver'));
      final painter = TextPainter(
        text: TextSpan(text: text.data, style: text.style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      expect(
        tester.getSize(find.text('Serving from homeserver')).width,
        greaterThanOrEqualTo(painter.width - 0.5),
      );
    });
  });

  group('the bar takes its own height', () {
    testWidgets('covers the status bar and adds its content height', (
      tester,
    ) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());
      expect(
        tester.getSize(find.byType(SelfHostBar)).height,
        _statusBar + SelfHostBar.contentHeight,
      );
    });

    testWidgets('the app below it is inset exactly once', (tester) async {
      ServerStore.instance.setForTest(homeserver);
      await mount(tester, scene());
      // The bar has already spent the inset, so the SafeArea below must add
      // nothing. Leave `padding.top` in place and content lands 47pt lower than
      // it should — the failure this pairing exists to prevent.
      expect(
        tester.getTopLeft(find.byKey(const Key('content'))).dy,
        _statusBar + SelfHostBar.contentHeight,
      );
    });

    testWidgets('a tap anywhere along the bar opens it', (tester) async {
      ServerStore.instance.setForTest(homeserver);
      var opened = false;
      await mount(tester, scene(onTap: () => opened = true));
      // Far left, well away from the label: the target is the whole strip,
      // which is the point of the shape.
      await tester.tapAt(const Offset(30, _statusBar + 12));
      await tester.pump();
      expect(opened, isTrue);
    });
  });
}
