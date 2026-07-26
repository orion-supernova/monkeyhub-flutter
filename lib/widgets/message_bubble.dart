import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../data/settings_store.dart';
import '../media/media_aspect_cache.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../screens/fullscreen_image_viewer.dart';
import '../services/link_opener.dart';
import 'audio_message.dart';
import 'link_preview_card.dart';
import 'linkified_text.dart';
import 'reaction_bubble.dart';
import 'remote_image.dart';
import 'steady_hero.dart';
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
    this.highlightT = 0,
    this.useHero = true,
    this.showReplyIndicator = true,
    this.seenByOthers = false,
    this.grouped = false,
    this.lastInRun = true,
    this.showAvatarSlot = true,
    this.showAvatar = true,
    this.avatarAtBottom = false,
    this.senderName,
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

  /// When true this message continues a run from the same sender: the vertical
  /// gap tightens and [senderName] is left null by the caller. Nothing
  /// collapses the run's meta rows — SENDING / FAILED / SEEN stay per-message.
  final bool grouped;

  /// Whether this row closes its run. The bubble that closes a run is the one
  /// that carries the tail — the rows above it keep their sender-side corners
  /// tightened so the whole run reads as a single block of speech. Defaults to
  /// true so a bubble rendered on its own (the lifted action-menu preview)
  /// looks like the single message it is.
  final bool lastInRun;

  /// Whether the leading avatar column exists at all. False in DMs, where
  /// there is only one other person and a face on every row is pure noise —
  /// the bubble then starts at the transcript's left edge.
  final bool showAvatarSlot;

  /// Whether *this* row is the one that draws the avatar. False renders the
  /// slot as empty space of the same size, so the bubble's left edge doesn't
  /// shift between rows of a run — or while `author` is still resolving.
  final bool showAvatar;

  /// Aligns the avatar with the bubble's bottom edge instead of its top. Set
  /// on the last row of a multi-message run, where the face closes a block
  /// the sender's name opened.
  final bool avatarAtBottom;

  /// Rendered above the bubble when non-null. Callers pass it only on the
  /// first row of a run, and never for the current user or in a DM.
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    // The bubble's shape is a user preference, so the whole row rebuilds when
    // it changes. Settings writes are rare and user-initiated, and this is
    // what makes the picker's preview take effect everywhere at once.
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) =>
          _build(context, SettingsStore.instance.bubbleStyle),
    );
  }

  Widget _build(BuildContext context, BubbleStyle bubbleStyle) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;
    // One lookup for the whole bubble. Null when this bubble is rendered
    // outside a ChatPane (the lifted preview in the action menu overlay), in
    // which case every metric below falls back to the literal it replaced.
    final metrics = ChatMetricsScope.maybeOf(context);
    final maxWidth = metrics?.bubbleMaxWidth ?? messageMaxWidth(context);

    // The main bubble with halo wrapper. The reply indicator (when present)
    // sits in a sibling Column ABOVE this — outside the bubble — so it can
    // adopt its own visual identity (phantom / sticky / comic) without
    // distorting the bubble's natural radius or background.
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _HighlightPulse(
        t: highlightT,
        shape: pulseShapeFor(
          theme: theme,
          message: message,
          isMine: isMine,
          bubbleStyle: bubbleStyle,
          firstInRun: !grouped,
          lastInRun: lastInRun,
        ),
        child: _bubbleContent(theme, isMine,
            ephemeral: false, metrics: metrics, bubbleStyle: bubbleStyle),
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
            parentIsMine:
                message.replyToPreview!.senderId == currentUserId,
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
      padding: EdgeInsets.symmetric(vertical: grouped ? 1 : 6),
      child: _BubbleLayout(
        isMine: isMine,
        showAvatarSlot: showAvatarSlot,
        avatarAtBottom: avatarAtBottom,
        senderName: senderName,
        tailGutter: theme.bubbleTailGutter(bubbleStyle),
        avatar: _AvatarSlot(
          author: author,
          api: api,
          onTap: onAuthorTap,
          collapsed: !showAvatar,
        ),
        bubble: GestureDetector(
          onLongPress: onLongPress,
          onDoubleTap: onDoubleTap,
          // Desktop/trackpad right-click opens the same action menu,
          // anchored to the same bubble rect. No platform gate needed —
          // touch devices never produce a secondary tap.
          onSecondaryTap: onLongPress,
          child: bubbleArea,
        ),
        reactions: message.reactions.isNotEmpty && onReactionTap != null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ReactionRow(
                  reactions: message.reactions,
                  currentUserId: currentUserId,
                  onToggle: onReactionTap!,
                  alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                ),
              )
            : null,
        meta: _MetaRow(
          message: message,
          isMine: isMine,
          seenByOthers: seenByOthers,
        ),
      ),
    );
  }

  Widget _bubbleContent(AppTheme theme, bool isMine,
      {required bool ephemeral,
      required BubbleStyle bubbleStyle,
      ChatMetrics? metrics}) {
    return buildMessageContent(
      theme: theme,
      message: message,
      isMine: isMine,
      ephemeral: ephemeral,
      api: api,
      useHero: useHero,
      metrics: metrics,
      bubbleStyle: bubbleStyle,
      firstInRun: !grouped,
      lastInRun: lastInRun,
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
    this.highlightT = 0,
    this.useHero = true,
    this.showReplyIndicator = true,
    this.seenByOthers = false,
    this.grouped = false,
    this.lastInRun = true,
    this.showAvatarSlot = true,
    this.showAvatar = true,
    this.avatarAtBottom = false,
    this.senderName,
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
  final double highlightT;
  final bool useHero;
  final bool showReplyIndicator;
  final bool seenByOthers;

  /// See [MessageBubble.grouped].
  final bool grouped;

  /// See [MessageBubble.lastInRun].
  final bool lastInRun;

  /// See [MessageBubble.showAvatarSlot].
  final bool showAvatarSlot;

  /// See [MessageBubble.showAvatar].
  final bool showAvatar;

  /// See [MessageBubble.avatarAtBottom].
  final bool avatarAtBottom;

  /// See [MessageBubble.senderName].
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    // See MessageBubble.build — the shape is a preference, so the row rebuilds
    // with it.
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) =>
          _build(context, SettingsStore.instance.bubbleStyle),
    );
  }

  Widget _build(BuildContext context, BubbleStyle bubbleStyle) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;
    final progress = message.lifeProgress(now);
    final dissolving = progress > 0.82;
    final dissolveT = dissolving ? ((progress - 0.82) / 0.18).clamp(0.0, 1.0) : 0.0;
    // See MessageBubble.build — null outside a ChatPane, and every metric
    // then falls back to the literal it replaced.
    final metrics = ChatMetricsScope.maybeOf(context);

    final inner = buildMessageContent(
      theme: theme,
      message: message,
      isMine: isMine,
      ephemeral: true,
      api: api,
      useHero: useHero,
      metrics: metrics,
      bubbleStyle: bubbleStyle,
      firstInRun: !grouped,
      lastInRun: lastInRun,
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

    final maxWidth = metrics?.bubbleMaxWidth ?? messageMaxWidth(context);

    final innerBubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _HighlightPulse(
        t: highlightT,
        shape: pulseShapeFor(
          theme: theme,
          message: message,
          isMine: isMine,
          bubbleStyle: bubbleStyle,
          ephemeral: true,
          firstInRun: !grouped,
          lastInRun: lastInRun,
        ),
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
            parentIsMine:
                message.replyToPreview!.senderId == currentUserId,
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
      padding: EdgeInsets.symmetric(vertical: grouped ? 1 : 6),
      child: Transform.translate(
        offset: Offset(0, -dissolveT * 10),
        child: _BubbleLayout(
          isMine: isMine,
          showAvatarSlot: showAvatarSlot,
          avatarAtBottom: avatarAtBottom,
          senderName: senderName,
          tailGutter: theme.bubbleTailGutter(bubbleStyle),
          nameOpacity: 1 - dissolveT,
          avatar: Opacity(
            opacity: 1 - dissolveT * 0.7,
            child: _AvatarSlot(
              author: author,
              api: api,
              onTap: onAuthorTap,
              collapsed: !showAvatar,
            ),
          ),
          bubble: GestureDetector(
            onLongPress: onLongPress,
            onDoubleTap: onDoubleTap,
            // See MessageBubble above — right-click mirrors long-press.
            onSecondaryTap: onLongPress,
            child: bubbleArea,
          ),
          reactions: message.reactions.isNotEmpty && onReactionTap != null
              ? Opacity(
                  opacity: 1 - dissolveT,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ReactionRow(
                      reactions: message.reactions,
                      currentUserId: currentUserId,
                      onToggle: onReactionTap!,
                      alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                    ),
                  ),
                )
              : null,
          meta: Opacity(
            opacity: 1 - dissolveT,
            child: _MetaRow(
              message: message,
              isMine: isMine,
              countdown: message.timeLeft(now),
              seenByOthers: seenByOthers,
            ),
          ),
        ),
      ),
    );
  }
}

