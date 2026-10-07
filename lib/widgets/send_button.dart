import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
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
class SendButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onSend != null && !busy;
    final fill = theme.bubbleFill(isMine: true);
    final ink = theme.accentInk;
    final glyphSize = size >= 40 ? 20.0 : 19.0;

    Widget disc(double hold) {
      final scheduling = hold >= _morphAt;
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
              child: Center(child: glyph),
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
      onTap: enabled ? onSend : null,
      onHold: onSchedule,
      holdLabel: AppLocalizations.of(context).composerScheduleAction,
      semanticLabel: semanticLabel,
      ringColor: ink,
      builder: (context, hold) => disc(hold),
    );
  }
}
