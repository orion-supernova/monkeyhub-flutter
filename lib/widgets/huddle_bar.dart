import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/chat_api.dart';
import '../calls/audio_level_monitor.dart';
import '../calls/group_call_service.dart';
import '../calls/live_calls_store.dart';
import '../calls/widgets/call_chrome.dart' show kCallAcceptGreen;
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/huddle_history.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'app_toast.dart';
import 'chat_dock.dart';
import 'chrome_motion.dart';
import 'glass_reveal.dart';
import 'liquid_glass.dart';
import 'spring_press.dart';
import 'user_avatar.dart';

// The huddle's three faces in a chat, from one file:
//
//  * [HuddleBar]       you are in a huddle here (dock shelf, priority huddle)
//  * [HuddleJoinPill]  others are in one and you are not (priority join)
//  * [HuddleHistoryLine] the system line it leaves behind
//
// plus [huddleShelfItems], the one function the room screen calls to register
// whichever of the first two applies. Design: docs/design/swipe-up-fork.html
// (#notify, #dock, #motion).

/// Height of the in-huddle bar. Its shelf row ([DockShelfItem.height]) is
/// [kHuddleBarRowHeight].
const double kHuddleBarHeight = 74;

/// Height of the join pill (WhatsApp's, scaled up a little for thumbs).
const double kHuddlePillHeight = 56;

/// The shelf row each form asks for: the form plus 6pt of air above and below.
const double kHuddleBarRowHeight = kHuddleBarHeight + 12;
const double kHuddlePillRowHeight = kHuddlePillHeight + 12;

/// Where a room stands with respect to huddles, for the shelf.
enum HuddleShelfMode {
  /// Nothing to show.
  none,

  /// This device is in the room's huddle: the bar.
  inHuddle,

  /// Others are in a huddle here and this device is free to join: the pill.
  join,
}

/// Which shelf item (if any) [roomId] gets, from state the app already holds.
///
/// A plain call is not a huddle: it keeps its banner and its chat-list pill.
/// A huddle you are in on ANOTHER of your devices shows nothing here, and one
/// you cannot join because this device is in a different call shows no pill
/// (a button that can only fail is worse than none).
HuddleShelfMode huddleShelfModeFor({
  required String roomId,
  required GroupCallService? service,
  required LiveRoomCall? live,
}) {
  final inCall = service?.inCall ?? false;
  if (inCall && service!.roomId == roomId && service.isHuddle) {
    return HuddleShelfMode.inHuddle;
  }
  if (live != null &&
      live.isHuddle &&
      !live.mine &&
      live.groupCallId != null &&
      !inCall) {
    return HuddleShelfMode.join;
  }
  return HuddleShelfMode.none;
}

/// The shelf items for [roomId]'s huddle: zero or one.
///
/// [members] is the room's loaded people, for faces and names. [onJoin] is the
/// existing join path (the same one the swipe fork calls); its failure is
/// toasted here.
List<DockShelfItem> huddleShelfItems({
  required String roomId,
  required GroupCallService? service,
  required LiveRoomCall? live,
  required Map<String, ChatUser> members,
  required String? myUserId,
  required ChatApi? api,
  required Future<void> Function() onJoin,
}) {
  switch (huddleShelfModeFor(roomId: roomId, service: service, live: live)) {
    case HuddleShelfMode.none:
      return const [];
    case HuddleShelfMode.inHuddle:
      final svc = service!;
      void open() => svc.reopenTick.value++;
      return [
        DockShelfItem(
          id: 'huddle',
          priority: DockShelfPriority.huddle,
          height: kHuddleBarRowHeight,
          expanded: (_) => HuddleBarHost(
            service: svc,
            members: members,
            api: api,
            onOpen: open,
          ),
          chip: (_) => HuddleChip(onTap: open),
        ),
      ];
    case HuddleShelfMode.join:
      final ids = [
        for (final id in live!.joinedUserIds)
          if (id != myUserId) id,
      ];
      return [
        DockShelfItem(
          id: 'huddle-join',
          priority: DockShelfPriority.join,
          height: kHuddlePillRowHeight,
          expanded: (_) => HuddleJoinPill(
            users: [for (final id in ids) members[id] ?? _stub(id)],
            api: api,
            onJoin: onJoin,
          ),
          chip: (_) => HuddleChip(onTap: () => unawaited(_tryJoin(onJoin))),
        ),
      ];
  }
}

