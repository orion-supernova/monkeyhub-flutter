import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/screens/feed/moment_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_comments_sheet.dart';
import 'package:monkeyhub/widgets/reaction_picker_sheet.dart';

/// What this pins: which surface a moment opens on, and that the run comes with
/// it.
///
/// `showMomentViewer` has to make one decision — full-screen stage or card —
/// and it makes it from the moment itself rather than from anything the caller
/// says. A highlight is a photograph and deserves the whole screen; a point is
/// a sentence and blowing one line of text up to fill a phone would be absurd.
/// Getting that backwards is invisible to the analyzer and obvious to a user,
/// which is exactly the kind of thing worth a test.
///
/// The second half is the swipe. Opening a highlight used to be a dead end:
/// you looked at one picture and backed out to tap the tile beside it. The
/// siblings the caller hands in become pages, and the ones with nothing to look
/// at are filtered out of them — a caption-only card in the middle of the rail
/// is a legitimate page of *nothing*, and swiping onto it reads as the gallery
/// having broken.

/// Resolves every storage id to null, which [RemoteImage] renders as its broken
/// tile. That is the point: no HTTP, no image codec, and the layout under test
/// is identical either way.
class _FakeChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

class _FakeFeedApi extends Fake implements FeedApi {
  final sent = <String>[];

  @override
  Future<void> react({
    required String userId,
    required String momentId,
    required String emoji,
  }) async => sent.add('+$emoji');

  @override
  Future<void> unreact({
    required String userId,
    required String momentId,
    required String emoji,
  }) async => sent.add('-$emoji');
}

Moment _moment({
  required String id,
  String? media,
  String? caption,
  MomentTag? tag,
  String userId = 'u1',
}) => Moment(
  id: id,
  userId: userId,
  dayKey: '2026-08-28',
  createdAt: DateTime(2026, 8, 28, 9),
  expiresAt: DateTime(2026, 8, 29, 9),
  authorName: 'Ada',
  authorUsername: 'ada',
  // Mine and seen: `markSeen` on someone else's unseen moment would reach the
  // fake API, and none of this is about the read receipt.
  mine: true,
  seen: true,
  caption: caption,
  tag: tag,
  mediaStorageId: media,
  mediaKind: media == null ? MomentMedia.none : MomentMedia.image,
);

