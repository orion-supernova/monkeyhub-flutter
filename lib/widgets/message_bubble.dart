import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
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
import 'message_stamp.dart';
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
    this.onReactionLongPress,
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
    this.onOpenViewOnce,
  });

  /// Spends this viewer's one look at a view-once photo and shows it. Null
  /// leaves the sealed tile inert.
  final Future<void> Function()? onOpenViewOnce;

  final ChatMessage message;
  final DateTime now;
  final String currentUserId;
  final ChatApi api;
  final ChatUser? author;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final void Function(String emoji)? onReactionTap;

  /// Long-press a reaction chip to see who is behind that emoji.
  final void Function(String emoji)? onReactionLongPress;

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
      // Top only — see [MessageGap]. A row owning half its gap at each end makes
      // the space between two rows depend on which two rows they are.
      padding: EdgeInsets.only(
          top: grouped ? MessageGap.withinRun : MessageGap.betweenRuns),
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
                  onShowReactors: onReactionLongPress,
                  alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                ),
              )
            : null,
        meta: messageStampsInline(message,
                showLinkUrls: SettingsStore.instance.showLinkUrls)
            ? null
            : _MetaRow(
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
      seenByOthers: seenByOthers,
      onOpenViewOnce: onOpenViewOnce,
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
    this.onReactionLongPress,
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
    this.onOpenViewOnce,
  });

  /// Spends this viewer's one look at a view-once photo and shows it. Null
  /// leaves the sealed tile inert.
  final Future<void> Function()? onOpenViewOnce;

  final ChatMessage message;
  final DateTime now;
  final String currentUserId;
  final ChatApi api;
  final ChatUser? author;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final void Function(String emoji)? onReactionTap;

  /// Long-press a reaction chip to see who is behind that emoji.
  final void Function(String emoji)? onReactionLongPress;

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
      countdown: message.timeLeft(now),
      seenByOthers: seenByOthers,
      onOpenViewOnce: onOpenViewOnce,
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
      // Top only — see [MessageGap]. A row owning half its gap at each end makes
      // the space between two rows depend on which two rows they are.
      padding: EdgeInsets.only(
          top: grouped ? MessageGap.withinRun : MessageGap.betweenRuns),
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
                      onShowReactors: onReactionLongPress,
                      alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                    ),
                  ),
                )
              : null,
          // Only the fallback row needs its own dissolve fade — a stamp inside
          // the bubble is already carried by the bubble's own blur and opacity.
          meta: messageStampsInline(message,
                  showLinkUrls: SettingsStore.instance.showLinkUrls)
              ? null
              : Opacity(
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

  /// The external timestamp row — null for every message that carries its stamp
  /// inside its own bubble, which is nearly all of them. Still `required` in the
  /// constructor so both call sites have to state which it is: a missing
  /// timestamp should never be an omission.
  final Widget? meta;

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
        if (meta != null)
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

/// Whether [message] renders a surface that can host its own timestamp: a text
/// or caption block to tuck it into, or a media tile to lay it over.
///
/// Two shapes cannot. A URL-only message with URLs hidden *is* a link preview
/// card — there is no bubble around it and nothing of ours inside it — and a
/// photo whose storage id never arrived is a bare error plate. Both keep the
/// external row they always had, which is why `_BubbleLayout.meta` is nullable
/// rather than gone.
bool messageStampsInline(ChatMessage message, {required bool showLinkUrls}) {
  switch (message.type) {
    case MessageType.image:
      // `viewOnce` is its own clause because a sealed photo never carries a
      // storage id — the server strips it — and would otherwise be pushed out
      // to an external timestamp row it has plenty of room to host itself.
      return message.content.isNotEmpty ||
          message.mediaStorageId != null ||
          message.viewOnce;
    case MessageType.video:
    case MessageType.audio:
    case MessageType.system:
      return true;
    case MessageType.text:
    case MessageType.url:
      return !_isStandaloneLinkCard(message, showLinkUrls);
  }
}

/// Exactly the condition [_LinkAwareBubble] picks its card-only mode on
/// (`hasUrls && !hasText`). One reading of it, so the bubble and the row beneath
/// it can never disagree about which of them owns the timestamp.
bool _isStandaloneLinkCard(ChatMessage message, bool showLinkUrls) {
  if (showLinkUrls) return false;
  if (UrlDetector.extract(message.content).isEmpty) return false;
  return _LinkAwareBubble._stripUrls(message.content).trim().isEmpty;
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

  /// Remaining life of an ephemeral message, for the stamp's countdown. Null on
  /// everything else.
  Duration? countdown,

  /// Whether anyone else has read this yet. Drives the stamp's read receipt.
  bool seenByOthers = false,

  /// Spends this viewer's one look at a view-once photo and shows it. Null
  /// where no repository is wired up (tests, previews), which leaves the sealed
  /// tile inert rather than half-working.
  Future<void> Function()? onOpenViewOnce,
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

  // Reading SettingsStore here is reactive: both bubble variants already wrap
  // their whole row in an AnimatedBuilder on it, for the bubble-shape
  // preference.
  final inline = messageStampsInline(
    message,
    showLinkUrls: SettingsStore.instance.showLinkUrls,
  );
  MessageStamp? stampFor(StampTone tone) => inline
      ? MessageStamp(
          createdAt: message.createdAt,
          status: message.status,
          countdown: countdown,
          showSeen: isMine && seenByOthers,
          tone: tone,
        )
      : null;
  // Every branch that draws its own ink already maps mine→accentInk and
  // theirs→ink; the stamp reads the same mapping, so it can never end up
  // accent-on-accent.
  final bubbleTone = isMine ? StampTone.onAccent : StampTone.onBubble;

  switch (message.type) {
    case MessageType.image:
      final id = message.mediaStorageId;
      Widget imageTile;
      // Checked BEFORE the storage-id branch on purpose. A view-once message
      // never carries a storage id — the server strips it from every read path
      // — so falling through would render the "broken image" placeholder, and
      // more importantly would put a `RemoteImage` (and its persistent disk
      // cache) anywhere near a photo that is supposed to leave no trace.
      if (message.viewOnce) {
        imageTile = _ViewOnceTile(
          theme: theme,
          message: message,
          isMine: isMine,
          width: imageSize,
          radius: mediaRadius,
          // `onBubble`, not `onMedia`: the sealed tile is a theme surface, so
          // the dark lozenge `onMedia` wraps itself in — which exists to survive
          // a photograph whose colour no theme knows — would be a black nub
          // floating on a themed card.
          stamp: hasCaption ? null : stampFor(StampTone.onBubble),
          onOpen: onOpenViewOnce,
        );
      } else if (id != null) {
        imageTile = _ImageTile(
          message: message,
          storageId: id,
          api: api,
          width: imageSize,
          radius: mediaRadius,
          useHero: useHero,
          // With a caption the stamp belongs to the caption bubble, not to the
          // photograph.
          stamp: hasCaption ? null : stampFor(StampTone.onMedia),
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
            child: _captionBody(theme, message.content, isMine,
                stamp: stampFor(bubbleTone)),
          ),
        ],
      );
    case MessageType.audio:
      final player = AudioMessage(
        api: api,
        storageId: message.mediaStorageId,
        isMine: isMine,
      );
      final audioStamp = stampFor(bubbleTone);
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: deco,
        child: audioStamp == null
            ? player
            : Row(
                mainAxisSize: MainAxisSize.min,
                // Lands on the same line as the player's own duration readout
                // rather than starting a second row of tiny type — the 34pt
                // play button sets the height, so this costs nothing.
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  player,
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: audioStamp,
                  ),
                ],
              ),
      );
    case MessageType.video:
      final videoTile = StampedMedia(
        tile: ClipRRect(
          borderRadius: mediaRadius,
          child: VideoMessage(
            api: api,
            storageId: message.mediaStorageId,
            isMine: isMine,
            maxWidth: metrics?.videoMaxWidth,
          ),
        ),
        stamp: hasCaption ? null : stampFor(StampTone.onMedia),
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
            child: _captionBody(theme, message.content, isMine,
                stamp: stampFor(bubbleTone)),
          ),
        ],
      );
    case MessageType.system:
      return Container(
        decoration: deco,
        child: _captionBody(theme, message.content, isMine,
            stamp: stampFor(bubbleTone)),
      );
    case MessageType.url:
    case MessageType.text:
      return _LinkAwareBubble(
        theme: theme,
        message: message,
        isMine: isMine,
        decoration: deco,
        stamp: stampFor(bubbleTone),
      );
  }
}

