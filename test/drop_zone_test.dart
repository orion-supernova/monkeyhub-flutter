@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/drop/drop_classifier.dart';
import 'package:monkeyhub/drop/drop_controller.dart';
import 'package:monkeyhub/drop/drop_item.dart';
import 'package:monkeyhub/drop/drop_zone.dart';
import 'package:monkeyhub/drop/drop_zone_registry.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// What this pins: which surface a drop lands on.
///
/// An OS drag produces no pointer events, so none of Flutter's own hit testing
/// applies — the app answers "what is under here" itself, from a list of
/// rectangles it keeps. Two things about that are easy to get quietly wrong
/// and both put somebody's file in the wrong chat:
///
///  * **a rectangle does not stop existing when it is covered.** A chat row
///    laid out past the end of its viewport, or a whole screen underneath a
///    pushed route, still measures exactly where it would paint.
///  * **nesting has to resolve without hand-picked numbers everywhere.** The
///    transcript contains the composer; the chat list contains its rows.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(body: child),
        ),
      );

  /// A handle over [key]'s box, with no widget of its own.
  ///
  /// The registry's logic is platform-independent even though `DropZone` only
  /// installs itself where a desktop drag exists, so it is exercised directly
  /// here rather than through a widget that would make the whole file
  /// macOS-only.
  DropZoneHandle handleFor(GlobalKey key, {int priority = 0}) => DropZoneHandle(
        key: key,
        policy: DropPolicy.permissive,
        priority: priority,
        onEnter: (_) {},
        onMove: (_) {},
        onLeave: () {},
        onDrop: (_) async {},
      );

  group('measuring a zone', () {
    testWidgets('reports where it paints, in global coordinates', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(host(
        Padding(
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 0),
          child: SizedBox(key: key, width: 200, height: 80),
        ),
      ));

      expect(handleFor(key).rect, const Rect.fromLTWH(40, 100, 200, 80));
    });

    testWidgets('is null once its widget is gone', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(host(SizedBox(key: key, width: 10, height: 10)));
      final handle = handleFor(key);
      expect(handle.rect, isNotNull);

      await tester.pumpWidget(host(const SizedBox.shrink()));
      expect(handle.rect, isNull);
    });

    testWidgets('is clipped to the scrollable it lives in', (tester) async {
      // The chat-row case. A `ListView` lays out rows past both ends of its
      // viewport, so without the intersection a row scrolled up under the
      // header would still claim the pointer hovering the header.
      final key = GlobalKey();
      await tester.pumpWidget(host(
        Center(
          child: SizedBox(
            height: 100,
            child: ListView(
              children: [
                const SizedBox(height: 300),
                SizedBox(key: key, height: 60),
                const SizedBox(height: 300),
              ],
            ),
          ),
        ),
      ));

      // Laid out 300pt down inside a 100pt viewport: entirely below it.
      expect(handleFor(key).rect, isNull);
    });
  });

  group('choosing between zones', () {
    testWidgets('priority wins over containment', (tester) async {
      final outer = GlobalKey();
      final inner = GlobalKey();
      await tester.pumpWidget(host(
        SizedBox.expand(
          key: outer,
          child: Center(child: SizedBox(key: inner, width: 100, height: 100)),
        ),
      ));

      final registry = DropZoneRegistry.forTest();
      final low = handleFor(inner, priority: 0);
      final high = handleFor(outer, priority: 20);
      registry.register(low);
      registry.register(high);

      final middle = tester.getCenter(find.byKey(inner));
      expect(registry.hitTest(middle), same(high));
    });

    testWidgets('at equal priority the smaller rectangle wins', (tester) async {
      // What makes nesting work without every caller hand-picking a number: a
      // zone drawn inside another is, by fitting inside it, more specific.
      final outer = GlobalKey();
      final inner = GlobalKey();
      await tester.pumpWidget(host(
        SizedBox.expand(
          key: outer,
          child: Center(child: SizedBox(key: inner, width: 100, height: 100)),
        ),
      ));

      final registry = DropZoneRegistry.forTest();
      final big = handleFor(outer);
      final small = handleFor(inner);
      registry.register(big);
      registry.register(small);

      expect(registry.hitTest(tester.getCenter(find.byKey(inner))), same(small));
      // Outside the inner box, the outer one is the only answer.
      expect(registry.hitTest(const Offset(5, 5)), same(big));
    });

    testWidgets('empty space belongs to nobody', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(host(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(key: key, width: 50, height: 50),
        ),
      ));

      final registry = DropZoneRegistry.forTest();
      registry.register(handleFor(key));
      expect(registry.hitTest(const Offset(400, 400)), isNull);
    });

    testWidgets('a disabled zone is skipped entirely', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(host(SizedBox.expand(key: key)));

      final registry = DropZoneRegistry.forTest();
      final handle = handleFor(key)..enabled = false;
      registry.register(handle);
      expect(registry.hitTest(const Offset(10, 10)), isNull);

      handle.enabled = true;
      expect(registry.hitTest(const Offset(10, 10)), same(handle));
    });

    test('unregistering removes it', () {
      final registry = DropZoneRegistry.forTest();
      final handle = handleFor(GlobalKey());
      registry.register(handle);
      registry.register(handle); // idempotent
      expect(registry.length, 1);
      registry.unregister(handle);
      expect(registry.length, 0);
    });
  });

  group('the widget', () {
    testWidgets('registers itself and cleans up after itself', (tester) async {
      await tester.pumpWidget(host(
        DropZone(onDrop: (_) async {}, child: const SizedBox.expand()),
      ));

      final before = DropZoneRegistry.instance.length;
      await tester.pumpWidget(host(const SizedBox.expand()));
      await tester.pump();
      expect(DropZoneRegistry.instance.length, before - 1);
    }, skip: !DropController.isSupported);

    testWidgets('goes dead under a pushed route', (tester) async {
      // Without this, dropping a file onto an open photo editor would send it
      // to the transcript behind — the editor covers the pixels, not the
      // rectangle.
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: DropZone(onDrop: (_) async {}, child: const SizedBox.expand()),
          ),
        ),
      ));

      final live = DropZoneRegistry.instance.hitTest(const Offset(100, 100));
      expect(live, isNotNull);

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
      );
      await tester.pumpAndSettle();
      expect(DropZoneRegistry.instance.hitTest(const Offset(100, 100)), isNull);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        DropZoneRegistry.instance.hitTest(const Offset(100, 100)),
        isNotNull,
      );
    }, skip: !DropController.isSupported);

    testWidgets('an explicitly disabled zone never registers a hit',
        (tester) async {
      await tester.pumpWidget(host(
        DropZone(
          enabled: false,
          onDrop: (_) async {},
          child: const SizedBox.expand(),
        ),
      ));
      expect(DropZoneRegistry.instance.hitTest(const Offset(50, 50)), isNull);
    }, skip: !DropController.isSupported);
  });

  group('a bundle', () {
    test('separates what has bytes from what was refused for its size', () {
      const bundle = DropBundle(files: [
        DroppedFile(name: 'a.png', mimeType: 'image/png', size: 10, path: '/tmp/a'),
        DroppedFile(name: 'b.mov', mimeType: 'video/quicktime', size: 99999999, oversize: true),
      ]);
      expect(bundle.sendable.map((f) => f.name), ['a.png']);
      expect(bundle.oversized.map((f) => f.name), ['b.mov']);
    });

    test('a file with neither a path nor bytes is not sendable', () {
      // The macOS staging failure: the copy did not happen, so claiming the
      // file would send an empty bubble.
      const bundle = DropBundle(files: [
        DroppedFile(name: 'a.png', mimeType: 'image/png', size: 10),
      ]);
      expect(bundle.sendable, isEmpty);
    });
  });
}
