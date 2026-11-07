import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../data/presence_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../models/chat_match.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
import 'match_face.dart';

/// Going live from a turn by turn duel.
///
/// Three pieces, all cheap (one controller each, painters repaint from it, no
/// blur anywhere):
///
///  * [GoLiveEntry] — the offer. Only there while the other player's presence
///    says online (it leases that one id from the shared [PresenceStore], so
///    it costs no subscription of its own).
///  * [LiveRequestCard] — the question, for both sides. A spark travels from
///    the asker's face to the asked one's and lands as a ring; a bar under it
///    runs down to the moment the request lapses.
///  * [LiveIgnite] — the moment both said yes: a shockwave, a burst of sparks
///    and the word LIVE, over the board, once.
///
/// Calm motion keeps every one of them still: the spark rests mid-link, the
/// ignite is a word that fades in and out.

/// The offer to play this turn by turn game live, under the board.
class GoLiveEntry extends StatefulWidget {
  const GoLiveEntry({
    super.key,
    required this.match,
    required this.viewerId,
    required this.busy,
    required this.onTap,
  });

  final ChatMatch match;
  final String viewerId;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<GoLiveEntry> createState() => _GoLiveEntryState();
}

class _GoLiveEntryState extends State<GoLiveEntry> {
  PresenceLease? _lease;
  String? _partner;

  MatchSeat? get _other {
    for (final s in widget.match.seats) {
      if (s.userId != widget.viewerId) return s;
    }
    return null;
  }

  void _hold() {
    final id = _other?.userId;
    if (id == _partner) return;
    _lease?.release();
    _partner = id;
    _lease = id == null ? null : PresenceStore.instance.lease([id]);
  }

  @override
  void initState() {
    super.initState();
    _hold();
  }

  @override
  void didUpdateWidget(GoLiveEntry old) {
    super.didUpdateWidget(old);
    _hold();
  }

