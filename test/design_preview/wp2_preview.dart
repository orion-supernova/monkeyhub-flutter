// WP2 glass controls: circles, pills, groups, capsules, segmented control, tab bar.
//
//   flutter test test/design_preview/wp2_preview.dart --dart-define=OUT=wp2_after
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/settings_store.dart' show HomeSection;
import 'package:monkeyhub/screens/navigation/pill_bottom_nav.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/action_buttons.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';
import 'package:monkeyhub/widgets/segmented_control.dart';

import 'preview_kit.dart';

const _out = String.fromEnvironment('OUT', defaultValue: 'wp2_after');

/// No SF Pro on Linux: stand Inter in for the Cupertino families.
Future<void> _inter() async {
  await loadPreviewFonts();
  final dir = 'assets/google_fonts';
  for (final family in const ['CupertinoSystemText', 'CupertinoSystemDisplay', 'Roboto']) {
    final loader = FontLoader(family);
    for (final w in ['Regular', 'Medium', 'Bold']) {
      final f = File('$dir/Inter-$w.ttf');
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      }
    }
    await loader.load();
  }
}

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.indigo.shade400, Colors.teal.shade300, Colors.orange.shade300],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(children: [
                  GlassBackButton(onTap: () {}),
                  const SizedBox(width: 12),
                  GlassCloseButton(onTap: () {}),
                  const SizedBox(width: 12),
                  GlassIconButton(
                      key: const ValueKey('probe'),
                      icon: CupertinoIcons.ellipsis,
                      onTap: () {}),
                  const SizedBox(width: 12),
                  GlassIconButton(icon: CupertinoIcons.camera, tone: GlassTone.media, onTap: () {}),
                  const SizedBox(width: 12),
                  ChromeDisc(onTap: () {}, child: const Icon(CupertinoIcons.pencil, size: 20)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  GlassPillButton(label: 'Edit', onTap: () {}),
                  const SizedBox(width: 12),
                  GlassPillButton(label: 'Send', tint: Colors.blue, onTap: () {}),
                  const SizedBox(width: 12),
                  GlassButtonGroup(tone: GlassTone.app, items: [
                    GlassGroupItem(icon: CupertinoIcons.camera, semanticLabel: 'a', onTap: () {}),
                    GlassGroupItem(icon: CupertinoIcons.square_pencil, semanticLabel: 'b', onTap: () {}),
                  ]),
                ]),
                const SizedBox(height: 24),
                SheetActionButton(label: 'Continue', onTap: () {}),
                const SizedBox(height: 10),
                SheetActionButton(label: 'Cancel', tonal: true, onTap: () {}),
                const SizedBox(height: 20),
                IosSegmentedControl<int>(
                  segments: const [
                    IosSegment(value: 0, label: 'Chats'),
                    IosSegment(value: 1, label: 'Calls'),
                    IosSegment(value: 2, label: 'Saved'),
                  ],
                  value: 1,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
        PillBottomNav(
          active: HomeSection.chat,
          onSelect: (_) {},
          badges: const {},
        ),
      ],
    );
  }
}

void main() {
  setUpAll(_inter);
  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    testWidgets('wp2 $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const _Page()),
        'build/design_preview/$_out/wp2_$id.png',
      );
    });
  }
  testWidgets('wp2 pressed', (tester) async {
    TestGesture? g;
    await snap(
      tester,
      previewApp(ThemeController.byId('basic'), const _Page()),
      'build/design_preview/$_out/wp2_basic_pressed.png',
      settle: const Duration(milliseconds: 90),
      act: () async {
        g = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('probe'))),
          kind: PointerDeviceKind.touch,
        );
      },
    );
    await g?.up();
  });
}
