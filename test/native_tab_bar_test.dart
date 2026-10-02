import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/navigation/destinations.dart';
import 'package:monkeyhub/screens/navigation/native_tab_bar.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeChrome.channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeChrome.channel, null);
  });

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  // The regression: in place of the full-size pill, a 0×0 stand-in let the
  // shell's Stack shrink to nothing, and the app went black under a working
  // native bar.
  testWidgets('keeps a Stack shaped like the shell full-size', (tester) async {
    final section = GlobalKey();
    await tester.pumpWidget(host(Scaffold(
      body: Stack(children: [
        Positioned.fill(child: SizedBox(key: section)),
        NativeTabBar(
          active: HomeSection.chat,
          onSelect: (_) {},
          badges: const {},
        ),
      ]),
    )));
    expect(tester.getSize(find.byKey(section)), const Size(800, 600));
  });

  testWidgets('configures once, then sends only real changes', (tester) async {
    Widget bar(int unread) => host(NativeTabBar(
          active: HomeSection.chat,
          onSelect: (_) {},
          badges: {HomeSection.chat: unread},
        ));
    await tester.pumpWidget(bar(2));
    expect(calls.map((c) => c.method), ['configure', 'update', 'setVisible']);
    final items = (calls.first.arguments as Map)['items'] as List;
    expect(items, hasLength(navOrder.length));

    calls.clear();
    await tester.pumpWidget(bar(2));
    expect(calls, isEmpty, reason: 'an identical rebuild sends nothing');

    await tester.pumpWidget(bar(3));
    expect(calls.map((c) => c.method), ['update']);
    expect((calls.single.arguments as Map)['badges'], [3, 0, 0, 0]);
  });

  testWidgets('a native tap reaches onSelect', (tester) async {
    HomeSection? picked;
    await tester.pumpWidget(host(NativeTabBar(
      active: HomeSection.chat,
      onSelect: (s) => picked = s,
      badges: const {},
    )));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      NativeChrome.channel.name,
      NativeChrome.channel.codec
          .encodeMethodCall(MethodCall('select', navIndexOf(HomeSection.feed))),
      (_) {},
    );
    expect(picked, HomeSection.feed);
  });

  testWidgets('an overlay hold hides the bar until released', (tester) async {
    await tester.pumpWidget(host(NativeTabBar(
      active: HomeSection.chat,
      onSelect: (_) {},
      badges: const {},
    )));
    List<Object?> visibility() => [
          for (final c in calls)
            if (c.method == 'setVisible') (c.arguments as Map)['visible'],
        ];
    expect(visibility(), [true]);

    final release = NativeChrome.hold();
    expect(visibility(), [true, false]);
    release();
    release(); // a second call is a no-op, not a second release
    expect(visibility(), [true, false, true]);
    expect(NativeChrome.holds.value, 0);
  });
}