/// ThemeScope sits ABOVE MaterialApp because the viewer is a route on the app's
/// own Navigator.
Widget _host({
  required Moment moment,
  List<Moment> siblings = const [],
  _FakeFeedApi? feedApi,
}) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showMomentViewer(
              context,
              moment: moment,
              api: _FakeChatApi(),
              feedApi: feedApi ?? _FakeFeedApi(),
              userId: 'u1',
              siblings: siblings,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a highlight with a picture opens full-screen', (tester) async {
    await tester.pumpWidget(
      _host(
        moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The stage is the only one of the two surfaces built out of a PageView.
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('the sunset'), findsOneWidget);
  });

  testWidgets('the photo viewport stays fixed when a pinch begins', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final viewer = find.byType(InteractiveViewer);
    final initialRect = tester.getRect(viewer);
    final center = initialRect.center;
    final first = await tester.startGesture(center - const Offset(50, 0));
    await tester.pump();
    final second = await tester.startGesture(center + const Offset(50, 0));
    await tester.pump();

    expect(tester.getRect(viewer), initialRect);

    await first.up();
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a pinch spreads over the whole screen, then settles back to '
      'the card', (tester) async {
    await tester.pumpWidget(
      _host(
        moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final viewer = find.byType(InteractiveViewer);
    // The zoom box is the whole screen, status bar and comment bar included,
    // even though the picture rests in the card between them.
    expect(tester.getRect(viewer), Offset.zero & screen);

    ClipRRect cardClip() => tester.widget<ClipRRect>(
      find.byWidgetPredicate(
        (w) => w is ClipRRect && w.clipper.runtimeType.toString() == '_CardClip',
      ),
    );
    expect(cardClip().clipBehavior, Clip.antiAlias);

    final center = tester.getRect(viewer).center;
    final first = await tester.startGesture(center - const Offset(30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();
    await first.moveBy(const Offset(-80, 0));
    await second.moveBy(const Offset(80, 0));
    await tester.pump();

    // Zoomed: the card's clip is lifted so the picture lies over the bars.
    expect(cardClip().clipBehavior, Clip.none);

    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    // Let go: it returns to the card on its own.
    expect(cardClip().clipBehavior, Clip.antiAlias);
  });

  testWidgets('the board is put away while the stage is still, and comes back '
      'for a drag and a close', (tester) async {
    await tester.pumpWidget(
      _host(moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.pump();

    final route = ModalRoute.of(tester.element(find.byType(PageView)))!;
    // Landed and still: nothing of the board beneath can be seen.
    expect(route.overlayEntries.first.opaque, isTrue);

    // A dismiss drag needs the board to show through the fading scrim.
    final g = await tester.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(0, 40));
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(route.overlayEntries.first.opaque, isFalse);

    // Let go short of the threshold: it springs back and the board goes again.
    await g.up();
    await tester.pumpAndSettle();
    await tester.pump();
    expect(route.overlayEntries.first.opaque, isTrue);

    // Closing hands the board back for the flight home.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    expect(route.overlayEntries.first.opaque, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('the bars stay on their edges, and follow a dismiss drag down', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.pump();

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final close = find.byIcon(CupertinoIcons.xmark);
    final caption = find.text('the sunset');
    // Top bar near the top, caption in the lower half: neither stretched to
    // fill the screen.
    expect(tester.getCenter(close).dy, lessThan(screen.height * 0.2));
    expect(tester.getCenter(caption).dy, greaterThan(screen.height * 0.6));

    final closeAt = tester.getCenter(close).dy;
    final captionAt = tester.getCenter(caption).dy;
    final g = await tester.startGesture(const Offset(200, 400));
    await g.moveBy(const Offset(0, 40));
    await g.moveBy(const Offset(0, 40));
    await tester.pump();
    // They travel with the picture rather than waiting behind it.
    expect(tester.getCenter(close).dy, greaterThan(closeAt + 40));
    expect(tester.getCenter(caption).dy, greaterThan(captionAt + 40));

    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getCenter(close).dy, closeAt);
  });

  testWidgets('the bars wait for the picture to land, and leave as it goes '
      'home', (tester) async {
    await tester.pumpWidget(
      _host(moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset')),
    );
    // How present the bars are, counting only the stage's own opacity: the
    // route's fade is a `FadeTransition`, and it is not what is under test.
    double present() {
      final close = find.byIcon(CupertinoIcons.xmark);
      if (close.evaluate().isEmpty) return 0;
      var o = 1.0;
      tester.element(close).visitAncestorElements((e) {
        final w = e.widget;
        if (w is Opacity) o *= w.opacity;
        return true;
      });
      return o;
    }

    await tester.tap(find.text('open'));
    await tester.pump();
    // Mid-flight the picture is crossing the screen over the page, so showing
    // the bars now would have them swallowed by it and shown again.
    await tester.pump(const Duration(milliseconds: 100));
    expect(present(), 0);
    await tester.pump(const Duration(milliseconds: 90));
    expect(present(), 0);

    // Landed: they come in.
    await tester.pumpAndSettle();
    expect(present(), 1);

    // A close takes them away at once, not after the route has finished.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(present(), 0);
    await tester.pumpAndSettle();
  });

  testWidgets('a hold fades every bar away, the progress bar too, and a '
      'release fades them back', (tester) async {
    await tester.pumpWidget(
      _host(moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The stage's own opacity over a widget; the route's fade is a
    // `FadeTransition` and is not counted.
    double present(Finder f) {
      expect(f, findsOneWidget);
      var o = 1.0;
      tester.element(f).visitAncestorElements((e) {
        final w = e.widget;
        if (w is Opacity) o *= w.opacity;
        return true;
      });
      return o;
    }

    final progress = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_StoryProgress',
    );
    final close = find.byIcon(CupertinoIcons.xmark);
    final comment = find.text('the sunset');
    final all = [progress, close, comment];
    for (final f in all) {
      expect(present(f), 1);
    }

    final g = await tester.startGesture(const Offset(200, 400));
    // Past the hold threshold, then partway through the fade: neither cut nor
    // finished.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 60));
    for (final f in all) {
      expect(present(f), allOf(greaterThan(0), lessThan(1)));
    }
    await tester.pump(const Duration(milliseconds: 300));
    for (final f in all) {
      expect(present(f), 0);
    }

    await g.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    for (final f in all) {
      expect(present(f), allOf(greaterThan(0), lessThan(1)));
    }
    await tester.pumpAndSettle();
    for (final f in all) {
      expect(present(f), 1);
    }
  });

  testWidgets('a point with no picture opens as a card', (tester) async {
    await tester.pumpWidget(
      _host(
        moment: _moment(
          id: 'p1',
          caption: 'washed the car, it rained at four',
          tag: MomentTag.jinx,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(find.text('washed the car, it rained at four'), findsOneWidget);
  });

  // Stories: a sideways swipe moves to the next PERSON. (Moving through one
  // person's pictures is a tap — see moment_story_test.dart.)
  testWidgets('the next person is one swipe away', (tester) async {
    final first = _moment(id: 'm1', media: 'blob1', caption: 'the sunset');
    final second = _moment(
      id: 'm2',
      media: 'blob2',
      caption: 'the cat',
      userId: 'u2',
    );
    await tester.pumpWidget(_host(moment: first, siblings: [first, second]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('the sunset'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('the cat'), findsOneWidget);
  });

  testWidgets('caption-only siblings are not pages you can swipe onto', (
    tester,
  ) async {
    final withPicture = _moment(
      id: 'm1',
      media: 'blob1',
      caption: 'the sunset',
    );
    final wordsOnly = _moment(id: 'm2', caption: 'no picture, just words');
    await tester.pumpWidget(
      _host(moment: withPicture, siblings: [withPicture, wordsOnly]),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('no picture, just words'), findsNothing);
    expect(find.text('the sunset'), findsOneWidget);
  });

  // Five quick reactions are the whole vocabulary; the full picker is one
  // tap past them on both surfaces.
  testWidgets('both surfaces offer the full emoji picker', (tester) async {
    await tester.pumpWidget(
      _host(
        moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // The comment bar opens the reply mode; the full picker is its big +.
    await tester.tap(find.text('Add a comment…'));
    await tester.pumpAndSettle();
    expect(find.byType(MomentCommentComposer), findsOneWidget);
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    expect(find.byType(ReactionPickerSheet), findsOneWidget);
  });

  // Tapping the story's comment bar opens the reply mode WITH the keyboard:
  // the composer's field holds focus without a second tap.
  testWidgets('the comment bar focuses the composer', (tester) async {
    await tester.pumpWidget(
      _host(
        moment: _moment(id: 'm2', media: 'blob2', caption: 'focus'),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a comment…'));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(
      field.focusNode.hasFocus,
      isTrue,
      reason: 'primary focus: ${FocusManager.instance.primaryFocus}',
    );
  });

  testWidgets('a point card has the picker too', (tester) async {
    await tester.pumpWidget(
      _host(
        moment: _moment(id: 'p1', caption: 'npc behaviour', tag: MomentTag.npc),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
  });

  testWidgets('a reaction lands, and is taken back from who reacted', (
    tester,
  ) async {
    // Every reaction change runs through one notifier that also feeds an
    // open who-reacted sheet; it once called itself and overflowed the stack
    // on the first tap.
    final feed = _FakeFeedApi();
    await tester.pumpWidget(
      _host(
        moment: _moment(id: 'p1', caption: 'npc behaviour', tag: MomentTag.npc),
        feedApi: feed,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🤖'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(feed.sent, ['+🤖']);

    await tester.longPress(find.text('🤖'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove yours'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(feed.sent, ['+🤖', '-🤖']);
    // It was the only reaction, so the sheet went with it; the card stays.
    expect(find.text('Remove yours'), findsNothing);
    expect(find.text('Add yours'), findsNothing);
    expect(find.text('🤖'), findsOneWidget);
  });
}
