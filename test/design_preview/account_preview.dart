// Renders the account-area pages (your profile, someone else's) under a few
// themes. Not a test — run by path:
//
//   flutter test test/design_preview/account_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/screens/profile_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

class _FakeApi extends Fake implements ChatApi {
  @override
  Future<ChatUser?> getProfile(String userId, {String? viewerUserId}) async =>
      null;
}

class _FakeRepo extends ChangeNotifier implements ChatRepository {
  _FakeRepo(this._me);
  final String _me;

  @override
  String? get userId => _me;

  @override
  List<ChatUser> get friends => [];

  @override
  List<FriendRequest> get outgoingRequests => const [];

  @override
  List<FriendRequest> get incomingRequests => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends ChangeNotifier implements AuthService {
  @override
  bool get isChild => false;

  @override
  bool get isSignedIn => true;

  @override
  Future<List<SocialProvider>> linkedProviders() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
  lastSeen: DateTime.now(),
  friendshipStatus: FriendshipStatus.friend,
);

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final id in ['basic', 'basic_daylight', 'vault_noir', 'risograph_pop']) {
    testWidgets('account preview: my profile $id', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          ProfileScreen(
            user: _me,
            repo: _FakeRepo('me'),
            api: _FakeApi(),
            auth: _FakeAuth(),
          ),
        ),
        'acct_me_$id.png',
      );
    });
    testWidgets('account preview: their profile $id', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId(id),
          ProfileScreen(user: _ece, repo: _FakeRepo('me'), api: _FakeApi()),
        ),
        'acct_them_$id.png',
      );
    });
  }
}