/// The row scaffold both bubble variants share: an optional sender name, the
/// avatar-and-bubble row, then reactions and the meta row.
///
/// Reactions and the meta row deliberately sit OUTSIDE the row rather than in
/// a column beside the avatar. That is what lets [avatarAtBottom] mean the
/// bubble's bottom edge — inside the row, "bottom" would be the bottom of the
/// timestamp, dropping the face a line and a half below the bubble it belongs
/// to. Everything outside the row is instead indented by the avatar's width so
/// it still lines up with the bubble.
class _BubbleLayout extends StatelessWidget {
  const _BubbleLayout({
    required this.isMine,
    required this.showAvatarSlot,
    required this.avatarAtBottom,
    required this.senderName,
    required this.avatar,
    required this.bubble,
    required this.reactions,
    required this.meta,
    this.tailGutter = 0,
    this.nameOpacity = 1,
  });

  final bool isMine;
  final bool showAvatarSlot;
  final bool avatarAtBottom;
  final String? senderName;
  final Widget avatar;
  final Widget bubble;
  final Widget? reactions;
  final Widget meta;

  /// Width of the strip the bubble reserves on the sender's side for its tail.
  /// Everything below the bubble is inset by it so timestamps and reactions
  /// line up with the bubble's *body* edge rather than the tail's tip.
  final double tailGutter;

