import 'dart:ui';
import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../screens/fullscreen_image_viewer.dart';
import 'audio_message.dart';
import 'reaction_bubble.dart';
import 'remote_image.dart';
import 'user_avatar.dart';
import 'video_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.now,
    required this.currentUserId,
    required this.api,
    this.author,
    this.onLongPress,
    this.onDoubleTap,
    this.onReactionTap,
    this.onAuthorTap,
    this.seenByOthers = false,
  });

  final ChatMessage message;
  final DateTime now;
  final String currentUserId;
  final ChatApi api;
  final ChatUser? author;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onAuthorTap;
  final bool seenByOthers;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine && author != null) ...[
            GestureDetector(
              onTap: onAuthorTap,
              child: UserAvatar(user: author!, size: 28, api: api, showStatus: false),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: onLongPress,
                  onDoubleTap: onDoubleTap,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    child: _bubbleContent(theme, isMine, ephemeral: false),
                  ),
                ),
                if (message.reactions.isNotEmpty && onReactionTap != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    child: ReactionRow(
                      reactions: message.reactions,
                      currentUserId: currentUserId,
                      onToggle: onReactionTap!,
                      alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                    ),
                  ),
                _MetaRow(
                  message: message,
                  isMine: isMine,
                  seenByOthers: seenByOthers,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubbleContent(AppTheme theme, bool isMine, {required bool ephemeral}) {
    return buildMessageContent(
      theme: theme,
      message: message,
      isMine: isMine,
      ephemeral: ephemeral,
      api: api,
    );
  }
}

class EphemeralMessageBubble extends StatelessWidget {
  const EphemeralMessageBubble({
    super.key,
    required this.message,
    required this.now,
    required this.currentUserId,
    required this.api,
    this.author,
    this.onLongPress,
    this.onDoubleTap,
    this.onReactionTap,
    this.onAuthorTap,
  });
  final ChatMessage message;
  final DateTime now;
  final String currentUserId;
  final ChatApi api;
  final ChatUser? author;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final void Function(String emoji)? onReactionTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;
    final progress = message.lifeProgress(now);
    final dissolving = progress > 0.82;
    final dissolveT = dissolving ? ((progress - 0.82) / 0.18).clamp(0.0, 1.0) : 0.0;

    final inner = buildMessageContent(
      theme: theme,
      message: message,
      isMine: isMine,
      ephemeral: true,
      api: api,
    );

    final bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        inner,
        if (dissolveT > 0)
          Positioned.fill(child: theme.ephemeralSignature(progress: dissolveT)),
      ],
    );

    final bubbleWithEffect = ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: dissolveT * 4.5,
        sigmaY: dissolveT * 4.5,
      ),
      child: Opacity(opacity: 1 - dissolveT * 0.85, child: bubble),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Transform.translate(
        offset: Offset(0, -dissolveT * 10),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && author != null) ...[
              GestureDetector(
                onTap: onAuthorTap,
                child: Opacity(
                  opacity: 1 - dissolveT * 0.7,
                  child: UserAvatar(user: author!, size: 28, api: api, showStatus: false),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: onLongPress,
                    onDoubleTap: onDoubleTap,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      child: bubbleWithEffect,
                    ),
                  ),
                  if (message.reactions.isNotEmpty && onReactionTap != null)
                    Opacity(
                      opacity: 1 - dissolveT,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                        child: ReactionRow(
                          reactions: message.reactions,
                          currentUserId: currentUserId,
                          onToggle: onReactionTap!,
                          alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                        ),
                      ),
                    ),
                  Opacity(
                    opacity: 1 - dissolveT,
                    child: _MetaRow(
                      message: message,
                      isMine: isMine,
                      countdown: message.timeLeft(now),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds the inner "bubble body" widget for any message type, applying the
/// theme's bubble decoration. Extracted so both the standard and ephemeral
/// variants share the same renderer.
Widget buildMessageContent({
  required AppTheme theme,
  required ChatMessage message,
  required bool isMine,
  required bool ephemeral,
  required ChatApi api,
}) {
  final deco = theme.messageBubbleDecoration(isMine: isMine, ephemeral: ephemeral);
  switch (message.type) {
    case MessageType.image:
      final id = message.mediaStorageId;
      return Container(
        decoration: deco,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (id != null)
              Builder(builder: (ctx) {
                return GestureDetector(
                  onTap: () => FullscreenImageViewer.open(
                    ctx,
                    storageId: id,
                    api: api,
                    heroTag: 'msg-image-${message.id}',
                  ),
                  child: Hero(
                    tag: 'msg-image-${message.id}',
                    child: RemoteImage(
                      storageId: id,
                      api: api,
                      width: 240,
                      height: 240,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                );
              })
            else
              Container(
                width: 240,
                height: 80,
                color: theme.surfaceSunken,
                alignment: Alignment.center,
                child: Icon(Icons.image_not_supported_outlined, color: theme.inkMuted),
              ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  message.content,
                  style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
                ),
              ),
          ],
        ),
      );
    case MessageType.audio:
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: deco,
        child: AudioMessage(
          api: api,
          storageId: message.mediaStorageId,
          isMine: isMine,
        ),
      );
    case MessageType.video:
      return Container(
        decoration: deco,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoMessage(
              api: api,
              storageId: message.mediaStorageId,
              isMine: isMine,
            ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  message.content,
                  style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
                ),
              ),
          ],
        ),
      );
    case MessageType.url:
    case MessageType.system:
    case MessageType.text:
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: deco,
        child: Text(
          message.content,
          style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
        ),
      );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.message,
    required this.isMine,
    this.countdown,
    this.seenByOthers = false,
  });
  final ChatMessage message;
  final bool isMine;
  final Duration? countdown;
  final bool seenByOthers;

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_fmtTime(message.createdAt), style: theme.monoTiny),
          if (message.status == MessageStatus.pending) ...[
            const SizedBox(width: 8),
            Text('· SENDING', style: theme.monoTiny.copyWith(color: theme.inkMuted)),
          ],
          if (message.status == MessageStatus.error) ...[
            const SizedBox(width: 8),
            Text('· FAILED', style: theme.monoTiny.copyWith(color: theme.danger)),
          ],
          if (countdown != null) ...[
            const SizedBox(width: 8),
            _Countdown(left: countdown!, theme: theme),
          ],
          if (isMine && seenByOthers && message.status == MessageStatus.sent) ...[
            const SizedBox(width: 8),
            Icon(Icons.done_all, size: 12, color: theme.accent),
            const SizedBox(width: 3),
            Text('SEEN', style: theme.monoTiny.copyWith(color: theme.accent)),
          ],
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.left, required this.theme});
  final Duration left;
  final AppTheme theme;

  String _fmt() {
    final s = left.inSeconds.clamp(0, 99999);
    if (s < 60) return '${s}s';
    final mins = s ~/ 60;
    final rem = s % 60;
    return '${mins}m ${rem.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final urgency = left.inSeconds < 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: urgency ? theme.accent.withValues(alpha: 0.18) : theme.surfaceSunken,
        border: Border.all(color: theme.accent.withValues(alpha: urgency ? 0.7 : 0.35), width: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          theme.hourglassIcon(size: 9, color: theme.accent),
          const SizedBox(width: 5),
          Text(_fmt(), style: theme.monoTiny.copyWith(color: theme.accent)),
        ],
      ),
    );
  }
}
