// Renders the second batch of restyled sheets and controls over a page.
//
//   flutter test test/design_preview/sheets2_preview.dart
//   flutter test test/design_preview/sheets2_preview.dart --plain-name report
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/screens/friend_request_draft_screen.dart';
import 'package:monkeyhub/screens/interaction_compose_sheet.dart';
import 'package:monkeyhub/models/room_pin.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/pinned_list_sheet.dart';
import 'package:monkeyhub/widgets/moment_reactor_sheet.dart';
import 'package:monkeyhub/widgets/password_prompt_sheet.dart';
import 'package:monkeyhub/widgets/report_sheet.dart';

import 'preview_kit.dart';

/// A page with something on it, so the dim and the sheet's edge read.
class _Page extends StatefulWidget {
  const _Page({required this.open});
  final void Function(BuildContext context) open;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
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

class _FakeApi extends Fake implements ChatApi {}

class _PinRepo extends Fake implements ChatRepository {
  @override
  List<RoomPin> pinsFor(String roomId) => [
        for (final (who, text) in const [
          ('Ece', 'Dinner moved to 8, same place'),
          ('Deniz Kaya', 'Wifi password: monkeys-on-the-roof'),
          ('Mom', 'Bring the blue folder on Sunday'),
        ])
          RoomPin(
            message: ChatMessage(
              id: who,
              roomId: 'r',
              senderId: who,
              senderName: who,
              content: text,
              createdAt: DateTime(2026, 10, 2, 18, 40),
              type: MessageType.text,
            ),
            pinnedAt: DateTime(2026, 10, 2, 19),
            pinnedBy: 'me',
          ),
      ];
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

final Map<String, void Function(BuildContext)> _sheets = {
  'pinned': (c) => showAdaptiveSheet<void>(
        c,
        builder: (_) => PinnedListSheet(
          repo: _PinRepo(),
          api: _FakeApi(),
          roomId: 'r',
          onJump: (_) {},
        ),
      ),
  'password': (c) => askPassword(
        c,
        title: 'Link Apple account',
        actionLabel: 'Continue',
        subtitle: 'Enter your password to link a new sign-in.',
      ),
  'report': (c) => showReportSheet(c),
  'poll': (c) => showInteractionComposeSheet(c, kind: MessageType.poll),
  'reactor': (c) => showMomentReactorSheet(
        c,
        emoji: '🔥',
        names: const ['Ece', 'Deniz Kaya', 'Mom', 'Arda', 'Zeynep'],
      ),
};

class _DraftRepo extends Fake implements ChatRepository {
  @override
  List<FriendRequest> get incomingRequests => const [];
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

/// Extra screens or controls that are not sheets, rendered as whole pages.
final Map<String, Widget> _pages = {
  'draft': FriendRequestDraftScreen(
    repo: _DraftRepo(),
    api: _FakeApi(),
    target: ChatUser(id: 'u_ece', username: 'ece', name: 'Ece Yıldız'),
  ),
};

void main() {
  setUpAll(loadPreviewFonts);
  const themes = ['basic', 'basic_daylight', 'risograph_pop'];
  for (final id in themes) {
    for (final e in _sheets.entries) {
      testWidgets('sheet ${e.key}: $id', (tester) async {
        await _snapAfterOpen(
          tester,
          previewApp(ThemeController.byId(id), _Page(open: e.value)),
          's2_${e.key}_$id.png',
        );
      });
    }
    for (final e in _pages.entries) {
      testWidgets('page ${e.key}: $id', (tester) async {
        await _snapAfterOpen(
          tester,
          previewApp(ThemeController.byId(id), e.value),
          's2_${e.key}_$id.png',
        );
      });
    }
  }
}

/// [snap], but stepping the clock frame by frame afterwards: a route pushed
/// from a post-frame callback only starts its transition on the NEXT frame.
Future<void> _snapAfterOpen(
  WidgetTester tester,
  Widget widget,
  String name,
) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = kIphone16Pro * dpr;
  final pad = FakeViewPadding(
    top: kIphoneTopInset * dpr,
    bottom: kIphoneBottomInset * dpr,
  );
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: widget));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final out = File('$kPreviewDir/$name');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(bytes!);
}
