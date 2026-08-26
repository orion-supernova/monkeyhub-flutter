import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// An encoded image held in memory, carried together with the content type it
/// was actually encoded as.
///
/// The upload path used to hardcode `contentType: 'image/jpeg'` at every call
/// site, which was true only by accident (image_picker's `imageQuality` forces
/// a JPEG re-encode). Convex serves the blob back with whatever type it was
/// stored under, so a wrong one makes the browser mis-sniff it. Pairing the
/// bytes with their type makes that class of mistake unrepresentable.
///
/// Bytes rather than a `dart:io` File: on web a picked image is a `blob:` URL
/// with no filesystem behind it, and every `File` call throws `UnsupportedError`
/// there. Nothing was gained by the detour through disk anyway — the decoder
/// read the whole file back into memory as its first act, and the uploader read
/// it a second time.
class CroppedImage {
  const CroppedImage({
    required this.bytes,
    required this.contentType,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final String contentType;
  final int width;
  final int height;
}

/// What to pass as `ImagePicker`'s `imageQuality`.
///
/// On mobile this is 88, and stays there for a reason unrelated to file size:
/// it forces a re-encode that normalizes EXIF orientation, which
/// `ImageCropScreen` and the chat editor both rely on — neither reads the
/// orientation tag itself.
///
/// On web it is null. `image_picker_for_web` implements `imageQuality` by
/// loading the blob into a canvas and re-encoding it, so the picture would be
/// generation-lossed twice: once there, then again by our own q90 export. There
/// is no EXIF benefit to buy with that, because the canvas round-trip drops the
/// metadata anyway.
const int? pickerImageQuality = kIsWeb ? null : 88;

// ------------------------------------------------------- outgoing photo size
//
// What a chat photo costs on the wire, and why it is capped by default.
//
// The editor used to export every photo at the source resolution and q90 —
// deliberately, so "the file the user sends is the one they gave us". On a
// 12 megapixel phone camera that is ~5 MB, and the arithmetic that makes it
// the wrong default is the fan-out: one photo into a four-person room is one
// 5 MB upload and *four* 5 MB downloads, because the recipients fetch the blob
// independently and there is no CDN in front of Convex storage. A single
// afternoon of chatting measured 10.8 MB uploaded against 51.2 MB served.
//
// So the default is a capped re-encode and HD is the opt-in, which is the
// trade every mainstream messenger makes: the cap is invisible on a phone
// screen, and the latency it buys back is not. [kSendPhotoMaxEdge] on the
// longest side keeps portrait photos portrait — it is a bound on the longer
// dimension, never a forced aspect.

/// Longest edge, in pixels, of a chat photo sent at the default setting.
///
/// 1280 covers every phone screen at better than 1:1 (a 6.7" flagship is
/// ~1290 logical points wide only in landscape) and lands a typical camera
/// photo around 150 KB. Above this the extra pixels are only ever seen by
/// someone pinch-zooming, which is what HD is for.
const int kSendPhotoMaxEdge = 1280;

/// JPEG quality for a chat photo sent at the default setting.
const int kSendPhotoQuality = 75;

/// JPEG quality for a photo sent as HD.
///
/// Matches what the editor has always exported, so turning HD on reproduces
/// the old behaviour exactly: source resolution, q90, no cap.
const int kSendPhotoHdQuality = 90;

/// Re-encodes [source] as a JPEG bounded by [maxEdge] on its longest side.
///
/// Used for a photo going out UNEDITED — the editor's pass-through path, which
/// otherwise hands back the picked bytes verbatim. An edited photo is capped
/// during its own composite instead, where the crop and strokes are already
/// being rasterized and a second decode would be waste.
///
/// Never upscales: [decodeImageBytes] declines to enlarge a small source, so a
/// 600px image comes back at 600px, re-encoded but not stretched.
///
/// The opaque backdrop is not optional. [rasterToJpegBytes] reads PREMULTIPLIED
/// rawRgba, which only equals straight RGBA where alpha is 255 — a PNG or WebP
/// with real transparency would come back with its semi-transparent pixels
/// darkened. JPEG has no alpha to preserve anyway, so flattening onto black is
/// both correct and lossless here.
Future<CroppedImage> compressForSend(
  Uint8List source, {
  int maxEdge = kSendPhotoMaxEdge,
  int quality = kSendPhotoQuality,
}) async {
  final decoded = await decodeImageBytes(source, maxEdge: maxEdge);
  final w = decoded.width;
  final h = decoded.height;
  final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, rect);
  canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xFF000000));
  canvas.drawImage(
    decoded,
    ui.Offset.zero,
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final raster = await picture.toImage(w, h);
  picture.dispose();
  decoded.dispose();

  // Takes ownership of `raster` and disposes it.
  return rasterToJpegBytes(raster, quality: quality);
}

