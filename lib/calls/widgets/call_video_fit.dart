import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// How a full-bleed call feed fits its box: fill it (cover) when the
/// picture and the box are the same shape, show all of it (contain) when
/// one is landscape and the other portrait.
///
/// Cover on a crossed shape is a heavy zoom, not a trim: a laptop's 16:9
/// camera filling a portrait phone keeps about a quarter of its width, so
/// the peer sees a close-up of a face that looks far away in the sender's
/// own preview. Same-shape feeds (phone to phone, laptop to laptop) still
/// fill edge to edge.
///
/// [video] is the picture's displayed size, rotation already applied; an
/// empty one (no frame yet) keeps cover, the shape every feed starts in.
BoxFit callFeedFit(Size video, Size box) {
  if (video.isEmpty || box.isEmpty) return BoxFit.cover;
  // A square either way is close enough to fill.
  if (video.width == video.height || box.width == box.height) {
    return BoxFit.cover;
  }
  final videoWide = video.width > video.height;
  final boxWide = box.width > box.height;
  return videoWide == boxWide ? BoxFit.cover : BoxFit.contain;
}

/// [renderer]'s picture size as shown: width and height swap for a frame
/// the sender tagged as rotated a quarter turn.
Size displayedVideoSize(RTCVideoValue v) {
  final rotated = v.rotation == 90 || v.rotation == 270;
  return rotated ? Size(v.height, v.width) : Size(v.width, v.height);
}

/// A full-bleed [RTCVideoView] whose fit follows [callFeedFit]: it listens
/// to [renderer] for the picture's size (a frame-size change, not every
/// frame) and to its own box.
class CallFeedView extends StatelessWidget {
  const CallFeedView({super.key, required this.renderer, this.mirror = false});

  final RTCVideoRenderer renderer;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder<RTCVideoValue>(
        valueListenable: renderer,
        builder: (context, v, _) {
          final fit = callFeedFit(displayedVideoSize(v), constraints.biggest);
          return RTCVideoView(
            renderer,
            mirror: mirror,
            objectFit: fit == BoxFit.contain
                ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        },
      ),
    );
  }
}
