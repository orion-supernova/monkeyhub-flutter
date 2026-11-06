import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/message_capabilities.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/spring.dart';
import '../keyboard/focusable_tap.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;
import 'glass_reveal.dart';
import 'glass_surface.dart';
import 'hold_scrub.dart';
import 'segmented_control.dart';
import 'translation_slab.dart' show FrozenBubble;
import 'blur_scrim.dart';
import 'teardown_safe.dart';

/// Actions surfaced by [showMessageActionMenu] (reactions are handled
/// separately via [MessageActionResult.emoji] / `.fullPicker`).
/// Two entries for pinning rather than one that toggles: the label IS the
/// affordance, and a single `pin` case would force both switch sites to re-derive
/// the current state just to know what they had done. Exactly one of the two is
/// ever offered, chosen by `isPinned`.
enum MessageAction {
  reply,

  /// Reopens the viewer's own text message in the composer for rewriting —
  /// offered only inside the server's 15-minute window. See
  /// [MessageCapabilities.canEdit].
  edit,
  forward,
  viewThread,
  copy,

  /// Puts a document's filename on the clipboard. Distinct from [copy], which
  /// takes a message's body — a document has no body, and its name is the one
  /// thing about it worth carrying somewhere else.
  copyName,

  /// Puts a location's `"lat, lng"` on the clipboard. The location-bubble
  /// counterpart to [copyName]: a location has no body either, and its
  /// coordinates are the one thing about it worth carrying somewhere else.
  /// See [MessageCapabilities.canCopyCoordinates].
  copyCoordinates,

  /// Hands the bubble to Sebastian and shows what it says underneath the
  /// original. See `lib/companions/`.
  ///
  /// Offered even when he isn't installed: tapping it then opens his install
  /// sheet and, once he has arrived, carries straight on with the translation
  /// that was asked for. That is on purpose — this row is the main way anybody
  /// finds out the feature exists, and hiding it until after a Settings visit
  /// would mean nobody ever did.
  translate,

  /// Puts a translated bubble back to what was actually said. Paired with
  /// [translate] the way [pin]/[unpin] are: exactly one of the two is ever
  /// offered, chosen by whether a translation is currently showing.
  showOriginal,

  /// Forgets this bubble's translation and asks again.
  ///
  /// Offered alongside [showOriginal], and NOT paired with it — both are
  /// useful at once, because they answer the two different things a reader
  /// thinks when a translation is wrong: "what did it actually say" and "try
  /// that again". The cache makes the second one necessary: without it,
  /// TRANSLATE on an already-translated message redraws the same bad answer
  /// forever.
  translateAgain,
  pin,
  unpin,

  /// Keeps this message for the viewer alone, where it is — the per-reader
  /// bookmark listed by room info's "Saved messages" section.
  ///
  /// Deliberately NOT [forward]-into-Saved-Messages, which is the other thing
  /// the word "save" could mean in this app and is already reachable through
  /// the forward sheet. That copies the message into the `dm:self:` room and
  /// strands it away from the conversation it belonged to; this leaves it in
  /// place and marks it. Paired with [unsave] for the reason pin/unpin are
  /// paired.
  save,
  unsave,
  select,

  /// Opens the message's read receipts: who has it and who has read it. The
  /// same screen the start-edge swipe pulls in, offered as a row so a mouse
  /// (which cannot swipe) can reach it too. See
  /// [MessageCapabilities.canViewReceipts].
  info,
  delete,
  report,
  viewProfile,

  /// The moderator rows on a report card in the moderation room. See
  /// [MessageCapabilities.canModerate] and `widgets/moderation_actions.dart`,
  /// which carries them out. Never offered anywhere else.
  modRemoveMessage,
  modRemoveContent,
  modBanUser,
  modUnbanUser,
  modDismiss,
}

/// Resolved choice from [showMessageActionMenu]. Exactly one of the three
/// shapes is filled in:
/// * `.action(...)` — user tapped a list row
/// * `.emoji(...)` — user tapped one of the quick reactions in the pill
/// * `.fullPicker()` — user tapped `+` and wants the full picker
class MessageActionResult {
  const MessageActionResult.action(MessageAction this.action,
      {this.album = false})
      : emoji = null,
        openFullReactionPicker = false;
  const MessageActionResult.emoji(String this.emoji, {this.album = false})
      : action = null,
        openFullReactionPicker = false;
  const MessageActionResult.fullPicker({this.album = false})
      : action = null,
        emoji = null,
        openFullReactionPicker = true;

  final MessageAction? action;
  final String? emoji;
  final bool openFullReactionPicker;

  /// The choice was made with the menu's album switch on "All": it applies
  /// to the whole album, not the one photo that was pressed. Always false
  /// without a [MessageMenuAlbum].
  final bool album;
}

/// What the menu needs to offer the whole album as well as the pressed photo:
/// the two-way switch at the top of the list ("All 4" / "This one"), and,
/// for the "All" side, its own rows and its own selected reactions. The
/// switch starts on "All".
class MessageMenuAlbum {
  const MessageMenuAlbum({
    required this.allLabel,
    required this.oneLabel,
    required this.capabilities,
    this.myReactions = const {},
    this.stackBuilder,
  });

  /// The lifted preview while the switch is on "All": the whole pile rather
  /// than the pressed card. Laid out in the pressed card's rect like the
  /// ordinary preview, and free to spill past it (the cards peeking out at
  /// the sides). Null keeps the card preview on both sides.
  final WidgetBuilder? stackBuilder;

  final String allLabel;
  final String oneLabel;

  /// The rows the whole album affords.
  final MessageCapabilities capabilities;

  /// The viewer's reactions to the whole album.
  final Set<String> myReactions;
}

const List<String> _kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

