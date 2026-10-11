import 'dart:math' as math;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/message_formatting.dart';
import '../models/message_interaction.dart';
import '../models/pending_upload.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../media/media_aspect_cache.dart';
import '../media/storage/auto_download.dart';
import '../media/storage/media_ledger.dart';
import '../platform.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';
import '../theme/interaction.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../screens/fullscreen_image_viewer.dart';
import '../screens/fullscreen_video_viewer.dart';
import '../services/link_opener.dart';
import 'audio_message.dart';
import 'auto_download_gate.dart';
import 'file_message.dart';
import 'highlight_pulse.dart';
import 'link_confirm_sheet.dart';
import 'link_preview_card.dart';
import 'jumbo_emoji.dart';
import 'linkified_text.dart';
import 'media_flight.dart';
import 'interaction_bubble.dart';
import 'location_bubble.dart';
import 'text_runs.dart';
import 'message_stamp.dart';
import 'photo_chrome.dart';
import 'photo_deck.dart';
import 'photo_mosaic.dart';
import 'reaction_bubble.dart';
import 'remote_image.dart';
import 'room_gallery_scope.dart';
import 'steady_hero.dart';
import 'reply_indicator.dart';
import 'translation_slab.dart';
import 'speaker_scope.dart';
import 'user_avatar.dart';
import 'message_departures.dart';
import 'message_hover_actions.dart';
import 'video_message.dart';
import 'video_note_message.dart';
import 'expressions/expression_bubble.dart';
import 'expressions/expression_sheet.dart';

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
    this.onContextMenu,
    this.hover,
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
    this.replyStyle,
    this.seenByOthers = false,
    this.deliveredToOthers = false,
    this.saved = false,
    this.pinned = false,
    this.grouped = false,
    this.lastInRun = true,
    this.showAvatarSlot = true,
    this.showAvatar = true,
    this.senderName,
    this.onOpenViewOnce,
    this.onStopLiveShare,
    this.publishingLiveShare = false,
    this.onRetrySend,
    this.onDiscardSend,
    this.bubbleKey,
    this.album = const [],
    this.onAlbumOpen,
    this.onAlbumTileLongPress,
    this.onAlbumReactionTap,
    this.onAlbumReactionLongPress,
    this.albumHighlightId,
    this.albumHighlightT = 0,
    this.interaction,
    this.interactionActions = InteractionActions.none,
  });

  /// The poll/checklist/event body for this row, when it has arrived. Null on
  /// every other type and on an interactive one still waiting for its own
  /// subscription — see [InteractionBubble], which treats null as an ordinary
  /// state and draws the prompt regardless.
  final MessageInteraction? interaction;

  /// What this transcript can do to that card. Built once per room rather than
  /// per row — see [InteractionActions].
  final InteractionActions interactionActions;

  /// Every photograph this row draws, oldest first, when a run of them was
  /// collapsed into one album — see `collapseAlbums`. Empty on an ordinary
  /// row, and never of length one.
  ///
  /// [message] is the last of them and stays the row's message in every other
  /// respect: it owns the timestamp, the delivery ticks, the avatar's place in
  /// the run and the swipe that arms a reply. Only the picture is different,
  /// and only because a mosaic is what the whole set looks like.
  final List<ChatMessage> album;

  /// Opens one photograph of [album] fullscreen. Null falls back to the
  /// gallery scope, exactly as a lone photo's tile does.
  final Future<void> Function(ChatMessage m,
      {required int sourceDecodeWidth})? onAlbumOpen;

  /// The tile under the finger and the key of its rect, for the action menu.
  /// The row's own [onLongPress] is about [message]; inside an album the
  /// target is whichever picture was actually pressed.
  final void Function(ChatMessage m, GlobalKey anchor)? onAlbumTileLongPress;

  final void Function(ChatMessage m, String emoji)? onAlbumReactionTap;
  final void Function(ChatMessage m, String emoji)? onAlbumReactionLongPress;

  /// Which photograph of [album] a jump has landed on, and how far into its
  /// pulse it is. Non-null moves the pulse OFF the block and onto that one
  /// tile — see [PhotoMosaic.highlightedPhotoId] — because a halo around ten
  /// photographs does not answer the question the trip was asking.
  final String? albumHighlightId;
  final double albumHighlightT;

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

  /// A mouse's secondary click, at its global position: the compact pointer
  /// menu rather than the long-press overlay. Null falls back to
  /// [onLongPress], which is what a right-click did before there was one.
  final void Function(Offset globalPosition)? onContextMenu;

  /// What the hover strip offers for this bubble. Inert without a
  /// [MessageHoverScope] above, so passing it costs a phone nothing.
  final MessageHoverTarget? hover;
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

  /// Renders this reply style instead of the user's setting — for previews
  /// that must show one specific design, and for tests.
  final ReplyStyle? replyStyle;

  final bool seenByOthers;

  /// Whether anyone else's device is known to hold this yet — the second
  /// tick, below [seenByOthers] on the same ladder. See [MessageReceipt].
  final bool deliveredToOthers;

  /// Whether THIS viewer has bookmarked this message, which puts a small mark
  /// on its stamp. Passed in rather than read from a repository here for the
  /// same reason the two receipts above are: a bubble is also rendered in
  /// previews and chrome that have no repository, and false is the right answer
  /// there. See [MessageStamp.saved].
  final bool saved;

  /// Whether this message is one of the room's pins, which puts a pin on its
  /// stamp beside the bookmark. Passed in for the same reason [saved] is.
  /// See [MessageStamp.pinned].
  final bool pinned;

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

  /// Rendered above the bubble when non-null. Callers pass it only on the
  /// first row of a run, and never for the current user or in a DM.
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    // Files this row's media in the storage ledger (which chat, which kind,
    // last seen) and offers it to auto-download. Both are a lookup on the hot
    // path and do real work only the first time a message is drawn.
    final incoming = message.senderId != currentUserId;
    MediaLedger.instance.noteMessage(message, incoming: incoming);
    for (final photo in album) {
      MediaLedger.instance.noteMessage(photo, incoming: incoming);
    }
    AutoDownload.instance.consider(message, api, incoming: incoming);
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

    // A full reply in the default style quotes INSIDE its own bubble, so
    // there is nothing above it: no card, no connector, no reserved gap.
    final quoteInside = message.isReply &&
        replyMarker == ReplyMarker.full &&
        (replyStyle ?? SettingsStore.instance.replyStyle) ==
            ReplyStyle.quote &&
        quoteFitsInside(message);
    final Widget? insideQuote = quoteInside
        ? InlineReplyQuote(
            preview: message.replyToPreview!,
            isMine: isMine,
            api: api,
            onTap: () {
              final id = message.replyToId;
              if (id != null) onReplyIndicatorTap?.call(id);
            },
          )
        : null;

    // The main bubble with halo wrapper. The reply indicator (when present)
    // sits in a sibling Column ABOVE this — outside the bubble — so it can
    // adopt its own visual identity (phantom / sticky / comic) without
    // distorting the bubble's natural radius or background.
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: HighlightPulse(
        // Stood down while one of this row's pictures is carrying the pulse:
        // two of them at once would ring the block AND the tile inside it.
        t: albumHighlightId == null ? highlightT : 0.0,
        shape: pulseShapeFor(
          theme: theme,
          message: message,
          isMine: isMine,
          bubbleStyle: bubbleStyle,
          firstInRun: !grouped,
          lastInRun: lastInRun,
        ),
        child: _bubbleContent(context, theme, isMine,
            ephemeral: false,
            metrics: metrics,
            bubbleStyle: bubbleStyle,
            quote: insideQuote),
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
    final marker = message.isReply && !quoteInside
        ? replyMarker
        : ReplyMarker.none;
    // The name sits OUTSIDE the bubble, on the room's own ground — so the ink
    // is conditioned against the background rather than against the fill the
    // bubble under it happens to be washed with.
    final nameColor =
        SpeakerScope.inkOf(context, message.senderId, on: theme.background);
    final tailGutter = theme.bubbleTailGutter(bubbleStyle);
    // A full quote card is tall enough to need its own beat — see
    // `continuesRun` — and a name floating above that card reads as
    // disconnected from the avatar closing the block down at the bubble's
    // bottom edge. Bracketing the name with the bubble instead, right below
    // the card that earns its own space, keeps a sender's name and face
    // around the one thing they actually said. The compact marker never hits
    // this: it draws a thin tether, not a card tall enough to matter.
    final showInlineName =
        marker == ReplyMarker.full && (senderName?.isNotEmpty ?? false);
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
              styleOverride: replyStyle,
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
          if (showInlineName)
            _SenderNameLabel(
              name: senderName!,
              color: nameColor,
              left: (isMine ? 0 : tailGutter) + 4,
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
        senderName: showInlineName ? null : senderName,
        nameColor: nameColor,
        tailGutter: tailGutter,
        avatar: _AvatarSlot(
          author: author,
          api: api,
          onTap: onAuthorTap,
          collapsed: !showAvatar,
        ),
        bubble: _BubbleGestureDetector(
          onLongPress: onLongPress,
          onDoubleTap: _contentHandlesTap(message) ? null : onDoubleTap,
          onContextMenu: onContextMenu,
          hover: hover,
          child: bubbleArea,
        ),
        // An album's chips are drawn on the tiles that earned them — a row
        // under a mosaic could not say which of ten photographs it was about.
        reactions: message.reactions.isNotEmpty &&
                onReactionTap != null &&
                album.length < 2
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ReactionRow(
                  reactions: message.reactions,
                  currentUserId: currentUserId,
                  onToggle: onReactionTap!,
                  onShowReactors: onReactionLongPress,
                  alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                  hanging: true,
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
                saved: saved,
                pinned: pinned,
              ),
      ),
    );
  }

  Widget _bubbleContent(BuildContext context, AppTheme theme, bool isMine,
      {required bool ephemeral,
      required BubbleStyle bubbleStyle,
      ChatMetrics? metrics,
      Widget? quote}) {
    return buildMessageContent(
      context: context,
      theme: theme,
      message: message,
      isMine: isMine,
      ephemeral: ephemeral,
      api: api,
      quote: quote,
      useHero: useHero,
      metrics: metrics,
      bubbleStyle: bubbleStyle,
      firstInRun: !grouped,
      lastInRun: lastInRun,
      seenByOthers: seenByOthers,
      deliveredToOthers: deliveredToOthers,
      saved: saved,
      pinned: pinned,
      onOpenViewOnce: onOpenViewOnce,
      onStopLiveShare: onStopLiveShare,
      publishingLiveShare: publishingLiveShare,
      onRetrySend: onRetrySend,
      onDiscardSend: onDiscardSend,
      currentUserId: currentUserId,
      onMentionTap: onMentionTap,
      album: album,
      onAlbumOpen: onAlbumOpen,
      onAlbumTileLongPress: onAlbumTileLongPress,
      onAlbumReactionTap: onAlbumReactionTap,
      onAlbumReactionLongPress: onAlbumReactionLongPress,
      albumHighlightId: albumHighlightId,
      albumHighlightT: albumHighlightT,
      interaction: interaction,
      interactionActions: interactionActions,
    );
  }
}

