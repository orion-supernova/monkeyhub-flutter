// What the browser and Linux show for the things that live only in the apps:
// a view once message, the transcript button, a secret room.
//
//   flutter test test/design_preview/app_only_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/privacy/app_only.dart';
import 'package:monkeyhub/privacy/capture_protection.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';

import 'preview_kit.dart';

class _Api extends Fake implements ChatApi {}

class _Cv extends Fake implements ConvexBackend {}

class _Opener extends StatefulWidget {
  const _Opener(this.open);
  final void Function(BuildContext) open;
  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

Widget _layout(Size size, Widget child) => LayoutScope(
      windowClass: size.width > 900 ? WindowClass.expanded : WindowClass.compact,
      width: size.width,
      child: child,
    );

void main() {
  setUpAll(loadPreviewFonts);
  tearDown(() => CaptureProtection.debugPlatformProtectsOverride = null);

  final themes = {
    'midnight': BasicTheme.midnight(),
    'daylight': BasicTheme.daylight(),
  };
  const desktop = Size(1280, 860);

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    testWidgets('view once sheet, phone $name', (tester) async {
      CaptureProtection.debugPlatformProtectsOverride = false;
      await snap(
        tester,
        _layout(kIphone16Pro, previewApp(theme, _Opener(AppOnly.confirmViewOnce))),
        'app_only_view_once_$name.png',
        // Frame by frame, so the sheet has finished rising.
        act: () async {},
      );
    });

    testWidgets('transcript sheet, desktop $name', (tester) async {
      await snap(
        tester,
        _layout(desktop, previewApp(theme, _Opener(AppOnly.explainTranscripts))),
        'app_only_transcript_$name.png',
        act: () async {},
        size: desktop,
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
      );
    });

    testWidgets('secret room gate, desktop $name', (tester) async {
      final repo = ChatRepository(api: _Api(), cv: _Cv());
      final room = ChatRoom(
        id: 'r1',
        name: 'After hours',
        createdBy: 'x',
        createdAt: DateTime(2026),
        isPrivate: true,
        memberCount: 3,
        type: RoomType.secret,
      );
      await snap(
        tester,
        _layout(desktop, previewApp(theme, SecretRoomGate(room: room, repo: repo))),
        'app_only_secret_room_$name.png',
        size: desktop,
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
      );
    });
  }
}
