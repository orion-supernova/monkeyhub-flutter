import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/message_capabilities.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';
import 'translation_slab.dart' show FrozenBubble;

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
  delete,
  report,
  viewProfile,
}

/// Resolved choice from [showMessageActionMenu]. Exactly one of the three
/// shapes is filled in:
/// * `.action(...)` — user tapped a list row
/// * `.emoji(...)` — user tapped one of the quick reactions in the pill
/// * `.fullPicker()` — user tapped `+` and wants the full picker
class MessageActionResult {
  const MessageActionResult.action(MessageAction this.action)
      : emoji = null,
        openFullReactionPicker = false;
  const MessageActionResult.emoji(String this.emoji)
      : action = null,
        openFullReactionPicker = false;
  const MessageActionResult.fullPicker()
      : action = null,
        emoji = null,
        openFullReactionPicker = true;

  final MessageAction? action;
  final String? emoji;
  final bool openFullReactionPicker;
}

const List<String> _kQuickReactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

/// Long-press context menu for a chat bubble. Inserts a root-overlay entry
/// that blurs the chat behind, lifts the tapped bubble at its original
/// position, and floats a reaction pill + action list anchored to the
/// bubble's leading edge. Returns when the user picks something or
/// dismisses via the scrim.
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
    required this.onResolve,
  });

  final Rect bubbleRect;

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resolve(MessageActionResult? result) async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
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
    final name = widget.fileName;
    if (name == null) return 0;
    final painter = TextPainter(
      text: TextSpan(text: name, style: theme.bodyEmph),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _ActionList.maxWidth - _FileNameHeader.padding.horizontal);
    return painter.height + _FileNameHeader.padding.vertical + 1; // + divider
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
    final curved = CurvedAnimation(parent: _ctrl, curve: theme.motionEntrance);
    final media = MediaQuery.of(context);
    final screen = media.size;

    // Built ONCE per layout, here, and handed to `_ActionList` verbatim. The
    // row count used to be a second, hand-synced copy of the list's if-chain
    // (`_actionCount()`), whose comment warned that a missed row mispositions
    // the whole menu by 48pt near a screen edge. Now the count is
    // `specs.length` by construction and there is nothing to keep in step.
    final specs = messageActionSpecs(
      l10n: AppLocalizations.of(context),
      capabilities: widget.capabilities,
      isPinned: widget.isPinned,
      isSaved: widget.isSaved,
      isTranslated: widget.isTranslated,
      hasFileName: widget.fileName != null,
    );

    final bubble = widget.bubbleRect;
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

    // The band the menu is allowed to live in, and the ceiling that follows
    // from it: pill, menu, and the gaps between them all have to come out of
    // the same height.
    final bandTop = topSafe;
    final bandBottom = math.max(topSafe, screen.height - bottomSafe);
    final maxMenuH = math.max(0.0, (bandBottom - bandTop) - pillH - gap * 2);

    // What the list WANTS. It gets [menuH], which is that clamped to the band —
    // and when the clamp bites, `_ActionList` scrolls inside it rather than
    // running off the screen.
    final wantedMenuH =
        (specs.length * rowH) + 12 + _headerHeight(context, theme);
    final menuH = math.min(wantedMenuH, maxMenuH);
    final menuScrolls = menuH < wantedMenuH;

    // The bubble is where it is — it can be half under the island, or half
    // under the keyboard, and the transcript is free to leave it there. The
    // menu is not. Everything below anchors to the bubble CLAMPED INTO THE
    // BAND, so a bubble hanging outside it pulls the menu only as far as the
    // edge and no further; measuring against the raw rect is how a menu ends up
    // arguing with the safe area and losing.
    final anchorTop = bubble.top.clamp(bandTop, bandBottom);
    final anchorBottom = bubble.bottom.clamp(bandTop, bandBottom);

    final spaceAbove = anchorTop - bandTop;
    final spaceBelow = bandBottom - anchorBottom;

    // Preferred: the bubble sits BETWEEN them — reactions above it, actions
    // below — which is what makes the lifted bubble read as the thing both are
    // acting on. Taken only when both land inside the band untouched.
    final splitPillTop = anchorTop - gap - pillH;
    final splitMenuTop = anchorBottom + gap;
    final split = splitPillTop >= bandTop && splitMenuTop + menuH <= bandBottom;

    final double pillTop;
    final double menuTop;
    if (split) {
      pillTop = splitPillTop;
      menuTop = splitMenuTop;
    } else {
      // One stack, placed and clamped as a UNIT. Clamping the two separately is
      // what put the menu on top of the reaction pill: each was individually
      // inside the band and they were both pushed to the same end of it, so the
      // quick reactions became unreachable. Moved together they cannot collide,
      // and `maxMenuH` above guarantees the pair fits the band by construction.
      //
      // Pill leads, because it is the shorter of the two and the one you reach
      // for without reading.
      final groupH = pillH + gap + menuH;
      final double wanted = spaceBelow >= spaceAbove
          ? anchorBottom + gap
          : anchorTop - gap - groupH;
      final groupTop = wanted
          .clamp(bandTop, math.max(bandTop, bandBottom - groupH))
          .toDouble();
      pillTop = groupTop;
      menuTop = groupTop + pillH + gap;
    }

    // Both entries slide in from the bubble's side, so each reads as growing
    // out of the message rather than arriving from off-screen. Derived from
    // where they actually landed, not from where they were asked to go.
    final pillBelowBubble = pillTop >= bubble.top;
    final menuBelowBubble = menuTop >= bubble.top;

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
          _Scrim(t: curved, onTap: () => _resolve(null)),
          _LiftedBubble(
            t: curved,
            rect: bubble,
            isMine: widget.isMine,
            // A still photograph, not a live bubble. `_LiftedBubble` forces
            // this into the rect the real one occupied at press time, so
            // anything inside that keeps changing overflows it — which a
            // translation streaming in underneath did, by 8.9 points. See
            // [FrozenBubble].
            child: FrozenBubble(
              child: widget.metrics == null
                  ? Builder(builder: widget.bubbleBuilder)
                  : ChatMetricsScope(
                      metrics: widget.metrics!,
                      child: Builder(builder: widget.bubbleBuilder),
                    ),
            ),
          ),
        Positioned(
          top: pillTop,
          left: edgeLeft,
          right: edgeRight,
          child: _AnimatedEntry(
            t: curved,
            fromAbove: pillBelowBubble,
            alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: _ReactionPill(
              isMine: widget.isMine,
              onEmoji: (e) {
                HapticFeedback.lightImpact();
                _resolve(MessageActionResult.emoji(e));
              },
              onMore: () {
                HapticFeedback.selectionClick();
                _resolve(const MessageActionResult.fullPicker());
              },
            ),
          ),
        ),
        Positioned(
          top: menuTop,
          left: edgeLeft,
          right: edgeRight,
          child: _AnimatedEntry(
            t: curved,
            fromAbove: menuBelowBubble,
            delay: 0.08,
            alignment: widget.isMine ? Alignment.topRight : Alignment.topLeft,
            child: _ActionList(
              specs: specs,
              fileName: widget.fileName,
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
                _resolve(MessageActionResult.action(a));
              },
            ),
          ),
        ),
        ],
        ),
      ),
    );
  }
}

