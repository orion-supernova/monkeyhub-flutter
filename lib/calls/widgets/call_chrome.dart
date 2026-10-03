import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chat_user.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/user_avatar.dart';
import '../call_stats_monitor.dart';
import '../../widgets/spring_press.dart';

/// The chrome both call screens are built from.
///
/// These grew up inside the 1:1 screen as private widgets and were copied,
/// worse, into the group screen. Now that a voice call can become a video
/// call mid-way and a shared screen can land on either, the two screens
/// have more in common than apart, and this is the one place their
/// vocabulary lives: the glass tray, the control button that sizes itself to
/// its slot, the tap-to-hide fade, the transient chip, the timer, the
/// ambient backdrop with its pulse rings, the ring that says who is talking
/// and the orb that stands for a participant in a voice call.

/// The glass tray the controls sit in: a frosted capsule over whatever is
/// behind it, capped and centred so on a wide window it reads as one
/// grouped control rather than a bar stretched edge to edge.
class GlassTray extends StatelessWidget {
  const GlassTray({
    super.key,
    required this.child,
    this.maxWidth = 460,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // iOS 26's tray: corners as round as the controls inside them
        // (concentric), so a one-row tray reads as a capsule and a two-row
        // one as a rounded slab of the same family.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(38),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                // Dark glass, not light: the controls are white, and over a
                // bright camera picture a white-tinted capsule left them
                // unreadable. FaceTime's tray is dark for the same reason.
                // The top-lit gradient is the glass's specular edge.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.42),
                  ],
                  stops: const [0.0, 0.45],
                ),
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// One control in the tray, in priority order — the first ones are the
/// ones that keep the first row when the tray has to wrap.
class CallTrayAction {
  const CallTrayAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;

  /// Handed to the button, so a test can find one control among many.
  final Key? key;
}

/// The control tray both call screens share: a glass capsule of round
/// controls and, standing alone beneath it, the red end-call hero.
///
/// The old tray was one `Row` of `Expanded` buttons — eight of them on a
/// phone left each ~42 pt wide with its label cut short. This one lays the
/// controls out the way FaceTime, Meet and Teams do: every control is the
/// same fixed size, as many as fit stand in a row, and the rest wrap onto
/// a second, quieter row. [actions] is in priority order, so the everyday
/// toggles (mute, camera, speaker, share) keep the first row and the
/// occasional ones (flip, options, hide) are the ones that move down. Rows
/// are balanced — five controls on a phone that fits five stay on one row;
/// seven become four and three, never six and one.
///
/// On a wide window the capsule grows until every control is on one row,
/// so a desktop keeps the single-line tray it always had.
class CallTray extends StatelessWidget {
  const CallTray({
    super.key,
    required this.actions,
    required this.endIcon,
    required this.endLabel,
    required this.onEnd,
    required this.endColor,
    this.maxWidth = 480,
  });

  final List<CallTrayAction> actions;
  final IconData endIcon;
  final String endLabel;
  final VoidCallback onEnd;
  final Color endColor;

  /// The capsule's width on a wide window — unless one row of every
  /// control needs more, in which case it gets that.
  final double maxWidth;

  /// A control's diameter, and the narrower one for a capsule with less
  /// than [compactBelow] to lay out in (a 320 pt phone).
  static const double diameter = 56;
  static const double compactDiameter = 48;
  static const double compactBelow = 300;

  /// Between two controls in a row, and between two rows.
  static const double gap = 12;
  static const double rowGap = 12;

  static const EdgeInsets capsulePadding =
      EdgeInsets.symmetric(horizontal: 12, vertical: 14);

  /// The capsule's hairline border — GlassTray draws it inside the box, so
  /// it comes out of the room the controls have.
  static const double capsuleBorder = 1;

  /// What the capsule takes off its width before the controls get any.
  static double get capsuleChrome =>
      capsulePadding.horizontal + 2 * capsuleBorder;

