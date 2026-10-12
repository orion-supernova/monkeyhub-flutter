import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'hold_ring_button.dart';
import 'liquid_glass.dart';
import 'photo_chrome.dart' show PhotoSpinner;

/// THE send button: the chat composer's and the photo composer's, one widget.
///
/// Two lines of work met here. The chat composer's disc had the gesture — a
/// tap sends, a hold sweeps a ring round it while it gathers in, and lets go
/// into the schedule sheet. The photo composer's had the material — the lit
/// glass edge every other control over a photo wears — and a busy state. Both
/// now have both:
///
///  * **The disc** is solid, in the outgoing bubble's colour: send is the one
///    control that commits something, and it wears the colour of what it is
///    about to create. A specular rim and a soft halo lift it the way the
///    glass around it is lifted, so it belongs to the iOS 26 chrome instead of
///    sitting flat on top of it.
///  * **The hold** is [HoldRingButton]'s, shrink and ring and building
///    vibration included — and as the ring passes halfway the arrow turns
///    into a clock, so the button says what letting go will do before it does.
///  * **Busy** swaps the arrow for the shared [PhotoSpinner]; **disabled** dims
///    the disc and takes the gestures away.
///
/// [badge] rides on the corner — the chat composer's count of queued messages.
///
/// A tap **launches** the arrow: it shoots up out of the disc and a fresh one
/// springs back in from below, the iMessage "it went" beat. The composer
/// usually swaps the button out a moment later (the field is empty again), so
/// the launch is quick enough to read inside that exit; where the button stays
/// (the photo composer going busy) the return completes it. Calm motion skips
/// it.
class SendButton extends StatefulWidget {
  const SendButton({
    super.key,
    required this.onSend,
    required this.semanticLabel,
    this.onSchedule,
    this.size = 40,
    this.busy = false,
    this.badge,
  });

  /// Null draws the button disabled.
  final VoidCallback? onSend;

  /// Null drops the hold entirely — no ring, no rotor action.
  final VoidCallback? onSchedule;

  final String semanticLabel;
  final double size;
  final bool busy;
  final Widget? badge;

  /// Where along the hold the arrow hands over to the clock. Just before halfway, with a
  /// quick fade: the whole hold is under half a second, and a later or slower
  /// hand-over is finished by the time the sheet opens — the clock would never
  /// actually be seen.
  static const _morphAt = 0.45;

  @override
  State<SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<SendButton>
    with SingleTickerProviderStateMixin {
  /// 0 → 1 over one launch; idle (and free) at 0 the rest of the time.
  late final AnimationController _launch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  /// Where the outgoing arrow hands over to the incoming one.
  static const _handOver = 0.32;

  @override
  void dispose() {
    _launch.dispose();
    super.dispose();
  }

  void _send() {
    final onSend = widget.onSend;
    if (onSend == null) return;
    if (!MotionScope.of(context).calm) _launch.forward(from: 0);
    onSend();
  }

  /// The arrow's flight: up and out on an ease-in, then back in from below on
  /// an overshooting spring.
  Widget _flight(Widget glyph, double travel) {
    return AnimatedBuilder(
      animation: _launch,
      child: glyph,
      builder: (context, child) {
        final t = _launch.value;
        if (t == 0 || t == 1) return child!;
        final double dy;
        final double opacity;
        if (t < _handOver) {
          final p = Curves.easeIn.transform(t / _handOver);
          dy = -travel * p;
          opacity = 1 - p;
        } else {
          final p = (t - _handOver) / (1 - _handOver);
          dy = travel * 0.6 * (1 - Curves.easeOutBack.transform(p));
          opacity = Curves.easeOut.transform(p.clamp(0.0, 1.0));
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSend = widget.onSend;
    final onSchedule = widget.onSchedule;
    final semanticLabel = widget.semanticLabel;
    final size = widget.size;
    final busy = widget.busy;
    final badge = widget.badge;
    const morphAt = SendButton._morphAt;
    final theme = ThemeScope.of(context);
    final enabled = onSend != null && !busy;
    final fill = theme.bubbleFill(isMine: true);
    final ink = theme.accentInk;
    final glyphSize = size >= 40 ? 20.0 : 19.0;

    Widget disc(double hold) {
      final scheduling = hold >= morphAt;
      final Widget glyph = busy
          ? PhotoSpinner(size: size * 0.45, color: ink)
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 70),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Icon(
                scheduling ? CupertinoIcons.clock : CupertinoIcons.arrow_up,
                key: ValueKey(scheduling),
                size: glyphSize,
                color: ink,
              ),
            );
      final Widget flying = busy ? glyph : _flight(glyph, size * 0.55);
      Widget body = AnimatedOpacity(
        opacity: enabled || busy ? 1 : 0.4,
        duration: const Duration(milliseconds: 160),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            // A halo, not a drop: centred so it lifts the disc off a bright
            // photo or a pale page without the Material lip under it.
            boxShadow: [
              BoxShadow(
                color: fill.withValues(alpha: 0.35),
                blurRadius: 12,
              ),
            ],
          ),
          child: CustomPaint(
            foregroundPainter: SpecularRim(
              shape: const CircleBorder(),
              light: theme.isLight,
              opacity: 0.8,
            ),
            child: SizedBox.square(
              dimension: size,
              // Clipped to the disc, so the arrow leaves through its rim
              // rather than flying over the composer.
              child: ClipOval(child: Center(child: flying)),
            ),
          ),
        ),
      );
      final b = badge;
      if (b != null) {
        body = Stack(
          clipBehavior: Clip.none,
          children: [
            body,
            Positioned(right: -1, bottom: -1, child: b),
          ],
        );
      }
      return body;
    }

    return HoldRingButton(
      onTap: enabled ? _send : null,
      onHold: onSchedule,
      holdLabel: AppLocalizations.of(context).composerScheduleAction,
      semanticLabel: semanticLabel,
      ringColor: ink,
      builder: (context, hold) => disc(hold),
    );
  }
}
