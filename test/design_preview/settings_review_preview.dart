// Design review of the settings & account area: every inner page and sheet,
// pushed (so the back chevron shows), under a dark, a light and a character
// theme, plus Turkish and 1.3x text runs. Not a test — run by path:
//
//   flutter test test/design_preview/settings_review_preview.dart
//   flutter test test/design_preview/settings_review_preview.dart --dart-define=PAGES=devices,blocked
//   ... --dart-define=THEMES=basic_rose,paper,bloom,vault_ivory

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/recovery_phrase.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/diagnostics/diag_log.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/models/app_release.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/family.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/models/user_device.dart';
import 'package:monkeyhub/screens/approvals_screen.dart';
import 'package:monkeyhub/screens/blocked_users_screen.dart';
import 'package:monkeyhub/screens/child_policy_screen.dart';
import 'package:monkeyhub/screens/devices_screen.dart';
import 'package:monkeyhub/screens/diagnostics/diag_filter_sheet.dart';
import 'package:monkeyhub/screens/diagnostics_screen.dart';
import 'package:monkeyhub/screens/family_screen.dart';
import 'package:monkeyhub/screens/glass_screen.dart';
import 'package:monkeyhub/screens/linked_accounts_screen.dart';
import 'package:monkeyhub/screens/logo_screen.dart';
import 'package:monkeyhub/screens/profile_screen.dart';
import 'package:monkeyhub/screens/profile_visibility_screen.dart';
import 'package:monkeyhub/screens/recovery_phrase_screen.dart';
import 'package:monkeyhub/screens/report_problem_screen.dart';
import 'package:monkeyhub/screens/server_screen.dart';
import 'package:monkeyhub/screens/settings_screen.dart';
import 'package:monkeyhub/screens/theme_screen.dart';
import 'package:monkeyhub/screens/video_quality_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/update/release_channel.dart';
import 'package:monkeyhub/widgets/server_role_sheet.dart';
import 'package:monkeyhub/widgets/update_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

final _now = DateTime.now();

ChatUser _u(String id, String name, {String? status}) => ChatUser(
      id: id,
      username: id,
      name: name,
      status: status,
      lastSeen: _now,
    );

final _me = ChatUser(
  id: 'me',
  username: 'murat',
  name: 'Murat Can',
  email: 'murat@example.com',
  hasRecoveryKey: true,
);

final _ece = ChatUser(
  id: 'ece',
  username: 'ece',
  name: 'Ece Yıldız',
  status: 'online',
  lastSeen: _now,
  friendshipStatus: FriendshipStatus.friend,
);

final _kid = ChildSummary(
  user: _u('deniz', 'Deniz Koç'),
  policy: const ChildPolicy(),
  pendingCount: 2,
  guardians: [_me, _u('aylin', 'Aylin Koç')],
  status: 'online',
  lastSeen: _now,
);

class _FakeApi extends Fake implements ChatApi {
  @override
  Future<ChatUser?> getProfile(String userId, {String? viewerUserId}) async =>
      userId == 'me' ? _me : _ece;

  @override
  Future<List<UserDevice>> listDevices({
    required String userId,
    required String deviceId,
  }) async =>
      [
        UserDevice(
          deviceId: 'a',
          platform: 'ios',
          deviceName: "Murat's iPhone 16 Pro",
          lastSeenAt: _now,
          createdAt: _now,
          isThis: true,
          reachable: true,
        ),
        UserDevice(
          deviceId: 'b',
          platform: 'macos',
          deviceName: 'MacBook Pro',
          lastSeenAt: _now.subtract(const Duration(hours: 3)),
          createdAt: _now,
          isThis: false,
          reachable: false,
        ),
        UserDevice(
          deviceId: 'c',
          platform: 'android',
          deviceName: 'Pixel 9 Pro XL (Murat’s work phone)',
          lastSeenAt: _now.subtract(const Duration(days: 12)),
          createdAt: _now,
          isThis: false,
          reachable: true,
        ),
      ];

  @override
  Future<List<ChatUser>> listBlocked(String userId) async => [
        _u('troll', 'Some Very Long Display Name Person'),
        _u('spam', 'Spam Bot'),
      ];

  @override
  Future<Subscription> subscribeGuardianQueue({
    required String guardianId,
    required void Function(List<QueueItem> items) onItems,
    void Function(Object error)? onError,
  }) async =>
      throw StateError('no socket');

  @override
  Future<List<QueueItem>> listGuardianQueue(String guardianId) async => [
        QueueItem(
          type: QueueItemType.contactOutgoing,
          id: 'q1',
          createdAt: _now,
          child: _kid.user,
          other: _u('mert', 'Mert Aydın'),
          note: 'He is in my class, can I add him?',
        ),
        QueueItem(
          type: QueueItemType.joinRoom,
          id: 'q2',
          createdAt: _now,
          child: _kid.user,
          room: RoomBrief(id: 'r', name: 'Minecraft Crew', memberCount: 12),
        ),
      ];

