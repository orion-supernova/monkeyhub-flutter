/// Drives the voice and video note recorder on a real phone, in Saved
/// Messages, and screenshots every beat: the bloom, the lock, pause and the
/// review strip, a trim from both ends, the preview playing, the send, and
/// the video note's flash. The real microphone and camera, real gestures.
///
///     CAPTURE_SHOTS=/some/dir flutter drive \
///       --driver=test_driver/capture_flow_driver.dart \
///       --target=integration_test/capture_flow_test.dart -d <device>
///
/// Not part of `flutter test`: it needs a signed-in phone with the camera
/// and microphone already granted.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monkeyhub/main.dart' as app;
import 'package:monkeyhub/widgets/capture_review.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('voice and video notes, end to end', (tester) async {
    final semantics = tester.ensureSemantics();
    var n = 0;

    /// Real time passes; frames keep coming.
    Future<void> wait(int ms) async {
      final end = DateTime.now().add(Duration(milliseconds: ms));
      while (DateTime.now().isBefore(end)) {
        await tester.pump(const Duration(milliseconds: 32));
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }

    Future<void> shot(String name) async {
      await tester.pump();
      n++;
      await binding.takeScreenshot('${n.toString().padLeft(2, '0')}_$name');
    }

    Future<void> waitFor(Finder f, {int timeoutMs = 20000}) async {
      final end = DateTime.now().add(Duration(milliseconds: timeoutMs));
      while (f.evaluate().isEmpty && DateTime.now().isBefore(end)) {
        await wait(200);
      }
      expect(f, findsWidgets, reason: 'waited ${timeoutMs}ms for $f');
    }

    app.main();
    await wait(4000);
    await shot('launch');

    final saved = find.text('Saved Messages');
    await waitFor(saved);
    await tester.tap(saved.first);
    await wait(2500);
    await shot('saved_messages');

    // ── Voice ───────────────────────────────────────────────────────────
    final camera = find.byIcon(Icons.photo_camera_outlined);
    await waitFor(camera);
    await tester.drag(camera.first, const Offset(0, -60));
    await wait(800);
    final mic = find.byIcon(Icons.mic_none_outlined);
    await waitFor(mic);
    await shot('voice_mode');

    var g = await tester.startGesture(tester.getCenter(mic.first));
    await wait(450);
    await shot('voice_bloom');
    await wait(1800);
    await shot('voice_holding');
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, -5));
      await wait(30);
    }
    await shot('voice_lock_half');
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, -6));
      await wait(30);
    }
    await wait(300);
    await shot('voice_latched_finger_down');
    await g.up();
    await wait(1500);
    await shot('voice_locked');
    await wait(2500);

    await tester.tap(find.bySemanticsLabel('Pause recording'));
    await wait(1500);
    await shot('voice_paused_review');

    Rect track() => tester.getRect(find.descendant(of: find.byType(CaptureReviewStrip), matching: find.byType(LayoutBuilder)).first);
    var r = track();
    g = await tester.startGesture(Offset(r.left + 10, r.center.dy));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(5, 0));
      await wait(30);
    }
    await shot('voice_trim_start_dragging');
    await g.up();
    await wait(300);
    r = track();
    g = await tester.startGesture(Offset(r.right - 10, r.center.dy));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-5, 0));
      await wait(30);
    }
    await g.up();
    await wait(300);
    await shot('voice_trimmed');
    await tester.tap(find.bySemanticsLabel('Play recording'));
    await wait(900);
    await shot('voice_preview_playing');
    await wait(1500);
    await tester.tap(find.bySemanticsLabel('send recording').last);
    await wait(3000);
    await shot('voice_sent');

    // ── Video ───────────────────────────────────────────────────────────
    final micAgain = find.byIcon(Icons.mic_none_outlined);
    await waitFor(micAgain);
    await tester.drag(micAgain.first, const Offset(0, -60));
    await wait(1500);
    final video = find.byIcon(Icons.videocam_outlined);
    await waitFor(video);
    await shot('video_mode_small_preview');
    await tester.tap(video.first);
    await wait(250);
    await shot('video_staging_flight');
    await wait(1200);
    await shot('video_staged');
    await tester.tap(find.bySemanticsLabel('Start recording'));
    await wait(2500);
    await shot('video_recording');
    final flash = find.bySemanticsLabel('Flash');
    if (flash.evaluate().isNotEmpty) {
      await tester.tap(flash.first);
      await wait(900);
      await shot('video_flash_on');
      await tester.tap(flash.first);
      await wait(600);
    }
    await wait(1500);
    await tester.tap(find.bySemanticsLabel('Pause recording'));
    await wait(2500);
    await shot('video_paused_review');
    r = track();
    g = await tester.startGesture(Offset(r.right - 10, r.center.dy));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-6, 0));
      await wait(40);
    }
    await shot('video_trim_end_dragging');
    await g.up();
    await wait(600);
    await shot('video_trimmed');
    await tester.tap(find.bySemanticsLabel('Play recording'));
    await wait(1200);
    await shot('video_preview_playing');
    await wait(1500);
    await tester.tap(find.bySemanticsLabel('send recording').last);
    await wait(5000);
    await shot('video_sent');

    semantics.dispose();
  });
}
