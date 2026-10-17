import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/composer/capture_machine.dart';
import 'package:monkeyhub/composer/capture_recorder.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/widgets/composer_capture.dart';
import 'package:monkeyhub/widgets/send_flight.dart';

/// A sent video note's circle flies down into its bubble: the bubble stays
/// hidden while the circle is in the air, takes over as it lands, and the
/// landing is felt. With no bubble to land on, or with motion calmed, the
/// circle shrinks where it is as it always did.
///
/// `--dart-define=PNG=<dir>` writes frames of the flight there, to look at.
void main() {
  const pngDir = String.fromEnvironment('PNG');
  late List<String> haptics;

  setUp(() {
    haptics = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final shot = GlobalKey();
  const bubbleKey = ValueKey('bubble');

  Widget host(ComposerCaptureController controller, {required bool land, bool calm = false}) {
    var sent = false;
    return RepaintBoundary(
      key: shot,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: calm),
            child: ThemeScope(
              controller: ThemeController(BasicTheme.midnight()),
              child: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  backgroundColor: const Color(0xFF15171C),
                  body: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          children: [
                            if (sent)
                              Align(
                                alignment: Alignment.centerRight,
                                child: SendFlightLanding(
                                  key: bubbleKey,
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF2E9E6B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            for (var i = 0; i < 4; i++)
                              Align(
                                alignment: i.isEven ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  width: 180,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: i.isEven ? const Color(0xFF2A2D35) : const Color(0xFF3A5BD9),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ChatComposerClassic(
                        controller: TextEditingController(),
                        ephemeral: false,
                        onSend: () {},
                        onAttach: () {},
                        onCamera: () {},
                        capture: ComposerCapture(
                          modes: ComposerInputMode.values,
                          onCamera: () {},
                          controller: controller,
                          onCaptured: (mode, _) {
                            if (land) setState(() => sent = true);
                          },
                          onProblem: (_) {},
                          recorderFactory: (_) => _FakeRecorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> png(WidgetTester tester, String name) async {
    if (pngDir.isEmpty) return;
    await tester.runAsync(() async {
      final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$pngDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
  }

  Future<void> recordAndSend(WidgetTester tester, ComposerCaptureController controller) async {
    final l10n = AppLocalizationsEn();
    controller.requestMode(ComposerInputMode.videoNote);
    await _frames(tester, 30);
    await tester.tap(find.bySemanticsLabel(l10n.composerCaptureStartRecordingLabel));
    await _frames(tester, 30);
    await tester.tap(find.bySemanticsLabel(l10n.composerCaptureSendLabel));
  }

  double bubbleOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find.descendant(of: find.byKey(bubbleKey), matching: find.byType(Opacity)).first)
      .opacity;

  testWidgets('the circle flies into its bubble and hands over on landing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ComposerCaptureController();
    final app = host(controller, land: true);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await recordAndSend(tester, controller);
    await tester.pump();
    await tester.pump();
    await png(tester, '0-handover');
    expect(find.byKey(bubbleKey), findsOneWidget);
    expect(bubbleOpacity(tester), 0, reason: 'hidden while the circle is in the air');

    // In the air for most of the flight; the bubble only shows as the
    // circle reaches it.
    final revealed = <double>[];
    for (var i = 1; i <= 6; i++) {
      await _frames(tester, 4);
      await png(tester, '$i-flight');
      revealed.add(bubbleOpacity(tester));
    }
    expect(revealed.first, 0);
    expect(revealed, orderedEquals([...revealed]..sort()));
    await _frames(tester, 20);
    await png(tester, '9-landed');
    expect(bubbleOpacity(tester), 1);
    expect(SendFlight.current, isNull);
    expect(haptics.where((h) => h.contains('lightImpact')), isNotEmpty);
    await _frames(tester, 200);
  });

  testWidgets('with no bubble to land on, it gives up and shrinks in place', (tester) async {
    final controller = ComposerCaptureController();
    final app = host(controller, land: false);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await recordAndSend(tester, controller);
    await _frames(tester, 10);
    expect(SendFlight.current, isNotNull, reason: 'still waiting for a landing');
    await _frames(tester, 60);
    expect(SendFlight.current, isNull);
    expect(find.text(AppLocalizationsEn().glassScreenPreviewBadge), findsNothing);
    await _frames(tester, 200);
  });

  testWidgets('calm motion never opens a flight', (tester) async {
    final controller = ComposerCaptureController();
    final app = host(controller, land: true, calm: true);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await recordAndSend(tester, controller);
    await tester.pump();
    expect(SendFlight.current, isNull);
    await _frames(tester, 10);
    // Not held back: there is no circle coming for it.
    expect(
      find.descendant(of: find.byKey(bubbleKey), matching: find.byType(Opacity)),
      findsNothing,
    );
  });
}

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

class _FakeRecorder implements CaptureRecorder {
  @override
  VoidCallback? onSessionLost;

  @override
  Stream<double>? get levels => null;

  @override
  Future<void> start() async {}

  @override
  Future<CaptureOutcome> stop() async => CaptureOutcome(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        contentType: 'video/mp4',
        duration: const Duration(seconds: 4),
      );

  @override
  Future<CaptureSegment> stopSegment() async => const CaptureSegment(
        path: '',
        duration: Duration(seconds: 2),
        contentType: 'video/mp4',
      );

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