ChatUser _stub(String id) => ChatUser(id: id, username: '', name: '');

Future<void> _tryJoin(Future<void> Function() onJoin) async {
  try {
    await onJoin();
  } catch (_) {}
}

// ───────────────────────────────── names ─────────────────────────────────

/// "Nobody else here yet" / "Zeynep" / "Zeynep and Alp" / "Zeynep and 2 others".
String huddleNamesLabel(AppLocalizations l10n, List<String> others) {
  switch (others.length) {
    case 0:
      return l10n.huddleBarNobodyElse;
    case 1:
      return others.first;
    case 2:
      return l10n.huddleBarNamesTwo(others[0], others[1]);
    default:
      return l10n.huddleBarNamesMore(others.length - 1, others.first);
  }
}

// ──────────────────────────────── the bar ────────────────────────────────

/// One face in the bar and the level that drives its speaking ring.
class HuddleFace {
  const HuddleFace({required this.user, this.level, this.muted = false});

  final ChatUser user;

  /// Smoothed 0..1 audio level; null draws no ring.
  final ValueListenable<double>? level;
  final bool muted;
}

/// The bar shown while you are in a huddle in this room.
///
/// Purely presentational: [HuddleBarHost] feeds it from the call service.
/// Lands with a squash and stretch and, when [playRings] (you just started or
/// joined), two sound rings pulsing out of it. The speaking rings are the one
/// continuous motion, because they are a live state.
class HuddleBar extends StatefulWidget {
  const HuddleBar({
    super.key,
    required this.faces,
    required this.names,
    required this.muted,
    required this.onToggleMute,
    required this.onLeave,
    required this.onOpen,
    this.api,
    this.playRings = false,
  });

  /// Me first, then the others, as many as fit (the bar shows four).
  final List<HuddleFace> faces;

  /// "Nobody else here yet" or who is here, already localized.
  final String names;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onLeave;

  /// The middle: faces and names. Opens the full call screen.
  final VoidCallback onOpen;
  final ChatApi? api;
  final bool playRings;

  @override
  State<HuddleBar> createState() => _HuddleBarState();
}

