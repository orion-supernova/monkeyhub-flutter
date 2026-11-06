import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

import '../calls/live_calls_store.dart';
import '../keyboard/focusable_tap.dart' show HoverEffect;
import '../l10n/generated/app_localizations.dart';
import '../models/call_history.dart';
import '../models/chat_message.dart';
import '../push/device_identity.dart';
import '../screens/calls/calls_format.dart' show platformName;
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'count_badge.dart';
import 'message_stamp.dart';
import 'spring_press.dart';

// ──────────────────────────── words ────────────────────────────

String _kind(CallEvent e) => e.isVideo ? 'video' : 'audio';

/// The bubble's first line for [phase]: "Video call", "Missed voice call",
/// "Calling…". Shared with the chat list's preview line so the two never
/// disagree.
String callTitle(AppLocalizations l, CallEvent e, CallPhase phase) {
  final t = _kind(e);
  return switch (phase) {
    CallPhase.calling => l.callBubbleCalling,
    CallPhase.incomingRinging => l.callBubbleIncomingCall(t),
    CallPhase.live ||
    CallPhase.outgoingEnded ||
    CallPhase.incomingEnded =>
      l.callBubbleCall(t),
    CallPhase.noAnswer => l.callBubbleNoAnswer,
    CallPhase.missed => l.callBubbleMissed(t),
    CallPhase.cancelled => l.callBubbleCancelled(t),
    CallPhase.declined => l.callBubbleDeclined(t),
  };
}

/// One line for a surface that shows the call without drawing it (the chat
/// list): "Outgoing video call · 12:41", "Missed voice call". [mine] is "the
/// viewer started it".
String callPreviewLine(AppLocalizations l, CallEvent e, {required bool mine}) {
  final phase = e.phaseFor(isMine: mine);
  final t = _kind(e);
  final title = switch (phase) {
    CallPhase.outgoingEnded => l.callBubbleOutgoingCall(t),
    CallPhase.incomingEnded => l.callBubbleIncomingCall(t),
    _ => callTitle(l, e, phase),
  };
  final d = e.duration;
  final talked = phase == CallPhase.outgoingEnded ||
      phase == CallPhase.incomingEnded;
  if (talked && d != null && d.inSeconds > 0) {
    return l.callBubblePreviewDuration(title, CallEvent.formatClock(d));
  }
  return title;
}

/// What the preview should say for raw `call:` [content], or null when it is
/// not one. A call this build cannot read still gets a neutral word, never the
/// raw code.
String? callPreviewForContent(
  AppLocalizations l,
  String content, {
  required bool mine,
}) {
  if (!CallEvent.isCallContent(content)) return null;
  final e = CallEvent.parse(content);
  if (e == null) return l.callBubbleCall('audio');
  return callPreviewLine(l, e, mine: mine);
}

// ──────────────────────────── bubble ────────────────────────────

typedef CallDecorator = Decoration Function(bool firstInRun, bool lastInRun);

/// A call, as a bubble.
///
/// Sender-sided like any message and drawn in the bubble chrome the person
/// picked ([decorate] is the theme's own decoration). While the call is live it
/// breathes: a soft waveform and a timer ticking up from `a`. When the same
/// message flips to its final state the bubble settles IN PLACE: the timer
/// freezes, the glyph kicks once on a jelly spring, the waveform flattens. A
/// missed call wobbles once, the first time it is drawn this session.
///
/// [run] is a collapsed row of missed calls from one caller (oldest first,
/// [message] last). It draws as one bubble with a ×N badge; the badge springs
/// the run open into its own bubbles.
///
/// Liveness for the group Join pill comes from [LiveCallsStore] (already
/// subscribed app-wide), never from a subscription of its own.
class CallBubble extends StatefulWidget {
  const CallBubble({
    super.key,
    required this.message,
    required this.event,
    required this.isMine,
    required this.theme,
    required this.decorate,
    this.stampOf,
    this.run = const [],
    this.onTap,
    this.ownPlatform,
  });

  final ChatMessage message;
  final CallEvent event;
  final bool isMine;
  final AppTheme theme;
  final CallDecorator decorate;

  /// The timestamp for one message of the bubble; null draws none.
  final MessageStamp? Function(ChatMessage m)? stampOf;
  final List<ChatMessage> run;