/// Whether [message]'s reply quote can be drawn inside its bubble: a plain
/// text bubble with words in it. Media, stickers, jumbo emoji and URL-only
/// cards have no bubble to put it in, and draw it above instead.
bool quoteFitsInside(ChatMessage message) {
  if (message.type != MessageType.text && message.type != MessageType.url) {
    return false;
  }
  if (messageJumboEmoji(message, ephemeral: false) != null) return false;
  final hidden = !SettingsStore.instance.showLinkUrls;
  final text = hidden
      ? DisplayTransform.of(
          message.content,
          hidden: UrlDetector.matches(message.content),
        ).text
      : message.content;
  return text.trim().isNotEmpty;
}

/// The entrance ramp on the themed dissolve overlay, as opposed to the fade on
/// the bubble it sits over.
///
/// Keyed because both are plain [Opacity]s inside the same subtree, and a test
/// asking "did the wash arrive or did it snap on" has to be able to say which
/// one it means.
@visibleForTesting
const Key ephemeralSignatureKey = Key('ephemeral-signature');

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
    this.onContextMenu,
    this.hover,
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
    this.saved = false,
    this.pinned = false,
    this.grouped = false,
    this.lastInRun = true,
    this.showAvatarSlot = true,
    this.showAvatar = true,
    this.senderName,
    this.onOpenViewOnce,
    this.onStopLiveShare,
    this.publishingLiveShare = false,
    this.onRetrySend,
    this.onDiscardSend,
    this.bubbleKey,
    this.interaction,
    this.interactionActions = InteractionActions.none,
    this.departures,
    this.rowKey,
  });

  /// Where this bubble reports its own expiry, and what rasters it for the
  /// exit. Null (a lifted preview, a thread pane, a test) means the bubble
  /// simply draws until its row is gone.
  final MessageDepartures? departures;

  /// The row's identity in the ledgers — stable across the `tmp_` → server
  /// id swap. Required alongside [departures].
  final String? rowKey;

  /// The poll/checklist/event body, and what may be done to it. Carried here as
  /// well as on [MessageBubble] because a Chamber of Secrets room can hold one:
  /// a poll that self-destructs is an ordinary poll with a clock on it, and
  /// nothing about answering it changes.
  final MessageInteraction? interaction;
  final InteractionActions interactionActions;

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

  /// The expiry clock, as a listenable rather than a value.
  ///
  /// A bubble on a clock is a function of the current instant across its
  /// whole body — the countdown, the closing wash and the moment it asks to
  /// leave all read it — so there is no small piece of this to isolate. What
  /// CAN be isolated is the rest of the screen: taking the clock as a
  /// listenable keeps a 5Hz tick inside the bubbles that are counting down
  /// instead of rebuilding the transcript around them. See [build].
  final ValueListenable<DateTime> now;
  final String currentUserId;
  final ChatApi api;
  final ChatUser? author;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  /// A mouse's secondary click, at its global position: the compact pointer
  /// menu rather than the long-press overlay. Null falls back to
  /// [onLongPress], which is what a right-click did before there was one.
  final void Function(Offset globalPosition)? onContextMenu;

  /// What the hover strip offers for this bubble. Inert without a
  /// [MessageHoverScope] above, so passing it costs a phone nothing.
  final MessageHoverTarget? hover;
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

  /// See [MessageBubble.saved]. Meaningful here too: an ephemeral message can
  /// be bookmarked, and the bookmark simply goes with it when it burns —
  /// `removeMessageAndFanout` drops both.
  final bool saved;

  /// See [MessageBubble.pinned].
  final bool pinned;

  /// See [MessageBubble.grouped].
  final bool grouped;

  /// See [MessageBubble.lastInRun].
  final bool lastInRun;

  /// See [MessageBubble.showAvatarSlot].
  final bool showAvatarSlot;

  /// See [MessageBubble.showAvatar].
  final bool showAvatar;

  /// See [MessageBubble.senderName].
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    // The clock arrives as a listenable, and the subscription starts HERE —
    // one level inside the row — on purpose. The countdown wants 5Hz, and
    // when the screen owned that as state, five times a second it rebuilt the
    // whole transcript: every row, ephemeral or not, plus the dividers, the
    // composer and the app bar, each row re-running its capability,
    // saved-state and read-cursor lookups. Four of those five ticks changed
    // nothing anybody could see, and they were paid out of the same frame
    // budget the receive path parses an arriving message on. Now the tick
    // repaints the bubbles that are actually counting down, and nothing else.
    return ValueListenableBuilder<DateTime>(
      valueListenable: now,
      builder: (context, nowValue, _) =>
          // See MessageBubble.build — the shape is a preference, so the row
          // rebuilds with it.
          AnimatedBuilder(
            animation: SettingsStore.instance,
            builder: (context, _) =>
                _build(context, SettingsStore.instance.bubbleStyle, nowValue),
          ),
    );
  }

  /// How long the closing wash runs for, at most.
  ///
  /// The wash is the warning, not the exit: the theme's signature builds over
  /// the bubble for its last few seconds — the message stays perfectly
  /// legible under it — and at expiry the bubble itself blows apart (see
  /// [DepartingRow]). Three seconds is long enough to read as "about to go"
  /// and short enough never to read as how old messages look here. It used to
  /// be a six-second fade to nothing, which left the row invisible for the
  /// moment that mattered.
  static const Duration _dissolveWindow = Duration(seconds: 3);

  /// ...and never more than this much of a short-lived message, so a room set
  /// to ten seconds does not spend a third of every message warning about it.
  static const double _dissolveMaxFraction = 0.18;

  /// How far the wash is allowed to lag the clock driving it.
  ///
  /// [now] ticks at 5Hz — right for a countdown, four frames a tick short of
  /// enough for a wash, and the reason this used to move in visible steps.
  /// The ramp is interpolated BETWEEN those ticks instead of stepping with
  /// them, and this is the tween that does it. Deliberately a shade longer
  /// than the 200ms tick: the next target then always arrives while the last
  /// one is still in flight, so the motion never stalls on a frame waiting
  /// for the clock. The cost is ~40ms of lag, on a ramp measured in seconds,
  /// that nobody can see.
  static const Duration _tickSmoothing = Duration(milliseconds: 240);

  /// 0 while the message is simply alive, 1 the instant it expires.
  double _washAt(DateTime now) {
    final expires = message.expiresAt;
    if (expires == null) return 0;
    final life = expires.difference(message.createdAt).inMicroseconds;
    if (life <= 0) return 1;
    final window = math.min(
      _dissolveWindow.inMicroseconds,
      (life * _dissolveMaxFraction).round(),
    );
    if (window <= 0) return 0;
    return (1 - expires.difference(now).inMicroseconds / window)
        .clamp(0.0, 1.0);
  }

  Widget _build(
      BuildContext context, BubbleStyle bubbleStyle, DateTime now) {
    final theme = ThemeScope.of(context);
    final isMine = message.senderId == currentUserId;
    // See MessageBubble.build — null outside a ChatPane, and every metric
    // then falls back to the literal it replaced.
    final metrics = ChatMetricsScope.maybeOf(context);

    // The bubble's own outline — tail, run-grouping and all. Computed once and
    // used three times: the scroll-to halo traces it, the closing wash is
    // clipped to it, and the exit takes flight only from inside it.
    final bubbleOutline = pulseShapeFor(
      theme: theme,
      message: message,
      isMine: isMine,
      bubbleStyle: bubbleStyle,
      ephemeral: true,
      firstInRun: !grouped,
      lastInRun: lastInRun,
    );

    // Expired on this device's clock: ask to leave. The ledger rasters the
    // bubble after this frame — which is why the bubble below still draws at
    // full strength — and swaps the row for the exit. Idempotent, so the
    // ticks that follow cost a map probe each.
    final departures = this.departures;
    final rowKey = this.rowKey;
    final expires = message.expiresAt;
    if (departures != null &&
        rowKey != null &&
        expires != null &&
        !now.isBefore(expires)) {
      departures.requestLocalDeparture(
        rowKey,
        message,
        isMine: isMine,
        outline: bubbleOutline,
      );
    }

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
      saved: saved,
      pinned: pinned,
      onOpenViewOnce: onOpenViewOnce,
      onStopLiveShare: onStopLiveShare,
      publishingLiveShare: publishingLiveShare,
      onRetrySend: onRetrySend,
      onDiscardSend: onDiscardSend,
      currentUserId: currentUserId,
      onMentionTap: onMentionTap,
      interaction: interaction,
      interactionActions: interactionActions,
    );

    // `inner` is built ONCE per clock tick, out here, and handed to the
    // animation by reference. `Element.updateChild` short-circuits on an
    // identical widget instance, so the sixty rebuilds a second below re-run
    // the wash wrapper and nothing else: the message's text, its markdown,
    // its media and its player are never rebuilt by the ramp.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _washAt(now)),
      duration: _tickSmoothing,
      curve: Curves.linear,
      builder: (context, t, _) => _frame(
        context,
        theme: theme,
        bubbleStyle: bubbleStyle,
        isMine: isMine,
        metrics: metrics,
        now: now,
        content: inner,
        bubbleOutline: bubbleOutline,
        t: t,
      ),
    );
  }

  /// One frame of the closing wash at [t] — 0 while the message is simply
  /// alive, 1 at expiry.
  ///
  /// The bubble itself is untouched by [t]: no fade, no blur, no drift. It
  /// used to do all three, reaching invisibility exactly at expiry — which
  /// meant the row was already gone to the eye when the list dropped it, and
  /// there was nothing left for an exit to happen to. Now the bubble stays at
  /// full strength under the wash until the instant it blows apart.
  Widget _frame(
    BuildContext context, {
    required AppTheme theme,
    required BubbleStyle bubbleStyle,
    required bool isMine,
    required ChatMetrics? metrics,
    required DateTime now,
    required Widget content,
    required ShapeBorder bubbleOutline,
    required double t,
  }) {
    final bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (t > 0)
          Positioned.fill(
            // CLIPPED TO THE BUBBLE, and this is not a detail.
            //
            // Every theme's signature fills the rect it is given — a gradient
            // in a `DecoratedBox`, a painter over `SizedBox.expand` — and the
            // rect a `Positioned.fill` gives it is the bubble's bounding BOX,
            // not the bubble. So the wash painted square corners outside a
            // rounded bubble and a hard edge across its tail: a rectangle that
            // appeared around the message for the length of the dissolve.
            // Invisible before only because the wash used to flash and leave;
            // now that it stays, it has to be the right shape.
            child: ClipPath(
              clipper: ShapeBorderClipper(shape: bubbleOutline),
              child: Opacity(
                key: ephemeralSignatureKey,
                // Every theme's signature is a motion — smoke rising, dots
                // scattering, a gradient washing across — and every one of
                // them paints at FULL strength the moment it is handed a
                // progress of zero. Mounting it at the top of the dissolve
                // therefore snapped a coloured wash onto the bubble in a
                // single frame, which is the flash this whole animation used
                // to open with. The painters carry no entrance of their own;
                // this is it.
                opacity:
                    Curves.easeOutCubic.transform((t / 0.22).clamp(0.0, 1.0)),
                child: theme.ephemeralSignature(progress: t),
              ),
            ),
          ),
      ],
    );

    final maxWidth = metrics?.bubbleMaxWidth ?? messageMaxWidth(context);

    final innerBubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: HighlightPulse(
        t: highlightT,
        shape: bubbleOutline,
        child: bubble,
      ),
    );

    // The raster boundary the exit is taken from: the bubble alone — wash
    // included, marker and avatar excluded — which is exactly the box
    // [DepartingRow] cuts into tiles. Only a bubble with a ledger to report
    // to pays for the layer.
    final anchor =
        departures != null && rowKey != null ? departures!.anchorKeyFor(rowKey!) : null;
    final captured = anchor == null
        ? innerBubble
        : RepaintBoundary(key: anchor, child: innerBubble);

    // See the twin in [MessageBubble] — the bubble alone, not the marker.
    final keyed = bubbleKey == null
        ? captured
        : KeyedSubtree(key: bubbleKey!, child: captured);

    // See the twin in [MessageBubble] — same rule, same veto.
    final marker = message.isReply ? replyMarker : ReplyMarker.none;
    // See the twin in [MessageBubble] — same ground, same reasoning.
    final nameColor =
        SpeakerScope.inkOf(context, message.senderId, on: theme.background);
    final tailGutter = theme.bubbleTailGutter(bubbleStyle);
    // See the twin in [MessageBubble] for why a full quote card pulls the
    // name down beside the bubble instead of leaving it to float above.
    final showInlineName =
        marker == ReplyMarker.full && (senderName?.isNotEmpty ?? false);
    final Widget bubbleArea;
    if (marker == ReplyMarker.none) {
      bubbleArea = keyed;
    } else {
      bubbleArea = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Marker sits OUTSIDE the raster boundary — its own identity, and
          // it simply leaves with the row.
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
          if (showInlineName)
            _SenderNameLabel(
              name: senderName!,
              color: nameColor,
              left: (isMine ? 0 : tailGutter) + 4,
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
        senderName: showInlineName ? null : senderName,
        nameColor: nameColor,
        tailGutter: tailGutter,
        avatar: _AvatarSlot(
          author: author,
          api: api,
          onTap: onAuthorTap,
          collapsed: !showAvatar,
        ),
        bubble: _BubbleGestureDetector(
          onLongPress: onLongPress,
          onDoubleTap: _contentHandlesTap(message) ? null : onDoubleTap,
          onContextMenu: onContextMenu,
          hover: hover,
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
                  hanging: true,
                ),
              )
            : null,
        meta: messageStampsInline(message,
                showLinkUrls: SettingsStore.instance.showLinkUrls,
                ephemeral: true)
            ? null
            : _MetaRow(
                message: message,
                isMine: isMine,
                countdown: message.timeLeft(now),
                seenByOthers: seenByOthers,
                deliveredToOthers: deliveredToOthers,
                saved: saved,
                pinned: pinned,
              ),
      ),
    );
  }
}

