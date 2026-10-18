import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calls/group_call_service.dart';
import '../calls/live_calls_store.dart';
import '../calls/widgets/call_chrome.dart'
    show ElapsedLabel, kCallAcceptGreen;
import '../backend/server_limits.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_preference.dart' show AppThemeBrightness;
import '../theme/theme_scope.dart';
import 'app_toast.dart';
import 'spring_press.dart';

// A call going on in a room, as the chat list shows it in every layout: a
// green halo that breathes around the room's face with a live equalizer
// badge on it, a [LiveCallChip] where the preview was ("Voice call · 3 in
// call · 04:12", shedding parts to fit) and, for a group call you are not
// in, a Join pill.
//
// A call is a live state, so this is the one place in the list allowed an
// idle loop. It runs only while a row with a call is on screen.

/// [child] (a room's face, [size] across) with the live-call halo around it
/// while [call] is set.
class LiveCallHalo extends StatefulWidget {
  const LiveCallHalo({
    super.key,
    required this.call,
    required this.size,
    required this.child,
    this.rim,
  });

  final LiveRoomCall? call;
  final double size;
  final Widget child;

  /// What the face sits on, for the badge's cut-out rim: the page when null,
  /// a card's own surface on a card or tile.
  final Color? rim;

  @override
  State<LiveCallHalo> createState() => _LiveCallHaloState();
}

