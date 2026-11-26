// THROWAWAY: drives the real app against a LOCAL demo backend for App Store
// preview capture. Never commit.
//
//   flutter drive --driver=test_driver/capture_flow_driver.dart \
//     --target=integration_test/zz_store_preview_test.dart \
//     --dart-define=DEMO_PW=... -d <simulator>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monkeyhub/backend/server_endpoint.dart';
import 'package:monkeyhub/backend/server_store.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/main.dart' as app;
import 'package:monkeyhub/widgets/self_host_badge.dart';

const _pw = String.fromEnvironment('DEMO_PW');
const _phase = String.fromEnvironment('PHASE', defaultValue: 'explore');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store preview', (tester) async {
    var n = 0;
    Future<void> wait(int ms) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
    }

    Future<void> shot(String name) async {
      await tester.pump();
      n++;
      if (_phase == 'explore') {
        await binding.takeScreenshot('${n.toString().padLeft(2, '0')}_$name');
      }
    }

    Future<bool> waitFor(Finder f, {int timeoutMs = 15000}) async {
      final end = DateTime.now().add(Duration(milliseconds: timeoutMs));
      while (f.evaluate().isEmpty && DateTime.now().isBefore(end)) {
        await wait(200);
      }
      return f.evaluate().isNotEmpty;
    }

    Future<void> tapText(String t, {int timeoutMs = 10000}) async {
      var f = find.text(t);
      if (f.evaluate().isEmpty) f = find.textContaining(t);
      if (await waitFor(f, timeoutMs: timeoutMs)) {
        await tester.tap(f.first, warnIfMissed: false);
      } else {
        debugPrint('CAPTURE: missing "$t"');
      }
    }

    ServerMarkBanner.hideForCapture = true;
    await ServerStore.instance.use(
      const ServerEndpoint(
        deploymentUrl: 'http://127.0.0.1:3210',
        siteUrlOverride: 'http://127.0.0.1:3211',
      ),
    );

    Future<void> back() async {
      final navs = find.byType(Navigator);
      for (final e in navs.evaluate().toList().reversed) {
        final st = (e as StatefulElement).state as NavigatorState;
        if (st.canPop()) {
          await st.maybePop();
          return;
        }
      }
      debugPrint('CAPTURE: nothing to pop');
    }

    app.main();
    await wait(5000);
    await shot('launch');

    // First-run onboarding: pick Midnight, then Continue through every page.
    if (find.text('Make it yours').evaluate().isNotEmpty) {
      final one = find.text('One theme');
      if (one.evaluate().isNotEmpty) await tester.tap(one.first, warnIfMissed: false);
      await wait(600);
      final mid = find.text('Midnight');
      if (mid.evaluate().isNotEmpty) await tester.tap(mid.first, warnIfMissed: false);
      await wait(600);
      await shot('onboard_theme');
    }
    for (var i = 0; i < 6; i++) {
      if (find.widgetWithText(TextField, 'Username').evaluate().isNotEmpty) break;
      var cont = find.text('Continue');
      if (cont.evaluate().isEmpty) cont = find.text('Get started');
      if (cont.evaluate().isEmpty) break;
      await tester.tap(cont.last, warnIfMissed: false);
      await wait(1500);
      await shot('onboard_$i');
    }

    final user = find.widgetWithText(TextField, 'Username');
    if (await waitFor(user, timeoutMs: 8000)) {
      await tester.enterText(user.first, 'maya');
      await tester.enterText(find.widgetWithText(TextField, 'Password').first, _pw);
      await wait(300);
      await shot('login_filled');
      await tapText('Sign in');
    } else {
      debugPrint('CAPTURE: no username field');
    }
    await wait(6000);
    // "Confirm it's you" (recovery phrase setup) after a fresh sign-in.
    if (find.text("Confirm").evaluate().isNotEmpty || find.textContaining("it's you").evaluate().isNotEmpty) {
      final pf = find.byType(TextField);
      if (pf.evaluate().isNotEmpty) {
        await tester.enterText(pf.first, _pw);
        await wait(300);
        await tapText('Continue');
        await wait(4000);
        await shot('after_confirm');
      }
    }
    for (var i = 0; i < 3; i++) {
      // Dismiss anything still covering the list (sheets with a close X).
      if (find.text('Chats').evaluate().isNotEmpty) break;
      await back();
      await wait(1500);
    }
    await shot('home');

    if (_phase == 'record') {
      void mark(String m) => debugPrint('CAPTURE_MARK $m');
      SettingsStore.instance.setSection(HomeSection.chat);
      await wait(2500);
      mark('start');
      await wait(2500);
      // 1. group chat: type and send
      await tapText('Weekend hike');
      await wait(2200);
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.tap(field.last, warnIfMissed: false);
        await wait(400);
        const msg = 'Count me in! 🙌';
        final runes = msg.runes.toList();
        for (var k = 1; k <= runes.length; k++) {
          await tester.enterText(field.last, String.fromCharCodes(runes.take(k)));
          await wait(85);
        }
        await wait(500);
        var send = find.bySemanticsLabel(RegExp(r'^Send', caseSensitive: false));
        if (send.evaluate().isNotEmpty) {
          await tester.tap(send.last, warnIfMissed: false);
        } else {
          await tester.testTextInput.receiveAction(TextInputAction.send);
          debugPrint('CAPTURE: send via keyboard action');
        }
        await wait(1800);
        FocusManager.instance.primaryFocus?.unfocus();
        await wait(700);
      }
      await back();
      await wait(1200);
      // 2. secret room
      await tapText('Birthday surprise');
      await wait(3800);
      await back();
      await wait(1000);
      // 3. games
      SettingsStore.instance.setSection(HomeSection.games);
      await wait(1800);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -380));
      await wait(1800);
      // 4. feed
      SettingsStore.instance.setSection(HomeSection.feed);
      await wait(2200);
      final noah = find.text('Noah');
      if (noah.evaluate().isNotEmpty) {
        await tester.tap(noah.first, warnIfMissed: false);
        await wait(3000);
      }
      mark('end');
      await wait(800);
      return;
    }

    await tapText('Weekend hike');
    await wait(3000);
    await shot('hike');
    await back();
    await wait(1500);

    for (final tab in [HomeSection.games, HomeSection.feed, HomeSection.calls, HomeSection.settings]) {
      SettingsStore.instance.setSection(tab);
      await wait(3000);
      await shot('tab_${tab.name}');
    }
    final fam = find.textContaining('Family');
    if (await waitFor(fam, timeoutMs: 3000)) {
      await tester.ensureVisible(fam.first);
      await wait(800);
      await shot('settings_family');
    }
  });
}