// A parent double-tap recognizer holds a child's ordinary tap until its
// timeout, and can turn two quick answers into an action-menu gesture.
// Attachment controls own their taps; long-press still opens the message menu.
bool _contentHandlesTap(ChatMessage message) => switch (message.type) {
  MessageType.text => message.mentions.isNotEmpty ||
      UrlDetector.matches(message.content).isNotEmpty,
  MessageType.system => false,
  _ => true,
};

/// Long-press-for-reactions, double-tap, and right-click on a single [child],
/// with an explicit long-press duration. Plain [GestureDetector] has no hook
/// for that duration, so this goes straight to the recognizers — see
/// [_HorizontalRightDragRecognizer] in swipe_to_reply.dart for the same
/// pattern.
///
/// Three pointer rules, all inert on a phone:
///
///  * **Right-click** opens [onContextMenu] at the pointer, on mouse-DOWN, the
///    way a Mac or Windows menu opens. It goes through
///    [_SecondaryClickRecognizer], which claims the secondary button the
///    moment it is pressed: a selectable text bubble has a [SelectionArea]
///    inside it with its own right-click handling (select the word, show the
///    text toolbar), and an eager claim is the one thing that beats a
///    recognizer DEEPER in the tree. Without [onContextMenu] a right-click
///    mirrors [onLongPress], as it always has.
///  * **Long-press** does not answer a mouse on web/desktop: holding the
///    button down there is the start of a text selection, and a menu blooming
///    half a second into a drag-select is a menu nobody asked for.
///  * **Double-tap** is off on physical-keyboard platforms. There a double
///    click selects a word, and a pending double-tap recognizer also holds
///    every single click on the bubble for the double-tap timeout.
class _BubbleGestureDetector extends StatelessWidget {
  const _BubbleGestureDetector({
    required this.child,
    this.onLongPress,
    this.onDoubleTap,
    this.onContextMenu,
    this.hover,
  });

  final Widget child;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final void Function(Offset globalPosition)? onContextMenu;
  final MessageHoverTarget? hover;

  static final Set<PointerDeviceKind> _notMouse = {
    for (final k in PointerDeviceKind.values)
      if (k != PointerDeviceKind.mouse) k,
  };

  @override
  Widget build(BuildContext context) {
    final onDoubleTap = isPhysicalKeyboardPlatform ? null : this.onDoubleTap;
    final onContextMenu = this.onContextMenu;
    final detector = RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: kActionMenuLongPress,
            supportedDevices: isWebOrDesktop ? _notMouse : null,
          ),
          (instance) => instance.onLongPress = onLongPress,
        ),
        if (onDoubleTap != null)
          DoubleTapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
            () => DoubleTapGestureRecognizer(),
            (instance) => instance.onDoubleTap = onDoubleTap,
          ),
        if (onContextMenu != null)
          _SecondaryClickRecognizer:
              GestureRecognizerFactoryWithHandlers<_SecondaryClickRecognizer>(
            () => _SecondaryClickRecognizer(),
            (instance) => instance.onClick = onContextMenu,
          )
        else
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(),
            // Touch devices never produce a secondary tap, so this needs no
            // platform gate.
            (instance) => instance.onSecondaryTap = onLongPress,
          ),
      },
      child: child,
    );
    return MessageHoverRegion(target: hover, child: detector);
  }
}

