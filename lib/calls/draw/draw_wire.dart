import 'dart:typed_data';

/// The wire format for strokes drawn over a shared screen.
///
/// This rides an `RTCDataChannel`, not Convex: a stroke is a few hundred
/// points a second while the finger is down and worthless three seconds
/// later, which is the opposite of what a database row is for. The channel
/// is ordered and reliable, so the format spends nothing on sequencing and
/// everything on being small — a point is two floats, an op is a byte, and a
/// frame is whatever one animation frame produced.
///
/// A frame: `[u8 version][u8 opCount]` then `opCount` ops. Every stroke id
/// is minted by the sender and only unique per sender; the receiver knows
/// who the channel belongs to and keys strokes on the pair.
///
/// Coordinates are fractions of the shared frame, 0..1 in both axes, so a
/// stroke lands on the same pixel of the presenter's screen whatever the
/// viewer's window looks like. A stroke's width is a fraction of the frame
/// width for the same reason.

/// The wire version this encoder speaks and this decoder accepts.
const int kDrawWireVersion = 1;

/// Point count per op is a u16.
const int kDrawMaxPointsPerOp = 0xFFFF;

/// Ops per frame is a u8. A longer batch is simply several frames back to
/// back — the decoder reads frames until the bytes run out.
const int kDrawMaxOpsPerFrame = 0xFF;

/// One thing that happened to the drawing.
sealed class DrawOp {
  const DrawOp();
}

/// A new stroke, with its colour, its width and its first point(s).
final class StrokeBegin extends DrawOp {
  const StrokeBegin({
    required this.strokeId,
    required this.argb,
    required this.width,
    required this.points,
  });

  final int strokeId;

  /// The stroke's colour, packed ARGB.
  final int argb;

  /// Width as a fraction of the frame width.
  final double width;

  /// x/y pairs, 0..1.
  final Float32List points;
}

/// More points for a stroke already begun.
final class StrokeAppend extends DrawOp {
  const StrokeAppend({required this.strokeId, required this.points});

  final int strokeId;
  final Float32List points;
}

/// The finger lifted; the stroke's clock starts.
final class StrokeEnd extends DrawOp {
  const StrokeEnd({required this.strokeId});

  final int strokeId;
}

/// Everything goes — sent by the presenter when the share stops.
final class DrawClear extends DrawOp {
  const DrawClear();
}

const int _opBegin = 0x01;
const int _opAppend = 0x02;
const int _opEnd = 0x03;
const int _opClear = 0x04;

/// Splits any op carrying more points than one op can say into a run of ops
/// that can.
List<DrawOp> _normalize(List<DrawOp> ops) {
  var needs = false;
  for (final op in ops) {
    final n = switch (op) {
      StrokeBegin(:final points) => points.length ~/ 2,
      StrokeAppend(:final points) => points.length ~/ 2,
      _ => 0,
    };
    if (n > kDrawMaxPointsPerOp) {
      needs = true;
      break;
    }
  }
  if (!needs) return ops;
  final out = <DrawOp>[];
  for (final op in ops) {
    switch (op) {
      case StrokeBegin(:final strokeId, :final argb, :final width, :final points):
        final n = points.length ~/ 2;
        if (n <= kDrawMaxPointsPerOp) {
          out.add(op);
          break;
        }
        out.add(StrokeBegin(
          strokeId: strokeId,
          argb: argb,
          width: width,
          points: Float32List.sublistView(points, 0, kDrawMaxPointsPerOp * 2),
        ));
        _appendChunks(out, strokeId, points, kDrawMaxPointsPerOp);
      case StrokeAppend(:final strokeId, :final points):
        final n = points.length ~/ 2;
        if (n <= kDrawMaxPointsPerOp) {
          out.add(op);
          break;
        }
        _appendChunks(out, strokeId, points, 0);
      default:
        out.add(op);
    }
  }
  return out;
}

void _appendChunks(
    List<DrawOp> out, int strokeId, Float32List points, int fromPoint) {
  final n = points.length ~/ 2;
  var p = fromPoint;
  while (p < n) {
    final take = (n - p).clamp(0, kDrawMaxPointsPerOp);
    out.add(StrokeAppend(
      strokeId: strokeId,
      points: Float32List.sublistView(points, p * 2, (p + take) * 2),
    ));
    p += take;
  }
}