class _HuddleBarState extends State<HuddleBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _land;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _land = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Calm motion lands the bar where it stands: no squash, no rings.
    if (MotionScope.of(context).calm) {
      _land.value = 1;
    } else {
      _land.forward();
    }
  }

  @override
  void dispose() {
    _land.dispose();
    super.dispose();
  }

  /// 0..1 over the first ~55% of the landing: the glass growing in, with the
  /// overshoot [Curves.easeOutBack] gives.
  double _grow(double t) =>
      Curves.easeOutBack.transform((t / 0.55).clamp(0.0, 1.0));

  /// Squash and stretch about the settle: wide and short at first contact,
  /// tall and narrow on the rebound, then rest. Damped, so it is over in
  /// ~0.5 s.
  Offset _squash(double t) {
    if (t >= 1) return const Offset(1, 1);
    final u = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    final s = math.sin(u * math.pi * 2.5) * math.pow(1 - u, 1.6) * 0.09;
    return Offset(1 + s, 1 - s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l10n.huddleBarSemantics(widget.names),
      child: AnimatedBuilder(
        animation: _land,
        child: _content(context, theme, l10n),
        builder: (context, content) {
          final t = _land.value;
          final sq = _squash(t);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (widget.playRings && t < 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _SoundRingsPainter(
                        t: t,
                        color: kCallAcceptGreen,
                      ),
                    ),
                  ),
                ),
              GlassReveal(
                t: _grow(t),
                from: 0.55,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(sq.dx, sq.dy, 1),
                  child: content,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// WhatsApp's voice-chat bar, scaled to the shelf row: a round mute button,
  /// the faces over a muted caption, a round red hang-up button. The shelf is
  /// [kDockShelfHeight] tall, so the buttons are 30pt where WhatsApp's are 37.
  Widget _content(BuildContext context, AppTheme theme, AppLocalizations l10n) {
    final faces = widget.faces.take(4).toList();
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(
          box.maxWidth - 32, math.max(kHuddleBarMinWidth, box.maxWidth * 0.64));
        return LiquidGlass(
          shape: LiquidGlassShape.rounded,
          padding: const EdgeInsets.all(_kBarPad),
          radius: 22,
          child: SizedBox(
            width: w - _kBarPad * 2,
            height: kHuddleBarHeight - _kBarPad * 2,
            child: Row(
              children: [
                _RoundButton(
                  icon: widget.muted
                      ? CupertinoIcons.mic_slash_fill
                      : CupertinoIcons.mic_fill,
                  fill: theme.ink.withValues(alpha: 0.14),
                  color: widget.muted ? theme.inkMuted : theme.ink,
                  semanticLabel: widget.muted
                      ? l10n.groupCallScreenUnmuteLabel
                      : l10n.groupCallScreenMuteLabel,
                  kickTrigger: widget.muted,
                  onTap: widget.onToggleMute,
                ),
                // The middle opens the call screen. A generous target, since
                // it is the bar's one big thing.
                Expanded(
                  child: SpringPress(
                    onTap: widget.onOpen,
                    scale: 0.98,
                    semanticLabel: l10n.huddleBarOpenSemantics,
                    focusShape: FocusRingShape.capsule,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _FaceStack(
                              faces: faces,
                              api: widget.api,
                              size: 36,
                              step: 26,
                            ),
                            const SizedBox(width: 6),
                            const _WaveDisc(),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            widget.names,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.caption.copyWith(
                              fontSize: 10.5,
                              height: 1.1,
                              color: theme.inkMuted,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _RoundButton(
                  icon: CupertinoIcons.phone_down_fill,
                  fill: theme.danger,
                  color: Colors.white,
                  semanticLabel: l10n.groupCallScreenLeaveLabel,
                  onTap: widget.onLeave,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// WhatsApp's bar is ~63% of the screen wide (247 of 390).
const double kHuddleBarMinWidth = 260;
const double _kBarPad = 6;
const double _kBarButton = 37;

/// The small grey disc after the faces (WhatsApp's wave/check disc): a still
/// waveform, so the bar has no idle loop.
class _WaveDisc extends StatelessWidget {
  const _WaveDisc();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.ink.withValues(alpha: 0.14),
      ),
      child: HuddleWaveGlyph(size: 14, color: theme.inkMuted, live: false),
    );
  }
}

/// Two rings of sound leaving the bar, one after the other. Strokes only: the
/// fade is the stroke's own alpha, never a layer over glass.
class _SoundRingsPainter extends CustomPainter {
  _SoundRingsPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 2; i++) {
      final p = ((t - 0.12 - i * 0.28) / 0.5).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final e = Curves.easeOutCubic.transform(p);
      final grow = 3 + 15 * e;
      final rect = (Offset.zero & size).inflate(grow);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - e) + 0.6
          ..color = color.withValues(alpha: 0.55 * (1 - e)),
      );
    }
  }

  @override
  bool shouldRepaint(_SoundRingsPainter old) => old.t != t || old.color != color;
}

/// Overlapping faces, each with its speaking ring.
class _FaceStack extends StatelessWidget {
  const _FaceStack({
    required this.faces,
    required this.api,
    this.size = 24,
    this.step = 15,
  });

  final List<HuddleFace> faces;
  final ChatApi? api;
  final double size;
  final double step;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final pad = size >= 22 ? 2.0 : 1.0;
    final width = size + (faces.length - 1) * step + pad * 2;
    return SizedBox(
      width: width,
      height: size + pad * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Later faces under earlier ones, so "me" is on top at the left.
          for (var i = faces.length - 1; i >= 0; i--)
            Positioned(
              left: i * step,
              top: 0,
              child: _SpeakingFace(
                face: faces[i],
                api: api,
                size: size,
                rim: theme.surfaceRaised,
              ),
            ),
        ],
      ),
    );
  }
}

class _SpeakingFace extends StatelessWidget {
  const _SpeakingFace({
    required this.face,
    required this.api,
    required this.rim,
    required this.size,
  });

  final HuddleFace face;
  final ChatApi? api;
  final Color rim;
  final double size;

  @override
  Widget build(BuildContext context) {
    // A thinner rim on the bar's small faces.
    final pad = size >= 22 ? 2.0 : 1.0;
    final avatar = Container(
      width: size + pad * 2,
      height: size + pad * 2,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(shape: BoxShape.circle, color: rim),
      child: UserAvatar(
        user: face.user,
        api: api,
        size: size,
        showStatus: false,
      ),
    );
    final level = face.level;
    if (level == null) return avatar;
    // Only this ring repaints when the level moves.
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _SpeakingRingPainter(level: level),
        child: avatar,
      ),
    );
  }
}

