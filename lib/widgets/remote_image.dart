import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../media/file_url_cache.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

/// Renders an image stored in Convex by [storageId].
///
/// Two layers of caching, because the old implementation had neither and images
/// visibly reloaded on every screen entry:
///
///  * **Bytes** — [CachedNetworkImage] keeps them on disk across launches and
///    honors the `cache-control: private, max-age=2592000` Convex already sends.
///    Plain `Image.network` has no persistent cache at all on mobile, so a cold
///    start re-downloaded every avatar.
///  * **Decode size** — every load is capped to the pixels actually painted.
///    This is the half that fixed the *in-session* reloading: stored photos run
///    ~1200×2600, which decodes to ~12 MiB, and Flutter's default `ImageCache`
///    budget is 100 MiB. Eight photos evicted the entire cache including every
///    avatar, so going back to the chat list re-downloaded all of them. A 40 px
///    avatar now costs ~0.03 MiB instead of 4 MiB.
///
/// The disk copy is deliberately left at full resolution (no `maxWidthDiskCache`)
/// so the fullscreen viewer can decode the same file at screen resolution and
/// stay sharp under zoom.
class RemoteImage extends StatefulWidget {
  const RemoteImage({
    super.key,
    required this.storageId,
    required this.api,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderDecodeWidth,
    this.decodeWidth,
    this.onAspectRatio,
  });

  final String storageId;
  final ChatApi api;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Decode width, in device pixels, of a low-resolution stand-in to show while
  /// the real one decodes — instead of the shimmer.
  ///
  /// Exists for the fullscreen viewer. Opening an image full-screen decodes it
  /// at screen resolution, which is a *different* `ImageCache` key from the
  /// thumbnail that was just on screen, so the destination of a Hero flight
  /// would otherwise land on a placeholder despite the bytes already being
  /// local. Pass the size the thumbnail used and that decode is reused as the
  /// backdrop: the flight arrives on the picture, and the sharp version fades
  /// in over it a frame or two later.
  final int? placeholderDecodeWidth;

  /// Decode width in device pixels, overriding what [decodeSizeFor] would work
  /// out from the painted box.
  ///
  /// Exists so the fullscreen viewer can hold the *big* decode back until its
  /// opening animation has finished. A full-screen decode is megabytes to
  /// allocate and megabytes to hand the GPU, and starting it on the frame the
  /// route is pushed puts all of that in direct competition with the flight —
  /// which is the one moment the picture is moving and dropped frames are
  /// unmissable. Pinned to the thumbnail's width the flight costs nothing at
  /// all, because that decode is already resident; the sharp one is fetched
  /// once the picture has landed and fades in over it.
  final int? decodeWidth;