/// The content type of [bytes], read from the header rather than a filename.
///
/// This used to sniff the file extension, which does not exist on web — a
/// picked image is a `blob:` URL with no `.jpg` on the end. Magic bytes are
/// also simply more honest: a mislabelled `.jpg` that is really a PNG would
/// have been uploaded as `image/jpeg` and mis-sniffed on the way back out.
String sniffImageContentType(Uint8List bytes) {
  bool match(int offset, List<int> magic) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (match(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (match(0, [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (match(0, [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  // RIFF....WEBP — the four bytes between are the chunk length.
  if (match(0, [0x52, 0x49, 0x46, 0x46]) &&
      match(8, [0x57, 0x45, 0x42, 0x50])) {
    return 'image/webp';
  }
  // ISO-BMFF: `ftyp` at offset 4, brand immediately after.
  if (match(4, [0x66, 0x74, 0x79, 0x70])) {
    for (final brand in const [
      [0x68, 0x65, 0x69, 0x63], // heic
      [0x68, 0x65, 0x69, 0x78], // heix
      [0x68, 0x65, 0x76, 0x63], // hevc
      [0x6D, 0x69, 0x66, 0x31], // mif1
    ]) {
      if (match(8, brand)) return 'image/heic';
    }
  }
  return 'image/jpeg';
}

/// Decodes [bytes], optionally capping the longest edge at [maxEdge].
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
///
/// The cap is applied through `instantiateImageCodecWithSize` rather than by
/// reading `ImageDescriptor.width` ourselves, because on web that getter throws
/// `UnsupportedError` outright — `ImageDescriptor.encoded` there is a bare
/// wrapper around the bytes that never parses a header, so every field is null
/// and every accessor throws (flutter_web_sdk/lib/ui/painting.dart). Asking for
/// the width was the first thing this function did, so on web it failed for
/// *every* image, not just an exotic one, and the editor blamed the photo.
///
/// The callback form is the API that hides the difference: on mobile it is
/// handed the header dimensions, and on web the engine decodes once to learn
/// them and re-decodes at the size we ask for. The second decode is the price
/// of a browser having no header API at all — there is nothing cheaper to buy.
Future<ui.Image> decodeImageBytes(Uint8List bytes, {int? maxEdge}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  // Takes ownership of the buffer and disposes it.
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: maxEdge == null
        ? null
        : (intrinsicWidth, intrinsicHeight) {
            final longest = math.max(intrinsicWidth, intrinsicHeight);
            if (longest <= maxEdge) return const ui.TargetImageSize();
            final k = maxEdge / longest;
            return ui.TargetImageSize(
              width: math.max(1, (intrinsicWidth * k).round()),
              height: math.max(1, (intrinsicHeight * k).round()),
            );
          },
  );
  try {
    final frame = await codec.getNextFrame();
    return frame.image;
  } finally {
    codec.dispose();
  }
}

/// The intrinsic pixel size of [bytes], without decoding them where possible.
///
/// Used to report the true dimensions of an image that is being passed through
/// untouched, where no decode of it exists to ask.
///
/// Two header readers, because neither one covers both platforms:
///
///  * Off web, `ImageDescriptor.encoded` reads the real header and understands
///    every format the platform decoder does, HEIC included, for the cost of
///    the read.
///  * On web that same call parses nothing and its getters throw, so the header
///    is parsed in pure Dart instead. This covers JPEG, PNG, GIF and WebP —
///    which is everything `sniffImageContentType` can name and a browser can
///    open.
///
/// A format neither reader knows falls back to a full decode, which is slow but
/// always right, and is the only honest answer for something like AVIF that the
/// browser can open and `package:image` cannot parse.
Future<ui.Size> imageBytesSize(Uint8List bytes) async {
  if (!kIsWeb) {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      return ui.Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  // Guarded, not just null-checked: a truncated or malformed file makes these
  // parsers throw as readily as it makes them decline, and both mean the same
  // thing here — this reader does not know what it is looking at.
  img.DecodeInfo? info;
  try {
    info = img.findDecoderForData(bytes)?.startDecode(bytes);
  } catch (_) {
    info = null;
  }
  if (info != null) {
    return ui.Size(info.width.toDouble(), info.height.toDouble());
  }

  final image = await decodeImageBytes(bytes);
  try {
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  } finally {
    image.dispose();
  }
}

/// Reflects [src] about its vertical centre line. Does not dispose [src].
///
/// Every camera mirrors its own front-lens *preview* — you see yourself the way
/// a mirror shows you — but records the frame the way the lens saw it, reversed
/// from what you were just looking at. Neither iOS, Android nor the web plugin
/// mirrors the capture, and none of them offers a switch, so a front-lens
/// photograph has to be flipped somewhere before the user sees it again.
///
/// That "somewhere" is deliberately **not** at capture time. Flipping the
/// encoded bytes means a full-resolution decode, rasterize, read-back and
/// re-encode standing between the shutter and the next screen, which is exactly
/// where a camera must not pause. Both screens downstream — the avatar cropper
/// and the chat editor — already decode the photo to a [ui.Image] and already
/// rasterize once on the way out. So they take a `mirrored` flag instead and
/// call this on the image they were going to decode anyway; the flip rides
/// along with work that was happening regardless, and the shutter returns
/// immediately.
///
/// Pure reflection at 1:1, so no resampling and nothing softens.
Future<ui.Image> flipImageHorizontally(ui.Image src) async {
  final w = src.width;
  final h = src.height;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
  );
  mirrorCanvasHorizontally(canvas, w.toDouble());
  canvas.drawImage(
    src,
    ui.Offset.zero,
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final flipped = await picture.toImage(w, h);
  picture.dispose();
  return flipped;
}

/// Reflects everything drawn afterwards about the vertical centre line of a
/// [width]-wide box: shift right by the full width, then negate x.
///
/// Shared so the on-screen flip and the one replayed at export cannot drift
/// apart — the same reason the editor's stroke painter is a single function
/// used by both its preview and its exporter.
void mirrorCanvasHorizontally(ui.Canvas canvas, double width) {
  canvas.translate(width, 0);
  canvas.scale(-1, 1);
}

/// Encodes a freshly rasterized [ui.Image] to JPEG bytes.
///
/// Takes ownership of [raster] and disposes it.
///
/// `dart:ui` can only encode PNG, and PNG is the wrong format for a photo: a
/// 1024² photographic PNG runs 1.6–2.6 MB against 150–260 KB for JPEG q90.
/// So we pull raw pixels out of the GPU image and hand them to the pure-Dart
/// `image` encoder instead.
Future<CroppedImage> rasterToJpegBytes(
  ui.Image raster, {
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
    throw StateError('rasterToJpegBytes: toByteData returned null');
  }
  final rgba = byteData.buffer.asUint8List();

  final jpeg = await compute(
    _encodeJpegJob,
    _JpegJob(rgba: rgba, width: width, height: height, quality: quality),
  );

  return CroppedImage(
    bytes: jpeg,
    contentType: 'image/jpeg',
    width: width,
    height: height,
  );
}

/// Everything [_encodeJpegJob] needs, in one sendable message.
class _JpegJob {
  const _JpegJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.quality,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final int quality;
}

/// Runs the encode off the UI isolate — `encodeJpg` is pure Dart and costs
/// 200–400 ms at 1024², which is several dropped frames if done inline.
///
/// `compute` rather than `Isolate.run`: the latter throws outright on web,
/// where there are no isolates to spawn. `compute` keeps the isolate on
/// mobile and desktop and falls back to running inline in the browser, which
/// is the only thing available there.
///
/// Top-level and taking a single plain-data message, as `compute` requires —
/// nothing here may capture `this` or a BuildContext, since the whole argument
/// has to be shipped across.
Uint8List _encodeJpegJob(_JpegJob job) {
  final decoded = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: job.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(decoded, quality: job.quality);
}

/// The [CroppedImage] to send for a photo nobody edited.
///
/// This is the outgoing-size POLICY, in one place, because it is a policy and
/// not a calculation: a photo goes out at the size the sender gave us when they
/// asked for [hd] or when it was already inside [kSendPhotoMaxEdge], and gets
/// capped otherwise. It used to live inline in the chat editor's pass-through,
/// which was the only path that had one — the bulk photo tray would have needed
/// a second copy of the same three rules, and two copies of a policy is one
/// copy that eventually drifts.
///
/// Returns null when the source's header cannot be read or the re-encode fails.
/// Null rather than a throw because the two callers want opposite things from
/// it: the editor falls through to its full export path, which decodes for real
/// and applies the same cap on the way out, while the tray has nothing behind
/// it and drops that one photo.
///
/// [onCompressing] fires only on the branch that does real work — a 12
/// megapixel decode and JPEG re-encode is a second or two on an older handset,
/// and it is the caller who owns the spinner that has to cover it. The
/// pass-through branches never call it, which is the point: raising a spinner
/// for work that isn't happening is its own kind of lie.
Future<CroppedImage?> prepareUneditedForSend(
  Uint8List source, {
  required bool hd,
  VoidCallback? onCompressing,
}) async {
  try {
    // The header, not a decode: this runs before we know whether anything is
    // going to be re-encoded, and decoding a photo only to find out it was
    // already small enough would cost the whole saving.
    final size = await imageBytesSize(source);
    if (hd || math.max(size.width, size.height) <= kSendPhotoMaxEdge) {
      return CroppedImage(
        bytes: source,
        contentType: sniffImageContentType(source),
        width: size.width.round(),
        height: size.height.round(),
      );
    }
    onCompressing?.call();
    return await compressForSend(source);
  } catch (e) {
    debugPrint('[image_raster] prepareUneditedForSend failed: $e');
    return null;
  }
}
