import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/swipe_fork.dart';

/// The swipe-up fork's chevron peek: its counting and stop rules, and the
/// glyph itself.
void main() {
  final store = SettingsStore.instance;

  Future<void> fresh(Map<String, String> initial) async {
    FlutterSecureStorage.setMockInitialValues(initial);
    await store.reloadForTest();
  }

  test('plays on the first three landings, then stops', () async {
    await fresh({});
    for (var i = 0; i < 3; i++) {
      expect(store.shouldShowForkPeek, isTrue, reason: 'play ${i + 1}');
      await store.markForkPeekShown();
    }
    expect(store.forkPeekCount, 3);
    expect(store.shouldShowForkPeek, isFalse);
  });

  test('completing the gesture once stops it for good', () async {
    await fresh({});
    await store.markForkPeekShown();
    expect(store.shouldShowForkPeek, isTrue);
    await store.markForkGestureDone();
    expect(store.shouldShowForkPeek, isFalse);
  });

  test('the counters survive a reload', () async {
    await fresh({});
    await store.markForkPeekShown();
    await store.markForkPeekShown();
    await store.reloadForTest();
    expect(store.forkPeekCount, 2);
    expect(store.shouldShowForkPeek, isTrue);
    await store.markForkGestureDone();
    await store.reloadForTest();
    expect(store.forkGestureDone, isTrue);
    expect(store.shouldShowForkPeek, isFalse);
  });

  testWidgets('the chevron rises, fades, then reports done', (t) async {
    var done = 0;
    await t.pumpWidget(MaterialApp(
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Center(
          child: ForkPeek(semanticLabel: 'Swipe up', onDone: () => done++),
        ),
      ),
    ));
    final start = t.getTopLeft(find.byType(Icon)).dy;
    await t.pump(const Duration(milliseconds: 600));
    expect(t.getTopLeft(find.byType(Icon)).dy, lessThan(start));
    expect(done, 0);
    await t.pump(const Duration(milliseconds: 500));
    expect(done, 1);
    expect(find.bySemanticsLabel('Swipe up'), findsOneWidget);
  });
}