  final double nameOpacity;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final name = senderName;
    // The avatar column exists only for incoming messages, and only outside a
    // DM. When it does, everything below the bubble row shifts right by the
    // same amount so the whole block reads as one left edge.
    final leads = !isMine && showAvatarSlot;
    final leadingIndent = leads ? _AvatarSlot._size + 8 : 0.0;
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (name != null && name.isNotEmpty)
          Padding(
            // +4 matches _MetaRow's own inset, so the name and the timestamp
            // bracketing the run sit on the same line. The tail gutter joins
            // in for incoming bubbles, where the body starts a hook's width in.
            padding: EdgeInsets.only(
              left: leadingIndent + 4 + (isMine ? 0 : tailGutter),
              bottom: 2,
            ),
            child: Opacity(
              opacity: nameOpacity,
              child: Text(
                name,
                // Deliberately NOT the uppercased monoTiny that reply
                // indicators and the composer card use: those are labels, this
                // is a person. mono has no letter-spacing and enough size to
                // read as a name, and stays clear of the 9px timestamp below.
                style: theme.mono.copyWith(
                  color: theme.accent.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment:
              avatarAtBottom ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (leads) ...[avatar, const SizedBox(width: 8)],
            Flexible(child: bubble),
          ],
        ),
        if (reactions != null)
          Padding(
            padding: EdgeInsets.only(
              left: leadingIndent + (isMine ? 0 : tailGutter),
              right: isMine ? tailGutter : 0,
            ),
            child: reactions,
          ),
        Padding(
          padding: EdgeInsets.only(
            left: leadingIndent + (isMine ? 0 : tailGutter),
            right: isMine ? tailGutter : 0,
          ),
          child: meta,
        ),
      ],
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
  /// Pane geometry, when this bubble is inside a `ChatPane`. Media tiles grow
  /// with the bubble on wide panes; when null (or on a phone, where the
  /// clamps bottom out) every size below is exactly the literal it replaced.
  ChatMetrics? metrics,
  required BubbleStyle bubbleStyle,
  /// Position in the sender's run — drives which corners tighten and which
  /// single bubble carries the tail.
  bool firstInRun = true,
  bool lastInRun = true,
}) {
  final deco = theme.bubbleDecoration(
    isMine: isMine,
    ephemeral: ephemeral,
    style: bubbleStyle,
    firstInRun: firstInRun,
    lastInRun: lastInRun,
  );
  final imageSize = metrics?.mediaMaxWidth ?? ChatMetrics.mediaMin;

  final hasCaption = message.content.isNotEmpty;
  // Media messages render as a rounded media tile WITHOUT a surrounding
  // bubble — alignment in the parent row conveys mine/theirs the way
  // iMessage's photo bubbles do. A bubble frame around a photograph reads
  // as visual noise and clashes with whatever the photo's content is.
  final mediaRadius = BorderRadius.circular(theme.radiusLg);

  switch (message.type) {
    case MessageType.image:
      final id = message.mediaStorageId;
      Widget imageTile;
      if (id != null) {
        imageTile = _ImageTile(
          message: message,
          storageId: id,
          api: api,
          width: imageSize,
          radius: mediaRadius,
          useHero: useHero,
        );
      } else {
        imageTile = Container(
          width: imageSize,
          height: 80,
          decoration: BoxDecoration(
            color: theme.surfaceSunken,
            borderRadius: mediaRadius,
          ),
          alignment: Alignment.center,
          child: Icon(Icons.image_not_supported_outlined, color: theme.inkMuted),
        );
      }
      if (!hasCaption) return imageTile;
      // With a caption: image on top, caption rendered as its own
      // small bubble underneath — same alignment as the row above it.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          imageTile,
          const SizedBox(height: 4),
          Container(
            decoration: deco,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(
              message.content,
              style: theme.body
                  .copyWith(color: isMine ? theme.accentInk : theme.ink),
            ),
          ),
        ],
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
      final videoTile = ClipRRect(
        borderRadius: mediaRadius,
        child: VideoMessage(
          api: api,
          storageId: message.mediaStorageId,
          isMine: isMine,
          maxWidth: metrics?.videoMaxWidth,
        ),
      );
      if (!hasCaption) return videoTile;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          videoTile,
          const SizedBox(height: 4),
          Container(
            decoration: deco,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(
              message.content,
              style: theme.body
                  .copyWith(color: isMine ? theme.accentInk : theme.ink),
            ),
          ),
        ],
      );
    case MessageType.system:
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: deco,
        child: Text(
          message.content,
          style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink),
        ),
      );
    case MessageType.url:
    case MessageType.text:
      return _LinkAwareBubble(
        theme: theme,
        message: message,
        isMine: isMine,
        decoration: deco,
      );
  }
}

