import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/native/native_control.dart';
import 'package:monkeyhub/widgets/route_depth.dart';

/// A native control may only show when it is whole and nothing Flutter
/// floats over it. Liquid Glass cut by a clipping ancestor renders as a flat
/// grey box (seen on device at the page bar, a sheet's top and the chat
/// list's header), and a native view always draws above Flutter, so one
/// under the call pills drew on top of them. Either way its Flutter
/// stand-in shows instead.
void main() {
  late List<Map<String, Object?>> syncs;

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    syncs = [];
    const overlay = MethodChannel('monkeyhub/native_overlay');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(overlay, (
      call,
    ) async {
      if (call.method == 'sync') {
        final items = (call.arguments as Map)['items'] as List;
        for (final i in items) {
          syncs.add((i as Map).cast<String, Object?>());
        }
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        overlay,
        null,
      ),
    );
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(home: Material(child: child)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Widget control() => NativeControl(
    size: const Size(100, 40),
    spec: NativeSpec.button(label: 'Go', height: 40),
    standIn: const SizedBox(width: 100, height: 40),
  );

  Map<String, Object?> last() => syncs.last;

  testWidgets('a whole control shows', (tester) async {
    await pump(
      tester,
      const Align(alignment: Alignment.center, child: _Ctl()),
    );
    expect(last()['visible'], isTrue);
  });

  testWidgets('a control a clip cuts into hides (the grey box)', (
    tester,
  ) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 60, // narrower than the 100pt control
          height: 40,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: 100,
              child: control(),
            ),
          ),
        ),
      ),
    );
    expect(last()['visible'], isFalse);
    expect(last()['why'], 'partial');
  });

  testWidgets('a control under floating Flutter chrome hides', (
    tester,
  ) async {
    await pump(
      tester,
      Stack(
        children: [
          Positioned(left: 20, top: 20, child: control()),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 50,
            child: NativeOccluder(child: ColoredBox(color: Colors.red)),
          ),
        ],
      ),
    );
    expect(last()['visible'], isFalse);
    expect(last()['why'], 'occluded');
  });

  testWidgets('under a fade in progress a control shows its stand-in; '
      'under a resting dim (static Opacity) it stays native', (tester) async {
    await pump(
      tester,
      const Align(
        child: FadeTransition(
          opacity: AlwaysStoppedAnimation<double>(0.5),
          child: _Ctl(),
        ),
      ),
    );
    expect(last()['visible'], isFalse);
    expect(last()['why'], 'faded');
    await pump(
      tester,
      const Align(child: Opacity(opacity: 0.5, child: _Ctl())),
    );
    expect(last()['visible'], isTrue);
  });

  testWidgets('a Flutter scrim dims the native control under it, not one '
      'in its own layer (the capture\'s buttons over its own dim)', (
    tester,
  ) async {
    await pump(
      tester,
      const Stack(
        children: [
          Positioned(left: 20, top: 20, child: _Ctl()),
          Positioned.fill(
            child: NativeScrim(alpha: 0.6, child: SizedBox.expand()),
          ),
        ],
      ),
    );
    expect(last()['visible'], isTrue, reason: 'stays native, dimmed');
    expect((last()['dim'] as num).toDouble(), closeTo(0.6, 0.03));

    await pump(
      tester,
      const NativeLayer(
        child: Stack(
          children: [
            Positioned.fill(
              child: NativeScrim(alpha: 0.6, child: SizedBox.expand()),
            ),
            Positioned.fill(child: NativeOccluder(child: SizedBox.expand())),
            Positioned(left: 20, top: 20, child: _Ctl()),
          ],
        ),
      ),
    );
    expect(last()['visible'], isTrue);
    expect(last()['dim'], isNull, reason: 'its own layer is below it');
  });

  testWidgets('faded to nothing (the mode button under the record bloom), a '
      'revealed control hides at once: no hold over what replaced it', (
    tester,
  ) async {
    final opacity = ValueNotifier<double>(1);
    await pump(
      tester,
      Align(
        child: ValueListenableBuilder<double>(
          valueListenable: opacity,
          builder: (_, o, child) => Opacity(opacity: o, child: child),
          child: const _Ctl(),
        ),
      ),
    );
    final id = (syncs.last['id'] as String?);
    // Reveal it, as the native side does.
    const codec = StandardMethodCodec();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'monkeyhub/native_overlay',
      codec.encodeMethodCall(
        MethodCall('event', {'id': id, 'name': 'revealed', 'value': true}),
      ),
      (_) {},
    );
    await tester.pump();
    syncs.clear();
    opacity.value = 0;
    await tester.pump();
    expect(syncs.first['visible'], isFalse, reason: 'first sync, no hold');
    expect(syncs.first['why'], 'clipped');
  });

  testWidgets('a disabled occluder (the idle record bloom over the composer) '
      'covers nothing', (tester) async {
    await pump(
      tester,
      const Stack(
        children: [
          Positioned(left: 20, top: 20, child: _Ctl()),
          Positioned.fill(
            child: NativeOccluder(enabled: false, child: SizedBox.expand()),
          ),
        ],
      ),
    );
    expect(last()['visible'], isTrue);
  });

  testWidgets('a collapsed occluder (pill hidden) hides nothing', (
    tester,
  ) async {
    await pump(
      tester,
      Stack(
        children: [
          Positioned(left: 20, top: 20, child: control()),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 0,
            child: NativeOccluder(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
    expect(last()['visible'], isTrue);
  });

  group('transitions', () {
    // id -> label, from the overlay's `set` traffic.
    late Map<String, String> labels;
    // label -> every placement synced for it, in order.
    late Map<String, List<Map<String, Object?>>> byLabel;
    final nav = GlobalKey<NavigatorState>();

    Future<void> app(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      labels = {};
      byLabel = {};
      const overlay = MethodChannel('monkeyhub/native_overlay');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(overlay, (
        call,
      ) async {
        final a = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
        if (call.method == 'set') {
          final spec = (a['spec'] as Map).cast<String, Object?>();
          labels[a['id'] as String] = spec['label'] as String;
        } else if (call.method == 'sync') {
          for (final i in a['items'] as List) {
            final m = (i as Map).cast<String, Object?>();
            final label = labels[m['id']] ?? '?';
            (byLabel[label] ??= []).add(m);
          }
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          overlay,
          null,
        ),
      );
      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            navigatorKey: nav,
            navigatorObservers: [RouteDepthObserver()],
            theme: ThemeData(
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            home: home,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Widget page(String label, {bool right = false}) => Material(
      child: Align(
        alignment: right ? Alignment.topRight : Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 60),
          child: NativeControl(
            size: const Size(80, 40),
            spec: NativeSpec.button(label: label, height: 40),
            standIn: SizedBox(key: ValueKey('standIn$label'), width: 80, height: 40),
          ),
        ),
      ),
    );

    /// Tells Dart the native side revealed [label] (as the real overlay
    /// does once its glass has sampled).
    Future<void> reveal(WidgetTester tester, String label) async {
      final id = labels.entries.firstWhere((e) => e.value == label).key;
      const codec = StandardMethodCodec();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'monkeyhub/native_overlay',
        codec.encodeMethodCall(
          MethodCall('event', {'id': id, 'name': 'revealed', 'value': true}),
        ),
        (_) {},
      );
      await tester.pump();
    }

    bool shown(String label) => byLabel[label]!.last['visible'] == true;

    testWidgets('ride along: the incoming page stays native and moves with '
        'the slide; the page under it steps aside only once covered', (
      tester,
    ) async {
      // A on the right of the outgoing page: the incoming page slides over
      // it. (A control on the left leaves the screen before it is reached,
      // and rightly stays native until then.)
      await app(tester, page('A', right: true));
      expect(shown('A'), isTrue);
      await reveal(tester, 'A');

      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => page('B')));
      await tester.pump(); // route built
      await tester.pump(const Duration(milliseconds: 16));
      final xs = <double>[];
      for (var f = 0; f < 30; f++) {
        await tester.pump(const Duration(milliseconds: 16));
        final b = byLabel['B'];
        if (b != null && b.last['visible'] == true) {
          xs.add((b.last['x'] as num).toDouble());
        }
      }
      expect(xs.length, greaterThan(5), reason: 'B shown during the slide');
      expect(xs.first, greaterThan(xs.last), reason: 'B moved left with it');
      // A: native through the start, then covered (stand-in) by B's page.
      final a = byLabel['A']!;
      expect(a.first['visible'], isTrue);
      expect(a.any((m) => m['why'] == 'covered'), isTrue);
      await tester.pumpAndSettle();
      expect(shown('B'), isTrue);
      expect(byLabel['B']!.last['x'], 20, reason: 'B at rest');
    });

    testWidgets('a page pushed in a pane INSIDE the page (a room side pane '
        'opening a profile) covers that page\'s header controls', (
      tester,
    ) async {
      final pane = GlobalKey<NavigatorState>();
      await app(tester, const SizedBox.shrink());
      // The room: a pushed root page whose body holds its own navigator.
      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => Stack(
          children: [
            Positioned.fill(
              child: Navigator(
                key: pane,
                observers: [RouteDepthObserver()],
                onGenerateRoute: (_) => PageRouteBuilder<void>(
                  pageBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            page('A', right: true),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      await reveal(tester, 'A');
      expect(shown('A'), isTrue);
      pane.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Material(child: SizedBox.expand()),
      ));
      await tester.pumpAndSettle();
      expect(byLabel['A']!.any((m) => m['why'] == 'covered'), isTrue);
      expect(shown('A'), isFalse);
    });

    testWidgets('under a dialog\'s scrim a control stays native and dims '
        'with it (no swap), unless the card itself is over it', (
      tester,
    ) async {
      await app(tester, page('A'));
      await reveal(tester, 'A');
      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const Center(
          child: NativeCover(child: SizedBox(width: 100, height: 100)),
        ),
      );
      await tester.pumpAndSettle();
      expect(shown('A'), isTrue, reason: 'stays native under the scrim');
      final dim = (byLabel['A']!.last['dim'] as num).toDouble();
      expect(dim, closeTo(0.54, 0.03), reason: "the dialog scrim's alpha");
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(shown('A'), isTrue);
      expect(byLabel['A']!.last['dim'], isNull, reason: 'scrim gone');

      // A card that does overlap the control covers it.
      showDialog<void>(
        context: nav.currentContext!,
        builder: (_) => const Align(
          alignment: Alignment.topLeft,
          child: NativeCover(child: SizedBox(width: 200, height: 200)),
        ),
      );
      await tester.pumpAndSettle();
      expect(shown('A'), isFalse);
      expect(byLabel['A']!.last['why'], 'covered');
    });

    testWidgets('stand-in first: a native control that must hide where its '
        'stand-in shows (mid-fade) stays up two frames after the stand-in is '
        'built, never a frame with neither', (tester) async {
      final fade = AnimationController(vsync: const TestVSync(), value: 1);
      addTearDown(fade.dispose);
      await app(
        tester,
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, top: 60),
              child: FadeTransition(
                opacity: fade,
                child: NativeControl(
                  size: const Size(80, 40),
                  spec: NativeSpec.button(label: 'A', height: 40),
                  standIn: const SizedBox(
                    key: ValueKey('standInA'),
                    width: 80,
                    height: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await reveal(tester, 'A');
      Finder standIn() => find.byKey(const ValueKey('standInA'));
      expect(standIn(), findsNothing, reason: 'native up, no stand-in');
      fade.value = 0.5;
      int? standInFrame;
      int? hiddenFrame;
      for (var f = 0; f < 8; f++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (standInFrame == null && standIn().evaluate().isNotEmpty) {
          standInFrame = f;
        }
        if (hiddenFrame == null && byLabel['A']!.last['visible'] == false) {
          hiddenFrame = f;
        }
      }
      expect(standInFrame, isNotNull);
      expect(hiddenFrame, isNotNull);
      expect(hiddenFrame! - standInFrame!, greaterThanOrEqualTo(2),
          reason: 'native leaves only after the stand-in had frames to paint');
    });

    testWidgets('covered by an incoming page, a native control leaves at '
        'once: the page is what replaces it, no hold over it', (tester) async {
      await app(tester, page('A', right: true));
      await reveal(tester, 'A');
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Material(child: SizedBox.expand())),
      );
      for (var f = 0; f < 40; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final covered = byLabel['A']!.where((m) => m['why'] == 'covered');
      expect(covered, isNotEmpty);
      expect(covered.first['visible'], isFalse, reason: 'first covered sync');
    });

    testWidgets('hide-during-transitions mode keeps the old behaviour', (
      tester,
    ) async {
      // Not awaited: the keychain write never completes under test; the
      // value itself is set synchronously.
      unawaited(SettingsStore.instance.setNativeRideAlong(false));
      addTearDown(() => unawaited(SettingsStore.instance.setNativeRideAlong(true)));
      await app(tester, page('A'));
      nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => page('B')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 16));
      expect(byLabel['B']!.last['why'], 'route');
      await tester.pumpAndSettle();
      expect(shown('B'), isTrue);
    });
  });

  testWidgets('a control that goes away leaves its native view hidden for '
      'the next one of its kind (a tab revisited shows native at once); '
      'a text field is never pooled', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final calls = <(String, Map<String, Object?>)>[];
    const overlay = MethodChannel('monkeyhub/native_overlay');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(overlay, (
      call,
    ) async {
      calls.add((call.method, (call.arguments as Map).cast<String, Object?>()));
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        overlay,
        null,
      ),
    );
    Future<void> show(Widget? w) async {
      await tester.pumpWidget(ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(home: Material(child: Center(child: w))),
      ));
      await tester.pump();
    }

    String idOfSet(String label) => calls
        .lastWhere((c) =>
            c.$1 == 'set' && (c.$2['spec'] as Map)['label'] == label)
        .$2['id'] as String;

    final button = NativeControl(
      size: const Size(80, 40),
      spec: NativeSpec.button(label: 'Pooled', height: 40),
    );
    await show(button);
    final first = idOfSet('Pooled');
    calls.clear();
    await show(null);
    expect(calls.where((c) => c.$1 == 'remove'), isEmpty,
        reason: 'kept, not destroyed');
    expect(
      calls.any((c) =>
          c.$1 == 'sync' &&
          (c.$2['items'] as List).any((i) =>
              (i as Map)['id'] == first && i['visible'] == false)),
      isTrue,
      reason: 'hidden',
    );
    await show(NativeControl(
      size: const Size(80, 40),
      spec: NativeSpec.button(label: 'Pooled', height: 40),
    ));
    expect(idOfSet('Pooled'), first, reason: 'adopted its own view');

    final field = NativeControl(
      size: const Size(200, 40),
      spec: NativeSpec.textField(text: '', placeholder: 'Field'),
    );
    await show(field);
    final fieldId = calls.lastWhere((c) =>
        c.$1 == 'set' && (c.$2['spec'] as Map)['kind'] == 'textField').$2['id'];
    calls.clear();
    await show(null);
    expect(
      calls.any((c) => c.$1 == 'remove' && c.$2['id'] == fieldId),
      isTrue,
      reason: 'stateful kinds are destroyed',
    );
  });
}

class _Ctl extends StatelessWidget {
  const _Ctl();

  @override
  Widget build(BuildContext context) => NativeControl(
    size: const Size(100, 40),
    spec: NativeSpec.button(label: 'Go', height: 40),
    standIn: const SizedBox(width: 100, height: 40),
  );
}