/// Claims a mouse's secondary button on the way DOWN and reports where.
///
/// Eager on purpose. A recognizer that waits for the arena to sweep loses to
/// any deeper one, and a [SelectionArea] inside a text bubble is deeper and
/// wants the same button. Accepting at once also means it fires before the
/// 100ms tap deadline, so the selection's own "right-click selects the word"
/// never runs underneath the menu.
class _SecondaryClickRecognizer extends OneSequenceGestureRecognizer {
  _SecondaryClickRecognizer()
      : super(supportedDevices: const {PointerDeviceKind.mouse});

  void Function(Offset globalPosition)? onClick;
  Offset? _down;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      event.buttons == kSecondaryMouseButton && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _down = event.position;
    resolve(GestureDisposition.accepted);
  }

  @override
  void acceptGesture(int pointer) {
    super.acceptGesture(pointer);
    final at = _down;
    _down = null;
    if (at != null) onClick?.call(at);
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    _down = null;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'secondary click';
}

/// The name label bracketing a run from above — rendered either at the top of
/// [_BubbleLayout], for a plain first-in-run message, or, when a full quote
/// card sits above the bubble instead, inline right beside it (see
/// `showInlineName` in both bubble widgets' `_build`). Kept as one widget so
/// the two placements read as the same signature rather than two different
/// labels that happen to look alike.
class _SenderNameLabel extends StatelessWidget {
  const _SenderNameLabel({
    required this.name,
    required this.color,
    required this.left,
  });

  final String name;

