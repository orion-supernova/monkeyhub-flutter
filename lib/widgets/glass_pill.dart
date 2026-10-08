
import 'package:flutter/cupertino.dart';

import '../theme/theme_scope.dart';
import '../l10n/text_case.dart';
import 'glass_reveal.dart';
import 'liquid_glass.dart';

/// Mounts [child] only while it is visible or animating.
///
/// Every pill that floats over a transcript is a `BackdropFilter`, which costs a
/// backdrop rasterization pass every frame it exists — even at zero opacity. So
/// this does not park a hidden pill in the tree behind an `AnimatedOpacity`:
/// below `isDismissed` it renders nothing at all, which also means nothing to
/// hit-test.
///
/// Shared by every transient pill rather than reimplemented per pill, because
/// the "renders nothing while hidden" contract is the whole point and a copy
/// that forgets it costs a rasterization pass in every chat, forever.
class TransientPillSlot extends StatefulWidget {
  const TransientPillSlot({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  State<TransientPillSlot> createState() => _TransientPillSlotState();
}

class _TransientPillSlotState extends State<TransientPillSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final CurvedAnimation _grow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // Replaced from the theme in didChangeDependencies, before first paint.
      duration: const Duration(milliseconds: 220),
      value: widget.visible ? 1 : 0,
    );
    // Overshoots on the way in; [GlassReveal] lets the scale follow it past 1
    // and clamps the content's fade itself.
    _grow = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    // The only transitions that change what is mounted are into and out of
    // `dismissed`; every other frame is painted by the transitions themselves.
    _ctrl.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl.duration = ThemeScope.of(context).motionFast;
  }

  @override
  void didUpdateWidget(TransientPillSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.removeStatusListener(_onStatus);
    _grow.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctrl.isDismissed) return const SizedBox.shrink();
    return RepaintBoundary(
      // Ignoring on the way out too: the pill is still painted while it
      // shrinks, and a tap landing on something that is visibly leaving is a
      // misfire.
      child: IgnorePointer(
        ignoring: !widget.visible,
        // Grown, not faded: the pill is glass, and a fade would have it blur
        // its layer's empty buffer, a flat wash until the fade ends and the
        // frost snaps in. See [GlassReveal].
        child: AnimatedBuilder(
          animation: _grow,
          builder: (_, child) =>
              GlassReveal(t: _grow.value, from: 0.6, child: child!),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The glass capsule every piece of floating list chrome is made of: a blurred,
/// accent-tinted lozenge holding a small icon and a word or two of mono caps.
///
/// One widget rather than one per pill on purpose — a reader who has learned to
/// read "jump to latest" shouldn't have to learn "back to reply" as a different
/// kind of object, and they only stay identical if they are literally the same
/// code.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;

  /// Rendered as-is. Callers pass mono caps to match the rest of the chrome.
  final String label;

  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return LiquidGlass(
      shape: LiquidGlassShape.capsule,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.accent),
          const SizedBox(width: 6),
          Text(
            sentenceCaseOf(context, label),
            style: theme.bodySoft.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.accent,
            ),
          ),
        ],
      ),
    );
  }
}
