import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/screens/feed/moment_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

/// Highlights are stories (§G of the round-2 spec): a photo runs 10 s and
/// moves on by itself, a held finger pauses it, the edges of the picture step
/// back and forward, and anything that covers the viewer stops the clock.
///
/// Driven on the test's fake clock. [debugStoryAssumeLoaded] stands in for the
/// picture decoding — there is no network here, so no photo ever "loads".
class _FakeChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

class _FakeFeedApi extends Fake implements FeedApi {}

Moment _m(String id, {String userId = 'u1', MomentTag? tag}) => Moment(
  id: id,
  userId: userId,
  dayKey: '2026-10-04',
  createdAt: DateTime(2026, 10, 4, 9),
  expiresAt: DateTime(2026, 10, 5, 9),
  authorName: 'Ada',
  authorUsername: 'ada',
  mine: true,
  seen: true,
  caption: 'caption $id',
  tag: tag,
  mediaStorageId: tag == null ? 'blob_$id' : null,
  mediaKind: tag == null ? MomentMedia.image : MomentMedia.none,
);

Widget _host(
  List<Moment> run, {
  int start = 0,
  bool screenReader = false,
}) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(accessibleNavigation: screenReader),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showMomentViewer(
              context,
              moment: run[start],
              api: _FakeChatApi(),
              feedApi: _FakeFeedApi(),
              userId: 'u1',
              siblings: run,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => debugStoryAssumeLoaded = true);
  tearDown(() => debugStoryAssumeLoaded = false);

  /// Opens the viewer and lets the 200ms route transition and the "loaded"
  /// post-frame land, so the clock has just started.
  Future<void> open(WidgetTester tester, List<Moment> run, {int start = 0, bool screenReader = false}) async {
    await tester.pumpWidget(_host(run, start: start, screenReader: screenReader));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> wait(WidgetTester tester, Duration d) async {
    // In 100ms steps so the clock's ticker sees every frame.
    final steps = d.inMilliseconds ~/ 100;
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a photo advances by itself after 10 s', (tester) async {
    await open(tester, [_m('a'), _m('b')]);
    expect(find.text('caption a'), findsOneWidget);

    await wait(tester, const Duration(milliseconds: 9600));
    expect(find.text('caption a'), findsOneWidget);

    await wait(tester, const Duration(milliseconds: 800));
    expect(find.text('caption b'), findsOneWidget);
  });

  testWidgets('holding pauses: hold at 5 s, release at 8 s, advance at 13 s', (
    tester,
  ) async {
    await open(tester, [_m('a'), _m('b')]);
    await wait(tester, const Duration(seconds: 5));

    final hold = await tester.startGesture(const Offset(400, 300));
    await wait(tester, const Duration(seconds: 3));
    // Held: the chrome is cleared off the picture (offstage), the item stays.
    expect(find.text('caption a'), findsNothing);
    expect(find.text('caption a', skipOffstage: false), findsOneWidget);
    await hold.up();
    await tester.pump();
    expect(find.text('caption a'), findsOneWidget);

    // 5 s were left on the clock when the finger went down.
    await wait(tester, const Duration(milliseconds: 4600));
    expect(find.text('caption a'), findsOneWidget);
    await wait(tester, const Duration(milliseconds: 800));
    expect(find.text('caption b'), findsOneWidget);
  });

  testWidgets('a tap on the left goes back, on the right goes forward', (
    tester,
  ) async {
    await open(tester, [_m('a'), _m('b'), _m('c')], start: 1);
    expect(find.text('caption b'), findsOneWidget);

    await tester.tapAt(const Offset(800 * 0.8, 300));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('caption c'), findsOneWidget);

    await tester.tapAt(const Offset(800 * 0.2, 300));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('caption b'), findsOneWidget);
  });

  testWidgets('the end of the last run closes the viewer', (tester) async {
    await open(tester, [_m('a'), _m('b', userId: 'u2')], start: 1);
    expect(find.text('caption b'), findsOneWidget);

    await wait(tester, const Duration(milliseconds: 10400));
    await tester.pumpAndSettle();
    expect(find.text('caption b'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the end of one person moves on to the next person', (
    tester,
  ) async {
    await open(tester, [_m('a'), _m('b', userId: 'u2')]);
    await wait(tester, const Duration(milliseconds: 10400));
    // Not pumpAndSettle: the next person's clock is running, and settling
    // would play them out and close the viewer.
    await wait(tester, const Duration(milliseconds: 500));
    expect(find.text('caption b'), findsOneWidget);
  });

  testWidgets('a route pushed over the viewer pauses the clock', (
    tester,
  ) async {
    await open(tester, [_m('a'), _m('b')]);
    await wait(tester, const Duration(seconds: 2));

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const Text('over')));
    await tester.pumpAndSettle();
    await wait(tester, const Duration(seconds: 15));
    nav.pop();
    await wait(tester, const Duration(milliseconds: 500));

    // 2.5 s were spent before the push; 15 s under it must not count.
    expect(find.text('caption a'), findsOneWidget);
    await wait(tester, const Duration(seconds: 8));
    expect(find.text('caption b'), findsOneWidget);
  });

  testWidgets('with a screen reader nothing advances on its own', (
    tester,
  ) async {
    await open(tester, [_m('a'), _m('b')], screenReader: true);
    await wait(tester, const Duration(seconds: 20));
    expect(find.text('caption a'), findsOneWidget);
  });

  testWidgets('advancing never animates a glass surface', (tester) async {
    await open(tester, [_m('a'), _m('b')]);
    await wait(tester, const Duration(milliseconds: 9800));

    // Through the change of item, frame by frame: no BackdropFilter may sit
    // under a partial opacity — a fading glass surface re-blurs the photo on
    // every frame of the fade.
    for (var f = 0; f < 30; f++) {
      await tester.pump(const Duration(milliseconds: 16));
      for (final e in find.byType(BackdropFilter).evaluate()) {
        e.visitAncestorElements((a) {
          final w = a.widget;
          final o = w is Opacity
              ? w.opacity
              : w is FadeTransition
              ? w.opacity.value
              : 1.0;
          expect(
            o == 0 || o == 1,
            isTrue,
            reason: 'BackdropFilter under ${w.runtimeType} at opacity $o',
          );
          return true;
        });
      }
    }
    expect(find.text('caption b'), findsOneWidget);
  });

  test('every quick-reaction set has five, and 😮 is in all of them', () {
    for (final tag in [null, ...MomentTag.values]) {
      final set = quickReactionsFor(tag);
      expect(set, hasLength(5), reason: '$tag');
      expect(set, contains('😮'), reason: '$tag');
      expect(set.toSet(), hasLength(5), reason: '$tag has a duplicate');
    }
  });

  testWidgets('your own point: a trash top-right, no red Delete link', (
    tester,
  ) async {
    debugStoryAssumeLoaded = false;
    final point = _m('p', tag: MomentTag.jinx);
    await tester.pumpWidget(_host([point]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(SheetTrashButton), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.momentViewerDelete), findsNothing);
    final trash = tester.getCenter(find.byType(SheetTrashButton));
    final close = tester.getCenter(find.byType(SheetCloseButton));
    expect(trash.dx, greaterThan(close.dx));
    expect((trash.dy - close.dy).abs(), lessThan(1));
  });
}
