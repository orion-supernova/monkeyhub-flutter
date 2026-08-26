import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../widgets/photo_dismiss_area.dart';
import '../widgets/remote_image.dart';
import '../widgets/route_landing.dart';
import '../widgets/steady_hero.dart';

/// Fullscreen viewer for a single image stored in Convex.
///
/// Pinch and double-tap to zoom; swipe in any vertical direction or tap the X
/// to dismiss. When the caller supplies a [heroTag] matching a [Hero] around the
/// thumbnail it was opened from, the picture flies between the two.
class FullscreenImageViewer extends StatefulWidget {
  const FullscreenImageViewer({
    super.key,
    required this.storageId,
    required this.api,
    this.heroTag,
    this.heroRadius,
    this.thumbnailDecodeWidth,
    this.circular = false,
    this.aspectRatio,
  });

  final String storageId;
  final ChatApi api;

  /// Tag of the [Hero] wrapping the source thumbnail.
  ///
  /// Null means no flight — and null is honoured literally. The previous
  /// implementation substituted `'image-$storageId'` when this was omitted,
  /// which could never match any caller's tag, so every "no tag" open mounted a
  /// lone Hero that quietly did nothing.
  final Object? heroTag;

  /// Corner radius of the source thumbnail, un-rounded to zero across the
  /// flight so the picture's corners open out rather than snapping square at
  /// whichever endpoint the shuttle happens to render. Rectangular mode only —
  /// [circular] is round at both ends and has nothing to tween.
  final BorderRadius? heroRadius;

  /// Decode width in device pixels of the thumbnail this was opened from, used
  /// as the arrival backdrop. See [RemoteImage.placeholderDecodeWidth] — without
  /// it the flight lands on a shimmer even though the bytes are already local.
  final int? thumbnailDecodeWidth;

  /// Show the picture as a large centered circle instead of a full-bleed
  /// rectangle. For avatars: they are cropped to a circle everywhere else in the
  /// app, so un-rounding one on the way to fullscreen reveals crop corners
  /// nobody chose. See [openAvatar].
  final bool circular;

  /// Width÷height of the picture, when the caller already knows it.
  ///
  /// Reserves the right box before a single byte has decoded. Without it the
  /// resting image is whatever the placeholder measures — and a placeholder with
  /// no intrinsic size fills the screen, so a Hero flight lands on a full-screen
  /// rect and then jumps down to the photo's real one the moment it decodes.
  /// Ignored in [circular] mode, where the box is a square by definition.
  final double? aspectRatio;

  /// Fraction of the shorter screen edge the circle occupies in [circular] mode.
  /// Big enough to read as "fullscreen", short of the edges so the round shape
  /// stays legible against the barrier.
  static const _circleFraction = 0.82;