  /// Call back (direct) or join (group, while live). Null where calling is
  /// off for the room: the bubble is then a plain record.
  final void Function(CallEvent event)? onTap;

  /// The viewer's platform tag, for "Answered on Mac". Tests set it.
  final String? ownPlatform;

  /// Runs the viewer has opened this session, by the run's last message id.
  @visibleForTesting
  static final Set<String> openedRuns = <String>{};

  /// The clock the live timer reads. Tests move it; the fake clock of
  /// `pump` does not move `DateTime.now`.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// Missed calls that already wobbled this session, so scrolling back to one
  /// does not play it again.
  @visibleForTesting
  static final Set<String> wobbled = <String>{};

  @override
  State<CallBubble> createState() => _CallBubbleState();
}

class _CallBubbleState extends State<CallBubble> with TickerProviderStateMixin {
  // The only idle loop: runs while the call is live and the ticker is enabled.
  // TickerMode stops it when the route is covered; the transcript's own
  // viewport disposes rows that scroll far away.
  AnimationController? _loop;
  late final AnimationController _kick = AnimationController(
    vsync: this,
    lowerBound: -1,
    upperBound: 2,
    value: 1,
  );
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final ValueNotifier<int> _secs = ValueNotifier<int>(0);

  bool _wasLive = false;
  bool _playingSettle = false;
  bool _playingWobble = false;

  CallEvent get _e => widget.event;
  CallPhase get _phase => _e.phaseFor(isMine: widget.isMine);

