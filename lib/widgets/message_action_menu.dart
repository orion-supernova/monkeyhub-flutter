import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';

/// Actions surfaced by [showMessageActionMenu] (reactions are handled
/// separately via [MessageActionResult.emoji] / `.fullPicker`).
/// Two entries for pinning rather than one that toggles: the label IS the
/// affordance, and a single `pin` case would force both switch sites to re-derive
/// the current state just to know what they had done. Exactly one of the two is
/// ever offered, chosen by `isPinned`.
enum MessageAction {
  reply,
  forward,
  viewThread,
  copy,

  /// Puts a document's filename on the clipboard. Distinct from [copy], which
  /// takes a message's body — a document has no body, and its name is the one
  /// thing about it worth carrying somewhere else.
  copyName,
  pin,
  unpin,
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
  required bool isMine,
  required bool canCopy,
  bool canReply = false,
  bool hasParent = false,
  bool canPin = false,
  bool isPinned = false,
  bool canForward = false,
  bool canSelect = false,

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
  final screenSize = MediaQuery.sizeOf(context);
  final safeInsets = MediaQuery.paddingOf(context);
  // From the VIEW, not from `MediaQuery.viewInsetsOf`. Every call site is
  // inside a Scaffold body, and a Scaffold with `resizeToAvoidBottomInset`
  // (the default) strips the bottom inset out of the MediaQuery it hands its
  // body — it has already resized the body, so from in there the keyboard has
  // been dealt with. This menu is not in there: it is a full-screen root
  // overlay laid over everything, and for it the keyboard is still very much
  // covering the bottom of the screen. Asking the MediaQuery gets a confident
  // zero and a menu with its last rows underneath the keys.
  final viewInsets = MediaQueryData.fromView(View.of(context)).viewInsets;

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
      canCopy: canCopy,
      canReply: canReply,
      hasParent: hasParent,
      canPin: canPin,
      isPinned: isPinned,
      canForward: canForward,
      canSelect: canSelect,
      fileName: fileName,
      screenSize: screenSize,
      safeInsets: safeInsets,
      viewInsets: viewInsets,
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
    required this.canCopy,
    required this.canReply,
    required this.hasParent,
    required this.canPin,
    required this.isPinned,
    required this.canForward,
    required this.canSelect,
    required this.fileName,
    required this.screenSize,
    required this.safeInsets,
    required this.viewInsets,
    required this.onResolve,
  });

  final Rect bubbleRect;

  /// Chat metrics captured from the pane the bubble was lifted out of; null
  /// when it wasn't inside one.
  final ChatMetrics? metrics;
  final WidgetBuilder bubbleBuilder;
  final bool isMine;
  final bool canCopy;
  final bool canReply;
  final bool hasParent;
  final bool canPin;
  final bool isPinned;
  final bool canForward;
  final bool canSelect;

  /// Non-null only for a document bubble — see [showMessageActionMenu].
  final String? fileName;
  final Size screenSize;
  final EdgeInsets safeInsets;

  /// Keyboard occlusion at the moment of the press — see [showMessageActionMenu].
  final EdgeInsets viewInsets;
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

  int _actionCount() {
    var n = 0;
    if (widget.canReply) n++;
    if (widget.canForward) n++;
    if (widget.hasParent) n++; // view thread
    if (widget.canCopy) n++;
    if (widget.fileName != null) n++; // copy name
    // Load-bearing, not bookkeeping: this drives `menuH` below, which decides
    // whether the list flips above or below the bubble. A row missing from this
    // count mispositions the whole menu by 48pt, silently, and only near the
    // top and bottom edges of the screen.
    if (widget.canPin) n++;
    if (widget.canSelect) n++;
    if (!widget.isMine) n++; // view profile
    if (widget.isMine) n++; // delete
    if (!widget.isMine) n++; // report
    return n;
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final curved = CurvedAnimation(parent: _ctrl, curve: theme.motionEntrance);

    final bubble = widget.bubbleRect;
    const gap = 8.0;
    const pillH = 50.0;
    const rowH = 48.0;
    const sidePadding = 16.0;
    final topSafe = widget.safeInsets.top + 12;
    // The keyboard is screen the menu does not have. A long-press in the room
    // unfocuses the composer first, but the hide is animated and this rect is
    // measured on the frame the press lands — and the thread overlay never
    // unfocuses at all. Counted here, the menu is laid out against the band it
    // can actually occupy rather than against a screen half of which is covered.
    final bottomSafe =
        widget.safeInsets.bottom + widget.viewInsets.bottom + 12;

    // The band the menu is allowed to live in, and the ceiling that follows
    // from it: pill, menu, and the gaps between them all have to come out of
    // the same height.
    final bandTop = topSafe;
    final bandBottom = widget.screenSize.height - bottomSafe;
    final maxMenuH = math.max(0.0, (bandBottom - bandTop) - pillH - gap * 2);

    // What the list WANTS. It gets [menuH], which is that clamped to the band —
    // and when the clamp bites, `_ActionList` scrolls inside it rather than
    // running off the screen.
    final wantedMenuH =
        (_actionCount() * rowH) + 12 + _headerHeight(context, theme);
    final menuH = math.min(wantedMenuH, maxMenuH);
    final menuScrolls = menuH < wantedMenuH;

    final spaceAbove = bubble.top - topSafe;
    final spaceBelow = bandBottom - bubble.bottom;

    // Pill prefers above; menu prefers below. Flip when there is no room
    // and the opposite side has more space.
    var pillAbove = spaceAbove >= pillH + gap;
    var menuBelow = spaceBelow >= menuH + gap;
    if (!pillAbove && !menuBelow) {
      // Pathological — pick whichever side has more room. Nothing overflows
      // off-screen any more; the clamp below pulls both back into the band and
      // they overlap the lifted bubble instead, which is recoverable in a way
      // that a row under the keyboard is not.
      pillAbove = spaceAbove >= spaceBelow;
      menuBelow = !pillAbove;
    } else if (!pillAbove && menuBelow) {
      // Pill goes below, between the bubble and the menu.
    } else if (pillAbove && !menuBelow) {
      // Menu goes above, between the pill and the bubble.
    }

    /// Pulls a placed element back inside the band. `max` on the low end so a
    /// band shorter than the element pins it to the top rather than inverting.
    double intoBand(double top, double height) =>
        top.clamp(bandTop, math.max(bandTop, bandBottom - height));

    final pillTop = intoBand(
        pillAbove ? bubble.top - gap - pillH : bubble.bottom + gap, pillH);
    final menuTop = intoBand(
        menuBelow
            ? (pillAbove ? bubble.bottom + gap : bubble.bottom + gap + pillH + gap)
            : (pillAbove
                ? bubble.top - gap - pillH - gap - menuH
                : bubble.top - gap - menuH),
        menuH);

    // Pill / menu align to the bubble's leading edge.
    final (double? edgeLeft, double? edgeRight) = widget.isMine
        ? (null, (widget.screenSize.width - bubble.right).clamp(sidePadding, widget.screenSize.width))
        : (bubble.left.clamp(sidePadding, widget.screenSize.width), null);

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
            child: widget.metrics == null
                ? widget.bubbleBuilder(context)
                : ChatMetricsScope(
                    metrics: widget.metrics!,
                    child: Builder(builder: widget.bubbleBuilder),
                  ),
          ),
        Positioned(
          top: pillTop,
          left: edgeLeft,
          right: edgeRight,
          child: _AnimatedEntry(
            t: curved,
            fromAbove: !pillAbove,
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
            fromAbove: menuBelow,
            delay: 0.08,
            alignment: widget.isMine ? Alignment.topRight : Alignment.topLeft,
            child: _ActionList(
              isMine: widget.isMine,
              canCopy: widget.canCopy,
              canReply: widget.canReply,
              hasParent: widget.hasParent,
              canPin: widget.canPin,
              isPinned: widget.isPinned,
              canForward: widget.canForward,
              canSelect: widget.canSelect,
              fileName: widget.fileName,
              // Null unless the band forced a clamp — an unconstrained list
              // shrink-wraps exactly as it always has.
              maxHeight: menuScrolls ? menuH : null,
              onAction: (a) {
                HapticFeedback.lightImpact();
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
    required this.isMine,
    required this.canCopy,
    required this.canReply,
    required this.hasParent,
    required this.canPin,
    required this.isPinned,
    required this.canForward,
    required this.canSelect,
    required this.onAction,
    this.fileName,
    this.maxHeight,
  });

  /// Shared with `_MessageActionMenuOverlay._headerHeight`, which has to
  /// measure the header against exactly the width it will get.
  static const double maxWidth = 240;

  final bool isMine;
  final bool canCopy;
  final bool canReply;
  final bool hasParent;
  final bool canPin;
  final bool isPinned;
  final bool canForward;
  final bool canSelect;
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
    void add(_ActionRowSpec spec) {
      if (rows.isNotEmpty) {
        rows.add(Container(height: 1, color: theme.divider.withValues(alpha: 0.5)));
      }
      rows.add(_ActionRow(spec: spec, onTap: () => onAction(spec.action)));
    }

    // Ahead of every action: this is the thing the user long-pressed to read.
    // Seeded into `rows` rather than prepended after, so `add`'s own
    // between-rows divider separates it from REPLY without a special case.
    final name = fileName;
    if (name != null) rows.add(_FileNameHeader(name: name, theme: theme));

    if (canReply) {
      add(const _ActionRowSpec(
        action: MessageAction.reply,
        icon: CupertinoIcons.arrowshape_turn_up_left,
        label: 'REPLY',
        destructive: false,
      ));
    }
    // Right after REPLY: both are "send this somewhere", and forwarding one
    // message is the single-item case of what the selection bar does for many.
    if (canForward) {
      add(const _ActionRowSpec(
        action: MessageAction.forward,
        icon: CupertinoIcons.arrowshape_turn_up_right,
        label: 'FORWARD',
        destructive: false,
      ));
    }
    if (hasParent) {
      add(const _ActionRowSpec(
        action: MessageAction.viewThread,
        icon: CupertinoIcons.arrow_branch,
        label: 'VIEW THREAD',
        destructive: false,
      ));
    }
    if (canCopy) {
      add(const _ActionRowSpec(
        action: MessageAction.copy,
        icon: CupertinoIcons.doc_on_doc,
        label: 'COPY',
        destructive: false,
      ));
    }
    // Takes COPY's slot rather than sitting beside it: `canCopy` is a text
    // message with a body, and a document has neither. Reading the name off the
    // header above is one thing; getting it into a search field is another.
    if (name != null) {
      add(const _ActionRowSpec(
        action: MessageAction.copyName,
        icon: CupertinoIcons.doc_on_doc,
        label: 'COPY NAME',
        destructive: false,
      ));
    }
    // Beside COPY rather than next to the destructive pair: the list runs
    // constructive → neutral → destructive, and a pin is shared room state, not
    // something done TO the message. Unpinning is reversible, so neither is
    // marked destructive — red would overstate it.
    if (canPin) {
      add(_ActionRowSpec(
        action: isPinned ? MessageAction.unpin : MessageAction.pin,
        icon: isPinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
        label: isPinned ? 'UNPIN' : 'PIN',
        destructive: false,
      ));
    }
    // Last of the neutral rows, because it is the only one that does nothing to
    // this message: it hands the transcript over to multi-select with this one
    // already picked, and everything after that happens in the selection bar.
    if (canSelect) {
      add(const _ActionRowSpec(
        action: MessageAction.select,
        icon: CupertinoIcons.checkmark_circle,
        label: 'SELECT',
        destructive: false,
      ));
    }
    if (!isMine) {
      add(const _ActionRowSpec(
        action: MessageAction.viewProfile,
        icon: CupertinoIcons.person_circle,
        label: 'PROFILE',
        destructive: false,
      ));
    }
    if (isMine) {
      add(const _ActionRowSpec(
        action: MessageAction.delete,
        icon: CupertinoIcons.trash,
        label: 'DELETE',
        destructive: true,
      ));
    }
    if (!isMine) {
      add(const _ActionRowSpec(
        action: MessageAction.report,
        icon: CupertinoIcons.flag,
        label: 'REPORT',
        destructive: true,
      ));
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
            : SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: column,
              ),
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

class _ActionRowSpec {
  const _ActionRowSpec({
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

class _ActionRow extends StatefulWidget {
  const _ActionRow({required this.spec, required this.onTap});
  final _ActionRowSpec spec;
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

