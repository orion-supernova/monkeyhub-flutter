// Round-2 design spec: the CURRENT state of the surfaces the round-2 notes
// name that no other preview renders — the chat gallery pager, the room-info
// media grid tiles, every search-field variant side by side, and the point
// composer with the keyboard up (where it ran under the Dynamic Island).
//
//   flutter test test/design_preview/round2_spec_preview.dart
//
// Not a test. PNGs land in build/design_preview/r2_*.png.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/feed_api.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/screens/feed/point_composer.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/expressions/sticker_search.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';
import 'package:monkeyhub/widgets/media_grid_tile.dart';
import 'package:monkeyhub/widgets/reaction_picker_sheet.dart' show EmojiSearchBar;
import 'package:monkeyhub/widgets/search_field.dart';
import 'package:monkeyhub/widgets/settings_search.dart';

import 'preview_kit.dart';

class _ChatApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

class _FeedApi extends Fake implements FeedApi {}

ChatMessage _m(String id, {MessageType type = MessageType.image, int? dur}) =>
    ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: 'u1',
      senderName: 'Ece Yıldız',
      content: '',
      createdAt: DateTime(2026, 10, 3, 14, 32),
      type: type,
      mediaStorageId: 'stor_$id',
      mediaWidth: 1200,
      mediaHeight: 1600,
      mediaDurationMs: dur,
    );

class _Opener extends StatefulWidget {
  const _Opener({required this.open});
  final void Function(BuildContext context) open;
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
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
        children: [
          Text('Feed', style: theme.displayLarge),
          for (var i = 0; i < 9; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Row $i', style: theme.bodyEmph),
            ),
        ],
      ),
    );
  }
}

class _Searches extends StatelessWidget {
  const _Searches();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final empty = TextEditingController();
    final filled = TextEditingController(text: 'deniz');
    Widget label(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 0, 6),
          child: Text(s, style: groupedMetaStyle(theme)),
        );
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 0),
        children: [
          label('SearchField (search screen, pickers, sheets) — empty'),
          SearchField(controller: empty, hintText: 'Search', onChanged: (_) {}),
          label('SearchField — with text'),
          SearchField(controller: filled, hintText: 'Search', onChanged: (_) {}),
          label('SettingsSearchField (Settings hub)'),
          SettingsSearchField(
            controller: TextEditingController(),
            focusNode: FocusNode(),
            onChanged: (_) {},
          ),
          label('StickerSearchField (expression panel)'),
          StickerSearchField(
            controller: TextEditingController(),
            focus: FocusNode(),
            onChanged: (_) {},
          ),
          label('SearchField.door (Discover)'),
          SearchField.door(hint: 'Search people', onTap: () {}),
          label('EmojiSearchBar (reaction picker door; own 10pt inset)'),
          EmojiSearchBar(onTap: () {}, bottomSafe: 0),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final api = _ChatApi();
    final items = [
      for (var i = 0; i < 14; i++)
        _m('g$i',
            type: i % 5 == 2 ? MessageType.video : MessageType.image,
            dur: i % 5 == 2 ? 42000 : null),
    ];
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(2, 60, 2, 0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => MediaGridTile(
            message: items[i],
            api: api,
            selected: i == 1 || i == 4,
            selecting: i < 6,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final id in ['basic', 'basic_daylight']) {
    final theme = ThemeController.byId(id);
    testWidgets('r2 pager $id', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          MediaPagerScreen(
            items: [for (var i = 0; i < 8; i++) _m('p$i')],
            initialIndex: 2,
            api: _ChatApi(),
            onShowInChat: (_) {},
          ),
        ),
        'r2_pager_$id.png',
      );
    });
    testWidgets('r2 grid $id', (tester) async {
      await snap(tester, previewApp(theme, const _Grid()), 'r2_grid_$id.png');
    });
    testWidgets('r2 search $id', (tester) async {
      await snap(
          tester, previewApp(theme, const _Searches()), 'r2_search_$id.png');
    });
    testWidgets('r2 point keyboard $id', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      addTearDown(tester.view.resetViewInsets);
      await snap(
        tester,
        previewApp(
          theme,
          _Opener(
            open: (c) => showPointComposer(c,
                api: _ChatApi(),
                feedApi: _FeedApi(),
                userId: 'me',
                initialTag: MomentTag.jinx),
          ),
        ),
        'r2_point_kb_$id.png',
      );
    });
  }
}