/// Long-press context menu for a chat bubble. Inserts a root-overlay entry
/// that blurs the chat behind, lifts the tapped bubble, and floats a reaction
/// pill above it and an action list below it, anchored to the bubble's leading
/// edge. Always that order: when there is no room the bubble moves or shrinks
/// instead (see [holdMenuPlacement]). The finger that opened it stays live, so
/// sliding across the pill and releasing reacts (see [HoldScrub]); rows always
/// need a tap. Returns when the user picks something or dismisses via the
/// scrim.
Future<MessageActionResult?> showMessageActionMenu({
  required BuildContext context,
  required GlobalKey anchorKey,
  required WidgetBuilder bubbleBuilder,

  /// Geometry only — which side the bubble hangs from, so the pill and list
  /// anchor to its leading edge. Which ROWS appear is entirely
  /// [capabilities]'s business.
  required bool isMine,

  /// Which rows this menu offers. Resolved by
  /// `ChatRepository.capabilitiesForMessage` rather than assembled at the call
  /// site — this parameter is what replaced eleven independent booleans that
  /// two screens each derived by hand.
  required MessageCapabilities capabilities,

  /// State, not affordance: which of the pin/save pairs' two labels is
  /// showing. The affordance itself is [capabilities].
  bool isPinned = false,
  bool isSaved = false,

  /// State, not affordance, exactly like [isPinned]: which of TRANSLATE /
  /// SHOW ORIGINAL this bubble is currently showing.
  bool isTranslated = false,

  /// A document's full filename, when this bubble is one.
  ///
  /// The row in the transcript holds the name to a single line — a document
  /// keeps a message's rhythm, and a name that wrapped made a six-line bubble
  /// out of one file. This is where the whole thing is legible: the menu prints
  /// it in full, over as many lines as it takes, and offers to copy it.
  String? fileName,

  /// The emoji the viewer has already left on this message. Drawn selected in
  /// the quick pill — and, when one is not among the quick six, drawn there
  /// anyway (WhatsApp's way), so a long-press always shows what you said.
  Set<String> myReactions = const {},

  /// Set when the pressed bubble is one card of an album: the menu then opens
  /// on the whole album, with a switch to the pressed photo alone. The
  /// result's [MessageActionResult.album] says which side was chosen.
  MessageMenuAlbum? album,

  /// The tallest the lifted preview settles. A bubble taller than this
  /// starts exactly over itself and shrinks toward its own edge as it lifts,
  /// and the pill and list are laid out around the smaller size. Set for
  /// photos and videos, which at full size crowd the menu off the screen.
  double? previewMaxHeight,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final anchorCtx = anchorKey.currentContext;
  if (anchorCtx == null) return null;
  final rb = anchorCtx.findRenderObject() as RenderBox?;
  if (rb == null || !rb.attached) return null;

  final topLeft = rb.localToGlobal(Offset.zero);
  final bubbleRect = topLeft & rb.size;

  // Deliberately NOT captured here: screen size, safe area, keyboard inset.
  // They are read inside the overlay entry instead — see
  // [_MessageActionMenuOverlayState.build], which explains why the caller's
  // MediaQuery is the wrong one to ask and why a snapshot is the wrong shape.
  // Only `bubbleRect` is a snapshot, because it has to be: it is where the
  // bubble was at the moment of the press, in window coordinates.

  // The entry lands on the ROOT overlay, so `bubbleBuilder` runs outside the
  // room's ChatPane and would see no chat metrics at all. Today that is
  // invisible because _LiftedBubble force-sizes the preview to the measured
  // rect, but capturing them here keeps the preview honest if that ever
  // relaxes — and makes the intent explicit rather than accidental.
  final metrics = ChatMetricsScope.readOf(context);

  // The blurred backdrop, taken once now rather than blurred live. See
  // [BlurSnapshot].
  final backdrop = BlurSnapshot.capture(anchorCtx);

  final completer = Completer<MessageActionResult?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _MessageActionMenuOverlay(
      bubbleRect: bubbleRect,
      metrics: metrics,
      bubbleBuilder: bubbleBuilder,
      isMine: isMine,
      capabilities: capabilities,
      isPinned: isPinned,
      isSaved: isSaved,
      isTranslated: isTranslated,
      fileName: fileName,
      myReactions: myReactions,
      album: album,
      previewScale: previewMaxHeight == null
          ? 1
          : math.min(1.0, previewMaxHeight / bubbleRect.height),
      backdrop: backdrop,
      onResolve: (result) {
        if (!completer.isCompleted) completer.complete(result);
        backdrop?.image.dispose();
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

// ───────────────────────── overlay widget ─────────────────────────

class _MessageActionMenuOverlay extends StatefulWidget {
  const _MessageActionMenuOverlay({
    required this.bubbleRect,
    required this.metrics,
    required this.bubbleBuilder,
    required this.isMine,
    required this.capabilities,
    required this.isPinned,
    required this.isSaved,
    required this.isTranslated,
    required this.fileName,
    required this.myReactions,
    required this.album,
    required this.previewScale,
    required this.backdrop,
    required this.onResolve,
  });

  /// How big the preview settles, relative to the pressed bubble. See
  /// [showMessageActionMenu]'s `previewMaxHeight`.
  final double previewScale;

  final Set<String> myReactions;

  /// See [showMessageActionMenu]'s `album`.
  final MessageMenuAlbum? album;

  final Rect bubbleRect;

  /// The chat behind, pre-blurred; null when it could not be captured.
  final BlurSnapshot? backdrop;

  /// Chat metrics captured from the pane the bubble was lifted out of; null
  /// when it wasn't inside one.
  final ChatMetrics? metrics;
  final WidgetBuilder bubbleBuilder;
  final bool isMine;
  final MessageCapabilities capabilities;
  final bool isPinned;
  final bool isSaved;
  final bool isTranslated;

  /// Non-null only for a document bubble — see [showMessageActionMenu].
  final String? fileName;
  final ValueChanged<MessageActionResult?> onResolve;

  @override
  State<_MessageActionMenuOverlay> createState() => _MessageActionMenuOverlayState();
}

class _MessageActionMenuOverlayState extends State<_MessageActionMenuOverlay>
    with SingleTickerProviderStateMixin
    implements HoldScrubTarget {
  late final AnimationController _ctrl;
  bool _closing = false;

  // ── the held finger (see [HoldScrub]) ──

  /// The reaction pill, measured for the scrub's hit test.
  final GlobalKey _pillKey = GlobalKey();

  /// The emoji the pill is showing, in order; `+` follows them. Kept from the
  /// last build so a release can say which one it landed on.
  List<String> _pillEmojis = const [];

  /// The finger that opened the menu is still down.
  bool _held = false;

  /// It has travelled past [HoldScrub.slop]: a release now means something.
  bool _sliding = false;

  /// Index under the finger: `0 ..< _pillEmojis.length` is an emoji,
  /// `_pillEmojis.length` is the `+`. Null when the finger is off the pill.
  int? _focus;

  /// The finger has been on the pill and left it: lifting now picks nothing,
  /// and the hint says so.
  bool _offPill = false;

  /// Set once an emoji is picked: where the magnified glyph flies to as the
  /// menu closes, so the reaction visibly lands on the message.
  Offset? _flyTo;

  /// The album switch's side: true acts on the whole album. Starts there
  /// whenever there is an album to act on.
  late bool _whole = widget.album != null;

  @override
  void initState() {
    super.initState();
    // Long enough for the jelly to ring (see [JellyCurve]): most of the
    // move is done in the first third, the rest is the wobble settling.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _ctrl.forward();
    _held = HoldScrub.isHeld && widget.capabilities.canReact;
    if (_held) HoldScrub.attach(this);
  }

  @override
  void dispose() {
    HoldScrub.detach(this);
    _ctrl.dispose();
    super.dispose();
  }

  /// Which pill slot [global] is over, or null when it is off the pill.
  ///
  /// The band is generous (40 above, 28 below, 20 past each end) because a
  /// finger sliding sideways drifts, and dropping the focus every time it
  /// wandered a few points off a 50pt pill would make the scrub feel broken.
  /// Inside the band only x matters.
  int? _slotAt(Offset global) {
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || _pillEmojis.isEmpty) return null;
    final local = box.globalToLocal(global);
    final size = box.size;
    if (local.dy < -40 || local.dy > size.height + 28) return null;
    if (local.dx < -20 || local.dx > size.width + 20) return null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = (rtl ? size.width - local.dx : local.dx) - _ReactionPill.padding;
    return (x / _PillEmoji.size)
        .floor()
        .clamp(0, _pillEmojis.length)
        .toInt();
  }

  @override
  void holdMove(Offset globalPosition, Offset fromOrigin) {
    if (!_held || _closing || !mounted) return;
    if (!_sliding) {
      if (fromOrigin.distance < HoldScrub.slop) return;
      _sliding = true;
    }
    final slot = _slotAt(globalPosition);
    final offPill = slot == null && (_focus != null || _offPill);
    if (slot == _focus && offPill == _offPill) return;
    if (slot != null) HapticFeedback.selectionClick();
    setState(() {
      _focus = slot;
      _offPill = offPill;
    });
  }

  @override
  void holdEnd(Offset globalPosition) {
    if (!_held || _closing || !mounted) return;
    _held = false;
    HoldScrub.detach(this);
    final slot = _sliding ? _focus : null;
    // Anything but an emoji leaves the menu open for tapping, exactly as a
    // release did before there was a scrub. Rows are never committed by a
    // release: a wrong reaction is one tap to undo, a wrong Forward is not.
    if (slot == null) {
      setState(() {
        _focus = null;
        _offPill = false;
      });
      return;
    }
    final whole = _whole && widget.album != null;
    if (slot < _pillEmojis.length) {
      _pickEmoji(_pillEmojis[slot], whole);
    } else {
      _pickMore(whole);
    }
  }

  void _pickEmoji(String e, bool whole) {
    if (_closing) return;
    HapticFeedback.lightImpact();
    // Picked by a tap or by a release, the glyph does the same thing: rises
    // out of its slot and drops onto the message as everything else closes.
    final i = _pillEmojis.indexOf(e);
    final r = widget.bubbleRect;
    setState(() {
      if (i >= 0) _focus = i;
      _offPill = false;
      _flyTo = Offset(
        widget.isMine ? r.right - 22 : r.left + 22,
        r.bottom - 6,
      );
    });
    _resolve(
      MessageActionResult.emoji(e, album: whole),
      linger: _ScrubMagnifier.flight,
    );
  }

  void _pickMore(bool whole) {
    HapticFeedback.selectionClick();
    _resolve(MessageActionResult.fullPicker(album: whole));
  }

  Future<void> _resolve(
    MessageActionResult? result, {
    Duration linger = Duration.zero,
  }) async {
    if (_closing) return;
    _closing = true;
    // [linger] keeps the entry up past the close for a flight that is still
    // landing; the menu itself closes on its usual beat either way.
    await Future.wait([
      _ctrl.reverse(),
      if (linger > Duration.zero) Future<void>.delayed(linger),
    ]);
    if (!mounted) return;
    widget.onResolve(result);
  }

  /// How tall the filename header will lay out, measured rather than guessed.
  ///
  /// Every other element in this menu is a fixed 48, which is why `menuH` could
  /// be arithmetic. A filename is not: it wraps to as many lines as it needs,
  /// and at three lines an estimate is off by enough to flip the menu to the
  /// wrong side of the bubble near a screen edge. Measured against the same
  /// width and text scale [_ActionList] will hand the real one — see
  /// [_FileNameHeader], which owns the padding both of these read.
  double _headerHeight(BuildContext context, AppTheme theme) {
    // The album switch, a fixed height, over everything else.
    final album =
        widget.album == null ? 0.0 : _AlbumSwitch.height + 1; // + divider
    final name = _whole ? null : widget.fileName;
    if (name == null) return album;
    final painter = TextPainter(
      text: TextSpan(text: name, style: theme.bodyEmph),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _ActionList.maxWidth - _FileNameHeader.padding.horizontal);
    return album +
        painter.height +
        _FileNameHeader.padding.vertical +
        1; // + divider
  }

  /// Lays the pill and the list out against the band between the WINDOW's top
  /// safe area and whatever is covering the bottom of it.
  ///
  /// Every number below comes from `MediaQuery.of(context)` read *here*, inside
  /// the root overlay entry, and pointedly not from the context that called
  /// [showMessageActionMenu]. That caller is a bubble in the transcript, and by
  /// the time a MediaQuery reaches it two ancestors have already spent it:
  ///
  /// * a `SafeArea` (the classic chat style wraps the whole room in one) —
  ///   which CONSUMES the top padding. `MediaQuery.paddingOf` under it reports
  ///   `top: 0`, and so does `viewPaddingOf`, because
  ///   `MediaQueryData.removePadding` decrements both. A menu laid out against
  ///   that thinks the band starts at y=0 and puts its reaction pill under the
  ///   Dynamic Island. Adding a `SafeArea` *inside* the menu cannot fix it
  ///   either: down there the padding is already zero, so the widget is a
  ///   no-op.
  /// * a `Scaffold`, which with the default `resizeToAvoidBottomInset` strips
  ///   `viewInsets.bottom` out of the MediaQuery it hands its body — it has
  ///   already resized the body around the keyboard. This overlay is not in
  ///   there, and for it the keyboard is still very much covering the screen.
  ///
  /// The root overlay sits above both, directly under the app's own
  /// `MediaQuery`, so nothing has edited what it reads. Taking it as an
  /// inherited dependency rather than snapshotting it at press time (which is
  /// what this used to do) also means the menu re-fits itself when the keyboard
  /// opens or closes underneath it, and when the device rotates.
  ///
  /// When the band is too short for everything, the ACTION LIST scrolls inside
  /// a clamped height rather than the menu shrinking its rows or spilling past
  /// the edge: rows that shrink stop being tappable long before they stop being
  /// readable, and a menu that ends early looks like a menu with fewer actions
  /// in it. See [_ScrollableMenuBody].
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final calm = MotionScope.of(context).calm;
    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: calm ? theme.motionEntrance : const JellyCurve(overshoot: 0.06),
      reverseCurve: Curves.easeInCubic,
    );
    final media = MediaQuery.of(context);
    final screen = media.size;

    // Built ONCE per layout, here, and handed to `_ActionList` verbatim. The
    // row count used to be a second, hand-synced copy of the list's if-chain
    // (`_actionCount()`), whose comment warned that a missed row mispositions
    // the whole menu by 48pt near a screen edge. Now the count is
    // `specs.length` by construction and there is nothing to keep in step.
    final album = widget.album;
    final whole = _whole && album != null;
    final specs = messageActionSpecs(
      l10n: AppLocalizations.of(context),
      capabilities: whole ? album.capabilities : widget.capabilities,
      isPinned: widget.isPinned,
      isSaved: widget.isSaved,
      isTranslated: widget.isTranslated,
      hasFileName: !whole && widget.fileName != null,
    );

    final pressed = widget.bubbleRect;
    const gap = 8.0;
    const pillH = 50.0;
    const rowH = 48.0;
    const sidePadding = 16.0;

    // `viewPadding`, not `padding`: `padding` is the safe area minus whatever
    // the keyboard has already eaten of it, so iOS reports `padding.bottom: 0`
    // while the keyboard is up. The island is physical and never goes anywhere,
    // so the top of the band is `viewPadding.top` in both states.
    final topSafe = media.viewPadding.top + 12;
    // At the bottom the keyboard and the home indicator OVERLAP rather than
    // stack — the keys are drawn over the indicator — so the bottom of the band
    // is the larger of the two, never their sum.
    final bottomSafe =
        math.max(media.viewInsets.bottom, media.viewPadding.bottom) + 12;
    final bandTop = topSafe;
    final bandBottom = math.max(topSafe, screen.height - bottomSafe);

    // What the list WANTS. When the band cannot hold it beside a readable
    // preview, `_ActionList` scrolls inside the height it is given rather
    // than running off the screen.
    final wantedMenuH =
        (specs.length * rowH) + 12 + _headerHeight(context, theme);

    // Pill above, preview in the middle, list below: ALWAYS, wherever the
    // bubble was pressed. The old layout picked between three shapes (split,
    // stacked under, stacked over), so the pill jumped around with the
    // bubble's position and a hand could never learn where it was. Now only
    // the preview moves: it glides the least distance that clears both, and
    // shrinks toward its own edge when it is too tall for what is left. The
    // pill's space is kept even where reactions are refused, so the list lands
    // where it always does.
    final place = holdMenuPlacement(
      pressed: pressed,
      bandTop: bandTop,
      bandBottom: bandBottom,
      pillHeight: pillH,
      wantedMenuHeight: wantedMenuH,
      gap: gap,
      maxScale: widget.previewScale,
    );
    final k = place.previewScale;
    final pillTop = place.pillTop;
    final menuTop = place.menuTop;
    final menuH = place.menuHeight;
    final menuScrolls = menuH < wantedMenuH;
    final liftDy = place.liftDy;

    // The settled preview's rect, which the chrome anchors to sideways.
    final bubble = Rect.fromLTWH(
      widget.isMine ? pressed.right - pressed.width * k : pressed.left,
      place.previewTop,
      pressed.width * k,
      pressed.height * k,
    );

    // Pill / menu align to the bubble's leading edge, held off the SIDE safe
    // area the same way they are held off the top one — in landscape on a
    // notched phone that is a real 44pt of screen the menu does not have, and
    // the sensor housing is on the leading edge exactly half the time.
    final leftSafe = media.viewPadding.left + sidePadding;
    final rightSafe = media.viewPadding.right + sidePadding;
    final (double? edgeLeft, double? edgeRight) = widget.isMine
        ? (
            null,
            (screen.width - bubble.right)
                .clamp(rightSafe, math.max(rightSafe, screen.width - rightSafe))
          )
        : (
            bubble.left
                .clamp(leftSafe, math.max(leftSafe, screen.width - leftSafe)),
            null
          );

    // Material(type: transparency) supplies the DefaultTextStyle that the
    // root overlay otherwise lacks — without it, every Text inside paints
    // Flutter's debug "missing ancestor" yellow underlines.
    return Material(
      type: MaterialType.transparency,
      // Esc dismisses, and Tab can't escape into the widgets behind the scrim.
      // Routed through _resolve so Esc gets the same exit animation and
      // re-entrancy guard as a scrim tap.
      child: OverlayModalScope(
        onDismiss: () => _resolve(null),
        child: Stack(
        children: [
          BlurScrim(
            t: curved,
            backdrop: widget.backdrop,
            onTap: () => _resolve(null),
          ),
          _LiftedBubble(
            t: curved,
            rect: pressed,
            settle: k,
            dy: liftDy,
            isMine: widget.isMine,
            // A still photograph, not a live bubble. `_LiftedBubble` forces
            // this into the rect the real one occupied at press time, so
            // anything inside that keeps changing overflows it — which a
            // translation streaming in underneath did, by 8.9 points. See
            // [FrozenBubble].
            child: FrozenBubble(
              child: () {
                // The pile on "All", the card on "This one", cross-faded as
                // the switch flips. Photographs only, so a fade is free.
                final stack = album?.stackBuilder;
                final builder =
                    whole && stack != null ? stack : widget.bubbleBuilder;
                final preview = AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  // Unclipped: the pile's side cards sit outside the rect.
                  layoutBuilder: (current, previous) => Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(whole && stack != null),
                    child: Builder(builder: builder),
                  ),
                );
                return widget.metrics == null
                    ? preview
                    : ChatMetricsScope(
                        metrics: widget.metrics!,
                        child: preview,
                      );
              }(),
            ),
          ),
        // Absent where the room's posting policy refuses reactions
        // (`MessageCapabilities.canReact`); the space it would take stays, so
        // the menu lands where it always does.
        if (widget.capabilities.canReact)
        Positioned(
          top: pillTop,
          left: edgeLeft,
          right: edgeRight,
          child: _AnimatedEntry(
            t: curved,
            fromAbove: false,
            alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: _ReactionPill(
              key: _pillKey,
              isMine: widget.isMine,
              emojis: _pillEmojis = quickPillEmojis(
                whole ? album.myReactions : widget.myReactions,
              ),
              selected: whole ? album.myReactions : widget.myReactions,
              focus: _focus,
              onEmoji: (e) => _pickEmoji(e, whole),
              onMore: () => _pickMore(whole),
            ),
          ),
        ),
        // The emoji under a sliding finger, magnified and lifted clear of the
        // pill. Drawn here rather than scaled inside the pill because the
        // pill's glass clips its contents to the capsule.
        Positioned(
          top: pillTop - 36 >= media.viewPadding.top + 4
              ? pillTop - 36
              : menuTop + menuH + gap,
          left: edgeLeft,
          right: edgeRight,
          child: _CancelHint(
            visible: _offPill,
            alignment: widget.isMine
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            child: Text(
              AppLocalizations.of(context).holdMenuReleaseToCancel,
              style: theme.caption,
            ),
          ),
        ),
        Positioned(
          top: menuTop,
          left: edgeLeft,
          right: edgeRight,
          child: _AnimatedEntry(
            t: curved,
            fromAbove: true,
            delay: 0.08,
            alignment: widget.isMine ? Alignment.topRight : Alignment.topLeft,
            child: _ActionList(
              specs: specs,
              fileName: whole ? null : widget.fileName,
              header: album == null
                  ? null
                  : _AlbumSwitch(
                      album: album,
                      whole: _whole,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _whole = v);
                      },
                    ),
              // Null unless the band forced a clamp — an unconstrained list
              // shrink-wraps exactly as it always has.
              maxHeight: menuScrolls ? menuH : null,
              onAction: (a) {
                // Delete is the one action with no confirm behind it, so it
                // is the one that lands with some weight.
                if (a == MessageAction.delete) {
                  HapticFeedback.mediumImpact();
                } else {
                  HapticFeedback.lightImpact();
                }
                _resolve(MessageActionResult.action(a, album: whole));
              },
            ),
          ),
        ),
        // The emoji under a sliding finger, magnified and lifted clear of the
        // pill (the pill's glass clips its contents, so it cannot grow in
        // place). One glyph that glides from slot to slot rather than one per
        // slot, and that flies down onto the message once picked. Last in the
        // stack so the flight passes over the bubble, not under it.
        _ScrubMagnifier(
          pillKey: _pillKey,
          emojis: _pillEmojis,
          index: _focus != null && _focus! < _pillEmojis.length
              ? _focus
              : null,
          flyTo: _flyTo,
        ),
        ],
        ),
      ),
    );
  }
}

