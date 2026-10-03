import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/people_picker.dart';

/// The one search box now standing between somebody and the person they want,
/// on two screens that used to have no list at all: the chat list's `+` and
/// the guardian's "allow someone" sheet.
///
/// What is pinned here is mostly about NOT lying. A picker that says "no one
/// matches" while a lookup is still in flight, or that shows a stranger under
/// the heading that says these people are yours, is worse than one that shows
/// nothing — both are answers, and neither is one we have.
/// Deliberately empty. The picker hands this straight to [UserAvatar], which
/// draws a monogram and asks the network nothing when there is no
/// `avatarStorageId` — and none of these fixtures has one. Searching is a
/// callback the host supplies, which is what makes the remote half testable
/// with no API at all.
class _FakeApi extends Fake implements ChatApi {}

ChatUser _user(String id, {String? name}) =>
    ChatUser(id: id, username: id, name: name ?? id);

void main() {
  final api = _FakeApi();

  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        // Bounded on purpose: PeoplePicker builds a real scrolling list and
        // says so in its doc. An unbounded host would throw.
        body: Center(child: SizedBox(width: 375, height: 500, child: child)),
      ),
    ),
  );

  Widget picker({
    required List<ChatUser> people,
    ValueChanged<ChatUser>? onPick,
    Future<List<ChatUser>> Function(String)? searchMore,
    List<Widget> leading = const [],
  }) => PeoplePicker(
    people: people,
    api: api,
    onPick: onPick ?? (_) {},
    hintText: 'search your friends',
    emptyLabel: 'no friends yet',
    noMatchLabel: 'no friends match',
    localHeader: 'YOUR FRIENDS',
    remoteHeader: 'EVERYONE ELSE',
    searchMore: searchMore,
    leading: leading,
  );

  group('the local list', () {
    testWidgets('shows everyone before a single key is pressed', (tester) async {
      await tester.pumpWidget(
        host(picker(people: [_user('ada'), _user('bela')])),
      );
      expect(find.text('@ada'), findsOneWidget);
      expect(find.text('@bela'), findsOneWidget);
    });

    testWidgets('filters on username and on display name', (tester) async {
      await tester.pumpWidget(
        host(picker(people: [_user('ada', name: 'Ada Lovelace'), _user('bela')])),
      );

      await tester.enterText(find.byType(TextField), 'lovel');
      await tester.pump();
      expect(find.text('@ada'), findsOneWidget);
      expect(find.text('@bela'), findsNothing);

      await tester.enterText(find.byType(TextField), 'bel');
      await tester.pump();
      expect(find.text('@bela'), findsOneWidget);
      expect(find.text('@ada'), findsNothing);
    });

    testWidgets('an empty list and an empty result say different things', (
      tester,
    ) async {
      await tester.pumpWidget(host(picker(people: const [])));
      expect(find.text('no friends yet'), findsOneWidget);

      await tester.pumpWidget(host(picker(people: [_user('ada')])));
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('no friends match'), findsOneWidget);
      expect(find.text('no friends yet'), findsNothing);
    });

    testWidgets('tapping a row hands the person back', (tester) async {
      ChatUser? picked;
      await tester.pumpWidget(
        host(picker(people: [_user('ada')], onPick: (u) => picked = u)),
      );
      await tester.tap(find.text('@ada'));
      await tester.pump();
      expect(picked?.id, 'ada');
    });

    testWidgets('no headings when there is only one section to head', (
      tester,
    ) async {
      await tester.pumpWidget(host(picker(people: [_user('ada')])));
      expect(find.text('Your friends'), findsNothing);
      expect(find.text('Everyone else'), findsNothing);
    });
  });

  group('the remote half', () {
    testWidgets('a short query never costs a round trip', (tester) async {
      final asked = <String>[];
      await tester.pumpWidget(
        host(
          picker(
            people: [_user('ada')],
            searchMore: (q) async {
              asked.add(q);
              return const [];
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 400));
      expect(asked, isEmpty);
    });

    testWidgets('strangers appear under their own heading, friends under theirs',
        (tester) async {
      await tester.pumpWidget(
        host(
          picker(
            people: [_user('adam')],
            searchMore: (_) async => [_user('adele')],
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ad');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Headings print in sentence case.
      expect(find.text('Your friends'), findsOneWidget);
      expect(find.text('Everyone else'), findsOneWidget);
      expect(find.text('@adam'), findsOneWidget);
      expect(find.text('@adele'), findsOneWidget);
    });

    testWidgets('somebody who is both is listed once, as a friend', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          picker(
            people: [_user('ada')],
            // The server does not know which of its hits the caller already
            // holds, so it returns this person too.
            searchMore: (_) async => [_user('ada'), _user('bela')],
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('@ada'), findsOneWidget);
    });

    testWidgets('"no one matches" is withheld until the lookup has answered', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          picker(
            people: const [],
            searchMore: (_) async {
              await Future<void>.delayed(const Duration(milliseconds: 200));
              return [_user('bela')];
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'bel');
      await tester.pump(const Duration(milliseconds: 300));
      // Debounce has fired, the request has not answered.
      expect(find.text('no friends match'), findsNothing);
      expect(find.byType(CupertinoActivityIndicator), findsWidgets);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('@bela'), findsOneWidget);
      expect(find.text('no friends match'), findsNothing);
    });

    testWidgets('a slow answer cannot overwrite a newer one', (tester) async {
      await tester.pumpWidget(
        host(
          picker(
            people: const [],
            searchMore: (q) async {
              // The first query is the slow one — the classic out-of-order
              // search bug, which shows up as results that do not match what
              // is in the box.
              await Future<void>.delayed(
                Duration(milliseconds: q == 'slow' ? 600 : 50),
              );
              return [_user(q)];
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'slow');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'fast');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('@fast'), findsOneWidget);

      // Now let the stale one land. It must be dropped on the floor.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('@fast'), findsOneWidget);
      expect(find.text('@slow'), findsNothing);
    });

    testWidgets('a failed lookup is not reported as an empty result', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          picker(
            people: [_user('ada')],
            searchMore: (_) async => throw StateError('offline'),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      // The local match survives, and nothing claims the search came back
      // empty — it never came back at all.
      expect(find.text('@ada'), findsOneWidget);
      expect(find.text('no friends match'), findsNothing);
    });
  });

  group('the host rows above the people', () {
    // The layout this pins is the one the pinned-footer version got wrong: the
    // host's actions belong INSIDE the scroller, above the people, so the list
    // gets the whole sheet instead of a band between two fixed blocks.
    testWidgets('scroll with the list rather than sitting in a fixed block', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          picker(
            people: List.generate(30, (i) => _user('friend$i')),
            leading: const [Text('CREATE A ROOM')],
          ),
        ),
      );
      expect(find.text('CREATE A ROOM'), findsOneWidget);

      // Far enough that a row pinned outside the scroller would still be
      // showing. This one goes with the list.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -600));
      await tester.pump();
      expect(find.text('CREATE A ROOM'), findsNothing);
    });

    testWidgets('step aside the moment a person is being searched for', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          picker(
            people: [_user('ada')],
            leading: const [Text('CREATE A ROOM')],
          ),
        ),
      );
      expect(find.text('CREATE A ROOM'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ada');
      await tester.pump();
      // "Create a room" is not an answer to "find me ada", and it would be
      // sitting on top of the row that is.
      expect(find.text('CREATE A ROOM'), findsNothing);
      expect(find.text('@ada'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('CREATE A ROOM'), findsOneWidget);
    });

    testWidgets('a heading separates them from the people', (tester) async {
      await tester.pumpWidget(
        host(
          picker(
            people: [_user('ada')],
            leading: const [Text('CREATE A ROOM')],
          ),
        ),
      );
      // Without it the list runs straight on from the buttons with nothing
      // saying what changed. It is NOT drawn when there are no host rows and
      // only one section — see the test above in the local group.
      // Headings print in sentence case.
      expect(find.text('Your friends'), findsOneWidget);
    });

    testWidgets('survive an empty friends list, so the actions stay reachable',
        (tester) async {
      await tester.pumpWidget(
        host(
          picker(people: const [], leading: const [Text('CREATE A ROOM')]),
        ),
      );
      // Someone with no friends yet still came here to make a room. Replacing
      // the whole scroller with a centred "no friends yet" would take that
      // away from them.
      expect(find.text('CREATE A ROOM'), findsOneWidget);
      expect(find.text('no friends yet'), findsOneWidget);
    });
  });
}
