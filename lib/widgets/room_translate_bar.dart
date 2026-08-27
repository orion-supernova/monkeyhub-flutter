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
/// working (the progress track). And it carries the way out, because the place
/// to turn a mode off is the thing that tells you the mode is on.
///
/// The chrome is [CompanionStrip], shared with the global download banner. It
/// used to be a private copy of the same control, half a point shorter and two
/// per cent more transparent, and it was the only one of the room's three top
/// strips that snapped into place instead of growing.
library;

import 'package:flutter/material.dart';

import '../companions/companion.dart';
import '../companions/sebastian.dart';
import '../l10n/generated/app_localizations.dart';
import 'companion_strip.dart';

class RoomTranslateBar extends StatelessWidget {
  const RoomTranslateBar({
    super.key,
    required this.roomId,
    required this.onStop,
    this.glass = false,
  });

  final String roomId;
  final VoidCallback onStop;

  /// Frosted and gutter-inset rather than full-bleed, for the compact chat
  /// style — where this floats over the transcript under a rounded glass header
  /// rather than sitting in a column beneath a square one. Same flag, same
  /// meaning and same look as [PinnedMessageBanner.glass], which it stacks
  /// directly under.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: Sebastian.instance,
      builder: (context, _) {
        final sebastian = Sebastian.instance;
        // Switched on for this room AND actually able to run. The second half
        // is not belt-and-braces: the room list is persisted, so it survives an
        // update that retires the brain it was translating with. Without this,
        // a user who upgrades into a new brain opens a room they translated
        // last week and is told Sebastian is translating it, by a strip sitting
        // over a queue that `enqueueRoom` declines to fill because there is no
        // brain on disk. The mode stays on and comes back by itself the moment
        // he is installed again.
        final on = sebastian.isRoomTranslating(roomId) && sebastian.isReady;
        final progress = sebastian.progressFor(roomId);
        final working = on && !progress.isComplete;

        return CompanionStrip(
          // Collapses to nothing rather than unmounting from the caller's side,
          // so the room screen places this unconditionally and the strip
          // animates its own arrival and departure.
          visible: on,
          companion: Companion.sebastian,
          glass: glass,
          // Two sentences for two states, rather than one with a number that
          // sits at "48 of 48" forever. Once it is done the count is noise;
          // what still matters is which language you are reading in.
          message: working
              ? l10n.roomTranslateWorking(progress.done, progress.total)
              : l10n.roomTranslateReading(sebastian.targetLanguage.autonym),
          // The track goes away when the work does. A full bar left sitting
          // under a finished room is a progress indicator reporting nothing.
          progress: working ? progress.fraction : null,
          actionLabel: l10n.roomTranslateStop,
          onAction: onStop,
          semanticLabel: l10n.roomTranslateTitle,
        );
      },
    );
  }
}
