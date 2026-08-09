import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/pending_upload.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../media/media_aspect_cache.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';
import '../theme/interaction.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../screens/fullscreen_image_viewer.dart';
import '../screens/fullscreen_video_viewer.dart';
import '../services/link_opener.dart';
import 'audio_message.dart';
import 'file_message.dart';
import 'link_preview_card.dart';
import 'linkified_text.dart';
import 'location_bubble.dart';
import 'message_stamp.dart';
import 'photo_chrome.dart';
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
    this.onMentionTap,
    this.onReplyIndicatorTap,
    this.onViewThread,
    this.parentAuthor,
    this.highlightT = 0,
    this.useHero = true,
    this.replyMarker = ReplyMarker.full,
    this.seenByOthers = false,
    this.deliveredToOthers = false,
    this.grouped = false,
    this.lastInRun = true,
    this.showAvatarSlot = true,
    this.showAvatar = true,
    this.avatarAtBottom = false,
    this.senderName,
    this.onOpenViewOnce,
    this.onStopLiveShare,
    this.publishingLiveShare = false,
    this.onRetrySend,
    this.onDiscardSend,
    this.bubbleKey,
  });

  /// Spends this viewer's one look at a view-once photo and shows it. Null
  /// leaves the sealed tile inert.
  final Future<void> Function()? onOpenViewOnce;

  /// Ends a running live-location share. Null on everything except the sender's
  /// own live share, which is what makes the bubble draw STOP at all.
  final Future<void> Function()? onStopLiveShare;

  /// Whether THIS device is the one publishing that share. False on the
  /// sender's second device, which can see its own share running but is not
  /// what is feeding it.
  final bool publishingLiveShare;

  /// Re-run or throw away a send that failed. Null on everything except the
  /// sender's own failed attachment, which is what makes the tile draw the pair.
  final Future<void> Function()? onRetrySend;
  final VoidCallback? onDiscardSend;

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

  /// Goes on the speech bubble alone — not the full-width row it sits in, and
  /// not the reply tether above it. A caller that has to tell "on the message"
  /// from "in the space beside it" measures this; the row spans the window
  /// however narrow the bubble is, and the tether is regularly wider than the
  /// message hanging off it, so neither can answer that. The thread overlay's
  /// tap-to-dismiss is the one caller that needs it.
  final GlobalKey? bubbleKey;

  /// Invoked when the user taps an @-mention. Receives the mentioned user's id
  /// so the screen can open their profile. Null leaves mentions highlighted
  /// but inert.
  final void Function(String userId)? onMentionTap;

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

  /// How much of the quoted parent to draw above the bubble — the full card,
  /// a one-line [ReplyMarkerLine], or nothing. Transcripts pass what
  /// `buildRoomItems` decided; the default draws the full card so a bubble
  /// rendered standalone still shows its context.
  ///
  /// [ReplyMarker.none] is for previews and chrome that want a bare bubble.
  /// It is not a way to make a reply look like a plain message: a lifted
  /// preview passing it disagrees with the row it lifted off, which is both a
  /// visual lie and, since the action menu force-sizes the preview into the
  /// measured rect, an overflow.
  final ReplyMarker replyMarker;

  final bool seenByOthers;

  /// Whether anyone else's device is known to hold this yet — the second
  /// tick, below [seenByOthers] on the same ladder. See [MessageReceipt].
  final bool deliveredToOthers;

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
        child: _bubbleContent(context, theme, isMine,
            ephemeral: false, metrics: metrics, bubbleStyle: bubbleStyle),
      ),
    );

    // Keyed around the bubble alone, never around the reply marker above it:
    // a tether is regularly wider than the short message hanging off it, and a
    // caller measuring "is this point on the message" would inherit that width
    // as an invisible dead strip beside the bubble. Nothing is lost — the
    // tether takes its own taps, so they never reach the caller either way.
    final keyed = bubbleKey == null
        ? bubble
        : KeyedSubtree(key: bubbleKey!, child: bubble);

    // `isReply` is the veto: a marker can only draw when there is a preview to
    // draw it from, and that is exactly what `isReply` asserts.
    final marker = message.isReply ? replyMarker : ReplyMarker.none;
    final Widget bubbleArea;
    if (marker == ReplyMarker.none) {
      bubbleArea = keyed;
    } else {
      bubbleArea = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (marker == ReplyMarker.compact)
            ReplyTether(
              preview: message.replyToPreview!,
              isMine: isMine,
              parentIsMine:
                  message.replyToPreview!.senderId == currentUserId,
              parentGutter: showAvatarSlot ? _AvatarSlot._size + 8 : 0,
              onTap: () {
                final id = message.replyToId;
                if (id != null) onReplyIndicatorTap?.call(id);
              },
              onViewThread: onViewThread,
            )
          else
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
          keyed,
        ],
      );
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
        bubble: _BubbleGestureDetector(
          onLongPress: onLongPress,
          onDoubleTap: onDoubleTap,
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
                deliveredToOthers: deliveredToOthers,
              ),
      ),
    );
  }

  Widget _bubbleContent(BuildContext context, AppTheme theme, bool isMine,
      {required bool ephemeral,
      required BubbleStyle bubbleStyle,
      ChatMetrics? metrics}) {
    return buildMessageContent(
      context: context,
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
      deliveredToOthers: deliveredToOthers,
      onOpenViewOnce: onOpenViewOnce,
      onStopLiveShare: onStopLiveShare,
      publishingLiveShare: publishingLiveShare,
      onRetrySend: onRetrySend,
      onDiscardSend: onDiscardSend,
      currentUserId: currentUserId,
      onMentionTap: onMentionTap,
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
    this.onMentionTap,
    this.onReplyIndicatorTap,
    this.onViewThread,
    this.parentAuthor,
    this.highlightT = 0,
    this.useHero = true,
    this.replyMarker = ReplyMarker.full,
    this.seenByOthers = false,
    this.deliveredToOthers = false,
    this.grouped = false,
    this.lastInRun = true,
    this.showAvatarSlot = true,
    this.showAvatar = true,
    this.avatarAtBottom = false,
    this.senderName,
    this.onOpenViewOnce,
    this.onStopLiveShare,
    this.publishingLiveShare = false,
    this.onRetrySend,
    this.onDiscardSend,
    this.bubbleKey,
  });

  /// Spends this viewer's one look at a view-once photo and shows it. Null
  /// leaves the sealed tile inert.
  final Future<void> Function()? onOpenViewOnce;

  /// Ends a running live-location share. Null on everything except the sender's
  /// own live share, which is what makes the bubble draw STOP at all.
  final Future<void> Function()? onStopLiveShare;

  /// Whether THIS device is the one publishing that share. False on the
  /// sender's second device, which can see its own share running but is not
  /// what is feeding it.
  final bool publishingLiveShare;

  /// Re-run or throw away a send that failed. Null on everything except the
  /// sender's own failed attachment, which is what makes the tile draw the pair.
  final Future<void> Function()? onRetrySend;
  final VoidCallback? onDiscardSend;

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

  /// See [MessageBubble.bubbleKey].
  final GlobalKey? bubbleKey;

  /// See [MessageBubble.onMentionTap].
  final void Function(String userId)? onMentionTap;
  final void Function(String parentId)? onReplyIndicatorTap;
  final VoidCallback? onViewThread;
  final ChatUser? parentAuthor;
  final double highlightT;
  final bool useHero;

  /// See [MessageBubble.replyMarker].
  final ReplyMarker replyMarker;

  final bool seenByOthers;

  /// Whether anyone else's device is known to hold this yet — the second
  /// tick, below [seenByOthers] on the same ladder. See [MessageReceipt].
  final bool deliveredToOthers;

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
      context: context,
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
      deliveredToOthers: deliveredToOthers,
      onOpenViewOnce: onOpenViewOnce,
      onStopLiveShare: onStopLiveShare,
      publishingLiveShare: publishingLiveShare,
      onRetrySend: onRetrySend,
      onDiscardSend: onDiscardSend,
      currentUserId: currentUserId,
      onMentionTap: onMentionTap,
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

    // See the twin in [MessageBubble] — the bubble alone, not the marker.
    final keyed = bubbleKey == null
        ? innerBubble
        : KeyedSubtree(key: bubbleKey!, child: innerBubble);

    // See the twin in [MessageBubble] — same rule, same veto.
    final marker = message.isReply ? replyMarker : ReplyMarker.none;
    final Widget bubbleArea;
    if (marker == ReplyMarker.none) {
      bubbleArea = keyed;
    } else {
      bubbleArea = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Marker sits OUTSIDE the dissolve effect — its own identity,
          // its own fade if we add one later.
          if (marker == ReplyMarker.compact)
            ReplyTether(
              preview: message.replyToPreview!,
              isMine: isMine,
              parentIsMine:
                  message.replyToPreview!.senderId == currentUserId,
              parentGutter: showAvatarSlot ? _AvatarSlot._size + 8 : 0,
              onTap: () {
                final id = message.replyToId;
                if (id != null) onReplyIndicatorTap?.call(id);
              },
              onViewThread: onViewThread,
            )
          else
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
          keyed,
        ],
      );
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
          bubble: _BubbleGestureDetector(
            onLongPress: onLongPress,
            onDoubleTap: onDoubleTap,
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
                    deliveredToOthers: deliveredToOthers,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Long-press-for-reactions, double-tap, and right-click-mirrors-long-press
/// on a single [child], with an explicit long-press duration. Plain
/// [GestureDetector] has no hook for that duration, so this goes straight to
/// the recognizers — see [_HorizontalRightDragRecognizer] in swipe_to_reply.dart
/// for the same pattern.
class _BubbleGestureDetector extends StatelessWidget {
  const _BubbleGestureDetector({
    required this.child,
    this.onLongPress,
    this.onDoubleTap,
  });

  final Widget child;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: kActionMenuLongPress),
          (instance) => instance.onLongPress = onLongPress,
        ),
        if (onDoubleTap != null)
          DoubleTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
            () => DoubleTapGestureRecognizer(),
            (instance) => instance.onDoubleTap = onDoubleTap,
          ),
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          // Desktop/trackpad right-click opens the same action menu, anchored
          // to the same bubble rect. No platform gate needed — touch devices
          // never produce a secondary tap.
          (instance) => instance.onSecondaryTap = onLongPress,
        ),
      },
      child: child,
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
      //
      // `upload` is its own clause for the same reason and a sharper symptom: an
      // outgoing photo has no storage id until its bytes land, so a captionless
      // one would start life with an external timestamp row, then have the row
      // taken away the instant the upload finished. The bubble grew a line and
      // then lost it, while the user watched.
      return message.content.isNotEmpty ||
          message.mediaStorageId != null ||
          message.viewOnce ||
          message.upload != null;
    case MessageType.video:
    case MessageType.audio:
    // A document tile is a row of chrome with a name in it — there is always
    // somewhere to tuck a timestamp, with or without a caption, and unlike the
    // image case it never depends on a storage id arriving.
    case MessageType.file:
    case MessageType.system:
      return true;
    // A location card is a filled rectangle with a stamp-sized corner to spare,
    // exactly like a media tile — with one exception. A share with no
    // coordinates renders as a bare error plate with no room in it, which is the
    // same shape as an image whose storage id never arrived, and takes the same
    // answer: keep the external row.
    case MessageType.location:
    case MessageType.liveLocation:
      return message.locationShare != null;
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
  required BuildContext context,
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

  /// Whether anyone else has read this yet. The top of the stamp's tick
  /// ladder — see [MessageReceipt].
  bool seenByOthers = false,

  /// Whether anyone else's device is known to hold this yet. The rung below
  /// [seenByOthers]; a message that is neither draws a single tick.
  bool deliveredToOthers = false,

  /// Spends this viewer's one look at a view-once photo and shows it. Null
  /// where no repository is wired up (tests, previews), which leaves the sealed
  /// tile inert rather than half-working.
  Future<void> Function()? onOpenViewOnce,

  /// Ends a running live-location share, and whether this device is the one
  /// publishing it. Threaded exactly like [onOpenViewOnce]: null leaves the
  /// bubble showing the share without offering to stop it, which is the right
  /// state for a recipient and for a preview with no repository behind it.
  Future<void> Function()? onStopLiveShare,
  bool publishingLiveShare = false,

  /// Re-run a send that failed, and throw one away. Threaded the same way
  /// [onOpenViewOnce] is, and null everywhere except a failed outgoing
  /// attachment — the tile draws the pair only when it is handed them, so a
  /// bubble that isn't failed cannot offer a retry.
  ///
  /// They live on the tile rather than in the action menu because an optimistic
  /// bubble has no action menu: the row passes `onLongPress: null` while a
  /// message is unconfirmed.
  Future<void> Function()? onRetrySend,
  VoidCallback? onDiscardSend,

  /// The reader, so a mention OF THEM can be drawn louder than a mention of
  /// anyone else. Null leaves every mention styled the same, which is the right
  /// fallback for previews and chrome that have no viewer.
  String? currentUserId,

  /// Opens a mentioned user's profile. Null leaves mentions highlighted but
  /// inert — the same treatment [onOpenViewOnce] gets where no repository is
  /// wired up.
  void Function(String userId)? onMentionTap,
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
          receipt: messageReceipt(
            isMine: isMine,
            deliveredToOthers: deliveredToOthers,
            seenByOthers: seenByOthers,
          ),
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
          onRetrySend: onRetrySend,
          onDiscardSend: onDiscardSend,
        );
      } else if (message.upload != null) {
        // Ahead of the storage-id branch deliberately. For a moment after the
        // upload succeeds the message has both a storage id and its bytes, and we
        // would rather keep painting the pixels already in memory than resolve a
        // URL and download back a picture we just finished sending.
        imageTile = _UploadingImageTile(
          theme: theme,
          message: message,
          upload: message.upload!,
          width: imageSize,
          radius: mediaRadius,
          stamp: hasCaption ? null : stampFor(StampTone.onMedia),
          onRetrySend: onRetrySend,
          onDiscardSend: onDiscardSend,
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
                stamp: stampFor(bubbleTone),
                mentionHandles: message.mentionHandles,
                mentionsEveryone: message.mentionsEveryone,
                currentUserId: currentUserId,
                onMentionTap: onMentionTap),
          ),
        ],
      );
    case MessageType.audio:
      // A voice note on its way up has no storage id, and `AudioMessage` renders
      // a null one as the literal text "[audio missing]" — which is true of a
      // broken message and alarmingly false of one that is uploading fine.
      final audioUpload = message.upload;
      final Widget player = audioUpload != null
          ? _OutboundAudioRow(
              theme: theme,
              upload: audioUpload,
              isMine: isMine,
              failed: message.status == MessageStatus.error,
              onRetry: onRetrySend,
              onDiscard: onDiscardSend,
            )
          : AudioMessage(
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
                  // Flexible, not bare: a `Row` hands a non-flex child
                  // UNBOUNDED width, so the player would take its natural size
                  // and push the stamp past the bubble's edge on a narrow
                  // phone. Loose fit, so a short player still hugs.
                  Flexible(child: player),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: KeyedSubtree(
                      key: kVisibleStampKey,
                      child: audioStamp,
                    ),
                  ),
                ],
              ),
      );
    case MessageType.video:
      final videoUpload = message.upload;
      final videoStorageId = message.mediaStorageId;
      // Matches the photo bubble's `msg-image-<id>`, and deliberately a
      // different string: a video and a photo are never the same message, but
      // the shared-content grid also flies these ids under its own prefix and
      // two heroes sharing a tag across routes that both join a flight is an
      // assertion rather than a graceful degrade.
      final videoHeroTag = useHero ? 'msg-video-${message.id}' : null;
      final videoTile = StampedMedia(
        tile: ClipRRect(
          borderRadius: mediaRadius,
          // Same reasoning as the audio row above: with no storage id there is
          // nothing for `VideoMessage` to resolve, so it would sit on its own
          // loading state forever. A placeholder at the tile's own size holds the
          // geometry the finished video will take, so the transcript doesn't jump
          // when the upload lands.
          child: videoUpload != null
              ? _OutboundVideoTile(
                  theme: theme,
                  upload: videoUpload,
                  failed: message.status == MessageStatus.error,
                  width: metrics?.videoMaxWidth ?? imageSize,
                  onRetry: onRetrySend,
                  onDiscard: onDiscardSend,
                )
              : VideoMessage(
                  api: api,
                  storageId: videoStorageId,
                  isMine: isMine,
                  posterStorageId: message.posterStorageId,
                  mediaAspectRatio: message.mediaAspectRatio,
                  durationMs: message.mediaDurationMs,
                  maxWidth: metrics?.videoMaxWidth,
                  heroTag: videoHeroTag,
                  onOpen: videoStorageId == null
                      ? null
                      : () => FullscreenVideoViewer.open(
                            context,
                            storageId: videoStorageId,
                            api: api,
                            posterStorageId: message.posterStorageId,
                            heroTag: videoHeroTag,
                          ),
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
                stamp: stampFor(bubbleTone),
                mentionHandles: message.mentionHandles,
                mentionsEveryone: message.mentionsEveryone,
                currentUserId: currentUserId,
                onMentionTap: onMentionTap),
          ),
        ],
      );
    case MessageType.file:
      // Same reasoning as the audio row above: with no storage id there is
      // nothing for `FileMessage` to resolve, and the row would offer a tap it
      // can only refuse. The outbound variant keeps the finished row's shape so
      // nothing moves when the upload lands.
      final fileUpload = message.upload;
      final Widget fileRow = fileUpload != null
          ? OutboundFileRow(
              theme: theme,
              fileName: message.fileName ??
                  AppLocalizations.of(context).messageBubbleFileFallbackName,
              fileSize: message.fileSize,
              isMine: isMine,
              failed: message.status == MessageStatus.error,
              maxWidth: metrics?.videoMaxWidth,
              indicator: _UploadIndicator(
                upload: fileUpload,
                failed: message.status == MessageStatus.error,
                color: isMine ? theme.accentInk : theme.ink,
                size: 22,
                onRetry: onRetrySend,
                onDiscard: onDiscardSend,
              ),
            )
          : FileMessage(
              api: api,
              storageId: message.mediaStorageId,
              fileName: message.fileName,
              fileSize: message.fileSize,
              mimeType: message.mimeType,
              isMine: isMine,
              maxWidth: metrics?.videoMaxWidth,
            );
      final hasFileCaption = message.content.isNotEmpty;
      // With a caption the stamp belongs to the caption block, exactly as it
      // does for an image or a video — two stamps, or one on the wrong block,
      // is what splitting them any other way produces.
      final fileStamp = hasFileCaption ? null : stampFor(bubbleTone);
      final fileTile = Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
        decoration: deco,
        child: fileStamp == null
            ? fileRow
            : Row(
                mainAxisSize: MainAxisSize.min,
                // Sits on the size line rather than starting a second row of
                // tiny type — the 40pt badge sets the height, so it is free.
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Flexible is load-bearing. A `Row` lays a non-flex child out
                  // with UNBOUNDED width, so the document row took its own
                  // `maxWidth` (a phone's `videoMaxWidth`, 280) — wider than
                  // the whole bubble body — and the stamp was pushed off the
                  // end: ~68pt of overflow, a timestamp nobody could see, and a
                  // save control clipped at the bubble's edge. Flexible hands
                  // the row what is actually left after the stamp, and its own
                  // name/size column ellipsizes into it.
                  Flexible(child: fileRow),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child:
                        KeyedSubtree(key: kVisibleStampKey, child: fileStamp),
                  ),
                ],
              ),
      );
      if (!hasFileCaption) return fileTile;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          fileTile,
          const SizedBox(height: 4),
          Container(
            decoration: deco,
            child: _captionBody(theme, message.content, isMine,
                stamp: stampFor(bubbleTone),
                mentionHandles: message.mentionHandles,
                mentionsEveryone: message.mentionsEveryone,
                currentUserId: currentUserId,
                onMentionTap: onMentionTap),
          ),
        ],
      );
    case MessageType.system:
      return Container(
        decoration: deco,
        child: _captionBody(theme, message.content, isMine,
            stamp: stampFor(bubbleTone),
            mentionHandles: message.mentionHandles,
            mentionsEveryone: message.mentionsEveryone,
            currentUserId: currentUserId,
            onMentionTap: onMentionTap),
      );
    case MessageType.location:
    case MessageType.liveLocation:
      // No bubble frame, matching the media tiles above: alignment in the row
      // already says mine/theirs, and a chat bubble drawn around a map card
      // reads as a frame around a frame.
      //
      // No caption branch either, unlike image and file. Nothing can attach text
      // to a location today — the sheet sends the fix and nothing else — and the
      // card's own two lines of readout are already the caption. If a label is
      // ever added it belongs INSIDE this widget, next to the coordinates,
      // rather than in a second bubble underneath.
      return LocationBubble(
        theme: theme,
        message: message,
        isMine: isMine,
        width: imageSize,
        radius: mediaRadius,
        // `onMedia`, not `onBubble`: the stamp is laid over the drawn card, and
        // the card's ground is a theme surface the stamp has to survive the same
        // way it survives a photograph.
        stamp: stampFor(StampTone.onMedia),
        onStopSharing: onStopLiveShare,
        publishing: publishingLiveShare,
      );
    case MessageType.url:
    case MessageType.text:
      return _LinkAwareBubble(
        theme: theme,
        message: message,
        isMine: isMine,
        decoration: deco,
        stamp: stampFor(bubbleTone),
        currentUserId: currentUserId,
        onMentionTap: onMentionTap,
      );
  }
}

