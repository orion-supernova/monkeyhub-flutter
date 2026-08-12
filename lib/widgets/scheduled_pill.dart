import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/scheduled_message.dart';
import 'glass_pill.dart';

/// Height of the slot the pill occupies, including the gap under it.
///
/// A constant for the same reason `kPinnedBannerHeight` is one: the liquid chat
/// style floats its composer over the transcript with `Positioned(bottom: 0)`
/// and reserves the space by adding a NUMBER to the message list's bottom
/// padding. Nothing measures the pill, so a pill whose real height drifts from
/// this constant sits on top of the newest message — silently, and only in that
/// one style.
///
/// 27pt of [GlassPill] (7 + 13 + 7) plus 13pt of gap beneath it.
const double kScheduledPillHeight = 40;

/// Says that this chat is holding messages of yours that have not gone out yet,
/// and opens the list on tap.
///
/// Lives above the composer, in the slot the reply and edit cards use, and is
/// the PERSISTENT half of how the feature announces itself. The send button's
/// clock badge is the other half and cannot do this job alone: that button only
/// exists while the composer has text in it (see `chat_composer.dart`), so with
/// an empty composer — which is the state a room is in when you walk back into
/// it — there is nothing on screen to carry a badge.
///
/// Built on [GlassPill] rather than beside it, so it is the same object as
/// "jump to latest" and "back to reply" rather than a third thing that looks
/// nearly like them.
class ScheduledPill extends StatelessWidget {
  const ScheduledPill({
    super.key,
    required this.scheduled,
    required this.onTap,
  });

  /// This room's queued messages, soonest first — `ChatRepository.scheduledFor`
  /// hands them over in that order.
  final List<ScheduledMessage> scheduled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pending = [for (final s in scheduled) if (s.pending) s];
    final failed = scheduled.any((s) => s.hasFailed);

    // Counts only what is actually going to be sent. A failed row is something
    // to deal with, not something in flight, and counting it would make the
    // pill promise a delivery that is not coming — the failure gets its own
    // word on the right instead.
    final count = pending.length;
    final label = l10n.scheduledPillLabel(count);

    // The trailing half: normally the next send time, but a failure outranks it.
    // Somebody whose message could not go out needs to know that before they
    // need to know when the next one is due.
    final String text;
    if (failed && count == 0) {
      // Nothing left in flight, only the wreckage. "0 SCHEDULED · NEEDS YOU"
      // is a count of nothing followed by a demand; the demand alone is the
      // whole message.
      text = l10n.scheduledPillAttention;
    } else if (failed) {
      text = l10n.scheduledPillJoin(label, l10n.scheduledPillAttention);
    } else if (pending.isNotEmpty) {
      text = l10n.scheduledPillJoin(
        label,
        MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(pending.first.sendAt),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        ),
      );
    } else {
      text = label;
    }

    return SizedBox(
      height: kScheduledPillHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: GlassPill(
          icon: Icons.schedule,
          label: text,
          semanticLabel: l10n.scheduledPillSemantics(count),
          onTap: onTap,
        ),
      ),
    );
  }
}