  @override
  Future<ChildGrants> listChildGrants({
    required String guardianId,
    required String childId,
  }) async =>
      ChildGrants(
        rooms: [RoomBrief(id: 'r1', name: 'Family', memberCount: 4)],
        contacts: [
          ChildContact(user: _u('mert', 'Mert Aydın'), connected: true),
          ChildContact(
            user: _u('zeynep', 'Zeynep'),
            connected: false,
            approvalId: 'a',
          ),
        ],
      );

  @override
  Future<List<ChatUser>> listFriends(String userId) async => [_ece];

  @override
  Future<List<RoomBrief>> grantableRooms({
    required String guardianId,
    required String childId,
  }) async =>
      const [];

  @override
  Future<void> backfillFamilyFriendships(String guardianId) async {}

  @override
  Future<String?> getFileUrl(String storageId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo extends ChangeNotifier implements ChatRepository {
  @override
  String? get userId => 'me';
  @override
  List<ChatUser> get friends => [_ece];
  @override
  List<FriendRequest> get outgoingRequests => const [];
  @override
  List<FriendRequest> get incomingRequests => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends ChangeNotifier implements AuthService {
  @override
  Session? get session =>
      Session(userId: 'me', username: 'murat', name: 'Murat Can');
  @override
  bool get isChild => false;
  @override
  bool get isSignedIn => true;
  @override
  Future<List<SocialProvider>> linkedProviders() async =>
      const [SocialProvider.apple];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFamily extends ChangeNotifier implements FamilyService {
  _FakeFamily({this.withKids = true});
  final bool withKids;
  @override
  int get pendingCount => withKids ? 2 : 0;
  @override
  FamilyContext get context => FamilyContext(
        accountType: AccountType.adult,
        childPolicy: null,
        guardians: const [],
        children: withKids ? [_kid] : const [],
        pendingCount: pendingCount,
      );
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pushes [page] over a blank root so the page wears its back chevron.
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

/// A settings-ish page that opens a sheet on its first frame.
class _SheetHost extends StatefulWidget {
  const _SheetHost(this.open);
  final void Function(BuildContext) open;
  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) => const VideoQualityScreen();
}

final _api = _FakeApi();

Widget _profileMe() => ProfileScreen(
      user: _me,
      repo: _FakeRepo(),
      api: _api,
      auth: _FakeAuth(),
      family: _FakeFamily(),
    );

final Map<String, Widget Function()> _pages = {
  'hub': () => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => SettingsScreen(
            repo: _FakeRepo(),
            api: _api,
            auth: _FakeAuth(),
            family: _FakeFamily(),
          ),
        ),
      ),
  'theme': () => const _Pushed(ThemeScreen()),
  'glass': () => const _Pushed(GlassScreen()),
  'logo': () => const _Pushed(LogoScreen()),
  'video': () => const _Pushed(VideoQualityScreen()),
  'profileme': () => _Pushed(_profileMe()),
  'profilethem': () => _Pushed(
        ProfileScreen(user: _ece, repo: _FakeRepo(), api: _api),
      ),
  'visibility': () => _Pushed(
        ProfileVisibilityScreen(repo: _FakeRepo(), api: _api),
      ),
  'devices': () => _Pushed(DevicesScreen(auth: _FakeAuth(), api: _api)),
  'blocked': () => _Pushed(BlockedUsersScreen(repo: _FakeRepo(), api: _api)),
  'blockedempty': () => _Pushed(
        BlockedUsersScreen(repo: _FakeRepo(), api: _EmptyApi()),
      ),
  'linked': () => _Pushed(LinkedAccountsScreen(auth: _FakeAuth())),
  'server': () => const _Pushed(ServerScreen()),
  'diagnostics': () => const _Pushed(DiagnosticsScreen()),
  'report': () => _Pushed(ReportProblemScreen(auth: _FakeAuth(), api: _api)),
  'family': () => _Pushed(
        FamilyScreen(api: _api, userId: 'me', family: _FakeFamily()),
      ),
  'familyempty': () => _Pushed(
        FamilyScreen(
          api: _api,
          userId: 'me',
          family: _FakeFamily(withKids: false),
        ),
      ),
  'approvals': () => _Pushed(
        ApprovalsScreen(api: _api, guardianId: 'me', family: _FakeFamily()),
      ),
  'childpolicy': () => _Pushed(
        ChildPolicyScreen(
          api: _api,
          guardianId: 'me',
          child: _kid,
          family: _FakeFamily(),
        ),
      ),
  'recovery': () => _Pushed(
        RecoveryPhraseScreen(
          phrase: RecoveryPhrase.generate(),
          mode: RecoveryGateMode.rotate,
          dismissible: true,
        ),
      ),
  'recoverysetup': () => _Pushed(
        RecoveryPhraseScreen(
          phrase: RecoveryPhrase.generate(),
          mode: RecoveryGateMode.setup,
          knownPassword: 'x',
        ),
      ),
  // Sheets
  'sh_role': () => _SheetHost((c) => showServerRoleInfo(c)),
  'sh_update': () => _SheetHost((c) => showUpdateSheet(
        c,
        release: AppRelease(
          channel: 'ios-testflight',
          version: '1.3.114',
          notes: 'Faster chat list, fixed the call screen on iPad.',
          publishedAt: 0,
        ),
        channel: ReleaseChannel.iosTestflight,
        currentVersion: '1.3.113',
        mandatory: false,
      )),
  'sh_updatemand': () => _SheetHost((c) => showUpdateSheet(
        c,
        release: AppRelease(
          channel: 'ios-testflight',
          version: '1.4.0',
          publishedAt: 0,
        ),
        channel: ReleaseChannel.iosTestflight,
        currentVersion: '1.3.113',
        mandatory: true,
      )),
  'sh_diagfilter': () => _SheetHost(
        (c) => DiagFilterSheet.show(c, const DiagFilter()),
      ),
  'sh_avatar': () => _SheetHost(
        (c) => showAvatarActionSheet(c, hasAvatar: true),
      ),
};

class _EmptyApi extends _FakeApi {
  @override
  Future<List<ChatUser>> listBlocked(String userId) async => const [];
}

/// Override with --dart-define=THEMES=basic_rose,paper,bloom,vault_ivory.
const _themesEnv = String.fromEnvironment('THEMES');
final _themes = _themesEnv.isEmpty
    ? const ['basic', 'basic_daylight', 'risograph_pop']
    : _themesEnv.split(',');

/// Pages that also get a Turkish render and a 1.3x text-scale render.
const _stress = {
  'hub',
  'logo',
  'profileme',
  'profilethem',
  'devices',
  'blocked',
  'linked',
  'server',
  'family',
  'approvals',
  'childpolicy',
  'visibility',
  'report',
  'recovery',
  'diagnostics',
  'glass',
  'sh_update',
  'sh_role',
  'sh_avatar',
  'sh_diagfilter',
};

/// Rendered as the iPhone it is designed for, so Switch.adaptive, the Apple
/// button and every platform check take their iOS branch.
final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    DiagLog.lifecycle('resumed');
    DiagLog.connection('connected', 'wss://convex.example.com');
    DiagLog.error('call', StateError('ICE failed after 3 attempts'));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'MonkeyHub',
      packageName: 'app',
      version: '1.3.113',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  const only = String.fromEnvironment('PAGES');
  for (final entry in _pages.entries) {
    if (only.isNotEmpty && !only.split(',').contains(entry.key)) continue;
    final tall = !entry.key.startsWith('sh_');
    final size = tall ? Size(393, double.parse(const String.fromEnvironment("HEIGHT", defaultValue: "1500"))) : kIphone16Pro;
    final dpr = tall ? 2.0 : 2.0;
    for (final id in _themes) {
      testWidgets('review: ${entry.key} $id', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), entry.value()),
          'rv_${entry.key}_$id.png',
          size: size,
          dpr: dpr,
          act: () async {},
        );
      }, variant: _ios);
    }
    if (_stress.contains(entry.key)) {
      testWidgets('review: ${entry.key} tr', (tester) async {
        await snap(
          tester,
          previewApp(
            ThemeController.byId('basic'),
            entry.value(),
            locale: const Locale('tr'),
          ),
          'rv_${entry.key}_tr.png',
          size: size,
          dpr: dpr,
          act: () async {},
        );
      }, variant: _ios);
      // Turkish at 1.3x together: the longest words at the largest size.
      testWidgets('review: ${entry.key} tr13', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await snap(
          tester,
          previewApp(
            ThemeController.byId('basic'),
            entry.value(),
            locale: const Locale('tr'),
          ),
          'rv_${entry.key}_tr13.png',
          size: size,
          dpr: dpr,
          act: () async {},
        );
      }, variant: _ios);
      testWidgets('review: ${entry.key} x1.3', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await snap(
          tester,
          previewApp(ThemeController.byId('basic_daylight'), entry.value()),
          'rv_${entry.key}_x13.png',
          size: size,
          dpr: dpr,
          act: () async {},
        );
      }, variant: _ios);
    }
  }
}
