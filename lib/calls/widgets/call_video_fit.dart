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

/// How a grid tile's feed fits it: fill the tile unless filling would cut
/// away more than half the picture, then show all of it.
///
/// A tile's shape follows the head count, not the screen, so the 1:1 rule
/// ([callFeedFit]) is the wrong question: two people stacked on a phone get
/// near-square tiles, and a portrait phone camera filling one keeps 60% of
/// its height, a normal FaceTime crop. What it guards against is the deep
/// zoom: a laptop's 16:9 camera in a tall 2x2 tile would keep a quarter of
/// its width, a nose where a face should be.
BoxFit callTileFit(Size video, Size box) {
  if (video.isEmpty || box.isEmpty) return BoxFit.cover;
  final v = video.width / video.height;
  final b = box.width / box.height;
  // The share of the picture a cover fit keeps along its cropped axis.
  final kept = v > b ? b / v : v / b;
  return kept >= 0.5 ? BoxFit.cover : BoxFit.contain;
}

/// [renderer]'s picture size as shown: width and height swap for a frame
/// the sender tagged as rotated a quarter turn.
Size displayedVideoSize(RTCVideoValue v) {
  final rotated = v.rotation == 90 || v.rotation == 270;
  return rotated ? Size(v.height, v.width) : Size(v.width, v.height);
}

/// A full-bleed [RTCVideoView] whose fit follows [callFeedFit] (or
/// [callTileFit] in a grid [tile]): it listens to [renderer] for the
/// picture's size (a frame-size change, not every frame) and to its own box.
///
/// Every one on screen can be found by its stream ([CallFeedAnchors]): the
/// floating call window flies out of the feed it is about to show, and
/// hands back to it once it has a picture.
class CallFeedView extends StatefulWidget {
  const CallFeedView({
    super.key,
    required this.renderer,
    this.mirror = false,
    this.tile = false,
  });

  final RTCVideoRenderer renderer;
  final bool mirror;

  /// A tile in a group grid rather than the whole screen.
  final bool tile;

  @override
  State<CallFeedView> createState() => _CallFeedViewState();
}

class _CallFeedViewState extends State<CallFeedView> {
  @override
  void initState() {
    super.initState();
    CallFeedAnchors._live.add(this);
  }

  @override
  void dispose() {
    CallFeedAnchors._live.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ValueListenableBuilder<RTCVideoValue>(
        valueListenable: widget.renderer,
        builder: (context, v, _) {
          final fit = (widget.tile ? callTileFit : callFeedFit)(
            displayedVideoSize(v),
            constraints.biggest,
          );
          return RTCVideoView(
            widget.renderer,
            mirror: widget.mirror,
            objectFit: fit == BoxFit.contain
                ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        },
      ),
    );
  }
}

/// The [CallFeedView]s on screen, found by the stream they show.
abstract final class CallFeedAnchors {
  static final Set<_CallFeedViewState> _live = {};

  static _CallFeedViewState? _find(String? streamId) {
    if (streamId == null) return null;
    for (final f in _live) {
      if (f.mounted && f.widget.renderer.srcObject?.id == streamId) return f;
    }
    return null;
  }

  /// Where a feed of [streamId] is on screen, in global coordinates; null
  /// when none is laid out.
  static Rect? rectOf(String? streamId) {
    final box = _find(streamId)?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// A feed of [streamId] is on screen with a picture in it.
  static bool showing(String? streamId) {
    final f = _find(streamId);
    if (f == null) return false;
    final v = f.widget.renderer.value;
    return v.width > 0 && v.height > 0;
  }
}
