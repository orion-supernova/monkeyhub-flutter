// Who reacted to a highlight: the avatar row over a story, and the sheet it
// opens (names, handles, every emoji, one capsule per emoji).
//
//   flutter test test/design_preview/moment_reactions_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_reactions.dart';

import 'preview_kit.dart';

final _api = ChatApi(ConvexBackend.instance);
final _t0 = DateTime(2026, 10, 8, 12);

MomentReactor _r(String id, String name, String emoji, int minute) => MomentReactor(
      emoji: emoji,
      userId: id,
      name: name,
      username: name.toLowerCase(),
      createdAt: _t0.add(Duration(minutes: minute)),
    );

final _reactors = [
  _r('ece', 'Johnathan Coachman-Whitfield', '❤️', 1),
  _r('ece', 'Johnathan Coachman-Whitfield', '😂', 9),
  _r('can', 'Can', '🔥', 4),
  _r('deniz', 'Deniz', '😮', 6),
  _r('me', 'Murat', '👏', 7),
  _r('selin', 'Selin', '❤️', 2),
  _r('selin', 'Selin', '🔥', 3),
  _r('selin', 'Selin', '😂', 5),
];

class _Host extends StatefulWidget {
  const _Host({required this.openSheet});
  final bool openSheet;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void initState() {
    super.initState();
    if (widget.openSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showMomentReactions(
            context,
            reactors: _reactors,
            api: _api,
            viewerId: 'me',
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2B3440),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
          child: MomentReactorStack(
            groups: groupReactors(_reactors),
            api: _api,
            viewerId: 'me',
            onTap: () {},
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final (name, sheet) in [('row', false), ('sheet', true)]) {
    testWidgets('moment reactions $name', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId('basic'), _Host(openSheet: sheet)),
        'moment_reactions_$name.png',
        act: () async {
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        },
      );
    });
  }
}
