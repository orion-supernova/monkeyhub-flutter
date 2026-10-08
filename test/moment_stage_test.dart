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

class _FakeFeedApi extends Fake implements FeedApi {}

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
Widget _host({required Moment moment, List<Moment> siblings = const []}) =>
    ThemeScope(
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
                  feedApi: _FakeFeedApi(),
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
      _host(moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The stage is the only one of the two surfaces built out of a PageView.
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('the sunset'), findsOneWidget);
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
    await tester.pumpWidget(
      _host(moment: first, siblings: [first, second]),
    );
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
    final withPicture = _moment(id: 'm1', media: 'blob1', caption: 'the sunset');
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
      _host(moment: _moment(id: 'm1', media: 'blob1', caption: 'the sunset')),
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
      _host(moment: _moment(id: 'm2', media: 'blob2', caption: 'focus')),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a comment…'));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(field.focusNode.hasFocus, isTrue,
        reason: 'primary focus: ${FocusManager.instance.primaryFocus}');
  });

  testWidgets('a point card has the picker too', (tester) async {
    await tester.pumpWidget(
      _host(moment: _moment(id: 'p1', caption: 'npc behaviour', tag: MomentTag.npc)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
  });
}
