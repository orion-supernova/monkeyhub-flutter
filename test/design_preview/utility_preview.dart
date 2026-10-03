// Renders the utility and flow pages (server, child pairing and setup,
// social username, report a problem, the approval gate) under a few themes.
// Not a test — run by path:
//
//   flutter test test/design_preview/utility_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_service.dart';
import 'package:monkeyhub/auth/social_sign_in.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/screens/child_pair_screen.dart';
import 'package:monkeyhub/screens/child_setup_screen.dart';
import 'package:monkeyhub/screens/server_screen.dart';
import 'package:monkeyhub/screens/social_username_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/approval_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

const _themes = ['basic', 'basic_daylight', 'risograph_pop'];

const _credential = SocialCredential(
  provider: SocialProvider.apple,
  idToken: 'header.payload.signature',
  rawNonce: 'nonce',
);

/// A page that opens the approval gate on its first frame, so the sheet can
/// be captured the way a child meets it.
class _GateHost extends StatefulWidget {
  const _GateHost();
  @override
  State<_GateHost> createState() => _GateHostState();
}

class _GateHostState extends State<_GateHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showApprovalGate(
        context,
        what: 'join Weekend Crew',
        detail: 'A public room with 248 members.',
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: WaitingPill()),
      );
}

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AuthService auth() => AuthService(ChatApi(ConvexBackend.instance));

  final pages = <String, Widget Function()>{
    'server': () => const ServerScreen(),
    'childpair': () => ChildPairScreen(auth: auth(), onCancel: () {}),
    'childsetup': () => ChildSetupScreen(
          api: ChatApi(ConvexBackend.instance),
          guardianId: 'me',
        ),
    'social': () => SocialUsernameScreen(
          auth: auth(),
          credential: _credential,
          suggestedName: 'Murat',
        ),
    'gate': () => const _GateHost(),
  };

  for (final id in _themes) {
    for (final entry in pages.entries) {
      testWidgets('utility preview: ${entry.key} $id', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), entry.value()),
          'util_${entry.key}_$id.png',
          // Frame-stepped, so the gate's sheet finishes rising.
          act: () async {},
        );
      });
    }
  }
}
