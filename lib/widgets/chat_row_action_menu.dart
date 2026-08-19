import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/message_preview.dart';
import '../theme/app_theme.dart';
import '../theme/interaction.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';
import 'glass_surface.dart';
import 'muted_badge.dart';
import 'pinned_badge.dart';
import 'remote_image.dart';
import 'room_identity.dart';
import 'typing_indicator.dart';
import 'user_avatar.dart';
import 'visibility_badge.dart';

enum ChatRowAction { pin, unpin, archive, unarchive, mute, unmute }

/// The hold that opens [showChatRowActionMenu] on a chat-list row.
///
/// Exists so that a chat row and a message bubble answer a finger on the same
/// beat and with the same buzz. Before this, the row was a bare
/// `GestureDetector.onLongPress` — the platform-default 500ms, silent — while
/// the bubble had already been tuned to [kActionMenuLongPress] with a medium
/// impact, so the identical gesture felt a fifth of a second stickier and
/// deader on the list than in the transcript.
///
/// [RawGestureDetector] for the same reason `message_bubble.dart` reaches for
/// one: plain [GestureDetector] has no hook for the long-press duration.
///
/// Wrap the row, and give *this* widget the anchor [GlobalKey] the menu is
/// positioned against — its render object is the row's, so the lifted copy
/// still lands on the real row's exact rect.
class ChatRowLongPress extends StatelessWidget {
  const ChatRowLongPress({
    super.key,
    required this.onLongPress,
    required this.child,
  });

  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(duration: kActionMenuLongPress),
          (instance) => instance.onLongPress = () {
            // On the trigger, not once the overlay has finished animating in:
            // the buzz is what tells a finger the hold took and it can let go.
            // Same impact weight as the bubble's (see room_screen.dart's
            // `onLongPress` and thread_overlay.dart's `_onLongPressBubble`).
            HapticFeedback.mediumImpact();
            onLongPress();
          },
        ),
      },
      child: child,
    );
  }
}

