import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

/// Renders an image stored in Convex by [storageId]. Resolves the serving
/// URL via `files.getFileUrl` and caches the resolved URL in-memory for the
/// life of the app so we don't re-resolve every rebuild.
class RemoteImage extends StatefulWidget {
  const RemoteImage({
    super.key,
    required this.storageId,
    required this.api,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String storageId;
  final ChatApi api;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  static final Map<String, String> _urlCache = {};

  @override
  State<RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<RemoteImage> {
  String? _url;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // Synchronous hit on the warm URL cache so rebuilds don't flash a
    // shimmer frame before the cached URL takes effect.
    final cached = RemoteImage._urlCache[widget.storageId];
    if (cached != null) {
      _url = cached;
    } else {
      _resolve();
    }
  }

  @override
  void didUpdateWidget(RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageId != widget.storageId) {
      _url = null;
      _error = null;
      final cached = RemoteImage._urlCache[widget.storageId];
      if (cached != null) {
        _url = cached;
      } else {
        _resolve();
      }
    }
  }

  Future<void> _resolve() async {
    try {
      final url = await widget.api.getFileUrl(widget.storageId);
      RemoteImage._urlCache[widget.storageId] = url;
      if (!mounted) return;
      setState(() => _url = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(theme.radiusMd);
    if (_error != null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: theme.surfaceSunken, borderRadius: radius),
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, size: 24, color: theme.inkMuted),
      );
    }
    if (_url == null) {
      return _ShimmerBox(
        width: widget.width,
        height: widget.height,
        borderRadius: radius,
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        _url!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            child: frame == null
                ? _ShimmerBox(
                    key: const ValueKey('shim'),
                    width: widget.width,
                    height: widget.height,
                    borderRadius: radius,
                  )
                : KeyedSubtree(key: const ValueKey('img'), child: child),
          );
        },
        errorBuilder: (_, _, _) => Container(
          width: widget.width,
          height: widget.height,
          color: theme.surfaceSunken,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, size: 24, color: theme.inkMuted),
        ),
      ),
    );
  }
}

/// Animated gradient skeleton used while a remote image is resolving its
/// URL or decoding its first frame. Sweeps a soft highlight across a
/// [AppTheme.surfaceSunken] base so the placeholder feels alive instead of
/// blank.
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    super.key,
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
