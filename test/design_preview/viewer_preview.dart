// The shared media-viewer chrome (ViewerTopBar + media-tone glass buttons and
// pills) over a bright, busy "photo", the case that has to stay legible.
//
//   flutter test test/design_preview/viewer_preview.dart
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';
import 'package:monkeyhub/widgets/viewer_chrome.dart';

import 'preview_kit.dart';

class _Scene extends StatelessWidget {
  const _Scene();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // A bright sky over a darker ground: the worst case for white glass.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFBFE3FF),
                    Color(0xFFFFD9A0),
                    Color(0xFF3D6B3A),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ViewerTopBar(
              onClose: () {},
              title: 'Ece',
              subtitle: '3 of 12',
              actions: [
                GlassIconButton(
                  tone: GlassTone.media,
                  icon: CupertinoIcons.chat_bubble,
                  onTap: () {},
                ),
              ],
            ),
          ),
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: ViewerTopBar(onClose: () {}),
          ),
          Positioned(
            top: 260,
            left: 0,
            right: 0,
            child: ViewerTopBar(
              onClose: () {},
              center: const Text(
                '1 · View once',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 60,
            child: Row(
              children: [
                GlassIconButton(
                  tone: GlassTone.media,
                  icon: CupertinoIcons.pencil,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                GlassIconButton(
                  tone: GlassTone.media,
                  icon: CupertinoIcons.textformat,
                  tint: theme.accent,
                  color: theme.accentInk,
                  onTap: () {},
                ),
                const SizedBox(width: 10),
                GlassIconButton(
                  tone: GlassTone.media,
                  icon: CupertinoIcons.crop,
                  onTap: null,
                ),
                const Spacer(),
                GlassPillButton(
                  tone: GlassTone.media,
                  label: 'SEND',
                  icon: CupertinoIcons.arrow_up,
                  tint: theme.accent,
                  onTap: () {},
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            bottom: 140,
            child: Row(
              children: [
                GlassIconButton(icon: CupertinoIcons.chevron_back, onTap: () {}),
                const SizedBox(width: 10),
                GlassPillButton(label: 'Done', onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('viewer preview: $id', (tester) async {
      await snap(
        tester,
        previewApp(ThemeController.byId(id), const _Scene()),
        'viewer_$id.png',
      );
    });
  }
}