/// A padded run of plain bubble text — an image or video caption, or a system
/// notice — stamped when [stamp] is non-null.
///
/// The padding moves off the enclosing `Container` and in here, because the
/// stamp's `Positioned` has to live *inside* the padded box to measure from the
/// text's edge rather than the bubble's.
///
/// Routed through [LinkifiedText] with `linkifyUrls: false` rather than
/// building its own `Text`: with no URLs and no mentions that widget's fast
/// path emits exactly the `Text` / `Text.rich` this used to, so a system notice
/// renders identically — while a caption that DOES carry mentions gets them
/// highlighted through the same code the text bubble uses, instead of a second
/// span builder that would have to be kept in step with it.
///
/// No caller passes a caption today, so the mention half of this is currently
/// only reachable by a system message. It is wired anyway so that adding a
/// caption composer is a repository change and not a rendering one.
Widget _captionBody(
  AppTheme theme,
  String text,
  bool isMine, {
  required MessageStamp? stamp,
  Map<String, String> mentionHandles = const {},
  bool mentionsEveryone = false,
  String? currentUserId,
  void Function(String userId)? onMentionTap,
}) {
  const pad = EdgeInsets.fromLTRB(14, 10, 14, 10);
  final style = theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink);
  final mentionInk = isMine
      ? theme.accentInk
      : (theme.accent.computeLuminance() < 0.2 ? theme.accent : theme.ink);
  final mentionStyle =
      style.copyWith(color: mentionInk, fontWeight: FontWeight.w600);
  final body = LinkifiedText(
    // trimRight so a caption ending in a newline doesn't push the stamp onto
    // a line of its own. Only when there IS a stamp — an unstamped caption kept
    // its trailing whitespace before and has no reason to stop.
    text: stamp == null ? text : text.trimRight(),
    style: style,
    linkifyUrls: false,
    // Unreachable with linkifyUrls false, but the parameters are required.
    linkStyle: style,
    onLinkTap: (_) {},
    trailing: stamp == null ? null : stampSpacerSpan(stamp),
    mentionHandles: mentionHandles,
    mentionsEveryone: mentionsEveryone,
    selfUserId: currentUserId,
    mentionStyle: mentionStyle,
    selfMentionStyle: mentionStyle.copyWith(
      background: Paint()
        ..color = isMine
            ? theme.accentInk.withValues(alpha: 0.22)
            : theme.accentSoft,
    ),
    onMentionTap: onMentionTap,
  );
  if (stamp == null) return Padding(padding: pad, child: body);
  return StampedTextBlock(stamp: stamp, padding: pad, child: body);
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
    this.onRetrySend,
    this.onDiscardSend,
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

  /// Only ever non-null on the sender's own copy of a send that failed. A sealed
  /// photo on its way up has no picture to show and no picture to show it *on* —
  /// the whole point of the fixed silhouette — so the retry pair goes where the
  /// seal goes, and everything about the tile's geometry stays put.
  final Future<void> Function()? onRetrySend;
  final VoidCallback? onDiscardSend;

  @override
  State<_ViewOnceTile> createState() => _ViewOnceTileState();
}

