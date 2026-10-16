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
/// None lights up with an accent fill. Each is a drawn glyph that MORPHS
/// between its states (the ring's dashes close and flood, the eye shuts
/// under dust, a badge traces itself round HD, the pencil lifts and draws),
/// kicks once as it turns on, ticks a haptic at each beat, and the first
/// time view once or spoiler is turned on it says what that does.
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

/// The knocked-out "1" in a flooded view-once ring: the media glass's own
/// dark, so it reads as a hole through the flood.
const Color _kGlassHole = Color(0xFF2C2C30);

/// One send switch's glyph, carrying its own state.
///
/// [on] drives a 0..1 morph (a spring with a pop for view once, an ease for
/// the rest), a one-off [_kick] runs as it turns on, and the ink lerps from
/// dim to full white with it. With [tip], the first time ever it turns on
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
  late final AnimationController _kick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
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
    if (_calm) {
      _state.value = target;
    } else if (widget.on) {
      // View once pops past full, as the recorder's ring does.
      final ratio = widget.kind == SendSwitch.viewOnce ? 0.5 : 0.85;
      _state.animateWith(SpringSimulation(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: math.pow(2 * math.pi / 0.3, 2).toDouble(),
          ratio: ratio,
        ),
        _state.value,
        target,
        0,
      ));
      _kick.forward(from: 0);
    } else {
      _state.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
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
      SendSwitch.viewOnce => ViewOnceGlyph(
          color: ink,
          knockout: _kGlassHole,
          on: t,
          size: size,
        ),
      SendSwitch.spoiler =>
        SpoilerGlyph(color: ink, on: t, burst: kick, size: size),
      SendSwitch.hd => HdGlyph(color: ink, on: t, kick: kick, size: size),
      SendSwitch.pen => PenGlyph(color: ink, on: t, size: size),
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
          return _glyph(t, _kick.value, ink);
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
