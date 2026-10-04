import 'dart:async';

import 'package:flutter/foundation.dart';
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
    NativeChrome.debugSupported = false;
  });

  testWidgets('startup detects native chrome on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeChrome.channel, (_) async => true);

    await NativeChrome.init();

    expect(NativeChrome.supported, isTrue);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('startup falls back when the scene bridge is missing', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    NativeChrome.debugSupported = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          NativeChrome.channel, (_) async => throw MissingPluginException(),
        );

    await NativeChrome.init();

    expect(NativeChrome.supported, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('an unanswered scene probe cannot hold startup indefinitely', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final reply = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeChrome.channel, (_) => reply.future);
    final initialization = NativeChrome.init();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await initialization;

    expect(NativeChrome.supported, isFalse);
    // A late scene reply must not enable a native bar after the shell has
    // already mounted its Flutter fallback.
    reply.complete(true);
    await tester.pump();
    expect(NativeChrome.supported, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('other platforms skip the native scene probe', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    NativeChrome.debugSupported = true;

    await NativeChrome.init();

    expect(calls, isEmpty);
    expect(NativeChrome.supported, isFalse);
    debugDefaultTargetPlatformOverride = null;
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

  // The vanishing-tab-bar bug: a theme change rebuilds the shell under a new
  // key, so the new bar configures BEFORE the old one is disposed. The old
  // dispose must name the old owner, or the native side removes the new bar.
  testWidgets('a rebuilt shell keeps its bar: dispose names the old owner',
      (tester) async {
    Widget bar(String key) => host(NativeTabBar(
          key: ValueKey(key),
          active: HomeSection.chat,
          onSelect: (_) {},
          badges: const {},
        ));
    await tester.pumpWidget(bar('midnight'));
    calls.clear();
    await tester.pumpWidget(bar('daylight'));

    final methods = calls.map((c) => c.method).toList();
    final configure = methods.indexOf('configure');
    final dispose = methods.indexOf('dispose');
    expect(configure, isNonNegative);
    expect(dispose, greaterThan(configure),
        reason: 'the new bar is configured before the old one goes');
    final newOwner = (calls[configure].arguments as Map)['owner'];
    final oldOwner = (calls[dispose].arguments as Map)['owner'];
    expect(oldOwner, isNot(newOwner));
  });

  // The dead-tabs bug: the same rebuild let the old instance's dispose clear
  // the channel handler the new one had just installed, so the bar showed
  // but no tap reached the shell until a restart.
  testWidgets('a rebuilt shell still hears taps', (tester) async {
    HomeSection? picked;
    Widget bar(String key) => host(NativeTabBar(
          key: ValueKey(key),
          active: HomeSection.chat,
          onSelect: (s) => picked = s,
          badges: const {},
        ));
    await tester.pumpWidget(bar('midnight'));
    await tester.pumpWidget(bar('daylight'));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      NativeChrome.channel.name,
      NativeChrome.channel.codec
          .encodeMethodCall(MethodCall('select', navIndexOf(HomeSection.feed))),
      (_) {},
    );
    expect(picked, HomeSection.feed);
  });
}