class _ViewOnceTileState extends State<_ViewOnceTile> {
  bool _busy = false;

  /// This is the sender's own copy and it hasn't reached the server yet.
  bool get _outbound => widget.message.upload != null;
  bool get _sending => _outbound && widget.message.status != MessageStatus.error;
  bool get _failed => _outbound && widget.message.status == MessageStatus.error;

  bool get _openable =>
      widget.onOpen != null &&
      !_busy &&
      !_outbound &&
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
  String _caption(BuildContext context) {
    final m = widget.message;
    final l10n = AppLocalizations.of(context);
    // Outbound states first: a photo still going up has not been opened, has not
    // expired, and is not yet "view once" — it is not anywhere yet.
    if (_failed) return l10n.messageBubbleAttachmentStatusFailed;
    if (_sending) return l10n.messageBubbleAttachmentStatusSending;
    if (m.viewOnceBurned) {
      return m.viewOnceOpened || widget.isMine
          ? l10n.messageBubbleViewOnceOpened
          : l10n.messageBubbleViewOnceExpired;
    }
    if (m.viewOnceOpened) return l10n.messageBubbleViewOnceOpened;
    if (widget.isMine) return l10n.messageBubbleViewOnceLabel;
    return l10n.messageBubbleViewOnceTapToView;
  }