  @override
  void initState() {
    super.initState();
    _wasLive = _e.isLive;
    _secs.value = _elapsed().inSeconds;
    _fx.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {
          _playingSettle = false;
          _playingWobble = false;
        });
      }
    });
    if (_isMissedForViewer && !_e.isLive) _maybeWobble();
  }

  bool get _isMissedForViewer => _phase == CallPhase.missed;

  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MotionScope.of(context).calm;
    _syncLoop();
  }

  void _maybeWobble() {
    if (CallBubble.wobbled.length > 400) CallBubble.wobbled.clear();
    if (!CallBubble.wobbled.add(widget.message.id)) return;
    // Started after the first frame so the first build is the settled bubble.
    _playingWobble = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MotionScope.of(context).calm) {
        if (mounted) setState(() => _playingWobble = false);
        return;
      }
      _fx.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(CallBubble old) {
    super.didUpdateWidget(old);
    final nowLive = _e.isLive;
    if (_wasLive && !nowLive) {
      // Same message, live to ended: settle in place.
      _secs.value = _elapsed().inSeconds;
      if (!_calm) {
        _playingSettle = true;
        _playingWobble = _isMissedForViewer;
        if (_playingWobble) CallBubble.wobbled.add(widget.message.id);
        _kick.value = 0;
        _kick.animateWith(SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 240, damping: 9),
          0,
          1,
          0,
        ));
        _fx.forward(from: 0);
      }
    }
    _wasLive = nowLive;
    _syncLoop();
  }

  Duration _elapsed() {
    final a = _e.answeredAt;
    if (a == null) return Duration.zero;
    final d = CallBubble.clock().difference(a);
    return d.isNegative ? Duration.zero : d;
  }

  void _syncLoop() {
    final run = _e.isLive && TickerMode.valuesOf(context).enabled;
    if (!run) {
      _loop?.stop();
      return;
    }
    final loop = _loop ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addListener(_tick);
    if (!loop.isAnimating) loop.repeat();
  }

  // Rebuilds only the timer text, and only when the second changes.
  void _tick() {
    final s = _elapsed().inSeconds;
    if (s != _secs.value) _secs.value = s;
  }

  @override
  void dispose() {
    _loop?.dispose();
    _kick.dispose();
    _fx.dispose();
    _secs.dispose();
    super.dispose();
  }

  void _toggleRun() {
    setState(() {
      final id = widget.message.id;
      if (!CallBubble.openedRuns.remove(id)) CallBubble.openedRuns.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final run = widget.run;
    final isRun = run.length > 1;
    final open = isRun && CallBubble.openedRuns.contains(widget.message.id);

    if (open) {
      return _opened(context, l);
    }
    final body = _body(context, l, badge: isRun ? run.length : null);
    return AnimatedSize(
      duration: _calm ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      alignment:
          widget.isMine ? Alignment.bottomRight : Alignment.bottomLeft,
      child: body,
    );
  }

  Widget _opened(BuildContext context, AppLocalizations l) {
    final run = widget.run;
    final events = [for (final m in run) CallEvent.parse(m.content)];
    final t = widget.theme;
    final cross =
        widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return AnimatedSize(
      duration: _calm ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      alignment: widget.isMine ? Alignment.bottomRight : Alignment.bottomLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [
          for (var i = 0; i < run.length; i++)
            if (events[i] != null)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: _calm ? 1 : 0, end: 1),
                  duration: Duration(milliseconds: 360 + 70 * i),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) => Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.86 + 0.14 * v,
                      alignment: widget.isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: child,
                    ),
                  ),
                  child: _CallBody(
                    key: ValueKey('call-open-${run[i].id}'),
                    theme: t,
                    event: events[i]!,
                    isMine: widget.isMine,
                    decoration: widget.decorate(i == 0, i == run.length - 1),
                    stamp: widget.stampOf?.call(run[i]),
                    ownPlatform: widget.ownPlatform,
                    roomId: run[i].roomId,
                    onTap: widget.onTap,
                  ),
                ),
              ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SpringPress(
              onTap: _toggleRun,
              scale: PressSpec.scaleSmall,
              hover: HoverEffect.none,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  l.callBubbleShowLess,
                  style: t.caption.copyWith(
                    color: t.inkMuted,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l, {int? badge}) {
    final t = widget.theme;
    final phase = _phase;
    final colors = _CallColors.of(t, widget.isMine, phase);
    final showWave = _e.isLive || _playingSettle;
    final glyph = AnimatedBuilder(
      animation: Listenable.merge([_kick, _fx]),
      builder: (context, _) {
        final fx = _fx.value;
        final settling = _playingSettle || _playingWobble;
        final scale = _playingSettle ? 1 + 0.3 * (1 - _kick.value) : 1.0;
        final wobble = _playingWobble && settling
            ? math.sin(fx * math.pi * 5) * 0.32 * math.pow(1 - fx, 2)
            : 0.0;
        final tip = phase == CallPhase.declined
            ? (_playingSettle
                ? Curves.easeOutBack.transform((fx / 0.6).clamp(0.0, 1.0))
                : 1.0)
            : 0.0;
        return _GlyphDisc(
          video: _e.isVideo,
          colors: colors,
          scale: scale,
          rotation: wobble,
          tip: tip,
        );
      },
    );
    final wave = showWave
        ? RepaintBoundary(
            child: SizedBox(
              width: 22,
              height: 12,
              child: CustomPaint(
                painter: _WavePainter(
                  loop: _loop,
                  fx: _fx,
                  settling: !_e.isLive,
                  color: colors.detail,
                ),
              ),
            ),
          )
        : null;
    return _CallBody(
      theme: t,
      event: _e,
      isMine: widget.isMine,
      decoration: widget.decorate(true, true),
      stamp: widget.stampOf?.call(widget.message),
      ownPlatform: widget.ownPlatform,
      roomId: widget.message.roomId,
      onTap: widget.onTap,
      glyph: glyph,
      wave: wave,
      secs: _e.isLive ? _secs : null,
      runCount: badge,
      onBadge: badge == null ? null : _toggleRun,
      frozenElapsed: _e.isLive ? null : _e.duration,
    );
  }
}

// ──────────────────────────── colours ────────────────────────────

class _CallColors {
  const _CallColors({
    required this.title,
    required this.detail,
    required this.glyph,
    required this.disc,
    required this.chipFill,
  });

  final Color title;
  final Color detail;
  final Color glyph;
  final Color disc;
  final Color chipFill;

  static _CallColors of(AppTheme t, bool mine, CallPhase phase) {
    // Red only for a call someone made to you and you never got: on your own
    // accent bubble red would be unreadable, and "no answer" is not an alarm.
    final alarm = !mine && phase == CallPhase.missed;
    if (mine) {
      return _CallColors(
        title: t.accentInk,
        detail: t.accentInk.withValues(alpha: 0.74),
        glyph: t.accentInk,
        disc: t.accentInk.withValues(alpha: 0.2),
        chipFill: t.accentInk.withValues(alpha: 0.18),
      );
    }
    return _CallColors(
      title: alarm ? t.danger : t.ink,
      detail: t.inkMuted,
      glyph: alarm ? t.danger : t.ink,
      disc: alarm ? t.danger.withValues(alpha: 0.13) : t.ink.withValues(alpha: 0.07),
      chipFill: t.ink.withValues(alpha: 0.07),
    );
  }
}