/// Long-press context menu for a chat-list row — iOS peek-and-pop, not a
/// swipe: a swipe-left gesture on a list row is already reserved (archive,
/// delete) in the wider vocabulary of list UIs, while "long-press lifts a
/// live preview above a row of options" is a pattern this app already uses
/// for message bubbles. Reusing it here rather than inventing a second
/// long-press language is the point.
///
/// Modeled on `message_action_menu.dart`'s `showMessageActionMenu` — same
/// anchor-then-root-overlay technique, same blurred scrim + lifted, in-focus
/// copy of the pressed item that a message bubble's long-press gets — but
/// deliberately smaller otherwise: no reaction pill, just a 1-2 row menu
/// below the lifted preview. Kept self-contained rather than sharing that
/// file's private widgets, since this menu's action set and positioning are
/// both much simpler.
///
/// [previewBuilder] builds a [ChatRowPreviewCard] for the lifted copy — the
/// same reason `showMessageActionMenu` takes a `bubbleBuilder` rather than a
/// snapshot: the root overlay sits outside the list, so there is nothing
/// already on screen at this rect it could borrow. Unlike a message bubble,
/// which already shows its full content at rest, a chat row is a compact
/// summary — one clipped line, a small avatar — so what gets lifted is not a
/// redraw of that same compact row but a richer card built from the same
/// underlying data: see [ChatRowPreviewCard].
///
/// [recentMessageCount] is how many messages [previewBuilder] will actually
/// render (capped at [ChatRowPreviewCard]'s own limit) — handed over
/// separately rather than inspected from the built widget so the overlay can
/// compute the card's height, and therefore where it and the menu land on
/// screen, the same way `actions.length` sizes the menu itself: from a
/// number, not a second measurement pass. Pass 0 when the room has no
/// messages resident in `ChatRepository` (see [ChatRowPreviewCard]'s doc for
/// why that's the common case, and why that's fine).
///
/// [isArchived] decides most of the row set: an archived room only offers
/// Unarchive — pinning something that's simultaneously archived-and-hidden
/// from the main list is a confusing combination not worth exposing, whether
/// this is opened from the main list or from the Archived Chats sheet.
///
/// Mute is the exception to that rule, and offered on an archived room too.
/// Archiving hides a chat from a list; it does not stop the chat pushing to a
/// locked phone, which is the thing someone reaching for this menu on an
/// archived room is most likely trying to stop. The pin/archive pairing is
/// confusing because both organise the same list; mute organises something
/// else entirely.
///
/// [canMute] comes from the room's capability table
/// (`lib/models/room_capabilities.dart`) and hides the row for the one kind of
/// room where a mute would provably do nothing.
Future<ChatRowAction?> showChatRowActionMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required WidgetBuilder previewBuilder,
  required int recentMessageCount,
  required bool isPinned,
  required bool isArchived,
  required bool isMuted,
  required bool canMute,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final anchorCtx = anchorKey.currentContext;
  if (anchorCtx == null) return null;
  final rb = anchorCtx.findRenderObject() as RenderBox?;
  if (rb == null || !rb.attached) return null;

  final topLeft = rb.localToGlobal(Offset.zero);
  final anchorRect = topLeft & rb.size;
  final screenSize = MediaQuery.sizeOf(context);
  final safeInsets = MediaQuery.paddingOf(context);

  final completer = Completer<ChatRowAction?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ChatRowActionMenuOverlay(
      anchorRect: anchorRect,
      previewBuilder: previewBuilder,
      recentMessageCount: recentMessageCount,
      screenSize: screenSize,
      safeInsets: safeInsets,
      isPinned: isPinned,
      isArchived: isArchived,
      isMuted: isMuted,
      canMute: canMute,
      onResolve: (result) {
        if (!completer.isCompleted) completer.complete(result);
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _ChatRowActionMenuOverlay extends StatefulWidget {
  const _ChatRowActionMenuOverlay({
    required this.anchorRect,
    required this.previewBuilder,
    required this.recentMessageCount,
    required this.screenSize,
    required this.safeInsets,
    required this.isPinned,
    required this.isArchived,
    required this.isMuted,
    required this.canMute,
    required this.onResolve,
  });

  final Rect anchorRect;
  final WidgetBuilder previewBuilder;

  /// See [showChatRowActionMenu]'s doc for why this is a bare count rather
  /// than something read off the built widget.
  final int recentMessageCount;
  final Size screenSize;
  final EdgeInsets safeInsets;
  final bool isPinned;
  final bool isArchived;
  final bool isMuted;
  final bool canMute;
  final ValueChanged<ChatRowAction?> onResolve;

  @override
  State<_ChatRowActionMenuOverlay> createState() =>
      _ChatRowActionMenuOverlayState();
}

class _ChatRowActionMenuOverlayState extends State<_ChatRowActionMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _closing = false;

  static const double _menuWidth = 220;
  static const double _rowHeight = 48;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resolve(ChatRowAction? result) async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onResolve(result);
  }

  List<ChatRowAction> get _actions => [
        if (!widget.isArchived)
          widget.isPinned ? ChatRowAction.unpin : ChatRowAction.pin,
        if (widget.canMute)
          widget.isMuted ? ChatRowAction.unmute : ChatRowAction.mute,
        widget.isArchived ? ChatRowAction.unarchive : ChatRowAction.archive,
      ];

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    final menuHeight = actions.length * _rowHeight + 12;
    final previewHeight = previewCardHeight(widget.recentMessageCount);

    // The card grows DOWN from where the row was pressed — the row already
    // read top-to-bottom, so its top edge is the one fixed point a reader's
    // eye already has. A card this much taller than the row it replaces can
    // easily push its own bottom edge, or the menu below it, past the safe
    // area on a row near the end of the list, so unlike the plain menu this
    // used to be (which only ever had to flip itself above a short anchor),
    // the whole card+menu GROUP shifts up as a unit to stay inside the band —
    // shifting rather than flipping keeps the card anchored under the finger
    // that pressed it instead of teleporting above it. Same idea as
    // `message_action_menu.dart`'s own band clamp, simplified here because
    // there is only ever the one candidate layout (below) to fit, never a
    // choice between two.
    const gap = 10.0;
    final minTop = widget.safeInsets.top + 12;
    final maxBottom = widget.screenSize.height - widget.safeInsets.bottom - 12;
    final groupHeight = previewHeight + gap + menuHeight;
    var previewTop = widget.anchorRect.top;
    if (previewTop + groupHeight > maxBottom) {
      previewTop = maxBottom - groupHeight;
    }
    if (previewTop < minTop) previewTop = minTop;
    final previewRect = Rect.fromLTWH(
      widget.anchorRect.left,
      previewTop,
      widget.anchorRect.width,
      previewHeight,
    );
    final menuTop = previewRect.bottom + gap;

    var left = widget.anchorRect.left;
    if (left + _menuWidth > widget.screenSize.width - 12) {
      left = widget.screenSize.width - _menuWidth - 12;
    }
    left = left.clamp(12.0, widget.screenSize.width - _menuWidth - 12);

    // Material(type: transparency) supplies the DefaultTextStyle that the
    // root overlay otherwise lacks — without it, every Text inside paints
    // Flutter's debug "missing ancestor" yellow underlines.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          children: [
            _Scrim(t: _ctrl, onTap: () => _resolve(null)),
            _LiftedRow(
              t: _ctrl,
              rect: previewRect,
              child: Builder(builder: widget.previewBuilder),
            ),
            Positioned(
              left: left,
              top: menuTop,
              width: _menuWidth,
              child: Opacity(
                opacity: _ctrl.value,
                child: Transform.translate(
                  offset: Offset(0, -8 * (1 - _ctrl.value)),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * _ctrl.value,
                    alignment: Alignment.topLeft,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: GlassSurface(
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final action in actions)
              _ChatRowActionRow(action: action, onTap: () => _resolve(action)),
          ],
        ),
      ),
      ),
    );
  }
}

