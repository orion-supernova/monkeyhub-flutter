import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/swipe_fork.dart';

/// The swipe-up fork's peek: its counting and stop rules, and the list nudge.
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

  testWidgets('the list nudges up, settles back once, then reports done',
      (t) async {
    var done = 0;
    late SwipeForkController fork;
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: _PeekHost(
          onFork: (f) => fork = f,
          onDone: () => done++,
        ),
      ),
    ));
    final rest = t.getTopLeft(find.text('m0')).dy;
    await t.pump(const Duration(milliseconds: 300));
    final nudged = t.getTopLeft(find.text('m0')).dy;
    expect(nudged, lessThan(rest));
    expect(rest - nudged, lessThanOrEqualTo(ForkPeek.rise + 0.01));
    expect(fork.peekOn.value, isTrue);
    await t.pump(const Duration(milliseconds: 400));
    expect(done, 0);
    await t.pump(const Duration(milliseconds: 400));
    expect(done, 1);
    expect(fork.peekOn.value, isFalse);
    expect(t.getTopLeft(find.text('m0')).dy, rest);
    expect(find.bySemanticsLabel('Swipe up'), findsOneWidget);
  });
}

class _PeekHost extends StatefulWidget {
  const _PeekHost({required this.onFork, required this.onDone});
  final void Function(SwipeForkController) onFork;
  final VoidCallback onDone;
  @override
  State<_PeekHost> createState() => _PeekHostState();
}

class _PeekHostState extends State<_PeekHost> with TickerProviderStateMixin {
  late final SwipeForkController c = SwipeForkController(
    vsync: this,
    canArm: () => true,
    roomState: () => const ForkRoomState(),
    onStartHuddle: () async {},
    onJoinHuddle: () async {},
    onToggleVanish: (_) async {},
  );

  @override
  void initState() {
    super.initState();
    widget.onFork(c);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        ForkLift(
          controller: c,
          child: ListView.builder(
            reverse: true,
            itemCount: 30,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('m$i')),
          ),
        ),
        SwipeForkOverlay(controller: c, dockHeight: () => 60),
        ForkPeek(controller: c, semanticLabel: 'Swipe up', onDone: widget.onDone),
      ]);
}
