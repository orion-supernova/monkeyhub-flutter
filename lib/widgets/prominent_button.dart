import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// The one big button on a first-run or sign-in screen: a full-width accent
/// capsule with sentence-case text, the iOS 26 `.glassProminent` shape.
///
/// No glow and no letter-spaced capitals — the old buttons shouted. It springs
/// on press, and while [busy] it trades its label for a spinner without
/// changing size, so nothing under it moves.
class ProminentButton extends StatefulWidget {
  const ProminentButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  State<ProminentButton> createState() => _ProminentButtonState();
}

class _ProminentButtonState extends State<ProminentButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final enabled = widget.onTap != null && !widget.busy;
    final fill = widget.onTap == null
        ? theme.accent.withValues(alpha: 0.4)
        : theme.accent;
    return FocusableTap(
      onTap: enabled ? widget.onTap : null,
      enabled: enabled,
      semanticLabel: widget.label,
      radius: 999,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: motion.d(
            _down
                ? const Duration(milliseconds: 90)
                : const Duration(milliseconds: 420),
          ),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: AnimatedContainer(
            duration: theme.motionFast,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              // A hairline of light along the top edge, the lit rim glass
              // buttons have, rather than a coloured glow underneath.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(fill, Colors.white, 0.10)!,
                  fill,
                ],
              ),
            ),
            child: widget.busy
                ? CupertinoActivityIndicator(color: theme.accentInk)
                : Text(
                    widget.label,
                    style: theme.bodyEmph.copyWith(
                      fontSize: 17,
                      color: theme.accentInk,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
