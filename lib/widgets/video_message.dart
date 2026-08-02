import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../backend/chat_api.dart';
import '../media/file_url_cache.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';

/// Inline video player for chat messages. Resolves the storage URL on demand
/// and renders a tap-to-play surface with a play overlay + scrubber.
class VideoMessage extends StatefulWidget {
  const VideoMessage({
    super.key,
    required this.api,
    required this.storageId,
    required this.isMine,
    this.maxWidth,
  });

  final ChatApi api;
  final String? storageId;
  final bool isMine;

  /// Widest the video box may get, normally `ChatMetrics.videoMaxWidth` from
  /// the enclosing chat pane. Null falls back to [ChatMetrics.videoMin], which
  /// is the 280 this used to hard-code — so phones are unchanged.
  final double? maxWidth;

  @override
  State<VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<VideoMessage> {
  VideoPlayerController? _controller;
  bool _resolving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final id = widget.storageId;
    if (id == null || id.isEmpty) return;
    setState(() => _resolving = true);
    try {
      // Shared with every other attachment in the app, and persisted, so a
      // re-opened room doesn't re-query a URL it already had.
      final url =
          await FileUrlCache.instance.resolve(id, () => widget.api.getFileUrl(id));
      // Burned view-once, or a swept blob. Throwing lands in the catch below,
      // which is already the right rendering — the alternative was parsing the
      // string "null" into a URI and letting the player fail on it.
      if (url == null) throw const FileUnavailable();
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _resolving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _resolving = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
      } else {
        c.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final c = _controller;
    // Placeholders keep the 240x180-inside-280 proportions they had when all
    // three numbers were literals, so they scale together with the box.
    final boxW = widget.maxWidth ?? ChatMetrics.videoMin;
    final placeholderW = boxW * (240 / 280);
    final placeholderH = boxW * (180 / 280);

    Widget surface;
    if (_error != null) {
      surface = Container(
        width: placeholderW,
        height: placeholderH,
        color: theme.surfaceSunken,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: theme.inkMuted),
      );
    } else if (c == null || _resolving) {
      surface = Container(
        width: placeholderW,
        height: placeholderH,
        color: theme.surfaceSunken,
        alignment: Alignment.center,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent),
        ),
      );
    } else {
      surface = AspectRatio(
        aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
        child: VideoPlayer(c),
      );
    }

    return GestureDetector(
      onTap: c == null ? null : _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: boxW,
              maxHeight: boxW * ChatMetrics.videoAspectCap,
            ),
            child: surface,
          ),
          if (c != null && !c.value.isPlaying)
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
        ],
      ),
    );
  }
}
