import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/services.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// One button revealed under a swiped row.
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// iOS-style swipe actions on a chat row: drag right for [leading], left for
/// [trailing], tap a revealed button, or swipe all the way to fire the
/// outermost one — the Mail and Telegram gesture.
///
/// The buttons are iOS 26's: rounded capsules with a gap between them that
/// grow out of the edge as the row slides, rather than flat full-height slabs.
/// Crossing the full-swipe threshold lands a haptic and stretches the outer
/// button across the gap, so the commit is felt and seen before the finger
/// lifts.
///
/// Only one row is open at a time: opening this one closes whichever was open,
/// and a tap anywhere on an open row closes it instead of opening the chat.
class ChatRowSwipe extends StatefulWidget {
  const ChatRowSwipe({
    super.key,
    required this.child,
    this.leading = const [],
    this.trailing = const [],
  });

  final Widget child;
  final List<SwipeAction> leading;
  final List<SwipeAction> trailing;

  @override
  State<ChatRowSwipe> createState() => _ChatRowSwipeState();
}

/// The row currently swiped open, so opening another can close it.
final ValueNotifier<Object?> _openRow = ValueNotifier(null);

class _ChatRowSwipeState extends State<ChatRowSwipe>
    with SingleTickerProviderStateMixin {
  static const double _buttonWidth = 74;
  static const double _gap = 6;
  static const double _edge = 8;

  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  )..addListener(() => setState(() => _dx = _settle.value));

  /// Horizontal offset of the row: positive reveals [leading].
  double _dx = 0;
  double _width = 1;
  bool _armed = false;

  double _revealFor(List<SwipeAction> a) =>
      a.isEmpty ? 0 : _edge + a.length * (_buttonWidth + _gap);

  double get _leadingReveal => _revealFor(widget.leading);
  double get _trailingReveal => _revealFor(widget.trailing);

  /// How far past its buttons a row has to travel to fire the outer one.
  double get _fullSwipe => _width * 0.62;

  @override
  void initState() {
    super.initState();
    _openRow.addListener(_onOtherOpened);
  }

  @override
  void dispose() {
    _openRow.removeListener(_onOtherOpened);
    if (_openRow.value == this) _openRow.value = null;
    _settle.dispose();
    super.dispose();
  }

  void _onOtherOpened() {
    if (_openRow.value != this && _dx != 0) _animateTo(0);
  }

  void _animateTo(double target, {double velocity = 0}) {
    final motion = MotionScope.of(context);
    if (motion.calm) {
      _settle.stop();
      setState(() => _dx = target);
      return;
    }
    _settle.value = _dx;
    // Critically damped on the way home, a touch of bounce on the way open —
    // the row seats against its buttons rather than stopping dead.
    final spring = SpringDescription(
      mass: 1,
      stiffness: 520,
      damping: target == 0 ? 46 : 32,
    );
    // A spring settles within a tolerance of its target, never on it; land
    // exactly, or a "closed" row stays a fraction open and keeps eating taps.
    // Completion only (a TickerFuture's own future never resolves on cancel):
    // a finger catching the row mid-spring must not make it jump.
    _settle
        .animateWith(SpringSimulation(spring, _dx, target, velocity))
        .then((_) {
      if (mounted) setState(() => _dx = target);
    });
  }

  void _onStart(DragStartDetails _) {
    _settle.stop();
    _openRow.value = this;
  }

  void _onUpdate(DragUpdateDetails d) {
    var next = _dx + d.delta.dx;
    if (next > 0 && widget.leading.isEmpty) next = 0;
    if (next < 0 && widget.trailing.isEmpty) next = 0;
    // Rubber-band past the full-swipe point instead of a hard stop.
    final limit = _width * 0.9;
    if (next.abs() > limit) {
      next = next.sign * (limit + (next.abs() - limit) * 0.2);
    }
    final armed = next.abs() >= _fullSwipe;
    if (armed != _armed) {
      HapticFeedback.mediumImpact();
      _armed = armed;
    }
    setState(() => _dx = next);
  }

  void _onEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond.dx;
    if (_armed) {
      final actions = _dx > 0 ? widget.leading : widget.trailing;
      _armed = false;
      _fire(_dx > 0 ? actions.first : actions.last);
      return;
    }
    final opening = _dx > 0 ? _leadingReveal : -_trailingReveal;
    final pastHalf = _dx.abs() > opening.abs() * 0.5;
    final flungOpen = v.sign == _dx.sign && v.abs() > 400;
    final flungShut = v.sign != _dx.sign && v.abs() > 400;
    if ((pastHalf || flungOpen) && !flungShut) {
      _animateTo(opening, velocity: v);
    } else {
      _animateTo(0, velocity: v);
    }
  }

  void _fire(SwipeAction a) {
    _animateTo(0);
    a.onTap();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.leading.isEmpty && widget.trailing.isEmpty) return widget.child;
    return LayoutBuilder(
      builder: (context, box) {
        _width = box.maxWidth;
        final open = _dx != 0;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onStart,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          child: Stack(
            children: [
              if (_dx > 0)
                Positioned.fill(
                  child: _ActionStrip(
                    actions: widget.leading,
                    reveal: _dx,
                    leading: true,
                    armed: _armed,
                    onTap: _fire,
                  ),
                ),
              if (_dx < 0)
                Positioned.fill(
                  child: _ActionStrip(
                    actions: widget.trailing,
                    reveal: -_dx,
                    leading: false,
                    armed: _armed,
                    onTap: _fire,
                  ),
                ),
              Transform.translate(
                offset: Offset(_dx, 0),
                // An open row eats the tap that would open the chat and
                // closes instead — the iOS table behaviour.
                child: AbsorbPointer(
                  absorbing: open,
                  child: widget.child,
                ),
              ),
              if (open)
                Positioned(
                  left: _dx > 0 ? _dx : 0,
                  right: _dx < 0 ? -_dx : 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _animateTo(0),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The buttons behind a row, laid out from the edge the row slid away from.
class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.actions,
    required this.reveal,
    required this.leading,
    required this.armed,
    required this.onTap,
  });

  final List<SwipeAction> actions;
  final double reveal;
  final bool leading;
  final bool armed;
  final ValueChanged<SwipeAction> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    const gap = _ChatRowSwipeState._gap;
    const edge = _ChatRowSwipeState._edge;
    final n = actions.length;
    // Space the revealed width gives each button. Buttons grow with the swipe
    // instead of sliding in at full size, so a short drag shows small round
    // icons that swell into labelled capsules.
    final usable = math.max(0.0, reveal - edge - gap * n);
    final each = usable / n;
    // The edge-most action is the one a full swipe fires; armed, it takes the
    // whole strip.
    final outer = leading ? 0 : n - 1;

    final buttons = <Widget>[];
    for (var i = 0; i < n; i++) {
      final a = actions[i];
      final w = armed ? (i == outer ? usable + gap * (n - 1) : 0.0) : each;
      buttons.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: w,
          margin: EdgeInsets.only(left: w > 0 ? gap : 0),
          child: w < 1
              ? const SizedBox.shrink()
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(a),
                  child: Container(
                    decoration: BoxDecoration(
                      color: a.color,
                      borderRadius: BorderRadius.circular(
                        math.min(18, w / 2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: ClipRect(
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        child: Opacity(
                          opacity: ((w - 28) / 30).clamp(0.0, 1.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(a.icon, size: 20, color: Colors.white),
                              if (w > 56) ...[
                                const SizedBox(height: 3),
                                Text(
                                  a.label,
                                  maxLines: 1,
                                  style: theme.caption.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            leading ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!leading) const SizedBox(width: edge),
          ...buttons,
          const SizedBox(width: gap),
          if (leading) const SizedBox(width: edge - gap),
        ],
      ),
    );
  }
}
