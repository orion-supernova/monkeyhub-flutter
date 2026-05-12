import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'reaction_bubble.dart';
import 'user_avatar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.now,
    required this.currentUserId,
    this.author,
    this.onLongPress,
    this.onReactionTap,
  });

  final ChatMessage message;
  final DateTime now;
  final String currentUserId;
  final ChatUser? author;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: theme.messageBubbleDecoration(isMine: isMine, ephemeral: false),
      child: Text(
        message.content,
        style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine && author != null) ...[
            UserAvatar(user: author!, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: onLongPress,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    child: bubble,
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
                _MetaRow(message: message, isMine: isMine, author: author),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EphemeralMessageBubble extends StatelessWidget {
  const EphemeralMessageBubble({
    super.key,
    required this.message,
    required this.now,
    required this.currentUserId,
    this.author,
    this.onLongPress,
    this.onReactionTap,
  });
  final ChatMessage message;
  final DateTime now;
  final String currentUserId;
  final ChatUser? author;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;
    final progress = message.lifeProgress(now);
    final dissolving = progress > 0.82;
    final dissolveT = dissolving ? ((progress - 0.82) / 0.18).clamp(0.0, 1.0) : 0.0;

    final inner = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: theme.messageBubbleDecoration(isMine: isMine, ephemeral: true),
      child: Text(
        message.content,
        style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
      ),
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
              Opacity(opacity: 1 - dissolveT * 0.7, child: UserAvatar(user: author!, size: 28)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress: onLongPress,
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
                      author: author,
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.message,
    required this.isMine,
    this.author,
    this.countdown,
  });
  final ChatMessage message;
  final bool isMine;
  final ChatUser? author;
  final Duration? countdown;

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
          if (!isMine && author != null) ...[
            Text(author!.displayName.toLowerCase(),
                style: theme.monoTiny.copyWith(color: theme.inkSoft)),
            const SizedBox(width: 6),
          ],
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