int _sizeOf(DrawOp op) => switch (op) {
      StrokeBegin(:final points) => 1 + 4 + 4 + 4 + 2 + 4 * points.length,
      StrokeAppend(:final points) => 1 + 4 + 2 + 4 * points.length,
      StrokeEnd() => 1 + 4,
      DrawClear() => 1,
    };

/// Encodes [ops] as one or more back-to-back frames.
Uint8List encodeDrawBatch(List<DrawOp> ops) {
  final flat = _normalize(ops);
  var total = 0;
  for (final op in flat) {
    total += _sizeOf(op);
  }
  final frames = flat.isEmpty ? 1 : (flat.length + kDrawMaxOpsPerFrame - 1) ~/ kDrawMaxOpsPerFrame;
  total += frames * 2;
  final bytes = Uint8List(total);
  final view = ByteData.view(bytes.buffer);
  var o = 0;
  var i = 0;
  do {
    final count = (flat.length - i).clamp(0, kDrawMaxOpsPerFrame);
    bytes[o++] = kDrawWireVersion;
    bytes[o++] = count;
    for (final end = i + count; i < end; i++) {
      final op = flat[i];
      switch (op) {
        case StrokeBegin(:final strokeId, :final argb, :final width, :final points):
          bytes[o++] = _opBegin;
          view.setUint32(o, strokeId, Endian.little);
          o += 4;
          view.setUint32(o, argb & 0xFFFFFFFF, Endian.little);
          o += 4;
          view.setFloat32(o, width, Endian.little);
          o += 4;
          o = _putPoints(view, o, points);
        case StrokeAppend(:final strokeId, :final points):
          bytes[o++] = _opAppend;
          view.setUint32(o, strokeId, Endian.little);
          o += 4;
          o = _putPoints(view, o, points);
        case StrokeEnd(:final strokeId):
          bytes[o++] = _opEnd;
          view.setUint32(o, strokeId, Endian.little);
          o += 4;
        case DrawClear():
          bytes[o++] = _opClear;
      }
    }
  } while (i < flat.length);
  return bytes;
}

int _putPoints(ByteData view, int o, Float32List points) {
  final n = points.length ~/ 2;
  view.setUint16(o, n, Endian.little);
  o += 2;
  for (var k = 0; k < n * 2; k++) {
    view.setFloat32(o, points[k], Endian.little);
    o += 4;
  }
  return o;
}

/// Decodes every op in [bytes], frame after frame. Never throws: whatever
/// was parsed before the first truncated or unknown op is what comes back,
/// because a peer on a newer build must not be able to knock this one off
/// the channel with one odd byte.
List<DrawOp> decodeDrawBatch(Uint8List bytes) {
  final out = <DrawOp>[];
  final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
  final len = bytes.length;
  var o = 0;
  while (o + 2 <= len) {
    if (bytes[o] != kDrawWireVersion) return out;
    final count = bytes[o + 1];
    o += 2;
    for (var i = 0; i < count; i++) {
      if (o >= len) return out;
      final tag = bytes[o++];
      switch (tag) {
        case _opBegin:
          if (o + 14 > len) return out;
          final id = view.getUint32(o, Endian.little);
          final argb = view.getUint32(o + 4, Endian.little);
          final width = view.getFloat32(o + 8, Endian.little);
          final n = view.getUint16(o + 12, Endian.little);
          o += 14;
          final pts = _getPoints(view, o, n, len);
          if (pts == null) return out;
          o += n * 8;
          out.add(StrokeBegin(
              strokeId: id, argb: argb, width: width, points: pts));
        case _opAppend:
          if (o + 6 > len) return out;
          final id = view.getUint32(o, Endian.little);
          final n = view.getUint16(o + 4, Endian.little);
          o += 6;
          final pts = _getPoints(view, o, n, len);
          if (pts == null) return out;
          o += n * 8;
          out.add(StrokeAppend(strokeId: id, points: pts));
        case _opEnd:
          if (o + 4 > len) return out;
          out.add(StrokeEnd(strokeId: view.getUint32(o, Endian.little)));
          o += 4;
        case _opClear:
          out.add(const DrawClear());
        default:
          return out;
      }
    }
  }
  return out;
}

Float32List? _getPoints(ByteData view, int o, int n, int len) {
  if (o + n * 8 > len) return null;
  final pts = Float32List(n * 2);
  for (var k = 0; k < n * 2; k++) {
    pts[k] = view.getFloat32(o + k * 4, Endian.little);
  }
  return pts;
}
