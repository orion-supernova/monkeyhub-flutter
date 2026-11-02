import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/media_send_options.dart';
import 'capture_glyphs.dart';
import 'glass_buttons.dart';
import 'glyph_tip.dart';
import 'liquid_glass.dart' show MediaGlass;

/// The switches every picture send offers, as one shared set: the pen (a
/// tool, offered where the screen can draw), view once, spoiler and HD.
///
/// One builder for every preview a picture is sent from, so the camera's
/// composer and the gallery's preview cannot drift apart again: they read
/// and write the same [MediaSendOptions] through the same glyphs.
///
/// None lights up with an accent fill. One rule for all four: off is an
/// outline, on is solid with its mark cut clean through (a real hole, so the
/// photo shows through it), the SF Symbols `.fill` idiom. Each MORPHS
/// between the two (the pencil fills and lifts to scribble, the ring's dashes
/// twist shut like an aperture and flood, the eye shuts under dust and
/// sparkles, a badge traces round HD and floods), kicks once as it turns on
/// (a wiggle, a pop, a twinkle, a swell), ticks a haptic at each beat, and
/// the first time view once or spoiler is turned on it says what that does.
List<GlassGroupItem> mediaSendSwitchItems(
  BuildContext context, {
  required MediaSendOptions options,
  bool enabled = true,
  bool viewOnce = true,
  bool spoiler = true,
  bool hd = true,

  /// Offers the pen, with its state and its toggle. Null leaves it out.
  bool? penArmed,
  VoidCallback? onPen,

  /// After view once flipped, for the screen's own follow-up (the caption
  /// field turns off under it).
  ValueChanged<bool>? onViewOnce,
}) {
  final l10n = AppLocalizations.of(context);
  VoidCallback? flip(bool on, void Function(bool) set) => !enabled
      ? null
      : () {
          // A firmer tick turning on than off: arming is the beat.
          if (on) {
            HapticFeedback.lightImpact();
          } else {
            HapticFeedback.selectionClick();
          }
          set(!on);
        };
  final pen = penArmed;
  return [
    if (pen != null)
      GlassGroupItem(
        glyph: SendSwitchGlyph(kind: SendSwitch.pen, on: pen),
        semanticLabel: pen
            ? l10n.cameraEditorScreenPenPutAwaySemanticLabel
            : l10n.cameraEditorScreenPenDrawSemanticLabel,
        onTap: enabled ? onPen : null,
      ),
    if (viewOnce)
      GlassGroupItem(
        glyph: SendSwitchGlyph(
          kind: SendSwitch.viewOnce,
          on: options.viewOnce,
          tip: l10n.mediaSendViewOnceTip,
        ),
        semanticLabel: options.viewOnce
            ? l10n.cameraEditorScreenViewOnceOnSemanticLabel
            : l10n.cameraEditorScreenViewOnceOffSemanticLabel,
        onTap: flip(options.viewOnce, (v) {
          options.viewOnce = v;
          onViewOnce?.call(v);
        }),
      ),
    if (spoiler)
      GlassGroupItem(
        glyph: SendSwitchGlyph(
          kind: SendSwitch.spoiler,
          on: options.spoiler,
          tip: l10n.mediaSendSpoilerTip,
        ),
        semanticLabel: options.spoiler
            ? l10n.mediaSendSpoilerOnSemanticLabel
            : l10n.mediaSendSpoilerOffSemanticLabel,
        onTap: flip(options.spoiler, (v) => options.spoiler = v),
      ),
    if (hd)
      GlassGroupItem(
        glyph: SendSwitchGlyph(kind: SendSwitch.hd, on: options.hd),
        semanticLabel: options.hd
            ? l10n.cameraEditorScreenHdOnSemanticLabel
            : l10n.cameraEditorScreenHdOffSemanticLabel,
        onTap: flip(options.hd, (v) => options.hd = v),
      ),
  ];
}

enum SendSwitch { pen, viewOnce, spoiler, hd }

/// How long a switch takes to turn on ([on]) and how long its kick runs
/// ([kick]): longer the more steps its glyph has to show. HD traces a frame,
/// floods it and cuts its letters through; the pencil only fills and lifts.
class _SwitchPace {
  const _SwitchPace(this.on, this.kick);
  final Duration on;
  final Duration kick;

  static _SwitchPace of(SendSwitch kind) => switch (kind) {
        SendSwitch.pen => const _SwitchPace(
            Duration(milliseconds: 560), Duration(milliseconds: 800)),
        SendSwitch.viewOnce => const _SwitchPace(
            Duration(milliseconds: 600), Duration(milliseconds: 700)),
        SendSwitch.spoiler => const _SwitchPace(
            Duration(milliseconds: 640), Duration(milliseconds: 1000)),
        SendSwitch.hd => const _SwitchPace(
            Duration(milliseconds: 760), Duration(milliseconds: 1040)),
      };
}

/// One send switch's glyph, carrying its own state.
///
/// [on] drives a 0..1 morph (a spring with a pop for view once, a timed
/// ease for the rest, as long as each has steps to show: see [_SwitchPace]),
/// a one-off [_kick] runs with it, and the ink lerps from dim to full white
/// with it. With [tip], the first time ever it turns on
/// (per switch, remembered in [SettingsStore.tipSeen]) a [TipBubble] pops
/// out of it. Reduce Motion snaps, no kick, a still tip.
class SendSwitchGlyph extends StatefulWidget {
  const SendSwitchGlyph({
    super.key,
    required this.kind,
    required this.on,
    this.tip,
    this.size = 24,
  });