// ───────────────────────── scrim ─────────────────────────

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

// ───────────────────────── lifted bubble ─────────────────────────

class _LiftedBubble extends StatelessWidget {
  const _LiftedBubble({
    required this.t,
    required this.rect,
    required this.isMine,
    required this.child,
  });
  final Animation<double> t;
  final Rect rect;
  final bool isMine;
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
            final scale = 1 + 0.04 * t.value;
            return Transform.scale(
              scale: scale,
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14 * t.value),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
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
        final v = ((t.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final dy = (fromAbove ? -6 : 6) * (1 - v);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Transform.scale(
              scale: 0.86 + 0.14 * v,
              alignment: alignment,
              child: c,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

// ───────────────────────── reaction pill ─────────────────────────

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.isMine, required this.onEmoji, required this.onMore});
  final bool isMine;
  final ValueChanged<String> onEmoji;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in _kQuickReactions) _PillEmoji(emoji: e, onTap: () => onEmoji(e)),
          _PillMore(onTap: onMore, theme: theme),
        ],
      ),
    );
  }
}

class _PillEmoji extends StatefulWidget {
  const _PillEmoji({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  State<_PillEmoji> createState() => _PillEmojiState();
}

class _PillEmojiState extends State<_PillEmoji> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 1.22 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

class _PillMore extends StatefulWidget {
  const _PillMore({required this.onTap, required this.theme});
  final VoidCallback onTap;
  final AppTheme theme;

  @override
  State<_PillMore> createState() => _PillMoreState();
}

class _PillMoreState extends State<_PillMore> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          width: 38,
          height: 38,
          margin: const EdgeInsets.only(left: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.theme.accentSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(CupertinoIcons.plus, size: 16, color: widget.theme.accent),
        ),
      ),
    );
  }
}

// ───────────────────────── action list ─────────────────────────

class _ActionList extends StatelessWidget {
  const _ActionList({
    required this.specs,
    required this.onAction,
    this.fileName,
    this.maxHeight,
  });

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
    final name = fileName;
    if (name != null) rows.add(_FileNameHeader(name: name, theme: theme));

    for (final spec in specs) {
      if (rows.isNotEmpty) {
        rows.add(Container(height: 1, color: theme.divider.withValues(alpha: 0.5)));
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
    if (caps.canViewProfile)
      MessageActionSpec(
        action: MessageAction.viewProfile,
        icon: CupertinoIcons.person_circle,
        label: l10n.messageActionMenuProfileLabel,
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
  ];
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({required this.spec, required this.onTap});
  final MessageActionSpec spec;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = widget.spec.destructive ? theme.danger : theme.ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: _pressed
            ? (widget.spec.destructive
                ? theme.danger.withValues(alpha: 0.14)
                : theme.accentSoft)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(widget.spec.icon, size: 18, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.spec.label,
                style: theme.label.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

