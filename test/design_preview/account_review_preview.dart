// Design review, part two: the settings & account states you only reach by
// tapping — the profile's edit confirm and edit sheet, the child-policy
// sheets, the glass "save as" alert, the device-remove confirm — plus the
// full-height child policy page. Not a test — run by path:
//
//   flutter test test/design_preview/account_review_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/family.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/models/user_device.dart';
import 'package:monkeyhub/screens/child_policy_screen.dart';
import 'package:monkeyhub/screens/devices_screen.dart';
import 'package:monkeyhub/screens/glass_screen.dart';
import 'package:monkeyhub/screens/logo_screen.dart';
import 'package:monkeyhub/screens/profile_screen.dart';
import 'package:monkeyhub/screens/theme_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

final _now = DateTime.now();

ChatUser _u(String id, String name) =>
    ChatUser(id: id, username: id, name: name, lastSeen: _now);

final _me = ChatUser(
  id: 'me',
  username: 'murat',
  name: 'Murat Can',
  email: 'murat@example.com',
  hasRecoveryKey: true,
);

final _kid = ChildSummary(
  user: _u('deniz', 'Deniz Koç'),
  policy: const ChildPolicy(),
  pendingCount: 0,
  guardians: [_me],
  lastSeen: _now,
);

class _Api extends Fake implements ChatApi {
  @override
  Future<ChatUser?> getProfile(String userId, {String? viewerUserId}) async =>
      _me;
  @override
  Future<List<UserDevice>> listDevices({
    required String userId,
    required String deviceId,
  }) async =>
      [
        UserDevice(
          deviceId: 'a',
          platform: 'ios',
          deviceName: 'iPhone',
          lastSeenAt: _now,
          createdAt: _now,
          isThis: true,
          reachable: true,
        ),
        UserDevice(
          deviceId: 'b',
          platform: 'macos',
          deviceName: 'MacBook Pro',
          lastSeenAt: _now,
          createdAt: _now,
          isThis: false,
          reachable: true,
        ),
      ];
  @override
  Future<ChildGrants> listChildGrants({
    required String guardianId,
    required String childId,
  }) async =>
      ChildGrants(rooms: const [], contacts: const []);
  @override
  Future<List<ChatUser>> listFriends(String userId) async =>
      [_u('ece', 'Ece Yıldız'), _u('arda', 'Arda')];
  @override
  Future<List<RoomBrief>> grantableRooms({
    required String guardianId,
    required String childId,
  }) async =>
      [RoomBrief(id: 'r', name: 'Minecraft Crew', memberCount: 12)];
  @override
  Future<String?> getFileUrl(String storageId) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo extends ChangeNotifier implements ChatRepository {
  @override
  String? get userId => 'me';
  @override
  List<ChatUser> get friends => const [];
  @override
  List<FriendRequest> get outgoingRequests => const [];
  @override
  List<FriendRequest> get incomingRequests => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthService {
  @override
  Session? get session =>
      Session(userId: 'me', username: 'murat', name: 'Murat Can');
  @override
  bool get isChild => false;
  @override
  bool get isSignedIn => true;
  @override
  Future<List<SocialProvider>> linkedProviders() async => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Family extends ChangeNotifier implements FamilyService {
  @override
  int get pendingCount => 0;
  @override
  FamilyContext get context => FamilyContext(
        accountType: AccountType.adult,
        childPolicy: null,
        guardians: const [],
        children: [_kid],
        pendingCount: 0,
      );
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pushed extends StatefulWidget {
  const _Pushed(this.page);
  final Widget page;
  @override
  State<_Pushed> createState() => _PushedState();
}

class _PushedState extends State<_Pushed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => widget.page,
      ));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _profile() => _Pushed(ProfileScreen(
      user: _me,
      repo: _Repo(),
      api: _Api(),
      auth: _Auth(),
      family: _Family(),
    ));

Widget _policy() => _Pushed(ChildPolicyScreen(
      api: _Api(),
      guardianId: 'me',
      child: _kid,
      family: _Family(),
    ));

/// Taps the first widget showing [text] (any case).
Future<void> Function() _tapText(WidgetTester t, RegExp text) => () async {
      final f = find.textContaining(text);
      // Dragged by hand rather than scrollUntilVisible: that needs its
      // target to resolve to exactly one element, and once in view the text
      // can match twice (a row and its footer) — "Too many elements".
      final scrollable = find.byWidgetPredicate((w) =>
          w is Scrollable && w.axisDirection == AxisDirection.down).first;
      for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
        await t.drag(scrollable, const Offset(0, -250), warnIfMissed: false);
        await t.pump();
      }
      await t.ensureVisible(f.last);
      await t.pump();
      await t.tap(f.last, warnIfMissed: false);
    };

typedef _Case = ({
  Widget Function() page,
  Future<void> Function() Function(WidgetTester)? act,
  Size size,
});

final Map<String, _Case> _cases = {
  'policyfull': (page: _policy, act: null, size: const Size(393, 2900)),
  'editconfirm': (
    page: _profile,
    act: (t) => _tapText(t, RegExp('Murat Can')),
    size: kIphone16Pro,
  ),
  'editsheet': (
    page: _profile,
    act: (t) => () async {
          await _tapText(t, RegExp('Murat Can'))();
          await t.pump(const Duration(milliseconds: 600));
          await t.tap(find.textContaining(RegExp('Change', caseSensitive: false)).last);
        },
    size: kIphone16Pro,
  ),
  'addcontact': (
    page: _policy,
    act: (t) => _tapText(t, RegExp('by username', caseSensitive: false)),
    size: kIphone16Pro,
  ),
  'pickperson': (
    page: _policy,
    act: (t) => _tapText(t, RegExp('your people', caseSensitive: false)),
    size: kIphone16Pro,
  ),
  'pickroom': (
    page: _policy,
    act: (t) => _tapText(t, RegExp('add a room', caseSensitive: false)),
    size: kIphone16Pro,
  ),
  'addguardian': (
    page: _policy,
    act: (t) => _tapText(t, RegExp('add a grown-up', caseSensitive: false)),
    size: kIphone16Pro,
  ),
  'graduate': (
    page: _policy,
    act: (t) => _tapText(t, RegExp('graduate', caseSensitive: false)),
    size: kIphone16Pro,
  ),
  'glasssave': (
    page: () => const _Pushed(GlassScreen()),
    act: (t) => _tapText(t, RegExp('save current', caseSensitive: false)),
    size: kIphone16Pro,
  ),
  'devremove': (
    page: () => _Pushed(DevicesScreen(auth: _Auth(), api: _Api())),
    act: (t) => () async {
          await t.tap(find.text('Remove').first, warnIfMissed: false);
        },
    size: kIphone16Pro,
  ),
  'themepager': (
    page: () => const _Pushed(ThemeScreen()),
    act: (t) => () async {
          await t.tap(find.text('Preview').first, warnIfMissed: false);
        },
    size: kIphone16Pro,
  ),
  'logo': (page: () => const _Pushed(LogoScreen()), act: null, size: const Size(393, 1500)),
};

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final e in _cases.entries) {
    for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
      testWidgets('acct review: ${e.key} $id', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), e.value.page()),
          'rva_${e.key}_$id.png',
          size: e.value.size,
          dpr: 2,
          act: e.value.act?.call(tester) ?? () async {},
        );
      }, variant: _ios);
    }
  }
  testWidgets('acct review: policyfull tr', (tester) async {
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), _policy(),
          locale: const Locale('tr')),
      'rva_policyfull_tr.png',
      size: const Size(393, 2900),
      dpr: 2,
      act: () async {},
    );
  }, variant: _ios);
}