// ──────────────────────────── body ────────────────────────────

/// The static layout of one call bubble. The animated pieces (glyph, waveform,
/// timer) are handed in by [_CallBubbleState]; an opened-run member passes
/// none and is simply a finished bubble.
class _CallBody extends StatelessWidget {
  const _CallBody({
    super.key,
    required this.theme,
    required this.event,
    required this.isMine,
    required this.decoration,
    required this.stamp,
    required this.roomId,
    required this.onTap,
    this.ownPlatform,
    this.glyph,
    this.wave,
    this.secs,
    this.runCount,
    this.onBadge,
    this.frozenElapsed,
  });

  final AppTheme theme;
  final CallEvent event;
  final bool isMine;
  final Decoration decoration;
  final MessageStamp? stamp;
  final String roomId;
  final void Function(CallEvent)? onTap;
  final String? ownPlatform;
  final Widget? glyph;
  final Widget? wave;
  final ValueListenable<int>? secs;
  final int? runCount;
  final VoidCallback? onBadge;
  final Duration? frozenElapsed;

  bool get _groupLive => event.isGroup && event.isLive;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final phase = event.phaseFor(isMine: isMine);
    final colors = _CallColors.of(theme, isMine, phase);
    final title = callTitle(l, event, phase);
    final detailStyle = theme.caption.copyWith(
      fontSize: 12.5,
      height: 1.25,
      color: colors.detail,
      decoration: TextDecoration.none,
    );