/// A photo in the transcript, shown at the picture's own aspect ratio.
///
/// The tile used to be a hard square. That was wrong in two ways at once: a
/// portrait photo was displayed as the middle third of itself, and — because the
/// square box drove a square *decode* — the bitmap was squashed rather than
/// cropped, so it was the middle third of a distorted picture. Worse, the
/// fullscreen viewer showed the real thing, so opening and closing one made the
/// photo change shape twice on the way there and twice on the way back.
///
/// Now the width is fixed and the height follows the ratio, clamped by
/// [ChatMetrics.mediaTileHeight]. Only a picture past the clamp is cropped, and
/// the Hero flight has nothing left to reconcile: both ends show the same
/// picture at the same ratio.
///
/// The ratio is known before the first frame in every case that matters — the
/// message carries it, or [MediaAspectCache] remembers it from the last time
/// this image was on screen. The one case that can't be pre-empted is an image
/// this device has genuinely never seen, sent before senders recorded sizes;
/// that stands on a square for one decode and then settles, once, ever.
class _ImageTile extends StatefulWidget {
  const _ImageTile({
    required this.message,
    required this.storageId,
    required this.api,
    required this.width,
    required this.radius,
    required this.useHero,
  });

  final ChatMessage message;
  final String storageId;
  final ChatApi api;
  final double width;
  final BorderRadius radius;
  final bool useHero;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _aspect = _known();
  }

  @override
  void didUpdateWidget(_ImageTile old) {
    super.didUpdateWidget(old);
    // A recycled row can land on a different photo; the previous one's shape
    // must not survive onto it.
    if (old.storageId != widget.storageId) _aspect = _known();
  }

  double? _known() =>
      widget.message.mediaAspectRatio ??
      MediaAspectCache.instance.peek(widget.storageId);

  /// Measured off the decode that is already on screen. Recorded even when it
  /// matches what we laid out with, so a ratio that only the sender knew is
  /// still there for this device next launch.
  void _onAspect(double aspect) {
    MediaAspectCache.instance.remember(widget.storageId, aspect);
    if (!mounted || _aspect == aspect) return;
    setState(() => _aspect = aspect);
  }

  String get _heroTag => 'msg-image-${widget.message.id}';

  @override
  Widget build(BuildContext context) {
    final height = ChatMetrics.mediaTileHeight(widget.width, _aspect);
    final Widget remote = RemoteImage(
      storageId: widget.storageId,
      api: widget.api,
      width: widget.width,
      height: height,
      borderRadius: widget.radius,
      // Only when there is something to learn. Measuring resolves an image
      // stream per tile, and a transcript full of photos would pay that on every
      // one of them to be told what the sender already said.
      onAspectRatio: _aspect == null ? _onAspect : null,
    );
    return GestureDetector(
      onTap: () => FullscreenImageViewer.open(
        context,
        storageId: widget.storageId,
        api: widget.api,
        heroTag: widget.useHero ? _heroTag : null,
        heroRadius: widget.radius,
        // Hands the viewer the shape to reserve, so the flight lands on a box
        // the picture actually fits rather than a full-screen one that snaps
        // down a frame later.
        aspectRatio: _aspect,
        // The tile's decode is already warm, so the viewer can open on it
        // immediately rather than shimmering while the full-resolution
        // decode lands.
        thumbnailDecodeWidth: thumbnailDecodeWidth(context, widget.width),
      ),
      child: widget.useHero
          ? SteadyHero(tag: _heroTag, child: remote)
          : remote,
    );
  }
}

