import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// A rasterized image on disk, carried together with the content type it was
/// actually encoded as.
///
/// The upload path used to hardcode `contentType: 'image/jpeg'` at every call
/// site, which was true only by accident (image_picker's `imageQuality` forces
/// a JPEG re-encode). Convex serves the blob back with whatever type it was
/// stored under, so a wrong one makes the browser mis-sniff it. Pairing the
/// file with its type makes that class of mistake unrepresentable.
class CroppedImage {
  const CroppedImage({
    required this.file,
    required this.contentType,
    required this.width,
    required this.height,
  });

  final File file;
  final String contentType;
  final int width;
  final int height;
}

/// Decodes [file], optionally capping its longest edge at [maxEdge].
///
/// Two callers, two very different needs, one decoder:
///
///  * **Display** passes a cap. A 4032×3024 photo is ~48 MB of RGBA at full
///    size and makes drawing stutter; 2048 is still well past any phone screen,
///    so the cap is invisible and the interaction is smooth.
///  * **Export** passes null. The file the user sends must be the resolution
///    they gave us — a tall photo stays tall — so the composite is built from
///    the real pixels, once, at save time.
///
/// Never upscales: a small source is decoded as-is.
Future<ui.Image> decodeImageFile(File file, {int? maxEdge}) async {
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  try {
    final longest = math.max(descriptor.width, descriptor.height);
    final k =
        (maxEdge != null && longest > maxEdge) ? maxEdge / longest : 1.0;
    final codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * k).round(),
      targetHeight: (descriptor.height * k).round(),
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  } finally {
    descriptor.dispose();
  }
}

/// The intrinsic pixel size of [file], without decoding it.
///
/// `ImageDescriptor.encoded` reads the header only, so this costs a file read
/// rather than the tens of megabytes a full decode would allocate. Used to
/// report the true dimensions of an image that is being passed through
/// untouched, where no decode of it exists to ask.
Future<ui.Size> imageFileSize(File file) async {
  final bytes = await file.readAsBytes();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  try {
    return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  } finally {
    descriptor.dispose();
  }
}

/// Encodes a freshly rasterized [ui.Image] to a JPEG in the temp directory.
///
/// Takes ownership of [raster] and disposes it.
///
/// `dart:ui` can only encode PNG, and PNG is the wrong format for a photo: a
/// 1024² photographic PNG runs 1.6–2.6 MB against 150–260 KB for JPEG q90.
/// So we pull raw pixels out of the GPU image and hand them to the pure-Dart
/// `image` encoder instead.
Future<CroppedImage> rasterToJpegFile(
  ui.Image raster, {
  String prefix = 'crop',
  int quality = 90,
}) async {
  final width = raster.width;
  final height = raster.height;
  // rawRgba is PREMULTIPLIED. Callers must paint an opaque backdrop before
  // drawing, so every alpha is 255 and premultiplied == straight; otherwise
  // semi-transparent pixels come back darkened.
  final byteData = await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
  raster.dispose();
  if (byteData == null) {
    throw StateError('rasterToJpegFile: toByteData returned null');
  }
  final rgba = byteData.buffer.asUint8List();

  final jpeg = await _encodeJpeg(rgba, width, height, quality);

  final tmp = await getTemporaryDirectory();
  final path =
      '${tmp.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final file = await File(path).writeAsBytes(jpeg, flush: true);
  return CroppedImage(
    file: file,
    contentType: 'image/jpeg',
    width: width,
    height: height,
  );
}

/// Runs the encode off the UI isolate — `encodeJpg` is pure Dart and costs
/// 200–400 ms at 1024², which is several dropped frames if done inline.
///
/// The closure deliberately captures only sendable locals (never `this`, never
/// a BuildContext), since `Isolate.run` has to ship them across.
Future<Uint8List> _encodeJpeg(
  Uint8List rgba,
  int width,
  int height,
  int quality,
) {
  return Isolate.run(() {
    final decoded = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodeJpg(decoded, quality: quality);
  });
}
