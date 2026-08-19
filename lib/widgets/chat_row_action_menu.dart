import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/message_preview.dart';
import '../theme/app_theme.dart';
import '../theme/interaction.dart';
import '../theme/layout.dart';
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

enum ChatRowAction {
  pin,
  unpin,
  archive,
  unarchive,
  mute,
  unmute,

  /// Not one of the menu's rows — resolved when the lifted preview card
  /// itself is tapped rather than one of the options below it. The same
  /// action the room's own row already offers on a plain tap; the preview
  /// existing at all shouldn't cost a reader that shortcut.
  open,
}

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
  const ChatRowLongPress({super.key, required this.onLongPress, required this.child});

  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
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
///
/// [onOpenRoom] is called directly by the overlay — not surfaced through the
/// returned Future the way pin/archive/mute are — when the lifted card
/// itself is tapped. Tapping the card commits to opening the room, and on
/// compact/medium windows that means growing the card into a full-screen
/// panel first (see `_ChatRowActionMenuOverlayState._beginOpen`); the callback
/// fires once that panel already covers the screen, so the real route
/// mounts invisibly underneath it rather than sliding in on top. On an
/// expanded (desktop) window there is no full-screen destination to grow
/// into — the room just replaces what's in the existing detail pane — so
/// there [onOpenRoom] fires immediately and the overlay simply closes.
/// Bind it to whatever the caller's own room-open helper is (see
/// `open_room.dart`'s `openRoom`); this file has no opinion on how a room
/// actually opens, only on when to ask for it.
Future<ChatRowAction?> showChatRowActionMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required WidgetBuilder previewBuilder,
  required bool isPinned,
  required bool isArchived,
  required bool isMuted,
  required bool canMute,
  required VoidCallback onOpenRoom,
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
      screenSize: screenSize,
      safeInsets: safeInsets,
      isPinned: isPinned,
      isArchived: isArchived,
      isMuted: isMuted,
      canMute: canMute,
      onOpenRoom: onOpenRoom,
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
    required this.screenSize,
    required this.safeInsets,
    required this.isPinned,
    required this.isArchived,
    required this.isMuted,
    required this.canMute,
    required this.onOpenRoom,
    required this.onResolve,
  });

  final Rect anchorRect;
  final WidgetBuilder previewBuilder;
  final Size screenSize;
  final EdgeInsets safeInsets;
  final bool isPinned;
  final bool isArchived;
  final bool isMuted;
  final bool canMute;
  final VoidCallback onOpenRoom;
  final ValueChanged<ChatRowAction?> onResolve;

  @override
  State<_ChatRowActionMenuOverlay> createState() => _ChatRowActionMenuOverlayState();
}