// ───────────────────────── scrim ─────────────────────────

/// Blurs and dims everything behind the menu — the same treatment
/// `message_action_menu.dart`'s `_Scrim` gives a long-pressed message bubble,
/// so a long-pressed chat row reads as the same gesture with the same weight.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.t, required this.onTap});
  final Animation<double> t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: t,
          builder: (_, _) {
            return Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22 * t.value, sigmaY: 22 * t.value),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.32 * t.value),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ───────────────────────── lifted row ─────────────────────────

/// Positions [child] at [rect] and lifts it with a scale + shadow — the
/// chat-row counterpart of `message_action_menu.dart`'s `_LiftedBubble`. Sits
/// above [_Scrim] in the stack, so it alone stays in sharp focus while
/// everything else blurs. `IgnorePointer`-wrapped: it's a stand-in for the
/// real row, not a second interactive one — tapping it does nothing, same as
/// the lifted bubble.
///
/// [rect] is no longer the anchor row's own rect verbatim: the overlay grows
/// it downward from the row's top-left into the taller band
/// [ChatRowPreviewCard] needs, so [child] is a fresh, richer preview built at
/// that grown size rather than a redraw of the small row at its original
/// size — see `showChatRowActionMenu`'s doc for why.
class _LiftedRow extends StatelessWidget {
  const _LiftedRow({required this.t, required this.rect, required this.child});
  final Animation<double> t;
  final Rect rect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: t,
          builder: (_, c) {
            final scale = 1 + 0.03 * t.value;
            return Transform.scale(
              scale: scale,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18 * t.value),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: c,
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }
}