  /// Spent means "there is nothing left to open here", which drives the sunken,
  /// struck-through treatment. An outbound photo is the opposite of spent — it
  /// hasn't gone anywhere yet — so it keeps the raised, accent-tinted tile even
  /// though `isMine` is true.
  bool get _spent =>
      !_outbound &&
      (widget.message.viewOnceBurned ||
          widget.message.viewOnceOpened ||
          widget.isMine);

  /// What sits above the "Photo" label: the wax seal, or whatever has replaced it
  /// for the moment.
  ///
  /// Every branch but one is pinned to the seal's own 44pt box, so the tile's
  /// vertical rhythm cannot move as the state changes — a sealed photo that
  /// resized itself on the way from sending to sent would undo the whole reason
  /// this tile has a fixed silhouette. The retry pair is the exception: two 34pt
  /// targets do not fit in 44pt of width, and shrinking them to fit would put a
  /// destructive control under the recommended minimum touch size.
  Widget _badge(AppTheme t, Color seal) {
    if (_failed) {
      return _UploadRetryControls(
        onRetry: widget.onRetrySend,
        onDiscard: widget.onDiscardSend,
      );
    }
    final Widget inner;
    if (_sending) {
      inner = ValueListenableBuilder<double?>(
        valueListenable: widget.message.upload!.progress,
        builder: (context, value, _) => PhotoSpinner(
          color: t.accent,
          value: value?.clamp(0.0, _UploadingImageTile._arcCeiling),
        ),
      );
    } else if (_busy) {
      inner = PhotoSpinner(color: t.accent);
    } else {
      return SizedBox(
        width: _ViewOnceTile._sealSize,
        height: _ViewOnceTile._sealSize,
        child: CustomPaint(
          painter: _ViewOnceSealPainter(color: seal, struck: _spent),
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
      );
    }
    return SizedBox(
      width: _ViewOnceTile._sealSize,
      height: _ViewOnceTile._sealSize,
      child: Center(child: inner),
    );
  }

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
                    _badge(t, seal),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)
                          .messageBubbleViewOncePhotoLabel,
                      style: t.label.copyWith(color: ink, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _caption(context),
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
      semanticLabel:
          AppLocalizations.of(context).messageBubbleViewOnceSemanticLabel,
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

/// The sender's own photo, painted from the bytes in hand while they go up.
///
/// This is the bubble that used not to exist. The optimistic message was built
/// only *after* the upload finished, so the sender tapped SEND, watched the
/// editor pop, and got an unchanged transcript for however long the upload took —
/// and then had the picture they had just sent fetched back down over the network
/// to draw it.
class _UploadingImageTile extends StatelessWidget {
  const _UploadingImageTile({
    required this.theme,
    required this.message,
    required this.upload,
    required this.width,
    required this.radius,
    required this.stamp,
    this.onRetrySend,
    this.onDiscardSend,
  });

  final AppTheme theme;
  final ChatMessage message;
  final PendingUpload upload;
  final double width;
  final BorderRadius radius;
  final MessageStamp? stamp;
  final Future<void> Function()? onRetrySend;
  final VoidCallback? onDiscardSend;

  /// The arc stops here and waits.
  ///
  /// The byte counter runs ahead of the wire by whatever the socket's send buffer
  /// holds, and even a truthful 100% would still be followed by the round trip of
  /// the mutation. A ring that fills completely and then sits there is the same
  /// broken promise as no feedback at all, so it holds just short and only
  /// completes when the status changes under it.
  static const _arcCeiling = 0.95;

  @override
  Widget build(BuildContext context) {
    final failed = message.status == MessageStatus.error;
    final height = ChatMetrics.mediaTileHeight(width, message.mediaAspectRatio);
    // One axis only. `Image.memory` decodes the full source otherwise, and a
    // 12-megapixel photo is ~48 MB of RGBA — enough to evict every avatar and
    // thumbnail in the app to paint one tile. Which axis and why lives in
    // `decodeSizeFor`; this reads it rather than guessing again.
    final decode = decodeSizeFor(
      width: width,
      height: null,
      dpr: MediaQuery.devicePixelRatioOf(context),
      screen: MediaQuery.sizeOf(context),
    );

    final tile = ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              upload.bytes,
              fit: BoxFit.cover,
              cacheWidth: decode.width,
              cacheHeight: decode.height,
              // The bytes never change identity, so there is nothing to fade
              // between — and a fade on every parent rebuild would flicker.
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              // A source the platform can't decode is still a real send that is
              // still going up. Say so with a plate rather than an exception
              // painted into the transcript.
              errorBuilder: (_, _, _) => ColoredBox(
                color: theme.surfaceSunken,
                child: Center(
                  child: Icon(Icons.image_outlined, color: theme.inkMuted),
                ),
              ),
            ),
            ColoredBox(color: Colors.black.withValues(alpha: 0.28)),
            Center(
              child: _UploadIndicator(
                upload: upload,
                failed: failed,
                color: Colors.white,
                size: 30,
                onRetry: onRetrySend,
                onDiscard: onDiscardSend,
              ),
            ),
          ],
        ),
      ),
    );

    return StampedMedia(tile: tile, stamp: stamp);
  }
}

