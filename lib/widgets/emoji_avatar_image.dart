import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Paints an emoji on a soft gradient tile and returns it as PNG bytes, so an
/// emoji chosen in the new room sheet can become the room's real picture.
///
/// Rooms have no emoji field, only a picture (`avatarStorageId`), and adding a
/// second kind of avatar would mean every place that draws a room learning
/// about it. Turning the emoji into the same kind of picture a member could
/// upload means nothing downstream changes: the chat list, the header, pushes
/// and every platform already know how to show it. It also never touches the
/// room's NAME, which an earlier version prefixed with the emoji.
///
/// The tile is drawn square; every place a room picture appears clips it to
/// its own shape. [gradient] comes from the theme's avatar palette, the same
/// colours a room without a picture would get.
Future<Uint8List> renderEmojiAvatar(
  String emoji,
  List<Color> gradient, {
  int size = 512,
}) async {
  final s = size.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, s, s));
  final colors = gradient.length >= 2
      ? gradient
      : [gradient.isEmpty ? const Color(0xFF888888) : gradient.first,
         gradient.isEmpty ? const Color(0xFF888888) : gradient.first];
  canvas.drawRect(
    Rect.fromLTWH(0, 0, s, s),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, s, s)),
  );
  final tp = TextPainter(
    text: TextSpan(text: emoji, style: TextStyle(fontSize: s * 0.56, height: 1)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset((s - tp.width) / 2, (s - tp.height) / 2));
  final image = await recorder.endRecording().toImage(size, size);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
