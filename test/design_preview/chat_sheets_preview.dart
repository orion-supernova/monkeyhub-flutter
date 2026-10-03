// The sheets that open from inside a chat, over a page, under a few themes.
//
//   flutter test test/design_preview/chat_sheets_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monkeyhub/expressions/expression_store.dart';
import 'package:monkeyhub/models/sticker_pack.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/expressions/expression_panel.dart';
import 'package:monkeyhub/widgets/attachment_menu.dart';
import 'package:monkeyhub/widgets/location_share_sheet.dart';
import 'package:monkeyhub/widgets/schedule_message_sheet.dart';

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
          Text('Ece', style: theme.displayLarge),
          for (var i = 0; i < 9; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Message $i', style: theme.body),
            ),
        ],
      ),
    );
  }
}

final Map<String, void Function(BuildContext)> sheets = {
  'plus': (c) => showAttachmentMenu(c),
  'schedule': (c) => showScheduleMessageSheet(
        c,
        preview: 'happy birthday! 🎂 can’t wait for tonight',
        queuedCount: 2,
      ),
  'schedule_pick': (c) => showScheduleMessageSheet(
        c,
        mode: ScheduleSheetMode.reschedule,
        initial: DateTime.now().add(const Duration(days: 2, hours: 3)),
      ),
  'location': (c) => showLocationShareSheet(c),
};

/// The composer's stickers panel, docked at the bottom of a chat.
class _PanelPage extends StatelessWidget {
  const _PanelPage({required this.stickers});
  final bool stickers;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
              children: [Text('Ece', style: theme.displayLarge)],
            ),
          ),
          ExpressionPanel(
            composer: TextEditingController(),
            onSend: (_, {query}) {},
            height: 340,
            bottomPadding: 34,
          ),
        ],
      ),
    );
  }
}

const _pack = StickerPack(
  id: 'p1',
  slug: 'noto-moods',
  title: 'Moods',
  personal: false,
  author: 'Google',
  license: 'CC BY 4.0',
  stickers: [],
);

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    // The emoji picker reads its recents from here.
    SharedPreferences.setMockInitialValues({});
    ExpressionStore.instance.debugSeed(packs: const [_pack]);
  });
  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    testWidgets('chat sheet panel_stickers $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const _PanelPage(stickers: true)),
        'cs_panel_stickers_$id.png',
        act: () async {
          await tester.tap(find.text('Stickers'));
        },
      );
    });
  }
  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    for (final e in sheets.entries) {
      testWidgets('chat sheet ${e.key} $id', (tester) async {
        await snap(
          tester,
          previewApp(ThemeController.byId(id), _Page(open: e.value)),
          'cs_${e.key}_$id.png',
          // Steps frame by frame so the sheet's rise actually completes.
          act: () async {},
        );
      });
    }
  }
}
