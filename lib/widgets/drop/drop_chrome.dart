import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../../drop/drop_classifier.dart';
import '../../drop/drop_controller.dart';
import '../../drop/drop_copy.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import 'drop_cards.dart';
import 'drop_glow.dart' show dropToneColor;

/// How hard the top card is pulled toward the pointer, per second.
///
/// The number that decides whether this feels like a physical object or like a
/// cursor decoration. Too high and the cards are welded to the pointer, which
/// is what a plain `Positioned` does and what makes most drag previews feel
/// cheap; too low and they lag far enough behind a fast traverse to be
/// mistaken for a dropped frame. Each card below the top follows the one above
/// it slightly more slowly — see [_followFor] — which is what makes the stack
/// swing out on a turn and settle back.
const double _kLeadStiffness = 26;

/// Gap between the pointer and the top-left of the card fan. Down and to the
/// right, where macOS and every browser put a native drag image, so the cards
/// land where the hand already expects them.
const Offset _kCardOffset = Offset(16, 18);

/// Chrome painted over the whole app while something is being dragged into it.
///
/// Mounted once, near the top of the tree, and inert on every platform without
/// a desktop drag. Three layers, in the order they matter:
///
///  1. **the aura** — a wash in from the window's edges, which is the one
///     signal that says "this window, as a whole, is receiving something".
///     Without it a drag over a part of the app with no zone in it looks
///     exactly like a drag the app never noticed.
///  2. **the card fan** — what is being carried, as cards that trail the
///     pointer.
///  3. **the verdict chip** — what letting go would do.
///
/// It draws NO per-zone highlight: that belongs to the zone, which knows its
/// own shape, and is painted inside it so the app's own content stays on top
/// of its own decoration. See [DropGlow].
class DropChrome extends StatefulWidget {
  const DropChrome({super.key});

  @override
  State<DropChrome> createState() => _DropChromeState();
}

