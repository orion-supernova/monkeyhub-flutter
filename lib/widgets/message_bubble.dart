import 'dart:ui';
import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'user_avatar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.now});
  final Message message;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final author = store.userById(message.authorId);
    final isMine = author.id == store.me.id;

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: theme.messageBubbleDecoration(isMine: isMine, ephemeral: false),
      child: Text(
        message.text,
        style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
      ),
    );

    final metaRow = Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine)
            Text(author.name.split(' ').first.toLowerCase(), style: theme.monoTiny.copyWith(color: theme.inkSoft)),
          if (!isMine) const SizedBox(width: 6),
          Text(_fmtTime(message.createdAt), style: theme.monoTiny),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMine) ...[
            UserAvatar(user: author, size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  child: bubble,
                ),
                metaRow,
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class EphemeralMessageBubble extends StatelessWidget {
  const EphemeralMessageBubble({super.key, required this.message, required this.now});
  final Message message;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final author = store.userById(message.authorId);
    final isMine = author.id == store.me.id;
    final progress = message.lifeProgress(now);
    final left = message.timeLeft(now);
    final dissolving = progress > 0.82;
    final dissolveT = dissolving ? ((progress - 0.82) / 0.18).clamp(0.0, 1.0) : 0.0;

    final bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: theme.messageBubbleDecoration(isMine: isMine, ephemeral: true),
          child: Text(
            message.text,
            style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
          ),
        ),
        // Theme-specific dissolve overlay only when message is close to expiring
        if (dissolveT > 0)
          Positioned.fill(
            child: theme.ephemeralSignature(progress: dissolveT),
          ),
      ],
    );

    final bubbleWithEffect = ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: dissolveT * 4.5,
        sigmaY: dissolveT * 4.5,
      ),
      child: Opacity(opacity: 1 - dissolveT * 0.85, child: bubble),
    );

    final metaRow = Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMine) ...[
            Text(author.name.split(' ').first.toLowerCase(), style: theme.monoTiny.copyWith(color: theme.inkSoft)),
            const SizedBox(width: 6),
          ],
          _Countdown(left: left, theme: theme),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Transform.translate(
        offset: Offset(0, -dissolveT * 10),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Opacity(opacity: 1 - dissolveT * 0.7, child: UserAvatar(user: author, size: 28)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    child: bubbleWithEffect,
                  ),
                  Opacity(opacity: 1 - dissolveT, child: metaRow),
                ],
              ),
            ),
          ],
        ),
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
          Text(
            _fmt(),
            style: theme.monoTiny.copyWith(color: theme.accent),
          ),
        ],
      ),
    );
  }
}
