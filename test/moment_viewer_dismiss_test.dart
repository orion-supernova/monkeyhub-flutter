import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/screens/feed/moment_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// What this pins: the moment viewer can be swiped away.
///
/// The close button sits in the card's top-right corner, which on a modern
/// phone is the one place a thumb cannot reach one-handed — so the gesture is
/// not a nicety, it is the primary way out and the button is the fallback. Two
/// things have historically broken it and neither is loud:
///
///  * the card growing past the viewport, which hands every vertical drag to
///    the scroll view and leaves the gesture silently dead; and
///  * a threshold low enough that a flick meant to scroll the card's caption
///    closes the whole thing instead.
///
/// So both halves are pinned: a real drag dismisses, a small one does not.
class _FakeChatApi extends Fake implements ChatApi {}

class _FakeFeedApi extends Fake implements FeedApi {}

Moment _moment() => Moment(
  id: 'm1',
  userId: 'u1',
  dayKey: '2026-08-08',
  createdAt: DateTime(2026, 8, 8, 9),
  expiresAt: DateTime(2026, 8, 9, 9),
  authorName: 'Ada',
  authorUsername: 'ada',
  // Mine and seen: `markSeen` on someone else's unseen moment would reach the
  // fake API, and this test is about the gesture, not the read receipt.
  mine: true,
  seen: true,
  caption: 'the car wash worked',
);

/// A host whose button opens the viewer. ThemeScope sits ABOVE MaterialApp
/// because the viewer is a route on the app's Navigator.
Widget _host({Rect? origin}) => ThemeScope(
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
              moment: _moment(),
              api: _FakeChatApi(),
              feedApi: _FakeFeedApi(),
              userId: 'u1',
              origin: origin,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  Future<void> open(WidgetTester tester, {Rect? origin}) async {
    await tester.pumpWidget(_host(origin: origin));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('the car wash worked'), findsOneWidget);
  }

  testWidgets('a downward drag on the card closes the viewer', (tester) async {
    await open(tester);

    await tester.fling(
      find.text('the car wash worked'),
      const Offset(0, 240),
      900,
    );
    await tester.pumpAndSettle();

    expect(find.text('the car wash worked'), findsNothing);
  });

  testWidgets('a drag on the scrim closes it too — the card is the hard part '
      'to reach', (tester) async {
    await open(tester);

    // Well outside the card: the top-left corner of the screen is scrim.
    await tester.flingFrom(const Offset(20, 20), const Offset(0, 240), 900);
    await tester.pumpAndSettle();

    expect(find.text('the car wash worked'), findsNothing);
  });

  testWidgets('a short drag springs back rather than dismissing', (
    tester,
  ) async {
    await open(tester);

    // Slow and short — under both the distance threshold and the fling
    // velocity, which is the shape of a hesitant touch, not a dismissal.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('the car wash worked')),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 6));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('the car wash worked'), findsOneWidget);
  });

  testWidgets('an upward drag closes it as well', (tester) async {
    await open(tester);

    await tester.fling(
      find.text('the car wash worked'),
      const Offset(0, -240),
      900,
    );
    await tester.pumpAndSettle();

    expect(find.text('the car wash worked'), findsNothing);
  });

  testWidgets('opened from a row, the card still lands where it belongs', (
    tester,
  ) async {
    // An origin rect drives the entrance transform. Whatever it does on the way
    // in, the card has to come to rest untransformed — a lerp that does not
    // finish at identity leaves the viewer permanently offset.
    await open(tester, origin: const Rect.fromLTWH(10, 600, 300, 40));
    final fromRow = tester.getRect(find.text('the car wash worked'));

    // Close it before opening the plain one — a `pumpWidget` leaves the route
    // stack alone, so without this the second `open` would tap the viewer's own
    // scrim and measure the first card all over again.
    await tester.fling(
      find.text('the car wash worked'),
      const Offset(0, 240),
      900,
    );
    await tester.pumpAndSettle();
    await open(tester);

    expect(tester.getRect(find.text('the car wash worked')), fromRow);
  });
}
