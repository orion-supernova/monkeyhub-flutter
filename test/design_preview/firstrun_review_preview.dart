// Design-review renders for first-run and the cross-cutting furniture: sign-in
// in every mode, social username, recovery phrase, device login (scan +
// panel), server picker, approval gate, banners, toasts, confirm / action
// sheets, the pill nav, empty states and skeletons — under a dark, a light and
// a character theme, plus Turkish and 1.3 text-scale passes.
//
//   flutter test test/design_preview/firstrun_review_preview.dart
//
// Output: build/design_preview/fr_<what>_<theme>[_tr|_x13].png. Not a test.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/recovery_phrase.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/connection_health.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/device_login_scan_screen.dart';
import 'package:monkeyhub/screens/friend_request_draft_screen.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/enums.dart' show RoomType;
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/screens/pairing_code_screen.dart';
import 'package:monkeyhub/widgets/editable_info_row.dart';
import 'package:monkeyhub/widgets/filter_capsule.dart';
import 'package:monkeyhub/widgets/number_stepper.dart';
import 'package:monkeyhub/widgets/visibility_badge.dart';
import 'package:monkeyhub/screens/login_screen.dart';
import 'package:monkeyhub/data/settings_store.dart' show HomeSection;
import 'package:monkeyhub/screens/navigation/pill_bottom_nav.dart';
import 'package:monkeyhub/screens/profile_screen.dart' show showAvatarActionSheet;
import 'package:monkeyhub/screens/recovery_phrase_screen.dart';
import 'package:monkeyhub/screens/server_screen.dart';
import 'package:monkeyhub/screens/social_username_screen.dart';
import 'package:monkeyhub/screens/theme_onboarding_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/app_toast.dart';
import 'package:monkeyhub/widgets/approval_gate.dart';
import 'package:monkeyhub/widgets/busy_scrim.dart';
import 'package:monkeyhub/widgets/connection_banner.dart';
import 'package:monkeyhub/widgets/destructive_sheet.dart';
import 'package:monkeyhub/widgets/discover_rows.dart';
import 'package:monkeyhub/widgets/game_board_skeleton.dart';
import 'package:monkeyhub/widgets/recovery_banner.dart';
import 'package:monkeyhub/widgets/room_filter_drawer.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';
import 'package:monkeyhub/widgets/skeleton_rows.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

class _NullKeychain extends FlutterSecureStoragePlatform {
  final Map<String, String> items = {};
  @override
  Future<String?> read({required String key, required Map<String, String> options}) async => items[key];
  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async => items[key] = value;
  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async => items.containsKey(key);
  @override
  Future<void> delete({required String key, required Map<String, String> options}) async => items.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async => items.clear();
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => items;
}

class _Health extends ChangeNotifier implements ConnectionHealth {
  _Health(this.phase, {this.isRetrying = false});
  @override
  final ConnectionPhase phase;
  @override
  final bool isRetrying;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Sign-in that always fails the way a wrong password does, so the
/// `login_error` pass shows the error banner rather than a busy CTA forever.
class _FailingAuth extends AuthService {
  _FailingAuth() : super(ChatApi(ConvexBackend.instance));
  @override
  Future<void> signIn({required String username, required String password}) async {
    throw Exception('WRONG_PASSWORD');
  }
}

class _DraftApi extends Fake implements ChatApi {}

/// Just enough repository for the friend-request draft: the request is live
/// (so nothing resolves and pops), and the thread subscription is absent.
class _DraftRepo extends Fake implements ChatRepository {
  _DraftRepo({this.incoming = const []});
  final List<FriendRequest> incoming;
  @override
  List<FriendRequest> get incomingRequests => incoming;
  @override
  List<FriendRequest> get outgoingRequests => const [];
  @override
  List<ChatUser> get friends => const [];
  @override
  String? get userId => 'me';
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

final _ece = ChatUser(id: 'u_ece', username: 'ece', name: 'Ece Yıldız');
final _incomingReq = FriendRequest(
  id: 'req1',
  user: _ece,
  createdAt: DateTime(2026, 10, 3),
  roomType: RoomType.secret,
  messageLifetime: const Duration(minutes: 5),
  messageCount: 0,
);

const _credential = SocialCredential(
  provider: SocialProvider.apple,
  idToken: 'header.payload.signature',
  rawNonce: 'nonce',
);

/// A page with content, which opens [open] on its first frame.
class _Page extends StatefulWidget {
  const _Page({this.open, this.child});
  final void Function(BuildContext context)? open;
  final Widget? child;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    final open = widget.open;
    if (open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => open(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: widget.child ??
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
            children: [
              Text('Chats', style: theme.displayLarge),
              for (var i = 0; i < 9; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(children: [
                    CircleAvatar(radius: 26, backgroundColor: theme.surfaceRaised),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Conversation $i', style: theme.bodyEmph)),
                  ]),
                ),
            ],
          ),
    );
  }
}

/// Pushes [page] as a fullscreen dialog on the first frame, the way the
/// login screen's server chip opens the server picker.
class _PushHost extends StatefulWidget {
  const _PushHost(this.page, {this.fullscreen = true});
  final Widget page;
  final bool fullscreen;
  @override
  State<_PushHost> createState() => _PushHostState();
}

class _PushHostState extends State<_PushHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: widget.fullscreen,
        builder: (_) => widget.page,
      ));
    });
  }

  @override
  Widget build(BuildContext context) => const _Page();
}

