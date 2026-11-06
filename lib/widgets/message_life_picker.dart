import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'detent_ruler.dart';
import 'segmented_control.dart';

/// When a secret room's message starts its countdown.
///
///  * [seen] - "After seen": the clock starts when the message is read.
///    Whatever is not read is still gone within 24 hours.
///  * [sent] - "After sent": the clock starts the moment it is sent, read or
///    not.
enum MessageClock { seen, sent }

/// A secret room's message life: which clock, and for how long.
typedef MessageLife = ({MessageClock clock, Duration lifetime});

/// Where a new secret room starts: 30 seconds from the moment of sending,
/// which is what the create sheet and the DM request draft both defaulted to.
const MessageLife kDefaultMessageLife = (
  clock: MessageClock.sent,
  lifetime: Duration(seconds: 30),
);

/// The lifetimes offered for [clock], shortest first. "After seen" is a
/// shorter menu (10s, 1m, 1h) because a message that waits to be read does not
/// need a fine-grained timer; "after sent" has five.
List<Duration> messageLifeOptions(MessageClock clock) => switch (clock) {
      MessageClock.seen => const [
          Duration(seconds: 10),
          Duration(minutes: 1),
          Duration(hours: 1),
        ],
      MessageClock.sent => const [
          Duration(seconds: 10),
          Duration(seconds: 30),
          Duration(minutes: 1),
          Duration(minutes: 5),
          Duration(hours: 1),
        ],
    };

/// [life] with its lifetime made valid for its clock: kept when the clock
/// offers it, otherwise the nearest lifetime it does (the shorter on a tie,
/// the safer side for something meant to disappear).
MessageLife normalizeMessageLife(MessageLife life) {
  final options = messageLifeOptions(life.clock);
  if (options.contains(life.lifetime)) return life;
  var best = options.first;
  for (final o in options) {
    if ((o - life.lifetime).abs() < (best - life.lifetime).abs()) best = o;
  }
  return (clock: life.clock, lifetime: best);
}

/// THE message timer picker for secret rooms: a segmented "After seen / After
/// sent" switch, a [DetentRuler] over that clock's lifetimes, and one line
/// saying what the choice means.
///
/// Three surfaces used to carry their own chip rows (the create sheet, the
/// room info screen, the DM request draft). They all render this instead, so
/// the options, the labels and the haptics are the same everywhere.
///
/// Controlled: [value] is the truth and [onChanged] reports every change,
/// always with a lifetime that is valid for its clock. Switching clocks keeps
/// the lifetime when the new clock offers it and otherwise moves to the
/// nearest one it does ([normalizeMessageLife]), so there is never a half-set
/// value to guard against.
///
/// Pass a single entry in [clocks] where the clock cannot be changed (the
/// switch is then left out and only the ruler shows).
class MessageLifePicker extends StatelessWidget {
  const MessageLifePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.clocks = MessageClock.values,
  }) : assert(clocks.length > 0);

  final MessageLife value;
  final ValueChanged<MessageLife> onChanged;

  /// The clocks the user may choose between.
  final List<MessageClock> clocks;

  static String _short(AppLocalizations l10n, Duration d) {
    if (d.inSeconds < 60) return l10n.createRoomSheetTtlSeconds(d.inSeconds);
    if (d.inMinutes < 60) return l10n.createRoomSheetTtlMinutes(d.inMinutes);
    return l10n.createRoomSheetTtlHours(d.inHours);
  }

  static String _spoken(AppLocalizations l10n, Duration d) {
    if (d.inSeconds < 60) return l10n.roomScreenTtlSeconds(d.inSeconds);
    if (d.inMinutes < 60) return l10n.roomScreenTtlMinutes(d.inMinutes);
    return l10n.roomScreenTtlHours(d.inHours);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final calm = MotionScope.of(context).calm;
    final life = normalizeMessageLife(value);
    final options = messageLifeOptions(life.clock);
    final index = options.indexOf(life.lifetime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (clocks.length > 1) ...[
          IosSegmentedControl<MessageClock>(
            segments: [
              for (final c in clocks)
                IosSegment(
                  value: c,
                  label: switch (c) {
                    MessageClock.seen => l10n.messageLifeAfterSeen,
                    MessageClock.sent => l10n.messageLifeAfterSent,
                  },
                ),
            ],
            value: life.clock,
            onChanged: (clock) =>
                onChanged(normalizeMessageLife((clock: clock, lifetime: life.lifetime))),
          ),
          const SizedBox(height: 12),
        ],
        DetentRuler(
          labels: [for (final d in options) _short(l10n, d)],
          semanticValues: [for (final d in options) _spoken(l10n, d)],
          semanticLabel: l10n.messageLifeRulerLabel,
          index: index,
          onChanged: (i) => onChanged((clock: life.clock, lifetime: options[i])),
        ),
        const SizedBox(height: 8),
        // The caption names what the choice means; it slides in when the clock
        // changes, and just swaps when the app is calm.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedSwitcher(
            duration: calm ? Duration.zero : theme.motionFast,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Text(
              switch (life.clock) {
                MessageClock.seen => l10n.messageLifeCaptionSeen,
                MessageClock.sent => l10n.messageLifeCaptionSent,
              },
              key: ValueKey(life.clock),
              style: theme.caption.copyWith(color: theme.inkMuted),
            ),
          ),
        ),
      ],
    );
  }
}