class _DropChromeState extends State<DropChrome>
    with TickerProviderStateMixin {
  final DropController _drop = DropController.instance;

  late final AnimationController _presence;

  /// Drives the trail. Runs only while a drag is over the window, which is the
  /// only reason a per-frame callback is acceptable here at all.
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  /// One smoothed position per card, plus one for the chip. Index 0 chases the
  /// pointer; every other index chases the one before it.
  late List<Offset> _trail;

  /// Bumped once per tick so the fan repaints without rebuilding the cards'
  /// subtrees.
  final ValueNotifier<int> _frame = ValueNotifier(0);

  bool _calm = false;

  @override
  void initState() {
    super.initState();
    _presence = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _trail = List.filled(kDropMaxCards + 2, Offset.zero);
    _drop.addListener(_onDropChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MotionScope.of(context).calm;
    if (_calm) _stopTicker();
  }

  @override
  void dispose() {
    _drop.removeListener(_onDropChanged);
    _stopTicker();
    _presence.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onDropChanged() {
    if (!mounted) return;
    if (_drop.active) {
      // Seeded, not animated in from wherever the last drag ended: the cards
      // have to appear AT the pointer and grow, not fly in across the window
      // from the corner they were last let go in.
      if (!_presence.isForwardOrCompleted) {
        _trail = List.filled(_trail.length, _drop.pointer.value);
      }
      _presence.forward();
      _startTicker();
    } else {
      _presence.reverse();
      _stopTicker();
    }
    setState(() {});
  }

  void _startTicker() {
    if (_calm || _ticker != null) return;
    _lastTick = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    // Clamped because a dropped frame (or a debugger pause) otherwise hands
    // the spring a dt large enough to overshoot into a visible snap.
    final dt = previous == Duration.zero
        ? 1 / 60
        : math.min(
            (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond,
            1 / 20,
          );
    final target = _drop.pointer.value;
    var lead = target;
    for (var i = 0; i < _trail.length; i++) {
      final k = _followFor(i);
      _trail[i] = Offset.lerp(_trail[i], lead, 1 - math.exp(-dt * k))!;
      lead = _trail[i];
    }
    _frame.value++;
  }

  /// Stiffness for trail index [i]. Monotonically softer, floored so the last
  /// card still arrives rather than drifting for a second after the pointer
  /// stops.
  static double _followFor(int i) =>
      math.max(11.0, _kLeadStiffness - i * 3.4);

  @override
  Widget build(BuildContext context) {
    if (!DropController.isSupported) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    // The `DefaultTextStyle` is not decoration — it is the whole fix for a
    // real bug.
    //
    // This subtree is mounted in `app.dart` as a SIBLING of the root
    // navigator, so it sits outside every Scaffold in the app and inherits no
    // text style at all. Flutter's fallback for that is its debug style: red
    // text under a double YELLOW underline. That is what the drag cards and
    // the verdict chip were painted in. `ConnectionBanner` carries the same
    // wrapper for the same reason and says so in the same words.
    //
    // `TextDecoration.none` explicitly, not merely absent: an inherited
    // decoration is the thing being defended against, and leaving it null
    // would let one back in if anything above this ever set one.
    //
    // No `Material` beside it, unlike the connection banner — nothing here
    // draws ink, and the banner needs one for its own surface rather than for
    // its text. Widget tests missed all of this because a test host puts its
    // subject in a Scaffold, which supplies both; `drop_chrome_test.dart`
    // now mounts this bare, the way the app does.
    return ExcludeSemantics(
      child: IgnorePointer(
        child: DefaultTextStyle(
          style: theme.body.copyWith(
            color: theme.ink,
            decoration: TextDecoration.none,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
                // Layer 1 — the window knows. Cheap, and the only thing on screen
                // when the pointer is somewhere with no zone under it.
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _presence,
                    builder: (context, _) {
                      final t = Curves.easeOut.transform(_presence.value);
                      if (t == 0) return const SizedBox.shrink();
                      return CustomPaint(
                        painter: _AuraPainter(
                          t: t,
                          color: dropToneColor(theme, _drop.plan.tone),
                          targeted: _drop.target != null,
                        ),
                      );
                    },
                  ),
                ),
                // Layers 2 and 3 — only while something is genuinely in the air.
                if (_drop.active || _presence.value > 0)
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_frame, _presence, _drop.pointer]),
                      builder: (context, _) => _fan(context, theme, l10n),
                    ),
                  ),
                // The landing. Outlives the session by design — it is what the
                // session turns INTO.
                RepaintBoundary(
                  child: _DropBurst(controller: _drop, theme: theme),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fan(BuildContext context, AppTheme theme, AppLocalizations l10n) {
    final t = Curves.easeOutBack.transform(_presence.value.clamp(0.0, 1.0));
    if (t <= 0) return const SizedBox.shrink();
    final plan = _drop.plan;
    final target = _drop.target;
    final message = dropMessage(
      l10n,
      plan: plan,
      targetLabel: target?.label,
      hasTarget: target != null,
    );

    final items = plan.items;
    final shown = items.take(kDropMaxCards).toList();
    final overflow = items.length - shown.length;
    final viewport = MediaQuery.sizeOf(context);

    // Widest card in the fan, so the whole stack flips to the left of the
    // pointer together rather than one card at a time as each one's own width
    // crosses the edge.
    var widest = 0.0;
    for (final a in shown) {
      widest = math.max(widest, DropCard.widthFor(a));
    }
    if (shown.isEmpty) widest = DropCard.narrow;
    final fanExtent = widest + (math.max(0, shown.length - 1) * 7);

    final children = <Widget>[];
    // Painted back to front so card 0 ends up on top, which is also the
    // order the fan offsets are built around.
    for (var i = shown.length - 1; i >= 0; i--) {
      final fan = dropCardFan(i, shown.length);
      final anchor = _positionFor(i, viewport, fanExtent);
      children.add(Positioned(
        left: anchor.dx + fan.offset.dx,
        top: anchor.dy + fan.offset.dy,
        child: Transform.rotate(
          angle: _calm ? 0 : fan.angle,
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: t,
            alignment: Alignment.topLeft,
            child: Opacity(
              opacity: _presence.value.clamp(0.0, 1.0),
              child: DropCard(
                assessment: shown[i],
                theme: theme,
                l10n: l10n,
                tone: plan.tone,
                overflowCount: i == shown.length - 1 ? overflow : 0,
              ),
            ),
          ),
        ),
      ));
    }

    final chipAnchor = _positionFor(shown.length, viewport, fanExtent);
    children.add(Positioned(
      left: chipAnchor.dx,
      top: chipAnchor.dy + dropFanHeight(shown.length) + 12,
      child: Opacity(
        opacity: _presence.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: t,
          alignment: Alignment.topLeft,
          child: _VerdictChip(message: message, theme: theme),
        ),
      ),
    ));

    return Stack(fit: StackFit.expand, children: children);
  }

  /// Where trail index [i] sits, clamped inside the window.
  ///
  /// The flip is what stops the fan from hanging off the right edge of a
  /// narrow window — and it flips the WHOLE fan on the widest card, so the
  /// stack never straddles the pointer.
  Offset _positionFor(int i, Size viewport, double fanExtent) {
    final base = _calm
        ? _drop.pointer.value
        : _trail[math.min(i, _trail.length - 1)];
    final flip = base.dx + _kCardOffset.dx + fanExtent > viewport.width - 12;
    final dx = flip
        ? base.dx - _kCardOffset.dx - fanExtent
        : base.dx + _kCardOffset.dx;
    final dy = base.dy + _kCardOffset.dy;
    return Offset(
      dx.clamp(12.0, math.max(12.0, viewport.width - fanExtent - 12)),
      dy.clamp(12.0, math.max(12.0, viewport.height - 150)),
    );
  }
}

/// The pill under the fan: what letting go would do, and the one caveat worth
/// saying while it is still in the air.
class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.message, required this.theme});

  final DropMessage message;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final accent = dropToneColor(theme, message.tone);
    final refuse = message.tone == DropTone.refuse;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 268),
          padding: const EdgeInsets.fromLTRB(11, 8, 13, 8),
          decoration: BoxDecoration(
            color: theme.surfaceRaised.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                switch (message.tone) {
                  DropTone.accept => CupertinoIcons.arrow_down_circle_fill,
                  DropTone.caution => CupertinoIcons.info_circle_fill,
                  DropTone.refuse => CupertinoIcons.xmark_circle_fill,
                },
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyEmph.copyWith(
                        color: refuse ? theme.danger : theme.ink,
                      ),
                    ),
                    if (message.detail != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        message.detail!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.caption.copyWith(color: theme.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The wash in from the window's edges.
///
/// Edges rather than a full scrim, and that is the whole design: a scrim would
/// dim the zone glow underneath it, which is the brightest and most
/// informative thing on screen during a drag. Light from the frame says "this
/// window is live" and leaves the middle alone.
class _AuraPainter extends CustomPainter {
  _AuraPainter({required this.t, required this.color, required this.targeted});

  final double t;
  final Color color;

  /// A drag with a zone under it needs less shouting from the frame — the zone
  /// is already lit. Without one, the frame is the only thing saying anything.
  final bool targeted;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strength = (targeted ? 0.10 : 0.17) * t;
    final reach = math.min(size.shortestSide * 0.36, 180.0);

    void edge(Rect band, Alignment from, Alignment to) {
      if (band.isEmpty) return;
      canvas.drawRect(
        band,
        Paint()
          ..shader = ui.Gradient.linear(
            from.withinRect(band),
            to.withinRect(band),
            [color.withValues(alpha: strength), color.withValues(alpha: 0)],
          ),
      );
    }

    edge(Rect.fromLTWH(0, 0, size.width, reach), Alignment.topCenter,
        Alignment.bottomCenter);
    edge(Rect.fromLTWH(0, size.height - reach, size.width, reach),
        Alignment.bottomCenter, Alignment.topCenter);
    edge(Rect.fromLTWH(0, 0, reach, size.height), Alignment.centerLeft,
        Alignment.centerRight);
    edge(Rect.fromLTWH(size.width - reach, 0, reach, size.height),
        Alignment.centerRight, Alignment.centerLeft);

    // A hairline right at the frame, so the window reads as having a live
    // border rather than merely a bright fog near its edges.
    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.42 * t),
    );
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.t != t || old.color != color || old.targeted != targeted;
}