  static Future<void> open(
    BuildContext context, {
    required String storageId,
    required ChatApi api,
    Object? heroTag,
    BorderRadius? heroRadius,
    int? thumbnailDecodeWidth,
    bool circular = false,
    double? aspectRatio,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        // Transparent: the barrier is painted inside, so it can fade with the
        // dismiss drag and leave the page underneath visible while the Hero
        // flies home. A solid barrierColor here would black out the return.
        barrierColor: Colors.transparent,
        // Tuned down from 260/220. The flight is a direct response to a tap on
        // the thing that flies, so it wants to feel like the picture moved, not
        // like an animation played; the hero controller already spends a frame
        // before any of it starts.
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, _, _) => FullscreenImageViewer(
          storageId: storageId,
          api: api,
          heroTag: heroTag,
          heroRadius: heroRadius,
          thumbnailDecodeWidth: thumbnailDecodeWidth,
          circular: circular,
          aspectRatio: aspectRatio,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  /// Opens [storageId] as a large centered circle flying from a [sourceSize]-wide
  /// circular avatar. Wraps [open] so the avatar call sites — room header, room
  /// info, profile — don't each repeat the same param soup.
  static Future<void> openAvatar(
    BuildContext context, {
    required String storageId,
    required ChatApi api,
    required Object heroTag,
    required double sourceSize,
  }) {
    return open(
      context,
      storageId: storageId,
      api: api,
      heroTag: heroTag,
      circular: true,
      // Reuse the decode that's already on screen as the arrival backdrop, so
      // the flight never lands on a placeholder.
      thumbnailDecodeWidth: _decodeWidth(context, sourceSize),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with RouteLanding {
  /// Live drag offset, written by [PhotoDismissArea] and painted here. A
  /// notifier rather than `setState` so a drag repaints one transform instead
  /// of rebuilding the whole route every frame.
  final ValueNotifier<Offset> _drag = ValueNotifier(Offset.zero);

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final diameter =
        math.min(screen.width, screen.height) * FullscreenImageViewer._circleFraction;
    final Widget image = widget.circular ? _circleImage(diameter) : _rectImage();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<Offset>(
        valueListenable: _drag,
        builder: (context, drag, child) {
          final t = photoDismissProgress(drag, screen);
          return Stack(
            children: [
              // Barrier inside the route so it can fade to fully transparent as
              // the drag commits — that's what makes the Hero return read as the
              // picture going back where it came from rather than a cut.
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 1 - t),
                  ),
                ),
              ),
              Transform.translate(
                offset: drag,
                child: Transform.scale(
                  scale: 1 - t * kPhotoDismissShrink,
                  child: child,
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                right: 8,
                child: Opacity(
                  // The chrome gets out of the way as the picture leaves.
                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          );
        },
        // Built once and passed through the builder: the image subtree is the
        // expensive part and none of it depends on the drag offset.
        // Hero wraps the image only, NOT the InteractiveViewer inside
        // [PhotoDismissArea]. Wrapping the viewer meant the flight scaled the
        // interactive layer itself, so its gesture geometry was mid-animation
        // garbage for the duration of every open and close.
        child: PhotoDismissArea(
          drag: _drag,
          onDismiss: () => Navigator.of(context).maybePop(),
          child: _maybeHero(image),
        ),
      ),
    );
  }

  /// The circle destination: a fixed square box, `cover`, clipped round.
  ///
  /// Deliberately no `width`/`height` on the [RemoteImage] — the [SizedBox]
  /// supplies the box, and leaving the image unsized sends its decode down
  /// `decodeSizeFor`'s screen-cap branch. That matters here: a circle crops a
  /// non-square avatar hard, and decoding to the box's short edge would leave
  /// the visible part upscaled and soft on the biggest view of it in the app.
  Widget _circleImage(double diameter) => ClipOval(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: RemoteImage(
            storageId: widget.storageId,
            api: widget.api,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.zero,
            placeholderDecodeWidth: widget.thumbnailDecodeWidth,
            decodeWidth: _deferredDecodeWidth,
          ),
        ),
      );

  /// The decode to use right now: the thumbnail's while the picture is still
  /// flying, and whatever the box asks for once it has landed. Null the whole
  /// time when there is no thumbnail to stand in — nothing to defer to.
  ///
  /// The thumbnail's decode is already resident, so painting from it costs
  /// nothing and the flight has neither anything to wait for nor anything to
  /// compete with. See [RemoteImage.decodeWidth], and [RouteLanding] for why
  /// "has it landed?" is a question that cannot be answered during a build.
  int? get _deferredDecodeWidth => landed ? null : widget.thumbnailDecodeWidth;

  /// The full-bleed destination: the whole frame, at its own ratio.
  Widget _rectImage() {
    final image = RemoteImage(
      storageId: widget.storageId,
      api: widget.api,
      fit: BoxFit.contain,
      borderRadius: BorderRadius.zero,
      placeholderDecodeWidth: widget.thumbnailDecodeWidth,
      decodeWidth: _deferredDecodeWidth,
    );
    final aspect = widget.aspectRatio;
    if (aspect == null || !aspect.isFinite || aspect <= 0) return image;
    // Pin the box to the picture's shape so the Hero has a stable destination
    // from the first frame, decoded or not. `Center` hands down loose
    // constraints, so this settles at the largest rect of that ratio which
    // fits — exactly where the decoded image would have landed anyway.
    return AspectRatio(aspectRatio: aspect, child: image);
  }

  /// Paints the picture `cover` inside whatever rect the flight is currently at.
  ///
  /// This is what makes an open and a close continuous. The thumbnail crops to
  /// fill its box and the fullscreen view shows the whole frame, so the two ends
  /// disagree about the crop — and a shuttle that paints `contain`, as this one
  /// used to, letterboxes the picture inside the small end and then snaps to the
  /// thumbnail's fill when it lands. `cover` reproduces the thumbnail's crop at
  /// the small end, and at the big end the rect already has the picture's own
  /// ratio, where `cover` and `contain` are the same thing. The crop animates
  /// instead of cutting.
  Widget _flightImage() => RemoteImage(
        storageId: widget.storageId,
        api: widget.api,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.zero,
        placeholderDecodeWidth: widget.thumbnailDecodeWidth,
        // The thing actually on screen for the length of a flight, so this is
        // the one that must never wait on a decode. On the way out that means
        // the thumbnail's, which is resident by definition — it is what was just
        // tapped. On the way home [RouteLanding.landed] is already true and the full decode
        // is resident too, so the return flies at full sharpness for free.
        decodeWidth: _deferredDecodeWidth,
      );

  Widget _maybeHero(Widget image) {
    final tag = widget.heroTag;
    if (tag == null) return image;
    if (widget.circular) {
      // Render *this* subtree in both directions rather than letting the
      // default shuttle pick up the destination's. On the way home the
      // destination is the avatar as its own screen draws it — and those differ:
      // room info clips with a 92 px radius, which at full size is a rounded
      // rectangle, not a circle. Flying our own ClipOval keeps it round from end
      // to end whichever way it is going.
      return SteadyHero(
        tag: tag,
        flightShuttleBuilder: (_, _, _, _, _) => image,
        child: image,
      );
    }
    final from = widget.heroRadius;
    // Built here rather than inside the shuttle builder so a flight inflates one
    // image widget instead of standing up a fresh one — and its decode is the
    // one this route already has warm.
    final flight = _flightImage();
    return SteadyHero(
      tag: tag,
      flightShuttleBuilder: (_, animation, _, _, _) {
        // Un-round the source shape across the flight. Without this a rounded
        // thumbnail snaps to square corners at whichever endpoint the shuttle
        // happens to render, which is the single most obvious tell that a
        // flight is a cut and not a movement.
        final tween = BorderRadiusTween(
          begin: from ?? BorderRadius.zero,
          end: BorderRadius.zero,
        );
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );
        return AnimatedBuilder(
          animation: curved,
          builder: (_, child) => ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: tween.evaluate(curved) ?? BorderRadius.zero,
            child: child,
          ),
          child: flight,
        );
      },
      child: image,
    );
  }
}

/// Decode width in device pixels for a thumbnail of [logicalWidth], for passing
/// as [FullscreenImageViewer.thumbnailDecodeWidth].
///
/// Has to agree with what [RemoteImage] actually decoded at, or the viewer's
/// backdrop is a different `ImageCache` entry and misses.
int thumbnailDecodeWidth(BuildContext context, double logicalWidth) =>
    _decodeWidth(context, logicalWidth);

/// The implementation behind [thumbnailDecodeWidth], under a name that isn't
/// shadowed by [FullscreenImageViewer.thumbnailDecodeWidth] — inside the class,
/// the field wins the lookup and the function is unreachable.
int _decodeWidth(BuildContext context, double logicalWidth) =>
    math.max(1, (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round());