// ───────────────────────── lifted bubble ─────────────────────────

class _LiftedBubble extends StatelessWidget {
  const _LiftedBubble({
    required this.t,
    required this.rect,
    required this.isMine,
    required this.child,
    this.dy = 0,
    this.settle = 1,
  });
  final Animation<double> t;
  final Rect rect;

  /// The scale it settles at, before the lift's own 3% (see
  /// `previewMaxHeight`).
  final double settle;
  final bool isMine;
  final Widget child;

  /// How far the bubble travels, at full lift, to clear a stacked menu.
  final double dy;

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
            // Lifts toward 1.03 — the long-press "pick up", subtle enough
            // that the bubble reads as raised rather than zoomed.
            final scale = (1 + (settle - 1) * t.value) * (1 + 0.03 * t.value);
            return Transform.translate(
              offset: Offset(0, dy * t.value),
              child: Transform.scale(
                scale: scale,
                alignment:
                    isMine ? Alignment.centerRight : Alignment.centerLeft,
                // No drop shadow. [rect] is the bubble's whole row — stamp,
                // gutter and all — not its rounded shape, and every theme
                // draws a different shape (tails, square Risograph corners),
                // so a shadow here is a square grey slab under a round
                // bubble. The scrim already lifts the bubble off the chat.
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

// ───────────────────────── animated entry wrapper ─────────────────────────

class _AnimatedEntry extends StatelessWidget {
  const _AnimatedEntry({
    required this.t,
    required this.fromAbove,
    required this.alignment,
    required this.child,
    this.delay = 0.04,
  });
  final Animation<double> t;
  final bool fromAbove;
  final Alignment alignment;
  final Widget child;
  // Fraction of the animation to delay this entry (0..1).
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (_, c) {
        final raw = (t.value - delay) / (1 - delay);
        final v = raw.clamp(0.0, 1.0);
        // The jelly's overshoot, which the reveal below cannot show (it
        // clamps): the glass swells past full size and rings back.
        final swell = raw > 1 ? 1 + (raw - 1) * 0.5 : 1.0;
        final dy = (fromAbove ? -6 : 6) * (1 - v);
        // Grown, not faded: the pill and the action list are glass, and a
        // fading layer leaves glass blurring an empty buffer, a flat white
        // flash on every open and close. See [GlassReveal].
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: swell,
            alignment: alignment,
            child: GlassReveal(t: v, alignment: alignment, from: 0.6, child: c!),
          ),
        );
      },
      child: child,
    );
  }
}

