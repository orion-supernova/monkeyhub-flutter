import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../theme/theme_scope.dart';
import 'glass_surface.dart';

/// Actions surfaced by [showMessageActionMenu] (reactions are handled
/// separately via [MessageActionResult.emoji] / `.fullPicker`).
enum MessageAction { reply, viewThread, copy, delete, report, viewProfile }

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

  final completer = Completer<MessageActionResult?>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _MessageActionMenuOverlay(
      bubbleRect: bubbleRect,
      bubbleBuilder: bubbleBuilder,
      isMine: isMine,
      canCopy: canCopy,
      canReply: canReply,
      hasParent: hasParent,
      screenSize: screenSize,
      safeInsets: safeInsets,
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
    required this.bubbleBuilder,
    required this.isMine,
    required this.canCopy,
    required this.canReply,
    required this.hasParent,
    required this.screenSize,
    required this.safeInsets,
    required this.onResolve,
  });

  final Rect bubbleRect;
  final WidgetBuilder bubbleBuilder;
  final bool isMine;
  final bool canCopy;
  final bool canReply;
  final bool hasParent;
  final Size screenSize;
  final EdgeInsets safeInsets;
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
    if (widget.hasParent) n++; // view thread
    if (widget.canCopy) n++;
    if (!widget.isMine) n++; // view profile
    if (widget.isMine) n++; // delete
    if (!widget.isMine) n++; // report
    return n;
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
    final bottomSafe = widget.safeInsets.bottom + 12;

    final menuH = (_actionCount() * rowH) + 12;

    final spaceAbove = bubble.top - topSafe;
    final spaceBelow = widget.screenSize.height - bubble.bottom - bottomSafe;

    // Pill prefers above; menu prefers below. Flip when there is no room
    // and the opposite side has more space.
    var pillAbove = spaceAbove >= pillH + gap;
    var menuBelow = spaceBelow >= menuH + gap;
    if (!pillAbove && !menuBelow) {
      // Pathological — pick whichever side has more room and live with
      // the overflow; bubble is huge or screen is tiny.
      pillAbove = spaceAbove >= spaceBelow;
      menuBelow = !pillAbove;
    } else if (!pillAbove && menuBelow) {
      // Pill goes below, between the bubble and the menu.
    } else if (pillAbove && !menuBelow) {
      // Menu goes above, between the pill and the bubble.
    }

    final pillTop = pillAbove ? bubble.top - gap - pillH : bubble.bottom + gap;
    final menuTop = menuBelow
        ? (pillAbove ? bubble.bottom + gap : bubble.bottom + gap + pillH + gap)
        : (pillAbove ? bubble.top - gap - pillH - gap - menuH : bubble.top - gap - menuH);

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
            child: widget.bubbleBuilder(context),
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
    required this.onAction,
  });
  final bool isMine;
  final bool canCopy;
  final bool canReply;
  final bool hasParent;
  final ValueChanged<MessageAction> onAction;

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

    if (canReply) {
      add(const _ActionRowSpec(
        action: MessageAction.reply,
        icon: CupertinoIcons.arrowshape_turn_up_left,
        label: 'REPLY',
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      child: GlassSurface(
        radius: theme.radiusLg + 6,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
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