/// Reserves a fixed 28×28 hit area for the sender avatar so the message
/// row's left edge stays put while `author` resolves asynchronously.
/// Renders the real avatar when the user is known; otherwise an empty
/// box of the same size keeps the geometry stable.
class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({
    required this.author,
    required this.api,
    required this.onTap,
    this.collapsed = false,
  });

  final ChatUser? author;
  final ChatApi api;
  final VoidCallback? onTap;

  /// Renders empty at the same size — every row of a run except the one that
  /// closes it. Repeating the avatar on every bubble is what made five
  /// consecutive messages read as five separate cards.
  final bool collapsed;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final user = author;
    if (collapsed || user == null) {
      return const SizedBox(width: _size, height: _size);
    }
    return GestureDetector(
      onTap: onTap,
      child: UserAvatar(user: user, size: _size, api: api, showStatus: false),
    );
  }
}

/// Bubble body for text/url messages.
///
/// Two visual modes, picked by message content + the user's
/// [SettingsStore.showLinkUrls] preference:
///
///  * **Standalone card** — when the message contains URL(s) but no other
///    text *and* the user keeps URLs hidden (the default). The preview
///    card itself becomes the bubble — no surrounding decoration, no
///    inline URL string. Iconic Apple/iMessage rich-link feel.
///  * **Text + inline previews** — when the message has body copy alongside
///    its URLs, or the user has opted into seeing raw URLs. The text
///    bubble renders normally (with inline links underlined when shown),
///    and previews stack below inside the same bubble shape.
class _LinkAwareBubble extends StatelessWidget {
  const _LinkAwareBubble({
    required this.theme,
    required this.message,
    required this.isMine,
    required this.decoration,
  });

  final AppTheme theme;
  final ChatMessage message;
  final bool isMine;

  /// A `ShapeDecoration` in practice — the tail cannot be expressed by a
  /// `BoxDecoration`. `Container` still clips to it (`getClipPath`) and still
  /// adds its `padding`, which is where the tail's gutter comes from.
  final Decoration decoration;

  static const int _maxPreviews = 2;

