import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/new_chat_menu.dart';
import 'package:monkeyhub/widgets/people_picker.dart';

/// The order of the `+` sheet, and the fact that the list has somewhere to go.
///
/// The first version pinned the two room actions to the BOTTOM of the sheet,
/// which left the friends a narrow band between the search bar and that
/// footer — a handful of rows visible and scrolling them felt like reading
/// through a letterbox. The order below (search, then actions, then people,
/// with the last two sharing one scroller) is the fix, and it is the thing
/// most likely to be undone by accident, so it is pinned by position rather
/// than by presence: every one of these would still pass if the widgets were
/// merely all *present* in the wrong arrangement.
class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends Fake implements ChatRepository {
  _FakeRepo(this._friends);
  final List<ChatUser> _friends;

  @override
  List<ChatUser> get friends => _friends;

  // The sheet subscribes so a request accepted while it is open shows up. It
  // never fires in these tests; it only has to not throw.
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

ChatUser _user(String id) => ChatUser(id: id, username: id, name: id);

void main() {
  final api = _FakeApi();

  // A phone, not the 800x600 default. The sheet is sized as a fraction of the
  // window and the rows have fixed heights, so how many fit — the very thing
  // these tests are about — is meaningless at a size no phone has.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1170, 2532); // iPhone 13 Pro
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Opens the sheet and settles it. Returns the outcome future so a test can
  /// assert what a tap handed back.
  Future<Future<NewChatOutcome?>> open(
    WidgetTester tester, {
    required List<ChatUser> friends,
    bool canCreateRoom = true,
    bool canJoinByCode = true,
  }) async {
    final repo = _FakeRepo(friends);
    late Future<NewChatOutcome?> outcome;
    // ThemeScope wraps the MaterialApp, not its `home`. The sheet is a route
    // on that app's Navigator, so a scope inside `home` is not an ancestor of
    // it and `ThemeScope.of` throws — which is exactly how the sheet would
    // fail in the app if it were ever pushed on the root navigator.
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => outcome = showNewChatMenu(
                    context,
                    repo: repo,
                    api: api,
                    canCreateRoom: canCreateRoom,
                    canJoinByCode: canJoinByCode,
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
    return outcome;
  }

  double topOf(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  group('the order down the sheet', () {
    testWidgets('search bar, then the room actions, then the friends', (
      tester,
    ) async {
      await open(tester, friends: [_user('ada'), _user('bela')]);

      final search = topOf(tester, find.byType(TextField));
      final create = topOf(tester, find.text('Create a room'));
      final join = topOf(tester, find.text('Join with a code'));
      final firstFriend = topOf(tester, find.text('@ada'));

      expect(search, lessThan(create));
      expect(create, lessThan(join));
      expect(join, lessThan(firstFriend));
    });

    testWidgets('the search bar does not scroll away with the rest', (
      tester,
    ) async {
      await open(
        tester,
        friends: List.generate(40, (i) => _user('friend$i')),
      );
      final before = topOf(tester, find.byType(TextField));

      await tester.drag(find.text('Create a room'), const Offset(0, -400));
      await tester.pumpAndSettle();

      // The actions went with the list; the bar you type into stayed put.
      expect(find.text('Create a room'), findsNothing);
      expect(topOf(tester, find.byType(TextField)), before);
    });

    testWidgets('every friend is reachable, however many there are', (
      tester,
    ) async {
      await open(
        tester,
        friends: List.generate(40, (i) => _user('friend$i')),
      );
      expect(find.text('@friend0'), findsOneWidget);
      expect(find.text('@friend39'), findsNothing);

      // The whole point of the complaint this fixes: the list has somewhere to
      // go. Scroll to the end and the last friend is there.
      final list = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(find.text('@friend39'), 300, scrollable: list);
      await tester.pumpAndSettle();
      expect(find.text('@friend39'), findsOneWidget);
      expect(find.text('@friend0'), findsNothing);
    });

    testWidgets('the list gets most of the sheet, not a band in the middle', (
      tester,
    ) async {
      await open(
        tester,
        friends: List.generate(40, (i) => _user('friend$i')),
      );
      final sheetHeight = tester.getSize(find.byType(PeoplePicker)).height;
      // The ListView, specifically — the search field has a Scrollable of its
      // own inside its EditableText.
      final listHeight = tester
          .getSize(find.descendant(
            of: find.byType(PeoplePicker),
            matching: find.byType(ListView),
          ))
          .height;

      // The pinned-footer version gave the rows a little over a third of the
      // sheet. Everything below the search bar is now theirs.
      expect(listHeight / sheetHeight, greaterThan(0.8));
    });
  });

  group('what it hands back', () {
    testWidgets('a tapped friend, not a room action', (tester) async {
      final outcome = await open(tester, friends: [_user('ada')]);
      await tester.tap(find.text('@ada'));
      await tester.pumpAndSettle();
      final result = await outcome;
      expect(result?.friend?.id, 'ada');
      expect(result?.choice, isNull);
    });

    testWidgets('a room action, not a friend', (tester) async {
      final outcome = await open(tester, friends: [_user('ada')]);
      await tester.tap(find.text('Create a room'));
      await tester.pumpAndSettle();
      final result = await outcome;
      expect(result?.choice, NewChatChoice.createRoom);
      expect(result?.friend, isNull);
    });
  });

  group('what a locked-down account sees', () {
    testWidgets('no room actions, but the friends are still there', (
      tester,
    ) async {
      // A child whose guardian has switched off room creation, and for whom
      // joining by code is off outright. Messaging an approved friend is the
      // one thing this account exists to do, so the sheet must still open
      // onto it — this is why the `+` is no longer hidden for them.
      await open(
        tester,
        friends: [_user('ada')],
        canCreateRoom: false,
        canJoinByCode: false,
      );
      expect(find.text('Create a room'), findsNothing);
      expect(find.text('Join with a code'), findsNothing);
      expect(find.text('@ada'), findsOneWidget);
    });
  });
}
