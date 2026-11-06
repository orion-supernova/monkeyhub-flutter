import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../data/vanish_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../privacy/vanish_rules.dart';
import 'progress_ring.dart';

/// The mark a vanishing message wears beside its time.
///
///  * counted (everyone it was sent to has seen it): a small [ProgressRing]
///    that drains until the burn, then the row dissolves on its own;
///  * not counted: a quiet clock and "24h", never a Seen tick, with the time
///    left in its semantics.
///
/// Each mark listens to the controller by itself, so a state change repaints
/// the marks and nothing else: the transcript is never rebuilt for a ring.
class VanishStampMark extends StatelessWidget {
  const VanishStampMark({
    super.key,
    required this.message,
    required this.isMine,
    required this.color,
    required this.style,
    this.controller,
  });

  final ChatMessage message;
  final bool isMine;

  /// The mark's ink (the stamp's own, so it reads on whatever it sits on).
  final Color color;

  /// The stamp's text style, for "24h".
  final TextStyle style;

  /// Null outside a room: the clock, with no ring to ever show.
  final VanishController? controller;

  /// The ring's edge, so the twin of a stamp can be reasoned about.
  static const double ringSize = 11;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) return _clock(context, c);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final kind = vanishStampKind(
          message: message,
          isMine: isMine,
          state: c.state,
        );
        if (kind == VanishStampKind.ring) {
          return _RingMark(state: c.state!, color: color, clock: c.clock);
        }
        return _clock(context, c);
      },
    );
  }

  Widget _clock(BuildContext context, VanishController? c) {
    final l10n = AppLocalizations.of(context);
    final until = message.vanishUntil;
    final now = c?.clock() ?? DateTime.now();
    final left = until == null ? Duration.zero : until.difference(now);
    final label = vanishTimeLeftLabel(l10n, left);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.clock, size: 10, color: color),
            const SizedBox(width: 2),
            Text(l10n.vanishClockLabel, style: style.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

/// "Vanishes in 5 hours" / "Vanishes in 12 minutes".
String vanishTimeLeftLabel(AppLocalizations l10n, Duration left) {
  if (left.inMinutes >= 60) return l10n.vanishLeftHours(left.inHours);
  return l10n.vanishLeftMinutes(left.inMinutes < 1 ? 1 : left.inMinutes);
}

/// The draining ring. Linear: the arc shrinks at the rate the timer runs, from
/// what is left of [VanishState.afterSeen] when this ring first learns of the
/// burn (a ring that mounts mid-drain starts mid-drain).
class _RingMark extends StatefulWidget {
  const _RingMark({required this.state, required this.color, required this.clock});

  final VanishState state;
  final Color color;
  final DateTime Function() clock;

  @override
  State<_RingMark> createState() => _RingMarkState();
}

class _RingMarkState extends State<_RingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drain;

  @override
  void initState() {
    super.initState();
    _drain = AnimationController(vsync: this, value: 1);
    _sync();
  }

  @override
  void didUpdateWidget(_RingMark old) {
    super.didUpdateWidget(old);
    if (old.state.burnAt != widget.state.burnAt ||
        old.state.afterSeen != widget.state.afterSeen) {
      _sync();
    }
  }

  void _sync() {
    final s = widget.state;
    final from = vanishRingRemaining(s, widget.clock());
    _drain.duration = Duration(seconds: s.afterSeen <= 0 ? 1 : s.afterSeen);
    if (from <= 0) {
      _drain.value = 0;
    } else {
      _drain.reverse(from: from);
    }
  }

  @override
  void dispose() {
    _drain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.vanishRingSemantics,
      child: ExcludeSemantics(
        child: SizedBox(
          width: VanishStampMark.ringSize,
          height: VanishStampMark.ringSize,
          child: ProgressRing.animated(
            animation: _drain,
            color: widget.color,
            trackColor: widget.color.withValues(alpha: 0.22),
            strokeWidth: 1.6,
            inset: 1,
          ),
        ),
      ),
    );
  }
}