  final SendSwitch kind;
  final bool on;
  final String? tip;
  final double size;

  @override
  State<SendSwitchGlyph> createState() => _SendSwitchGlyphState();
}

class _SendSwitchGlyphState extends State<SendSwitchGlyph>
    with TickerProviderStateMixin {
  late final AnimationController _state = AnimationController.unbounded(
    vsync: this,
    value: widget.on ? 1 : 0,
  );
  /// The one-off beat on a flip: a hop and the glyph's own move turning
  /// on, a small dip turning off. Runs as long as the morph and a little
  /// past it, so a glyph's own beat (HD's swell, the sparkles' twinkle)
  /// lands as its morph does rather than halfway through it.
  late final AnimationController _kick = AnimationController(
    vsync: this,
    duration: _SwitchPace.of(widget.kind).kick,
  );

  /// Which way the last flip went, for the beat's shape.
  bool _kickOn = true;
  int _tipTrigger = 0;
  bool _calm = false;

  String get _tipId => 'sendSwitch.${widget.kind.name}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(SendSwitchGlyph old) {
    super.didUpdateWidget(old);
    if (old.on == widget.on) return;
    final target = widget.on ? 1.0 : 0.0;
    final pace = _SwitchPace.of(widget.kind);
    if (_calm) {
      _state.value = target;
    } else if (widget.on) {
      if (widget.kind == SendSwitch.viewOnce) {
        // View once pops past full, as the recorder's ring does.
        _state.animateWith(SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: math.pow(2 * math.pi / 0.6, 2).toDouble(),
            ratio: 0.5,
          ),
          _state.value,
          target,
          0,
        ));
      } else {
        // The rest run their steps in order on a clock: a spring rushed
        // HD's trace, flood and cut into a quarter of a second.
        _state.animateTo(target, duration: pace.on, curve: Curves.easeInOut);
      }
      _kickOn = true;
      _kick
        ..duration = pace.kick
        ..forward(from: 0);
    } else {
      _state.animateTo(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
      _kickOn = false;
      _kick
        ..duration = const Duration(milliseconds: 460)
        ..forward(from: 0);
    }
    if (widget.on && widget.tip != null) _maybeTip();
  }

  void _maybeTip() {
    final store = SettingsStore.instance;
    if (store.tipSeen(_tipId)) return;
    store.markTipSeen(_tipId).catchError((Object _) {});
    // Called from didUpdateWidget, so the build that follows carries it.
    _tipTrigger++;
  }

  @override
  void dispose() {
    _state.dispose();
    _kick.dispose();
    super.dispose();
  }

  Widget _glyph(double t, double kick, Color ink) {
    final size = widget.size;
    return switch (widget.kind) {
      SendSwitch.viewOnce => ViewOnceGlyph(color: ink, on: t, size: size),
      SendSwitch.spoiler =>
        SpoilerGlyph(color: ink, on: t, burst: kick, size: size),
      SendSwitch.hd => HdGlyph(color: ink, on: t, kick: kick, size: size),
      SendSwitch.pen => PenGlyph(color: ink, on: t, kick: kick, size: size),
    };
  }

  /// The tip's living mark: the flame for once, the shutting eye's dust
  /// for a spoiler, puffing on a slow beat.
  Widget _tipGlyph(double clock, double age) => switch (widget.kind) {
        SendSwitch.viewOnce => FlameGlyph(
            color: const Color(0xFFFFFFFF),
            core: TipBubble.background,
            flicker: clock / 0.7,
            ignite: TipBubble.igniteOf(age),
            size: 30,
          ),
        _ => SpoilerGlyph(
            color: const Color(0xFFFFFFFF),
            on: TipBubble.igniteOf(age),
            burst: (clock / 1.1) % 1.0,
            size: 30,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final glyph = RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_state, _kick]),
        builder: (context, _) {
          final t = _state.value;
          final ink = Color.lerp(
            MediaGlass.inkDim,
            MediaGlass.ink,
            t.clamp(0.0, 1.0),
          )!;
          final k = _kick.value;
          // The hop is its own short beat at the start of the kick, however
          // long the glyph's own move runs.
          final ms = k * _kick.duration!.inMilliseconds;
          final hop = (ms / 460).clamp(0.0, 1.0);
          final beat = k <= 0 || hop >= 1
              ? 0.0
              : math.sin(math.pi * Curves.easeOut.transform(hop));
          // Turning on, the glyph hops up and swells; turning off it ducks.
          return Transform.translate(
            offset: Offset(0, _kickOn ? -2.5 * beat : 0),
            child: Transform.scale(
              scale: 1 + (_kickOn ? 0.2 : -0.12) * beat,
              child: _glyph(t, _kickOn ? k : 0, ink),
            ),
          );
        },
      ),
    );
    final tip = widget.tip;
    if (tip == null) return glyph;
    return GlyphTipAnchor(
      text: tip,
      trigger: _tipTrigger,
      glyph: _tipGlyph,
      child: glyph,
    );
  }
}