    // Join pill: a group call that is live right now. Reads the store that is
    // already subscribed app-wide; the bubble subscribes to nothing.
    Widget? joinPill;
    if (_groupLive && onTap != null) {
      joinPill = ListenableBuilder(
        listenable: LiveCallsStore.instance,
        builder: (context, _) {
          final live = LiveCallsStore.instance.forRoom(roomId);
          final joinable =
              live != null && live.groupCallId == event.id && !live.mine;
          if (!joinable) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _JoinPill(
              label: l.callBubbleJoin,
              mine: isMine,
              theme: theme,
              onTap: () => onTap!(event),
            ),
          );
        },
      );
    }

    final people = event.isGroup && event.people != null
        ? l.callBubblePeople(event.people!)
        : null;
    final String? sub;
    if (runCount != null) {
      // The ×N badge already says how many; the line says what a tap does,
      // and only falls back to the count where a tap does nothing.
      sub = (event.isGroup || onTap == null)
          ? l.callBubbleMissedRun(runCount!)
          : l.callBubbleTapToCallBack;
    } else {
      sub = switch (phase) {
        CallPhase.calling || CallPhase.incomingRinging => l.callBubbleRinging,
        CallPhase.live => null,
        CallPhase.outgoingEnded || CallPhase.incomingEnded => _endedSub(l, phase),
        CallPhase.missed || CallPhase.cancelled || CallPhase.noAnswer =>
          (event.isGroup || onTap == null) ? null : l.callBubbleTapToCallBack,
        CallPhase.declined => null,
      };
    }

    final own = ownPlatform ?? DeviceIdentity.platformTag();
    final answeredOn =
        event.answeredOn != null && event.answeredElsewhere(own)
            ? l.callBubbleAnsweredOn(
                platformName(l, event.answeredOn!))
            : null;
    final q = event.quality;
    final qualityLabel = q == CallEventQuality.fair
        ? l.callBubbleQualityFair
        : q == CallEventQuality.poor
            ? l.callBubbleQualityPoor
            : null;

    Widget timerOrSub() {
      if (secs != null) {
        return ValueListenableBuilder<int>(
          valueListenable: secs!,
          builder: (context, s, _) {
            final clock = CallEvent.formatClock(Duration(seconds: s));
            final hasStarted = event.answeredAt != null;
            final text = [
              if (hasStarted) clock else l.callBubbleRinging,
              ?people,
            ].join(' · ');
            return Text(text, style: detailStyle);
          },
        );
      }
      // One sentence, one separator: "Incoming · 12:41 · Answered on Mac".
      final text = [
        ?sub,
        if (people != null && runCount == null) people,
        ?answeredOn,
      ].join(' · ');
      return Text(text, style: detailStyle);
    }

    final hasSubText =
        secs != null || sub != null || people != null || answeredOn != null;
    final detail = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 7,
      runSpacing: 3,
      children: [
        if (hasSubText) timerOrSub(),
        ?wave,
        if (qualityLabel != null)
          _Chip(
            label: qualityLabel,
            fill: colors.chipFill,
            ink: colors.detail,
            dot: q == CallEventQuality.poor
                ? theme.danger
                : const Color(0xFFE0A526),
            style: detailStyle,
          ),
        // Reserves the stamp's room; the visible twin sits in the corner.
        if (stamp != null && joinPill == null) StampSpacer(stamp: stamp!),
      ],
    );

    final titleStyle = theme.body.copyWith(
      color: colors.title,
      fontWeight: FontWeight.w600,
      height: 1.2,
      decoration: TextDecoration.none,
    );
    final titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(title,
              style: titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (runCount != null) ...[
          const SizedBox(width: 8),
          CountBadge.label(
            text: l.callBubbleRunBadge(runCount!),
            fill: isMine
                ? theme.accentInk.withValues(alpha: 0.24)
                : theme.danger,
            ink: isMine ? theme.accentInk : Colors.white,
            onTap: onBadge,
          ),
        ],
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              glyph ??
                  _GlyphDisc(
                    video: event.isVideo,
                    colors: colors,
                    tip: phase == CallPhase.declined ? 1 : 0,
                  ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleRow, const SizedBox(height: 2), detail],
                ),
              ),
            ],
          ),
          ?joinPill,
        ],
      ),
    );

    Widget bubble = Container(
      decoration: decoration,
      constraints: const BoxConstraints(minWidth: 196),
      child: (stamp != null && joinPill == null)
          ? Stack(
              children: [
                content,
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  end: 14,
                  bottom: 9,
                  child: IgnorePointer(child: stamp!),
                ),
              ],
            )
          : content,
    );

    final canTap = onTap != null && !_groupLive;
    if (canTap) {
      bubble = SpringPress(
        onTap: () => onTap!(event),
        scale: 0.975,
        hover: HoverEffect.none,
        child: bubble,
      );
    }
    final spoken = [
      title,
      ?sub,
      ?people,
    ].join(', ');
    return Semantics(
      container: true,
      label: spoken,
      button: canTap,
      child: bubble,
    );
  }

  String? _endedSub(AppLocalizations l, CallPhase phase) {
    final d = event.duration;
    final out = phase == CallPhase.outgoingEnded;
    if (d == null || d.inSeconds <= 0) {
      return out ? l.callBubbleOutgoing : l.callBubbleIncoming;
    }
    final clock = CallEvent.formatClock(d);
    return out
        ? l.callBubbleOutgoingDuration(clock)
        : l.callBubbleIncomingDuration(clock);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.fill,
    required this.ink,
    required this.dot,
    required this.style,
  });

  final String label;
  final Color fill;
  final Color ink;
  final Color dot;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 1, 7, 1),
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: fill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: style.copyWith(fontSize: 11, color: ink)),
          ],
        ),
      );
}

class _JoinPill extends StatelessWidget {
  const _JoinPill({
    required this.label,
    required this.mine,
    required this.theme,
    required this.onTap,
  });

  final String label;
  final bool mine;
  final AppTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SpringPress(
        onTap: onTap,
        scale: PressSpec.scale,
        hover: HoverEffect.none,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: mine ? theme.accentInk : theme.accent,
          ),
          child: Text(
            label,
            style: theme.body.copyWith(
              fontWeight: FontWeight.w700,
              color: mine ? theme.accent : theme.accentInk,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      );
}

// ──────────────────────────── glyph ────────────────────────────

class _GlyphDisc extends StatelessWidget {
  const _GlyphDisc({
    required this.video,
    required this.colors,
    this.scale = 1,
    this.rotation = 0,
    this.tip = 0,
  });

