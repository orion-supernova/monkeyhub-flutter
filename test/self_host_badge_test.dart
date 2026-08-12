import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/server_endpoint.dart';
import 'package:monkeyhub/backend/server_store.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/self_host_badge.dart';

/// The badge floats above every route in the app, permanently, in the corner
/// where close buttons and call controls live. Two properties keep that from
/// being a bug in itself, and both are the kind an unrelated edit can quietly
/// break: it must vanish entirely on the bundled server, and it must never take
/// a tap.
void main() {
  const custom = ServerEndpoint(deploymentUrl: 'https://chat.example.com');

  Widget scene({SelfHostBadgeStyle? style, VoidCallback? onBackgroundTap}) {
    final controller = ThemeController(ThemeController.byId('basic'));
    return MediaQuery(
      data: const MediaQueryData(
        size: Size(390, 700),
        padding: EdgeInsets.only(top: 47),
      ),
      child: ThemeScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onBackgroundTap,
                  child: const SizedBox.expand(),
                ),
                SelfHostBadge(style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ServerStore.instance.resetForTest();
  });

  testWidgets('draws nothing on the bundled server', (tester) async {
    await tester.pumpWidget(scene());
    expect(find.text('SELF-HOSTED'), findsNothing);
    // Zero-sized, not merely invisible: a stock install must pay nothing at
    // all for a feature it has never touched.
    expect(tester.getSize(find.byType(SelfHostBadge)), Size.zero);
  });

  testWidgets('names the deployment once the app is repointed', (tester) async {
    ServerStore.instance.setForTest(custom);
    await tester.pumpWidget(scene(style: SelfHostBadgeStyle.ribbon));
    expect(find.text('SELF-HOSTED'), findsOneWidget);
  });

  testWidgets('the pill carries the host', (tester) async {
    ServerStore.instance.setForTest(custom);
    await tester.pumpWidget(scene(style: SelfHostBadgeStyle.pill));
    expect(find.text('chat.example.com'), findsOneWidget);
  });

  for (final style in SelfHostBadgeStyle.values) {
    testWidgets('the ${style.name} badge never swallows a tap', (tester) async {
      ServerStore.instance.setForTest(custom);
      var tapped = false;
      await tester.pumpWidget(
        scene(style: style, onBackgroundTap: () => tapped = true),
      );
      // Straight through the middle of the badge, in the top-right corner.
      await tester.tapAt(const Offset(345, 30));
      await tester.pump();
      expect(
        tapped,
        isTrue,
        reason: 'the badge is above every route — a tap it eats is a tap the '
            'close button underneath it never gets',
      );
    });

    testWidgets('the ${style.name} preview builds at thumbnail size',
        (tester) async {
      final controller = ThemeController(ThemeController.byId('basic'));
      await tester.pumpWidget(
        ThemeScope(
          controller: controller,
          child: MaterialApp(
            home: Center(
              child: SelfHostBadgePreview(
                style: style,
                host: 'chat.example.com',
              ),
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
}
