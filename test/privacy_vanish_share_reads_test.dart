import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/profile_visibility_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// Settings > Privacy: someone who hides "seen" gets one extra switch, "Share
/// my reads in vanishing chats", off until they choose. It is not drawn for
/// anyone who shares their reads, and flipping it saves through
/// `users.updateVisibility`.
class _FakeRepo extends Fake implements ChatRepository {
  @override
  String? get userId => 'me';
}

class _FakeApi extends Fake implements ChatApi {
  _FakeApi(this.visibility);
  final Map<String, dynamic> visibility;
  final List<Map<String, Object?>> saved = [];

  @override
  Future<ChatUser?> getProfile(String userId, {String? viewerUserId}) async =>
      ChatUser.fromJson({
        '_id': 'me',
        'username': 'me',
        'name': 'Me',
        'visibility': visibility,
      });

  @override
  Future<void> updateVisibility({
    required String userId,
    FieldVisibility? avatar,
    FieldVisibility? status,
    FieldVisibility? lastSeen,
    FieldVisibility? seen,
    FieldVisibility? friendRequests,
    FieldVisibility? feed,
    FieldVisibility? points,
    FieldVisibility? puzzle,
    FieldVisibility? pointsPast,
    bool? vanishShareReads,
  }) async {
    saved.add({'seen': seen, 'vanishShareReads': vanishShareReads});
  }
}

/// The page carries a spinner that never stops (it is only faded out while
/// idle), so `pumpAndSettle` would never return.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  Future<_FakeApi> open(WidgetTester t, Map<String, dynamic> visibility) async {
    t.view.physicalSize = const Size(420, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final api = _FakeApi(visibility);
    await t.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileVisibilityScreen(repo: _FakeRepo(), api: api),
        ),
      ),
    );
    await settle(t);
    return api;
  }

  const title = 'Share my reads in vanishing chats';

  testWidgets('shown, off, with its footnote when seen is nobody', (t) async {
    await open(t, {'seen': 'nobody'});
    expect(find.text(title), findsOneWidget);
    expect(
      find.textContaining(
          "A vanishing message disappears 10 seconds after it's read"),
      findsOneWidget,
    );
    expect(find.textContaining('You can change this anytime.'), findsOneWidget);
    final sw = t.widget<Switch>(find.byType(Switch).last);
    expect(sw.value, isFalse);
  });

  testWidgets('not drawn while reads are shared with friends', (t) async {
    await open(t, {'seen': 'friends'});
    expect(find.text(title), findsNothing);
  });

  testWidgets('already opted in reads as on', (t) async {
    await open(t, {'seen': 'nobody', 'vanishShareReads': true});
    final sw = t.widget<Switch>(find.byType(Switch).last);
    expect(sw.value, isTrue);
  });

  testWidgets('flipping it saves vanishShareReads and nothing else', (t) async {
    final api = await open(t, {'seen': 'nobody'});
    await t.tap(find.text(title));
    await settle(t);
    expect(api.saved, hasLength(1));
    expect(api.saved.single, {'seen': null, 'vanishShareReads': true});
    expect(t.widget<Switch>(find.byType(Switch).last).value, isTrue);
  });
}