// ───────────────────────── reaction pill ─────────────────────────

/// The six emoji the pill shows, given what the viewer already reacted with.
///
/// The quick set, unless the viewer used something outside it: then their own
/// emoji take the TRAILING quick slots (WhatsApp's behaviour), so a reaction
/// you left is always in the pill to see and take back, and the pill never
/// grows past six — it is sized to fit a phone's width with the `+`.
/// Selected quick emoji keep their place; only unselected ones give theirs up.
/// Shared with the pointer menu (`message_context_menu.dart`), so a long-press
/// and a right-click offer the same six.
List<String> quickPillEmojis(Set<String> selected) {
  final extras = [
    for (final e in selected)
      if (!_kQuickReactions.contains(e)) e,
  ];
  if (extras.isEmpty) return _kQuickReactions;
  final out = [..._kQuickReactions];
  // Walk from the end, replacing quick emoji the viewer did NOT use.
  var i = out.length - 1;
  for (final e in extras.take(_kQuickReactions.length)) {
    while (i >= 0 && selected.contains(out[i])) {
      i--;
    }
    if (i < 0) break;
    out[i] = e;
    i--;
  }
  return out;
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    super.key,
    required this.isMine,
    required this.emojis,
    required this.selected,
    required this.onEmoji,
    required this.onMore,
    this.focus,
  });
  final bool isMine;

  /// What the pill shows, from [quickPillEmojis].
  final List<String> emojis;
  final Set<String> selected;
  final ValueChanged<String> onEmoji;
  final VoidCallback onMore;

  /// The slot under a sliding finger (`emojis.length` is the `+`). The
  /// focused emoji is drawn magnified ABOVE the pill by the overlay, so here
  /// it steps aside; its neighbours swell a little toward it.
  final int? focus;

  /// Horizontal inset of the glass around the first and last slot. The
  /// scrub's hit test reads it, so it is the one number for both.
  static const double padding = 6;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final f = focus;
    double scaleOf(int i) {
      if (f == null) return 1;
      if (i == f) return i == emojis.length ? 1.1 : 0;
      if ((i - f).abs() == 1) return 1.06;
      return 1;
    }

    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: padding, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, e) in emojis.indexed)
            _PillEmoji(
              emoji: e,
              selected: selected.contains(e),
              scrubScale: scaleOf(i),
              onTap: () => onEmoji(e),
            ),
          _PillMore(
            onTap: onMore,
            theme: theme,
            scrubScale: scaleOf(emojis.length),
          ),
        ],
      ),
    );
  }
}