/// A padded run of plain bubble text — an image or video caption, or a system
/// notice — stamped when [stamp] is non-null.
///
/// The padding moves off the enclosing `Container` and in here, because the
/// stamp's `Positioned` has to live *inside* the padded box to measure from the
/// text's edge rather than the bubble's.
Widget _captionBody(
  AppTheme theme,
  String text,
  bool isMine, {
  required MessageStamp? stamp,
}) {
  const pad = EdgeInsets.fromLTRB(14, 10, 14, 10);
  final style = theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink);
  if (stamp == null) {
    return Padding(padding: pad, child: Text(text, style: style));
  }
  return StampedTextBlock(
    stamp: stamp,
    padding: pad,
    child: Text.rich(TextSpan(
      // trimRight so a caption ending in a newline doesn't push the stamp onto
      // a line of its own.
      text: text.trimRight(),
      children: [stampSpacerSpan(stamp)],
      style: style,
    )),
  );
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
/// The sealed bubble for a burn-after-reading photo.
///
/// It never shows the picture, and it never can: the server does not send the
/// storage id, so there is nothing here to render even accidentally. The bytes
/// arrive only through [ViewOnceViewer], into memory, once.
///
/// Fixed size, deliberately. Dropping `mediaWidth`/`mediaHeight` on an armed
/// send (they would leak the photo's true shape) removes exactly what
/// [ChatMetrics.mediaTileHeight] and `MediaAspectCache` exist to supply, so a
/// constant is the only way to avoid the one-frame resize those were built to
/// prevent — and it keeps all three states on one silhouette, so the transcript
/// never jumps when a bubble goes from sealed to opened to ghost.
///
/// Square, and smaller than a real photo tile. A wide short bar reads as a file
/// attachment; a square in the media slot reads as a picture — which is what
/// this is, minus the picture. It carries its own timestamp (see
/// [messageStampsInline]) rather than paying for a second row underneath.
class _ViewOnceTile extends StatefulWidget {
  const _ViewOnceTile({
    required this.theme,
    required this.message,
    required this.isMine,
    required this.width,
    required this.radius,
    required this.stamp,
    required this.onOpen,
  });

