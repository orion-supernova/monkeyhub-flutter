import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../backend/chat_api.dart';
import '../theme/theme_scope.dart';

/// Inline video player for chat messages. Resolves the storage URL on demand
/// and renders a tap-to-play surface with a play overlay + scrubber.
class VideoMessage extends StatefulWidget {
  const VideoMessage({
    super.key,
    required this.api,
    required this.storageId,
    required this.isMine,
  });

  final ChatApi api;
  final String? storageId;
  final bool isMine;

  @override
  State<VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<VideoMessage> {
  VideoPlayerController? _controller;
  bool _resolving = false;
  Object? _error;

  static final Map<String, String> _urlCache = {};

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
      var url = _urlCache[id];
      url ??= await widget.api.getFileUrl(id);
      _urlCache[id] = url;
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

    Widget surface;
    if (_error != null) {
      surface = Container(
        width: 240,
        height: 180,
        color: theme.surfaceSunken,
        alignment: Alignment.center,
        child: Icon(Icons.broken_image_outlined, color: theme.inkMuted),
      );
    } else if (c == null || _resolving) {
      surface = Container(
        width: 240,
        height: 180,
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
            constraints: const BoxConstraints(maxWidth: 280, maxHeight: 360),
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