/// The emoji under a sliding finger, drawn large over its slot in the pill:
/// the keyboard key-popup, so the finger never covers what it is choosing.
///
/// Everything about it moves rather than cuts: it grows out of the pill when
/// the finger arrives, glides sideways from slot to slot, swaps its glyph with
/// a quick scale, sinks back into the pill when the finger leaves, and, when
/// [flyTo] is set, arcs down onto the message and shrinks into it.
class _ScrubMagnifier extends StatefulWidget {
  const _ScrubMagnifier({
    required this.pillKey,
    required this.emojis,
    required this.index,
    required this.flyTo,
  });
  final GlobalKey pillKey;
  final List<String> emojis;

  /// The focused EMOJI slot (never the `+`), or null.
  final int? index;
  final Offset? flyTo;

  static const Duration flight = Duration(milliseconds: 460);

  @override
  State<_ScrubMagnifier> createState() => _ScrubMagnifierState();
}

/// Driven by retargetable springs ([Spring]) rather than fixed tweens, so a
/// finger that changes its mind mid-glide bends the motion instead of
/// restarting it, and the glyph lags, overshoots and rings like jelly:
///
///  * [_x] chases the focused slot, a little loose, so it swings past and
///    settles back.
///  * [_grow] blows it up out of the pill and lets it wobble at full size.
///  * its own speed squashes and stretches it along the direction of travel,
///    and tilts it into the turn.
class _ScrubMagnifierState extends State<_ScrubMagnifier>
    with TickerProviderStateMixin {
  static const double _box = 48;

  final Spring _x = Spring(response: 0.26, ratio: 0.72);
  final Spring _grow = Spring(response: 0.32, ratio: 0.62);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: _ScrubMagnifier.flight,
  )..addListener(() => setState(() {}));

  String _glyph = '';
  double _y = 0;

  /// Where the glyph sits over [index]'s slot, in window coordinates (the
  /// overlay fills the window).
  Offset? _slotCenter(int index) {
    final box = widget.pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = _ReactionPill.padding + _PillEmoji.size * (index + 0.5);
    // Centered on the pill's top edge: lifted just clear of the finger,
    // still reading as the slot's own emoji rather than a separate bubble.
    return box.localToGlobal(Offset(rtl ? box.size.width - x : x, 0));
  }

  bool get _calm => MotionScope.of(context).calm;

  void _kick() {
    if (_calm) {
      _x.snap(_x.target);
      _grow.snap(_grow.target);
      setState(() {});
      return;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _x.tick(dt);
    _grow.tick(dt);
    setState(() {});
    if (_x.atRest && _grow.atRest) _ticker.stop();
  }

  void _aim(int i) {
    final at = _slotCenter(i);
    if (at == null) return;
    _glyph = widget.emojis[i];
    _y = at.dy;
    if (_grow.value < 0.05 && _grow.target == 0) {
      // Arriving from nothing: appear over the slot, then blow up.
      _x.snap(at.dx);
    } else {
      _x.retarget(at.dx);
    }
    _grow.retarget(1, response: 0.32, ratio: 0.62);
    _kick();
  }

  @override
  void didUpdateWidget(_ScrubMagnifier old) {
    super.didUpdateWidget(old);
    final i = widget.index;
    if (widget.flyTo != null) {
      if (old.flyTo == null) {
        if (i != null && (_grow.target == 0 || _glyph != widget.emojis[i])) {
          _aim(i);
        }
        _calm ? _fly.value = 1 : _fly.forward();
      }
      return;
    }
    if (i == null) {
      if (_grow.target != 0) {
        // Critically damped on the way OUT: a wobbly spring would swing
        // through zero and back, and the glyph would blink up again.
        _grow.retarget(0, response: 0.22, ratio: 1);
        _kick();
      }
      return;
    }
    if (i != old.index || _grow.target == 0) _aim(i);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Never below zero: an underdamped spring heading to 0 swings past it,
    // and a negative scale draws a mirrored glyph (the trace this replaced).
    final g = math.max(0.0, _grow.value);
    final f = _fly.value;
    if (g < 0.01 && f == 0) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    var c = Offset(_x.value, _y);
    var scale = g;
    var opacity = 1.0;

    // Jelly: squash and stretch along the direction of travel, lean into it.
    final v = _x.velocity;
    final stretch = (v.abs() / 6000).clamp(0.0, 0.1);
    var sx = 1 + stretch;
    var sy = 1 - stretch * 0.6;
    var tilt = (v / 14000).clamp(-0.08, 0.08);

    final target = widget.flyTo;
    if (target != null && f > 0) {
      // An arc onto the message: up and over, then down, shrinking toward
      // chip size, rolling forward as it goes, and a soft squash as it lands.
      final p = Curves.easeInOutCubic.transform(f);
      c = Offset.lerp(c, target, p)! -
          Offset(0, 22 * math.sin(math.pi * f));
      scale *= 1 - 0.55 * Curves.easeIn.transform(f);
      tilt += 0.12 * math.sin(math.pi * f) * (target.dx < c.dx ? -1 : 1);
      final land = ((f - 0.78) / 0.22).clamp(0.0, 1.0);
      final squash = math.sin(math.pi * land) * 0.08;
      sx *= 1 + squash;
      sy *= 1 - squash;
      opacity = f > 0.86 ? (1 - (f - 0.86) / 0.14).clamp(0.0, 1.0) : 1;
    }

    return Positioned(
      left: c.dx - _box / 2,
      top: c.dy - _box / 2,
      width: _box,
      height: _box,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..rotateZ(tilt)
              ..scaleByDouble(scale * sx, scale * sy, 1, 1),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: const JellyCurve(overshoot: 0.08),
              switchOutCurve: Curves.easeInCubic,
              // `t` is already jelly-curved and runs past 1, so nothing here
              // may feed it into another Curve (they assert 0..1; chaining an
              // Interval threw on every overshoot frame). Plain math instead.
              transitionBuilder: (child, t) => AnimatedBuilder(
                animation: t,
                builder: (_, c) => Opacity(
                  opacity: (t.value / 0.3).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: math.max(0.0, t.value),
                    child: c,
                  ),
                ),
                child: child,
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: [...previous, ?current],
              ),
              child: Center(
                key: ValueKey(_glyph),
                child: Text(_glyph, style: const TextStyle(fontSize: 32)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Release to cancel": grows out of the pill when a sliding finger leaves
/// it and sinks back when it returns. Grown, not faded, for the reason
/// [_AnimatedEntry] gives: a fading glass layer flashes.
class _CancelHint extends StatefulWidget {
  const _CancelHint({
    required this.visible,
    required this.alignment,
    required this.child,
  });
  final bool visible;
  final Alignment alignment;
  final Widget child;

  @override
  State<_CancelHint> createState() => _CancelHintState();
}

class _CancelHintState extends State<_CancelHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
    reverseDuration: const Duration(milliseconds: 160),
    value: widget.visible ? 1 : 0,
  );

  @override
  void didUpdateWidget(_CancelHint old) {
    super.didUpdateWidget(old);
    if (widget.visible != old.visible) {
      widget.visible ? _c.forward() : _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          if (_c.value == 0) return const SizedBox.shrink();
          final v = _c.status == AnimationStatus.reverse
              ? Curves.easeInCubic.transform(_c.value)
              : const JellyCurve(overshoot: 0.06).transform(_c.value);
          return Align(
            alignment: widget.alignment,
            widthFactor: 1,
            heightFactor: 1,
            child: Transform.translate(
              offset: Offset(0, 6 * (1 - v)),
              child: GlassReveal(
                t: v,
                alignment: widget.alignment,
                from: 0.6,
                child: child!,
              ),
            ),
          );
        },
        child: GlassSurface(
          radius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PillEmoji extends StatefulWidget {
  const _PillEmoji({
    required this.emoji,
    required this.onTap,
    this.selected = false,
    this.scrubScale = 1,
  });
  final String emoji;
  final VoidCallback onTap;

  /// Width of one slot. The scrub's hit test divides by it.
  static const double size = 38;

  /// Set by a sliding finger: 0 when this one is magnified above the pill,
  /// a little over 1 beside it. See [_ReactionPill.focus].
  final double scrubScale;

  /// Already one of the viewer's reactions — tapping it takes it back.
  final bool selected;

  @override
  State<_PillEmoji> createState() => _PillEmojiState();
}

class _PillEmojiState extends State<_PillEmoji>
    with TeardownSafe<_PillEmoji> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // FocusableTap so a keyboard can reach it; the pointer keeps its own
    // press below.
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: widget.emoji,
      selected: widget.selected,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        // Leaving for the magnifier, the glyph is gone from its slot in the
        // SAME frame the magnifier starts growing out of it: a hand-off, not
        // two glyphs. It used to shrink to 0 on easeOutBack, which swings
        // below zero and drew a tiny mirrored copy for a few frames; a quick
        // fade instead still left a ghost. Everything else (swelling beside
        // the finger, popping back in when the finger leaves) rings like
        // jelly.
        child: AnimatedOpacity(
          opacity: widget.scrubScale == 0 ? 0 : 1,
          duration: widget.scrubScale == 0
              ? Duration.zero
              : const Duration(milliseconds: 160),
          child: AnimatedScale(
          scale: _pressed ? 1.22 : math.max(widget.scrubScale, 0.35),
          duration: widget.scrubScale == 0
              ? Duration.zero
              : const Duration(milliseconds: 480),
          curve: const JellyCurve(overshoot: 0.08),
          // The selected disc is the iMessage tapback's: a soft accent wash
          // behind the glyph, no outline — the glass pill already has an
          // edge, and a ring inside it read as a second border.
          child: Container(
            width: _PillEmoji.size,
            height: _PillEmoji.size,
            alignment: Alignment.center,
            decoration: widget.selected
                ? BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
        ),
      ),
    );
  }
}

class _PillMore extends StatefulWidget {
  const _PillMore({
    required this.onTap,
    required this.theme,
    this.scrubScale = 1,
  });
  final VoidCallback onTap;
  final AppTheme theme;

  /// See [_PillEmoji.scrubScale].
  final double scrubScale;

  @override
  State<_PillMore> createState() => _PillMoreState();
}

class _PillMoreState extends State<_PillMore>
    with TeardownSafe<_PillMore> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // FocusableTap so a keyboard can reach it; the pointer keeps its own
    // press below.
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: MaterialLocalizations.of(context).moreButtonTooltip,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 1.15 : widget.scrubScale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutBack,
          child: Container(
            width: 38,
            height: 38,
            margin: const EdgeInsets.only(left: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: quietFill(widget.theme),
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.plus, size: 16, color: widget.theme.accent),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── action list ─────────────────────────

/// The switch at the top of an album card's menu: the whole album, or the
/// one photo that was pressed. A fixed [height], so the overlay can lay the
/// menu out by arithmetic as it does every other row.
class _AlbumSwitch extends StatelessWidget {
  const _AlbumSwitch({
    required this.album,
    required this.whole,
    required this.onChanged,
  });

  static const double height = 46;

  final MessageMenuAlbum album;
  final bool whole;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
        child: IosSegmentedControl<bool>(
          segments: [
            IosSegment(value: true, label: album.allLabel),
            IosSegment(value: false, label: album.oneLabel),
          ],
          value: whole,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ActionList extends StatelessWidget {
  const _ActionList({
    required this.specs,
    required this.onAction,
    this.fileName,
    this.header,
    this.maxHeight,
  });

  /// Drawn above everything, the filename included: the album switch.
  final Widget? header;

  /// Shared with `_MessageActionMenuOverlay._headerHeight`, which has to
  /// measure the header against exactly the width it will get.
  static const double maxWidth = 240;

  /// The rows, in order — built by [messageActionSpecs], which is also where
  /// the overlay took the count it laid this list out with. Handing the same
  /// list to both is the invariant; building a second one here would be the
  /// 48pt misposition bug growing back.
  final List<MessageActionSpec> specs;
  final ValueChanged<MessageAction> onAction;

  /// Non-null for a document bubble, whose name the transcript row can only
  /// afford one line of — see [showMessageActionMenu].
  final String? fileName;

  /// Set only when the list is taller than the space it has — a small screen,
  /// an open keyboard, a long filename header, or all three. The list then
  /// scrolls inside this instead of running past the edge of the screen.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final rows = <Widget>[];

    // Ahead of every action: this is the thing the user long-pressed to read.
    // Seeded into `rows` first, so the between-rows divider below separates it
    // from the first action without a special case.
    final top = header;
    if (top != null) rows.add(top);
    final name = fileName;
    if (name != null) {
      if (rows.isNotEmpty) {
        rows.add(Container(
          height: 1 / MediaQuery.devicePixelRatioOf(context),
          color: theme.ink.withValues(alpha: 0.10),
        ));
      }
      rows.add(_FileNameHeader(name: name, theme: theme));
    }

    for (final spec in specs) {
      if (rows.isNotEmpty) {
        // A hairline at ink 0.10, the SheetGroup rule — not a 1pt grey bar.
        rows.add(Container(
          height: 1 / MediaQuery.devicePixelRatioOf(context),
          color: theme.ink.withValues(alpha: 0.10),
        ));
      }
      rows.add(_ActionRow(spec: spec, onTap: () => onAction(spec.action)));
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 200,
        maxWidth: maxWidth,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: GlassSurface(
        radius: theme.radiusLg + 6,
        padding: const EdgeInsets.symmetric(vertical: 6),
        // Only when clamped. A `SingleChildScrollView` takes the smaller of its
        // content and the constraint either way, but wrapping unconditionally
        // would make every menu in the app a scrollable — and hand the rows'
        // taps to a drag recognizer that has no reason to exist.
        child: maxHeight == null
            ? column
            : _ScrollableMenuBody(theme: theme, child: column),
      ),
    );
  }
}

/// The action list when it does not fit the space it was given.
///
/// A menu that silently ends mid-list looks like a menu with fewer actions in
/// it — there is nothing at the fold to say DELETE is one flick away. The thumb
/// is what says so.
///
/// Its own widget purely to own the [ScrollController]: [_ActionList] is
/// stateless, and `thumbVisibility` needs a controller shared with the view it
/// is measuring.
class _ScrollableMenuBody extends StatefulWidget {
  const _ScrollableMenuBody({required this.theme, required this.child});

  final AppTheme theme;
  final Widget child;

  @override
  State<_ScrollableMenuBody> createState() => _ScrollableMenuBodyState();
}

class _ScrollableMenuBodyState extends State<_ScrollableMenuBody> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.theme.ink;
    return RawScrollbar(
      controller: _controller,
      // Drawn from the moment the menu opens, not faded in on first scroll.
      // A scrollbar that appears once you scroll answers a question you have
      // already answered yourself; this one has to be there before the flick.
      thumbVisibility: true,
      thumbColor: ink.withValues(alpha: 0.32),
      thickness: 3,
      radius: const Radius.circular(2),
      // Clear of the glass surface's rounded corner, and short of both ends so
      // the thumb never sits against the edge of the menu.
      crossAxisMargin: 3,
      mainAxisMargin: 8,
      child: SingleChildScrollView(
        controller: _controller,
        padding: EdgeInsets.zero,
        child: widget.child,
      ),
    );
  }
}

/// The whole filename, printed over as many lines as it takes.
///
/// Not a row and not tappable — nothing happens when you press it. It is the
/// answer to "what is this file actually called", which the transcript's
/// single-line row cannot give without costing every document bubble the height
/// of a paragraph.
class _FileNameHeader extends StatelessWidget {
  const _FileNameHeader({required this.name, required this.theme});

  /// Read by `_MessageActionMenuOverlay._headerHeight` to measure this before
  /// it exists. Changing it here changes the measurement.
  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 12, 16, 12);

  final String name;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      // No `maxLines`. A filename is bounded by the filesystem at 255
      // characters, and a menu tall enough to prove it is still better than one
      // that ends the name in an ellipsis for the second time.
      child: Text(name, style: theme.bodyEmph.copyWith(color: theme.ink)),
    );
  }
}