  /// Fixed geometry, one number: the tile is square at every size.
  static const double tileSize = 152;

  /// The seal's box. The numeral inside it is the same one the camera editor's
  /// arm control and the fullscreen viewer's badge draw.
  static const double _sealSize = 44;

  final AppTheme theme;
  final ChatMessage message;
  final bool isMine;
  final double width;
  final BorderRadius radius;
  final MessageStamp? stamp;
  final Future<void> Function()? onOpen;

  @override
  State<_ViewOnceTile> createState() => _ViewOnceTileState();
}

class _ViewOnceTileState extends State<_ViewOnceTile> {
  bool _busy = false;

  bool get _openable =>
      widget.onOpen != null &&
      !_busy &&
      widget.message.viewOnceOpenable(isMine: widget.isMine);

  Future<void> _open() async {
    if (!_openable) return;
    setState(() => _busy = true);
    try {
      await widget.onOpen!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The one line under the title. Distinguishes "you had your look" from
  /// "nobody gets one any more", because those are different facts and the user
  /// can act on the difference (ask for it again vs. it's simply over).
  String get _caption {
    final m = widget.message;
    if (m.viewOnceBurned) {
      return m.viewOnceOpened || widget.isMine ? 'opened' : 'expired';
    }
    if (m.viewOnceOpened) return 'opened';
    if (widget.isMine) return 'view once';
    return 'tap to view';
  }

  bool get _spent =>
      widget.message.viewOnceBurned ||
      widget.message.viewOnceOpened ||
      widget.isMine;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    // Square at every size: a narrow pane shrinks the tile rather than
    // squashing it into the bar it used to be.
    final s = math.min(widget.width, _ViewOnceTile.tileSize);
    // Live and spent differ in weight, not in shape.
    final ink = _spent ? t.inkMuted : t.ink;
    final seal = _spent ? t.inkMuted : t.accent;
    // Raised while there is still something to open, sunken once there isn't —
    // a spent photo is a hole in the transcript, a sealed one is an object.
    final base = _spent ? t.surfaceSunken : t.surfaceRaised;

    final tile = Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        // Blended into the gradient's stops rather than passed as `color`:
        // `BoxDecoration` paints a gradient *instead of* a colour, so setting
        // both silently drops the surface and washes the tile out.
        color: _spent ? base : null,
        gradient: _spent
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(t.accent.withValues(alpha: 0.10), base),
                  Color.alphaBlend(t.accent.withValues(alpha: 0.02), base),
                ],
              ),
        borderRadius: widget.radius,
        border: Border.all(
          color: _spent ? t.divider : t.accent.withValues(alpha: 0.35),
        ),
        // One soft accent-tinted lift, and only while the photo is still there
        // to be had. Nothing about a spent tile should catch the eye.
        boxShadow: _spent
            ? null
            : [
                BoxShadow(
                  color: t.accent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      // No padding here: the stamp below measures from the tile's true edges,
      // and a Container pad would push it inwards by that much again.
      child: Stack(
        children: [
          Positioned.fill(
            // The deep bottom pad reserves the stamp's strip, so the centred
            // block sits clear of it rather than overlapping it. `Positioned`
            // rather than a plain child because a Stack lays its non-positioned
            // children out *loose* — a bare Center would shrink-wrap the column
            // and park it in the top-left corner.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 26),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _ViewOnceTile._sealSize,
                      height: _ViewOnceTile._sealSize,
                      child: _busy
                          ? Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(t.accent),
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: _ViewOnceSealPainter(
                                color: seal,
                                struck: _spent,
                              ),
                              child: Center(
                                child: Text(
                                  '1',
                                  style: TextStyle(
                                    color: seal,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Photo',
                      style: t.label.copyWith(color: ink, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _caption,
                      style: t.monoTiny.copyWith(
                        color: _spent ? t.inkMuted : t.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.stamp != null)
            Positioned.directional(
              textDirection: Directionality.of(context),
              // Wider than `StampedMedia`'s 8: that inset is tuned for a fully
              // rounded lozenge, and this stamp is bare text, which needs more
              // clearance from a large corner radius to look inset at all.
              end: 12,
              bottom: 10,
              // A timestamp is not a tap target; the tile owns the tap.
              child: KeyedSubtree(
                key: kVisibleStampKey,
                child: IgnorePointer(child: widget.stamp!),
              ),
            ),
        ],
      ),
    );

    if (!_openable) return tile;
    return FocusableTap(
      onTap: _open,
      semanticLabel: 'view once photo, tap to view',
      radius: widget.radius.topLeft.x,
      child: GestureDetector(
        onTap: _open,
        behavior: HitTestBehavior.opaque,
        child: tile,
      ),
    );
  }
}

/// The seal: a ring around the "1", filled while the photo can still be opened
/// and struck through once it can't.
class _ViewOnceSealPainter extends CustomPainter {
  const _ViewOnceSealPainter({required this.color, required this.struck});

  final Color color;
  final bool struck;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 1;
    if (!struck) {
      // A disc behind the numeral, so a live seal reads as a wax stamp rather
      // than an outline waiting to be filled in.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
          ..color = color.withValues(alpha: 0.12),
      );
    }
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true
      ..color = color;
    canvas.drawCircle(c, r, p);
    if (!struck) return;
    // Trailing-to-leading slash, the same direction a "no" symbol reads. Held
    // back from full strength: spent is a state, not an error.
    final d = r * 0.72;
    canvas.drawLine(
      Offset(c.dx - d, c.dy + d),
      Offset(c.dx + d, c.dy - d),
      p
        ..strokeWidth = 1.3
        ..color = color.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_ViewOnceSealPainter old) =>
      old.color != color || old.struck != struck;
}

class _ImageTile extends StatefulWidget {
  const _ImageTile({
    required this.message,
    required this.storageId,
    required this.api,
    required this.width,
    required this.radius,
    required this.useHero,
    required this.stamp,
  });

  final ChatMessage message;
  final String storageId;
  final ChatApi api;
  final double width;
  final BorderRadius radius;
  final bool useHero;

  /// Laid over the picture's bottom-trailing corner. Null when the message has
  /// a caption to carry the stamp instead.
  final MessageStamp? stamp;

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  double? _aspect;

  /// True for the length of the fullscreen round trip. The stamp is a sibling
  /// of the hero rather than part of it, so without this it would hover over
  /// the empty slot the photo leaves behind while it is away.
  bool _viewing = false;

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

  Future<void> _openViewer() async {
    setState(() => _viewing = true);
    try {
      await FullscreenImageViewer.open(
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
        // immediately rather than shimmering while the full-resolution decode
        // lands.
        thumbnailDecodeWidth: thumbnailDecodeWidth(context, widget.width),
      );
    } finally {
      if (mounted) setState(() => _viewing = false);
    }
  }

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
      onTap: _openViewer,
      child: StampedMedia(
        tile: widget.useHero
            ? SteadyHero(tag: _heroTag, child: remote)
            : remote,
        stamp: _viewing ? null : widget.stamp,
      ),
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
    required this.stamp,
  });

  final AppTheme theme;
  final ChatMessage message;
  final bool isMine;

  /// Tucked into the text block's bottom-trailing corner. Null for the
  /// card-only mode below, which has no bubble of its own — see
  /// [messageStampsInline], which reads the same condition so the external row
  /// takes over for exactly those messages.
  final MessageStamp? stamp;

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

        final stamp = this.stamp;
        final textPad = EdgeInsets.fromLTRB(14, 10, 14, hasUrls ? 8 : 10);
        final body = LinkifiedText(
          // Trailing whitespace would push the stamp onto a line of its own.
          text: displayText.trimRight(),
          style: theme.body.copyWith(color: inkColor),
          linkStyle: theme.body.copyWith(
            color: linkAccent,
            decoration: TextDecoration.underline,
            decorationColor: linkAccent.withValues(alpha: 0.7),
          ),
          onLinkTap: (url) => LinkOpener.open(context, url),
          trailing: stamp == null ? null : stampSpacerSpan(stamp),
        );

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
            // wraps to a second line. The stamp lives INSIDE the text block
            // precisely so it cannot break that — the Stack hugs the
            // paragraph, and the paragraph now includes the room the stamp
            // needs.
            crossAxisAlignment:
                hasUrls ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                if (stamp == null)
                  Padding(padding: textPad, child: body)
                else
                  StampedTextBlock(
                      stamp: stamp, padding: textPad, child: body),
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

/// The external timestamp row, kept for the two message shapes that have no
/// bubble of their own to sit in — see [messageStampsInline]. Same cluster the
/// bubbles use inside themselves; only the tone and the surrounding padding
/// differ.
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The +4 is mirrored by _BubbleLayout's sender-name inset, so the name
      // opening a run and the timestamp closing it sit on the same left edge.
      padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
      child: MessageStamp(
        key: kVisibleStampKey,
        createdAt: message.createdAt,
        status: message.status,
        countdown: countdown,
        showSeen: isMine && seenByOthers,
        tone: StampTone.onSurface,
      ),
    );
  }
}
