// Renders the Settings hub and its appearance/chat sub-pages under a few
// themes, so the iOS redesign can be looked at.
//
//   flutter test test/design_preview/settings_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/session_store.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/family/family_service.dart';
import 'package:monkeyhub/screens/bubble_style_screen.dart';
import 'package:monkeyhub/screens/chat_style_screen.dart';
import 'package:monkeyhub/screens/language_screen.dart';
import 'package:monkeyhub/screens/motion_screen.dart';
import 'package:monkeyhub/screens/navigation_screen.dart';
import 'package:monkeyhub/screens/reply_style_screen.dart';
import 'package:monkeyhub/screens/room_layout_screen.dart';
import 'package:monkeyhub/screens/settings_screen.dart';
import 'package:monkeyhub/screens/speaker_color_screen.dart';
import 'package:monkeyhub/screens/theme_screen.dart';
import 'package:monkeyhub/screens/video_quality_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'preview_kit.dart';

class _FakeApi extends Fake implements ChatApi {}

class _FakeRepo extends Fake implements ChatRepository {}

class _FakeAuth extends ChangeNotifier implements AuthService {
  @override
  Session? get session =>
      Session(userId: 'me', username: 'murat', name: 'Murat Can');

  @override
  bool get isChild => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFamily extends ChangeNotifier implements FamilyService {
  @override
  int get pendingCount => 0;

  @override
  Future<void> refresh() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Which pages to render, by short name.
final _pages = <String, Widget Function()>{
  'hub': () => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => SettingsScreen(
            repo: _FakeRepo(),
            api: _FakeApi(),
            auth: _FakeAuth(),
            family: _FakeFamily(),
          ),
        ),
      ),
  'theme': () => const ThemeScreen(),
  'layout': () => const RoomLayoutScreen(),
  'chatstyle': () => const ChatStyleScreen(),
  'bubble': () => const BubbleStyleScreen(),
  'reply': () => ReplyStyleScreen(api: _FakeApi()),
  'motion': () => const MotionScreen(),
  'nav': () => const NavigationScreen(),
  'language': () => const LanguageScreen(),
  'speaker': () => const SpeakerColorScreen(),
  'video': () => const VideoQualityScreen(),
};

const _themes = ['basic', 'basic_daylight', 'risograph_pop', 'neon_night'];

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    PackageInfo.setMockInitialValues(
      appName: 'MonkeyHub',
      packageName: 'app',
      version: '1.3.112',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  const only = String.fromEnvironment('PAGES');
  for (final entry in _pages.entries) {
    if (only.isNotEmpty && !only.split(',').contains(entry.key)) continue;
    for (final id in _themes) {
      testWidgets('settings preview: ${entry.key} $id', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), entry.value()),
          'set_${entry.key}_$id.png',
          size: const Size(393, 1700),
          dpr: 2,
        );
      });
    }
  }
}