  /// Reports the picture's width÷height once it has decoded.
  ///
  /// Read off the decode that is already on screen rather than by measuring the
  /// file again: [decodeSizeFor] constrains one axis, so the resized bitmap
  /// carries the source's ratio, and asking for it costs an `ImageCache` lookup
  /// against an entry this widget just populated. No second read, no second
  /// decode, no full-resolution copy.
  ///
  /// Fires at most once per resolved URL, and only when the ratio is genuinely
  /// new to this mount — a caller can drive layout from it without writing a
  /// setState loop.
  final ValueChanged<double>? onAspectRatio;

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

/// Target decode size in *device* pixels for a [RemoteImage] painted into a
/// [width]×[height] logical box on a [dpr] screen.
///
/// **Exactly one axis is ever constrained, never both.** `memCacheWidth` and
/// `memCacheHeight` reach `ResizeImage` through `octo_image`, and its default
/// `ResizeImagePolicy.exact` resizes to precisely that width *and* height
/// "regardless of whether it matches the source image's intrinsic aspect ratio
/// — similar to [BoxFit.fill]". Passing both squashed the bitmap before [fit]
/// ever ran, so a `cover` box had nothing left to crop and every non-square
/// source rendered stretched. Every call site in this app paints into a square,
/// so that hit avatars, message tiles, room cards and reply previews alike.
///
/// With one axis the other scales proportionally and the aspect ratio survives.
/// The cost is that `cover` into a square from a landscape source now decodes
/// short of the box's height and upscales to fill it; at thumbnail sizes that is
/// invisible, and the one place it would show — the fullscreen avatar circle —
/// deliberately passes no size at all so it lands on the screen cap below.
///
/// When neither axis is given (the fullscreen viewer) the decode is capped to
/// the screen's longest edge: decoding a 12 MP photo to paint a 1200 px-wide
/// phone screen is wasted memory and a wasted decode.
({int? width, int? height}) decodeSizeFor({
  required double? width,
  required double? height,
  required double dpr,
  required Size screen,
}) {
  int? px(double? logical) =>
      logical == null || !logical.isFinite ? null : math.max(1, (logical * dpr).round());

  // Width wins when both are asked for, so the key agrees with the one
  // `thumbnailDecodeWidth` builds for the fullscreen viewer's warm backdrop.
  // Disagree and that backdrop is a different `ImageCache` entry and always
  // misses, which is what used to land Hero flights on a shimmer.
  final w = px(width);
  if (w != null) return (width: w, height: null);
  final h = px(height);
  if (h != null) return (width: null, height: h);

  final longest = math.max(screen.width, screen.height);
  return (width: math.max(1, (longest * dpr).round()), height: null);
}

class _RemoteImageState extends State<RemoteImage> {
  String? _url;
  Object? _error;

