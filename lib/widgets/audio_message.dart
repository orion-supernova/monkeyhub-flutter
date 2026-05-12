import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../backend/chat_api.dart';
import '../theme/theme_scope.dart';

/// Inline audio bubble. Resolves [storageId] → URL via the API, lazy-loads
/// into a [just_audio] player, plays in place. Minimal UX: play/pause +
/// position scrubber.
class AudioMessage extends StatefulWidget {
  const AudioMessage({
    super.key,
    required this.api,
    required this.storageId,
    required this.isMine,
  });
  final ChatApi api;
  final String? storageId;
  final bool isMine;

  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage> {
  final _player = AudioPlayer();
  bool _ready = false;
  Object? _error;

  static final Map<String, String> _urlCache = {};

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final id = widget.storageId;
    if (id == null) return;
    try {
      String url = _urlCache[id] ?? await widget.api.getFileUrl(id);
      _urlCache[id] = url;
      await _player.setUrl(url);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final ink = widget.isMine ? theme.accentInk : theme.ink;

    if (widget.storageId == null) {
      return Text('[audio missing]', style: theme.body.copyWith(color: ink));
    }
    if (_error != null) {
      return Text('audio failed', style: theme.body.copyWith(color: ink));
    }

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        final processing = snap.data?.processingState;
        return StreamBuilder<Duration?>(
          stream: _player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final total = _player.duration ?? Duration.zero;
            final progress = total.inMilliseconds == 0
                ? 0.0
                : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: !_ready
                      ? null
                      : () {
                          if (playing) {
                            _player.pause();
                          } else {
                            if (processing == ProcessingState.completed) {
                              _player.seek(Duration.zero);
                            }
                            _player.play();
                          }
                        },
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: widget.isMine ? ink.withValues(alpha: 0.2) : theme.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: !_ready
                        ? SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.isMine ? ink : theme.accentInk,
                            ),
                          )
                        : Icon(
                            playing ? Icons.pause : Icons.play_arrow,
                            color: widget.isMine ? ink : theme.accentInk,
                            size: 18,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: ink,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        total > Duration.zero ? '${_fmt(pos)} / ${_fmt(total)}' : 'loading…',
                        style: theme.monoTiny.copyWith(color: ink.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