  @override
  Widget build(BuildContext context) {
    // Null outside a chat pane, where this falls back to the 320 it used to
    // hard-code.
    final linkWidth =
        ChatMetricsScope.maybeOf(context)?.linkPreviewWidth ??
            ChatMetrics.linkMin;
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final showUrls = SettingsStore.instance.showLinkUrls;
        final urls = UrlDetector.extract(message.content);
        final hasUrls = urls.isNotEmpty;

        // What text do we actually render? When the user has kept URLs
        // hidden, strip them out of the inline body — otherwise mixed
        // messages read with awkward gaps where the URL used to be.
        final displayText = showUrls
            ? message.content
            : _stripUrls(message.content);
        final hasText = displayText.trim().isNotEmpty;

        if (hasUrls && !hasText) {
          // URL-only message, URLs hidden → the preview *is* the bubble.
          // No outer bubble decoration; alignment in the parent row
          // already conveys ownership the way iMessage rich links do.
          //
          // Using a fixed `SizedBox` width (clamped by the outer bubble
          // constraint) keeps the card's width stable while its internal
          // layout swaps between skeleton / hero / compact / bare —
          // otherwise the column would shrink to the narrower bare/compact
          // intrinsic width once the fetch lands, visibly pulling the
          // message left or right depending on alignment. Still fixed —
          // just fixed per pane rather than forever.
          return SizedBox(
            width: linkWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final url in urls.take(_maxPreviews))
                  Padding(
                    padding: EdgeInsets.only(
                      top: url == urls.first ? 0 : 8,
                    ),
                    child: LinkPreviewCard(
                      url: url,
                      isMine: isMine,
                      insideBubble: false,
                      onTap: (u) => LinkOpener.open(context, u),
                    ),
                  ),
              ],
            ),
          );
        }

        // Mixed (text + maybe URLs) — normal bubble with optional inline
        // previews stacked beneath the text.
        final inkColor = isMine ? theme.accentInk : theme.ink;
        final linkAccent = isMine
            ? theme.accentInk
            : (theme.accent.computeLuminance() < 0.2
                ? theme.accent
                : theme.ink);

        return Container(
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          child: Column(
            // Stretch ONLY when there are preview cards to fill the bubble.
            // Unconditionally, it forced every text bubble out to the full
            // maxWidth of its ConstrainedBox — a two-letter "hey" rendered as
            // a full-width bar with a screenful of empty space beside the
            // text. With `start` the bubble hugs its text and the max is what
            // it should always have been: the point where a long message
            // wraps to a second line.
            crossAxisAlignment:
                hasUrls ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 10, 14, hasUrls ? 8 : 10),
                  child: LinkifiedText(
                    text: displayText,
                    style: theme.body.copyWith(color: inkColor),
                    linkStyle: theme.body.copyWith(
                      color: linkAccent,
                      decoration: TextDecoration.underline,
                      decorationColor: linkAccent.withValues(alpha: 0.7),
                    ),
                    onLinkTap: (url) => LinkOpener.open(context, url),
                  ),
                ),
              if (hasUrls)
                for (final url in urls.take(_maxPreviews))
                  LinkPreviewCard(
                    url: url,
                    isMine: isMine,
                    insideBubble: true,
                    onTap: (u) => LinkOpener.open(context, u),
                  ),
            ],
          ),
        );
      },
    );
  }

  /// Removes every URL match from [text] and tidies up the whitespace
  /// left in its wake (collapsing runs of spaces, trimming spaces around
  /// surviving newlines).
  static String _stripUrls(String text) {
    final matches = UrlDetector.matches(text);
    if (matches.isEmpty) return text;
    final buf = StringBuffer();
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) buf.write(text.substring(cursor, m.start));
      cursor = m.end;
    }
    if (cursor < text.length) buf.write(text.substring(cursor));
    return buf
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
  }
}

/// The outline the scroll-to-message halo should trace for [message]: the
/// bubble's own shape, tail and all, or a plain rounded rect for the media
/// types that render frameless.
ShapeBorder pulseShapeFor({
  required AppTheme theme,
  required ChatMessage message,
  required bool isMine,
  required BubbleStyle bubbleStyle,
  bool ephemeral = false,
  bool firstInRun = true,
  bool lastInRun = true,
}) {
  final bare =
      message.type == MessageType.image || message.type == MessageType.video;
  if (bare) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(theme.radiusLg),
    );
  }
  return theme.bubbleShape(
    isMine: isMine,
    ephemeral: ephemeral,
    style: bubbleStyle,
    firstInRun: firstInRun,
    lastInRun: lastInRun,
  );
}

/// One-shot accent halo pulse around a bubble. Drives off a 0..1 progress
/// value (typically a controller in 0..1 over ~1s) and maps it through
/// `sin(t*pi)` so the pulse blooms then settles in a single rise-fall arc.
class _HighlightPulse extends StatelessWidget {
  const _HighlightPulse({
    required this.t,
    required this.shape,
    required this.child,
  });
  final double t;

  /// The bubble's own outline, so the halo and the border pulse hug the tail
  /// instead of cutting across it.
  final ShapeBorder shape;

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
              decoration: ShapeDecoration(
                shape: shape,
                shadows: [
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
            child: CustomPaint(
              painter: _PulseOutline(
                shape: shape,
                color: theme.accent.withValues(alpha: 0.55 * tCurve),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Strokes [shape]'s outline. A `ShapeDecoration` would paint the shape's own
/// [BorderSide] — which is the theme's hairline, not this pulse — so the
/// highlight draws its own stroke over the same path.
class _PulseOutline extends CustomPainter {
  const _PulseOutline({required this.shape, required this.color});

  final ShapeBorder shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      shape.getOuterPath(Offset.zero & size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_PulseOutline old) =>
      old.shape != shape || old.color != color;
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