/// One row of the action list: what it does, what it looks like, and whether
/// it paints in the danger colour. Public (with [messageActionSpecs]) so a
/// test can assert the ordering rule without pumping the whole overlay.
class MessageActionSpec {
  const MessageActionSpec({
    required this.action,
    required this.icon,
    required this.label,
    required this.destructive,
  });
  final MessageAction action;
  final IconData icon;
  final String label;
  final bool destructive;
}

/// The menu's rows for [capabilities], in display order. THE single source:
/// the overlay's height math uses this list's length and `_ActionList` renders
/// this exact list, which is what retired the hand-synced `_actionCount()`
/// whose drift used to misposition the menu by 48pt.
///
/// Ordering rule: constructive → neutral → destructive.
List<MessageActionSpec> messageActionSpecs({
  required AppLocalizations l10n,
  required MessageCapabilities capabilities,
  required bool isPinned,
  required bool isSaved,
  required bool isTranslated,
  required bool hasFileName,
}) {
  final caps = capabilities;
  return [
    if (caps.canReply)
      MessageActionSpec(
        action: MessageAction.reply,
        icon: CupertinoIcons.arrowshape_turn_up_left,
        label: l10n.messageActionMenuReplyLabel,
        destructive: false,
      ),
    // Directly after REPLY: both reopen the composer around this message —
    // one to answer it, one to rewrite it — and EDIT ahead of the send-it-
    // somewhere rows keeps the "changes this conversation" actions together.
    if (caps.canEdit)
      MessageActionSpec(
        action: MessageAction.edit,
        icon: CupertinoIcons.pencil,
        label: l10n.messageActionMenuEditLabel,
        destructive: false,
      ),
    // Both are "send this somewhere", and forwarding one message is the
    // single-item case of what the selection bar does for many.
    if (caps.canForward)
      MessageActionSpec(
        action: MessageAction.forward,
        icon: CupertinoIcons.arrowshape_turn_up_right,
        label: l10n.messageActionMenuForwardLabel,
        destructive: false,
      ),
    if (caps.canViewThread)
      MessageActionSpec(
        action: MessageAction.viewThread,
        icon: CupertinoIcons.arrow_branch,
        label: l10n.messageActionMenuViewThreadLabel,
        destructive: false,
      ),
    if (caps.canCopy)
      MessageActionSpec(
        action: MessageAction.copy,
        icon: CupertinoIcons.doc_on_doc,
        label: l10n.messageActionMenuCopyLabel,
        destructive: false,
      ),
    // Takes COPY's slot rather than sitting beside it: `canCopy` is a text
    // message with a body, and a document has neither. Reading the name off
    // the header is one thing; getting it into a search field is another.
    if (caps.canCopyName && hasFileName)
      MessageActionSpec(
        action: MessageAction.copyName,
        icon: CupertinoIcons.doc_on_doc,
        label: l10n.messageActionMenuCopyNameLabel,
        destructive: false,
      ),
    // Same slot family as COPY / COPY NAME — a third "put something from this
    // message on the clipboard" row, gated to location shares the way COPY
    // NAME is gated to documents. The clipboard icon it shares with them is
    // what says so at a glance.
    if (caps.canCopyCoordinates)
      MessageActionSpec(
        action: MessageAction.copyCoordinates,
        icon: CupertinoIcons.doc_on_doc,
        label: l10n.messageActionMenuCopyCoordinatesLabel,
        destructive: false,
      ),
    // Directly after the clipboard rows, because it belongs to the same family
    // as COPY: all of them are "do something with the WORDS in this message"
    // and none of them changes anything anyone else can see. Ahead of PIN,
    // which is where the shared-state actions start.
    if (caps.canTranslate && isTranslated)
      MessageActionSpec(
        action: MessageAction.translateAgain,
        icon: CupertinoIcons.arrow_clockwise,
        label: l10n.messageActionMenuTranslateAgainLabel,
        destructive: false,
      ),
    if (caps.canTranslate)
      MessageActionSpec(
        action: isTranslated
            ? MessageAction.showOriginal
            : MessageAction.translate,
        // `globe` and not `sparkles` or a robot: this app's position is that a
        // companion is a person doing a job, not an AI feature, and the icon is
        // where that either holds or visibly doesn't.
        icon: isTranslated
            ? CupertinoIcons.arrow_uturn_left
            : CupertinoIcons.globe,
        label: isTranslated
            ? l10n.messageActionMenuShowOriginalLabel
            : l10n.messageActionMenuTranslateLabel,
        destructive: false,
      ),
    // Beside COPY rather than next to the destructive pair: a pin is shared
    // room state, not something done TO the message. Unpinning is reversible,
    // so neither is marked destructive — red would overstate it.
    if (caps.canPin)
      MessageActionSpec(
        action: isPinned ? MessageAction.unpin : MessageAction.pin,
        icon: isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
        label: isPinned
            ? l10n.messageActionMenuUnpinLabel
            : l10n.messageActionMenuPinLabel,
        destructive: false,
      ),
    // Directly after PIN, because the two are the same gesture aimed at
    // different audiences — "everyone here should see this" and "I want this
    // later" — and reading them together is what makes the difference
    // legible. Neither is destructive; both undo in one tap.
    if (caps.canSave)
      MessageActionSpec(
        action: isSaved ? MessageAction.unsave : MessageAction.save,
        icon: isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
        label: isSaved
            ? l10n.messageActionMenuUnsaveLabel
            : l10n.messageActionMenuSaveLabel,
        destructive: false,
      ),
    // Last of the neutral rows, because it is the only one that does nothing
    // to this message: it hands the transcript over to multi-select with this
    // one already picked, and everything after that happens in the selection
    // bar.
    if (caps.canSelect)
      MessageActionSpec(
        action: MessageAction.select,
        icon: CupertinoIcons.checkmark_circle,
        label: l10n.messageActionMenuSelectLabel,
        destructive: false,
      ),
    // After SELECT and before the destructive pair: it reads about this
    // message and changes nothing. Only ever on your own message, so it never
    // meets VIEW PROFILE, which is only ever on someone else's.
    if (caps.canViewReceipts)
      MessageActionSpec(
        action: MessageAction.info,
        icon: CupertinoIcons.info_circle,
        label: l10n.msgDeskInfoLabel,
        destructive: false,
      ),
    if (caps.canViewProfile)
      MessageActionSpec(
        action: MessageAction.viewProfile,
        icon: CupertinoIcons.person_circle,
        label: l10n.messageActionMenuProfileLabel,
        destructive: false,
      ),
    // A moderator's two neutral answers to a report card: undo a ban, or
    // decline to act. Neither takes anything away, so neither is red, and both
    // sit above the destructive block per the ordering rule. Unban only while
    // the person IS banned; Ban (below) only while they are not.
    if (caps.canModerate && caps.canModerateUser && caps.moderatedUserBanned)
      MessageActionSpec(
        action: MessageAction.modUnbanUser,
        icon: CupertinoIcons.arrow_uturn_left_circle,
        label: l10n.moderationActionUnban,
        destructive: false,
      ),
    if (caps.canModerate)
      MessageActionSpec(
        action: MessageAction.modDismiss,
        icon: CupertinoIcons.archivebox,
        label: l10n.moderationActionDismiss,
        destructive: false,
      ),
    if (caps.canDelete)
      MessageActionSpec(
        action: MessageAction.delete,
        icon: CupertinoIcons.trash,
        label: l10n.messageActionMenuDeleteLabel,
        destructive: true,
      ),
    if (caps.canReport)
      MessageActionSpec(
        action: MessageAction.report,
        icon: CupertinoIcons.flag,
        label: l10n.messageActionMenuReportLabel,
        destructive: true,
      ),
    // Last, and only ever on a report card: the two moderator actions that
    // take something away. Their neutral siblings sit above the red block.
    if (caps.canModerate && caps.canModerateMessage)
      MessageActionSpec(
        action: MessageAction.modRemoveMessage,
        icon: CupertinoIcons.trash,
        label: l10n.moderationActionRemoveMessage,
        destructive: true,
      ),
    if (caps.canModerate && caps.canModerateContent)
      MessageActionSpec(
        action: MessageAction.modRemoveContent,
        icon: CupertinoIcons.trash,
        label: l10n.moderationActionRemoveContent,
        destructive: true,
      ),
    if (caps.canModerate && caps.canModerateUser && !caps.moderatedUserBanned)
      MessageActionSpec(
        action: MessageAction.modBanUser,
        icon: CupertinoIcons.nosign,
        label: l10n.moderationActionBan,
        destructive: true,
      ),
  ];
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({required this.spec, required this.onTap});
  final MessageActionSpec spec;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow>
    with TeardownSafe<_ActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = widget.spec.destructive ? theme.danger : theme.ink;
    // FocusableTap so a keyboard can reach it; the pointer keeps its own
    // press below.
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: sentenceCaseOf(context, widget.spec.label),
      radius: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        // The iOS context-menu row, the same one the chat list's long-press
        // menu draws: the label in 17pt body type and sentence case on the
        // left, the glyph on the right, a neutral wash under the finger. It
        // was tracked caps with a leading icon — a second dialect of the same
        // menu. Fixed at [rowH] less the hairline so the placement maths in
        // the overlay stays exact.
        child: AnimatedContainer(
          duration: _pressed ? Duration.zero : const Duration(milliseconds: 200),
          height: 47,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: _pressed
              ? theme.ink.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  sentenceCaseOf(context, widget.spec.label),
                  style: theme.body.copyWith(
                    fontSize: 17,
                    color: color,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(widget.spec.icon, size: 19, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

