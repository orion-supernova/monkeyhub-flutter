import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/media/file_url_cache.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/media/video_file_cache.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/screens/fullscreen_video_viewer.dart';
import 'package:monkeyhub/widgets/video_message.dart';

/// What this pins: **the pre-ready states of `VideoPlayerSurface` fill the
/// screen, and the spinner inside them stays 32 points wide.**
///
/// Those states are a `Stack` with `StackFit.expand`, and that fit hands every
/// non-positioned child *tight* constraints equal to the stack — so the
/// `SizedBox(32, 32)` around the progress ring was silently overridden and the
/// ring drew at the size of the stack, which under the viewer's `Center` is the
/// entire screen. Tapping a video produced a screen-filling spinning circle.
/// The `Center` inside the expanded child is what makes a fixed size mean
/// anything again.
///
/// The first fix for that also boxed the plate in an `AspectRatio`, to stop it
/// snapping to the video's real shape once `initialize()` landed. That was
/// wrong in a way only a portrait video shows: `mediaAspectRatio` is null for
/// every video the sender couldn't measure, the fallback guessed 16∶9, and a
/// portrait poster letterboxed inside a landscape guess is a stamp floating in
/// the middle of a black screen. The plate fills instead, and `BoxFit.contain`
/// sizes the poster by its own true shape — the right box, with no ratio to
/// know. Both properties are invisible in a screenshot of the finished state,
/// which is why they are pinned here.
class _StalledApi extends Fake implements ChatApi {
  final Completer<String?> gate = Completer<String?>();

  @override
  Future<String?> getFileUrl(String storageId) => gate.future;
}

void main() {
  const viewport = Size(400, 800);

  late Directory cacheDir;

  setUp(() {
    FileUrlCache.instance
      ..debugReset()
      ..debugPersist = false;
    // A real empty directory, so the surface's "do I already have this on
    // disk" read is a deterministic miss rather than a path_provider channel
    // that isn't there under the test binding.
    cacheDir = Directory.systemTemp.createTempSync('mh_video_surface_test');
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = cacheDir;
  });

  tearDown(() {
    VideoFileCache.instance
      ..debugReset()
      ..debugDir = null;
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  /// Enough frames for the disk lookup and the URL resolve to settle. Not
  /// `pumpAndSettle` — the spinner animates forever, so it would time out.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  Widget host(Widget child) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('a video that is still resolving is a plate, not a portal', (
    tester,
  ) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _StalledApi();
    await tester.pumpWidget(
      host(
        VideoPlayerSurface(api: api, storageId: 'stalled_1'),
      ),
    );
    await settle(tester);

    expect(
      tester.getSize(find.byType(CircularProgressIndicator)),
      const Size(32, 32),
      reason: 'StackFit.expand hands tight constraints to unwrapped children',
    );
    expect(
      tester.getSize(find.byType(VideoPlayerSurface)),
      viewport,
      reason: 'the plate fills its box; the poster shapes itself inside it',
    );

    // Let the resolve answer so nothing is left holding the load timeout's
    // timer when the tree comes down.
    api.gate.complete(null);
    await settle(tester);

    expect(
      tester.getSize(find.byIcon(Icons.videocam_off_outlined)),
      const Size(36, 36),
      reason: 'the unavailable glyph is subject to the same expand',
    );
    expect(
      tester.getSize(find.byType(VideoPlayerSurface)),
      viewport,
      reason: 'and the error plate keeps the same geometry as the loading one',
    );
  });

  testWidgets('the viewer never boxes its plate at a guessed ratio', (
    tester,
  ) async {
    // The regression this replaces: the plate was boxed at 16∶9 whenever the
    // sender hadn't recorded a size, so a portrait video opened onto a
    // 400×225 letterbox — a stamp in the middle of an 800-tall black screen.
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _StalledApi();
    await tester.pumpWidget(
      host(FullscreenVideoViewer(storageId: 'stalled_2', api: api)),
    );
    await settle(tester);

    expect(
      tester.getSize(find.byType(VideoPlayerSurface)),
      viewport,
      reason: 'no ratio is guessed, so nothing can be guessed wrong',
    );

    api.gate.complete(null);
    await settle(tester);
  });

  testWidgets('the viewer falls back to the Flutter player, not an error', (
    tester,
  ) async {
    // The test VM is neither iOS nor Android, so `NativeVideoPlayer.supported`
    // is false — which makes this the exact path a web build takes. A viewer
    // that treated "no OS player here" as a failure would leave every web user
    // looking at an error where a working player belongs.
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _StalledApi();
    await tester.pumpWidget(
      host(
        FullscreenVideoViewer(storageId: 'stalled_3', api: api),
      ),
    );
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(VideoPlayerSurface), findsOneWidget);

    api.gate.complete(null);
    await settle(tester);
  });
}