/// A voice note on its way up, in the same silhouette the finished player takes.
///
/// The finished player is a 34pt round play button, a waveform and a duration.
/// This is the button's ring where the button will be, and the word in place of
/// the duration — so nothing moves when the real player replaces it.
class _OutboundAudioRow extends StatelessWidget {
  const _OutboundAudioRow({
    required this.theme,
    required this.upload,
    required this.isMine,
    required this.failed,
    this.onRetry,
    this.onDiscard,
  });

  final AppTheme theme;
  final PendingUpload upload;
  final bool isMine;
  final bool failed;
  final Future<void> Function()? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final ink = isMine ? theme.accentInk : theme.ink;
    final indicator = _UploadIndicator(
      upload: upload,
      failed: failed,
      color: ink,
      size: 22,
      onRetry: onRetry,
      onDiscard: onDiscard,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pinned to the play button's own box while it is a ring, so the finished
        // player slots in without anything moving. NOT pinned when it is the retry
        // pair: two 34pt touch targets do not fit in 34pt of width, and shrinking
        // them to fit would put a destructive control under the minimum tap size.
        // The bubble is free to widen for those few seconds.
        if (failed)
          indicator
        else
          SizedBox(width: 34, height: 34, child: Center(child: indicator)),
        const SizedBox(width: 10),
        Text(
          failed
              ? AppLocalizations.of(context).messageBubbleAttachmentStatusFailed
              : AppLocalizations.of(context)
                  .messageBubbleAttachmentStatusSending,
          style: theme.body.copyWith(color: ink),
        ),
      ],
    );
  }
}

