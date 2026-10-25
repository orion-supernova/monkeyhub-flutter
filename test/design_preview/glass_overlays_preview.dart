// Glass overlay primitives: progress dialog, HUD, scan frame.
//
//   flutter test test/design_preview/glass_overlays_preview.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/glass_hud.dart';
import 'package:monkeyhub/widgets/glass_progress_dialog.dart';
import 'package:monkeyhub/widgets/scan_frame_overlay.dart';

import 'preview_kit.dart';

Widget _card(Widget child) => Padding(padding: const EdgeInsets.all(10), child: child);

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
    // SF Pro is macOS-only: stand Inter in for the Basic themes' families.
    for (final family in const ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
      final loader = FontLoader(family);
      for (final w in const ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final b = File('assets/google_fonts/Inter-$w.ttf').readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(b.buffer)));
      }
      await loader.load();
    }
  });

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('glass overlays: $id', (tester) async {
      final theme = ThemeController.byId(id);
      await snap(
        tester,
        previewApp(
          theme,
          Builder(builder: (context) {
            // Static cards on the page: the same widgets the routes host.
            Widget prog(double? v, String msg) => _card(GlassOverlayCard(
                  width: 270,
                  radius: (theme.radiusXl * 1.4).clamp(10.0, 30.0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ProgressRing(value: v),
                        const SizedBox(height: 16),
                        Text('Syncing Messages…',
                            style: theme.body.copyWith(
                                fontSize: 17, fontWeight: FontWeight.w600, color: theme.ink)),
                        const SizedBox(height: 4),
                        Text(msg,
                            style: theme.body.copyWith(fontSize: 13, color: theme.inkMuted)),
                      ]),
                    ),
                    Container(height: 0.5, color: theme.ink.withValues(alpha: 0.16)),
                    SizedBox(
                      height: 46,
                      child: Center(
                        child: Text('Cancel',
                            style: theme.body.copyWith(
                                fontSize: 17,
                                color: v != null && v >= 1
                                    ? theme.inkMuted.withValues(alpha: 0.5)
                                    : theme.accent)),
                      ),
                    ),
                  ]),
                ));
            Widget hud(Widget icon, String label) => _card(GlassOverlayCard(
                  width: 160,
                  height: 160,
                  radius: 22,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 64, height: 64, child: icon),
                    const SizedBox(height: 14),
                    Text(label,
                        style: theme.body.copyWith(
                            fontSize: 15, fontWeight: FontWeight.w600, color: theme.ink)),
                  ]),
                ));
            return SingleChildScrollView(
              padding: const EdgeInsets.only(top: 60),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  prog(0.0, '0%'),
                ]),
                prog(0.55, '55%'),
                prog(1.0, '100%'),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  hud(Icon(Icons.lock_open_rounded, size: 64, color: theme.ink), 'Unlocked'),
                  hud(GlassHudCheck(size: 64, color: theme.ink), 'Done'),
                ]),
                Container(
                  margin: const EdgeInsets.all(16),
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0B1220), Color(0xFF3B2A4A)],
                    ),
                  ),
                  child: const Center(child: ScanFrameOverlay()),
                ),
              ]),
            );
          }),
        ),
        'glass_overlays_$id.png',
        size: const Size(393, 1500),
        settle: const Duration(milliseconds: 900),
      );
    });
  }
}