  /// Null keeps the accent every sender used to share — a DM, a room with
  /// speaker colours off, or a sender who is no longer a member and so has no
  /// colour of their own.
  final Color? color;
  final double left;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: EdgeInsets.only(left: left, bottom: 2),
      child: Text(
        name,
        // A person's name on the body face at 13/w600 — never the theme's
        // mono, which on a character theme is a tracked typewriter face.
        style: theme.bodySoft.copyWith(
          fontSize: 13,
          letterSpacing: 0,
          // The 0.95 stays off the speaker ink: that colour was
          // conditioned to clear 4.5:1 against this exact background, and
          // shaving five percent off it would spend contrast the
          // conditioning just finished earning.
          color: color ?? theme.accent.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// The row scaffold both bubble variants share: an optional sender name, the
/// avatar-and-bubble row, then reactions and the meta row.
///
/// Reactions and the meta row deliberately sit OUTSIDE the row rather than in
/// a column beside the avatar. That is what keeps "bottom" — where the avatar
/// always sits, whether it closes a five-message run or is a run of one
/// standing on its own — meaning the bubble's bottom edge: inside the row,
/// "bottom" would be the bottom of the timestamp, dropping the face a line
/// and a half below the bubble it belongs to. Everything outside the row is
/// instead indented by the avatar's width so it still lines up with the
/// bubble.
/// How far hanging reaction badges sit in from the bubble's body edge.
const double _kReactionInset = 10;

class _BubbleLayout extends StatelessWidget {
  const _BubbleLayout({
    required this.isMine,
    required this.showAvatarSlot,
    required this.senderName,
    required this.avatar,
    required this.bubble,
    required this.reactions,
    required this.meta,
    this.tailGutter = 0,
    this.nameColor,
  });

  final bool isMine;
  final bool showAvatarSlot;
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

  /// The ink [senderName] is written in. Null keeps the accent every sender
  /// used to share — a DM, a room with speaker colours off, or a sender who is
  /// no longer a member and so has no colour of their own.
  final Color? nameColor;

  @override
  Widget build(BuildContext context) {
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
          // +4 matches _MetaRow's own inset, so the name and the timestamp
          // bracketing the run sit on the same line. The tail gutter joins
          // in for incoming bubbles, where the body starts a hook's width in.
          _SenderNameLabel(
            name: name,
            color: nameColor,
            left: leadingIndent + 4 + (isMine ? 0 : tailGutter),
          ),
        Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          // Always the bubble's bottom edge — the face closes whatever block
          // it belongs to, whether that block is a five-message run or a
          // run of one standing on its own.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (leads) ...[avatar, const SizedBox(width: 8)],
            Flexible(child: bubble),
          ],
        ),
        // Hung off the bubble's bottom edge, WhatsApp's way, rather than sat
        // in a row of their own beneath it — see [HangingReactions], which is
        // why the inset is INSIDE it rather than a Padding around it. Inset
        // from the body's edge on the sender's side, so the badges tuck under
        // the bubble's corner instead of lining up flush with it.
        if (reactions != null)
          HangingReactions(
            child: Padding(
              // The 4 underneath is the air a hanging badge needs from the
              // next bubble: inside a run that gap is only 2, and a badge
              // nearly touching the bubble below read as belonging to it.
              padding: EdgeInsets.only(
                left: leadingIndent +
                    (isMine ? 0 : tailGutter + _kReactionInset),
                right: isMine ? tailGutter + _kReactionInset : 0,
                bottom: 4,
              ),
              child: reactions,
            ),
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
bool messageStampsInline(ChatMessage message,
    {required bool showLinkUrls, bool ephemeral = false}) {
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
    case MessageType.videoNote:
      // The one media shape with nowhere to tuck a stamp: a round tile has no
      // bottom-right corner to lay one over, and a lozenge floating beside the
      // circle's edge reads as a detached label rather than part of the bubble.
      // It keeps the external timestamp row, the same as a bare error plate.
      return false;
    case MessageType.poll:
    case MessageType.checklist:
    case MessageType.event:
      // The card owns its stamp, but not by laying one over a filled corner the
      // way a photo does — it has a footer row of its own with room at the end
      // of it. See `_Footer` in `interaction_bubble.dart` for why: this edge
      // already carries text, and a lozenge floating over a percentage is the
      // kind of overlap that only looks right on the one string it was checked
      // against. Either way the answer here is the same — inline, no external
      // row.
      return true;
    case MessageType.text:
    case MessageType.url:
      // A jumbo emoji has no bubble to tuck a stamp into and nothing opaque to
      // lay one over — see [JumboEmojiBubble], which reads the same condition.
      if (messageJumboEmoji(message, ephemeral: ephemeral) != null) return false;
      return !_isStandaloneLinkCard(message, showLinkUrls);
    // A GIF is a filled rectangle, so the stamp lays over its corner exactly
    // as it does on a photo — unless there is no picture to lay it on.
    case MessageType.gif:
      return message.expression != null;
    // A sticker is a cut-out floating on the transcript, the jumbo emoji's
    // shape: nothing opaque to lay a stamp over, so it keeps the external row.
    case MessageType.sticker:
      return false;
  }
}

/// The emoji run [message] should be drawn big and bare as, or null when it
/// should keep its bubble.
///
/// One reading of the condition for all three of the things that have to agree
/// about it: the content itself, the timestamp row (`messageStampsInline`) and
/// the highlight halo's outline ([pulseShapeFor]).
///
/// Two vetoes beyond "is it emoji", both about something the bubble is
/// carrying that the bare glyph could not:
///
///  * **Formatting.** A spoiler, a code span or a link entity over an emoji is
///    drawn by the text pipeline, veil and all. There is nothing to gain by
///    enlarging it and a working feature to lose.
///  * **Ephemeral.** The frame IS the affordance — it is the only thing on
///    screen saying this message will vanish, and it is what the dissolve
///    signature is painted into. A disappearing message keeps its bubble.
List<String>? messageJumboEmoji(ChatMessage message,
    {required bool ephemeral}) {
  if (ephemeral) return null;
  if (message.type != MessageType.text && message.type != MessageType.url) {
    return null;
  }
  if (message.formatting.isNotEmpty) return null;
  return jumboEmojiRun(message.content);
}

/// Exactly the condition [_LinkAwareBubble] picks its card-only mode on
/// (`hasUrls && !hasText`). One reading of it, so the bubble and the row beneath
/// it can never disagree about which of them owns the timestamp.
bool _isStandaloneLinkCard(ChatMessage message, bool showLinkUrls) {
  if (showLinkUrls) return false;
  final matches = UrlDetector.matches(message.content);
  if (matches.isEmpty) return false;
  return DisplayTransform.of(message.content, hidden: matches)
      .text
      .trim()
      .isEmpty;
}

/// The plate a picture message draws when it carries nothing to show — a GIF
/// or sticker row whose fields did not survive, the same shape as a photo
/// whose storage id never arrived.
Widget _missingPicturePlate(AppTheme theme, double width, BorderRadius radius) =>
    Container(
      width: width,
      height: 80,
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(CupertinoIcons.photo, color: theme.inkMuted),
    );

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

  /// A reply quote to draw at the top INSIDE the bubble ([ReplyStyle.quote]).
  /// Only text bubbles take it — see [quoteFitsInside]; every other shape
  /// ignores it and the caller draws the quote above instead.
  Widget? quote,
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

  /// Whether this viewer has bookmarked the message, which marks its stamp.
  /// See [MessageStamp.saved].
  bool saved = false,

  /// Whether the message is one of the room's pins. See [MessageStamp.pinned].
  bool pinned = false,

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

  /// The run of photographs this row stands for, oldest first, with [message]
  /// as the last of them. Two or more turns the photo case into a mosaic;
  /// anything less leaves it the single tile it has always been.
  List<ChatMessage> album = const [],
  Future<void> Function(ChatMessage m, {required int sourceDecodeWidth})?
      onAlbumOpen,
  void Function(ChatMessage m, GlobalKey anchor)? onAlbumTileLongPress,
  void Function(ChatMessage m, String emoji)? onAlbumReactionTap,
  void Function(ChatMessage m, String emoji)? onAlbumReactionLongPress,

  /// Which photograph of [album] a jump has landed on, and how far into its
  /// pulse it is. Null on the block a jump did not aim at — see
  /// [PhotoMosaic.highlightedPhotoId].
  String? albumHighlightId,
  double albumHighlightT = 0,

  /// The body of a poll, checklist or event — see [InteractionBubble]. Null on
  /// every other type, and also on an interactive one whose body has not
  /// arrived yet, which is an ordinary state rather than a gap.
  MessageInteraction? interaction,

  /// What the transcript can do to that card. One object rather than six
  /// callbacks, built once per room — see [InteractionActions].
  InteractionActions interactionActions = InteractionActions.none,
}) {
  // Who is talking, painted into the bubble itself rather than only into the
  // name above it. A run of five messages prints its sender's name once, and
  // without this the four bubbles under that name carry no identity at all —
  // which is the whole complaint group rooms have about coloured usernames.
  //
  // Outgoing bubbles are left alone: they are filled with the accent, sit on
  // the other margin, and never show a name. There is nothing left to
  // disambiguate.
  final authored =
      theme.messageBubbleDecoration(isMine: isMine, ephemeral: ephemeral);
  final authoredFill = authored.color;
  final speakerFill = (isMine || authoredFill == null)
      ? null
      : SpeakerScope.washOf(context, message.senderId, surface: authoredFill);
  final deco = theme.bubbleDecoration(
    isMine: isMine,
    ephemeral: ephemeral,
    style: bubbleStyle,
    firstInRun: firstInRun,
    lastInRun: lastInRun,
    fill: speakerFill,
    // Only ever handed over alongside a fill, so a reader who asked for names
    // alone never gets a recoloured border out of it.
    edge: speakerFill == null
        ? null
        : SpeakerScope.markOf(context, message.senderId, on: authoredFill!),
  );
  final imageSize = metrics?.mediaMaxWidth ?? ChatMetrics.mediaMin;

  final hasCaption = message.content.isNotEmpty;
  // Media messages render as a rounded media tile WITHOUT a surrounding
  // bubble — alignment in the parent row conveys mine/theirs the way
  // iMessage's photo bubbles do. A bubble frame around a photograph reads
  // as visual noise and clashes with whatever the photo's content is.
  final mediaRadius = BorderRadius.circular(theme.radiusLg);
  // Square inside a captioned bubble, because there the FRAME owns the
  // corners: `_captionedAttachment` clips the whole column to the bubble's
  // shape, and a tile that also rounded itself would leave the bubble's fill
  // showing in four little arcs behind the photograph.
  final tileRadius = hasCaption ? BorderRadius.zero : mediaRadius;

  // Reading SettingsStore here is reactive: both bubble variants already wrap
  // their whole row in an AnimatedBuilder on it, for the bubble-shape
  // preference.
  final inline = messageStampsInline(
    message,
    showLinkUrls: SettingsStore.instance.showLinkUrls,
    ephemeral: ephemeral,
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
          saved: saved,
          pinned: pinned,
          edited: message.edited,
          tone: tone,
        )
      : null;
  // Every branch that draws its own ink already maps mine→accentInk and
  // theirs→ink; the stamp reads the same mapping, so it can never end up
  // accent-on-accent.
  final bubbleTone = isMine ? StampTone.onAccent : StampTone.onBubble;

  // Before every per-type branch. An album is only ever built from
  // captionless, un-sealed, un-quoted photographs and videos
  // (`albumEligible`), so none of the cases below can apply to one; the row
  // is drawn as its LAST member, which may be either, so it cannot live inside
  // the image case. And the album has to own the stamp, because the block's
  // corner is a card's corner rather than this message's own tile.
  if (album.length > 1) {
    return _AlbumTile(
      photos: album,
      api: api,
      width: imageSize,
      radius: mediaRadius,
      currentUserId: currentUserId ?? '',
      onOpen: onAlbumOpen,
      onTileLongPress: onAlbumTileLongPress,
      onReactionTap: onAlbumReactionTap,
      onReactionLongPress: onAlbumReactionLongPress,
      highlightedPhotoId: albumHighlightId,
      highlightT: albumHighlightT,
      stamp: stampFor(StampTone.onMedia),
    );
  }

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
          radius: tileRadius,
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
          radius: tileRadius,
          stamp: hasCaption ? null : stampFor(StampTone.onMedia),
          onRetrySend: onRetrySend,
          onDiscardSend: onDiscardSend,
        );
      } else if (id != null) {
        imageTile = _ImageTile(
          message: message,
          incoming: !isMine,
          storageId: id,
          api: api,
          width: imageSize,
          radius: tileRadius,
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
            borderRadius: tileRadius,
          ),
          alignment: Alignment.center,
          child: Icon(CupertinoIcons.photo, color: theme.inkMuted),
        );
      }
      if (!hasCaption) return imageTile;
      return _captionedAttachment(
        context: context,
        theme: theme,
        message: message,
        isMine: isMine,
        deco: deco,
        tile: imageTile,
        stamp: stampFor(bubbleTone),
        currentUserId: currentUserId,
        onMentionTap: onMentionTap,
      );
    // Bare, like a photo: no bubble frame around a picture. `content` is the
    // alt text, never a caption, so there is no captioned variant.
    case MessageType.gif:
      final gif = message.expression;
      if (gif == null) return _missingPicturePlate(theme, imageSize, mediaRadius);
      return GifMessageTile(
        item: gif,
        maxWidth: imageSize,
        radius: mediaRadius,
        stamp: stampFor(StampTone.onMedia),
        onTap: () => showExpressionSheet(context, gif),
      );
    case MessageType.sticker:
      final sticker = message.expression;
      if (sticker == null) {
        return _missingPicturePlate(theme, kStickerMessageSize, mediaRadius);
      }
      return StickerMessage(
        item: sticker,
        api: api,
        onTap: () => showExpressionSheet(context, sticker),
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
      // See [bubbleMediaHeroTag] for why a video's tag is deliberately not
      // the photo bubble's.
      final videoHeroTag = useHero ? bubbleMediaHeroTag(message) : null;
      final videoTile = StampedMedia(
        tile: ClipRRect(
          borderRadius: tileRadius,
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
                            // The chat's photos and videos, so the OS player
                            // swipes through them. Null outside a room.
                            gallery: RoomGalleryScope.maybeOf(context)
                                ?.videoGalleryFor
                                ?.call(message),
                          ),
                ),
        ),
        stamp: hasCaption ? null : stampFor(StampTone.onMedia),
      );
      if (!hasCaption) return videoTile;
      return _captionedAttachment(
        context: context,
        theme: theme,
        message: message,
        isMine: isMine,
        deco: deco,
        tile: videoTile,
        stamp: stampFor(bubbleTone),
        currentUserId: currentUserId,
        onMentionTap: onMentionTap,
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
              message: message,
            );
      final hasFileCaption = message.content.isNotEmpty;
      // With a caption the stamp belongs to the caption block, exactly as it
      // does for an image or a video — two stamps, or one on the wrong block,
      // is what splitting them any other way produces.
      final fileStamp = hasFileCaption ? null : stampFor(bubbleTone);
      // No `deco` when there is a caption: `_captionedAttachment` paints the
      // frame, and painting it here as well is the same fill twice — visibly
      // darker on any translucent theme, and a second border on the ones that
      // draw an edge.
      final fileTile = Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
        decoration: hasFileCaption ? null : deco,
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
      return _captionedAttachment(
        context: context,
        theme: theme,
        message: message,
        isMine: isMine,
        deco: deco,
        tile: fileTile,
        stamp: stampFor(bubbleTone),
        currentUserId: currentUserId,
        onMentionTap: onMentionTap,
      );
    case MessageType.videoNote:
      // Everything about the circle lives in `video_note_message.dart`, the way
      // audio and documents already live in files of their own. One branch here
      // and nothing else in this file knows the shape exists.
      final noteUpload = message.upload;
      final noteSize = math.min(metrics?.videoMaxWidth ?? 200.0, 200.0);
      if (noteUpload != null) {
        return ValueListenableBuilder<double?>(
          valueListenable: noteUpload.progress,
          builder: (context, value, _) => OutboundVideoNote(
            theme: theme,
            diameter: noteSize,
            failed: message.status == MessageStatus.error,
            progress: value,
            posterBytes: noteUpload.posterBytes,
            onRetry: onRetrySend,
            onDiscard: onDiscardSend,
          ),
        );
      }
      return VideoNoteMessage(
        api: api,
        storageId: message.mediaStorageId,
        isMine: isMine,
        posterStorageId: message.posterStorageId,
        durationMs: message.mediaDurationMs,
        diameter: noteSize,
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
    case MessageType.poll:
    case MessageType.checklist:
    case MessageType.event:
      // No bubble frame, matching the media tiles and the location card above:
      // this is a piece of furniture with controls on it, and a chat bubble
      // drawn around it would be a frame around a frame. The card paints its
      // own ground and border.
      //
      // [interaction] is nullable here and null is ordinary rather than an
      // error — the transcript and the interaction subscription land
      // independently, and the message usually arrives first. The card renders
      // its prompt from `message.content` either way. See the header on
      // [InteractionBubble].
      return InteractionBubble(
        theme: theme,
        message: message,
        interaction: interaction,
        isMine: isMine,
        width: imageSize,
        radius: mediaRadius,
        // `onBubble`/`onAccent`, not `onMedia`: the stamp sits in the card's own
        // footer row against a theme surface, not laid over a picture.
        stamp: stampFor(StampTone.onBubble),
        actions: interactionActions,
        currentUserId: currentUserId,
      );
    case MessageType.url:
    case MessageType.text:
      final jumbo = messageJumboEmoji(message, ephemeral: ephemeral);
      if (jumbo != null) {
        return JumboEmojiBubble(
          // The client id, not the row id: an optimistic send swaps `id` the
          // instant the server confirms it, and the entrance is spent per
          // message, not per row. See [JumboEmojiBubble].
          identity: message.clientId ?? message.id,
          clusters: jumbo,
          isMine: isMine,
        );
      }
      return _LinkAwareBubble(
        theme: theme,
        message: message,
        isMine: isMine,
        // Never a Chamber of Secrets message or a view-once one: both are
        // things the sender chose NOT to leave lying around, and a selection
        // is one ⌘C away from a copy. Spoilers are refused inside, per text.
        selectable: !ephemeral && !message.viewOnce,
        quote: quote,
        decoration: deco,
        stamp: stampFor(bubbleTone),
        currentUserId: currentUserId,
        onMentionTap: onMentionTap,
        // Naming someone in a group is the second half of "who is this" — the
        // first is who wrote the message, and a mention that arrives in the
        // mentioned person's own colour answers both in one glance.
        //
        // Incoming bubbles only, and resolved against the fill this bubble
        // actually paints (wash included), not against the theme's untinted
        // one. An outgoing bubble IS the accent, and a hue laid over a
        // saturated fill fights it instead of reading against it — the same
        // reasoning that already sends mentions to `linkInk` there.
        mentionTint: (isMine || authoredFill == null)
            ? null
            : (userId) => SpeakerScope.inkOf(
                  context,
                  userId,
                  on: speakerFill ?? authoredFill,
                ),
      );
  }
}