/// The banners, pills, scrim and empty states on one page.
class _Bits extends StatelessWidget {
  const _Bits();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: Stack(children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 40),
          children: [
            ConnectionBanner(health: _Health(ConnectionPhase.reconnecting)),
            ConnectionBanner(health: _Health(ConnectionPhase.stalled)),
            const SizedBox(height: 12),
            RecoveryPhraseBanner(onTap: () {}),
            const SizedBox(height: 12),
            const Row(children: [WaitingPill(), Spacer()]),
            const SizedBox(height: 8),
            const Wrap(spacing: 6, runSpacing: 6, children: [
              VisibilityBadge(isPublic: true),
              LockedBadge(),
              JoinedBadge(),
              EphemeralBadge(ttl: Duration(minutes: 5)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              NumberStepper(
                value: 4,
                min: 1,
                max: 9,
                onChanged: (_) {},
                increaseLabel: 'More',
                decreaseLabel: 'Fewer',
              ),
              const Spacer(),
            ]),
            EditableInfoRow(
              label: 'Name',
              value: 'Murat',
              controller: TextEditingController(),
              placeholder: 'Add a name',
              onCommit: (_) {},
              saveLabel: 'Save',
              cancelLabel: 'Cancel',
              note: 'Shown to people you chat with',
            ),
            const SizedBox(height: 8),
            FilteredEmptyState(
              filter: RoomFilter(const {RoomFacet.unread, RoomFacet.groups}),
              total: 42,
              onClear: () {},
            ),
            const DiscoverEmptyLine('nothing pending right now'),
            const SizedBox(height: 8),
            const SkeletonRows(count: 3, avatarSize: 44, circular: false),
            const SizedBox(height: 8),
            const SizedBox(
              height: 120,
              child: Center(child: GameBoardSkeleton(radius: 12, cells: 5)),
            ),
          ],
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120,
          child: BusyScrim(label: 'Switching servers…'),
        ),
      ]),
    );
  }
}

/// The nav bar alone, over a filled page.
class _Nav extends StatelessWidget {
  const _Nav();
  @override
  Widget build(BuildContext context) => const _Page(
        child: Stack(children: [
          _Page(),
          PillBottomNav(
            active: HomeSection.discover,
            onSelect: _noop,
            badges: {HomeSection.chat: 12, HomeSection.settings: 1},
          ),
        ]),
      );
}

void _noop(HomeSection _) {}

