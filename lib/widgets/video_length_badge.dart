import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../backend/chat_api.dart';
import '../media/video_duration.dart';
import 'photo_chrome.dart' show MediaDurationBadge;

/// A video's running time on the shared duration badge, for every surface
/// that shows a video tile: the room gallery and the chat bubble.
///
/// Uses the message's own length when the sender measured one. When it did
/// not, [VideoDuration] reads it from the file's header, once per video per
/// device, and the badge fills in when the answer lands: no more tiles with
/// a time beside tiles without one.
class VideoLengthBadge extends StatefulWidget {
  const VideoLengthBadge({
    super.key,
    required this.storageId,
    required this.durationMs,
    required this.api,
    this.withIcon = false,
  });

  final String? storageId;
  final int? durationMs;
  final ChatApi api;

  /// Leads with a play glyph, and shows just the glyph while the length is
  /// unknown: the gallery tile's mark, which must say "video" either way.
  final bool withIcon;

  @override
  State<VideoLengthBadge> createState() => _VideoLengthBadgeState();
}

class _VideoLengthBadgeState extends State<VideoLengthBadge> {
  int? _probed;

  int? get _ms => knownVideoDuration(widget.storageId, widget.durationMs) ??
      _probed;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  @override
  void didUpdateWidget(VideoLengthBadge old) {
    super.didUpdateWidget(old);
    if (old.storageId != widget.storageId) {
      _probed = null;
      _probe();
    }
  }

  void _probe() {
    final id = widget.storageId;
    if (id == null || _ms != null) return;
    VideoDuration.instance
        .resolve(id, videoUrlFor(id, widget.api.getFileUrl))
        .then((ms) {
      if (!mounted || widget.storageId != id || ms == null) return;
      setState(() => _probed = ms);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ms = _ms;
    final icon = widget.withIcon ? CupertinoIcons.play_fill : null;
    if (ms == null || ms <= 0) {
      return widget.withIcon
          ? const MediaDurationBadge(text: '', icon: CupertinoIcons.play_fill)
          : const SizedBox.shrink();
    }
    return MediaDurationBadge(duration: Duration(milliseconds: ms), icon: icon);
  }
}