/// Green ring that wakes when somebody talks and swells with the voice.
class _SpeakingRingPainter extends CustomPainter {
  _SpeakingRingPainter({required this.level}) : super(repaint: level);

  final ValueListenable<double> level;

  @override
  void paint(Canvas canvas, Size size) {
    final v = level.value;
    if (v < 0.04) return;
    final a = (v * 5).clamp(0.0, 1.0);
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 + 1.2 * v.clamp(0.0, 1.0)
        ..color = kCallAcceptGreen.withValues(alpha: a),
    );
  }

  @override
  bool shouldRepaint(_SpeakingRingPainter old) => old.level != level;
}

/// A 37pt round control inside the bar, on its own filled disc.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.fill,
    required this.color,
    required this.semanticLabel,
    required this.onTap,
    this.kickTrigger,
  });

  final IconData icon;
  final Color fill;
  final Color color;
  final String semanticLabel;
  final VoidCallback onTap;
  final Object? kickTrigger;

  @override
  Widget build(BuildContext context) {
    Widget glyph = Icon(icon, size: 19, color: color);
    if (kickTrigger != null) {
      glyph = KickGlyph(kick: GlyphKick.pop, trigger: kickTrigger, child: glyph);
    }
    return SpringPress(
      onTap: onTap,
      semanticLabel: semanticLabel,
      focusShape: FocusRingShape.circle,
      child: Container(
        width: _kBarButton,
        height: _kBarButton,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        child: glyph,
      ),
    );
  }
}

// ─────────────────────────────── the host ────────────────────────────────

/// Feeds a [HuddleBar] from the call service: who is here, who is speaking,
/// whether the mic is muted. Owns its own [AudioLevelMonitor], which polls
/// only while the bar is on screen.
class HuddleBarHost extends StatefulWidget {
  const HuddleBarHost({
    super.key,
    required this.service,
    required this.members,
    required this.onOpen,
    this.api,
  });

  final GroupCallService service;
  final Map<String, ChatUser> members;
  final VoidCallback onOpen;
  final ChatApi? api;

  @override
  State<HuddleBarHost> createState() => _HuddleBarHostState();
}

class _HuddleBarHostState extends State<HuddleBarHost> {
  final AudioLevelMonitor _levels =
      AudioLevelMonitor(interval: const Duration(milliseconds: 400));

  GroupCallService get svc => widget.service;

  @override
  void initState() {
    super.initState();
    svc.addListener(_onChanged);
    _levels.sources = () sync* {
      for (final p in svc.peers.values) {
        final pc = p.pc;
        final track = _firstAudio(p.remoteStream);
        if (pc == null || track == null) continue;
        yield AudioLevelSource(
          id: p.userId,
          pc: pc,
          track: track,
          muted: p.mediaState.audioMuted || !p.connected,
        );
      }
    };
    _levels.localPc = () {
      for (final p in svc.peers.values) {
        if (p.pc != null) return p.pc;
      }
      return null;
    };
    _levels.localTrack = () => _firstAudio(svc.localStream);
    // Not started here: see [didChangeDependencies].
  }

