import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;

/// The small action strip that floats beside a bubble while a mouse rests on
/// it (react, reply, more), the way Telegram and WhatsApp desktop do it.
///
/// ### Why it costs the transcript nothing
///
/// The transcript is the hottest tree in the app, and hover is the busiest
/// input there is: the pointer crosses a dozen bubbles on its way anywhere,
/// and a scroll under a resting pointer crosses them for it. So hovering must
/// never rebuild a bubble, and a bubble that is not hovered must carry nothing
/// more than the [MouseRegion] that notices the pointer.
///
/// One [MessageHoverController] serves the whole transcript. A bubble's region
/// reports enter and exit to it and nothing else; the controller waits out a
/// short dwell, measures the ONE hovered bubble, and draws the strip in a
/// single [OverlayEntry] of its own. Showing, moving and hiding the strip
/// rebuilds that entry and nothing in the list.
///
/// The strip is not modal and takes no focus: it is a pointer affordance, and
/// a widget that grabbed focus on hover would pull the caret out of the
/// composer every time the mouse wandered over the conversation. (Which is
/// also why it is NOT wrapped in an `OverlayModalScope`.) Everything on it is
/// reachable from the keyboard another way: the menu key paths and the
/// shortcuts.

/// What one bubble offers the strip. Built per row by the screen, which is
/// where the closures already live; the strip only ever reads the hovered
/// one.
@immutable
class MessageHoverTarget {
  const MessageHoverTarget({
    required this.id,
    required this.isMine,
    this.onReact,
    this.onReply,
    this.onMore,
  });

  /// The row's identity. Two targets with the same id are the same bubble,
  /// so a rebuild of the row while hovered does not restart the dwell.
  final String id;

  /// Which side the strip goes on: beside an incoming bubble's trailing edge,
  /// or an outgoing one's leading edge, so it always sits in the open lane of
  /// the conversation rather than over the bubble.
  final bool isMine;

  /// Given the button's rect in global coordinates, so the popover it opens
  /// can hang off the button that opened it. Null hides that button.
  final void Function(Rect anchor)? onReact;
  final VoidCallback? onReply;
  final void Function(Rect anchor)? onMore;

  bool get isEmpty => onReact == null && onReply == null && onMore == null;
}

/// Hands the transcript's one [MessageHoverController] down to its bubbles.
/// Never notifies: the controller's identity is fixed for the room's life.
class MessageHoverScope extends InheritedWidget {
  const MessageHoverScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final MessageHoverController controller;

  static MessageHoverController? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<MessageHoverScope>()
      ?.controller;

  @override
  bool updateShouldNotify(MessageHoverScope old) =>
      old.controller != controller;
}

/// Wraps a bubble in the one widget it pays for being hoverable. Inert (it
/// returns [child] untouched) with no [MessageHoverScope] above it, which is
/// every phone, every preview and every lifted copy in a menu.
class MessageHoverRegion extends StatelessWidget {
  const MessageHoverRegion({
    super.key,
    required this.target,
    required this.child,
  });

  final MessageHoverTarget? target;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = target;
    if (t == null || t.isEmpty) return child;
    final controller = MessageHoverScope.maybeOf(context);
    if (controller == null) return child;
    return MouseRegion(
      // Never opaque: the text inside sets its own I-beam, links their hand.
      opaque: false,
      onEnter: (_) => controller.enter(t, context),
      onExit: (_) => controller.exit(t.id),
      child: child,
    );
  }
}

class _Shown {
  const _Shown(this.target, this.rect, this.overlaySize);
  final MessageHoverTarget target;

  /// The bubble, in the overlay's coordinates.
  final Rect rect;
  final Size overlaySize;
}

/// The dwell, the measuring and the single overlay entry. See the file doc.
class MessageHoverController {
  MessageHoverController({
    this.dwell = const Duration(milliseconds: 150),
    this.grace = const Duration(milliseconds: 160),
  });

  /// How long the pointer must rest on a bubble before the strip appears.
  /// Short enough to feel immediate when you mean it, long enough that a
  /// pointer sweeping across the transcript does not flash a strip on every
  /// bubble it crosses.
  final Duration dwell;

  /// How long the strip outlives the pointer leaving its bubble, which is the
  /// time it takes to cross the gap from the bubble onto the strip.
  final Duration grace;

  final ValueNotifier<_Shown?> _shown = ValueNotifier(null);
  Timer? _showTimer;
  Timer? _hideTimer;
  String? _pendingId;
  bool _overStrip = false;
  OverlayEntry? _entry;
  OverlayState? _overlay;
  bool _disposed = false;

  /// The id of the bubble the strip is showing for, or null.
  @visibleForTesting
  String? get shownId => _shown.value?.target.id;

  void enter(MessageHoverTarget target, BuildContext context) {
    if (_disposed) return;
    _hideTimer?.cancel();
    final shown = _shown.value;
    if (shown != null && shown.target.id == target.id) return;
    _pendingId = target.id;
    _showTimer?.cancel();
    _showTimer = Timer(dwell, () {
      if (_pendingId != target.id || !context.mounted) return;
      _pendingId = null;
      _show(target, context);
    });
  }

  void exit(String id) {
    if (_pendingId == id) {
      _showTimer?.cancel();
      _pendingId = null;
    }
    if (_shown.value?.target.id == id) _scheduleHide();
  }

