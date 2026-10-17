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
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'app_toast.dart';
import 'spring_press.dart';

// A call going on in a room, as the chat list shows it: a green halo that
// breathes around the room's face with a live equalizer badge on it, the
// preview line turned into the call's own line ("Ongoing voice call · 3 in
// call · 04:12") and, for a group call you are not in, a Join pill.
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
  });

  final LiveRoomCall? call;
  final double size;
  final Widget child;

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
  });

  final Animation<double> loop;
  final bool video;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = ThemeScope.of(context).background;
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

/// The preview line while a call is going on in the room.
class LiveCallLine extends StatelessWidget {
  const LiveCallLine({
    super.key,
    required this.call,
    required this.theme,
    required this.fontSize,
  });

  final LiveRoomCall call;
  final AppTheme theme;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = theme.bodySoft.copyWith(
      fontSize: fontSize,
      color: theme.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final title = call.video
        ? l10n.groupCallBannerOngoingVideoCall
        : l10n.groupCallBannerOngoingVoiceCall;
    final started = call.startedAt;
    return Row(
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: style.copyWith(
                    color: kCallAcceptGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (call.groupCallId != null)
                  TextSpan(
                    text:
                        '  ·  ${l10n.groupCallScreenParticipantCount(call.count)}',
                  ),
                if (started != null) const TextSpan(text: '  ·  '),
              ],
            ),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (started != null) ElapsedLabel(start: started, style: style),
      ],
    );
  }
}

/// Join a group call you are not in, straight from the list.
class LiveCallJoinPill extends StatefulWidget {
  const LiveCallJoinPill({super.key, required this.call});

  final LiveRoomCall call;

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
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kCallAcceptGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                l10n.groupCallBannerJoinButtonLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
