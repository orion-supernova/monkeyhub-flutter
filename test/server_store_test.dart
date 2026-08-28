import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/server_directory.dart';
import 'package:monkeyhub/backend/server_endpoint.dart';
import 'package:monkeyhub/backend/server_store.dart';

/// The recents list is the one piece of state here with a rule that is easy to
/// get subtly wrong: the server you just LEFT belongs in the history, the one
/// you just arrived at does not, and neither may appear twice. Getting it wrong
/// produces a list that grows a duplicate every time someone flips between two
/// boxes, which is exactly what the list is for.
void main() {
  const a = ServerEndpoint(deploymentUrl: 'https://a.example.com');
  final homeserver = KnownHosts.endpointFor(ServerRole.homeserver);
  const b = ServerEndpoint(deploymentUrl: 'https://b.example.com');
  const c = ServerEndpoint(deploymentUrl: 'https://c.example.com');

  final store = ServerStore.instance;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    store.resetForTest();
  });

  test('starts on the bundled default', () {
    expect(store.isCustom, isFalse);
    expect(store.custom, isNull);
    expect(store.recent, isEmpty);
  });

  test('the first custom server leaves the history empty', () async {
    // There is nothing to remember yet — the bundled default has its own card
    // and is never a history entry.
    await store.use(a);
    expect(store.isCustom, isTrue);
    expect(store.host, 'a.example.com');
    expect(store.recent, isEmpty);
  });

  test('the server being left goes to the front of the history', () async {
    await store.use(a);
    await store.use(b);
    expect(store.recent, [a]);
    await store.use(c);
    expect(store.recent, [b, a]);
  });

  test('flipping between two servers never duplicates either', () async {
    await store.use(a);
    await store.use(b);
    await store.use(a);
    await store.use(b);
    await store.use(a);
    expect(store.recent, [b]);
  });

  test('returning to the default remembers the server left behind', () async {
    await store.use(a);
    await store.useBundled();
    expect(store.isCustom, isFalse);
    expect(store.recent, [a]);
  });

  test('the history is capped, oldest first out', () async {
    for (var i = 0; i < ServerStore.maxRecent + 3; i++) {
      await store.use(ServerEndpoint(deploymentUrl: 'https://s$i.example.com'));
    }
    expect(store.recent.length, ServerStore.maxRecent);
    // Newest departure at the front; the earliest ones have fallen off.
    expect(store.recent.first.host, 's${ServerStore.maxRecent + 1}.example.com');
  });

  test('forgetting drops an entry and nothing else', () async {
    await store.use(a);
    await store.use(b);
    await store.use(c);
    expect(store.recent, [b, a]);
    await store.forget(a);
    expect(store.recent, [b]);
    // The active server is untouched — it was never in the list.
    expect(store.custom, c);
  });

  test('re-selecting the same server is a no-op, not a history entry',
      () async {
    await store.use(a);
    await store.use(a);
    expect(store.recent, isEmpty);
    expect(store.custom, a);
  });

  test('an override splits siteUrl from the deployment url', () async {
    const split = ServerEndpoint(
      deploymentUrl: 'https://a.example.com',
      siteUrlOverride: 'https://actions.example.com',
    );
    await store.use(split);
    expect(store.deploymentUrl, 'https://a.example.com');
    expect(store.siteUrl, 'https://actions.example.com');
  });

  test('two endpoints differing only by override are not the same server',
      () async {
    const split = ServerEndpoint(
      deploymentUrl: 'https://a.example.com',
      siteUrlOverride: 'https://actions.example.com',
    );
    await store.use(a);
    await store.use(split);
    // Same host, different routing — treating them as one would silently keep
    // the old HTTP-action origin after the user changed it.
    expect(store.recent, [a]);
    expect(store.siteUrl, 'https://actions.example.com');
  });

  group('who put this app on this server', () {
    // The address cannot answer it. An install the operator moved onto the home
    // server and an install whose owner typed that same address in are on the
    // same host, with the same URL — and must not behave alike: one is passing
    // through and gets taken home again, the other was chosen and stays.
    test('a followed server is not the user\'s, and follows directives',
        () async {
      await store.use(homeserver, pinned: false);
      expect(store.isPinned, isFalse);
      expect(store.role, ServerRole.homeserver);
      expect(store.followsDirectives, isTrue);
    });

    test('the same address, typed in, is the user\'s own server', () async {
      await store.use(homeserver);
      expect(store.isPinned, isTrue);
      // Self-hosted: chosen, therefore theirs to see and nobody's to move.
      expect(store.role, ServerRole.selfHosted);
      expect(store.isSelfHosted, isTrue);
      expect(store.followsDirectives, isFalse);
    });

    test('pinning changes nothing but the reason for being here', () async {
      await store.use(homeserver, pinned: false);
      await store.pin();
      expect(store.deploymentUrl, homeserver.deploymentUrl);
      expect(store.siteUrl, homeserver.siteUrl);
      expect(store.role, ServerRole.selfHosted);
      // Nowhere was left, so nothing joins the history.
      expect(store.recent, isEmpty);
    });

    test('arriving at the same address for a new reason is a change',
        () async {
      await store.use(homeserver, pinned: false);
      var beats = 0;
      void listener() => beats++;
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));
      await store.use(homeserver);
      expect(beats, 1);
      expect(store.isPinned, isTrue);
    });

    test('pinning the primary is possible and stops it following', () async {
      // Not a hypothetical: the ordinary address is exactly what someone
      // troubleshooting types in. It is still their choice, and a directive
      // must not override it.
      await store.use(KnownHosts.endpointFor(ServerRole.primary));
      expect(store.role, ServerRole.selfHosted);
      expect(store.followsDirectives, isFalse);
    });

    test('going back to the default is the way off a pin', () async {
      // Whatever was pinned — a private box or one of the operator's — the
      // bundled deployment is the ordinary arrangement, and an install on it is
      // governed like any other.
      for (final endpoint in [a, homeserver]) {
        await store.use(endpoint);
        expect(store.isPinned, isTrue, reason: endpoint.host);
        await store.useBundled();
        expect(store.isPinned, isFalse, reason: endpoint.host);
      }
    });
  });

  test('notifies on every change, so the badge and rows keep up', () async {
    var beats = 0;
    void listener() => beats++;
    store.addListener(listener);
    addTearDown(() => store.removeListener(listener));
    await store.use(a);
    await store.use(b);
    await store.useBundled();
    expect(beats, 3);
  });
}