class _LiveCallHaloState extends State<LiveCallHalo>
    with SingleTickerProviderStateMixin {
  /// The breathing and the badge's bars, one loop for both. Created on the
  /// first call, never for the rows that never have one.
  AnimationController? _loop;

  /// The halo's arrival, so it draws in rather than snapping on.
  double _target = 0;

  AnimationController _ensureLoop() => _loop ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LiveCallHalo old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final live = widget.call != null;
    _target = live ? 1 : 0;
    if (!live) {
      _loop?.stop();
      return;
    }
    final loop = _ensureLoop();
    if (MediaQuery.disableAnimationsOf(context)) {
      loop.stop();
    } else if (!loop.isAnimating) {
      loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _target),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: widget.child,
      builder: (context, on, child) {
        if (on <= 0.001 && call == null) return child!;
        final loop = _ensureLoop();
        return SizedBox.square(
          dimension: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The face shrinks a touch inside the ring, so the ring sits
              // in the room the avatar always had.
              Positioned.fill(
                child: Transform.scale(
                  scale: 1 - 0.14 * on.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _HaloPainter(loop: loop, on: on),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Transform.scale(
                  scale: on.clamp(0.0, 1.2),
                  child: _EqualizerBadge(
                    loop: loop,
                    rim: widget.rim,
                    video: call?.video ?? false,
                    size: math.max(18.0, widget.size * 0.36),
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

/// The ring and its breath: a solid green ring, and a soft second one
/// swelling out of it and fading, like sound leaving the room.
class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.loop, required this.on}) : super(repaint: loop);

  final Animation<double> loop;
  final double on;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final a = on.clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      r - 1.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = kCallAcceptGreen.withValues(alpha: a),
    );
    if (!loop.isAnimating) return;
    final p = Curves.easeOut.transform(loop.value);
    canvas.drawCircle(
      c,
      r - 1.25 + 5 * p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * (1 - p) + 0.5
        ..color = kCallAcceptGreen.withValues(alpha: 0.5 * (1 - p) * a),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.on != on;
}

/// A green disc on the face's corner with three bars bouncing in it, out
/// of step: someone is talking in there.
class _EqualizerBadge extends StatelessWidget {
  const _EqualizerBadge({
    required this.loop,
    required this.video,
    required this.size,
    this.rim,
  });

  final Color? rim;
  final Animation<double> loop;
  final bool video;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = rim ?? ThemeScope.of(context).background;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kCallAcceptGreen,
        shape: BoxShape.circle,
        // A rim of the page, so the badge reads cut out of the face.
        border: Border.all(color: bg, width: 2),
      ),
      child: RepaintBoundary(
        child: CustomPaint(painter: LiveBarsPainter(loop: loop)),
      ),
    );
  }
}

/// Three rounded bars bouncing out of step, in [color]; still and even
/// when [loop] is not running.
class LiveBarsPainter extends CustomPainter {
  LiveBarsPainter({required this.loop, this.color = Colors.white, this.inset})
      : super(repaint: loop);

  final Animation<double> loop;
  final Color color;

  /// Air around the bars; a third of the box when null (the badge).
  final double? inset;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = inset ?? size.shortestSide * 0.28;
    final box = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final w = box.width / 5;
    final paint = Paint()..color = color;
    final v = loop.value;
    final moving = loop.isAnimating;
    for (var i = 0; i < 3; i++) {
      // Each bar on its own rhythm: two sines a little out of tune with
      // each other, so the pattern never visibly repeats.
      final h = moving
          ? 0.35 +
              0.65 *
                  (0.5 +
                      0.25 * math.sin(2 * math.pi * (v * (2 + i) + i * 0.3)) +
                      0.25 * math.sin(2 * math.pi * (v * 3 + i * 0.55)))
          : (i == 1 ? 1.0 : 0.6);
      final bh = box.height * h.clamp(0.2, 1.0);
      final x = box.left + w * (i * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, box.center.dy - bh / 2, w, bh),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(LiveBarsPainter old) => old.color != color;
}

/// Rebuilds [builder] when the call in [roomId] changes, and only then.
///
/// [LiveCallsStore] notifies for every room's call at once; a row listening
/// to it directly rebuilt the whole list each time anyone anywhere joined a
/// call. This compares the one room's answer (a [LiveRoomCall] has value
/// equality) and stays still when it is unchanged.
class RoomLiveCallBuilder extends StatefulWidget {
  const RoomLiveCallBuilder({
    super.key,
    required this.roomId,
    required this.builder,
  });

  final String roomId;
  final Widget Function(BuildContext context, LiveRoomCall? call) builder;

  @override
  State<RoomLiveCallBuilder> createState() => _RoomLiveCallBuilderState();
}

class _RoomLiveCallBuilderState extends State<RoomLiveCallBuilder> {
  LiveRoomCall? _call;

  @override
  void initState() {
    super.initState();
    _call = LiveCallsStore.instance.forRoom(widget.roomId);
    LiveCallsStore.instance.addListener(_sync);
  }

  @override
  void didUpdateWidget(RoomLiveCallBuilder old) {
    super.didUpdateWidget(old);
    if (old.roomId != widget.roomId) {
      _call = LiveCallsStore.instance.forRoom(widget.roomId);
    }
  }

  void _sync() {
    final next = LiveCallsStore.instance.forRoom(widget.roomId);
    if (next != _call && mounted) setState(() => _call = next);
  }

  @override
  void dispose() {
    LiveCallsStore.instance.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _call);
}

/// THE live-call indicator in the chat list, in every layout: a green
/// capsule with a drawn phone (or camera) whose sound waves breathe out one
/// after the other, a short label, how many are in it and how long it has
/// been going.
///
/// It fits by dropping, never by cutting. The parts go in order of what is
/// least worth losing: the head count first, then the label (the glyph
/// already says voice or video), then the clock, so a narrow grid tile in
/// Turkish shows the glyph and "04:12" where a row in English shows
/// everything. A truncated "Devam eden görüntülü ar..." is what this
/// replaced.
class LiveCallChip extends StatelessWidget {
  const LiveCallChip({
    super.key,
    required this.call,
    this.fontSize = 13,
    this.surface,
  });

  final LiveRoomCall call;
  final double fontSize;

  /// What the chip sits on, for its fill and its ink's contrast; the page
  /// background when null.
  final Color? surface;

  /// What fits in [maxWidth], best first.
  @visibleForTesting
  static ({bool label, bool people, bool clock}) fit({
    required double maxWidth,
    required double glyph,
    required double pad,
    required double gap,
    required double label,
    required double people,
    required double clock,
    required double dot,
  }) {
    final base = pad * 2 + glyph;
    double width(bool l, bool p, bool c) =>
        base +
        (l ? gap + label : 0) +
        (p ? (l ? dot : gap) + people : 0) +
        (c ? ((l || p) ? dot : gap) + clock : 0);
    final hasClock = clock > 0;
    final hasPeople = people > 0;
    for (final (l, p, c) in [
      (true, hasPeople, hasClock),
      (true, false, hasClock),
      (false, false, hasClock),
      (true, false, false),
    ]) {
      if (width(l, p, c) <= maxWidth + 0.5) {
        return (label: l, people: p, clock: c);
      }
    }
    return (label: false, people: false, clock: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final under = surface ?? theme.background;
    final fill = Color.alphaBlend(
      kCallAcceptGreen.withValues(alpha: theme.isLight ? 0.13 : 0.18),
      under,
    );
    final ink = liveCallInk(fill);
    final label =
        call.video ? l10n.liveCallChipVideo : l10n.liveCallChipVoice;
    final people = call.groupCallId != null
        ? l10n.groupCallScreenParticipantCount(call.count)
        : null;
    final started = call.startedAt;
    final strong = theme.bodySoft.copyWith(
      fontSize: fontSize,
      height: 1.15,
      fontWeight: FontWeight.w600,
      color: ink,
      letterSpacing: -0.1,
      decoration: TextDecoration.none,
    );
    final soft = strong.copyWith(
      fontWeight: FontWeight.w500,
      color: ink.withValues(alpha: 0.78),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    double measure(String s, TextStyle style) => (TextPainter(
          text: TextSpan(text: s, style: style),
          textDirection: dir,
          textScaler: scaler,
          maxLines: 1,
        )..layout())
            .width;
    final glyph = scaler.scale(fontSize) + 3;
    final pad = fontSize * 0.62;
    final gap = fontSize * 0.38;
    const dotText = '  ·  ';
    final long = started != null &&
        DateTime.now().difference(started) > const Duration(minutes: 55);
    final dot = measure(dotText, soft);
    return Semantics(
      container: true,
      label: [label, ?people].join(', '),
      child: LayoutBuilder(
        builder: (context, box) {
          final show = fit(
            maxWidth: box.maxWidth,
            glyph: glyph,
            pad: pad,
            gap: gap,
            label: measure(label, strong),
            people: people == null ? 0 : measure(people, soft),
            clock: started == null ? 0 : measure(long ? '0:00:00' : '00:00', soft),
            dot: dot,
          );
          final any = show.label || show.people || show.clock;
          return Container(
            height: math.max(glyph + 6, scaler.scale(fontSize) * 1.15 + 8),
            padding: EdgeInsets.symmetric(horizontal: pad),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiveCallGlyph(video: call.video, size: glyph, color: ink),
                if (any) SizedBox(width: gap),
                if (show.label)
                  Flexible(
                    child: Text(
                      label,
                      style: strong,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                if (show.people) ...[
                  if (show.label) Text(dotText, style: soft),
                  Text(people!, style: soft, maxLines: 1, softWrap: false),
                ],
                if (show.clock) ...[
                  if (show.label || show.people) Text(dotText, style: soft),
                  ElapsedLabel(start: started!, style: soft),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The call green, darkened (on a light fill) or lifted (on a dark one) until
/// small bold text on [fill] reads: 4.5:1 where it can, never under 3.
/// `#34C759` on white is 2.2:1, which is why the plain green was not enough.
Color liveCallInk(Color fill) {
  final dark = fill.computeLuminance() > 0.18;
  var ink = kCallAcceptGreen;
  for (var t = 0.0; t <= 1.0; t += 0.08) {
    ink = Color.lerp(
      kCallAcceptGreen,
      dark ? const Color(0xFF0B3D1A) : const Color(0xFFD9F7E1),
      t,
    )!;
    if (_contrast(ink, fill) >= 4.5) return ink;
  }
  return ink;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// A drawn phone (or camera) with two sound waves leaving its corner.
///
/// Live, so it breathes: the waves brighten one after the other on a 1.6 s
/// cosine, the way the autoplay chevrons do, and read as sound going out
/// while nothing moves. Arriving, the handset rocks twice like a phone
/// ringing on a table (the camera pushes its lens forward instead). Reduce
/// Motion gets the still glyph. The ticker stops whenever the glyph is not
/// on screen ([TickerMode]) and only one exists per call on screen.
class LiveCallGlyph extends StatefulWidget {
  const LiveCallGlyph({
    super.key,
    required this.video,
    required this.size,
    required this.color,
  });

  final bool video;
  final double size;
  final Color color;

  @override
  State<LiveCallGlyph> createState() => _LiveCallGlyphState();
}

class _LiveCallGlyphState extends State<LiveCallGlyph>
    with TickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _kick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  bool _calm = false;
  bool _kicked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
    if (_calm) {
      _flow
        ..stop()
        ..value = 0;
      _kick.value = 0;
      return;
    }
    if (!_flow.isAnimating) _flow.repeat();
    if (!_kicked) {
      _kicked = true;
      _kick.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(LiveCallGlyph old) {
    super.didUpdateWidget(old);
    if (old.video != widget.video && !_calm) _kick.forward(from: 0);
  }

  @override
  void dispose() {
    _flow.dispose();
    _kick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _LiveCallGlyphPainter(
            video: widget.video,
            color: widget.color,
            flow: _flow,
            kick: _kick,
          ),
        ),
      );
}

class _LiveCallGlyphPainter extends CustomPainter {
  _LiveCallGlyphPainter({
    required this.video,
    required this.color,
    required this.flow,
    required this.kick,
  }) : super(repaint: Listenable.merge([flow, kick]));

  final bool video;
  final Color color;
  final AnimationController flow;
  final AnimationController kick;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.4, s * 0.105)
      ..color = color;

    // Two rocks that die away, like a phone buzzing on a table.
    final k = kick.value;
    final ring = k == 0 || k == 1
        ? 0.0
        : math.sin(k * math.pi * 4) * (1 - Curves.easeOut.transform(k));

    // The waves: centred on the glyph's top-right corner, brightening in
    // turn from the inner one out.
    final origin = Offset(s * 0.56, s * 0.44);
    for (var i = 0; i < 2; i++) {
      final phase = (flow.value - i * 0.22) % 1.0;
      final breath = flow.isAnimating
          ? 0.5 + 0.5 * math.cos(2 * math.pi * phase)
          : 1.0;
      final r = s * (0.24 + 0.2 * i);
      stroke.color = color.withValues(alpha: color.a * (1 - 0.6 * (1 - breath)));
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: r),
        -math.pi / 2 + 0.28,
        math.pi / 2 - 0.56,
        false,
        stroke,
      );
    }
    stroke.color = color;

    if (video) {
      // A camera body and its lens, lower left; the lens pushes forward on
      // arrival.
      final push = k == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(k));
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.04, s * 0.5, s * 0.4, s * 0.36),
        Radius.circular(s * 0.09),
      );
      canvas.drawRRect(body, stroke);
      final lx = s * 0.47 + push * s * 0.06;
      canvas.drawPath(
        Path()
          ..moveTo(lx, s * 0.64)
          ..lineTo(lx + s * 0.16, s * 0.54)
          ..lineTo(lx + s * 0.16, s * 0.82)
          ..lineTo(lx, s * 0.72),
        stroke,
      );
      return;
    }

    // The handset: one fat arc with round ends, earpiece top left,
    // mouthpiece bottom right, rocking about its middle.
    canvas.save();
    final pivot = Offset(s * 0.36, s * 0.64);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(ring * 0.32);
    canvas.translate(-pivot.dx, -pivot.dy);
    final handset = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.2
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s * 0.62, s * 0.38), radius: s * 0.44),
      math.pi * 0.55,
      math.pi * 0.5,
      false,
      handset,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LiveCallGlyphPainter old) =>
      old.video != video || old.color != color;
}

/// Join a group call you are not in, straight from the list.
class LiveCallJoinPill extends StatefulWidget {
  const LiveCallJoinPill({super.key, required this.call, this.dense = false});

  final LiveRoomCall call;

  /// The smaller pill a grid tile's corner has room for.
  final bool dense;

  /// Shown for this call: a group call, you are not in it, and not already
  /// in another one on this device.
  static bool wants(LiveRoomCall? call) {
    if (call == null || call.groupCallId == null || call.mine) return false;
    final svc = GroupCallService.maybeInstance;
    return svc != null && !svc.inCall;
  }

  @override
  State<LiveCallJoinPill> createState() => _LiveCallJoinPillState();
}

class _LiveCallJoinPillState extends State<LiveCallJoinPill> {
  bool _busy = false;

  Future<void> _join() async {
    final svc = GroupCallService.maybeInstance;
    final id = widget.call.groupCallId;
    if (svc == null || id == null || _busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await svc.joinCall(id);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final msg = e.toString().contains('CALL_FULL')
          ? l10n.groupCallBannerCallFullError
          : friendlyServerError(e, l10n, l10n.groupCallBannerJoinFailedError);
      showAppToast(context, msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: () => unawaited(_join()),
      semanticLabel: l10n.groupCallBannerJoinCallSemanticLabel,
      radius: 14,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_join()),
        child: SpringPress.passive(
          scale: 0.92,
          child: AnimatedOpacity(
            opacity: _busy ? 0.55 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              height: widget.dense ? 24 : 28,
              padding: EdgeInsets.symmetric(horizontal: widget.dense ? 10 : 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kCallAcceptGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                l10n.groupCallBannerJoinButtonLabel,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.dense ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
