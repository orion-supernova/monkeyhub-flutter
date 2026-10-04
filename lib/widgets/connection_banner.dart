import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../backend/connection_health.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show groupedMetaStyle;

/// Thin top-of-screen strip reflecting [ConnectionHealth]. Lives in the
/// safe-area inset so it never collides with the status bar or notch.
///
/// Purely a view: every probe, timer and retry decision belongs to
/// [ConnectionHealth]. This widget previously ran its own parallel watchdog and
/// kept its own idea of `connected`, which meant it could hide itself on a
/// successful probe without the app ever learning the socket had come back —
/// leaving a healthy-looking UI over dead subscriptions.
///
/// Collapses to zero height when online: it shares a [Column] with
/// [ActiveCallPill], so reserving space here would push the pill off-position.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.health});

  final ConnectionHealth health;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: health,
      builder: (context, _) {
        final phase = health.phase;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: phase == ConnectionPhase.online
              // Zero-height AND non-hit-testable. The old version stayed
              // hit-testable across the top of every screen while hidden.
              ? const SizedBox(width: double.infinity, height: 0)
              : Material(
                  color: Colors.transparent,
                  // This subtree sits above the root navigator, outside any
                  // Scaffold, so it inherits no text style. Without an explicit
                  // one Flutter paints its debug yellow underlines.
                  child: DefaultTextStyle(
                    style: theme.body,
                    child: SafeArea(
                      bottom: false,
                      child: _Strip(theme: theme, health: health, phase: phase),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.theme,
    required this.health,
    required this.phase,
  });

  final AppTheme theme;
  final ConnectionHealth health;
  final ConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stalled = phase == ConnectionPhase.stalled;
    // A floating status capsule, iOS-style — not the bordered card with a
    // hard ledge shadow it used to be. Solid rather than glass on purpose: it
    // arrives inside an AnimatedSize, and a BackdropFilter must never animate.
    // The danger state is a tint of the fill, not a red outline.
    final body = Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
      decoration: BoxDecoration(
        color: stalled
            ? Color.alphaBlend(
                theme.danger.withValues(alpha: 0.12),
                theme.surfaceRaised,
              )
            : theme.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        // A float shadow, kept close on light themes: a deep offset there
        // reads as a hard ledge under the capsule rather than lift.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isLight ? 0.08 : 0.28),
            blurRadius: theme.isLight ? 12 : 18,
            offset: Offset(0, theme.isLight ? 2 : 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // While a retry is in flight the leading slot always spins, so a tap
          // visibly does something even in the stalled state.
          if (stalled && !health.isRetrying)
            _Dot(color: theme.danger)
          else
            SizedBox(
              width: 12,
              height: 12,
              child: CupertinoActivityIndicator(
                radius: 6,
                color: stalled ? theme.danger : theme.accent,
              ),
            ),
          const SizedBox(width: 8),
          // Flexible + two lines: in Turkish the stalled copy is wider than
          // the screen, and an unflexed Text in a min-size Row overflowed it.
          // Meta on the body face, never the theme's mono — this is a
          // sentence, and on character themes mono is a typewriter.
          Flexible(
            child: Text(
              stalled
                  ? (health.isRetrying
                        ? l10n.attachmentMenuConnectionRetrying
                        : l10n.attachmentMenuConnectionCantReachServer)
                  : l10n.attachmentMenuConnectionReconnecting,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              // Start, not centre: when it wraps, a centred ragged block
              // floats away from the dot it belongs to. On one line the
              // capsule still hugs the text, so nothing changes there.
              textAlign: TextAlign.start,
              style: groupedMetaStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
                color: stalled ? theme.danger : theme.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );

    if (!stalled) return body;

    // Bare GestureDetector, never InkWell: this app's tappables register no ink
    // and no ripple (see FocusableTap's doc comment). FocusableTap adds the
    // keyboard binding and semantics that a raw detector lacks.
    return FocusableTap(
      onTap: health.retryNow,
      radius: 20,
      semanticLabel: l10n.attachmentMenuConnectionRetrySemanticLabel,
      // BOTH handlers are required, and this is not belt-and-braces.
      // FocusableTap registers NO gesture recognizer — it binds onTap to
      // Enter/Space only — so without the detector's own onTap the banner is
      // dead to touch, mouse and VoiceOver, and reachable solely by tabbing to
      // it with a hardware keyboard. See the header of
      // test/call_controls_tap_test.dart: this exact mistake has shipped once
      // already. connection_banner_tap_test.dart pins it here.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: health.retryNow,
        child: body,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
