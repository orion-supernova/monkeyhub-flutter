import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/interaction.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';

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

/// Long-press context menu for a chat-list row.
///
/// Modeled on `message_action_menu.dart`'s `showMessageActionMenu` — same
/// anchor-then-root-overlay technique, same blurred scrim + lifted, in-focus
/// copy of the pressed item that a message bubble's long-press gets — but
/// deliberately smaller otherwise: no reaction pill, just a 1-2 row menu
/// anchored below (or above, near the bottom edge) the tapped row. Kept
/// self-contained rather than sharing that file's private row widgets, since
/// this menu's action set and positioning are both much simpler.
///
/// [rowBuilder] rebuilds the room's own row widget (`RoomCard`/
/// `RoomGridTile`) for the lifted copy — the same reason
/// `showMessageActionMenu` takes a `bubbleBuilder` rather than a snapshot: the
/// root overlay sits outside the list, so there is nothing already on screen
/// at this rect it could borrow, and rebuilding at the anchor's exact size is
/// what makes the lift look like it grew out of the real row rather than
/// spawning a second one.
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
  required WidgetBuilder rowBuilder,
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
      rowBuilder: rowBuilder,
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
    required this.rowBuilder,
    required this.screenSize,
    required this.safeInsets,
    required this.isPinned,
    required this.isArchived,
    required this.isMuted,
    required this.canMute,
    required this.onResolve,
  });

  final Rect anchorRect;
  final WidgetBuilder rowBuilder;
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

    // Prefer opening below the row; flip above it when there isn't room
    // before the bottom safe inset.
    final spaceBelow =
        widget.screenSize.height -
        widget.safeInsets.bottom -
        widget.anchorRect.bottom;
    final openBelow = spaceBelow >= menuHeight + 12;
    final top = openBelow
        ? widget.anchorRect.bottom + 6
        : (widget.anchorRect.top - menuHeight - 6).clamp(
            widget.safeInsets.top + 6,
            widget.screenSize.height,
          );

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
              rect: widget.anchorRect,
              child: Builder(builder: widget.rowBuilder),
            ),
            Positioned(
              left: left,
              top: top,
              width: _menuWidth,
              child: Opacity(
                opacity: _ctrl.value,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    (openBelow ? -1 : 1) * 8 * (1 - _ctrl.value),
                  ),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * _ctrl.value,
                    alignment: openBelow
                        ? Alignment.topLeft
                        : Alignment.bottomLeft,
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

/// A fresh copy of the pressed row, redrawn at its exact on-screen rect and
/// lifted with a scale + shadow — the chat-row counterpart of
/// `message_action_menu.dart`'s `_LiftedBubble`. Sits above [_Scrim] in the
/// stack, so it alone stays in sharp focus while everything else blurs.
/// `IgnorePointer`-wrapped: it's a stand-in for the real row, not a second
/// interactive one — tapping it does nothing, same as the lifted bubble.
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
