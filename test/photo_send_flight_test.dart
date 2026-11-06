import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/photo_send_flight.dart';
import 'package:monkeyhub/widgets/send_flight.dart';

/// The photo preview's Send flies the picture into its new bubble: the
/// bubble is hidden while the picture is in the air, shown fully once it has
/// landed, and the flight leaves nothing behind in the overlay. A send with
/// no bubble to land on fades out and still never leaves a bubble hidden.
void main() {
  Future<ui.Image> still(WidgetTester tester) async =>
      (await tester.runAsync(() {
        final rec = ui.PictureRecorder();
        Canvas(rec).drawRect(
          const Rect.fromLTWH(0, 0, 60, 80),
          Paint()..color = const Color(0xFFE0688A),
        );
        return rec.endRecording().toImage(60, 80);
      }))!;

  double landingOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find.descendant(
        of: find.byType(SendFlightLanding),
        matching: find.byType(Opacity),
      ))
      .opacity;

  testWidgets('the bubble stays hidden until the picture lands on it', (
    tester,
  ) async {
    final image = await still(tester);
    final show = ValueNotifier(false);
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return Stack(children: [
          Positioned(
            right: 10,
            bottom: 100,
            child: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, v, _) => v
                  ? const SendFlightLanding(
                      kind: SendFlightKind.photo,
                      child: SizedBox(width: 200, height: 260),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ]);
      }),
    ));

    PhotoSendFlight.launch(
      ctx,
      image: image,
      src: const Rect.fromLTWH(0, 0, 60, 80),
      from: const Rect.fromLTWH(0, 100, 400, 530),
    );
    await tester.pump();
    // The preview has closed and the transcript adds the new bubble.
    show.value = true;
    await tester.pump();
    expect(SendFlight.current?.claimed, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(landingOpacity(tester), 0, reason: 'still in the air');

    await tester.pumpAndSettle();
    expect(landingOpacity(tester), 1);
    expect(SendFlight.current, isNull);
  });

  testWidgets('with no bubble, the picture fades and the ticket closes', (
    tester,
  ) async {
    final image = await still(tester);
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      }),
    ));
    PhotoSendFlight.launch(
      ctx,
      image: image,
      src: const Rect.fromLTWH(0, 0, 60, 80),
      from: const Rect.fromLTWH(0, 100, 400, 530),
    );
    final ticket = SendFlight.current!;
    await tester.pumpAndSettle();
    expect(ticket.closed, isTrue);
    expect(ticket.reveal.value, 1);
  });

  // The landing used to wrap the picture alone, and the flight aimed at the
  // whole bubble: the caption's bubble sat on screen under an empty slot, and
  // the picture squashed into the caption's room.
  testWidgets('a caption flies with its picture and lands on the caption', (
    tester,
  ) async {
    final image = await still(tester);
    final show = ValueNotifier(false);
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return Stack(children: [
          Positioned(
            right: 10,
            bottom: 100,
            child: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, v, _) => v
                  ? const SendFlightLanding(
                      kind: SendFlightKind.photo,
                      color: Color(0xFF3478F6),
                      textStyle: TextStyle(fontSize: 15),
                      child: SizedBox(
                        width: 200,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          SendFlightMark(
                            part: SendFlightPart.media,
                            child: SizedBox(height: 240),
                          ),
                          SendFlightMark(
                            part: SendFlightPart.caption,
                            child: SizedBox(height: 40),
                          ),
                        ]),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ]);
      }),
    ));

    PhotoSendFlight.launch(
      ctx,
      image: image,
      src: const Rect.fromLTWH(0, 0, 60, 80),
      from: const Rect.fromLTWH(0, 100, 400, 530),
      caption: 'sunset at the pier',
      captionFrom: const Rect.fromLTWH(30, 700, 300, 21),
      captionStyle: const TextStyle(fontSize: 16),
    );
    await tester.pump();
    show.value = true;
    await tester.pump();
    final ticket = SendFlight.current!;
    final space = tester.renderObject<RenderBox>(find.byType(Overlay).first);
    expect(ticket.partIn(SendFlightPart.media, space)?.height, 240);
    expect(ticket.partIn(SendFlightPart.caption, space)?.height, 40);
    expect(ticket.textStyle?.fontSize, 15);
    await tester.pump(const Duration(milliseconds: 200));
    expect(landingOpacity(tester), 0, reason: 'caption and all, still away');
    await tester.pumpAndSettle();
    expect(landingOpacity(tester), 1);
    expect(tester.takeException(), isNull);
  });
}
