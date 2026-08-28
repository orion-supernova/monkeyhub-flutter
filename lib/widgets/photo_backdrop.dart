import 'dart:ui';

import 'package:flutter/widgets.dart';

/// Fills the screen behind a `contain`-fitted photograph with a blurred,
/// darkened copy of the picture itself.
///
/// **Why every fullscreen viewer in this app needs one.** A photograph is
/// almost never the shape of the phone. Fitted with `contain` — which is the
/// only honest fit, since `cover` crops somebody's picture without asking — a
/// 4:3 shot on a 19.5:9 screen leaves a third of the display as dead black, and
/// that dead black is exactly where the chrome sits: the close button, the
/// author's name, the caption. The result reads as a picture sitting in a
/// letterbox with a toolbar above it, not as a fullscreen photo — which was the
/// complaint, in those words, about the Feed's viewer and the view-once one.
///
/// Filling that space with the picture's own colours, blurred past recognition
/// and dimmed, is what closes the gap. The chrome then floats over *the
/// photograph* at every aspect ratio, the edges of the frame stop being a hard
/// rectangle, and nothing is cropped.
///
/// **[ImageFiltered], not [BackdropFilter].** This blurs its own child rather
/// than everything painted beneath it, so it costs one filtered layer instead
/// of a full-screen readback per frame — and callers hand it a *small* decode
/// (a thumbnail is ideal: it is already resident, and it is about to be blurred
/// into mush anyway), which makes the whole thing nearly free.
///
/// Mount it as the first child of the viewer's `Stack`, under the picture —
/// inside a `Positioned.fill` unless the stack is already `StackFit.expand`.
class PhotoBackdrop extends StatelessWidget {
  const PhotoBackdrop({
    super.key,
    required this.image,
    this.sigma = 34,
    this.dim = 0.34,
  });

  /// The same picture, which the caller should render at [BoxFit.cover] and
  /// at the smallest decode it has handy.
  final Widget image;

  /// Blur radius. High on purpose: this must never read as a second copy of
  /// the photograph competing with the real one, only as its colour.
  final double sigma;

  /// How far the blurred copy is pushed back behind the real one, 0..1.
  ///
  /// **Deliberately light.** The first version of this dimmed by 0.62 and, with
  /// a scrim gradient on top of it, the result was still a black band with
  /// buttons on it — which is the complaint it was written to answer, unfixed.
  /// The backdrop only works if it visibly reads as the photograph's own colour
  /// continuing past the frame. Legibility over it is the chrome's job: glass
  /// buttons and text shadows, not a curtain.
  final double dim;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Under everything: a picture with transparency, or one still
          // decoding, must not show whatever route is behind this one.
          const ColoredBox(color: Color(0xFF000000)),
          ClipRect(
            child: ImageFiltered(
              // `decal` rather than the default `clamp`: clamping smears the
              // edge pixels outward in bands, which on a photo with a hard
              // horizon reads as a rendering fault. Decal lets the blur fall
              // off into the black underneath instead.
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              // Overscaled so the softened edge decal leaves at the frame's
              // border is pushed off screen rather than showing as a pale
              // vignette inside it.
              child: Transform.scale(scale: 1.25, child: image),
            ),
          ),
          ColoredBox(color: Color.fromRGBO(0, 0, 0, dim)),
        ],
      ),
    );
  }
}

/// The decode width, in device pixels, a backdrop copy asks for when the caller
/// has nothing warmer to offer.
///
/// Tiny on purpose. It is about to be blurred by 34 logical pixels, so anything
/// sharper is megabytes spent on detail that is destroyed on the way to the
/// screen. Prefer a width the caller has ALREADY decoded — a thumbnail's — over
/// this, since that costs nothing at all.
const int kPhotoBackdropDecodeWidth = 96;

/// The fraction of a picture that has to survive a fill for filling to be worth
/// it.
///
/// A `cover` fit on a viewer that is not the picture's shape crops the long
/// axis, and past some point what is left is a slice rather than a photograph.
/// At 0.55 a phone-camera PORTRAIT shot (3:4 on a 19.5:9 screen keeps ~62%)
/// fills the screen the way a story does, while a landscape shot (~35%) and a
/// square one (~46%) stay whole and get [PhotoBackdrop] behind them instead.
///
/// That split is the whole answer to "the image is not covering fullscreen": on
/// a tall phone most of what people post is portrait, and letterboxing it left
/// nearly 40% of the display as dead space with the chrome sitting in it.
const double kPhotoFillThreshold = 0.55;

/// Whether a picture of [aspect] (width ÷ height) should FILL a viewer on a
/// [screen]-shaped display rather than being letterboxed inside it.
///
/// False for an unknown ratio: showing the whole picture is the answer that is
/// never wrong, and the ratio is usually known a frame later anyway.
bool photoFillsScreen(double? aspect, Size screen) {
  if (aspect == null || !aspect.isFinite || aspect <= 0) return false;
  if (screen.width <= 0 || screen.height <= 0) return false;
  final screenAspect = screen.width / screen.height;
  final keep = aspect > screenAspect
      ? screenAspect / aspect
      : aspect / screenAspect;
  return keep >= kPhotoFillThreshold;
}