  /// Polls only while this screen can be seen.
  ///
  /// Tapping the bar opens the full call screen ON TOP of the room, and the
  /// room stays mounted underneath with this bar in it. The call screen runs
  /// its own [AudioLevelMonitor], so polling here too would read the same
  /// peer connections' stats twice for nothing anyone sees. A route covered
  /// by an opaque one has its tickers switched off by the Navigator, and that
  /// is exactly the signal: follow [TickerMode] and stop while it's off.
  ValueListenable<TickerModeData>? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TickerMode.getValuesNotifier(context);
    if (!identical(next, _visible)) {
      _visible?.removeListener(_syncPolling);
      _visible = next..addListener(_syncPolling);
    }
    _syncPolling();
  }

  void _syncPolling() {
    final on = _visible?.value.enabled ?? true;
    if (on && !_levels.running) {
      _levels.start();
    } else if (!on && _levels.running) {
      _levels.stop();
    }
  }

  static MediaStreamTrack? _firstAudio(MediaStream? s) {
    final tracks = s?.getAudioTracks();
    return (tracks == null || tracks.isEmpty) ? null : tracks.first;
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    svc.removeListener(_onChanged);
    _visible?.removeListener(_syncPolling);
    _levels
      ..stop()
      ..dispose();
    super.dispose();
  }

  ChatUser _user(String id, String fallbackName) =>
      widget.members[id] ??
      ChatUser(id: id, username: '', name: fallbackName);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = svc.userId ?? '';
    // Who is here, from the roster (joined rows) with the live links as the
    // fallback for the moment before it arrives.
    final others = <String>[];
    for (final r in svc.rosterRows) {
      final id = r['userId']?.toString();
      if (id != null && id != me && r['status'] == 'joined') others.add(id);
    }
    if (svc.rosterRows.isEmpty) {
      others.addAll(svc.peers.keys.where((id) => id != me));
    }
    final faces = <HuddleFace>[
      HuddleFace(
        user: _user(me, ''),
        level: _levels.levelOf(AudioLevelMonitor.me),
        muted: svc.localMuted,
      ),
      for (final id in others)
        HuddleFace(
          user: _user(id, svc.peers[id]?.name ?? ''),
          level: _levels.levelOf(id),
          muted: svc.peers[id]?.mediaState.audioMuted ?? false,
        ),
    ];
    final joinedAt = svc.joinedAt;
    final fresh = joinedAt != null &&
        DateTime.now().difference(joinedAt) < const Duration(seconds: 6);
    return HuddleBar(
      faces: faces,
      names: huddleNamesLabel(l10n, [
        for (final id in others)
          _user(id, svc.peers[id]?.name ?? '').displayName,
      ]),
      muted: svc.localMuted,
      api: widget.api,
      playRings: fresh,
      onToggleMute: () => unawaited(svc.toggleMute()),
      onLeave: () => unawaited(svc.leaveCall()),
      onOpen: widget.onOpen,
    );
  }
}

// ─────────────────────────────── join pill ───────────────────────────────

/// Others are in a huddle here: up to three real faces and a Join capsule.
/// Joining is the existing join path; a failure is toasted.
class HuddleJoinPill extends StatefulWidget {
  const HuddleJoinPill({
    super.key,
    required this.users,
    required this.onJoin,
    this.api,
  });

  final List<ChatUser> users;
  final Future<void> Function() onJoin;
  final ChatApi? api;

  @override
  State<HuddleJoinPill> createState() => _HuddleJoinPillState();
}

class _HuddleJoinPillState extends State<HuddleJoinPill> {
  bool _busy = false;

