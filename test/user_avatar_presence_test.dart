import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/presence_store.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

Widget _host(Widget child) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

/// The dot is the only circle-decorated Container the avatar draws without
/// an image; counting them is enough to tell whether it is there.
Finder _dot() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle &&
      (w.decoration as BoxDecoration).border != null,
);

/// A widget test that leaves no presence timers behind: the binding checks for
/// pending timers before any tearDown runs, so the unmount and the store's
/// clear happen inside the test.
void avatarTest(
  String name,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    store.clear();
    for (final s in extraStores) {
      s.clear();
    }
  });
}

late PresenceStore store;
final extraStores = <PresenceStore>[];

void main() {
  final online = ChatUser(
    id: 'bea',
    username: 'bea',
    name: 'Bea',
    status: 'online',
  );

  late List<void Function(dynamic)> feeds;
  late List<bool> cancelled;
  late List<List<String>> asked;

  // Every avatar in this file leases from a private store, so none of them
  // arms the singleton's timers or reaches for a backend.
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await SettingsStore.instance.setShowPresenceDots(true);
    feeds = [];
    cancelled = [];
    asked = [];
    store = PresenceStore.forTest((ids, onData, onError) async {
      asked.add(ids);
      feeds.add(onData);
      final i = cancelled.length;
      cancelled.add(false);
      return () => cancelled[i] = true;
    });
    presenceStoreForWidgets = store;
  });

  tearDown(() {
    extraStores.clear();
    presenceStoreForWidgets = null;
  });

  avatarTest('the Settings toggle reaches a const avatar without a rebuild',
      (tester) async {
    await tester.pumpWidget(_host(UserAvatar(user: online)));
    expect(_dot(), findsOneWidget);

    await SettingsStore.instance.setShowPresenceDots(false);
    await tester.pump();
    expect(_dot(), findsNothing);

    await SettingsStore.instance.setShowPresenceDots(true);
    await tester.pump();
    expect(_dot(), findsOneWidget);
  });

  avatarTest('showStatus: false still wins with the setting on',
      (tester) async {
    await tester.pumpWidget(
      _host(UserAvatar(user: online, showStatus: false)),
    );
    expect(_dot(), findsNothing);
  });

  group('store-driven dot', () {
    Color? dotColor(WidgetTester tester) {
      final f = _dot();
      if (f.evaluate().isEmpty) return null;
      final c = tester.widget<Container>(f);
      return (c.decoration as BoxDecoration).color;
    }

    avatarTest('follows store updates without remounting the face',
        (tester) async {
      final key = GlobalKey();
      final user = ChatUser(id: 'bea', username: 'bea', name: 'Bea');
      await tester.pumpWidget(
        _host(KeyedSubtree(key: key, child: UserAvatar(user: user))),
      );
      // Nothing known and no legacy status: no dot yet.
      expect(_dot(), findsNothing);
      final face = tester.element(find.text('B'));

      await tester.pump(const Duration(milliseconds: 300));
      expect(asked.single, ['bea']);

      feeds.last([
        {'id': 'bea', 's': 'online', 'ls': DateTime.now().millisecondsSinceEpoch},
      ]);
      await tester.pump();
      final online = dotColor(tester);
      expect(online, isNotNull);

      feeds.last([
        {'id': 'bea', 's': 'offline', 'ls': 1},
      ]);
      await tester.pump();
      final offline = dotColor(tester);
      expect(offline, isNotNull);
      expect(offline, isNot(online));

      // Same element: the Stack and the face were never rebuilt from scratch.
      expect(tester.element(find.text('B')), same(face));
    });

    avatarTest('a store value beats user.status; unknown falls back to it',
        (tester) async {
      await tester.pumpWidget(_host(UserAvatar(user: online)));
      final fallback = dotColor(tester);
      expect(fallback, isNotNull);

      await tester.pump(const Duration(milliseconds: 300));
      feeds.last([
        {'id': 'bea', 's': 'offline', 'ls': 1},
      ]);
      await tester.pump();
      expect(dotColor(tester), isNot(fallback));
    });

    avatarTest('legacy mode reads user.status and takes no lease',
        (tester) async {
      await tester.pumpWidget(_host(UserAvatar(user: online)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(asked, hasLength(1));

      // The server turns out to have no presenceApi.
      final legacyStore = PresenceStore.forTest((ids, onData, onError) async {
        onError(Exception('Could not find public function for presenceApi'));
        return () {};
      });
      presenceStoreForWidgets = legacyStore;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(UserAvatar(user: online, size: 41)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(legacyStore.legacy, isTrue);
      expect(dotColor(tester), isNotNull);
      extraStores.add(legacyStore);
    });

    avatarTest('releases the lease on dispose', (tester) async {
      await tester.pumpWidget(_host(UserAvatar(user: online)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.subscribedIds, {'bea'});

      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pump(const Duration(seconds: 4));
      expect(store.subscribedIds, isEmpty);
      expect(cancelled.single, isTrue);
    });

    avatarTest('re-leases when the id changes', (tester) async {
      await tester.pumpWidget(_host(UserAvatar(user: online)));
      await tester.pump(const Duration(milliseconds: 300));
      final cal = ChatUser(id: 'cal', username: 'cal', name: 'Cal');
      await tester.pumpWidget(_host(UserAvatar(user: cal)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.subscribedIds, contains('cal'));
      await tester.pump(const Duration(seconds: 4));
      expect(store.subscribedIds, {'cal'});
    });
  });
}
