import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/widgets/departing_row.dart';
import 'package:monkeyhub/widgets/message_departures.dart';

/// How a captured bubble leaves: the row holds its height for the whole
/// flight on one ticker, then closes; calm motion closes it at once with no
/// ticker at all.
void main() {
  final born = DateTime(2026, 3, 1, 12);
  final message = ChatMessage(
    id: 'm1',
    roomId: 'r',
    senderId: 'alice',
    senderName: 'alice',
    content: 'going',
    createdAt: born,
    expiresAt: born.add(const Duration(minutes: 10)),
    type: MessageType.text,
    status: MessageStatus.sent,
  );

  ui.Image picture() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 200, 60),
      Paint()..color = const Color(0xFF3366FF),
    );
    return recorder.endRecording().toImageSync(200, 60);
  }

  DepartureCapture capture({ui.Image? image, bool isMine = false}) =>
      DepartureCapture(
        message: message,
        rowKey: 'm1',
        isMine: isMine,
        image: image,
        pixelRatio: 1,
        bubbleSize: const Size(200, 60),
        bubbleInRow: const Offset(8, 10),
        rowSize: const Size(320, 80),
        outline: Path()
          ..addRRect(RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 200, 60),
            const Radius.circular(16),
          )),
      );

  Widget host(DepartingRow row) => MaterialApp(
        home: Scaffold(
          body: Column(children: [row]),
        ),
      );

  double rowHeight(WidgetTester tester) =>
      tester.getSize(find.byType(DepartingRow)).height;

  testWidgets('full motion: one ticker, the row holds, then closes', (
    tester,
  ) async {
    final image = picture();
    var done = 0;
    await tester.pumpWidget(host(DepartingRow(
      capture: capture(image: image),
      calm: false,
      onDone: () => done++,
    )));
    expect(tester.binding.transientCallbackCount, 1,
        reason: 'exactly one ticker drives the whole exit');
    expect(rowHeight(tester), 80);

    await tester.pump(const Duration(milliseconds: 500));
    expect(rowHeight(tester), 80, reason: 'nothing below moves mid-flight');
    expect(done, 0);
    expect(tester.binding.transientCallbackCount, 1);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(rowHeight(tester), 80, reason: 'still being drawn off at 3s');
    expect(done, 0);

    await tester.pump(const Duration(milliseconds: 900));
    expect(rowHeight(tester), lessThan(80), reason: 'closing by 3.9s');
    expect(done, 0);

    await tester.pump(const Duration(milliseconds: 300));
    expect(done, 1, reason: 'finished a little after 4s');
    expect(rowHeight(tester), 0);
    expect(tester.binding.transientCallbackCount, 0);
    image.dispose();
  });

  testWidgets('calm motion: no ticker, the row closes at once', (tester) async {
    final image = picture();
    var done = 0;
    await tester.pumpWidget(host(DepartingRow(
      capture: capture(image: image),
      calm: true,
      onDone: () => done++,
    )));
    expect(tester.binding.transientCallbackCount, 0);
    expect(rowHeight(tester), 0);
    expect(done, 1, reason: 'one pump is enough');
    image.dispose();
  });

  testWidgets('a capture with no picture takes the calm path', (tester) async {
    var done = 0;
    await tester.pumpWidget(host(DepartingRow(
      capture: capture(image: null),
      calm: false,
      onDone: () => done++,
    )));
    expect(tester.binding.transientCallbackCount, 0);
    expect(rowHeight(tester), 0);
    expect(done, 1);
  });
}