  /// Hides at once: a scroll, a menu opening, the room going away.
  void dismiss() {
    _showTimer?.cancel();
    _pendingId = null;
    _hideTimer?.cancel();
    _overStrip = false;
    if (_shown.value != null) _shown.value = null;
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(grace, () {
      if (!_overStrip) _shown.value = null;
    });
  }

  void _stripHover(bool inside) {
    _overStrip = inside;
    if (inside) {
      _hideTimer?.cancel();
    } else {
      _scheduleHide();
    }
  }

  void _show(MessageHoverTarget target, BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final overlayBox = overlay.context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.hasSize) return;
    if (_overlay != overlay) {
      _entry?.remove();
      _entry = null;
      _overlay = overlay;
    }
    final entry = _entry ??= OverlayEntry(
      builder: (_) => ValueListenableBuilder<_Shown?>(
        valueListenable: _shown,
        builder: (context, shown, _) => shown == null
            ? const SizedBox.shrink()
            : _StripPositioned(
                key: ValueKey(shown.target.id),
                shown: shown,
                onHover: _stripHover,
                onUsed: dismiss,
              ),
      ),
    );
    if (!entry.mounted) overlay.insert(entry);
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    _shown.value = _Shown(target, topLeft & box.size, overlayBox.size);
  }

  void dispose() {
    _disposed = true;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    if (_entry?.mounted ?? false) _entry!.remove();
    _entry = null;
    _shown.dispose();
  }
}

/// Places the strip in the open lane beside the bubble, vertically centred on
/// a short bubble and near the bottom of a tall one (where the eye is when it
/// finishes reading), held inside the overlay.
class _StripPositioned extends StatelessWidget {
  const _StripPositioned({
    super.key,
    required this.shown,
    required this.onHover,
    required this.onUsed,
  });

  final _Shown shown;
  final ValueChanged<bool> onHover;
  final VoidCallback onUsed;

  static const double gap = 6;

  @override
  Widget build(BuildContext context) {
    final t = shown.target;
    final r = shown.rect;
    final count = (t.onReact != null ? 1 : 0) +
        (t.onReply != null ? 1 : 0) +
        (t.onMore != null ? 1 : 0);
    final w = MessageHoverStrip.widthFor(count);
    const h = MessageHoverStrip.height;
    var left = t.isMine ? r.left - gap - w : r.right + gap;
    left = left
        .clamp(4.0, (shown.overlaySize.width - w - 4).clamp(4.0, double.infinity))
        .toDouble();
    var top = r.height <= 64 ? r.center.dy - h / 2 : r.bottom - h - 4;
    top = top
        .clamp(0.0, (shown.overlaySize.height - h).clamp(0.0, double.infinity))
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        // Plain Material so the labels never fall back to the debug style.
        child: Material(
          type: MaterialType.transparency,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            // A solid, unblurred chip, so fading it is free: there is no
            // backdrop filter in here for an opacity layer to break.
            builder: (_, v, child) => Opacity(
              opacity: v,
              child: Transform.scale(
                scale: 0.92 + 0.08 * v,
                alignment:
                    t.isMine ? Alignment.centerRight : Alignment.centerLeft,
                child: child,
              ),
            ),
            child: MessageHoverStrip(target: t, onUsed: onUsed),
          ),
        ),
      ),
    );
  }
}

/// The strip's face. Public for the render test.
@visibleForTesting
class MessageHoverStrip extends StatelessWidget {
  const MessageHoverStrip({super.key, required this.target, this.onUsed});

  final MessageHoverTarget target;

  /// Called after any button: the strip gets out of the way of what it opened.
  final VoidCallback? onUsed;

  static const double height = 32;
  static const double button = 28;
  static double widthFor(int buttons) => buttons * button + 4 + 2;

  Rect _rectOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final t = target;
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: theme.ink.withValues(alpha: 0.10),
          width: 1 / MediaQuery.devicePixelRatioOf(context),
        ),
        // Centred, not dropped: an offset shadow reads as a grey lip under
        // the chip on a light theme. Centred, it just lifts it off the page.
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (t.onReact != null)
            Builder(
              builder: (context) => _StripButton(
                icon: CupertinoIcons.smiley,
                label: l10n.msgDeskReactLabel,
                onTap: () {
                  final at = _rectOf(context);
                  onUsed?.call();
                  t.onReact!(at);
                },
              ),
            ),
          if (t.onReply != null)
            _StripButton(
              icon: CupertinoIcons.arrowshape_turn_up_left,
              label: sentenceCaseOf(context, l10n.messageActionMenuReplyLabel),
              onTap: () {
                onUsed?.call();
                t.onReply!();
              },
            ),
          if (t.onMore != null)
            Builder(
              builder: (context) => _StripButton(
                icon: CupertinoIcons.ellipsis,
                label: l10n.msgDeskMoreLabel,
                onTap: () {
                  final at = _rectOf(context);
                  onUsed?.call();
                  t.onMore!(at);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _StripButton extends StatefulWidget {
  const _StripButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_StripButton> createState() => _StripButtonState();
}

class _StripButtonState extends State<_StripButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 600),
      child: FocusableTap(
        onTap: widget.onTap,
        semanticLabel: widget.label,
        shape: FocusRingShape.circle,
        inset: 1,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              width: MessageHoverStrip.button,
              height: MessageHoverStrip.button,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hover ? quietFill(theme) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                size: 16,
                color: _hover ? theme.ink : theme.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
