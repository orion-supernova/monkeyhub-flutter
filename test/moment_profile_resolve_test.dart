import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/data/profile_cache.dart';
import 'package:monkeyhub/data/profile_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_comment.dart';
import 'package:monkeyhub/models/moment_group.dart';
import 'package:monkeyhub/screens/feed/moment_viewer.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_reactions.dart';
import 'package:monkeyhub/widgets/moment_rail.dart';

/// What this pins: moment screens show the LIVE name and face from the profile
/// cache, with the copy stored on the row as the fallback, and "Deleted
/// account" for a tombstone.
class _Api extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

class _FeedApi extends Fake implements FeedApi {}

Map<String, dynamic> _row(String id, String name, {bool deleted = false}) => {
  'id': id,
  'name': name,
  'username': 'un_$id',
  if (deleted) 'deleted': true,
  'updatedAt': 1,
};

Future<ProfileCache> _cache(Map<String, Map<String, dynamic>?> server) async {
  final c = ProfileCache.forTest(
    fetch: (ids) async => [for (final id in ids) server[id]],
    subscribe: (ids, onData, onError) async => () {},
  );
  await c.attach('me');
  return c;
}

Moment _moment({bool mine = false}) => Moment(
  id: 'm1',
  userId: 'u1',
  dayKey: '2026-10-09',
  createdAt: DateTime(2026, 10, 9, 9),
  expiresAt: DateTime(2026, 10, 10, 9),
  authorName: 'Old Ann',
  authorUsername: 'old_ann',
  mine: mine,
  seen: true,
  caption: 'hello there',
);

Widget _app(ProfileCache? cache, Widget home) {
  final app = ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );
  return cache == null ? app : ProfileScope(cache: cache, child: app);
}

Future<void> _finish(WidgetTester tester, ProfileCache? cache) async {
  await tester.pumpWidget(const SizedBox());
  cache?.dispose();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  Widget rail(Moment m) => MomentRail(
    groups: MomentGroup.of([m]),
    api: _Api(),
    serverNow: DateTime(2026, 10, 9, 13),
    onCapture: () {},
    onOpen: (_) {},
  );

  testWidgets('an author rename shows on the rail', (tester) async {
    final cache = await _cache({'u1': _row('u1', 'New Ann')});
    await tester.pumpWidget(_app(cache, rail(_moment())));
    expect(find.text('Old Ann'), findsWidgets);
    await _settle(tester);
    expect(find.text('New Ann'), findsWidgets);
    expect(find.text('Old Ann'), findsNothing);
    await _finish(tester, cache);
  });

  testWidgets('an author rename shows in the viewer', (tester) async {
    final cache = await _cache({'u1': _row('u1', 'New Ann')});
    await tester.pumpWidget(
      ProfileScope(
        cache: cache,
        child: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showMomentViewer(
                    context,
                    moment: _moment(),
                    api: _Api(),
                    feedApi: _FeedApi(),
                    userId: 'me',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('New Ann'), findsWidgets);
    expect(find.text('Old Ann'), findsNothing);
    await _finish(tester, cache);
  });

  testWidgets('a reactor rename shows in the reactions sheet', (tester) async {
    final cache = await _cache({'r1': _row('r1', 'New Rae')});
    await tester.pumpWidget(
      _app(
        cache,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showMomentReactions(
              context,
              reactors: [
                MomentReactor(
                  emoji: '🔥',
                  userId: 'r1',
                  name: 'Old Rae',
                  username: 'old_rae',
                  createdAt: DateTime(2026, 10, 9),
                ),
              ],
              api: _Api(),
              viewerId: 'me',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _settle(tester);
    expect(find.text('New Rae'), findsWidgets);
    expect(find.text('Old Rae'), findsNothing);
    expect(find.text('@un_r1'), findsOneWidget);
    await _finish(tester, cache);
  });

  MomentComment comment() => MomentComment(
    id: 'c1',
    userId: 'u2',
    userName: 'Old Cem',
    createdAt: DateTime(2026, 10, 9),
    isAuthor: false,
    mine: false,
    canDelete: false,
    userAvatarStorageId: 'blob_copy',
  );

  Future<void> probe(
    WidgetTester tester,
    ProfileCache? cache,
    void Function(BuildContext) read,
  ) async {
    await tester.pumpWidget(
      _app(
        cache,
        Builder(
          builder: (context) {
            read(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('a comment author resolves, with the copy as fallback', (
    tester,
  ) async {
    final cache = await _cache({'u2': _row('u2', 'New Cem')});
    String? name;
    String? face;
    await probe(tester, cache, (c) {
      name = comment().nameIn(c);
      face = comment().avatarIn(c);
    });
    expect(name, 'New Cem');
    // The profile is known and has no face (access may be gone): the stale
    // copy must not resurface.
    expect(face, isNull);
    await _finish(tester, cache);
  });

  testWidgets('a tombstone reads Deleted account', (tester) async {
    final cache = await _cache({
      'u1': _row('u1', '', deleted: true),
      'u2': _row('u2', '', deleted: true),
    });
    String? name;
    String? author;
    await probe(tester, cache, (c) {
      name = comment().nameIn(c);
      author = _moment().nameIn(c);
    });
    expect(name, 'Deleted account');
    expect(author, 'Deleted account');
    await _finish(tester, cache);
  });

  testWidgets('without a scope the copy is shown', (tester) async {
    String? name;
    String? author;
    String? face;
    await probe(tester, null, (c) {
      name = comment().nameIn(c);
      author = _moment().nameIn(c);
      face = comment().avatarIn(c);
    });
    expect(name, 'Old Cem');
    expect(author, 'Old Ann');
    expect(face, 'blob_copy');
  });

  testWidgets('an unknown profile falls back to the copy', (tester) async {
    final cache = await _cache({});
    String? author;
    await probe(tester, cache, (c) => author = _moment().nameIn(c));
    expect(author, 'Old Ann');
    await _finish(tester, cache);
  });
}
