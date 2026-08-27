/// The strip that says a room is being translated.
///
/// ── Why the room needs a bar and a bubble doesn't ──────────────────────────
///
/// Translating one message is self-evident: you tapped a thing and the thing
/// changed. Translating a room is a mode, and a mode with no persistent
/// indicator is a mode people forget they are in — then wonder why their own
/// messages have a second paragraph, or why the room reads slightly oddly.
///
/// So the bar exists to answer three questions without being asked: is this on
/// (it is visible at all), into what (the language, named), and is it still
/// working (the hairline). And it carries the way out, because the place to
/// turn a mode off is the thing that tells you the mode is on.
///
/// It is a strip and not a banner. It sits under the header at 34 points and
/// takes no more of the transcript than a date divider does.
library;

import 'package:flutter/material.dart';

import '../companions/companion.dart';
import '../companions/sebastian.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

class RoomTranslateBar extends StatelessWidget {
  const RoomTranslateBar({
    super.key,
    required this.roomId,
    required this.onStop,
  });

  final String roomId;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: Sebastian.instance,
      builder: (context, _) {
        final sebastian = Sebastian.instance;
        // Collapses to nothing rather than unmounting from the caller's side,
        // so the room screen can place this unconditionally and the strip
        // animates its own arrival and departure.
        if (!sebastian.isRoomTranslating(roomId)) {
          return const SizedBox(height: 0, width: double.infinity);
        }

        final progress = sebastian.progressFor(roomId);
        final working = !progress.isComplete;

        return Container(
          height: 34,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.10),
            border: Border(
              bottom: BorderSide(color: theme.accent.withValues(alpha: 0.20)),
            ),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  const SizedBox(width: 14),
                  CompanionMark(
                    companion: Companion.sebastian,
                    size: 15,
                    foreground: theme.accent,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      // Two sentences for two states, rather than one with a
                      // number that sits at "48 of 48" forever. Once it is
                      // done the count is noise; what still matters is which
                      // language you are reading in.
                      working
                          ? l10n.roomTranslateWorking(
                              progress.done,
                              progress.total,
                            )
                          : l10n.roomTranslateReading(
                              sebastian.targetLanguage.autonym,
                            ),
                      style: theme.caption.copyWith(color: theme.accent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: onStop,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      // Generous horizontal padding is the tap target: the
                      // strip is 34 tall, so height cannot supply one, and a
                      // word this small needs the width to be reachable.
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        l10n.roomTranslateStop,
                        style: theme.caption.copyWith(
                          color: theme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // The progress hairline rides the strip's own bottom border
              // rather than being a bar of its own. It is the only moving
              // thing on screen while a room translates, and at one point tall
              // it reads as progress without competing with the transcript.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.fraction),
                  duration: motion.d(const Duration(milliseconds: 260)),
                  curve: motion.c(theme.motionCurve),
                  builder: (context, value, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0),
                      child: Container(height: 1.5, color: theme.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The room-menu row that turns the mode on, and its three unavailable
/// states.
///
/// Its own widget because the answer to "can this room be translated" has four
/// shapes — off, on, needs installing, unsupported — and putting that
/// switch inside the room screen's build would put it inside a method that is
/// already long enough.
class RoomTranslateToggle extends StatelessWidget {
  const RoomTranslateToggle({
    super.key,
    required this.roomId,
    required this.onStart,
    required this.onStop,
    required this.onSetUp,
  });

  final String roomId;
  final VoidCallback onStart;
  final VoidCallback onStop;

  /// Opens the install sheet, or Settings if the problem is that Sebastian is
  /// switched off rather than missing.
  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final sebastian = Sebastian.instance;

    if (!sebastian.isAvailable) {
      return _Row(
        theme: theme,
        icon: Icons.translate,
        label: l10n.roomTranslateTitle,
        detail: l10n.companionUnsupportedPlatform,
        onTap: null,
      );
    }

    final on = sebastian.isRoomTranslating(roomId);
    if (!sebastian.isReady) {
      return _Row(
        theme: theme,
        icon: Icons.translate,
        label: l10n.roomTranslateTitle,
        detail: l10n.roomTranslateNeedsSetUp,
        onTap: onSetUp,
      );
    }

    return _Row(
      theme: theme,
      icon: Icons.translate,
      label: on ? l10n.roomTranslateStopTitle : l10n.roomTranslateTitle,
      detail: on
          ? null
          : sebastian.targetLanguage.autonym,
      onTap: on ? onStop : onStart,
      active: on,
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.theme,
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.active = false,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final ink = enabled
        ? (active ? theme.accent : theme.ink)
        : theme.inkMuted.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 17, color: ink),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.body.copyWith(color: ink))),
            if (detail != null)
              Text(
                detail!,
                style: theme.caption.copyWith(color: theme.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}