/// The moment of release.
///
/// A ring that runs out from where the pointer let go and fades, plus a bloom
/// under it. It exists to close the loop the fan opened: without it the cards
/// simply cease to exist and the eye has nothing to follow into the
/// transcript, where an optimistic bubble is already appearing.
///
/// A refused drop gets the same shape in the danger colour and a shorter
/// throw — it dissolves rather than splashing.
class _DropBurst extends StatefulWidget {
  const _DropBurst({required this.controller, required this.theme});

  final DropController controller;
  final AppTheme theme;

  @override
  State<_DropBurst> createState() => _DropBurstState();
}

class _DropBurstState extends State<_DropBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  DropLanding? _playing;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        final played = _playing;
        if (played != null) widget.controller.clearLanding(played.serial);
        if (mounted) setState(() => _playing = null);
      });
    widget.controller.landing.addListener(_onLanding);
  }

  @override
  void dispose() {
    widget.controller.landing.removeListener(_onLanding);
    _burst.dispose();
    super.dispose();
  }

  void _onLanding() {
    final landing = widget.controller.landing.value;
    if (landing == null || !mounted) return;
    // Calm motion gets no burst at all. It is pure decoration — the send is
    // confirmed by the bubble appearing in the transcript, which is the thing
    // that actually happened.
    if (MotionScope.of(context).calm) {
      widget.controller.clearLanding(landing.serial);
      return;
    }
    setState(() => _playing = landing);
    _burst.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final landing = _playing;
    if (landing == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _burst,
      builder: (context, _) => CustomPaint(
        painter: _BurstPainter(
          at: landing.at,
          t: _burst.value,
          color: landing.accepted
              ? dropToneColor(widget.theme, landing.plan.tone)
              : widget.theme.danger,
          accepted: landing.accepted,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.at,
    required this.t,
    required this.color,
    required this.accepted,
  });

  final Offset at;
  final double t;
  final Color color;
  final bool accepted;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(t);
    final fade = (1 - t) * (1 - t);
    final reach = accepted ? 96.0 : 52.0;

    canvas.drawCircle(
      at,
      reach * eased,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - eased * 0.7)
        ..color = color.withValues(alpha: 0.85 * fade),
    );
    canvas.drawCircle(
      at,
      reach * 0.62 * eased,
      Paint()
        ..color = color.withValues(alpha: 0.14 * fade)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 12),
    );
    if (!accepted) return;
    // A second, faster ring a beat behind the first. One ring reads as a
    // ripple; two read as an impact, which is what a file arriving is.
    final inner = Curves.easeOutCubic.transform((t * 1.5).clamp(0.0, 1.0));
    canvas.drawCircle(
      at,
      reach * 0.55 * inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: 0.45 * fade),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.t != t || old.at != at || old.color != color;
}