  Future<void> _join() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onJoin();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showAppToast(
        context,
        e.toString().contains('CALL_FULL')
            ? l10n.forkFailCallFull
            : l10n.forkFailGeneric,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final shown = widget.users.take(3).toList();
    final names = huddleNamesLabel(l10n, [
      for (final u in widget.users) u.displayName,
    ]);
    // WhatsApp's compact pill: the speakers' faces and one big green capsule,
    // no words but the button's own. Names ride along as the faces' label.
    return _GrowIn(
      child: LiquidGlass(
        shape: LiquidGlassShape.capsule,
        padding: const EdgeInsets.fromLTRB(8, 5, 5, 5),
        child: SizedBox(
          height: kHuddlePillHeight - 10,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: names,
                child: ExcludeSemantics(
                  child: _FaceStack(
                    faces: [for (final u in shown) HuddleFace(user: u)],
                    api: widget.api,
                    size: 36,
                    step: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SpringPress(
                onTap: () => unawaited(_join()),
                semanticLabel: l10n.forkActionJoinHuddle,
                focusShape: FocusRingShape.capsule,
                child: Container(
                  height: kHuddlePillHeight - 10,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kCallAcceptGreen.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _busy
                          ? kCallAcceptGreen.withValues(alpha: 0.6)
                          : kCallAcceptGreen,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.speaker_2_fill,
                            size: 20, color: Colors.black),
                        const SizedBox(width: 7),
                        Text(
                          l10n.groupCallBannerJoinButtonLabel,
                          style: theme.bodySoft.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
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
        ),
      ),
    );
  }
}

/// Glass that grows in (never fades) once, on mount; instant under calm
/// motion.
class _GrowIn extends StatefulWidget {
  const _GrowIn({required this.child});
  final Widget child;

  @override
  State<_GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<_GrowIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionScope.of(context).calm) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (_, child) =>
            GlassReveal(t: _curve.value, from: 0.6, child: child!),
      );
}

// ─────────────────────────────── chip & glyph ────────────────────────────

/// The shelf's collapsed form of a huddle: the live waveform glyph.
class HuddleChip extends StatelessWidget {
  const HuddleChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: kDockShelfHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: kDockChipWidth),
          child: LiquidGlass(
            shape: LiquidGlassShape.capsule,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            onTap: onTap,
            semanticLabel: l10n.huddleChipSemantics,
            child: Center(
              widthFactor: 1,
              child: HuddleWaveGlyph(size: 13, color: theme.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four rounded bars rising and falling out of step: someone is in a huddle.
///
/// A live state, so it is allowed an idle loop; Reduce Motion (or [live]
/// false) gets the still, even glyph. The ticker is only created when it will
/// run.
class HuddleWaveGlyph extends StatefulWidget {
  const HuddleWaveGlyph({
    super.key,
    required this.size,
    required this.color,
    this.live = true,
  });

  final double size;
  final Color color;
  final bool live;

  @override
  State<HuddleWaveGlyph> createState() => _HuddleWaveGlyphState();
}

class _HuddleWaveGlyphState extends State<HuddleWaveGlyph>
    with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HuddleWaveGlyph old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) _sync();
  }

  void _sync() {
    final run = widget.live && !MotionScope.of(context).calm;
    if (!run) {
      _loop?.stop();
      return;
    }
    final loop = _loop ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!loop.isAnimating) loop.repeat();
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loop = _loop;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _WavePainter(
          loop: loop,
          color: widget.color,
          moving: loop?.isAnimating ?? false,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.loop, required this.color, required this.moving})
      : super(repaint: loop);

  final AnimationController? loop;
  final Color color;
  final bool moving;

  static const _still = [0.45, 0.85, 0.65, 0.4];

  @override
  void paint(Canvas canvas, Size size) {
    const n = 4;
    final w = size.width / (n * 2 - 1);
    final v = loop?.value ?? 0;
    final paint = Paint()..color = color;
    for (var i = 0; i < n; i++) {
      final h = moving
          ? 0.3 +
              0.7 *
                  (0.5 +
                      0.5 * math.sin(2 * math.pi * (v * (1 + i % 2) + i * 0.27)))
          : _still[i];
      final bh = size.height * h.clamp(0.2, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 2 * w, (size.height - bh) / 2, w, bh),
          Radius.circular(w / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || old.moving != moving;
}

// ───────────────────────────── history line ──────────────────────────────

/// "Huddle · 12 min · 3 people", or the starter's local-only
/// "You wanted to talk · Nobody joined".
///
/// A centred system line, not a bubble: it is a fact about the room, not
/// something anybody said. [content] is the raw message content; a string that
/// is neither line renders nothing.
class HuddleHistoryLine extends StatelessWidget {
  const HuddleHistoryLine({super.key, required this.content});

  final String content;

  /// The localized text for [content], or null if it is not a huddle line.
  static String? textFor(AppLocalizations l10n, String content) {
    if (HuddleHistory.isAlone(content)) return l10n.huddleAloneLine;
    final h = HuddleHistory.parse(content);
    if (h == null) return null;
    return l10n.huddleHistoryLine(
      formatHuddleDuration(l10n, h.duration),
      l10n.huddlePeopleCount(h.people),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = textFor(AppLocalizations.of(context), content);
    if (text == null) return const SizedBox.shrink();
    final theme = ThemeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HuddleWaveGlyph(size: 12, color: theme.inkMuted, live: false),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.caption.copyWith(
                  fontSize: 12.5,
                  color: theme.inkMuted,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "under a minute", "12 min", "1 h 05 min".
String formatHuddleDuration(AppLocalizations l10n, Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 1) return l10n.huddleDurationUnderMinute;
  if (minutes < 60) return l10n.huddleDurationMinutes(minutes);
  return l10n.huddleDurationHours(
    minutes ~/ 60,
    (minutes % 60).toString().padLeft(2, '0'),
  );
}