  @override
  void dispose() {
    _lease?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _partner;
    final other = _other;
    if (id == null || other == null) return const SizedBox.shrink();
    final motion = MotionScope.of(context);
    return ValueListenableBuilder<PresenceInfo?>(
      valueListenable: PresenceStore.instance.of(id),
      builder: (context, info, _) {
        final online = info?.isOnline ?? false;
        return AnimatedSize(
          duration: motion.d(const Duration(milliseconds: 240)),
          curve: ThemeScope.of(context).motionCurve,
          alignment: Alignment.topCenter,
          child: online
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _EntryBody(
                    name: other.name,
                    busy: widget.busy,
                    onTap: widget.onTap,
                  ),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }
}

class _EntryBody extends StatelessWidget {
  const _EntryBody({
    required this.name,
    required this.busy,
    required this.onTap,
  });

  final String name;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final label = sentenceCaseOf(context, l10n.chatGameLivePlay);
    return SpringPress(
      onTap: busy ? null : onTap,
      semanticLabel: label,
      focusRadius: theme.radiusLg,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        decoration: BoxDecoration(
          color: theme.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(
            color: theme.success.withValues(alpha: 0.28),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _LiveDot(color: theme.success),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.bodyEmph.copyWith(
                      color: theme.ink,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sentenceCaseOf(context, l10n.chatGameLiveOnline(name)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySoft.copyWith(
                      color: theme.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.success,
                shape: BoxShape.circle,
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.bolt_fill,
                      size: 17,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A green dot with a ring that breathes out of it. Still under calm motion.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = !MotionScope.of(context).calm;
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _DotPainter(_c, widget.color),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.t, this.color) : super(repaint: t);

  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = t.value;
    if (p > 0) {
      final e = Curves.easeOut.transform(p);
      canvas.drawCircle(
        c,
        5 + 6 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.5 * (1 - e)),
      );
    }
    canvas.drawCircle(c, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DotPainter old) => old.color != color;
}

/// The question: [asker] asks [asked] to play live. [mine] says which of the
/// two the viewer is; the asked one gets the buttons, the asker a Cancel.
///
/// The bar underneath runs for [remaining], the time the request has left
/// (the screen decides when it lapses; the bar only shows it coming).
class LiveRequestCard extends StatefulWidget {
  const LiveRequestCard({
    super.key,
    required this.roomId,
    required this.asker,
    required this.asked,
    required this.viewerIsAsker,
    required this.remaining,
    required this.busy,
    required this.onCancel,
    this.onAccept,
  });

  final String roomId;
  final MatchSeat asker;
  final MatchSeat asked;
  final bool viewerIsAsker;
  final Duration remaining;
  final bool busy;

  /// Asker: Cancel. Asked: Decline.
  final VoidCallback onCancel;

  /// Asked only: Play live.
  final VoidCallback? onAccept;

  @override
  State<LiveRequestCard> createState() => _LiveRequestCardState();
}

class _LiveRequestCardState extends State<LiveRequestCard>
    with TickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1800);

  late final AnimationController _spark = AnimationController(
    vsync: this,
    duration: _cycle,
  );
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: kLiveRequestTtl,
  );

  @override
  void initState() {
    super.initState();
    final left =
        widget.remaining.inMilliseconds / kLiveRequestTtl.inMilliseconds;
    _bar.value = left.clamp(0.0, 1.0);
    _bar.reverse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = !MotionScope.of(context).calm;
    if (run && !_spark.isAnimating) {
      _spark.repeat();
    } else if (!run && _spark.isAnimating) {
      _spark
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _spark.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final calm = MotionScope.of(context).calm;
    final title = widget.viewerIsAsker
        ? l10n.chatGameLiveAsking(widget.asked.name)
        : l10n.chatGameLiveWants(widget.asker.name);
    final sub = widget.viewerIsAsker
        ? l10n.chatGameLiveAskingSub
        : l10n.chatGameLiveWantsSub;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.28),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      _Face(
                        roomId: widget.roomId,
                        seat: widget.asker,
                      ),
                      Expanded(
                        child: CustomPaint(
                          painter: _LinkPainter(
                            _spark,
                            theme.accent,
                            calm,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      _Face(
                        roomId: widget.roomId,
                        seat: widget.asked,
                        ping: _spark,
                        pingColor: theme.accent,
                        calm: calm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sentenceCaseOf(context, title),
                  textAlign: TextAlign.center,
                  style: groupedTitleStyle(theme),
                ),
                const SizedBox(height: 4),
                Text(
                  sentenceCaseOf(context, sub),
                  textAlign: TextAlign.center,
                  style: groupedMetaStyle(theme).copyWith(
                    color: theme.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RowPillButton(
                      label: widget.viewerIsAsker
                          ? l10n.chatGameCancel
                          : l10n.chatGameDecline,
                      onTap: widget.busy ? null : widget.onCancel,
                    ),
                    if (widget.onAccept != null) ...[
                      const SizedBox(width: 8),
                      RowPillButton(
                        label: l10n.chatGameLivePlay,
                        onTap: widget.busy ? null : widget.onAccept,
                        filled: true,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Time left: the bar only shows it, the screen decides.
          AnimatedBuilder(
            animation: _bar,
            builder: (context, _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: _bar.value,
                child: Container(
                  height: 3,
                  color: theme.accent.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A seat's face in a 56pt square, with room for a ring to ping out of it.
class _Face extends StatelessWidget {
  const _Face({
    required this.roomId,
    required this.seat,
    this.ping,
    this.pingColor,
    this.calm = false,
  });

  final String roomId;
  final MatchSeat seat;
  final Animation<double>? ping;
  final Color? pingColor;
  final bool calm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ping != null && !calm)
            Positioned.fill(
              child: CustomPaint(painter: _PingPainter(ping!, pingColor!)),
            ),
          MatchFace(
            roomId: roomId,
            userId: seat.userId,
            name: seat.name,
            size: 40,
          ),
        ],
      ),
    );
  }
}

/// The cycle: the spark leaves the asker, arrives at 80%, and the ring fires.
const _arrive = 0.8;

class _LinkPainter extends CustomPainter {
  _LinkPainter(this.t, this.color, this.calm) : super(repaint: t);

  final Animation<double> t;
  final Color color;
  final bool calm;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const inset = 4.0;
    final w = size.width - inset * 2;
    if (w <= 0) return;
    final p = t.value;

    // The line: dashes that march toward the asked one.
    final dash = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.30);
    const seg = 4.0;
    const gap = 6.0;
    final shift = calm ? 0.0 : (p * (seg + gap) * 2) % (seg + gap);
    for (var x = inset - (seg + gap) + shift; x < inset + w; x += seg + gap) {
      final a = math.max(x, inset);
      final b = math.min(x + seg, inset + w);
      if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), dash);
    }

    // The spark, with a short tail.
    final run = calm ? 0.5 : Curves.easeInOutCubic.transform(
      (p / _arrive).clamp(0.0, 1.0),
    );
    for (var i = 3; i >= 0; i--) {
      final lag = i * 0.045;
      final e = (run - lag).clamp(0.0, 1.0);
      if (!calm && p >= _arrive && i > 0) continue;
      final x = inset + w * e;
      final fade = 1 - i * 0.28;
      if (i == 0) {
        canvas.drawCircle(
          Offset(x, y),
          9,
          Paint()..color = color.withValues(alpha: 0.16),
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        i == 0 ? 4.5 : 3.5 - i * 0.5,
        Paint()..color = color.withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.color != color || old.calm != calm;
}

class _PingPainter extends CustomPainter {
  _PingPainter(this.t, this.color) : super(repaint: t);

  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = t.value;
    if (p < _arrive) return;
    final k = Curves.easeOut.transform((p - _arrive) / (1 - _arrive));
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      20 + 8 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - k) + 0.5
        ..color = color.withValues(alpha: 0.7 * (1 - k)),
    );
  }

  @override
  bool shouldRepaint(_PingPainter old) => old.color != color;
}

/// The moment a turn by turn game becomes live: a shockwave from the middle
/// of the board, a burst of sparks, the word LIVE popping in and out. Plays
/// once and calls [onDone]. Never takes a touch.
class LiveIgnite extends StatefulWidget {
  const LiveIgnite({super.key, required this.label, required this.onDone});

  final String label;
  final VoidCallback onDone;

  @override
  State<LiveIgnite> createState() => _LiveIgniteState();
}

class _LiveIgniteState extends State<LiveIgnite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final calm = MotionScope.of(context).calm;
    if (calm) _c.duration = const Duration(milliseconds: 700);
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final calm = MotionScope.of(context).calm;
    final text = sentenceCaseOf(context, widget.label).toUpperCase();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!calm)
            CustomPaint(
              painter: _IgnitePainter(_c, theme.success, theme.accent),
            ),
          Center(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final t = _c.value;
                // In fast, held, out.
                final inn = Curves.easeOutBack.transform(
                  (t / 0.22).clamp(0.0, 1.0),
                );
                final out = ((t - 0.72) / 0.28).clamp(0.0, 1.0);
                final scale = calm ? 1.0 : 0.55 + 0.45 * inn;
                final opacity = calm
                    ? math.sin(t * math.pi).clamp(0.0, 1.0)
                    : (inn.clamp(0.0, 1.0) * (1 - out));
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.success,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: theme.success.withValues(alpha: 0.45),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.bolt_fill,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IgnitePainter extends CustomPainter {
  _IgnitePainter(this.t, this.a, this.b) : super(repaint: t);

  final Animation<double> t;
  final Color a;
  final Color b;

  static const _rays = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final p = t.value;
    final c = size.center(Offset.zero);
    final reach = size.shortestSide * 0.62;

    // The shockwave: a ring that leaves the middle and thins as it goes.
    final w = Curves.easeOutCubic.transform((p / 0.7).clamp(0.0, 1.0));
    if (w < 1) {
      canvas.drawCircle(
        c,
        reach * w,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14 * (1 - w) + 1
          ..color = a.withValues(alpha: 0.55 * (1 - w)),
      );
    }

    // The flash: a soft disc that is gone in a few frames.
    final f = (p / 0.18).clamp(0.0, 1.0);
    if (f < 1) {
      canvas.drawCircle(
        c,
        reach * 0.5 * Curves.easeOut.transform(f),
        Paint()..color = a.withValues(alpha: 0.28 * (1 - f)),
      );
    }

    // The sparks: short strokes thrown outward, alternating colours, lengths
    // and delays varied so it reads as a burst and not as a clock face.
    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var i = 0; i < _rays; i++) {
      final delay = (i % 3) * 0.04;
      final e = ((p - 0.04 - delay) / 0.6).clamp(0.0, 1.0);
      if (e <= 0 || e >= 1) continue;
      final ease = Curves.easeOutCubic.transform(e);
      final ang = (i / _rays) * 2 * math.pi + (i.isEven ? 0.0 : 0.12);
      final long = 0.55 + 0.45 * ((i * 7) % 5) / 4;
      final r1 = reach * (0.18 + 0.62 * ease) * long;
      final r2 = r1 + reach * 0.16 * (1 - e) * long;
      final d = Offset(math.cos(ang), math.sin(ang));
      canvas.drawLine(
        c + d * r1,
        c + d * r2,
        line..color = (i.isEven ? a : b).withValues(alpha: 1 - e),
      );
    }
  }

  @override
  bool shouldRepaint(_IgnitePainter old) => old.a != a || old.b != b;
}