// ───────────────────────── preview card ─────────────────────────
//
// Fixed-height bands rather than measured content. `_ChatRowActionMenuOverlayState.build()`
// has to know this card's height BEFORE laying it out, to decide where the
// card and the menu below it land on screen — a card that sized itself to
// its content would need a measure-then-position pass that `Positioned`
// inside a `Stack` can't give it. [previewCardHeight] computes the same
// number [ChatRowPreviewCard] renders at, from the same inputs, the same way
// `_rowHeight * actions.length` already sizes the menu itself. Keep the two
// in sync: a badge row that wrapped to two lines, or a fourth cached message,
// would desync the overlay's math from what's actually on screen.
const double _previewPadding = 14;
const double _previewTopRowH = 22;
const double _previewAvatarSize = 48;
const double _previewIdentityRowH = 54;
const double _previewFooterRowH = 20;
const double _previewGap = 10;
const double _previewMessageLineH = 22;
const double _previewMessageGap = 4;
const double _previewFallbackBodyH = 84;

/// How many of a room's cached messages [ChatRowPreviewCard] will ever show
/// at once — see its class doc.
const int previewMaxMessages = 3;

/// The vertical band the card's body — either the cached-message list or the
/// full-text fallback — occupies for [messageCount] messages (capped at
/// [previewMaxMessages]). Shared between [previewCardHeight] and
/// [ChatRowPreviewCard] itself so the two can't drift apart.
double _previewBodyHeight(int messageCount) {
  if (messageCount <= 0) return _previewFallbackBodyH;
  final n = messageCount > previewMaxMessages ? previewMaxMessages : messageCount;
  return n * _previewMessageLineH + (n - 1) * _previewMessageGap;
}

/// The full height [ChatRowPreviewCard] will render at for [messageCount]
/// cached messages. See `showChatRowActionMenu`'s [recentMessageCount] doc
/// for why the overlay needs this ahead of building the card.
double previewCardHeight(int messageCount) =>
    _previewPadding * 2 +
    _previewTopRowH +
    _previewGap +
    _previewIdentityRowH +
    _previewGap +
    _previewBodyHeight(messageCount) +
    _previewGap +
    _previewFooterRowH;

/// The richer, long-press preview of a chat row: the same identity a
/// [RoomCard]/[RoomGridTile] already shows — avatar, name, badges, the last-
/// message stamp — grown into its own card, with the last message read in
/// full rather than clipped to the one line a compact row has room for, and,
/// when [recentMessages] has anything in it, the last few messages instead of
/// just the newest one.
///
/// [recentMessages] is deliberately not fetched by this widget, or by
/// anything it calls. It is exactly what `ChatRepository.messagesFor(room.id)`
/// already holds in memory at press time — empty for the overwhelming
/// majority of rooms, which the viewer has not opened this session and whose
/// transcript was therefore never subscribed to, and a real (if partial)
/// transcript tail for one they have. A long-press preview that blocked on a
/// network round trip to fill itself in would turn a peek into a spinner, so
/// this never asks for more than what's already resident — see the callers in
/// `home_screen.dart` and `archived_chats_sheet.dart`, which slice
/// `messagesFor` down to the newest [previewMaxMessages] themselves before
/// handing it here. When the list is empty the card falls back to
/// `room.lastMessage` via [roomSubtitle] — the same server-computed preview
/// text the compact row already shows, just no longer clipped to one line.
///
/// Every band in [build] is a fixed height taken from the constants above —
/// see those for why.
class ChatRowPreviewCard extends StatelessWidget {
  const ChatRowPreviewCard({
    super.key,
    required this.room,
    required this.dmUser,
    required this.recentMessages,
    this.typists = const [],
    this.api,
  });

  final ChatRoom room;
  final ChatApi? api;

  /// For DM rooms, the other participant — same override [RoomCard] applies
  /// to the raw "dm:..." room name and its avatar.
  final ChatUser? dmUser;