void main() {
  setUpAll(() async {
    FlutterSecureStoragePlatform.instance = _NullKeychain();
    await loadPreviewFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AuthService auth() => AuthService(ChatApi(ConvexBackend.instance));
  final phrase = RecoveryPhrase.generate();

  // what -> (builder, optional action after first frames)
  final screens = <String, (Widget Function(), Future<void> Function(WidgetTester)?)>{
    'login_signin': (() => LoginScreen(auth: auth()), null),
    'login_signup': (
      () => LoginScreen(auth: auth()),
      (t) async {
        await t.tap(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ModeToggle'));
      },
    ),
    'login_reset': (
      () => LoginScreen(auth: auth()),
      (t) async {
        // "Forgot password?" — the first text link in the footer.
        await t.tap(find.byType(TextLinkButton).first);
      },
    ),
    'login_error': (
      () => LoginScreen(auth: _FailingAuth()),
      (t) async {
        final fields = find.byType(TextField);
        await t.enterText(fields.at(0), 'murat');
        await t.enterText(fields.at(1), 'hunter2');
        await t.tap(find.byType(SheetActionButton).first);
      },
    ),
    'draft_out': (
      () => FriendRequestDraftScreen(repo: _DraftRepo(), api: _DraftApi(), target: _ece),
      (t) async {
        // Ephemeral on, so the lifetime header and its capsules show too.
        await t.tap(find.byType(FilterCapsule).last);
      },
    ),
    'draft_in': (
      () => FriendRequestDraftScreen(
            repo: _DraftRepo(incoming: [_incomingReq]),
            api: _DraftApi(),
            req: _incomingReq,
          ),
      null,
    ),
    'onb_look': (() => const ThemeOnboardingScreen(), null),
    'social_create': (
      () => SocialUsernameScreen(auth: auth(), credential: _credential, suggestedName: 'Murat'),
      null,
    ),
    'social_link': (
      () => SocialUsernameScreen(auth: auth(), credential: _credential, suggestedName: 'Murat'),
      (t) async {
        await t.tap(find.byType(SheetActionButton).last);
      },
    ),
    'recovery_show': (
      () => RecoveryPhraseScreen(phrase: phrase, mode: RecoveryGateMode.setup),
      null,
    ),
    'recovery_password': (
      () => RecoveryPhraseScreen(
            phrase: phrase,
            mode: RecoveryGateMode.repair,
            dismissible: true,
            onCommit: (_, _) async {},
          ),
      null,
    ),
    'scan': (() => _PushHost(DeviceLoginScanScreen(auth: auth()), fullscreen: false), null),
    'pairing': (
      () => _PushHost(
            PairingCodeScreen(
              api: ChatApi(ConvexBackend.instance),
              guardianId: 'g',
              child: ChatUser(id: 'k', username: 'ayse', name: 'Ayşe'),
            ),
            fullscreen: false,
          ),
      null,
    ),
    'server_onboarding': (() => const ServerScreen(onboarding: true), null),
    'server_modal': (() => const _PushHost(ServerScreen()), null),
    'gate': (
      () => _Page(open: (c) => showApprovalGate(c, what: 'join Weekend Crew', detail: 'A public room with 248 members.')),
      null,
    ),
    'confirm': (
      () => _Page(open: (c) => showConfirmSheet(c,
          headline: 'Delete this chat?',
          body: 'Every message in it goes, for everyone.',
          confirmLabel: 'Delete chat')),
      null,
    ),
    'actions': (
      () => _Page(open: (c) => showIosActionSheet<int>(c,
          title: 'Weekend Crew',
          message: 'Choose what happens to this conversation.',
          actions: const [
            IosSheetAction(label: 'Mark as read', value: 1),
            IosSheetAction(label: 'Pin', value: 2),
            IosSheetAction(label: 'Leave group', value: 3, destructive: true),
          ])),
      null,
    ),
    'avatar_sheet': (
      () => _Page(open: (c) => showAvatarActionSheet(c, hasAvatar: true)),
      null,
    ),
    'toast_action': (
      () => _Page(open: (c) => AppToast.of(c).show('Pinned to the top', actionLabel: 'Undo', onAction: () {})),
      null,
    ),
    'toast_error_long': (
      () => _Page(open: (c) => AppToast.of(c).error(
          "Couldn't reach the server. Your message is saved and will send when you're back online.")),
      null,
    ),
    'toast_success': (
      () => _Page(open: (c) => AppToast.of(c).success('Copied')),
      null,
    ),
    'bits': (() => const _Bits(), null),
    'nav': (() => const _Nav(), null),
  };

  const themes = ['basic', 'basic_daylight', 'risograph_pop'];
  const variants = <String, ({Locale locale, double scale})>{
    '': (locale: Locale('en'), scale: 1.0),
    '_tr': (locale: Locale('tr'), scale: 1.0),
    '_x13': (locale: Locale('en'), scale: 1.3),
    '_trx13': (locale: Locale('tr'), scale: 1.3),
  };

  for (final id in themes) {
    for (final e in screens.entries) {
      for (final v in variants.entries) {
        // Locale / scale passes on the dark theme only, plus the character
        // theme in Turkish for the flows with the longest copy.
        if (v.key.isNotEmpty && id != 'basic' &&
            !(id == 'risograph_pop' && v.key == '_tr')) {
          continue;
        }
        testWidgets('fr ${e.key} $id${v.key}', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = v.value.scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final action = e.value.$2;
          await snap(
            tester,
            previewApp(ThemeController.byId(id), e.value.$1(),
                locale: v.value.locale),
            'fr_${e.key}_$id${v.key}.png',
            act: action == null ? () async {} : () => action(tester),
          );
        });
      }
    }
  }
}