  final bool video;
  final _CallColors colors;
  final double scale;
  final double rotation;
  final double tip;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: colors.disc, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(
              painter: CallGlyphPainter(
                video: video,
                color: colors.glyph,
                tip: tip,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The handset or camera as a stroked line glyph, drawn so it can move.
/// [tip] 0..1 turns the handset face down (a declined call); the camera ignores
/// it.
class CallGlyphPainter extends CustomPainter {
  CallGlyphPainter({required this.video, required this.color, this.tip = 0});

  final bool video;
  final Color color;
  final double tip;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.save();
    canvas.scale(s);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (video) {
      final body = RRect.fromLTRBR(2.5, 6, 15, 18, const Radius.circular(3));
      canvas.drawRRect(body, p);
      final lens = Path()
        ..moveTo(15, 10.4)
        ..lineTo(20.2, 7.4)
        ..quadraticBezierTo(21.5, 6.8, 21.5, 8.2)
        ..lineTo(21.5, 15.8)
        ..quadraticBezierTo(21.5, 17.2, 20.2, 16.6)
        ..lineTo(15, 13.6);
      canvas.drawPath(lens, p);
    } else {
      // Tipped down: swing the handset about its centre, to the hang-up pose.
      canvas.translate(12, 12);
      canvas.rotate(tip * 2.36);
      canvas.translate(-12, -12);
      canvas.drawPath(_handset, p);
    }
    canvas.restore();
  }

  // A handset on a 24 box: two earpieces joined by the curve of the grip.
  static final Path _handset = Path()
    ..moveTo(22, 16.92)
    ..lineTo(22, 19.92)
    ..arcToPoint(const Offset(19.82, 21.92),
        radius: const Radius.circular(2), clockwise: true)
    ..arcToPoint(const Offset(11.19, 18.85),
        radius: const Radius.circular(19.79), clockwise: true)
    ..arcToPoint(const Offset(5.19, 12.85),
        radius: const Radius.circular(19.5), clockwise: true)
    ..arcToPoint(const Offset(2.12, 4.18),
        radius: const Radius.circular(19.79), clockwise: true)
    ..arcToPoint(const Offset(4.11, 2),
        radius: const Radius.circular(2), clockwise: true)
    ..lineTo(7.11, 2)
    ..arcToPoint(const Offset(9.11, 3.72),
        radius: const Radius.circular(2), clockwise: true)
    ..arcToPoint(const Offset(9.81, 6.53),
        radius: const Radius.circular(12.84), clockwise: false)
    ..arcToPoint(const Offset(9.36, 8.64),
        radius: const Radius.circular(2), clockwise: true)
    ..lineTo(8.09, 9.91)
    ..arcToPoint(const Offset(14.09, 15.91),
        radius: const Radius.circular(16), clockwise: false)
    ..lineTo(15.36, 14.64)
    ..arcToPoint(const Offset(17.47, 14.19),
        radius: const Radius.circular(2), clockwise: true)
    ..arcToPoint(const Offset(20.28, 14.89),
        radius: const Radius.circular(12.84), clockwise: false)
    ..arcToPoint(const Offset(22, 16.92),
        radius: const Radius.circular(2), clockwise: true)
    ..close();

  @override
  bool shouldRepaint(CallGlyphPainter old) =>
      old.video != video || old.color != color || old.tip != tip;
}

// ──────────────────────────── waveform ────────────────────────────

/// Five soft bars. Repaints from the loop (live) or the settle controller
/// (flattening) and from nothing else; the paint object and the phase table
/// are reused, so a frame allocates nothing but the five endpoints.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.loop,
    required this.fx,
    required this.settling,
    required this.color,
  }) : super(repaint: Listenable.merge([?loop, fx]));

  final Animation<double>? loop;
  final Animation<double> fx;
  final bool settling;
  final Color color;

  static const _phase = [0.0, 0.31, 0.57, 0.18, 0.74];
  static const _base = [0.5, 0.8, 1.0, 0.7, 0.45];
  final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;

  @override
  void paint(Canvas canvas, Size size) {
    _paint.color = color;
    // Flattening: 1 -> 0 over the first half of the settle.
    final amp = settling
        ? 1 - Curves.easeOut.transform((fx.value / 0.5).clamp(0.0, 1.0))
        : 1.0;
    final t = loop?.value ?? 0.0;
    final mid = size.height / 2;
    final step = size.width / 5;
    for (var i = 0; i < 5; i++) {
      final wob = 0.5 + 0.5 * math.sin((t + _phase[i]) * 2 * math.pi);
      final h = (1.5 + (size.height - 1.5) * _base[i] * (0.35 + 0.65 * wob) * amp) / 2;
      final x = step * (i + 0.5);
      canvas.drawLine(Offset(x, mid - h), Offset(x, mid + h), _paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || old.settling != settling || old.loop != loop;
}