  /// Oldest-to-newest. The caller should already have sliced this down to
  /// [previewMaxMessages] — see the class doc — but the body still takes only
  /// the first [previewMaxMessages] of whatever arrives, since that count is
  /// also what `previewCardHeight` sized the overlay's `Positioned` rect from.
  final List<ChatMessage> recentMessages;
  final List<ChatUser> typists;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final subtitle = roomSubtitle(context, room);
    // `Container` folds a `decoration`'s border width into the padding it
    // gives its child — border and background together would shrink this
    // card's content band by the current theme's border width (0.5 to 2,
    // depending on theme), overflowing the fixed height `previewCardHeight`
    // promised the overlay. `foregroundDecoration` paints the border after
    // layout instead, so the padding box stays exactly `_previewPadding`
    // regardless of which theme's border is active.
    final cardDecoration = theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false);
    return Container(
      padding: const EdgeInsets.all(_previewPadding),
      decoration: BoxDecoration(
        color: cardDecoration.color,
        borderRadius: cardDecoration.borderRadius,
        boxShadow: cardDecoration.boxShadow,
      ),
      foregroundDecoration: BoxDecoration(
        border: cardDecoration.border,
        borderRadius: cardDecoration.borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _previewTopRowH,
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!room.isDm)
                        VisibilityBadge(isPublic: room.isPublic, dense: true),
                      if (room.isEphemeral && room.messageLifetime != null)
                        EphemeralBadge(ttl: room.messageLifetime!, dense: true),
                      if (room.hasPassword) const LockedBadge(dense: true),
                      if (room.isPinned) const PinnedBadge(dense: true),
                      if (room.isMuted)
                        MutedBadge(
                          dense: true,
                          silencesNotifications: room.notificationsMuted,
                          silencesCounts: room.badgesMuted,
                        ),
                    ],
                  ),
                ),
                Text(
                  room.lastMessageTime != null
                      ? roomTimeAgo(context, room.lastMessageTime!)
                      : l10n.roomCardStartedAgo(roomTimeAgo(context, room.createdAt)),
                  style: theme.monoTiny,
                ),
              ],
            ),
          ),
          const SizedBox(height: _previewGap),
          SizedBox(
            height: _previewIdentityRowH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _avatar(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    room.isSavedMessages
                        ? l10n.savedMessagesTitle
                        : (dmUser?.displayName ?? room.name),
                    style: room.hasUnread
                        ? theme.displayMedium.copyWith(fontWeight: FontWeight.w700)
                        : theme.displayMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.visibleUnreadCount > 0) ...[
                  const SizedBox(width: 8),
                  CountBadge(
                    count: room.visibleUnreadCount,
                    mention: room.hasVisibleMention,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: _previewGap),
          _body(theme, subtitle),
          const SizedBox(height: _previewGap),
          SizedBox(
            height: _previewFooterRowH,
            child: Row(
              children: [
                if (!room.isDm)
                  Text(l10n.roomCardMemberCount(room.memberCount), style: theme.caption),
                const Spacer(),
                if (room.isEphemeral)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      theme.hourglassIcon(size: 12, color: theme.accent),
                      const SizedBox(width: 6),
                      Text(
                        l10n.roomCardMessagesFadeLabel,
                        style: theme.monoTiny.copyWith(color: theme.accent),
                      ),
                    ],
                  )
                else
                  Text(l10n.roomCardEnterLabel, style: theme.monoTiny),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(AppTheme theme) {
    const size = _previewAvatarSize;
    if (room.isSavedMessages) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: theme.accentSoft, shape: BoxShape.circle),
        child: Icon(CupertinoIcons.bookmark_fill, size: 20, color: theme.accent),
      );
    }
    if (dmUser != null) {
      return UserAvatar(user: dmUser!, size: size, api: api);
    }
    if (room.avatarStorageId != null && api != null) {
      return ClipOval(
        child: RemoteImage(
          storageId: room.avatarStorageId!,
          api: api!,
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(size / 2),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider),
      ),
      child: room.isEphemeral
          ? theme.hourglassIcon(size: 22, color: theme.accent)
          : Icon(Icons.tag, size: 22, color: theme.accent),
    );
  }

  /// Typing beats everything else here, same priority [RoomCard] gives it:
  /// someone mid-sentence right now is more current than anything already
  /// sent. Otherwise the cached transcript tail when there is one, and the
  /// room's own last-message text — grown to four lines instead of one —
  /// when there isn't.
  Widget _body(AppTheme theme, RoomSubtitle subtitle) {
    if (typists.isNotEmpty) {
      return SizedBox(
        height: _previewBodyHeight(recentMessages.length),
        child: Align(alignment: Alignment.topLeft, child: TypingLine(typists: typists)),
      );
    }
    if (recentMessages.isNotEmpty) {
      return SizedBox(
        height: _previewBodyHeight(recentMessages.length),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // `.take` rather than trusting the caller's slice outright: this
            // is the one place a mismatch between what's iterated and what
            // `_previewBodyHeight` measured would show up as a RenderFlex
            // overflow rather than a silently-dropped message.
            for (final m in recentMessages.take(previewMaxMessages)) _messageLine(theme, m),
          ],
        ),
      );
    }
    return SizedBox(
      height: _previewFallbackBodyH,
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          subtitle.text,
          style: subtitle.kind == RoomSubtitleKind.message
              ? theme.bodySoft
              : theme.bodySoft.copyWith(color: theme.inkMuted),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// One cached message as "Name  content" — bold name, plain content, both
  /// in [AppTheme.bodySoft] — the same shape a group-chat notification
  /// summary uses, and enough on its own to tell two DM messages apart
  /// without borrowing the transcript's bubble-side alignment, which this
  /// flat list has no room for.
  Widget _messageLine(AppTheme theme, ChatMessage m) {
    final name = m.senderName.trim();
    return SizedBox(
      height: _previewMessageLineH,
      child: Text.rich(
        TextSpan(
          children: [
            if (name.isNotEmpty)
              TextSpan(
                text: '$name  ',
                style: theme.bodySoft.copyWith(fontWeight: FontWeight.w700, color: theme.ink),
              ),
            TextSpan(text: messagePreviewLine(m), style: theme.bodySoft),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ChatRowActionRow extends StatefulWidget {
  const _ChatRowActionRow({required this.action, required this.onTap});
  final ChatRowAction action;
  final VoidCallback onTap;

  @override
  State<_ChatRowActionRow> createState() => _ChatRowActionRowState();
}

class _ChatRowActionRowState extends State<_ChatRowActionRow> {
  bool _pressed = false;

  (IconData, String) _spec(AppLocalizations l10n) => switch (widget.action) {
    ChatRowAction.pin => (CupertinoIcons.pin, l10n.chatRowActionMenuPinLabel),
    ChatRowAction.unpin => (
      CupertinoIcons.pin_slash,
      l10n.chatRowActionMenuUnpinLabel,
    ),
    ChatRowAction.archive => (
      CupertinoIcons.archivebox,
      l10n.chatRowActionMenuArchiveLabel,
    ),
    ChatRowAction.unarchive => (
      CupertinoIcons.tray_arrow_up,
      l10n.chatRowActionMenuUnarchiveLabel,
    ),
    ChatRowAction.mute => (
      CupertinoIcons.bell_slash,
      l10n.chatRowActionMenuMuteLabel,
    ),
    ChatRowAction.unmute => (
      CupertinoIcons.bell,
      l10n.chatRowActionMenuUnmuteLabel,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final (icon, label) = _spec(AppLocalizations.of(context));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: _pressed ? theme.accentSoft : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: theme.label.copyWith(color: theme.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
