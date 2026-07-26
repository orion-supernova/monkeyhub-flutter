import 'dart:math' as math;
import 'dart:typed_data';

/// Below this mean luminance, a selfie taken without extra light comes out
/// muddy and noisy. Roughly a dim indoor room after sunset.
///
/// A threshold rather than a curve because it drives one binary decision — does
/// the screen flash fire on auto — and a hysteresis band ([darkExitLuminance])
/// keeps that decision from flickering when the reading sits on the line.
const double darkEnterLuminance = 0.22;

/// The reading has to climb back above *this* before "dark" is released. The
/// gap is deliberate: without it, a preview metering at exactly the threshold
/// toggles the flash icon several times a second.
const double darkExitLuminance = 0.30;

/// Mean brightness of a camera preview frame, on 0..1.
///
/// The only light meter available to us. `CameraController` exposes exposure
/// offsets but nothing that reads the scene, and neither iOS nor Android hands
/// Flutter a lux value — so auto-flash on a selfie camera, which has no
/// hardware flash to let the platform decide for us, has to meter the frames
/// itself.
///
/// Samples a [grid]×[grid] lattice rather than walking the buffer. A 1080p
/// frame is two million pixels arriving many times a second; 1024 of them
/// spread evenly across the frame answer "is this room dark" just as well, at a
/// cost that does not scale with resolution.
///
/// [bytesPerPixel] is 1 for a luma plane — plane 0 of yuv420 is Y, which is
/// luminance already — and 4 for a packed BGRA frame, which iOS delivers by
/// default and which is weighted here into real luminance rather than averaged
/// flat. Rows are addressed through [bytesPerRow], not `width * bytesPerPixel`:
/// capture buffers are commonly padded to an alignment boundary, and reading
/// straight through would fold that padding into the average and report every
/// scene darker than it is.
///
/// Returns 0 for a frame that is empty or does not describe itself coherently,
/// which reads as "dark" — the safe way to be wrong, since the cost is a flash
/// that was not needed rather than a photograph nobody can see.
double meanPreviewLuminance({
  required Uint8List bytes,
  required int width,
  required int height,
  required int bytesPerRow,
  required int bytesPerPixel,
  int grid = 32,
}) {
  if (width <= 0 || height <= 0 || bytes.isEmpty || grid <= 0) return 0;
  if (bytesPerPixel != 1 && bytesPerPixel != 4) return 0;
  if (bytesPerRow < width * bytesPerPixel) return 0;

  final stepX = math.max(1, width ~/ grid);
  final stepY = math.max(1, height ~/ grid);

  var total = 0.0;
  var count = 0;

  for (var y = 0; y < height; y += stepY) {
    final rowStart = y * bytesPerRow;
    for (var x = 0; x < width; x += stepX) {
      final i = rowStart + x * bytesPerPixel;
      if (i + bytesPerPixel > bytes.length) break;
      if (bytesPerPixel == 1) {
        total += bytes[i];
      } else {
        // 32BGRA, so blue first and alpha last. Rec. 601 weights: a flat mean
        // would call a saturated blue frame as bright as a green one, which is
        // not how an eye or a sensor sees it.
        total += 0.114 * bytes[i] + 0.587 * bytes[i + 1] + 0.299 * bytes[i + 2];
      }
      count++;
    }
  }

  if (count == 0) return 0;
  return (total / count / 255).clamp(0.0, 1.0);
}