class _ChatRowActionMenuOverlayState extends State<_ChatRowActionMenuOverlay> with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// 0→1 over [_flying]'s duration: grows the card from its normal preview
  /// rect to the full screen, and its corner radius from the card's own down
  /// to square. See [_beginOpen].
  late final AnimationController _growCtrl;

  /// 0→1 once [_growCtrl] finishes: fades this WHOLE overlay out, revealing
  /// the real route [_beginOpen] pushed the instant the panel above finished
  /// covering the screen. See [_beginOpen].
  late final AnimationController _revealCtrl;
  bool _closing = false;

  /// True from the moment the card is tapped. Distinct from [_closing]: a
  /// flight commits to opening the room and runs to completion regardless —
  /// there is no reversing a "we're navigating" decision the way there is a
  /// plain dismiss, so every other gesture (scrim tap, menu rows) gets
  /// disabled the instant this flips.
  bool _flying = false;

  /// Built exactly once, on first use, and reused for the rest of this
  /// overlay's life — see where it's read in [build] for why. `late` rather
  /// than computed inline: it needs to survive being read from many frames
  /// across two different animations, not get rebuilt as a side effect of
  /// either one ticking.
  Widget? _previewContent;

  // The preview and the menu below it share one width — not the pressed
  // row's own. A row's rect is whatever the list laid it out at (a home-tab
  // GRID tile can be under 150 wide), and growing the lifted card to a
  // richer preview while still pinning it to that narrow width is what made
  // every band inside it cramped: badges wrapping, titles ellipsizing,
  // "6g"-style abbreviations standing in for text that had nowhere to sit.
  // A fixed, generous width — capped only by the screen itself — is what
  // Telegram/iMessage's own peek does: the card you get is sized to be read,
  // not to match whatever you happened to press.
  static const double _cardWidth = 320;
  static const double _rowHeight = 48;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _growCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _growCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolve(ChatRowAction? result) async {
    if (_closing || _flying) return;
    _closing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onResolve(result);
  }

  /// Tapping the lifted card commits to opening the room — see
  /// [showChatRowActionMenu]'s doc for the split between an immediate desktop
  /// open and a full-screen flight everywhere else.
  ///
  /// The flight itself never touches `RoomScreen`, never pushes more than the
  /// one real route, and never uses `Hero` — a genuine Hero flight needs both
  /// ends on the Navigator, and this card lives in a root `Overlay` instead
  /// (see `showChatRowActionMenu`'s own doc for why: the anchor-then-overlay
  /// technique this menu shares with `message_action_menu.dart`). So instead
  /// of morphing the card's own content into the transcript — content that
  /// was never going to survive contact with `RoomScreen`'s real layout
  /// anyway — [_growCtrl] grows a plain panel, in the room's background
  /// color, from the card's rect to the full screen with its corners
  /// straightening out as it goes. The instant that panel finishes covering
  /// the screen, [widget.onOpenRoom] mounts the real route underneath it —
  /// invisibly, since the panel is already the same flat color the screen is
  /// about to be — and [_revealCtrl] dissolves this whole overlay away to
  /// show it. Two plain tweens standing in for a Hero flight, not a
  /// substitute for one: the "growing panel, then a dissolve" shape is what
  /// reads as premium, not literal continuity of pixels the card was never
  /// going to keep anyway.
  Future<void> _beginOpen() async {
    if (_closing || _flying) return;
    if (context.isExpanded) {
      // No full-screen destination to grow into on a desktop window — the
      // room just replaces what's already showing in the detail pane, so
      // this closes exactly like any other menu action.
      widget.onOpenRoom();
      await _resolve(ChatRowAction.open);
      return;
    }
    setState(() => _flying = true);
    await _growCtrl.forward();
    if (!mounted) return;
    widget.onOpenRoom();
    await _revealCtrl.forward();
    if (!mounted) return;
    // Not `_resolve`: that reverses `_ctrl` to shrink the card back down,
    // which would fight the flight it just finished. `_revealCtrl` already
    // faded everything to nothing — removing the entry now is invisible.
    widget.onResolve(ChatRowAction.open);
  }

  List<ChatRowAction> get _actions => [
    if (!widget.isArchived) widget.isPinned ? ChatRowAction.unpin : ChatRowAction.pin,
    if (widget.canMute) widget.isMuted ? ChatRowAction.unmute : ChatRowAction.mute,
    widget.isArchived ? ChatRowAction.unarchive : ChatRowAction.archive,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final actions = _actions;
    final menuHeight = actions.length * _rowHeight + 12;
    const previewHeight = previewCardHeight;

    // This whole method reruns on every tick of the entrance animation AND
    // both flight animations — up to ~640ms at 60fps, so dozens of calls.
    // `widget.previewBuilder` builds a real `ChatRowPreviewCard`: an avatar,
    // a badge row, a scrollable transcript of chat bubbles. None of that
    // depends on anything any of these animations are interpolating — only
    // the RECT it sits inside does — so calling it fresh on every one of
    // those dozens of ticks was rebuilding that entire subtree for no
    // reason, on top of whatever it was actually meant to animate. Cached
    // once and reused as the SAME widget instance from then on: Flutter's
    // own element diffing skips rebuilding a child entirely when it's
    // `identical()` to what was there last frame, which turns this from
    // "rebuild a transcript's ListView 40 times" into "build it once."
    final previewContent = _previewContent ??= Builder(builder: widget.previewBuilder);

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

    // Capped to the screen (minus a 12 margin on each side) rather than
    // always the full 320: a card wider than the screen would just overflow
    // sideways instead of reading as "generous."
    final cardWidth = math.min(_cardWidth, widget.screenSize.width - 24);
    // Centered on wherever the press landed, not left-pinned to the anchor —
    // a tile in the grid's right column would otherwise grow its much wider
    // card straight off the right edge. Clamped last so a press near either
    // edge still keeps the whole card on screen.
    final anchorCenter = widget.anchorRect.left + widget.anchorRect.width / 2;
    var left = anchorCenter - cardWidth / 2;
    left = left.clamp(12.0, widget.screenSize.width - cardWidth - 12);

    final previewRect = Rect.fromLTWH(left, previewTop, cardWidth, previewHeight);
    final menuTop = previewRect.bottom + gap;

    // The scrim and the menu have nothing to do once a flight is under way —
    // both fade out fast (well inside the first third of the grow) rather
    // than riding the whole 340ms out, so they're gone before the panel is
    // even halfway to full screen. `IgnorePointer` follows a beat behind
    // rather than flipping the instant `_flying` does, so a hold-and-release
    // that lands right as the tap fires can't graze a still-fading menu row.
    final flightFade = _flying
        ? Curves.easeIn.transform((_growCtrl.value / 0.35).clamp(0.0, 1.0))
        : 0.0;
    final chromeVisible = 1 - flightFade;
    final chromeInert = flightFade > 0.5;

    // fastOutSlowIn, not easeOutCubic: a cubic ease-OUT front-loads almost
    // all the size change into roughly the first third of the duration and
    // spends the rest barely moving at all — the box reads as having
    // "jumped" to nearly its final size immediately, then the remaining
    // ~250ms of an already-finished-looking motion is dead air before
    // anything else happens. fastOutSlowIn — Material's own standard curve
    // for exactly this "container transform" shape — still starts brisk but
    // keeps visibly moving well into the back half, which is what actually
    // reads as one continuous grow instead of a snap-then-wait.
    final growT = Curves.fastOutSlowIn.transform(_growCtrl.value);
    final flightRect =
        _flying ? Rect.lerp(previewRect, Offset.zero & widget.screenSize, growT)! : previewRect;
    final flightRadius = (1 - growT) * theme.radiusXl;
    // The lift's 3% scale reads as a subtle press-lift on a card-sized box;
    // unwound to 0 by the time the box is near fullscreen, where the same 3%
    // would push real pixels past the screen's own edges — see _LiftedRow's
    // doc for why nothing else would catch that.
    final liftT = _flying ? 1 - growT : 1.0;
    // Between the sixth and just past half of the grow: late enough that the
    // card visibly starts expanding before its content disappears — the
    // continuity a flight needs — but not so late that a "small content
    // adrift in a mostly-blank, nearly-fullscreen panel" phase lingers,
    // which read as broken rather than smooth. Held at 1 for the reveal too:
    // once `RoomScreen` mounts underneath, this panel needs to already be a
    // flat match for its background, not the card fading back in first.
    final contentFade = _flying
        ? Curves.easeIn.transform(((_growCtrl.value - 0.16) / 0.38).clamp(0.0, 1.0))
        : 0.0;
    // The first ~30% of `_revealCtrl` maps to a flat 0, not a separate real
    // delay — `RoomScreen`'s first frame still has its own layout/data
    // settling to do (subscriptions resolving, its first real message list
    // laying out) once `onOpenRoom` mounts it, and revealing on the very
    // frame it mounts is what put that settling on screen, under a fade,
    // right as the flight was supposed to be finishing. An `Interval`
    // keeps this one continuous `forward()` — the controller is ticking the
    // entire time — rather than pausing execution for a beat and then
    // starting a second animation.
    final revealT = const Interval(0.3, 1.0, curve: Curves.easeOut).transform(_revealCtrl.value);

    // Material(type: transparency) supplies the DefaultTextStyle that the
    // root overlay otherwise lacks — without it, every Text inside paints
    // Flutter's debug "missing ancestor" yellow underlines.
    return IgnorePointer(
      // Once the reveal starts, the real route is already mounted directly
      // underneath this overlay — it needs to start receiving taps well
      // before this fade finishes, not wait out the last 220ms of a panel
      // that's already invisible.
      ignoring: _revealCtrl.value > 0,
      child: Opacity(
        opacity: 1 - revealT,
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _growCtrl, _revealCtrl]),
            builder: (context, child) {
              return Stack(
                children: [
                  // Gone the instant a flight starts, not faded out with the
                  // menu: `BackdropFilter` runs a real blur pass every frame
                  // it's in the tree, and that cost doesn't scale down with
                  // its own opacity — a gradual fade would still pay full
                  // blur cost for the ~130ms it takes to reach zero. That's
                  // real, visible cost on a simulator's software renderer,
                  // landing right in the fastest, most visible part of the
                  // grow — exactly the kind of per-frame tax that reads as a
                  // dropped-frame "jump" rather than smooth motion. The card
                  // has already started covering it by the time it vanishes,
                  // so there's nothing left for a fade to soften anyway.
                  if (!_flying)
                    _Scrim(
                      t: _ctrl,
                      onTap: () => _resolve(null),
                      visibility: chromeVisible,
                    ),
                  _LiftedRow(
                    t: _ctrl,
                    rect: flightRect,
                    liftT: liftT,
                    // Only wrapped in the extra ClipRRect+Stack once a flight
                    // is actually under way — at rest this is a bare
                    // GestureDetector, exactly as it was before any of this
                    // existed. That's deliberate, not incidental: nesting
                    // this inside a Stack under a ClipRRect changed how a
                    // `tester.tap` at the row's own screen point resolved
                    // through the gesture arena in testing, even though
                    // nothing about the tappable AREA should have changed —
                    // rather than chase why, the fix is to only add that
                    // extra structure once it's actually needed, which is
                    // never true before `_flying`.
                    child: _flying
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(flightRadius),
                            child: Stack(
                              children: [
                                // Stays mounted and visible through the whole
                                // grow — the card's own fixed-height bands
                                // don't stretch to fill the larger box, they
                                // just stay put at their natural size while
                                // the box grows around them, which is
                                // exactly the "the thing you pressed is what
                                // is expanding" continuity a flight needs.
                                // Swapping this out for a blank panel the
                                // instant the tap lands, however briefly, was
                                // what read as the preview going blank
                                // before it had visibly gone anywhere.
                                //
                                // RepaintBoundary because none of that is
                                // actually ANIMATING internally — the
                                // transcript's ListView, the avatar's
                                // RemoteImage — it just sits there while the
                                // box around it grows. `previewContent` is
                                // already the same cached instance across
                                // every frame (see `build`'s top) so it was
                                // never going to rebuild here regardless;
                                // `RepaintBoundary` is the other half of that
                                // — caching the RASTER too, so the (now
                                // static) content doesn't get repainted just
                                // because the clip/transform around it is.
                                // Not interactive any more either —
                                // `_beginOpen`'s own guard already makes a
                                // second tap a no-op, so there is nothing
                                // left for a GestureDetector to do here.
                                RepaintBoundary(child: previewContent),
                                if (contentFade > 0)
                                  IgnorePointer(
                                    child: Opacity(
                                      opacity: contentFade,
                                      // The room's own background, not the
                                      // card's — by the time this fully
                                      // covers the panel it needs to already
                                      // be the color `RoomScreen` opens on,
                                      // so the route mounting underneath a
                                      // moment later is invisible rather
                                      // than a color flash.
                                      child: ColoredBox(color: theme.background),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : GestureDetector(
                            // Opaque so a tap over the card's padding/gaps —
                            // not just its painted content — still counts. A
                            // drag over the transcript's own ListView still
                            // wins that gesture arena; only a
                            // tap-without-drag reaches here.
                            behavior: HitTestBehavior.opaque,
                            onTap: _beginOpen,
                            child: previewContent,
                          ),
                  ),
                  Positioned(
                    left: left,
                    top: menuTop,
                    width: cardWidth,
                    child: IgnorePointer(
                      ignoring: chromeInert,
                      child: Opacity(
                        opacity: _ctrl.value * chromeVisible,
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
                  for (final action in actions) _ChatRowActionRow(action: action, onTap: () => _resolve(action)),
                ],
              ),
            ),
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
  const _Scrim({required this.t, required this.onTap, this.visibility = 1});
  final Animation<double> t;
  final VoidCallback onTap;

  /// A plain multiplier, not its own [Animation] — this widget is rebuilt
  /// fresh every tick of whichever [AnimatedBuilder] constructs it (see
  /// `_ChatRowActionMenuOverlayState.build`), so a field read here is always
  /// current without needing to merge another `Listenable`. Lets the flight
  /// fade the scrim out — a fullscreen panel has nothing left to dim behind
  /// it — without touching [t], which still drives the entrance/exit this
  /// widget shares with everything else keyed to it.
  final double visibility;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: t,
          builder: (_, _) {
            final alpha = t.value * visibility;
            return Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 22 * alpha, sigmaY: 22 * alpha),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.32 * alpha)),
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
/// everything else blurs.
///
/// Unlike the lifted bubble — and unlike this card before it grew a real
/// scrollable transcript — NOT `IgnorePointer`-wrapped: [ChatRowPreviewCard]'s
/// transcript band needs a finger to actually reach it and drag, and its
/// `child` is itself wrapped in a `GestureDetector` that resolves
/// [ChatRowAction.open] on a plain tap — the same shortcut tapping the real
/// row would have given, so previewing it first shouldn't cost that. A drag
/// over the transcript still wins its own gesture arena and just scrolls;
/// tapping the scrim outside the card's rect still dismisses, since that's a
/// separate widget beneath this one in the stack.
///
/// [rect] is no longer the anchor row's own rect verbatim: the overlay grows
/// it downward from the row's top-left into the taller band
/// [ChatRowPreviewCard] needs, so [child] is a fresh, richer preview built at
/// that grown size rather than a redraw of the small row at its original
/// size — see `showChatRowActionMenu`'s doc for why.
class _LiftedRow extends StatelessWidget {
  const _LiftedRow({
    required this.t,
    required this.rect,
    required this.child,
    this.liftT = 1,
  });
  final Animation<double> t;
  final Rect rect;
  final Widget child;

  /// How much of the lift's own 3% scale + shadow still applies, 0-1 — NOT
  /// the same knob as [t]. [t] is the entrance/exit and stays pinned at 1
  /// for the whole of a flight, so left alone the lift would too: 3% of a
  /// ~320×400 card is a few imperceptible pixels, but 3% of a box CENTER-
  /// SCALED to nearly the size of the screen is real pixels pushed past its
  /// physical edges — nothing clips a `Transform.scale`'s paint back to the
  /// screen, so that overflow doesn't error, it just renders, which is
  /// exactly the "goes off screen" a flight's tail end doesn't want. The
  /// overlay fades this to 0 as the grow finishes rather than ever letting
  /// scale exceed 1 near fullscreen.
  final double liftT;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: AnimatedBuilder(
        animation: t,
        builder: (_, c) {
          final scale = 1 + 0.03 * t.value * liftT;
          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18 * t.value * liftT),
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

/// A *measured* number, not a guess: `tester.getSize()` on a dense, icon-only
/// badge comes back 25.0 tall regardless of which badge — a labelled dense
/// badge measures 24 tall but 99-111 WIDE, wide enough that two of them
/// already exceed this card's available width and wrap to a second line,
/// which is what was silently clipping badges here before. Icon-only ones
/// measure a consistent ~27 wide, so all five badges this row can ever show
/// fit on one line with room to spare — see the badges themselves, all
/// passed `iconOnly: true` below.
const double _previewTopRowH = 25;
const double _previewAvatarSize = 30;
const double _previewIdentityRowH = 30;
const double _previewFooterRowH = 20;
const double _previewGap = 10;

/// The gap under the badges/timestamp row specifically — tighter than
/// [_previewGap] everywhere else. That row is empty air for most rooms (no
/// badges is the common case, leaving just a small right-aligned timestamp),
/// so giving it the same breathing room as bands that are actually full of
/// content read as a big dead bar at the top of the card.
const double _previewTopGap = 6;

/// The transcript band's height when there's anything cached to scroll
/// through — a real, if miniature, chat window rather than a couple of
/// flattened text lines. Fixed regardless of how many messages are on offer:
/// the band SCROLLS to reach them instead of growing to fit them, which is
/// what keeps this a constant [previewCardHeight] can use rather than a
/// function of message count.
const double _previewTranscriptH = 260;

/// Widest a single bubble in [ChatRowPreviewCard._transcript] gets — fixed
/// rather than a fraction of the card's own width, since the card's width is
/// itself capped independently (see `_ChatRowActionMenuOverlayState`'s
/// `_cardWidth`) and a bubble this size already reads well against it.
const double _previewBubbleMaxWidth = 220;

/// How many of a room's messages [ChatRowPreviewCard] will ever hand to its
/// scrollable transcript — a defensive cap on a list that, for a room with a
/// long history, could otherwise run to hundreds of entries. Not a rendering
/// limit: everything under this cap is reachable by scrolling, not just the
/// newest few. Also what it asks the server for when nothing is cached yet —
/// see the class doc.
const int previewMaxMessages = 40;

/// The full height [ChatRowPreviewCard] renders at. A true constant, not a
/// function of the room or its messages: every room gets the same transcript
/// band, whether it's showing cached messages, a fetch in flight, a typing
/// line, or "no messages yet" — one card size for every long press is also
/// simply the more coherent result, the same way every message bubble menu
/// opens to the same shape regardless of what the message was.
const double previewCardHeight =
    _previewPadding * 2 +
    _previewTopRowH +
    _previewTopGap +
    _previewIdentityRowH +
    _previewGap +
    _previewTranscriptH +
    _previewGap +
    _previewFooterRowH;

/// The richer, long-press preview of a chat row: the same identity a
/// [RoomCard]/[RoomGridTile] already shows — avatar, name, badges, the last-
/// message stamp — above a real, scrollable miniature transcript: actual chat
/// bubbles, in the same shape and color [AppTheme.bubbleDecoration] paints in
/// the room itself, that a finger can drag through rather than a few
/// flattened lines of text. This is the "small real chatroom-like window" the
/// compact row never had room for — and it works for every room, not only
/// ones already open this session; see [recentMessages].
///
/// [recentMessages] is what `ChatRepository.messagesFor(room.id)` already
/// holds in memory at press time — instant, but empty for the majority of
/// rooms, which the viewer has not opened this session and whose transcript
/// was therefore never subscribed to. When it arrives empty, this widget
/// fetches a tail itself (see [_ChatRowPreviewCardState._fetch]) rather than
/// staying stuck on the one-line fallback, so a long-press works the same on
/// every room. That fetch is `ChatApi.listMessages`, which calls the Convex
/// QUERY `messages:list` — a pure read with no write path at all, so a peek
/// can never mark the room read or delivered the way actually opening it
/// (`ChatRepository.openRoom`) would; only `ChatApi.markRoomRead` and
/// `markRoomDelivered` do that, and neither is called anywhere near this
/// widget. Until the fetch lands — or if it never does — the card shows
/// `room.lastMessage` via [roomSubtitle], the same server-computed preview
/// text the compact row already shows, just no longer clipped to one line.
///
/// Every band in [build] is a fixed height taken from the constants above —
/// see those for why — except the transcript band itself, which scrolls
/// rather than growing, so its height stays fixed too.
class ChatRowPreviewCard extends StatefulWidget {
  const ChatRowPreviewCard({
    super.key,
    required this.room,
    required this.dmUser,
    required this.recentMessages,
    required this.currentUserId,
    this.typists = const [],
    this.api,
  });

  final ChatRoom room;

  /// Also who [_ChatRowPreviewCardState._fetch] asks for a tail when
  /// [recentMessages] arrives empty — null only in contexts (tests, mostly)
  /// that have no live backend to ask, where the card simply stays on the
  /// fallback line forever, same as before this widget could fetch at all.
  final ChatApi? api;

  /// For DM rooms, the other participant — same override [RoomCard] applies
  /// to the raw "dm:..." room name and its avatar.
  final ChatUser? dmUser;

  /// Whose bubbles land on the right, in the room's accent color, the same
  /// as everywhere else a transcript decides mine-vs-theirs.
  final String currentUserId;

  /// Oldest-to-newest, same order `ChatApi.listMessages` hands back. The
  /// transcript still takes only the newest [previewMaxMessages] of whatever
  /// arrives here — see the class doc.
  final List<ChatMessage> recentMessages;
  final List<ChatUser> typists;

  @override
  State<ChatRowPreviewCard> createState() => _ChatRowPreviewCardState();
}

class _ChatRowPreviewCardState extends State<ChatRowPreviewCard> {
  late List<ChatMessage> _messages = widget.recentMessages;

  @override
  void initState() {
    super.initState();
    if (_messages.isEmpty && widget.api != null) _fetch();
  }

  /// Runs once, from [initState] — a fresh [State] per press is exactly the
  /// one-shot lifetime this needs, so there's no separate "already fetching"
  /// flag to keep in sync. See the class doc for why this can never mark
  /// anything read.
  Future<void> _fetch() async {
    try {
      final fetched = await widget.api!.listMessages(
        roomId: widget.room.id,
        limit: previewMaxMessages,
        viewerUserId: widget.currentUserId,
      );
      if (!mounted || fetched.isEmpty) return;
      setState(() => _messages = fetched);
    } catch (_) {
      // Peeking at a room that fails to load its tail just stays on the
      // last-message fallback line — nothing here is worth surfacing an
      // error over for a long-press preview.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final room = widget.room;
    final dmUser = widget.dmUser;
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
      foregroundDecoration: BoxDecoration(border: cardDecoration.border, borderRadius: cardDecoration.borderRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _previewTopRowH,
            // A `Wrap`, unlike a `Row`/`Column`, does not assert when it
            // needs more room than it's given — a room with enough badges to
            // need a second line would silently paint that line over the
            // identity row below instead of erroring where it'd get caught.
            // Clipped to this row's own fixed height, an overflowing second
            // line simply disappears instead: an occasionally-truncated badge
            // set beats corrupting the row underneath it.
            child: ClipRect(
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // iconOnly: a labelled dense badge measures 99-111
                        // wide (see [_previewTopRowH]'s doc) — two of those
                        // is already more than this card has to give. Icon-
                        // only ones are a consistent ~27, so every badge this
                        // row can ever show fits on the one line
                        // [_previewTopRowH] is sized for. The tap tooltip
                        // still spells each one out in full — see
                        // `RoomBadge`'s own doc for why that's enough.
                        if (!room.isDm) VisibilityBadge(isPublic: room.isPublic, dense: true, iconOnly: true),
                        if (room.isEphemeral && room.messageLifetime != null)
                          EphemeralBadge(ttl: room.messageLifetime!, dense: true, iconOnly: true),
                        if (room.hasPassword) const LockedBadge(dense: true, iconOnly: true),
                        if (room.isPinned) const PinnedBadge(dense: true, iconOnly: true),
                        if (room.isMuted)
                          MutedBadge(
                            dense: true,
                            iconOnly: true,
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
          ),
          const SizedBox(height: _previewTopGap),
          SizedBox(
            height: _previewIdentityRowH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _avatar(theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    room.isSavedMessages ? l10n.savedMessagesTitle : (dmUser?.displayName ?? room.name),
                    // displaySmall, not displayMedium: this card is the
                    // richer version of RoomCard's own compact row, and
                    // RoomCard titles its name at displaySmall too. Medium
                    // (28) is sized for an actual page header — a room name
                    // was never meant to read that large here, and this was
                    // the single biggest thing making the header feel
                    // oversized.
                    style: room.hasUnread
                        ? theme.displaySmall.copyWith(fontWeight: FontWeight.w700)
                        : theme.displaySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (room.visibleUnreadCount > 0) ...[
                  const SizedBox(width: 8),
                  CountBadge(count: room.visibleUnreadCount, mention: room.hasVisibleMention),
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
                if (!room.isDm) Text(l10n.roomCardMemberCount(room.memberCount), style: theme.caption),
                const Spacer(),
                if (room.isEphemeral)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      theme.hourglassIcon(size: 12, color: theme.accent),
                      const SizedBox(width: 6),
                      Text(l10n.roomCardMessagesFadeLabel, style: theme.monoTiny.copyWith(color: theme.accent)),
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
    final room = widget.room;
    final dmUser = widget.dmUser;
    final api = widget.api;
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
      return UserAvatar(user: dmUser, size: size, api: api);
    }
    if (room.avatarStorageId != null && api != null) {
      return ClipOval(
        child: RemoteImage(
          storageId: room.avatarStorageId!,
          api: api,
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
  /// sent. Otherwise a real, scrollable transcript tail once [_messages] has
  /// anything in it — whether that arrived with the widget or [_fetch] filled
  /// it in — and the room's own last-message text, grown to four lines
  /// instead of one, until either of those is true.
  ///
  /// All three render inside the same fixed [_previewTranscriptH] band — see
  /// [previewCardHeight]'s doc for why that no longer varies by state.
  Widget _body(AppTheme theme, RoomSubtitle subtitle) {
    final Widget content;
    if (widget.typists.isNotEmpty) {
      content = Align(
        alignment: Alignment.topLeft,
        child: TypingLine(typists: widget.typists),
      );
    } else if (_messages.isNotEmpty) {
      content = _transcript(theme);
    } else {
      // Covers both "genuinely nothing ever sent" and "the fetch in
      // `_fetch` hasn't landed yet" — the room's own last-message line
      // reads fine in either case, and this band silently upgrades to the
      // real transcript the moment `_fetch` resolves, no spinner needed.
      content = Align(
        alignment: Alignment.topLeft,
        child: Text(
          subtitle.text,
          style: subtitle.kind == RoomSubtitleKind.message
              ? theme.bodySoft
              : theme.bodySoft.copyWith(color: theme.inkMuted),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return SizedBox(height: _previewTranscriptH, child: content);
  }

  /// The transcript tail as real chat bubbles — [AppTheme.bubbleDecoration],
  /// the same shape and color the room itself paints, not a flattened line of
  /// text. Newest message at the bottom and scrolled there on open, same as
  /// the room; dragging up reaches the rest of [_messages]. This band is
  /// genuinely interactive, unlike the rest of the card — see `_LiftedRow`'s
  /// doc for why the card as a whole had to stop ignoring pointers for a drag
  /// here to reach it.
  Widget _transcript(AppTheme theme) {
    final room = widget.room;
    final style = SettingsStore.instance.bubbleStyle;
    final ordered = _messages.length > previewMaxMessages
        ? _messages.sublist(_messages.length - previewMaxMessages)
        : _messages;
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radiusMd),
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: ordered.length,
        itemBuilder: (context, i) {
          final index = ordered.length - 1 - i;
          final m = ordered[index];
          final isMine = m.senderId == widget.currentUserId;
          // Named once per consecutive run from the same sender, the same
          // grouping the real transcript applies — repeating a name on every
          // line of a burst reads as noise there and would here too.
          final prev = index > 0 ? ordered[index - 1] : null;
          final showName = !room.isDm && !isMine && (prev == null || prev.senderId != m.senderId);
          return _bubbleRow(theme, m, isMine: isMine, showName: showName, style: style);
        },
      ),
    );
  }

  Widget _bubbleRow(
    AppTheme theme,
    ChatMessage m, {
    required bool isMine,
    required bool showName,
    required BubbleStyle style,
  }) {
    final decoration = theme.bubbleDecoration(isMine: isMine, ephemeral: widget.room.isEphemeral, style: style);
    final textStyle = theme.bodySoft.copyWith(color: isMine ? theme.accentInk : theme.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _previewBubbleMaxWidth),
            child: DecoratedBox(
              decoration: decoration,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          m.senderName,
                          style: theme.caption.copyWith(fontWeight: FontWeight.w700, color: theme.accent),
                        ),
                      ),
                    Text(messagePreviewLine(m), style: textStyle, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    ChatRowAction.unpin => (CupertinoIcons.pin_slash, l10n.chatRowActionMenuUnpinLabel),
    ChatRowAction.archive => (CupertinoIcons.archivebox, l10n.chatRowActionMenuArchiveLabel),
    ChatRowAction.unarchive => (CupertinoIcons.tray_arrow_up, l10n.chatRowActionMenuUnarchiveLabel),
    ChatRowAction.mute => (CupertinoIcons.bell_slash, l10n.chatRowActionMenuMuteLabel),
    ChatRowAction.unmute => (CupertinoIcons.bell, l10n.chatRowActionMenuUnmuteLabel),
    // Never actually reached: `_actions` (the only place a `ChatRowAction`
    // becomes an `_ChatRowActionRow`) never includes `open` — it resolves
    // straight from a tap on the lifted card, not a row in this list. Listed
    // so a genuine future menu row for it fails here instead of silently
    // rendering nothing.
    ChatRowAction.open => throw UnimplementedError('open is not a menu row'),
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
