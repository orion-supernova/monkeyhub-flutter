import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/media/image_raster.dart';

/// The selfie mirror.
///
/// Front-lens captures come back the way the sensor saw them, reversed from the
/// preview the user framed the shot in — no platform mirrors the capture and
/// none offers a switch. `flipImageHorizontally` is the correction, and both
/// the avatar cropper and the chat editor apply it to their decode.
///
/// Worth a test because the failure is silent and symmetric: a flip applied
/// twice, or in the wrong axis, still produces a perfectly valid photograph.
/// That is exactly how the first version of this shipped a preview that was
/// flipped back to front — the app cancelled a flip the platform had already
/// applied, and nothing anywhere reported an error.
///
/// Everything real happens inside `tester.runAsync`. `Picture.toImage()` is
/// genuine raster work that never resolves under the fake-async binding, so a
/// plain `test()` here would hang the whole suite rather than fail.
void main() {
  /// A [width]×1 strip whose pixels run left to right through [colours].
  Uint8List strip(List<int> colours) {
    final bitmap = img.Image(width: colours.length, height: 1);
    for (var x = 0; x < colours.length; x++) {
      final c = colours[x];
      bitmap.setPixelRgba(
        x,
        0,
        (c >> 16) & 0xFF,
        (c >> 8) & 0xFF,
        c & 0xFF,
        0xFF,
      );
    }
    return Uint8List.fromList(img.encodePng(bitmap));
  }

  /// Reads [image] back as a row of 0xRRGGBB values.
  Future<List<int>> row(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final px = data!.buffer.asUint8List();
    return [
      for (var i = 0; i < px.length; i += 4)
        (px[i] << 16) | (px[i + 1] << 8) | px[i + 2],
    ];
  }

  const red = 0xFF0000;
  const green = 0x00FF00;
  const blue = 0x0000FF;

  testWidgets('a flip reverses the image along x', (tester) async {
    await tester.runAsync(() async {
      final src = await decodeImageBytes(strip([red, green, blue]));
      addTearDown(src.dispose);

      final flipped = await flipImageHorizontally(src);
      addTearDown(flipped.dispose);

      expect(await row(src), [red, green, blue]);
      expect(await row(flipped), [blue, green, red]);
      // A mirror is not a resize.
      expect(flipped.width, src.width);
      expect(flipped.height, src.height);
    });
  });

  testWidgets('flipping twice is the identity', (tester) async {
    await tester.runAsync(() async {
      // The failure this guards is the one that actually shipped: two flips
      // cancelling out, leaving a selfie that looks plausible and is backwards.
      final src = await decodeImageBytes(strip([red, green, blue]));
      addTearDown(src.dispose);

      final once = await flipImageHorizontally(src);
      addTearDown(once.dispose);
      final twice = await flipImageHorizontally(once);
      addTearDown(twice.dispose);

      expect(await row(twice), await row(src));
    });
  });

  testWidgets('the source image survives the flip', (tester) async {
    await tester.runAsync(() async {
      // Both callers dispose the original themselves right after flipping, so
      // this must not take ownership of it.
      final src = await decodeImageBytes(strip([red, blue]));
      final flipped = await flipImageHorizontally(src);
      addTearDown(flipped.dispose);

      expect(await row(src), [red, blue]);
      src.dispose();
    });
  });
}
