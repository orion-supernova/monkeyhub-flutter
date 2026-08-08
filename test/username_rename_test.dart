import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/username_availability_controller.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/mention.dart';
import 'package:monkeyhub/screens/profile_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Guards the claims that made changing a username safe to ship.
///
/// The audit that preceded the feature found nothing in the app relating users
/// by handle — every table and every client cache keys on `userId`. Two things
/// were nonetheless load-bearing enough to pin down here, because both are the
/// kind that break silently:
///
///  * an @-mention written before a rename must go on resolving afterwards, and
///  * the two self-only fields the rename gate reads must survive `copyWith`,
///    which ProfileScreen calls on every refresh.
///
/// ANTI-HANG DISCIPLINE — nothing here touches the network. The widget test
/// passes null for `api`/`repo`/`auth`, which is exactly the combination that
/// makes ProfileScreen's `_refresh` and `_refreshLinkedProviders` no-op.
void main() {
  group('a rename does not break older @-mentions', () {
    // The message as it was written: the text says @oldname, and the array the
    // server built at send time agrees.
    final sent = ChatMessage(
      id: 'm1',
      roomId: 'r1',
      senderId: 'u2',
      senderName: 'Someone',
      content: 'morning @oldname, ready?',
      createdAt: DateTime(2026, 1, 1),
      mentions: const [MessageMention(userId: 'u1', username: 'oldname')],
    );

    test('the handle in the text still resolves to the right person', () {
      // Nothing about the rename is modelled here, and that IS the point: both
      // halves of the match live on the message, so the account changing its
      // handle afterwards cannot reach either one.
      final hits = MentionDetector.matches(
        sent.content,
        usernameById: sent.mentionHandles,
      );

      expect(hits, hasLength(1));
      expect(hits.single.userId, 'u1');
    });

    test('"does this mention me" asks by id, never by handle', () {
      // The badge and the push both hang off this. Were it comparing handles,
      // renaming would quietly stop notifying the person who was tagged.
      expect(sent.mentionsUser('u1'), isTrue);
      expect(sent.mentionsUser('u2'), isFalse);
    });

    test('someone else claiming the freed handle does not steal the mention', () {
      // The old handle is released on rename, so it can be re-registered. A
      // renderer that resolved against the live roster would now point this
      // mention at the wrong human; resolving against the snapshot cannot.
      final hits = MentionDetector.matches(
        sent.content,
        usernameById: sent.mentionHandles,
      );

      expect(hits.single.userId, isNot('u3'));
      expect(hits.single.userId, 'u1');
    });
  });

  group('the fields the rename gate reads', () {
    test('parse off a self-profile fetch', () {
      final u = ChatUser.fromJson(const {
        '_id': 'u1',
        'username': 'someone',
        'name': 'Someone',
        'hasPassword': false,
        'usernameChangedAt': 1767225600000,
      });

      expect(u.hasPassword, isFalse);
      expect(u.usernameChangedAt,
          DateTime.fromMillisecondsSinceEpoch(1767225600000));
    });

    test('read as unknown when the backend omits them', () {
      // An older deploy, or a fetch that was not a self-view. Null must not
      // collapse into false — `hasPassword == false` routes to the provider
      // sheet, and doing that to a password account is a dead end.
      final u = ChatUser.fromJson(const {
        '_id': 'u1',
        'username': 'someone',
        'name': 'Someone',
      });

      expect(u.hasPassword, isNull);
      expect(u.usernameChangedAt, isNull);
    });

    test('survive copyWith', () {
      // ProfileScreen calls copyWith on every freshly fetched user to graft
      // friendship state on. copyWith drops what it does not name, so omitting
      // these would erase the gate and the cooldown on each refresh — and the
      // symptom would be a password prompt appearing on an Apple-only account.
      final u = ChatUser(
        id: 'u1',
        username: 'someone',
        name: 'Someone',
        hasPassword: false,
        usernameChangedAt: DateTime(2026, 8, 1),
      );

      final copy = u.copyWith(friendshipStatus: FriendshipStatus.friend);

      expect(copy.hasPassword, isFalse);
      expect(copy.usernameChangedAt, DateTime(2026, 8, 1));
    });
  });

  group('the availability typeahead', () {
    // A ChatApi stand-in that records what was asked and answers on command,
    // so the debounce and the race guard can be driven deterministically.
    late _FakeAvailabilityApi api;

    setUp(() => api = _FakeAvailabilityApi());

    test('does not ask until the typing settles', () {
      fakeAsync((async) {
        final c = UsernameAvailabilityController(api: api);
        addTearDown(c.dispose);

        // Six keystrokes inside one debounce window.
        for (final s in ['m', 'mo', 'mon', 'monk', 'monke', 'monkey']) {
          c.onChanged(s);
          async.elapse(const Duration(milliseconds: 40));
        }
        expect(api.asked, isEmpty, reason: 'still typing');
        expect(c.status, UsernameCheck.checking);

        async.elapse(UsernameAvailabilityController.debounce);
        // One request, for the final value — not six.
        expect(api.asked, ['monkey']);
      });
    });

    test('an empty field and the value it opened with ask nothing', () {
      fakeAsync((async) {
        final c = UsernameAvailabilityController(api: api, initialValue: 'mine');
        addTearDown(c.dispose);

        c.onChanged('');
        async.elapse(const Duration(seconds: 1));
        expect(c.status, UsernameCheck.idle);

        // The rename sheet opens prefilled. Calling that "taken" — which it is,
        // by the person reading it — would look broken before a key is pressed.
        c.onChanged('mine');
        async.elapse(const Duration(seconds: 1));
        expect(c.status, UsernameCheck.idle);
        expect(api.asked, isEmpty);
      });
    });

    test('too long is answered without a round trip', () {
      fakeAsync((async) {
        final c = UsernameAvailabilityController(api: api);
        addTearDown(c.dispose);

        c.onChanged('x' * 33);
        async.elapse(const Duration(seconds: 1));

        expect(c.status, UsernameCheck.invalid);
        expect(api.asked, isEmpty);
      });
    });

    test('each reason maps to its own verdict', () {
      for (final (reason, expected) in [
        (null, UsernameCheck.available),
        ('taken', UsernameCheck.taken),
        ('reserved', UsernameCheck.reserved),
        ('invalid', UsernameCheck.invalid),
        // A reason invented after this build shipped.
        ('something_new', UsernameCheck.taken),
      ]) {
        fakeAsync((async) {
          final fake = _FakeAvailabilityApi(reason: reason);
          final c = UsernameAvailabilityController(api: fake);
          addTearDown(c.dispose);

          c.onChanged('candidate');
          async.elapse(const Duration(seconds: 1));

          expect(c.status, expected, reason: 'reason=$reason');
        });
      }
    });

    test('a failed check never reads as a rejection', () {
      fakeAsync((async) {
        final c = UsernameAvailabilityController(
          api: _FakeAvailabilityApi(throws: true),
        );
        addTearDown(c.dispose);

        c.onChanged('candidate');
        async.elapse(const Duration(seconds: 1));

        // Not `taken`. Offline says nothing about the name, and telling someone
        // to pick a different one because their connection dropped is a lie.
        expect(c.status, UsernameCheck.unknown);
      });
    });

    test('a slow answer cannot overwrite a newer one', () {
      fakeAsync((async) {
        final slow = _FakeAvailabilityApi(reason: 'taken', delay: 800);
        final c = UsernameAvailabilityController(api: slow);
        addTearDown(c.dispose);

        c.onChanged('first');
        async.elapse(UsernameAvailabilityController.debounce);

        // Second query overtakes the first, which is still in flight.
        slow.reason = null;
        slow.delay = 10;
        c.onChanged('second');
        async.elapse(const Duration(seconds: 2));

        // 'first' would have said taken, and it lands last. The sequence guard
        // is what stops the classic typeahead bug of the stale answer winning.
        expect(slow.asked, ['first', 'second']);
        expect(c.status, UsernameCheck.available);
        expect(c.settledValue, 'second');
      });
    });
  });

  group('the handle row', () {
    Future<void> pump(WidgetTester tester, ChatUser user) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // No api, repo or auth: every network path on this screen is gated
            // on one of them being non-null.
            home: ProfileScreen(user: user),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders the handle on someone else\'s profile', (tester) async {
      await pump(
        tester,
        ChatUser(id: 'u9', username: 'stranger', name: 'A Stranger'),
      );

      expect(find.text('@stranger'), findsOneWidget);
    });

    testWidgets('never shows a cooldown notice on a profile that is not yours',
        (tester) async {
      // usernameChangedAt is self-only server-side, so this should not arrive
      // at all — but a lock notice under a stranger's handle would be nonsense
      // if it ever did, and the guard for that is cheap.
      await pump(
        tester,
        ChatUser(
          id: 'u9',
          username: 'stranger',
          name: 'A Stranger',
          usernameChangedAt: DateTime.now(),
        ),
      );

      final l10n = AppLocalizationsEn();
      expect(
        find.textContaining(
          l10n.profileScreenUsernameLockedUntil('').trim().split(' ').first,
        ),
        findsNothing,
      );
    });
  });
}

/// Stands in for the availability query. Subclasses [ChatApi] rather than
/// implementing an interface because there is no interface — every screen takes
/// the concrete class — and only the one method is ever reached.
class _FakeAvailabilityApi extends ChatApi {
  _FakeAvailabilityApi({this.reason, this.throws = false, this.delay = 0})
      : super(ConvexBackend.instance);

  /// Null answers "available"; anything else is the server's refusal code.
  String? reason;
  bool throws;

  /// Milliseconds before answering, so a stale response can be made to land
  /// after a newer one.
  int delay;

  final List<String> asked = [];

  @override
  Future<UsernameAvailability> isUsernameAvailable({
    required String username,
    String? excludeUserId,
  }) async {
    asked.add(username);
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
    if (throws) throw Exception('offline');
    return UsernameAvailability(available: reason == null, reason: reason);
  }
}
