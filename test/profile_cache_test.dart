import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/profile_cache.dart';
import 'package:monkeyhub/data/profile_scope.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

Map<String, dynamic> row(
  String id, {
  String name = 'Ann',
  String? avatar,
  int u = 1,
  bool deleted = false,
}) => {
  'id': id,
  'name': name,
  'username': 'un_$id',
  'avatarStorageId': ?avatar,
  if (deleted) 'deleted': true,
  'updatedAt': u,
};

class Harness {
  final List<List<String>> fetches = [];
  final List<List<String>> subs = [];
  final List<void Function(dynamic)> subData = [];
  var cancels = 0;
  Map<String, Map<String, dynamic>?> server = {};
  Object? fetchError;
  DateTime clockNow = DateTime(2026, 1, 1);

  late final ProfileCache cache = () {
    final c = ProfileCache.forTest(
      fetch: (ids) async {
        fetches.add(List.of(ids));
        if (fetchError != null) throw fetchError!;
        return [for (final id in ids) server[id]];
      },
      subscribe: (ids, onData, onError) async {
        subs.add(List.of(ids));
        subData.add(onData);
        return () => cancels++;
      },
    );
    c.now = () => clockNow;
    return c;
  }();
}

void main() {
  void tick(FakeAsync fa, Harness h, Duration d) {
    h.clockNow = h.clockNow.add(d);
    fa.elapse(d);
    fa.flushMicrotasks();
  }

  test('batch coalescing: one fetch for ids asked within 50 ms, deduped', () {
    fakeAsync((fa) {
      final h = Harness()
        ..server = {'a': row('a'), 'b': row('b', name: 'Bo'), 'c': row('c')};
      h.cache.attach('me');
      fa.flushMicrotasks();
      expect(h.cache.nameFor('a', fallback: 'copy'), 'copy');
      h.cache.nameFor('b');
      h.cache.nameFor('a'); // still queued: no second request
      tick(fa, h, const Duration(milliseconds: 20));
      h.cache.nameFor('c');
      expect(h.fetches, isEmpty);
      tick(fa, h, const Duration(milliseconds: 60));
      expect(h.fetches, hasLength(1));
      expect(h.fetches.single.toSet(), {'a', 'b', 'c'});
      expect(h.cache.nameFor('b', fallback: 'copy'), 'Bo');
      expect(h.cache.usernameFor('b'), 'un_b');
      // Known now: no more traffic.
      h.cache.nameFor('b');
      tick(fa, h, const Duration(seconds: 1));
      expect(h.fetches, hasLength(1));
    });
  });

  test('chunks of 100', () {
    fakeAsync((fa) {
      final h = Harness();
      h.cache.attach('me');
      fa.flushMicrotasks();
      for (var i = 0; i < 230; i++) {
        h.cache.nameFor('u$i');
      }
      tick(fa, h, const Duration(milliseconds: 60));
      expect(h.fetches.map((f) => f.length), [100, 100, 30]);
    });
  });

  test('negative cache: a null answer is not re-asked for 60 s', () {
    fakeAsync((fa) {
      final h = Harness(); // server knows nobody
      h.cache.attach('me');
      fa.flushMicrotasks();
      expect(h.cache.nameFor('x', fallback: 'copy'), 'copy');
      tick(fa, h, const Duration(milliseconds: 60));
      expect(h.fetches, hasLength(1));
      h.cache.nameFor('x');
      tick(fa, h, const Duration(seconds: 30));
      expect(h.fetches, hasLength(1));
      tick(fa, h, const Duration(seconds: 31));
      h.cache.nameFor('x');
      tick(fa, h, const Duration(milliseconds: 60));
      expect(h.fetches, hasLength(2));
    });
  });

  test('active ids subscribe once, deduped by key', () {
    fakeAsync((fa) {
      final h = Harness()..server = {'a': row('a'), 'b': row('b')};
      h.cache.attach('me');
      fa.flushMicrotasks();
      h.cache.nameFor('b');
      h.cache.nameFor('a');
      tick(fa, h, const Duration(milliseconds: 1100));
      expect(h.subs, [
        ['a', 'b'],
      ]);
      h.cache.nameFor('a'); // not new: nothing changes
      tick(fa, h, const Duration(seconds: 1));
      expect(h.subs, hasLength(1));
      expect(h.cancels, 0);
    });
  });

  test('active set caps at 100, newest first, and ages out after 60 s', () {
    fakeAsync((fa) {
      final h = Harness();
      h.cache.attach('me');
      fa.flushMicrotasks();
      for (var i = 0; i < 130; i++) {
        h.cache.nameFor('u$i');
      }
      tick(fa, h, const Duration(milliseconds: 1100));
      expect(h.subs.single, hasLength(100));
      expect(h.subs.single, contains('u129'));
      expect(h.subs.single, isNot(contains('u0')));
      tick(fa, h, const Duration(seconds: 75));
      expect(h.cancels, 1);
      expect(h.cache.subscribedIds, isEmpty);
    });
  });

  test('a changed u refetches only that id', () {
    fakeAsync((fa) {
      final h = Harness()
        ..server = {'a': row('a', u: 1), 'b': row('b', name: 'Bo', u: 1)};
      h.cache.attach('me');
      fa.flushMicrotasks();
      h.cache.nameFor('a');
      h.cache.nameFor('b');
      tick(fa, h, const Duration(milliseconds: 1100));
      h.fetches.clear();

      // Same versions: nothing.
      h.subData.last([
        {'id': 'a', 'u': 1, 'av': false},
        {'id': 'b', 'u': 1, 'av': false},
      ]);
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.fetches, isEmpty);

      h.server['a'] = row('a', name: 'Anna', u: 2);
      h.subData.last([
        {'id': 'a', 'u': 2, 'av': false},
        {'id': 'b', 'u': 1, 'av': false},
      ]);
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.fetches, [
        ['a'],
      ]);
      expect(h.cache.nameFor('a'), 'Anna');
      expect(h.cache.nameFor('b'), 'Bo');
    });
  });

  test('an av flip refetches even when u is unchanged', () {
    fakeAsync((fa) {
      final h = Harness()..server = {'a': row('a', u: 5)};
      h.cache.attach('me');
      fa.flushMicrotasks();
      h.cache.avatarFor('a');
      tick(fa, h, const Duration(milliseconds: 1100));
      expect(h.cache.avatarFor('a'), isNull);
      h.fetches.clear();

      h.server['a'] = row('a', u: 5, avatar: 'blob1');
      h.subData.last([
        {'id': 'a', 'u': 5, 'av': true},
      ]);
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.fetches, [
        ['a'],
      ]);
      expect(h.cache.avatarFor('a'), 'blob1');
    });
  });

  test('versions bypass the negative cache for a changed id', () {
    fakeAsync((fa) {
      final h = Harness();
      h.cache.attach('me');
      fa.flushMicrotasks();
      h.cache.nameFor('a');
      tick(fa, h, const Duration(milliseconds: 1100));
      expect(h.fetches, hasLength(1)); // null: negative cached
      h.server['a'] = row('a', u: 3);
      h.subData.last([
        {'id': 'a', 'u': 3, 'av': false},
      ]);
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.fetches, hasLength(2));
      expect(h.cache.nameFor('a'), 'Ann');
    });
  });

  test('fallback: unknown, empty name, and no scope all use the copy', () {
    fakeAsync((fa) {
      final h = Harness()..server = {'e': row('e', name: '')};
      expect(h.cache.nameFor('a', fallback: 'copy'), 'copy'); // unattached
      h.cache.attach('me');
      fa.flushMicrotasks();
      expect(h.cache.nameFor('a', fallback: 'copy'), 'copy');
      expect(h.cache.avatarFor('a', fallback: 'old'), 'old');
      h.cache.nameFor('e');
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.cache.nameFor('e', fallback: 'copy'), 'copy');
    });
  });

  test('legacy mode: function not found stops fetching and subscribing', () {
    fakeAsync((fa) {
      final h = Harness()
        ..fetchError = Exception('Could not find public function for profiles:get');
      h.cache.attach('me');
      fa.flushMicrotasks();
      expect(h.cache.nameFor('a', fallback: 'copy'), 'copy');
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.cache.legacy, isTrue);
      h.cache.nameFor('b');
      h.cache.nameFor('c');
      tick(fa, h, const Duration(seconds: 2));
      expect(h.fetches, hasLength(1));
      expect(h.subs, isEmpty);
      expect(h.cache.nameFor('a', fallback: 'copy'), 'copy');
      h.cache.clear();
      expect(h.cache.legacy, isFalse);
    });
  });

  test('legacy mode from the versions subscription too', () {
    fakeAsync((fa) {
      final h = Harness();
      final c = ProfileCache.forTest(
        fetch: (ids) async => [for (final _ in ids) null],
        subscribe: (ids, onData, onError) async {
          onError(Exception('function not found'));
          return () {};
        },
      );
      c.attach('me');
      fa.flushMicrotasks();
      c.nameFor('a');
      fa.elapse(const Duration(milliseconds: 1100));
      fa.flushMicrotasks();
      expect(c.legacy, isTrue);
      expect(h.fetches, isEmpty);
    });
  });

  test('LRU keeps the 2000 most recently used', () {
    fakeAsync((fa) {
      final h = Harness();
      for (var i = 0; i < 2100; i++) {
        h.server['u$i'] = row('u$i', name: 'N$i');
      }
      h.cache.attach('me');
      fa.flushMicrotasks();
      for (var i = 0; i < 2100; i++) {
        h.cache.nameFor('u$i');
      }
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.cache.length, 2000);
      expect(h.cache.peek('u0'), isNull);
      expect(h.cache.peek('u99'), isNull);
      expect(h.cache.peek('u100'), isNotNull);
      expect(h.cache.peek('u2099'), isNotNull);
    });
  });

  test('tombstone ignores the copied handle and face', () {
    fakeAsync((fa) {
      final h = Harness()..server = {'g': row('g', deleted: true, avatar: 'x')};
      h.cache.attach('me');
      fa.flushMicrotasks();
      h.cache.nameFor('g');
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.cache.isDeleted('g'), isTrue);
      expect(h.cache.avatarFor('g', fallback: 'old'), isNull);
      expect(h.cache.usernameFor('g', fallback: '@old'), '');
    });
  });

  test('a known profile without an avatar beats the copied face', () {
    fakeAsync((fa) {
      final h = Harness()..server = {'a': row('a')};
      h.cache.attach('me');
      fa.flushMicrotasks();
      expect(h.cache.avatarFor('a', fallback: 'old'), 'old'); // unknown yet
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.cache.avatarFor('a', fallback: 'old'), isNull);
    });
  });

  test('a failed refetch is retried on the next version delivery', () {
    fakeAsync((fa) {
      final h = Harness()..server = {'a': row('a', avatar: 'b1', u: 1)};
      h.cache.attach('me');
      fa.flushMicrotasks();
      h.cache.avatarFor('a');
      tick(fa, h, const Duration(milliseconds: 1100));
      h.fetches.clear();
      h.fetchError = Exception('network');
      h.subData.last([
        {'id': 'a', 'u': 2, 'av': false},
      ]);
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.fetches, hasLength(1));
      expect(h.cache.avatarFor('a'), 'b1'); // old face while it failed
      h.fetchError = null;
      h.server['a'] = row('a', u: 2);
      h.subData.last([
        {'id': 'a', 'u': 2, 'av': false},
      ]);
      tick(fa, h, const Duration(milliseconds: 100));
      expect(h.fetches, hasLength(2));
      expect(h.cache.avatarFor('a'), isNull);
    });
  });

  test('scrolling many new ids batches resubscribes to about one a second', () {
    fakeAsync((fa) {
      final h = Harness();
      h.cache.attach('me');
      fa.flushMicrotasks();
      for (var i = 0; i < 50; i++) {
        h.cache.nameFor('u$i');
        tick(fa, h, const Duration(milliseconds: 100));
      }
      tick(fa, h, const Duration(seconds: 2));
      expect(h.subs.length, lessThanOrEqualTo(7));
      expect(h.subs.last, hasLength(50));
      expect(h.fetches.expand((f) => f).toSet(), hasLength(50));
    });
  });

  test('disk round trip, per user, schema-versioned', () async {
    final tmp = await Directory.systemTemp.createTemp('profcache');
    addTearDown(() => tmp.delete(recursive: true));
    final h = Harness()..server = {'a': row('a', name: 'Anna', avatar: 'blob', u: 7)};
    ProfileCache make() => ProfileCache.forTest(
      fetch: (ids) async => [for (final id in ids) h.server[id]],
      subscribe: (ids, onData, onError) async => () {},
      dir: () async => tmp,
    );

    final c1 = make();
    await c1.attach('me');
    c1.nameFor('a');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(c1.peek('a')?.name, 'Anna');
    await c1.flush();
    c1.clear();

    final file = File('${tmp.path}/cache/me/profiles.json');
    expect(file.existsSync(), isTrue);
    final json = jsonDecode(file.readAsStringSync()) as Map;
    expect(json['v'], ProfileCache.schemaVersion);
    expect((json['p'] as Map)['a'], containsPair('n', 'Anna'));

    final c2 = make();
    await c2.attach('me');
    expect(c2.peek('a')?.name, 'Anna');
    expect(c2.peek('a')?.avatarStorageId, 'blob');
    expect(c2.peek('a')?.updatedAt, 7);
    c2.clear();

    // Another user sees nothing of it.
    final c3 = make();
    await c3.attach('someone-else');
    expect(c3.peek('a'), isNull);
    c3.clear();

    // A future schema version is ignored, not misread.
    file.writeAsStringSync(jsonEncode({'v': 99, 'p': json['p']}));
    final c4 = make();
    await c4.attach('me');
    expect(c4.peek('a'), isNull);
    c4.clear();

    // Garbage is ignored.
    file.writeAsStringSync('{not json');
    final c5 = make();
    await c5.attach('me');
    expect(c5.length, 0);
    c5.clear();
  });

  testWidgets('a tombstone reads "Deleted account"; others read the profile',
      (tester) async {
    final h = Harness()
      ..server = {
        'gone': row('gone', name: 'Old Name', deleted: true),
        'live': row('live', name: 'Livia'),
      };
    await h.cache.attach('me');
    late BuildContext ctx;
    await tester.pumpWidget(
      ProfileScope(
        cache: h.cache,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (c) {
              ctx = c;
              return Text(
                '${c.profileName('gone', fallback: 'copy')}|'
                '${c.profileName('live', fallback: 'copy')}|'
                '${c.profileName('nobody')}',
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('copy|copy|…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Deleted account|Livia|…'), findsOneWidget);
    expect(ctx.profileAvatar('live', fallback: 'x'), isNull);
    expect(ctx.profileAvatar('nobody', fallback: 'x'), 'x');
    h.cache.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