/// A video on its way up: the tile it will occupy, with the ring in the middle.
class _OutboundVideoTile extends StatelessWidget {
  const _OutboundVideoTile({
    required this.theme,
    required this.upload,
    required this.failed,
    required this.width,
    this.onRetry,
    this.onDiscard,
  });

  final AppTheme theme;
  final PendingUpload upload;
  final bool failed;
  final double width;
  final Future<void> Function()? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      // 16:9, the shape most phone video actually is. There is no header to read
      // the true ratio out of without decoding the container, and one guess that
      // is usually right beats a square that never is.
      height: width * 9 / 16,
      color: Colors.black,
      alignment: Alignment.center,
      child: _UploadIndicator(
        upload: upload,
        failed: failed,
        color: Colors.white,
        size: 30,
        onRetry: onRetry,
        onDiscard: onDiscard,
      ),
    );
  }
}

/// The state of one outgoing attachment, in one glyph: a filling ring while it
/// goes up, RETRY and DISCARD once it has failed.
///
/// Shared by all three attachment kinds. A photo shows it over the picture, a
/// video over its placeholder, a voice note beside its waveform — but the rule
/// for what to draw is the same in every case, and it only wants writing once.
class _UploadIndicator extends StatelessWidget {
  const _UploadIndicator({
    required this.upload,
    required this.failed,
    required this.color,
    required this.size,
    this.onRetry,
    this.onDiscard,
  });

