import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/widgets/still_blur.dart';

/// The still blur against the live one it replaces: the same picture, and a
/// blur that is done once rather than every frame.
void main() {
  const key = ValueKey('shot');

  /// A picture with detail in it: hard edges and colour, the worst case for
  /// a blur done at a lower resolution.
  Widget picture(Color accent) => CustomPaint(
        size: const Size(240, 180),
        painter: _Picture(accent),
      );

  Future<Uint8List> pixels(WidgetTester tester) async {
    final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final image = b.toImageSync(pixelRatio: 3);
    final data = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Widget host(Widget child) => MaterialApp(
        home: Center(child: RepaintBoundary(key: key, child: child)),
      );

  testWidgets('looks like the live blur it replaces', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Widget live() => ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 20,
              sigmaY: 20,
              tileMode: TileMode.mirror,
            ),
            child: picture(Colors.orange),
          ),
        );
    Widget still() => ClipRect(
          child: StillBlur(sigma: 20, child: picture(Colors.orange)),
        );
    await tester.pumpWidget(host(live()));
    final a = await pixels(tester);
    await tester.pumpWidget(host(still()));
    final b = await pixels(tester);
    expect(a.length, b.length);

    var sum = 0;
    var worst = 0;
    final diff = Uint8List(a.length);
    for (var i = 0; i < a.length; i += 4) {
      var d = 0;
      for (var c = 0; c < 3; c++) {
        final e = (a[i + c] - b[i + c]).abs();
        if (e > d) d = e;
        sum += e;
      }
      if (d > worst) worst = d;
      // Amplified eight times, so a difference you could not see shows.
      final v = (d * 8).clamp(0, 255);
      diff
        ..[i] = v
        ..[i + 1] = v
        ..[i + 2] = v
        ..[i + 3] = 255;
    }
    final mean = sum / (a.length / 4 * 3);
    final out = Platform.environment['STILL_BLUR_PNG_DIR'];
    if (out != null) {
      final w = (240 * 3).round();
      final h = a.length ~/ 4 ~/ w;
      Directory(out).createSync(recursive: true);
      for (final (name, bytes) in [('live', a), ('still', b), ('diff_x8', diff)]) {
        File('$out/still_blur_$name.png').writeAsBytesSync(img.encodePng(
          img.Image.fromBytes(
            width: w,
            height: h,
            bytes: bytes.buffer,
            numChannels: 4,
          ),
        ));
      }
      // ignore: avoid_print
      print('still blur vs live: mean $mean, worst $worst (of 255)');
    }
    // Indistinguishable: well under one shade on average, and no pixel off
    // by more than a few.
    expect(mean, lessThan(1.5));
    expect(worst, lessThan(12));
  });

  testWidgets('blurs once, not every frame something moves over it', (
    tester,
  ) async {
    final ticker = ValueNotifier<int>(0);
    await tester.pumpWidget(host(Stack(
      children: [
        StillBlur(sigma: 20, child: picture(Colors.orange)),
        // Dust over it, repainting every frame.
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(painter: _Ticking(ticker)),
          ),
        ),
      ],
    )));
    final blur = tester.renderObject<RenderStillBlur>(find.byType(StillBlur));
    final first = blur.debugStill;
    expect(first, isNotNull);
    for (var i = 0; i < 5; i++) {
      ticker.value++;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(identical(blur.debugStill, first), isTrue);
  });

  testWidgets('a picture that changes under it is blurred anew', (
    tester,
  ) async {
    await tester.pumpWidget(host(StillBlur(
      sigma: 20,
      child: picture(Colors.orange),
    )));
    final blur = tester.renderObject<RenderStillBlur>(find.byType(StillBlur));
    final first = blur.debugStill;
    // A late decode: the same widget, new pixels.
    await tester.pumpWidget(host(StillBlur(
      sigma: 20,
      child: picture(Colors.teal),
    )));
    expect(identical(blur.debugStill, first), isFalse);
    // Turned off, it lets go of the still and is the picture again.
    await tester.pumpWidget(host(StillBlur(
      sigma: 20,
      enabled: false,
      child: picture(Colors.teal),
    )));
    expect(blur.debugStill, isNull);
  });
}

class _Picture extends CustomPainter {
  const _Picture(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF20304A));
    const n = 12.0;
    for (var y = 0.0; y < size.height; y += n) {
      for (var x = 0.0; x < size.width; x += n) {
        if (((x + y) / n).round().isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, n, n), Paint()..color = accent);
        }
      }
    }
    canvas.drawCircle(
      Offset(size.width * 0.7, size.height * 0.4),
      40,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_Picture old) => old.accent != accent;
}

class _Ticking extends CustomPainter {
  _Ticking(this.tick) : super(repaint: tick);

  final ValueNotifier<int> tick;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(10.0 + tick.value, 10),
      2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_Ticking old) => false;
}
