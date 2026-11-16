import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/screens/feed/moment_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// A highlight opened from a notification does not close while anything is
/// still unseen: forward wraps round to the people before the one it opened
/// on, where a tap on the rail only ever looks ahead. And each person's
/// "posted a highlight" banner is cleared once their last one is watched.

class _FakeChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

class _FakeFeedApi extends Fake implements FeedApi {
  final seen = <String>[];

  @override
  Future<void> markSeen({required String userId, required List<String> momentIds}) async => seen.addAll(momentIds);
}

Moment _m(String id, String userId, {bool seen = false}) => Moment(
  id: id,
  userId: userId,
  dayKey: '2026-08-28',
  createdAt: DateTime(2026, 8, 28, 9),
  expiresAt: DateTime(2026, 8, 29, 9),
  authorName: userId,
  authorUsername: userId,
  mine: false,
  seen: seen,
  mediaStorageId: 'blob_$id',
  mediaKind: MomentMedia.image,
);

Widget _host(Moment moment, List<Moment> siblings, _FakeFeedApi feed, {required bool catchUp}) => ThemeScope(
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
              feedApi: feed,
              userId: 'me',
              siblings: siblings,
              catchUp: catchUp,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

/// Forward, the way a thumb does it: a tap on the trailing side.
Future<void> _forward(WidgetTester tester) async {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await _settle(tester, () => tester.tapAt(Offset(size.width * .8, size.height * .5)));
}

/// A second of frames: past the route's fade and the cube turn, short of the
/// eight seconds after which an undecoded picture plays on by itself.
Future<void> _settle(WidgetTester tester, Future<void> Function() act) async {
  await act();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool _open(WidgetTester tester) => find.byType(PageView).evaluate().isNotEmpty;

void main() {
  final dismissed = <String>[];
  setUp(() {
    dismissed.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('monkeyhub/notifications'),
      (call) async {
        if (call.method == 'dismiss') {
          dismissed.addAll(((call.arguments as Map)['ids'] as List).cast<String>());
        }
        return null;
      },
    );
  });

  // The rail's order: ada, then bea (two), then cem.
  List<Moment> rail() => [_m('a1', 'ada'), _m('b1', 'bea'), _m('b2', 'bea'), _m('c1', 'cem')];

  testWidgets('from a notification: plays on to the people before, then closes', (tester) async {
    final feed = _FakeFeedApi();
    final all = rail();
    await tester.pumpWidget(_host(all[1], all, feed, catchUp: true));
    await _settle(tester, () => tester.tap(find.text('open')));
    expect(_open(tester), isTrue);

    await _forward(tester); // b1 -> b2
    await _forward(tester); // b2 -> c1
    expect(_open(tester), isTrue);
    await _forward(tester); // c1 -> wraps to a1
    expect(_open(tester), isTrue, reason: 'ada is still unseen');
    await _forward(tester); // nothing left
    await tester.pump(const Duration(seconds: 1));
    expect(_open(tester), isFalse);

    expect(feed.seen, ['b1', 'b2', 'c1', 'a1']);
    expect(dismissed.toSet(), {
      'friend_moment:bea:2026-08-28',
      'friend_moment:cem:2026-08-28',
      'friend_moment:ada:2026-08-28',
    });
  });

  testWidgets('from the rail: forward only looks ahead, as before', (tester) async {
    final feed = _FakeFeedApi();
    final all = rail();
    await tester.pumpWidget(_host(all[3], all, feed, catchUp: false));
    await _settle(tester, () => tester.tap(find.text('open')));
    expect(_open(tester), isTrue);

    await _forward(tester); // cem is last: closes
    await tester.pump(const Duration(seconds: 1));
    expect(_open(tester), isFalse);
    expect(feed.seen, ['c1']);
  });

  testWidgets('a banner stays while that person has one left unwatched', (tester) async {
    final feed = _FakeFeedApi();
    final all = rail();
    await tester.pumpWidget(_host(all[1], all, feed, catchUp: true));
    await _settle(tester, () => tester.tap(find.text('open')));
    expect(dismissed, isEmpty, reason: 'b2 is still waiting');
    await _forward(tester);
    expect(dismissed, ['friend_moment:bea:2026-08-28']);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
