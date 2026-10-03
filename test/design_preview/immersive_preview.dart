// Immersive screens: the call chrome (voice-call backdrop + tray) and, as
// they land, the viewers and recorder.
//
//   flutter test test/design_preview/immersive_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/voice_recorder_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'preview_kit.dart';

class _VoiceCall extends StatelessWidget {
  const _VoiceCall();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final actions = [
      CallTrayAction(icon: Icons.mic_off, label: 'Mute', onTap: () {}),
      CallTrayAction(
        icon: Icons.videocam,
        label: 'Camera',
        onTap: () {},
      ),
      CallTrayAction(
        icon: Icons.volume_up,
        label: 'Speaker',
        onTap: () {},
        active: true,
      ),
      CallTrayAction(icon: Icons.ios_share, label: 'Share', onTap: () {}),
      CallTrayAction(icon: Icons.more_horiz, label: 'More', onTap: () {}),
    ];
    final inset = CallTray.estimateHeight(
      actionCount: actions.length,
      width: MediaQuery.sizeOf(context).width,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AudioBackdrop(
            name: 'Ece Yıldız',
            status: Text('04:12', style: callStatusStyle(theme)),
            theme: theme,
            user: ChatUser(id: 'u_ece', username: 'ece', name: 'Ece'),
            bottomInset: inset,
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 80,
            left: 0,
            right: 0,
            child: const OverlayChip(label: 'Reconnecting…'),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CallTray(
                  actions: actions,
                  endIcon: Icons.call_end,
                  endLabel: 'End',
                  endColor: theme.danger,
                  onEnd: () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  // The recorder creates a native recorder on open; nothing records here.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => call.method == 'hasPermission' ? false : null,
    );
  });
  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    testWidgets('immersive preview: voice call $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const _VoiceCall()),
        'imm_voice_$id.png',
      );
    });
  }
  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('immersive preview: recorder $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const VoiceRecorderScreen()),
        'imm_recorder_$id.png',
      );
    });
  }
}
