import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
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
    _resolve();
  }

  @override
  void didUpdateWidget(RemoteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageId != widget.storageId) {
      _url = null;
      _error = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final cached = RemoteImage._urlCache[widget.storageId];
    if (cached != null) {
      setState(() => _url = cached);
      return;
    }
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
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: theme.surfaceSunken, borderRadius: radius),
        alignment: Alignment.center,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        _url!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
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