  /// Between the capsule and the end-call hero; the hero's own size; the
  /// clearance under it so it never sits on the home indicator.
  static const double heroGap = 16;
  static const double heroDiameter = 72;
  static const double bottomPadding = 10;

  /// The label under a control: a 6 pt gap and one 11 pt line.
  static const double labelBlock = 6 + 16;

  static double diameterFor(double innerWidth) =>
      innerWidth < compactBelow ? compactDiameter : diameter;

  /// The width one row of [count] controls of size [d] needs.
  static double oneRowWidth(int count, double d) =>
      count * d + math.max(0, count - 1) * gap;

  /// The capsule's width given [available] points of screen: [maxWidth],
  /// or wider when that is what one row of every control takes.
  static double capsuleWidth(int count, double available, double maxWidth) {
    final oneRow = oneRowWidth(count, diameter) + capsuleChrome;
    return math.min(available, math.max(maxWidth, oneRow));
  }

  /// How many of [count] controls stand in a row [innerWidth] wide: as many
  /// as fit at their fixed size, never fewer than three.
  static int perRow(int count, double innerWidth) {
    if (count <= 0) return 1;
    final d = diameterFor(innerWidth);
    final fit = ((innerWidth + gap) / (d + gap)).floor();
    return fit.clamp(math.min(3, count), count);
  }

  /// The rows [items] fall into: no more than [perRow] each, balanced so
  /// the last row is never a lone control, the first row taking the first
  /// — highest-priority — items.
  static List<List<T>> rowsFor<T>(List<T> items, int perRow) {
    if (items.isEmpty) return const [];
    final rows = (items.length / perRow).ceil();
    final per = (items.length / rows).ceil();
    return [
      for (var i = 0; i < items.length; i += per)
        items.sublist(i, math.min(i + per, items.length)),
    ];
  }

  /// How tall the tray is for [actionCount] controls on a screen [width]
  /// wide, measured above the safe-area inset — for the layouts that keep
  /// clear of it. [horizontalInset] is the padding the screen wraps the
  /// tray in on each side.
  static double estimateHeight({
    required int actionCount,
    required double width,
    double maxWidth = 480,
    double horizontalInset = 16,
  }) {
    final available = math.max(0.0, width - 2 * horizontalInset);
    final inner =
        capsuleWidth(actionCount, available, maxWidth) - capsuleChrome;
    final d = diameterFor(inner);
    final rows = actionCount <= 0
        ? 0
        : rowsFor(List<int>.filled(actionCount, 0), perRow(actionCount, inner))
            .length;
    final capsule = rows == 0
        ? 0.0
        : capsulePadding.vertical +
            2 * capsuleBorder +
            rows * (d + labelBlock) +
            (rows - 1) * rowGap;
    return capsule +
        (rows == 0 ? 0 : heroGap) +
        heroDiameter +
        labelBlock +
        bottomPadding;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : maxWidth;
        final capsule = capsuleWidth(actions.length, available, maxWidth);
        final inner = capsule - capsuleChrome;
        final d = diameterFor(inner);
        final rows = rowsFor(actions, perRow(actions.length, inner));
        // Columns line up across rows, and a shorter last row sits centred
        // under the one above. Slots snap to half a point so the row's sum
        // can never drift a hair past the width it was given.
        final cols = rows.isEmpty
            ? 1
            : rows.map((r) => r.length).reduce(math.max);
        final slot = (inner / cols * 2).floorToDouble() / 2;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rows.isNotEmpty) ...[
              GlassTray(
                maxWidth: capsule,
                padding: capsulePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: rowGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final a in rows[i])
                            SizedBox(
                              width: slot,
                              child: CallControlButton(
                                key: a.key,
                                icon: a.icon,
                                label: a.label,
                                onTap: a.onTap,
                                active: a.active,
                                enabled: a.enabled,
                                diameter: d,
                                // The everyday controls read a shade
                                // brighter than the ones that wrapped.
                                subdued: i > 0,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: heroGap),
            ],
            // The hero action: alone on its own row so it never competes
            // for space with the toggles above it, at a size that reads as
            // unmistakably primary.
            CallControlButton(
              icon: endIcon,
              background: endColor,
              iconColor: Colors.white,
              large: true,
              onTap: onEnd,
              label: endLabel,
            ),
            const SizedBox(height: bottomPadding),
          ],
        );
      },
    );
  }
}