/// Most link cards stacked under one caption. Matches `_LinkAwareBubble`'s own
/// limit, for the same reason: two is already a tall bubble and the third is
/// always the one nobody reads.
const int _kMaxCaptionPreviews = 2;

/// ONE bubble holding an attachment, the words under it, and any links those
/// words carry.
///
/// This used to be two. The attachment was a tile, the caption was a second
/// rounded container four points below it, and a photo with a sentence
/// attached rendered as a pair of bubbles from the same person at the same
/// second — which reads as two messages, because in this app two bubbles IS
/// two messages. Every chat app that carries captions draws them inside the
/// frame; this does too now.
///
/// Three things have to line up for that to work and all three are handed in
/// rather than decided here:
///
///  * **the tile brings no corners of its own.** `clipBehavior` on this
///    container rounds the attachment to the bubble's shape — including its
///    tail — so a tile that also rounded itself would leave the bubble's fill
///    showing in four little arcs. Callers pass `BorderRadius.zero` (see
///    `tileRadius`).
///  * **the tile brings no decoration of its own.** The document row used to
///    carry `deco` itself; inside the frame that is the same fill painted
///    twice, which on a translucent theme is visibly darker.
///  * **the stamp belongs to the caption.** It is the bottom-right corner of
///    the bubble now, and the caption is what ends there.
///
/// [CrossAxisAlignment.stretch] is what makes it read as one object: the
/// caption and the preview cards take the attachment's width instead of
/// hugging their own text, so the bubble has one edge rather than three.
Widget _captionedAttachment({
  required BuildContext context,
  required AppTheme theme,
  required ChatMessage message,
  required bool isMine,
  required Decoration deco,
  required Widget tile,
  required MessageStamp? stamp,
  String? currentUserId,
  void Function(String userId)? onMentionTap,
}) {
  final showUrls = SettingsStore.instance.showLinkUrls;
  final urls = UrlDetector.extract(message.content);

  // Whether to fold the bare URLs out of the caption, as the text bubble does
  // when `showLinkUrls` is off.
  //
  // Only when something is LEFT once they are gone, and that condition is the
  // whole of the rule. A text message that is nothing but a link drops its
  // bubble entirely and becomes the preview card — see `_LinkAwareBubble`'s
  // card-only mode, and `messageStampsInline`, which moves the timestamp to a
  // row underneath in exactly that case. An attachment cannot do either: the
  // bubble is already there holding a photograph, and this message's type says
  // its stamp is inline. Folding a caption away to nothing would leave an
  // empty padded row with the timestamp sitting in it.
  //
  // So a caption of "look at this https://…" renders as "look at this" with a
  // card under it, and a caption of just "https://…" keeps its link, visible
  // and tappable, with the card under that. Which is also what the sender
  // typed, so it is no lie either way.
  final hidden = showUrls ? const <UrlMatch>[] : UrlDetector.matches(message.content);
  final folded = DisplayTransform.of(message.content, hidden: hidden).text;
  final hideAutoUrls = hidden.isNotEmpty && folded.trim().isNotEmpty;

  return Container(
    decoration: deco,
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        _captionBody(
          theme,
          message.content,
          isMine,
          stamp: stamp,
          mentionHandles: message.mentionHandles,
          mentionsEveryone: message.mentionsEveryone,
          currentUserId: currentUserId,
          onMentionTap: onMentionTap,
          formatting: message.formatting,
          spoilerContextId: message.id,
          hideAutoUrls: hideAutoUrls,
          onLinkTap: (url) => LinkOpener.open(context, url),
          // Qualified because it is a static on `_LinkAwareBubble` — shared
          // rather than copied, so a caption's link entity confirms through
          // exactly the sheet a text bubble's does.
          onLinkEntityTap: (url) =>
              _LinkAwareBubble._confirmAndOpenEntityLink(context, url),
        ),
        // Below the words, inside the frame — the same place and the same
        // `insideBubble` card the text bubble uses, so a link sent with a
        // photo and a link sent on its own look like the same feature.
        for (final url in urls.take(_kMaxCaptionPreviews))
          LinkPreviewCard(
            url: url,
            isMine: isMine,
            insideBubble: true,
            onTap: (u) => LinkOpener.open(context, u),
          ),
      ],
    ),
  );
}