  final PendingUpload upload;
  final bool failed;
  final Color color;
  final double size;
  final Future<void> Function()? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return _UploadRetryControls(onRetry: onRetry, onDiscard: onDiscard);
    }
    // Listened to directly rather than read off a rebuild: progress ticks about
    // ten times a second, and the repository's notifyListeners would rebuild the
    // whole transcript for each one.
    return ValueListenableBuilder<double?>(
      valueListenable: upload.progress,
      builder: (context, value, _) => PhotoSpinner(
        size: size,
        color: color,
        value: value?.clamp(0.0, _UploadingImageTile._arcCeiling),
      ),
    );
  }
}

/// RETRY and DISCARD over a send that failed.
///
/// Bare [GestureDetector] plus [FocusableTap], no `IconButton` and no ink —
/// nothing in this app ripples. The dark lozenge is the same one [MessageStamp]
/// wears over media, for the same reason: it sits on a photograph, whose colour
/// no theme knows.
class _UploadRetryControls extends StatelessWidget {
  const _UploadRetryControls({required this.onRetry, required this.onDiscard});

  final Future<void> Function()? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UploadControl(
              icon: Icons.refresh,
              semanticLabel: AppLocalizations.of(context)
                  .messageBubbleRetrySendingSemanticLabel,
              onTap: onRetry == null ? null : () => onRetry!(),
            ),
            const SizedBox(width: 4),
            _UploadControl(
              icon: Icons.close,
              semanticLabel:
                  AppLocalizations.of(context).messageBubbleDiscardSemanticLabel,
              onTap: onDiscard,
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadControl extends StatelessWidget {
  const _UploadControl({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
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
    this.currentUserId,
    this.onMentionTap,
  });

  final AppTheme theme;
  final ChatMessage message;
  final bool isMine;
  final String? currentUserId;
  final void Function(String userId)? onMentionTap;

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
        // Mentions borrow the link's ink for the same reason it was computed
        // that way: an outgoing bubble is FILLED with `theme.accent`, so an
        // accent-coloured word inside one is invisible. Weight carries the
        // emphasis instead of colour, and no underline — that stays the link's
        // own signature so the two remain tellable apart at a glance.
        final mentionStyle = theme.body.copyWith(
          color: linkAccent,
          fontWeight: FontWeight.w600,
        );
        // Being named yourself gets a wash behind the text as well. This is the
        // one distinction the feature exists to draw, so it is the one that
        // gets the loudest treatment available.
        //
        // `TextStyle.background` rather than a `WidgetSpan` pill: this
        // paragraph already carries one placeholder whose sizing is
        // load-bearing (`stampSpacerSpan` reserves exactly the room the
        // timestamp needs, and a too-full line is supposed to wrap instead of
        // giving it up). A pill wraps as an atomic unit and would start
        // influencing that decision. A background paints behind the glyphs at
        // zero layout cost, and — unlike a placeholder — stays selectable, so
        // the copy action keeps agreeing with what is on screen.
        final selfMentionStyle = mentionStyle.copyWith(
          background: Paint()
            ..color = isMine
                ? theme.accentInk.withValues(alpha: 0.22)
                : theme.accentSoft,
        );
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
          mentionHandles: message.mentionHandles,
          mentionsEveryone: message.mentionsEveryone,
          selfUserId: currentUserId,
          mentionStyle: mentionStyle,
          selfMentionStyle: selfMentionStyle,
          onMentionTap: onMentionTap,
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
    this.deliveredToOthers = false,
  });
  final ChatMessage message;
  final bool isMine;
  final Duration? countdown;
  final bool seenByOthers;

  /// Whether anyone else's device is known to hold this yet — the second
  /// tick, below [seenByOthers] on the same ladder. See [MessageReceipt].
  final bool deliveredToOthers;

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
        receipt: messageReceipt(
          isMine: isMine,
          deliveredToOthers: deliveredToOthers,
          seenByOthers: seenByOthers,
        ),
        tone: StampTone.onSurface,
      ),
    );
  }
}