/// The ambient ground of a voice call: a soft wash of the theme's accent
/// centred just above the middle, falling to black. The focal glow is the
/// avatar's own shadow, so the two always line up.
class CallBackdrop extends StatelessWidget {
  const CallBackdrop({super.key, required this.accent, this.child});

  final Color accent;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.0,
          colors: [accent.withValues(alpha: 0.32), Colors.black],
          stops: const [0.0, 0.85],
        ),
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}

/// Two concentric rings breathing outward from a [child] — the "someone is
/// on the line" motion of a voice call. [diameter] is the child's; the rings
/// start there and travel [reach] further.
class PulseRings extends StatefulWidget {
  const PulseRings({
    super.key,
    required this.accent,
    required this.diameter,
    required this.child,
    this.reach = 120,
    this.animate = true,
  });

  final Color accent;
  final double diameter;
  final double reach;
  final Widget child;

  /// Off under calm motion: the child stands still.
  final bool animate;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _start();
  }

  void _start() {
    _pulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void didUpdateWidget(PulseRings old) {
    super.didUpdateWidget(old);
    if (widget.animate && _pulse == null) _start();
    if (!widget.animate && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = _pulse;
    final box = widget.diameter + widget.reach;
    if (pulse == null) {
      return SizedBox(
        width: box,
        height: box,
        child: Center(child: widget.child),
      );
    }
    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: pulse,
        child: widget.child,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            for (final phase in const [0.0, 0.5])
              _ring((pulse.value + phase) % 1.0),
            child!,
          ],
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final size = widget.diameter + t * widget.reach;
    return Opacity(
      opacity: (1.0 - t) * 0.35,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.accent.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// The ring that says "talking": the avatar's own ring in the accent, and a
/// glow that breathes with the level. Listens to ONE notifier, so a word
/// spoken repaints this ring and nothing else on the screen.
class SpeakingRing extends StatelessWidget {
  const SpeakingRing({
    super.key,
    required this.level,
    required this.accent,
    required this.size,
    required this.child,
  });

  /// 0..1, smoothed by the monitor.
  final ValueListenable<double> level;
  final Color accent;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: level,
      child: child,
      builder: (context, l, child) {
        final on = l > 0.04;
        final glow = (l * 1.6).clamp(0.0, 1.0);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: on ? accent : Colors.white.withValues(alpha: 0.22),
              width: on ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18 + 0.42 * glow),
                blurRadius: 18 + 26 * glow,
                spreadRadius: 1 + 3 * glow,
              ),
            ],
          ),
          child: Padding(padding: const EdgeInsets.all(2), child: child),
        );
      },
    );
  }
}

/// A participant in a voice call: their face in a [SpeakingRing], their
/// name, and the small facts that matter — muted, still connecting, or not
/// even here yet (a [ghost] is someone invited whose phone is still
/// ringing).
class ParticipantOrb extends StatelessWidget {
  const ParticipantOrb({
    super.key,
    required this.user,
    required this.size,
    required this.level,
    required this.accent,
    required this.label,
    this.api,
    this.muted = false,
    this.dimmed = false,
    this.ghost = false,
    this.caption,
  });

  final ChatUser user;
  final double size;
  final ValueListenable<double> level;
  final Color accent;
  final String label;
  final ChatApi? api;
  final bool muted;
  final bool dimmed;
  final bool ghost;

