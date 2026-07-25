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

  @override
  State<RemoteImage> createState() => _RemoteImageState();
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

  /// Target decode size in *device* pixels.
  ///
  /// Null on an axis means "no constraint from us" — `cached_network_image`
  /// scales the other axis proportionally, so passing only one preserves the
  /// image's aspect ratio. When neither is given (the fullscreen viewer) we
  /// clamp to the screen's longest edge, since decoding a 12 MP photo to paint
  /// a 1200 px-wide phone screen is wasted memory and a wasted decode.
  ({int? width, int? height}) _decodeSize(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    int? px(double? logical) =>
        logical == null || !logical.isFinite ? null : math.max(1, (logical * dpr).round());

    final w = px(widget.width);
    final h = px(widget.height);
    if (w != null || h != null) return (width: w, height: h);

    final size = MediaQuery.sizeOf(context);
    final longest = math.max(size.width, size.height);
    final capped = math.max(1, (longest * dpr).round());
    // Constrain the longer axis only, so portrait and landscape sources both
    // keep their aspect ratio.
    return (width: capped, height: null);
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
