import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/spoiler_store.dart';
import '../l10n/generated/app_localizations.dart';
import 'dust/dust_kit.dart';
import 'dust/rub_field.dart';
import 'dust/spoiler_dust.dart';
import 'spoiler_veil.dart'
    show
        VeilModel,
        kSpoilerGather,
        kSpoilerHeal,
        kSpoilerHoldBaseMs,
        kSpoilerHoldMaxMs,
        kSpoilerRevealIn;
import 'still_blur.dart';

/// How long the wavefront takes to open a spoiler picture. A little longer
/// than a line of text's (`kSpoilerRevealIn`), for a disc that has a whole
/// photograph to cross.
const Duration kMediaSpoilerReveal = Duration(milliseconds: 560);

/// Grains per square point over a sealed picture: a shade denser than the
/// ambient fields elsewhere ([SpoilerDust.defaultDensity]), so a whole photo
/// reads as the same haze a line of hidden text does rather than a scatter.
const double kMediaSpoilerDensity = 1 / 6;

/// How long a picture stays open after a full reveal before the dust comes
/// back over it: the text spoiler's hold, which grows with what it hides up
/// to [kSpoilerHoldMaxMs]. Any picture hides more than that line's worth.
const Duration kMediaSpoilerHold = Duration(milliseconds: kSpoilerHoldMaxMs);

/// The most grains one picture carries. A tall photo is 80k pt²; the field's
/// usual cap (a video note's) left it at one grain per 25pt², which on the
/// device read as sparse specks over a blur.
const int kMediaSpoilerMaxGrains = 7000;

/// A photo or video sent as a spoiler, and its reveal.
///
/// Sealed, the picture is blurred (its colours still there, nothing to make
/// out), dimmed a shade, and the text spoiler's living dust ([SpoilerDust],
/// the same grains on the same current) drifts over it: Telegram's "hidden,
/// but there". A tap opens it the way a text spoiler opens: a wavefront from
/// the touch point, the sharp picture inside an expanding disc while the dust
/// ahead of its edge is blown clear and the rest of it settles out.
///
/// Like a line of text it does not stay open: after [kMediaSpoilerHold] the
/// dust gathers back over it exactly as a line of text's does, arriving on a
/// wind front with the blur returning behind it. While it is open it is remembered
/// in [SpoilerStore] (under its own key, so a spoiler caption on the same
/// message keeps its own veil), so a row scrolled away and back is still
/// open and its hold starts again. With no [revealKey] (the fullscreen
/// viewer) it stays open for as long as it is showing.
///
/// While sealed the cover takes the tap, so the first tap reveals and only
/// the next opens the viewer; a long press still reaches the bubble. With
/// [interactive] false (a thumbnail: a reply's quote, a shared-media tile, a
/// pick waiting to be sent) it is only the look, and never opens.
///
/// The blur is an [ImageFiltered] over the picture itself, never a
/// `BackdropFilter`, and it never animates: the wavefront is a clip of the
/// sharp picture over the still blur.
class MediaSpoilerCover extends StatefulWidget {
  const MediaSpoilerCover({
    super.key,
    required this.child,
    this.sealed = true,
    this.revealKey,
    this.interactive = true,
    this.borderRadius = BorderRadius.zero,
    this.sigma = 20,
    this.dustDensity = kMediaSpoilerDensity,
    this.dust = true,
    this.resealOnDispose = false,
    this.onRevealed,
  });

  /// The picture. Laid out by its own size; the cover sizes to it.
  final Widget child;

  /// False shows [child] as it is: the same tree, so flipping it neither
  /// remounts the picture nor drops its decode.
  final bool sealed;

  /// What [SpoilerStore] remembers the reveal under: the message id. Null
  /// reveals for as long as this widget lives.
  final String? revealKey;
  final bool interactive;
  final BorderRadius borderRadius;

  /// The blur's strength. A thumbnail wants less to read as the same blur.
  final double sigma;
  final double dustDensity;

  /// False keeps the blur and the shade and leaves the dust out: for a
  /// thumbnail too small for grains to read (a reply's 18pt quote).
  final bool dust;

  /// Leaving this widget (the gallery page closing) seals the picture in
  /// [SpoilerStore] again, so coming back finds the dust over it instead of
  /// an open picture on a fresh hold. A bubble leaves this off: a row
  /// scrolled away and back is meant to still be open.
  final bool resealOnDispose;
  final VoidCallback? onRevealed;

  /// The store key for [messageId]'s picture.
  static String storeKey(String messageId) => 'media:$messageId';

  @override
  State<MediaSpoilerCover> createState() => _MediaSpoilerCoverState();
}

