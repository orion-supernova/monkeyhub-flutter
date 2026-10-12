import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/route_depth.dart';

/// On the desktop split shell a page that closes back onto the shell wears
/// the ×; one pushed deeper keeps the chevron; phones never change.
void main() {
  final mac = TargetPlatformVariant.only(TargetPlatform.macOS);

  Future<GlobalKey<NavigatorState>> pump(WidgetTester tester, double width) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: LayoutScope(
        windowClass: Breakpoints.classOf(width),
        width: width,
        child: MaterialApp(
          navigatorKey: nav,
          navigatorObservers: [RouteDepthObserver()],
          home: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    ));
    return nav;
  }

  Route<void> page() => MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: GlassBackButton())),
      );

  testWidgets('split shell: × over the shell, chevron one level deeper', (tester) async {
    final nav = await pump(tester, 1200);
    nav.currentState!.push(page());
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.chevron_back), findsNothing);

    nav.currentState!.push(page());
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
  }, variant: mac);

  testWidgets('phone layout keeps the chevron', (tester) async {
    final nav = await pump(tester, 400);
    nav.currentState!.push(page());
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.chevron_back), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsNothing);
  }, variant: mac);

  testWidgets('an explicit closes wins', (tester) async {
    final nav = await pump(tester, 400);
    nav.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(body: Center(child: GlassBackButton(closes: true, onTap: () {}))),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
  }, variant: mac);
}
