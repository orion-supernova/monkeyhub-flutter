import 'dart:math' as math;
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
import 'reply_indicator.dart';
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
    this.onReplyIndicatorTap,
    this.onViewThread,
    this.parentAuthor,
    this.distanceLabel,
    this.highlightT = 0,
    this.useHero = true,
    this.showReplyIndicator = true,
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

  /// Invoked when the user taps the inline reply indicator. Receives the
  /// parent message id so the screen can scroll-and-highlight it.
  final void Function(String parentId)? onReplyIndicatorTap;

  /// Invoked when the user taps the branch icon on the inline reply
  /// indicator. The screen opens the cinematic thread overlay.
  final VoidCallback? onViewThread;

  /// Optional cached parent author — when provided, the inline indicator
  /// renders the parent's avatar circle, making the reply visually richer.
  final ChatUser? parentAuthor;

  /// Optional formatted distance hint shown on the reply indicator's header.
  final String? distanceLabel;

  /// 0..1 driving a one-shot accent halo pulse around the bubble (used by the
  /// scroll-to-parent flow). 0 = no pulse.
  final double highlightT;

  /// When false, image bubbles render without their Hero wrapper so they can
  /// be displayed inside an overlay without colliding with the in-list Hero.
  final bool useHero;

  /// When false, the inline reply indicator is suppressed and the leading-
  /// top corner stays full radius. Used inside the thread overlay where the
  /// chain is already visualized — showing each card's inline tether on top
  /// of the depth stack would be redundant clutter.
  final bool showReplyIndicator;

  final bool seenByOthers;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    // The main bubble with halo wrapper. The reply indicator (when present)
    // sits in a sibling Column ABOVE this — outside the bubble — so it can
    // adopt its own visual identity (phantom / sticky / comic) without
    // distorting the bubble's natural radius or background.
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _HighlightPulse(
        t: highlightT,
        isMine: isMine,
        child: _bubbleContent(theme, isMine, ephemeral: false),
      ),
    );

    final Widget bubbleArea;
    if (message.isReply && showReplyIndicator) {
      bubbleArea = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ReplyIndicator(
            preview: message.replyToPreview!,
            isMine: isMine,
            distanceLabel: distanceLabel,
            api: api,
            parentAuthor: parentAuthor,
            onTap: () {
              final id = message.replyToId;
              if (id != null) onReplyIndicatorTap?.call(id);
            },
            onViewThread: onViewThread,
          ),
          bubble,
        ],
      );
    } else {
      bubbleArea = bubble;
    }

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
                  child: bubbleArea,
                ),
                if (message.reactions.isNotEmpty && onReactionTap != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
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
      useHero: useHero,
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
    this.onReplyIndicatorTap,
    this.onViewThread,
    this.parentAuthor,
    this.distanceLabel,
    this.highlightT = 0,
    this.useHero = true,
    this.showReplyIndicator = true,
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
  final void Function(String parentId)? onReplyIndicatorTap;
  final VoidCallback? onViewThread;
  final ChatUser? parentAuthor;
  final String? distanceLabel;
  final double highlightT;
  final bool useHero;
  final bool showReplyIndicator;

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
      useHero: useHero,
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

    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    final innerBubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _HighlightPulse(
        t: highlightT,
        isMine: isMine,
        child: bubbleWithEffect,
      ),
    );

    final Widget bubbleArea;
    if (message.isReply && showReplyIndicator) {
      bubbleArea = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Indicator sits OUTSIDE the dissolve effect — its own identity,
          // its own fade if we add one later.
          ReplyIndicator(
            preview: message.replyToPreview!,
            isMine: isMine,
            distanceLabel: distanceLabel,
            api: api,
            parentAuthor: parentAuthor,
            onTap: () {
              final id = message.replyToId;
              if (id != null) onReplyIndicatorTap?.call(id);
            },
            onViewThread: onViewThread,
          ),
          innerBubble,
        ],
      );
    } else {
      bubbleArea = innerBubble;
    }

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
                    child: bubbleArea,
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
/// variants share the same renderer. The inline reply indicator is NO
/// LONGER rendered inside the bubble — it lives as a sibling above the
/// bubble in the caller's Column, so the bubble's natural radius is
/// preserved.
Widget buildMessageContent({
  required AppTheme theme,
  required ChatMessage message,
  required bool isMine,
  required bool ephemeral,
  required ChatApi api,
  bool useHero = true,
}) {
  final deco =
      theme.messageBubbleDecoration(isMine: isMine, ephemeral: ephemeral);

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
                final imageChild = RemoteImage(
                  storageId: id,
                  api: api,
                  width: 240,
                  height: 240,
                  borderRadius: BorderRadius.zero,
                );
                return GestureDetector(
                  onTap: () => FullscreenImageViewer.open(
                    ctx,
                    storageId: id,
                    api: api,
                    heroTag: useHero ? 'msg-image-${message.id}' : null,
                  ),
                  child: useHero
                      ? Hero(tag: 'msg-image-${message.id}', child: imageChild)
                      : imageChild,
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

/// One-shot accent halo pulse around a bubble. Drives off a 0..1 progress
/// value (typically a controller in 0..1 over ~1s) and maps it through
/// `sin(t*pi)` so the pulse blooms then settles in a single rise-fall arc.
class _HighlightPulse extends StatelessWidget {
  const _HighlightPulse({
    required this.t,
    required this.isMine,
    required this.child,
  });
  final double t;
  final bool isMine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return child;
    final theme = ThemeScope.of(context);
    final tCurve = math.sin(t * math.pi).clamp(0.0, 1.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Accent glow halo sitting behind the bubble.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.55 * tCurve),
                    blurRadius: 28 * tCurve,
                    spreadRadius: 4 * tCurve,
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
        // Accent border pulse on top so the highlight reads even when the
        // halo is occluded by overlapping bubbles below in the stack.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.accent.withValues(alpha: 0.55 * tCurve),
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
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