class _MediaSpoilerCoverState extends State<MediaSpoilerCover>
    with TickerProviderStateMixin {
  /// The tap's reveal: the text spoiler's wavefront, at its pace.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: kSpoilerRevealIn,
  )..addStatusListener(_onWave);

  /// The cover coming back after a full reveal: the text spoiler's gather.
  late final AnimationController _gather = AnimationController(
    vsync: this,
    duration: kSpoilerGather,
  )..addStatusListener(_onGather);
  bool _gathering = false;
  Offset _wind = const Offset(1, 0);
  double _pMin = 0;
  double _pMax = 0;

  /// The wavefront's radius last tick, so its sweep can throw what it
  /// passed over.
  double _swept = 0;

  /// Crumbles a partial rub shut, as a text spoiler's wipe does.
  late final AnimationController _heal = AnimationController(
    vsync: this,
    duration: kSpoilerHeal,
  )..addStatusListener(_onHeal);

  /// Where the tap landed, in the cover's own box.
  Offset? _origin;
  late bool _open = _stored;

  /// The rub's holes; made on the first rub, dropped once the picture is open.
  _RubMask? _rub;

  /// Bumped whenever the holes change, so the masks repaint without a build.
  final ValueNotifier<int> _rubRevision = ValueNotifier(0);

  /// The text spoiler's living part, over a picture: dust boiling off the
  /// rim of the rub for as long as the finger is down, and the dust that
  /// blows back in when it heals. Made with the rub, stepped only while it
  /// has something to move.
  RubField? _field;
  Ticker? _fieldTicker;
  Duration? _lastFieldTick;
  double _fieldTime = 0;
  final ValueNotifier<int> _fieldFrame = ValueNotifier(0);

  /// The fingertip while it rubs: the dust's draught.
  final ValueNotifier<Offset?> _touch = ValueNotifier(null);

  Offset? _lastRub;
  Timer? _healTimer;

  /// Arms the re-cover after a full reveal.
  Timer? _recoverTimer;
  bool _calm = false;

  bool get _stored {
    final key = widget.revealKey;
    return key != null &&
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey(key));
  }

  @override
  void initState() {
    super.initState();
    // Mounting onto a picture left open (a row recycled while it showed):
    // pick it up, and start its hold again so it can never stay open.
    if (_open) _scheduleRecover();
  }

  @override
  void didUpdateWidget(MediaSpoilerCover old) {
    super.didUpdateWidget(old);
    if (old.revealKey != widget.revealKey) {
      _wave.reset();
      _origin = null;
      _open = _stored;
      _dropRub();
      _recoverTimer?.cancel();
      if (_open) _scheduleRecover();
    }
  }

  /// After the hold, the dust comes back over the whole picture.
  void _scheduleRecover() {
    _recoverTimer?.cancel();
    if (widget.revealKey == null) return;
    _recoverTimer = Timer(kMediaSpoilerHold, _recover);
  }

  void _recover() {
    if (!mounted || !_open) return;
    final box = context.findRenderObject() as RenderBox?;
    if (_calm || box == null || !box.hasSize || !widget.dust) {
      _conceal();
      setState(() => _open = false);
      return;
    }
    // The text spoiler's gather, over a picture: a wind, mostly sideways
    // with a tilt, and a front crossing the whole picture behind which the
    // blur is back; the dust arrives on it from upwind, each grain just
    // before the front reaches where it settles.
    final size = box.size;
    final rand = math.Random(_fieldTime.hashCode ^ size.hashCode ^ 0x5EA1);
    final tilt = (rand.nextDouble() - 0.5) * (math.pi / 3);
    final sign = rand.nextBool() ? 1.0 : -1.0;
    _wind = Offset(math.cos(tilt) * sign, math.sin(tilt));
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final c in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      final p = c.dx * _wind.dx + c.dy * _wind.dy;
      lo = math.min(lo, p);
      hi = math.max(hi, p);
    }
    _pMin = lo;
    _pMax = hi;
    // The arriving dust at about half the cover's own density, the rest of
    // it coming in under the front; a field of its own, sized for it.
    final n = math.min(
      5000,
      (size.width * size.height * kMediaSpoilerDensity * 0.5).round(),
    );
    final field = RubField(
      Offset.zero & size,
      MediaQuery.devicePixelRatioOf(context),
      grains: n + 64,
    );
    field.prepareGather(
      rand,
      wind: _wind,
      pMin: _pMin,
      pad: _gatherPad,
      span: _gatherSpan,
      n: field.capacity - 64,
    );
    setState(() {
      _open = false;
      _origin = null;
      _wave.reset();
      _rub?.dispose();
      _rub = null;
      _field = field;
      _gathering = true;
    });
    _ensureField();
    _gather.forward(from: 0);
  }

  static const double _gatherPad = VeilModel.frontBand + VeilModel.frontJitter;
  double get _gatherSpan => _pMax - _pMin + 2 * _gatherPad;

  /// The gather's front along [_wind] at [t] in 0..1, as the text's.
  double _gatherFront(double t) => (_pMin - _gatherPad) + t * _gatherSpan;

  void _onGather(AnimationStatus s) {
    if (s != AnimationStatus.completed || !mounted) return;
    _field?.endHeal();
    _conceal();
    setState(() {
      _gathering = false;
      _gather.value = 0;
    });
  }

  void _conceal() {
    final key = widget.revealKey;
    if (key != null) {
      SpoilerStore.instance.conceal(MediaSpoilerCover.storeKey(key));
    }
  }

  /// The wavefront's radius at [t]: the text's, eased out to past the far
  /// corner.
  double _waveRadius(double t, Size size) {
    final o = _origin;
    if (o == null || t <= 0) return 0;
    var far = 0.0;
    for (final c in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      far = math.max(far, (c - o).distance);
    }
    return Curves.easeOutCubic.transform(t) * (far + VeilModel.waveOvershoot);
  }

  RubField _newField(Size size) => RubField(
        Offset.zero & size,
        MediaQuery.devicePixelRatioOf(context),
        // Off the hole's own ragged edge, spread across the noise's swing,
        // not on a ring round the fingertip: a ring is the finger's shape,
        // and a fast stroke dragged it about as a circle.
        rimMin: 0.45,
        rimSpan: 1.1,
        discShare: 0.9,
      );

  @override
  void dispose() {
    if (widget.resealOnDispose && _open) _conceal();
    _healTimer?.cancel();
    _recoverTimer?.cancel();
    _fieldTicker?.dispose();
    _wave.dispose();
    _gather.dispose();
    _heal.dispose();
    _rub?.dispose();
    _rubRevision.dispose();
    _fieldFrame.dispose();
    _touch.dispose();
    super.dispose();
  }

  void _onWave(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() {
        _open = true;
        _dropRub();
      });
      _scheduleRecover();
    }
  }

  void _onHeal(AnimationStatus s) {
    if (s != AnimationStatus.completed || !mounted) return;
    // The holes are shut. The field outlives them: the grains the heal blew
    // in are still settling and fade on their own lives, as the text's do,
    // rather than all vanishing on the last frame of the front.
    final field = _field;
    final rub = _rub;
    if (field != null && rub != null) field.endHeal();
    setState(() {
      _healTimer?.cancel();
      _heal
        ..value = 0
        ..duration = kSpoilerHeal;
      _rub?.dispose();
      _rub = null;
      _lastRub = null;
    });
  }

  void _dropRub() {
    _healTimer?.cancel();
    _heal.value = 0;
    _rub?.dispose();
    _rub = null;
    _field = null;
    _fieldTicker?.stop();
    _lastFieldTick = null;
    _lastRub = null;
    _touch.value = null;
  }

  // ---------------------------------------------------------------- field

  void _ensureField() {
    if (_calm || _field == null || !mounted) return;
    final t = _fieldTicker ??= createTicker(_onFieldTick);
    if (!t.isActive) {
      _lastFieldTick = null;
      t.start();
    }
  }

  void _onFieldTick(Duration elapsed) {
    final field = _field;
    final rub = _rub;
    if (field == null) {
      _fieldTicker?.stop();
      return;
    }
    final dt = dustFrameDt(_lastFieldTick, elapsed);
    _lastFieldTick = elapsed;
    _fieldTime += dt;
    // Dust boils off only while a finger is on it and the picture is still
    // being rubbed, not once the wavefront has taken over.
    final emitting =
        rub != null && !_wave.isAnimating && !_open ? _touch.value : null;
    // A held finger keeps opening the hole from where it pressed, as the
    // text's wavefront opens from a tap.
    if (emitting != null && !rub!.healing && rub.grow(dt, emitting)) {
      _rubRevision.value++;
      if (rub.clearedFraction >= _RubMask.enough) _reveal(emitting);
    }
    // The wavefront throws the dust it sweeps over, as the text's does.
    if (_wave.isAnimating && _origin != null) {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final r = _waveRadius(_wave.value, box.size);
        final from = math.max(_swept, r * VeilModel.waveRim);
        if (r > from) {
          final ring = math.pi * (r * r - from * from);
          final n = (ring * kMediaSpoilerDensity * 0.6).round().clamp(0, 600);
          field.burst(_origin!, from, r + 20, n);
        }
        _swept = r;
      }
    }
    field.step(
      dt,
      time: _fieldTime,
      touch: _touch.value,
      emitFrom: emitting,
      rub: _gathering ? _gatherHole : rub,
      heal: _gathering
          ? _gather.value
          : (_heal.isAnimating ? _heal.value : (_heal.value > 0 ? 1 : 0)),
    );
    _fieldFrame.value++;
    if (emitting == null &&
        !_heal.isAnimating &&
        !_wave.isAnimating &&
        !_gather.isAnimating &&
        !field.busy) {
      _fieldTicker?.stop();
      _lastFieldTick = null;
      // Healed and settled: nothing left to move, so nothing left to hold.
      // The next rub makes a fresh field.
      if (_rub == null) setState(() => _field = null);
    }
  }

  void _reveal(Offset at) {
    if (_open || _wave.isAnimating || _gathering) return;
    _healTimer?.cancel();
    if (_heal.isAnimating) _heal.stop();
    HapticFeedback.lightImpact();
    final key = widget.revealKey;
    if (key != null) {
      SpoilerStore.instance.reveal(MediaSpoilerCover.storeKey(key));
    }
    widget.onRevealed?.call();
    if (_calm) {
      setState(() {
        _open = true;
        _dropRub();
      });
      _scheduleRecover();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    setState(() {
      _origin = at;
      if (box != null && box.hasSize && widget.dust) {
        _field ??= _newField(box.size);
      }
    });
    _swept = 0;
    _ensureField();
    _wave.forward(from: 0);
  }

  /// The gather's front, as the field reads it to time each grain's arrival.
  late final RubHole _gatherHole = _GatherHole(this);

  // ------------------------------------------------------------------ rub

  void _rubStart(Offset at, Size size) {
    if (_open || _wave.isAnimating || _gathering) return;
    _healTimer?.cancel();
    // A stroke onto healing holes takes them over rather than fighting the
    // fade.
    if (_heal.isAnimating || _heal.value > 0) {
      _heal
        ..stop()
        ..value = 0;
    }
    final fresh = _rub == null;
    if (fresh) {
      // The first touch of the dust: a tick, as a fingertip finds grit.
      HapticFeedback.selectionClick();
      setState(() {
        _rub = _RubMask(size);
        _field ??= _newField(size);
      });
    } else if (_rub!.healing) {
      // Caught mid-heal: the dust already blown back stays where it landed,
      // the rest of the hole is the finger's again.
      _rub!.endHeal();
      _field?.endHeal();
    }
    _rub!.lift();
    _lastRub = null;
    _rubAt(at);
    _ensureField();
  }

  void _rubAt(Offset point) {
    final rub = _rub;
    if (rub == null || _open || _wave.isAnimating) return;
    _touch.value = point;
    final last = _lastRub;
    // Between move events, so a fast swipe leaves a stroke, not a dotted
    // line of brush stamps.
    if (last != null && (point - last).distance > _RubMask.step) {
      final steps = ((point - last).distance / _RubMask.step).ceil();
      for (var i = 1; i <= steps; i++) {
        rub.stamp(Offset.lerp(last, point, i / steps)!);
      }
    } else {
      rub.stamp(point);
    }
    _lastRub = point;
    _rubRevision.value++;
    // Most of it rubbed away: the rest goes in one breath, from the finger.
    if (rub.clearedFraction >= _RubMask.enough) _reveal(point);
  }

  void _rubEnd() {
    _lastRub = null;
    _touch.value = null;
    if (_open || _wave.isAnimating || _rub == null) return;
    // A glimpse, as a text spoiler's wipe is: the holes stay a moment, then
    // the dust settles back over them.
    _healTimer?.cancel();
    _healTimer = Timer(const Duration(milliseconds: kSpoilerHoldBaseMs), () {
      final rub = _rub;
      if (!mounted || rub == null || _open || _wave.isAnimating) return;
      // The text spoiler's heal: a wind picks a side, the hole closes behind
      // a soft front crossing it, and the dust that was blown away arrives
      // on that front, each grain as the front reaches where it settles.
      final rand = math.Random(_fieldTime.hashCode ^ rub.hashCode);
      rub.beginHeal(rand);
      _field?.prepareHeal(rub, rand, density: kMediaSpoilerDensity);
      _ensureField();
      _heal
        ..duration = kSpoilerHeal
        ..forward(from: 0);
    });
  }

  /// The text spoiler's two fronts as a mask over [b]: opaque where the
  /// sharp picture shows ([keep]) or where the dust does (![keep]).
  ///
  /// Opening: a disc from the tap, clear to [VeilModel.waveRim] of its
  /// radius and soft beyond it. Gathering: covered upwind of the front,
  /// clear downwind, a [VeilModel.frontBand] between.
  Shader _frontShader(Rect b, {required bool keep}) {
    const on = Color(0xFFFFFFFF), off = Color(0x00FFFFFF);
    if (_gathering) {
      final f = _gatherFront(_gather.value);
      return ui.Gradient.linear(
        _wind * (f - VeilModel.frontBand),
        _wind * f,
        keep ? const [off, on] : const [on, off],
      );
    }
    final r = math.max(0.01, _waveRadius(_wave.value, b.size));
    return ui.Gradient.radial(
      _origin ?? b.center,
      r,
      keep ? const [on, on, off] : const [off, off, on],
      const [0, VeilModel.waveRim, 1],
    );
  }

  @override
  Widget build(BuildContext context) {
    _calm = MediaQuery.disableAnimationsOf(context);
    final sealed = widget.sealed && !_open;
    final revealing = sealed && _origin != null;
    final gathering = sealed && _gathering;
    final rub = sealed ? _rub : null;
    final holes = Listenable.merge([_rubRevision, _heal]);
    // One tree whether sealed, opening or open, so the picture is never
    // remounted under the finger that opened it (or by a send that went out
    // plain): only the blur's switch and the overlay change.
    final base = ClipRRect(
      borderRadius: widget.borderRadius,
      clipBehavior: sealed ? Clip.antiAlias : Clip.none,
      // Sealed, the picture's own taps (a video's play) wait for the reveal.
      child: IgnorePointer(
        ignoring: sealed,
        // Blurred once into a still, not every frame the dust moves over it
        // (see [StillBlur]). Mirrored at the edges, so the blur does not fade
        // to a dark rim.
        child: StillBlur(
          enabled: sealed,
          sigma: widget.sigma,
          child: widget.child,
        ),
      ),
    );
    final seed = (widget.revealKey ?? '').hashCode & 0x7fffffff;
    final cover = Stack(
      // Passed through: the picture is sized exactly as it would be bare.
      fit: StackFit.passthrough,
      children: [
        base,
        if (sealed)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A shade down, so the white dust reads over a bright sky.
                  const IgnorePointer(
                    child: ColoredBox(color: Color(0x2E000000)),
                  ),
                  if (rub != null)
                    // The sharp picture, through the holes the finger has
                    // rubbed, feathered at their crumbling rims.
                    IgnorePointer(
                      key: const ValueKey('rubbed'),
                      child: _Holes(
                        rub: rub,
                        heal: _heal,
                        repaint: holes,
                        keep: true,
                        child: widget.child,
                      ),
                    ),
                  if (revealing || gathering)
                    // The sharp picture: inside the text's soft-rimmed disc
                    // as it opens, and downwind of its front as it gathers.
                    IgnorePointer(
                      key: const ValueKey('disc'),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_wave, _gather]),
                        builder: (context, child) => ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (b) => _frontShader(b, keep: true),
                          child: child,
                        ),
                        child: widget.child,
                      ),
                    ),
                  if (widget.dust)
                  IgnorePointer(
                    key: const ValueKey('dust'),
                    // Always the same wrapper, holes or none, so the field is
                    // never remounted by the first rub: with no holes it
                    // paints the dust straight through.
                    child: _Holes(
                      rub: rub,
                      heal: _heal,
                      repaint: holes,
                      keep: false,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_wave, _gather]),
                        builder: (context, dust) => revealing || gathering
                            ? ShaderMask(
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (b) =>
                                    _frontShader(b, keep: false),
                                child: dust,
                              )
                            : dust!,
                        child: SpoilerDust(
                          seed: seed,
                          density: widget.dustDensity,
                          maxGrains: kMediaSpoilerMaxGrains,
                          brightness: 1.35,
                          // The front does the hiding, as the text's does:
                          // the dust is all there until it passes, and back
                          // at once behind a gather.
                          fade: gathering ? Duration.zero : kMediaSpoilerReveal,
                          draught: widget.interactive ? _touch : null,
                        ),
                      ),
                    ),
                  ),
                  if (widget.dust && _field != null)
                    // Over the holes, not cut by them: the rim's dust streams
                    // out across the edge, which is what makes the edge.
                    IgnorePointer(
                      key: const ValueKey('rubField'),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: RubFieldPainter(
                            field: _field!,
                            repaint: _fieldFrame,
                            dpr: MediaQuery.devicePixelRatioOf(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    if (!widget.interactive) return cover;
    return Semantics(
      button: sealed,
      label: sealed
          ? AppLocalizations.of(context).mediaSpoilerRevealSemanticLabel
          : null,
      onTap: sealed ? () => _reveal(Offset.zero) : null,
      child: RawGestureDetector(
          behavior:
              sealed ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
          gestures: {
            if (sealed)
              _CoverTapRecognizer:
                  GestureRecognizerFactoryWithHandlers<_CoverTapRecognizer>(
                _CoverTapRecognizer.new,
                (r) => r.onTapUp = (d) => _reveal(d.localPosition),
              ),
            if (sealed && !_calm)
              _RubRecognizer:
                  GestureRecognizerFactoryWithHandlers<_RubRecognizer>(
                _RubRecognizer.new,
                (r) {
                  r.dragStartBehavior = DragStartBehavior.down;
                  r.onStart = (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null || !box.hasSize) return;
                    _rubStart(d.localPosition, box.size);
                  };
                  r.onUpdate = (d) => _rubAt(d.localPosition);
                  r.onEnd = (_) => _rubEnd();
                  r.onCancel = _rubEnd;
                },
              ),
          },
          child: cover,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The rub
// ---------------------------------------------------------------------------

/// A tap on the dust, with a tight pre-accept slop, so a short rub is handed
/// to [_RubRecognizer] rather than mistaken for a tap that opens the whole
/// picture: the text spoiler's split, for the same reason.
class _CoverTapRecognizer extends TapGestureRecognizer {
  _CoverTapRecognizer() : super(preAcceptSlopTolerance: _RubRecognizer.slop);
}

/// The rub: a sideways drag on the dust, accepted early, then free in two
/// dimensions. Sideways only to begin, exactly as the text spoiler's wipe,
/// so a scroll that starts on a photo is still the list's and a long press is
/// still the bubble's; early, so it wins the tie with the row's
/// swipe-to-reply, which is the same kind of recognizer one level up.
class _RubRecognizer extends HorizontalDragGestureRecognizer {
  _RubRecognizer();

  static const double slop = 6;

  double _dx = 0;
  double _dy = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _dx = 0;
    _dy = 0;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _dx += event.delta.dx;
      _dy += event.delta.dy;
    }
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      _dx.abs() > slop && _dx.abs() > 1.2 * _dy.abs();
}

/// The gather as [RubField] reads it: always healing, on its wind and
/// across its range, with no hole to thin the dust over.
class _GatherHole implements RubHole {
  _GatherHole(this.s);

  final _MediaSpoilerCoverState s;

  @override
  int get discs => 0;
  @override
  double discX(int j) => 0;
  @override
  double discY(int j) => 0;
  @override
  double discR(int j) => 0;
  @override
  double get rimRadius => 0;
  @override
  double clearedAt(double x, double y) => 0;
  @override
  bool get healing => true;
  @override
  Offset get healWind => s._wind;
  @override
  double get healPMin => s._pMin;
  @override
  double get healPadding => _MediaSpoilerCoverState._gatherPad;
  @override
  double get healSpan => s._gatherSpan;
}

/// The holes a finger opens in the dust over a picture.
///
/// Not a brush. A heap of soft discs along the finger's path reads as an
/// eraser dragged through paint, whatever dust is boiling over its rim. This
/// is a field instead, the text spoiler's wavefront in small: every touch
/// point is a seed whose reach grows for as long as the finger stays near it
/// (so a held finger keeps opening, from where it pressed), and the edge is
/// wherever that reach beats a noise threshold. The noise has a soft octave
/// and a grain-sized one, so the boundary wanders and then crumbles grain by
/// grain rather than following the stroke's tube. A heal runs the same field
/// in reverse behind the heal's wind front, so the hole fills back in the
/// same grain-sized steps.
///
/// The reach lives on a coarse grid; [image] reads it per mask pixel and
/// opens each pixel's grain once the reach passes that grain's own need, so
/// the edge is a band of grains, some open, some not. One `drawRawPoints`,
/// cached until the reach or the heal moves.
class _RubMask implements RubHole {
  _RubMask(this.size) {
    // A vertex every few points, coarser only on a very large cover.
    _gap = math.max(_minGap, math.sqrt(size.width * size.height / _maxVerts));
    cols = (size.width / _gap).ceil() + 1;
    rows = (size.height / _gap).ceil() + 1;
    final n = cols * rows;
    _reach = Float32List(n)..fillRange(0, n, -1000);
    _noise = Float32List(n);
    final rand = math.Random(0x5EED);
    final lattice = Float32List(_lat * _lat);
    for (var i = 0; i < lattice.length; i++) {
      lattice[i] = rand.nextDouble();
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final x = c * _gap, y = r * _gap;
        // Two octaves of value noise and a grain of white noise on top: the
        // soft octave bends the edge, the fine one and the grit crumble it.
        final soft = _valueNoise(lattice, x / 15, y / 15);
        final fine = _valueNoise(lattice, x / 5.5 + 17.3, y / 5.5 + 5.1);
        final grit = rand.nextDouble();
        _noise[r * cols + c] = soft * 0.5 + fine * 0.3 + grit * 0.2;
      }
    }
  }

  final Size size;
  late final double _gap;
  late final int cols;
  late final int rows;

  /// How far inside the nearest seed's reach each vertex is, pt; negative
  /// is outside.
  late final Float32List _reach;
  late final Float32List _noise;

  static const double _minGap = 3.5;
  static const double _maxVerts = 16000;
  static const int _lat = 64;

  /// The brush: what a seed grows to, give or take.
  static const double brush = 26;

  /// Interpolation step between move events.
  static const double step = 8;

  /// Rubbed this clear, the rest of the picture opens on its own.
  static const double enough = 0.62;

  /// A new seed every this many points of travel.
  static const double _spacing = 7;

  /// A seed's reach the moment it is pressed, and how quickly it grows to
  /// its own full reach (an exponential approach, s).
  static const double _seedStart = 8;
  static const double _growTau = 0.42;

  /// How far the noise moves the edge, pt.
  static const double _wander = 16;

  /// A seed keeps growing while the finger is within its reach and this.
  static const double _nearby = 18;

  final math.Random _rand = math.Random(0x5EED);
  final List<double> _cx = [], _cy = [], _cr = [], _max = [], _age = [];
  Offset? _last;

  /// A heal in progress: its wind (a unit vector) and the range along it
  /// that the front sweeps, the hole's own, padded so it starts fully open
  /// and ends fully shut.
  @override
  bool healing = false;
  @override
  Offset healWind = const Offset(1, 0);
  @override
  double healPMin = 0;
  double healPMax = 0;

  /// Width of the healing front's band. The text's is 50; a picture's
  /// holes are a thumb or two wide, so a little wider.
  static const double healBand = 64;
  static const double healPad = healBand + 6;
  @override
  double get healSpan => healPMax - healPMin + 2 * healPad;

  /// The front's position along [healWind] at [t] in 0..1.
  double healFrontAt(double t) => (healPMin - healPad) + t * healSpan;

  @override
  int get discs => _cx.length;
  @override
  double discX(int j) => _cx[j];
  @override
  double discY(int j) => _cy[j];
  @override
  double discR(int j) => _cr[j];
  @override
  double get rimRadius => brush;
  @override
  double get healPadding => healPad;

  static double _valueNoise(Float32List lat, double x, double y) {
    final xi = x.floor(), yi = y.floor();
    final fx = x - xi, fy = y - yi;
    final sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    double at(int i, int j) => lat[(j & (_lat - 1)) * _lat + (i & (_lat - 1))];
    final a = at(xi, yi), b = at(xi + 1, yi);
    final c = at(xi, yi + 1), d = at(xi + 1, yi + 1);
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy;
  }

  /// Picks the heal's wind, mostly sideways with a tilt, as the text's does.
  void beginHeal(math.Random rand) {
    final tilt = (rand.nextDouble() - 0.5) * (math.pi / 3);
    final sign = rand.nextBool() ? 1.0 : -1.0;
    healWind = Offset(math.cos(tilt) * sign, math.sin(tilt));
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (var j = 0; j < _cx.length; j++) {
      final p = _cx[j] * healWind.dx + _cy[j] * healWind.dy;
      final r = _cr[j] + _wander;
      lo = math.min(lo, p - r);
      hi = math.max(hi, p + r);
    }
    healPMin = lo.isFinite ? lo : 0;
    healPMax = hi.isFinite ? hi : 0;
    healing = true;
    _revision++;
  }

  void endHeal() {
    if (!healing) return;
    healing = false;
    _revision++;
  }

  /// Openness at vertex [i], 0..1, before any heal.
  double _openAt(int i) {
    final o = _reach[i] + _wander * (_noise[i] - 0.5);
    return (o / _crumble + 0.5).clamp(0.0, 1.0);
  }

  /// How open the hole is at ([x], [y]), 0..1.
  @override
  double clearedAt(double x, double y) {
    final c = (x / _gap).round();
    final r = (y / _gap).round();
    if (c < 0 || c >= cols || r < 0 || r >= rows) return 0;
    return _openAt(r * cols + c);
  }

  void lift() => _last = null;

  /// A touch at [point]: a new seed if the finger has travelled far enough
  /// from the last one.
  void stamp(Offset point) {
    final last = _last;
    if (last != null && (point - last).distance < _spacing) return;
    _cx.add(point.dx);
    _cy.add(point.dy);
    _cr.add(_seedStart);
    _max.add(brush * (0.92 + _rand.nextDouble() * 0.42));
    _age.add(0);
    _last = point;
    _raster(_cx.length - 1);
    _revision++;
  }

  /// Grows the seeds near the finger at [touch] by [dt]. True if anything
  /// grew.
  bool grow(double dt, Offset touch) {
    var grew = false;
    for (var j = 0; j < _cx.length; j++) {
      if (_cr[j] >= _max[j] - 0.05) continue;
      final dx = _cx[j] - touch.dx, dy = _cy[j] - touch.dy;
      final reach = _cr[j] + _nearby;
      if (dx * dx + dy * dy > reach * reach) continue;
      _age[j] += dt;
      _cr[j] = _seedStart +
          (_max[j] - _seedStart) * (1 - math.exp(-_age[j] / _growTau));
      _raster(j);
      grew = true;
    }
    if (grew) _revision++;
    return grew;
  }

  /// Lays seed [j]'s reach into the field. Reach only ever grows, so the
  /// field keeps its maximum.
  void _raster(int j) {
    final cx = _cx[j], cy = _cy[j], cr = _cr[j];
    final out = cr + _wander;
    final c0 = math.max(0, ((cx - out) / _gap).floor());
    final c1 = math.min(cols - 1, ((cx + out) / _gap).ceil());
    final r0 = math.max(0, ((cy - out) / _gap).floor());
    final r1 = math.min(rows - 1, ((cy + out) / _gap).ceil());
    for (var r = r0; r <= r1; r++) {
      final dy = r * _gap - cy;
      for (var c = c0; c <= c1; c++) {
        final dx = c * _gap - cx;
        final v = cr - math.sqrt(dx * dx + dy * dy);
        final i = r * cols + c;
        if (v > _reach[i]) _reach[i] = v;
      }
    }
  }

  double get clearedFraction {
    var open = 0.0;
    for (var i = 0; i < _reach.length; i++) {
      if (_reach[i] > -_wander) open += _openAt(i);
    }
    return open / _reach.length;
  }

  int _revision = 0;
  int _imageRevision = -1;
  double _imageHeal = -1;
  ui.Image? _image;

  /// Rasterised at half size: a quarter of the pixels, and each mask pixel
  /// is one grain of the dissolve, two points across.
  static const double _scale = 0.5;

  /// Over this many points the edge goes from every grain shut to every
  /// grain open: the width of the crumbling.
  static const double _crumble = 7;

  late final int _pw = math.max(1, (size.width * _scale).ceil());
  late final int _ph = math.max(1, (size.height * _scale).ceil());

  /// Each mask pixel's grain: the openness it needs before it opens. Fixed,
  /// so a grain that opened stays open as the edge moves on, and a heal
  /// shuts them again in the reverse order.
  late final Uint8List _grain = () {
    final g = Uint8List(_pw * _ph);
    final rand = math.Random(0xC0FFEE);
    for (var i = 0; i < g.length; i++) {
      g[i] = 1 + rand.nextInt(254);
    }
    return g;
  }();

  /// The open grains' centres, refilled per rebuild; never reallocated.
  late final Float32List _points = Float32List(_pw * _ph * 2);

  static final Paint _featherPaint = Paint()
    ..imageFilter = ui.ImageFilter.blur(sigmaX: 0.9, sigmaY: 0.9);

  static final Paint _grainPaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.square
    ..isAntiAlias = false;

  /// The holes as an alpha mask, [heal] of the way closed; cached until
  /// either changes.
  ui.Image image(double heal) {
    final cached = _image;
    if (cached != null && _imageRevision == _revision && _imageHeal == heal) {
      return cached;
    }
    final w = healWind;
    final front = healFrontAt(heal);
    // Deep enough to shut the widest seed through the noise's whole swing.
    const depth = brush * 1.4 + _wander + _crumble;
    final inv = 1 / (_scale * _gap);
    var n = 0;
    for (var py = 0; py < _ph; py++) {
      final y = (py + 0.5) / _scale;
      final gy = (py + 0.5) * inv;
      final r0 = math.min(rows - 2, gy.floor());
      final fy = gy - r0;
      for (var px = 0; px < _pw; px++) {
        final gx = (px + 0.5) * inv;
        final c0 = math.min(cols - 2, gx.floor());
        final i00 = r0 * cols + c0;
        // Nowhere near a seed: the common case, and the cheap one.
        final a00 = _reach[i00], a01 = _reach[i00 + 1];
        final a10 = _reach[i00 + cols], a11 = _reach[i00 + cols + 1];
        if (a00 <= -_wander &&
            a01 <= -_wander &&
            a10 <= -_wander &&
            a11 <= -_wander) {
          continue;
        }
        final fx = gx - c0;
        double lerp(double a, double b, double c, double d) {
          final top = a + (b - a) * fx;
          return top + ((c + (d - c) * fx) - top) * fy;
        }

        var o = lerp(a00, a01, a10, a11) +
            _wander *
                (lerp(_noise[i00], _noise[i00 + 1], _noise[i00 + cols],
                        _noise[i00 + cols + 1]) -
                    0.5);
        if (healing) {
          // Upwind of the front the reach is taken back, the full depth past
          // its band: the same grains shut, in the reverse order.
          final p = (px + 0.5) / _scale * w.dx + y * w.dy;
          final shut = ((front - p) / healBand).clamp(0.0, 1.0);
          o -= depth * shut;
        }
        // Openness across the crumbling band, against this grain's need.
        final open = (o / _crumble + 0.5) * 255;
        if (open <= _grain[py * _pw + px]) continue;
        _points[n++] = px + 0.5;
        _points[n++] = py + 0.5;
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (n > 0) {
      // A feather of a grain's width, so the edge is ragged by the noise and
      // soft at the grain, never a staircase of mask pixels.
      canvas
        ..saveLayer(null, _featherPaint)
        ..drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(_points, 0, n),
          _grainPaint,
        )
        ..restore();
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_pw, _ph);
    picture.dispose();
    _image?.dispose();
    _image = image;
    _imageRevision = _revision;
    _imageHeal = heal;
    return image;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
  }
}

/// Paints [child] through the rubbed holes ([keep]) or everywhere but them
/// (![keep]). With no [rub] it is a plain pass-through with no layer, which is
/// every sealed picture nobody has touched.
class _Holes extends SingleChildRenderObjectWidget {
  const _Holes({
    required this.rub,
    required this.heal,
    required this.repaint,
    required this.keep,
    required Widget super.child,
  });

  final _RubMask? rub;
  final Animation<double> heal;
  final Listenable repaint;
  final bool keep;

  @override
  _RenderHoles createRenderObject(BuildContext context) =>
      _RenderHoles(rub, heal, repaint, keep);

  @override
  void updateRenderObject(BuildContext context, _RenderHoles r) {
    r
      ..rub = rub
      ..heal = heal
      ..repaint = repaint
      ..keep = keep;
  }
}

class _RenderHoles extends RenderProxyBox {
  _RenderHoles(this._rub, this.heal, this._repaint, this.keep);

  _RubMask? _rub;
  set rub(_RubMask? v) {
    if (identical(v, _rub)) return;
    _rub = v;
    markNeedsPaint();
  }

  Animation<double> heal;
  bool keep;

  Listenable _repaint;
  set repaint(Listenable v) {
    if (identical(v, _repaint)) return;
    if (attached) _repaint.removeListener(markNeedsPaint);
    _repaint = v;
    if (attached) _repaint.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _repaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _repaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _rub != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final rub = _rub;
    if (rub == null || child == null) {
      layer = null;
      if (keep) return;
      super.paint(context, offset);
      return;
    }
    final image = rub.image(heal.value);
    // A shader mask's shader is in the mask rect's own coordinates.
    final m = Matrix4.identity()
      ..scaleByDouble(
        size.width / image.width,
        size.height / image.height,
        1,
        1,
      );
    final shaderLayer = (layer as ShaderMaskLayer?) ?? ShaderMaskLayer();
    shaderLayer
      // Sampled smoothly: the mask is half size, and a nearest-pixel read
      // of it is what drew blocks along the rim.
      ..shader = ImageShader(
        image,
        TileMode.decal,
        TileMode.decal,
        m.storage,
        filterQuality: FilterQuality.low,
      )
      ..maskRect = offset & size
      ..blendMode = keep ? BlendMode.dstIn : BlendMode.dstOut;
    layer = shaderLayer;
    context.pushLayer(shaderLayer, super.paint, offset);
  }
}