/// A padded run of bubble text — an attachment's caption, or a system notice —
/// stamped when [stamp] is non-null.
///
/// The padding moves off the enclosing `Container` and in here, because the
/// stamp's `Positioned` has to live *inside* the padded box to measure from the
/// text's edge rather than the bubble's.
///
/// Routed through [LinkifiedText] rather than building its own `Text`: with no
/// URLs and no mentions that widget's fast path emits exactly the `Text` /
/// `Text.rich` this used to, so a system notice renders identically — while a
/// caption that carries mentions or links gets them through the same code the
/// text bubble uses, instead of a second span builder that would have to be
/// kept in step with it.
///
/// [onLinkTap] is what separates the two callers. A system notice passes null
/// and its URLs stay inert text, which is what they have always been. A
/// caption passes a handler, and its links become real: tappable, hideable
/// under `showLinkUrls`, and previewed by the cards
/// [_captionedAttachment] stacks underneath. They were dead text until then —
/// a link sent as a caption was the one place in this app where a URL was not
/// a link, which is exactly how an App Store link shared from the iOS
/// extension arrived: unclickable, unpreviewed, and sitting in a second bubble
/// below the file it came with.
Widget _captionBody(
  AppTheme theme,
  String text,
  bool isMine, {
  required MessageStamp? stamp,
  Map<String, String> mentionHandles = const {},
  bool mentionsEveryone = false,
  String? currentUserId,
  void Function(String userId)? onMentionTap,
  List<FormattingEntity> formatting = const [],
  String? spoilerContextId,

  /// Non-null turns the URLs in [text] into links. See the class doc.
  void Function(String url)? onLinkTap,

  /// Confirms before opening, for a link ENTITY whose visible words say
  /// nothing about its destination. Only consulted when [onLinkTap] is set.
  void Function(String url)? onLinkEntityTap,

  /// Folds bare URLs out of the rendered text, honouring
  /// `SettingsStore.showLinkUrls`. The fold lives in [LinkifiedText] because
  /// the formatting offsets index the ORIGINAL string.
  bool hideAutoUrls = false,
}) {
  const pad = EdgeInsets.fromLTRB(14, 10, 14, 10);
  final style = theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink);
  final linkAccent = theme.linkInk(isMine: isMine);
  final mentionStyle = style.copyWith(
      color: linkAccent, fontWeight: FontWeight.w600);
  final body = LinkifiedText(
    text: text,
    // trimRight so a caption ending in a newline doesn't push the stamp onto
    // a line of its own. Only when there IS a stamp — an unstamped caption kept
    // its trailing whitespace before and has no reason to stop.
    trimRight: stamp != null,
    style: style,
    linkifyUrls: onLinkTap != null,
    hideAutoUrls: hideAutoUrls,
    linkStyle: onLinkTap == null
        ? style
        : style.copyWith(
            color: linkAccent,
            decoration: TextDecoration.underline,
            decorationColor: linkAccent.withValues(alpha: 0.7),
          ),
    onLinkTap: onLinkTap ?? (_) {},
    onLinkEntityTap: onLinkEntityTap,
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
    formatting: formatting,
    codeStyle: theme.codeStyle(style),
    codeBackground: theme.codeBackground(isMine: isMine),
    codeBorder: theme.codeBorder(isMine: isMine),
    spoilerContextId: spoilerContextId,
    // onMedia: a caption's dust sits on a photograph, not on a bubble, so it
    // takes a fixed neutral rather than the theme's bubble ink.
    spoilerDust: theme.spoilerDust(isMine: isMine, onMedia: true),
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
                    const SizedBox(height: 6),
                    Text(
                      AppLocalizations.of(context)
                          .messageBubbleViewOncePhotoLabel,
                      // The body face at meta size, sentence case — never
                      // the theme's tracked `label` slot. The tile is a
                      // fixed height, so the pair stays at 13.
                      style: t.bodySoft.copyWith(
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _caption(context),
                      style: t.bodySoft.copyWith(
                        fontSize: 13,
                        height: 1.15,
                        letterSpacing: 0,
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
    required this.incoming,
    required this.storageId,
    required this.api,
    required this.width,
    required this.radius,
    required this.useHero,
    required this.stamp,
  });

  final ChatMessage message;

  /// Someone else sent it, so auto-download rules apply to it.
  final bool incoming;
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

/// A run of photographs as one block, with the row's stamp on it.
///
/// Its own widget for the one reason [_ImageTile] is: the stamp is a sibling of
/// the pictures rather than part of them, so while one of them is away being
/// looked at fullscreen the stamp would otherwise hang in the air over the hole
/// it left. A block's stamp sits in its bottom-trailing corner, which is a
/// TILE's corner — the very tile most likely to be the one that just flew.
class _AlbumTile extends StatefulWidget {
  const _AlbumTile({
    required this.photos,
    required this.api,
    required this.width,
    required this.radius,
    required this.currentUserId,
    required this.onOpen,
    required this.onTileLongPress,
    required this.onReactionTap,
    required this.onReactionLongPress,
    required this.highlightedPhotoId,
    required this.highlightT,
    required this.stamp,
  });

  final List<ChatMessage> photos;
  final ChatApi api;
  final double width;
  final BorderRadius radius;
  final String currentUserId;
  final Future<void> Function(ChatMessage m,
      {required int sourceDecodeWidth})? onOpen;
  final void Function(ChatMessage m, GlobalKey anchor)? onTileLongPress;
  final void Function(ChatMessage m, String emoji)? onReactionTap;
  final void Function(ChatMessage m, String emoji)? onReactionLongPress;
  final String? highlightedPhotoId;
  final double highlightT;
  final MessageStamp? stamp;

  @override
  State<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<_AlbumTile> {
  /// True for the length of a fullscreen round trip, exactly as in
  /// [_ImageTileState].
  bool _viewing = false;

  Future<void> _open(ChatMessage m, {required int sourceDecodeWidth}) async {
    final Future<void> trip;
    final videoId = m.mediaStorageId;
    if (m.type == MessageType.video) {
      // A video plays, exactly as a lone video bubble's tap does, flying from
      // the card's poster. Not into the photo gallery, whose video pages are a
      // poster to tap a second time.
      if (videoId == null) return;
      trip = FullscreenVideoViewer.open(
        context,
        storageId: videoId,
        api: widget.api,
        posterStorageId: m.posterStorageId,
        heroTag: mosaicHeroTag(m),
        gallery: RoomGalleryScope.maybeOf(context)?.videoGalleryFor?.call(m),
      );
    } else {
      // The gallery scope is the same fallback a lone photo's tile takes when
      // no caller handed it an opener.
      final open =
          widget.onOpen ?? RoomGalleryScope.maybeOf(context)?.openGallery;
      if (open == null) return;
      trip = open(m, sourceDecodeWidth: sourceDecodeWidth);
    }
    setState(() => _viewing = true);
    try {
      await trip;
    } finally {
      if (mounted) setState(() => _viewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stamp = _viewing ? null : widget.stamp;
    // Cards or grid, from Settings. Listened to here rather than up the
    // transcript: only albums change shape when it flips.
    return ListenableBuilder(
      listenable: SettingsStore.instance,
      builder: (context, _) {
        if (SettingsStore.instance.albumCards) {
          // The count label sits over the deck, the stamp on the front card:
          // only the deck itself goes under [StampedMedia].
          return PhotoDeck(
            photos: widget.photos,
            api: widget.api,
            width: widget.width,
            radius: widget.radius,
            currentUserId: widget.currentUserId,
            onOpen: _open,
            onTileLongPress: widget.onTileLongPress,
            onReactionTap: widget.onReactionTap,
            onReactionLongPress: widget.onReactionLongPress,
            highlightedPhotoId: widget.highlightedPhotoId,
            highlightT: widget.highlightT,
            stamp: stamp,
          );
        }
        return StampedMedia(
          tile: PhotoMosaic(
            photos: widget.photos,
            api: widget.api,
            width: widget.width,
            radius: widget.radius,
            currentUserId: widget.currentUserId,
            onOpen: _open,
            onTileLongPress: widget.onTileLongPress,
            onReactionTap: widget.onReactionTap,
            onReactionLongPress: widget.onReactionLongPress,
            highlightedPhotoId: widget.highlightedPhotoId,
            highlightT: widget.highlightT,
          ),
          stamp: stamp,
        );
      },
    );
  }
}

/// The [Hero] tag the transcript's bubble for [message] flies under.
///
/// Public and shared because the fullscreen gallery has to build the SAME
/// string to have anywhere to fly from: it is handed a list of messages, not a
/// list of widgets, and a tag it guessed differently is a tag that matches
/// nothing and degrades silently to a cross-fade.
///
/// A photo and a video get deliberately different prefixes. They are never the
/// same message, but the shared-content grid flies these ids under a prefix of
/// its own, and two heroes sharing a tag across routes that both join one
/// flight is an assertion rather than a graceful degrade.
Object bubbleMediaHeroTag(ChatMessage message) =>
    message.type == MessageType.video
        ? 'msg-video-${message.id}'
        : 'msg-image-${message.id}';

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

  Object get _heroTag => bubbleMediaHeroTag(widget.message);

  /// Opens this photograph fullscreen.
  ///
  /// The gallery when there is a conversation behind it, and a lone viewer when
  /// there is not. Both are a round trip, and both hide the stamp for its
  /// duration — see [_viewing].
  Future<void> _openViewer() async {
    final gallery = RoomGalleryScope.maybeOf(context);
    // The decode this tile is already painting from. Handed over both ways —
    // the gallery has no way to work it out, and without it the picture it
    // flies is a decode nobody has asked for yet, which is a shimmer.
    final decode = thumbnailDecodeWidth(context, widget.width);
    setState(() => _viewing = true);
    try {
      if (gallery != null) {
        await gallery.openGallery(widget.message, sourceDecodeWidth: decode);
        return;
      }
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
        thumbnailDecodeWidth: decode,
        // Share and Save on the lone viewer too.
        message: widget.message,
      );
    } finally {
      if (mounted) setState(() => _viewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = ChatMetrics.mediaTileHeight(widget.width, _aspect);
    final Widget remote = AutoDownloadGate(
      storageId: widget.storageId,
      roomId: widget.message.roomId,
      incoming: widget.incoming,
      borderRadius: widget.radius,
      child: RemoteImage(
        storageId: widget.storageId,
        api: widget.api,
        width: widget.width,
        height: height,
        borderRadius: widget.radius,
        // Only when there is something to learn. Measuring resolves an image
        // stream per tile, and a transcript full of photos would pay that on
        // every one of them to be told what the sender already said.
        onAspectRatio: _aspect == null ? _onAspect : null,
      ),
    );
    return GestureDetector(
      onTap: _openViewer,
      child: StampedMedia(
        tile: widget.useHero
            ? SteadyHero(
                tag: _heroTag,
                // The tile settles what the flight looks like, in both
                // directions — see [mediaFlightShuttle]. It matters less here
                // than on an album's hard square crop, because a lone tile is
                // laid out at the picture's own ratio and so has little crop to
                // animate; the corners and the warm decode are the whole of it.
                flightShuttleBuilder: mediaFlightShuttle(
                  image: RemoteImage(
                    storageId: widget.storageId,
                    api: widget.api,
                    borderRadius: BorderRadius.zero,
                    decodeWidth:
                        thumbnailDecodeWidth(context, widget.width),
                  ),
                  radius: widget.radius,
                ),
                child: remote,
              )
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
                  child: Icon(CupertinoIcons.photo, color: theme.inkMuted),
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
              icon: CupertinoIcons.arrow_clockwise,
              semanticLabel: AppLocalizations.of(context)
                  .messageBubbleRetrySendingSemanticLabel,
              onTap: onRetry == null ? null : () => onRetry!(),
            ),
            const SizedBox(width: 4),
            _UploadControl(
              icon: CupertinoIcons.xmark,
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
    // The face is the one part of a row that is unmistakably one person, so the
    // ring is where the colour and the person get introduced to each other. It
    // is also what makes the colour legible to a reader who cannot tell two
    // hues apart: the ring is always around the same face.
    //
    // Ringed against the theme's ground rather than the bubble's, because that
    // is what a 28px circle out in the margin actually sits on.
    final theme = ThemeScope.of(context);
    final ring = SpeakerScope.markOf(context, user.id, on: theme.background);
    return GestureDetector(
      onTap: onTap,
      child: UserAvatar(
        user: user,
        size: _size,
        api: api,
        showStatus: false,
        ring: ring != null,
        ringColor: ring,
      ),
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
    this.quote,
    required this.decoration,
    required this.stamp,
    this.currentUserId,
    this.onMentionTap,
    this.mentionTint,
    this.selectable = false,
  });

  final AppTheme theme;
  final ChatMessage message;
  final bool isMine;

  /// Whether the words may be drag-selected on a pointer platform. See
  /// [_SelectableMessageText] for what else has to hold.
  final bool selectable;
  final String? currentUserId;
  final void Function(String userId)? onMentionTap;

  /// The colour to write a mention OF [userId] in, or null to leave it in the
  /// bubble's own mention ink. See the call site for why outgoing bubbles pass
  /// null outright.
  final Color? Function(String userId)? mentionTint;

  /// Tucked into the text block's bottom-trailing corner. Null for the
  /// card-only mode below, which has no bubble of its own — see
  /// [messageStampsInline], which reads the same condition so the external row
  /// takes over for exactly those messages.
  final MessageStamp? stamp;

  /// A `ShapeDecoration` in practice — the tail cannot be expressed by a
  /// `BoxDecoration`. `Container` still clips to it (`getClipPath`) and still
  /// adds its `padding`, which is where the tail's gutter comes from.
  final Decoration decoration;

  /// The reply quote block, first thing inside the bubble. Null for a
  /// non-reply or any other reply style.
  final Widget? quote;

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
        // messages read with awkward gaps where the URL used to be. The
        // rewrite itself lives in `DisplayTransform` (text_runs.dart) so the
        // message's stored formatting offsets are MAPPED through it rather
        // than broken by it; this call only answers "is there any text left",
        // which decides the card-only branch below.
        final displayText = showUrls
            ? message.content
            : DisplayTransform.of(
                message.content,
                hidden: UrlDetector.matches(message.content),
              ).text;
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
        // Lifted into FormattingSurface.linkInk so the formatting layer draws
        // links with the exact same derivation; see the extension for the
        // accent-on-accent history.
        final linkAccent = theme.linkInk(isMine: isMine);

        final stamp = this.stamp;
        // iMessage proportions: a one-line bubble lands near 36pt tall at a 17pt
        // body. The old 14/10 made every line a slab, and a run of short
        // replies read as a stack of buttons.
        final textPad = EdgeInsets.fromLTRB(12, 7, 12, hasUrls ? 6 : 7);
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
        final baseStyle = theme.body.copyWith(color: inkColor);
        final body = LinkifiedText(
          // The ORIGINAL content — the fold owns both rewrites (URL hiding
          // and the trailing-whitespace trim that keeps the stamp off a line
          // of its own), because the formatting offsets index this string.
          text: message.content,
          hideAutoUrls: !showUrls,
          trimRight: true,
          style: baseStyle,
          linkStyle: theme.body.copyWith(
            color: linkAccent,
            decoration: TextDecoration.underline,
            decorationColor: linkAccent.withValues(alpha: 0.7),
          ),
          onLinkTap: (url) => LinkOpener.open(context, url),
          // A link ENTITY's visible words say nothing about its destination,
          // so it confirms before opening; bare URLs above keep their direct
          // open because their text IS the destination.
          onLinkEntityTap: (url) => _confirmAndOpenEntityLink(context, url),
          trailing: stamp == null ? null : stampSpacerSpan(stamp),
          mentionHandles: message.mentionHandles,
          mentionsEveryone: message.mentionsEveryone,
          selfUserId: currentUserId,
          mentionStyle: mentionStyle,
          selfMentionStyle: selfMentionStyle,
          mentionTint: mentionTint,
          onMentionTap: onMentionTap,
          formatting: message.formatting,
          codeStyle: theme.codeStyle(baseStyle),
          codeBackground: theme.codeBackground(isMine: isMine),
          codeBorder: theme.codeBorder(isMine: isMine),
          spoilerContextId: message.id,
          spoilerDust: theme.spoilerDust(isMine: isMine),
        );

        final column = Column(
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
            crossAxisAlignment: hasUrls || quote != null
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (quote != null)
                Padding(
                  // Inset so its corners sit concentric inside the bubble's.
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                  child: quote,
                ),
              if (hasText)
                if (stamp == null)
                  Padding(
                      padding: textPad, child: _selectableOr(context, body))
                else
                  StampedTextBlock(
                      stamp: stamp,
                      padding: textPad,
                      child: _selectableOr(context, body)),
              if (hasUrls)
                for (final url in urls.take(_maxPreviews))
                  LinkPreviewCard(
                    url: url,
                    isMine: isMine,
                    insideBubble: true,
                    onTap: (u) => LinkOpener.open(context, u),
                  ),
              // Last inside the bubble, under the previews as well as the
              // text. The whole original message — words, links, cards — reads
              // as one thing, and what it MEANS arrives after it. Draws
              // nothing at all until somebody asks; see [MessageTranslation]
              // for why it is safe to mount in every text bubble.
              MessageTranslation(message: message, isMine: isMine),
            ],
          );
        return Container(
          decoration: decoration,
          clipBehavior: Clip.antiAlias,
          // With a quote, the quote spans the bubble: the column is sized to
          // its widest child (quote or text) and then stretched to it, so a
          // short reply under a long quote widens to the quote, and a short
          // quote over a long reply reaches the bubble's edge. Paid only on
          // replies — everything else keeps the plain hugging column.
          // Not with link cards: they already stretch to the bubble's max, and
          // a card's intrinsic width is not a size worth asking it for.
          child: quote == null || hasUrls
              ? column
              : IntrinsicWidth(child: column),
        );
      },
    );
  }

  /// [body] made drag-selectable when this bubble and this platform allow
  /// it, and returned untouched otherwise. Gated on
  /// [isPhysicalKeyboardPlatform] rather than [isWebOrDesktop]: on a phone
  /// browser a long-press must still open the message menu, and a
  /// [SelectionArea] would take that press for itself. A spoiler anywhere in
  /// the text refuses the whole bubble: a selection paints straight through
  /// the veil, and copies what is under it.
  Widget _selectableOr(BuildContext context, Widget body) {
    if (!selectable || !isPhysicalKeyboardPlatform) return body;
    if (message.formatting.any((f) => f.type == FormattingType.spoiler)) {
      return body;
    }
    // A bubble drawn somewhere with no overlay (an offscreen capture) cannot
    // host a selection and does not need one.
    if (Overlay.maybeOf(context) == null) return body;
    return _SelectableMessageText(child: body);
  }

  /// Show the destination, then open only on an explicit yes. Extracted so
  /// the async gap has one owner and one `mounted` check.
  static Future<void> _confirmAndOpenEntityLink(
    BuildContext context,
    String url,
  ) async {
    final ok = await showLinkConfirmSheet(context, url: url);
    if (!ok || !context.mounted) return;
    LinkOpener.open(context, url);
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
  // A jumbo emoji is bare for the same reason a photo is: there is no bubble
  // under the halo, so the halo has to supply its own outline.
  final bare = message.type == MessageType.image ||
      message.type == MessageType.video ||
      message.type == MessageType.gif ||
      message.type == MessageType.sticker ||
      messageJumboEmoji(message, ephemeral: ephemeral) != null;
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
    this.saved = false,
    this.pinned = false,
  });
  final ChatMessage message;
  final bool isMine;
  final Duration? countdown;
  final bool seenByOthers;

  /// Whether anyone else's device is known to hold this yet — the second
  /// tick, below [seenByOthers] on the same ladder. See [MessageReceipt].
  final bool deliveredToOthers;

  /// See [MessageStamp.saved]. The fallback row carries the bookmark for the
  /// same two shapes it carries the clock for — a standalone link card has no
  /// surface of ours to mark either.
  final bool saved;

  /// See [MessageStamp.pinned]. Carried here for the same reason as [saved].
  final bool pinned;

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
        saved: saved,
        pinned: pinned,
        edited: message.edited,
        tone: StampTone.onSurface,
      ),
    );
  }
}

