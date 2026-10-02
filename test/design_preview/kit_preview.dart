// Renders the shared iOS kit (lib/widgets/ios_kit.dart) under a few themes.
//
//   flutter test test/design_preview/kit_preview.dart
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';

import 'preview_kit.dart';

class _KitPage extends StatelessWidget {
  const _KitPage();

  @override
  Widget build(BuildContext context) => IosPage(
        title: 'Settings',
        showBack: false,
        children: [
          GroupedSection(children: [
            GroupedRow(
              title: 'Murat Can',
              subtitle: '@murat · Profile, account, recovery',
              onTap: () {},
            ),
          ]),
          GroupedSection(header: 'Appearance', children: [
            GroupedRow(
              icon: CupertinoIcons.paintbrush_fill,
              tone: TileTone.indigo,
              title: 'Theme',
              value: 'Midnight',
              onTap: () {},
            ),
            GroupedRow(
              icon: CupertinoIcons.app_fill,
              tone: TileTone.blue,
              title: 'App Icon',
              value: 'Classic',
              onTap: () {},
            ),
            GroupedRow.toggle(
              icon: CupertinoIcons.drop_fill,
              tone: TileTone.teal,
              title: 'iOS Liquid Glass',
              value: true,
              onChanged: (_) {},
            ),
          ]),
          GroupedSection(
            header: 'Chat list',
            footer: 'Rows look like Messages; cards spell every detail out.',
            children: [
              GroupedRow.choice(title: 'Rows', selected: true, onTap: () {}),
              GroupedRow.choice(title: 'Cards', selected: false, onTap: () {}),
              GroupedRow.choice(title: 'Grid', selected: false, onTap: () {}),
            ],
          ),
          GroupedSection(children: [
            GroupedRow(
              icon: CupertinoIcons.bell_fill,
              tone: TileTone.red,
              title: 'Notifications',
              badge: 2,
              onTap: () {},
            ),
            GroupedRow(title: 'Sign Out', destructive: true, onTap: () {}),
          ]),
        ],
      );
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final id in ['basic', 'basic_daylight', 'risograph_pop', 'vault_noir']) {
    testWidgets('kit preview: $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const _KitPage()),
        'kit_$id.png',
      );
    });
  }
}