  /// A line under the name — "Ringing…" for a ghost.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final avatar = UserAvatar(
      user: user,
      api: api,
      size: size - 6,
      showStatus: false,
    );
    Widget face = SpeakingRing(
      level: level,
      accent: accent,
      size: size,
      child: ClipOval(child: avatar),
    );
    if (ghost) {
      face = Opacity(
        opacity: 0.45,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: avatar),
          ),
        ),
      );
    } else if (dimmed) {
      face = Opacity(opacity: 0.55, child: face);
    }
    return SizedBox(
      width: size + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          face,
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (muted) ...[
                const Icon(Icons.mic_off, size: 12, color: Colors.white70),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: theme.monoTiny.copyWith(
                    color: Colors.white.withValues(alpha: ghost ? 0.6 : 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                caption!,
                style: theme.monoTiny.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// The self-view tile of a 1:1 video call, FaceTime-style: drag it anywhere
/// and on release it springs to the nearest corner, carrying the fling's
/// velocity into the spring so a flick lands where it was thrown.
///
/// Fills its parent (lay it out with [Positioned.fill]) and places the tile
/// inside, clear of [top] and [bottom] — the name block above and the tray
/// below. A tap still reaches [child]'s own handler (the feed swap): pans
/// and taps are separate gestures, and a tap moves nothing.
class DraggablePip extends StatefulWidget {
  const DraggablePip({
    super.key,
    required this.child,
    required this.top,
    required this.bottom,
    this.size = const Size(100, 140),
    this.margin = 16,
  });

  final Widget child;
  final double top;
  final double bottom;
  final Size size;
  final double margin;

  @override
  State<DraggablePip> createState() => _DraggablePipState();
}

class _DraggablePipState extends State<DraggablePip>
    with SingleTickerProviderStateMixin {
  /// Which corner the tile rests in: x and y each -1 or 1. Starts top-right,
  /// where the tile has always been.
  Offset _corner = const Offset(1, -1);

  /// The tile's top-left while dragging or settling; null at rest.
  Offset? _live;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;

  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  )..addListener(() {
      setState(() => _live = Offset.lerp(_from, _to, _settle.value));
    });

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  Offset _cornerOrigin(Size area, Offset corner) {
    final m = widget.margin;
    final w = widget.size.width;
    final h = widget.size.height;
    final x = corner.dx < 0 ? m : area.width - w - m;
    final y = corner.dy < 0 ? widget.top : area.height - h - widget.bottom;
    return Offset(x, y);
  }

  void _onEnd(Size area, DragEndDetails d) {
    final at = _live ?? _cornerOrigin(area, _corner);
    final v = d.velocity.pixelsPerSecond;
    // Project the fling a fifth of a second ahead and pick the corner it is
    // heading for — a flick across the screen should cross the screen.
    final projected = at + v * 0.2;
    final centre = projected +
        Offset(widget.size.width / 2, widget.size.height / 2);
    final next = Offset(
      centre.dx < area.width / 2 ? -1 : 1,
      centre.dy < area.height / 2 ? -1 : 1,
    );
    _corner = next;
    _from = at;
    _to = _cornerOrigin(area, next);
    final distance = (_to - _from).distance;
    if (distance < 1 || MediaQuery.disableAnimationsOf(context)) {
      setState(() => _live = null);
      return;
    }
    // The spring runs 0→1 along the path; the fling's speed along that
    // path becomes its starting velocity, in path-lengths per second.
    final along = (_to - _from) / distance;
    final speed = (v.dx * along.dx + v.dy * along.dy) / distance;
    _settle
        .animateWith(
          SpringSimulation(
            const SpringDescription(mass: 1, stiffness: 300, damping: 26),
            0,
            1,
            speed,
          ),
        )
        .then((_) {
      if (mounted) setState(() => _live = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final area = box.biggest;
        final at = _live ?? _cornerOrigin(area, _corner);
        return Stack(
          children: [
            Positioned(
              left: at.dx,
              top: at.dy,
              width: widget.size.width,
              height: widget.size.height,
              child: GestureDetector(
                onPanStart: (_) {
                  _settle.stop();
                  _live ??= _cornerOrigin(area, _corner);
                },
                onPanUpdate: (d) =>
                    setState(() => _live = (_live ?? at) + d.delta),
                onPanEnd: (d) => _onEnd(area, d),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small captions over a call — the group bar's title line and timer, a
/// tile's name tag: the system face at 13, never the theme's mono slot.
TextStyle callCaptionStyle(AppTheme theme) => theme.body.copyWith(
      fontSize: 13,
      height: 1.2,
      letterSpacing: -0.1,
      color: Colors.white70,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// The line under a caller's name — "Ringing…", the call timer. The body
/// face at 17 in soft white, FaceTime's subtitle; tabular figures so the
/// timer's digits do not jitter as they tick.
TextStyle callStatusStyle(AppTheme theme) => theme.body.copyWith(
      fontSize: 17,
      height: 1.2,
      letterSpacing: -0.2,
      color: Colors.white.withValues(alpha: 0.72),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Fades (and optionally slides) an overlay region for the call screen's
/// tap-to-hide-controls gesture. [IgnorePointer] while hidden so faded-out
/// chrome can't be tapped through mid-animation or while fully hidden.
class ControlsFade extends StatelessWidget {
  const ControlsFade({
    super.key,
    required this.visible,
    required this.child,
    this.slide,
  });

  final bool visible;
  final Widget child;

  /// Fractional offset (of the child's own size) to slide toward when
  /// hidden — e.g. (0, -0.3) drifts upward as it fades out.
  final Offset? slide;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    Widget result = AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: _duration,
      curve: _curve,
      child: child,
    );
    if (slide != null) {
      result = AnimatedSlide(
        offset: visible ? Offset.zero : slide!,
        duration: _duration,
        curve: _curve,
        child: result,
      );
    }
    return IgnorePointer(ignoring: !visible, child: result);
  }
}

class AudioBackdrop extends StatefulWidget {
  const AudioBackdrop({
    super.key,
    required this.name,
    required this.status,
    required this.theme,
    required this.user,
    this.api,
    this.peerMuted = false,
    this.bottomInset = 0,
  });
  final String name;
  final Widget status;
  final bool peerMuted;

  /// What the tray covers at the bottom of the screen, so the avatar and
  /// name centre in the space above it rather than under it.
  final double bottomInset;
  final dynamic theme;
  final ChatUser user;
  final ChatApi? api;

  @override
  State<AudioBackdrop> createState() => AudioBackdropState();
}

class AudioBackdropState extends State<AudioBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = theme.accent as Color;
    return CallBackdrop(
      accent: accent,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.bottomInset),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar + concentric pulse rings.
                // Springs in once when the call screen opens.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.82, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: PulseRings(
                  accent: accent,
                  diameter: 132,
                  reach: 128,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.38),
                          blurRadius: 48,
                        ),
                      ],
                    ),
                    // Real avatar photo when available; per-user gradient +
                    // initial otherwise (UserAvatar handles both).
                    child: UserAvatar(
                      user: widget.user,
                      api: widget.api,
                      size: 132,
                      showStatus: false,
                    ),
                  ),
                  ),
                ),
                const SizedBox(height: 28),
                // FaceTime's name: big, centred, the one thing on screen
                // that is not the person's face.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.name,
                    style: theme.displayLarge.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.peerMuted) ...[
                      const Icon(Icons.mic_off, size: 14, color: Colors.white70),
                      const SizedBox(width: 8),
                    ],
                    widget.status,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.active = false,
    this.background,
    this.iconColor,
    this.large = false,
    this.enabled = true,
    this.diameter,
    this.subdued = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool active;
  final Color? background;
  final Color? iconColor;
  final bool large;
  final bool enabled;

  /// Pin the circle to exactly this size instead of sizing it from the
  /// slot. [CallTray] sets it, so every control in the tray is the same
  /// size whatever its label needs.
  final double? diameter;

  /// A quieter surface for a control on the tray's second row.
  final bool subdued;

  /// The hero ends the call and lands like it; the tray's toggles tick like
  /// switches. A disabled control never gets here — it builds no tap target.
  void _tap() {
    if (large) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    // Sized from whatever width the Row's Expanded slot actually gives us —
    // never exceeding today's diameter, never shrinking below a usable
    // floor — so a narrow phone or a large accessibility text scale can
    // never overflow the tray (see call_screen control-row layout).
    return LayoutBuilder(
      builder: (context, constraints) {
        // The end-call button (large: true) now sits alone on its own row
        // (see the control-bar layout in call_screen's build()), so it gets
        // a bigger ceiling/floor than the toolbar row's shared-width toggles.
        final maxDiameter = diameter ?? (large ? 72.0 : 56.0);
        final minDiameter = diameter ?? (large ? 56.0 : 40.0);
        final size = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(minDiameter, maxDiameter).toDouble()
            : maxDiameter;
        final iconSize = size * (large ? 32 / 72 : 24 / 56);
        final labelScaler = MediaQuery.textScalerOf(
          context,
        ).clamp(maxScaleFactor: 1.3);
        if (!enabled) {
          // Unavailable control (e.g. flip while the camera is off):
          // dimmed and non-tappable.
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.30),
                  size: iconSize,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textScaler: labelScaler,
                style: _labelStyle.copyWith(
                  color: Colors.white.withValues(alpha: 0.30),
                ),
              ),
            ],
          );
        }
        final bg =
            background ??
            (active
                ? Colors.white.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: subdued ? 0.12 : 0.18));
        final fg = iconColor ?? (active ? Colors.black : Colors.white);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FocusableTap(
              onTap: _tap,
              semanticLabel: label,
              shape: FocusRingShape.circle,
              // FocusableTap adds keyboard focus/activation only — the
              // child GestureDetector is what makes this tappable.
              child: GestureDetector(
                onTap: _tap,
                child: SpringPress.passive(
                  scale: 0.9,
                  // Size pinned outside, colour animated inside: an
                  // AnimatedContainer given the size too would tween it
                  // whenever the slot changed, and the tray's own height
                  // estimate would stop matching what it draws.
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: AnimatedContainer(
                    // A toggle flipping on fills white over a beat rather
                    // than snapping, the FaceTime mute button.
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                      // Only the standalone hero button (end call) needs to
                      // read as floating above the video — the toolbar row's
                      // buttons already sit inside their own glass tray. A
                      // centred glow, not a dropped shadow: offset, it read
                      // as a hard lip under the button.
                      boxShadow: large
                          ? [
                              BoxShadow(
                                color: bg.withValues(alpha: 0.40),
                                blurRadius: 24,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(icon, color: fg, size: iconSize),
                  ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textScaler: labelScaler,
              style: _labelStyle,
            ),
          ],
        );
      },
    );
  }

  /// The caption under a control: the platform face (SF on iOS) at 11 —
  /// no explicit family, whose line metrics would outgrow the slot the tray
  /// measures for. Not larger and not
  /// heavier — the tray's slots are sized for this line, and at 12pt medium
  /// "Speaker" no longer fits a compact slot (call_tray_layout_test).
  static const _labelStyle = TextStyle(
    color: Color(0xD9FFFFFF),
    fontSize: 11,
  );
}


/// Small centered pill shown over the call view during a transient state —
/// device-switch renegotiation, ICE-restart recovery, or a degraded
/// connection. Subtle by design; the call audio/video continues behind it.
class OverlayChip extends StatelessWidget {
  const OverlayChip({
    super.key,
    required this.label,
    this.spinner = true,
    this.tint,
  });
  final String label;
  final bool spinner;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final fg = tint ?? Colors.white;
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: fg.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              CupertinoActivityIndicator(radius: 7, color: fg),
              const SizedBox(width: 10),
            ] else ...[
              Icon(Icons.network_check, size: 14, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: theme.caption.copyWith(
                fontFamily: 'CupertinoSystemText',
                fontSize: 13,
                color: fg,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed live numeric readout — opt-in replacement for [OverlayChip]'s
/// plain "poor/weak connection" label, driven by the same
/// [CallQualitySnapshot] the chip already reads. Shown whenever
/// [SettingsStore.showNetworkStats] is on, at every quality tier, not just
/// when degraded.
class NetworkStatsPanel extends StatelessWidget {
  const NetworkStatsPanel({super.key, required this.snapshot});
  final CallQualitySnapshot snapshot;

  String _fmtKbps(double? v) => v == null ? '—' : '${v.round()} kbps';
  String _fmtMs(double? v) => v == null ? '—' : '${v.round()} ms';

  IconData _qualityIcon(CallQuality q) => switch (q) {
    CallQuality.good => Icons.signal_cellular_alt,
    CallQuality.fair => Icons.signal_cellular_alt_2_bar,
    CallQuality.poor => Icons.signal_cellular_alt_1_bar,
  };

  Widget _metric(TextStyle style, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Text(text, style: style.copyWith(color: color.withValues(alpha: 0.95))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final q = snapshot;
    final res = (q.frameWidth != null && q.frameHeight != null)
        ? '${q.frameWidth}×${q.frameHeight}'
              '${q.fps != null ? '@${q.fps!.round()}' : ''}'
        : null;
    final tint = switch (q.quality) {
      CallQuality.poor => const Color(0xFFFF6B6B),
      CallQuality.fair => const Color(0xFFFFB74D),
      CallQuality.good => Colors.white,
    };
    final style = theme.monoTiny;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(color: tint.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                // Resolution leads — it's what a user actually notices when
                // they wonder "why does the video look bad," so it shouldn't
                // read as an afterthought next to the more technical
                // quality/path metric.
                if (res != null)
                  _metric(style, Icons.aspect_ratio, res, Colors.white),
                _metric(
                  style,
                  _qualityIcon(q.quality),
                  q.candidateType ?? '—',
                  tint,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _metric(
                  style,
                  Icons.arrow_downward_rounded,
                  _fmtKbps(q.inKbps),
                  Colors.white,
                ),
                _metric(
                  style,
                  Icons.arrow_upward_rounded,
                  _fmtKbps(q.outKbps),
                  Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _metric(
                  style,
                  Icons.timer_outlined,
                  '${l10n.callScreenStatsRttLabel} ${_fmtMs(q.rttMs)}',
                  Colors.white,
                ),
                if (q.jitterMs != null)
                  _metric(
                    style,
                    Icons.graphic_eq,
                    '${l10n.callScreenStatsJitterLabel} ${_fmtMs(q.jitterMs)}',
                    Colors.white,
                  ),
                if (q.lossPercent != null)
                  _metric(
                    style,
                    Icons.error_outline,
                    '${l10n.callScreenStatsLossLabel} '
                    '${q.lossPercent!.toStringAsFixed(1)}%',
                    Colors.white,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Self-ticking call-duration label. Owning the 1 Hz timer here confines the
/// per-second rebuild to this one Text widget.
class ElapsedLabel extends StatefulWidget {
  const ElapsedLabel({super.key, required this.start, required this.style});
  final DateTime start;
  final TextStyle style;

  @override
  State<ElapsedLabel> createState() => ElapsedLabelState();
}

class ElapsedLabelState extends State<ElapsedLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.start);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final label = d.inHours > 0 ? '${d.inHours}:$mm:$ss' : '$mm:$ss';
    return Text(label, style: widget.style);
  }
}