/// Drag-to-select for one bubble's words, iMessage-for-Mac style: the
/// selection lives inside the bubble and never runs across the transcript.
///
/// One [SelectionArea] per text bubble rather than one around the list, on
/// purpose. A list-wide area would select across bubbles that the lazy list
/// is free to unmount mid-drag, and it would also wrap every photo, poll and
/// view-once tile in a registrar they would each have to opt out of.
///
/// Its toolbar is switched off (`contextMenuBuilder: null`): a right-click on
/// the bubble opens the message menu, which the bubble's eager secondary-click
/// recognizer claims before the area ever sees the button.
///
/// ⌘C is overridden to copy PLAIN text. The paragraph carries a placeholder
/// for the timestamp's reserved space (see `stampSpacerSpan`), and a selection
/// that reaches the end of the message would otherwise put an object
/// replacement character on the clipboard.
class _SelectableMessageText extends StatefulWidget {
  const _SelectableMessageText({required this.child});

  final Widget child;

  @override
  State<_SelectableMessageText> createState() => _SelectableMessageTextState();
}

class _SelectableMessageTextState extends State<_SelectableMessageText> {
  SelectedContent? _selected;

  late final Map<Type, Action<Intent>> _actions = {
    CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
      onInvoke: (_) {
        final text = plainSelectionText(_selected?.plainText ?? '');
        if (text.isNotEmpty) Clipboard.setData(ClipboardData(text: text));
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: _actions,
      child: SelectionArea(
        contextMenuBuilder: null,
        onSelectionChanged: (c) => _selected = c,
        child: widget.child,
      ),
    );
  }
}

/// What a message selection puts on the clipboard: the words, without the
/// placeholder characters inline widgets leave in a paragraph's text, and
/// without the trailing whitespace a selection to the end drags along.
@visibleForTesting
String plainSelectionText(String raw) =>
    raw.replaceAll('\uFFFC', '').trimRight();