  /// True when the URL came back from the network this mount rather than from
  /// the warm cache. Only then is a fade worth playing — fading in something
  /// that was already on disk just reads as a flicker.
  bool _wasCold = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageId != widget.storageId) {
      _error = null;
      _bind();
    }
  }

  /// Resolves the serving URL, synchronously when [FileUrlCache] already knows
  /// it. The synchronous path matters: it's what stops a cached image from
  /// rendering one placeholder frame before its URL arrives.
  void _bind() {
    final known = FileUrlCache.instance.peek(widget.storageId);
    if (known != null) {
      _url = known;
      _wasCold = false;
      return;
    }
    _url = null;
    _wasCold = true;
    final id = widget.storageId;
    final api = widget.api;
    FileUrlCache.instance.resolve(id, () => api.getFileUrl(id)).then((url) {
      // The widget may have been recycled onto a different image while this was
      // in flight (list reorder, page swipe) — dropping a stale result here is
      // what stops one row briefly showing another row's picture.
      if (!mounted || widget.storageId != id) return;
      setState(() => _url = url);
    }).catchError((Object e) {
      if (!mounted || widget.storageId != id) return;
      setState(() => _error = e);
    });
  }

  ({int? width, int? height}) _decodeSize(BuildContext context) {
    final override = widget.decodeWidth;
    if (override != null) return (width: math.max(1, override), height: null);
    return decodeSizeFor(
      width: widget.width,
      height: widget.height,
      dpr: MediaQuery.devicePixelRatioOf(context),
      screen: MediaQuery.sizeOf(context),
    );
  }

  /// The (url, decode) pair whose ratio has already been reported, so a rebuild
  /// — and a rebuild is what [RemoteImage.onAspectRatio] usually *causes* —
  /// doesn't resolve and report all over again.
  Object? _measured;

  ImageStream? _measureStream;
  ImageStreamListener? _measureListener;

  /// Asks the `ImageCache` for the size of the decode this widget is painting.
  ///
  /// The provider is rebuilt to equal the one `CachedNetworkImage` makes
  /// internally — same URL, same [ResizeImage] wrapper — so this resolves to the
  /// entry that already exists instead of starting a second, unresized decode.
  void _reportAspect(String url, ({int? width, int? height}) decode) {
    if (widget.onAspectRatio == null) return;
    final token = '$url|${decode.width}x${decode.height}';
    if (_measured == token) return;
    _measured = token;
    _stopMeasuring();

    final provider = ResizeImage.resizeIfNeeded(
      decode.width,
      decode.height,
      CachedNetworkImageProvider(url),
    );
    final stream = provider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      final size = Size(info.image.width.toDouble(), info.image.height.toDouble());
      // Hand the frame back immediately; holding it would keep a second
      // reference to the bitmap alive for the life of this widget.
      info.dispose();
      _stopMeasuring();
      if (!mounted || size.height <= 0) return;
      final aspect = size.width / size.height;
      // A warm entry completes the stream *synchronously* from `addListener`,
      // which lands inside the build that started it. The whole point of this
      // callback is to let a caller resize around the picture, so it has to
      // arrive somewhere a setState is legal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAspectRatio?.call(aspect);
      });
    }, onError: (_, _) => _stopMeasuring());

    _measureStream = stream;
    _measureListener = listener;
    stream.addListener(listener);
  }

  void _stopMeasuring() {
    final stream = _measureStream;
    final listener = _measureListener;
    _measureStream = null;
    _measureListener = null;
    if (stream != null && listener != null) stream.removeListener(listener);
  }

  @override
  void dispose() {
    _stopMeasuring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(theme.radiusMd);

    if (_error != null) return _broken(theme, radius);
    if (_url == null) {
      return _ShimmerBox(
        width: widget.width,
        height: widget.height,
        borderRadius: radius,
      );
    }

    final decode = _decodeSize(context);
    _reportAspect(_url!, decode);
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: _url!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: decode.width,
        memCacheHeight: decode.height,
        // A warm image is already decoded; fading it in would make a cache HIT
        // look like a load. Only a genuinely cold fetch gets the fade.
        fadeInDuration:
            _wasCold ? const Duration(milliseconds: 180) : Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (_, url) => _placeholder(url, radius),
        errorWidget: (_, _, _) => _broken(theme, radius),
      ),
    );
  }

  Widget _placeholder(String url, BorderRadius radius) {
    final lowRes = widget.placeholderDecodeWidth;
    if (lowRes != null) {
      return CachedNetworkImage(
        imageUrl: url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        memCacheWidth: lowRes,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        // No nested stand-in — one level of fallback, then the shimmer.
        placeholder: (_, _) => _ShimmerBox(
          width: widget.width,
          height: widget.height,
          borderRadius: radius,
        ),
        errorWidget: (_, _, _) => _ShimmerBox(
          width: widget.width,
          height: widget.height,
          borderRadius: radius,
        ),
      );
    }
    return _ShimmerBox(
      width: widget.width,
      height: widget.height,
      borderRadius: radius,
    );
  }

  Widget _broken(AppTheme theme, BorderRadius radius) => Container(
        width: widget.width,
        height: widget.height,
        decoration:
            BoxDecoration(color: theme.surfaceSunken, borderRadius: radius),
        alignment: Alignment.center,
        child:
            Icon(Icons.broken_image_outlined, size: 24, color: theme.inkMuted),
      );
}

/// Animated gradient skeleton used while a remote image is resolving its
/// URL or decoding its first frame. Sweeps a soft highlight across a
/// [AppTheme.surfaceSunken] base so the placeholder feels alive instead of
/// blank.
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    duration: const Duration(milliseconds: 1400),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Midtone base that splits the difference between the two bubble
    // surface tones, so the placeholder doesn't read as a stark "dark
    // box" inside a lighter bubble silhouette (which made any rounded-
    // corner antialias imperfection visible as a hard "cut off" edge).
    final base = Color.alphaBlend(
      theme.surfaceSunken.withValues(alpha: 0.55),
      theme.surfaceRaised,
    );
    final highlight = Color.alphaBlend(
      theme.surfaceRaised.withValues(alpha: 0.85),
      base,
    );
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // Sweep the gradient from fully off-screen-left (t=0) through the
          // box (t=0.5) to fully off-screen-right (t=1). At both endpoints
          // the gradient is outside [-1,1] so the visible content is uniform
          // base — the loop wraps invisibly with no flicker.
          final t = _ctrl.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment(-3 + 4 * t, 0),
              end: Alignment(-1 + 4 * t, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Container(
              width: widget.width,
              height: widget.height,
              color: base,
            ),
          );
        },
      ),
    );
  }
}
