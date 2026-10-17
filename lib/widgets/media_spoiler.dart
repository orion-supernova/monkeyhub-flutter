import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter, PathOperation;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/spoiler_store.dart';
import '../l10n/generated/app_localizations.dart';
import 'dust/spoiler_dust.dart';
import 'spoiler_veil.dart' show kSpoilerHeal, kSpoilerHoldBaseMs;

/// How long the wavefront takes to open a spoiler picture. A little longer
/// than a line of text's (`kSpoilerRevealIn`), for a disc that has a whole
/// photograph to cross.
const Duration kMediaSpoilerReveal = Duration(milliseconds: 560);

/// A photo or video sent as a spoiler, and its reveal.
///
/// Sealed, the picture is blurred (its colours still there, nothing to make
/// out), dimmed a shade, and the text spoiler's living dust ([SpoilerDust],
/// the same grains on the same current) drifts over it: Telegram's "hidden,
/// but there". A tap opens it the way a text spoiler opens: a wavefront from
/// the touch point, the sharp picture inside an expanding disc while the dust
/// ahead of its edge is blown clear and the rest of it settles out.
///
/// Unlike a line of text it stays open: a picture is looked at, not glimpsed.
/// Open for the visit, remembered in [SpoilerStore] (under its own key, so a
/// spoiler caption on the same message keeps its own veil) and sealed again
/// once the room is left, as text spoilers are.
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
    this.dustDensity = SpoilerDust.defaultDensity,
    this.dust = true,
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
  final VoidCallback? onRevealed;

  /// The store key for [messageId]'s picture.
  static String storeKey(String messageId) => 'media:$messageId';

  @override
  State<MediaSpoilerCover> createState() => _MediaSpoilerCoverState();
}

class _MediaSpoilerCoverState extends State<MediaSpoilerCover>
    with TickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: kMediaSpoilerReveal,
  )..addStatusListener(_onWave);

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

  /// The fingertip while it rubs: the dust's draught.
  final ValueNotifier<Offset?> _touch = ValueNotifier(null);

  Offset? _lastRub;
  Timer? _healTimer;
  bool _calm = false;

  bool get _stored {
    final key = widget.revealKey;
    return key != null &&
        SpoilerStore.instance.isRevealed(MediaSpoilerCover.storeKey(key));
  }

  @override
  void didUpdateWidget(MediaSpoilerCover old) {
    super.didUpdateWidget(old);
    if (old.revealKey != widget.revealKey) {
      _wave.reset();
      _origin = null;
      _open = _stored;
      _dropRub();
    }
  }

  @override
  void dispose() {
    _healTimer?.cancel();
    _wave.dispose();
    _heal.dispose();
    _rub?.dispose();
    _rubRevision.dispose();
    _touch.dispose();
    super.dispose();
  }

  void _onWave(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() {
        _open = true;
        _dropRub();
      });
    }
  }

  void _onHeal(AnimationStatus s) {
    if (s != AnimationStatus.completed || !mounted) return;
    setState(_dropRub);
  }

  void _dropRub() {
    _healTimer?.cancel();
    _heal.value = 0;
    _rub?.dispose();
    _rub = null;
    _lastRub = null;
    _touch.value = null;
  }

  void _reveal(Offset at) {
    if (_open || _wave.isAnimating) return;
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
      return;
    }
    setState(() => _origin = at);
    _wave.forward(from: 0);
  }

  // ------------------------------------------------------------------ rub

  void _rubStart(Offset at, Size size) {
    if (_open || _wave.isAnimating) return;
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
      setState(() => _rub = _RubMask(size));
    }
    _rub!.lift();
    _lastRub = null;
    _rubAt(at);
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
      if (!mounted || _rub == null || _open || _wave.isAnimating) return;
      _heal.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    _calm = MediaQuery.disableAnimationsOf(context);
    final sealed = widget.sealed && !_open;
    final revealing = sealed && _origin != null;
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
        child: ImageFiltered(
        enabled: sealed,
        imageFilter: ImageFilter.blur(
          sigmaX: widget.sigma,
          sigmaY: widget.sigma,
          // Mirrored at the edges, so the blur does not fade to a dark rim.
          tileMode: TileMode.mirror,
        ),
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
                  if (revealing)
                    // The sharp picture, inside the growing disc.
                    IgnorePointer(
                      key: const ValueKey('disc'),
                      child: AnimatedBuilder(
                        animation: _wave,
                        builder: (context, child) => ClipPath(
                          clipper: _DiscClipper(_origin!, _wave.value),
                          child: child,
                        ),
                        child: widget.child,
                      ),
                    ),
                  if (revealing)
                    // The wavefront itself: a soft bright rim riding the
                    // disc's edge, fading as it reaches the corners.
                    IgnorePointer(
                      key: const ValueKey('rim'),
                      child: CustomPaint(
                        painter: _WavefrontPainter(_origin!, _wave),
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
                        animation: _wave,
                        builder: (context, dust) => revealing
                            ? ClipPath(
                                clipper: _DiscClipper(
                                  _origin!,
                                  _wave.value,
                                  outside: true,
                                ),
                                child: dust,
                              )
                            : dust!,
                        child: SpoilerDust(
                          seed: seed,
                          density: widget.dustDensity,
                          brightness: 1.25,
                          active: !revealing,
                          fade: kMediaSpoilerReveal,
                          draught: widget.interactive ? _touch : null,
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

/// The holes a finger has rubbed in the dust: a heap of jittered discs along
/// its path, flecked with satellites, so the rim crumbles instead of ruling,
/// as the text spoiler's wipe does. A brush a little wider than the text's,
/// for a picture rather than a word.
class _RubMask {
  _RubMask(this.size)
      : cols = math.max(1, (size.width / cell).ceil()),
        rows = math.max(1, (size.height / cell).ceil()) {
    values = Float32List(cols * rows);
  }

  final Size size;
  final int cols;
  final int rows;
  late final Float32List values;

  static const double cell = 10;
  static const double brush = 26;

  /// Interpolation step between move events.
  static const double step = 8;

  /// Rubbed this clear, the rest of the picture opens on its own.
  static const double enough = 0.62;

  static const double _spacing = 4.5;
  static const int _satelliteBudget = 260;

  final math.Random _rand = math.Random(0x5EED);
  final List<double> _cx = [], _cy = [], _cr = [], _rate = [];
  Offset? _last;

  void lift() => _last = null;

  void stamp(Offset point) {
    final last = _last;
    final travelled = last == null ? double.infinity : (point - last).distance;
    if (travelled >= _spacing) {
      // A slow finger presses wider than a fast one.
      final speed = travelled.isFinite ? travelled : 0.0;
      final r = brush *
          (1.18 - speed / 70).clamp(0.78, 1.18) *
          (0.86 + _rand.nextDouble() * 0.3);
      _add(point, r);
      if (_cx.length < _satelliteBudget) {
        for (var s = 0; s < 3; s++) {
          final a = _rand.nextDouble() * 2 * math.pi;
          final d = r * (0.6 + _rand.nextDouble() * 0.5);
          _add(
            point + Offset(math.cos(a) * d, math.sin(a) * d * 0.8),
            r * (0.14 + _rand.nextDouble() * 0.22),
          );
        }
      }
      _last = point;
    }
    final minX = ((point.dx - brush) / cell).floor();
    final maxX = ((point.dx + brush) / cell).ceil();
    final minY = ((point.dy - brush) / cell).floor();
    final maxY = ((point.dy + brush) / cell).ceil();
    for (var y = math.max(0, minY); y <= math.min(rows - 1, maxY); y++) {
      for (var x = math.max(0, minX); x <= math.min(cols - 1, maxX); x++) {
        final d = (Offset((x + 0.5) * cell, (y + 0.5) * cell) - point).distance;
        if (d > brush) continue;
        final fall = 1 - d / brush;
        final i = y * cols + x;
        values[i] = math.min(1, values[i] + fall * fall * 1.6);
      }
    }
    _revision++;
  }

  void _add(Offset c, double r) {
    _cx.add(c.dx);
    _cy.add(c.dy);
    _cr.add(r);
    // Each disc closes at its own pace when the dust settles back: small
    // flecks first, so the hole crumbles shut rather than shrinking.
    _rate.add(0.75 + _rand.nextDouble() * 0.6 + (r < brush * 0.4 ? 0.5 : 0));
  }

  double get clearedFraction {
    var cleared = 0.0;
    for (final v in values) {
      cleared += math.min(1, v);
    }
    return cleared / values.length;
  }

  int _revision = 0;
  int _imageRevision = -1;
  double _imageHeal = -1;
  ui.Image? _image;

  /// Rasterised at half size: the rim is feathered anyway, and a mask a
  /// quarter of the pixels is a quarter of the upload.
  static const double _scale = 0.5;

  /// The holes as an alpha mask, [heal] of the way closed; cached until
  /// either changes.
  ui.Image image(double heal) {
    final cached = _image;
    if (cached != null && _imageRevision == _revision && _imageHeal == heal) {
      return cached;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    for (var j = 0; j < _cx.length; j++) {
      final close = heal <= 0
          ? 0.0
          : Curves.easeInOutCubic.transform((heal * _rate[j]).clamp(0.0, 1.0));
      final r = _cr[j] * (1 - close);
      if (r < 0.5) continue;
      canvas.drawCircle(Offset(_cx[j], _cy[j]), r, paint);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      math.max(1, (size.width * _scale).ceil()),
      math.max(1, (size.height * _scale).ceil()),
    );
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
      ..shader = ImageShader(image, TileMode.decal, TileMode.decal, m.storage)
      ..maskRect = offset & size
      ..blendMode = keep ? BlendMode.dstIn : BlendMode.dstOut;
    layer = shaderLayer;
    context.pushLayer(shaderLayer, super.paint, offset);
  }
}

/// The wavefront's disc at [center], [t] of the way open: from nothing to
/// past the box's far corner, eased out so it bursts open and slows as it
/// reaches the edges. With [outside], everything but the disc.
class _DiscClipper extends CustomClipper<Path> {
  _DiscClipper(this.center, this.t, {this.outside = false});

  final Offset center;
  final double t;
  final bool outside;

  @override
  Path getClip(Size size) {
    final radius = _waveRadius(center, size, t);
    final disc = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    if (!outside) return disc;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      disc,
    );
  }

  @override
  bool shouldReclip(_DiscClipper old) =>
      old.center != center || old.t != t || old.outside != outside;
}

/// How far the wavefront from [o] has got across [size] at [t].
double _waveRadius(Offset o, Size size, double t) {
  final far = [
    o,
    Offset(size.width - o.dx, o.dy),
    Offset(o.dx, size.height - o.dy),
    Offset(size.width - o.dx, size.height - o.dy),
  ].map((p) => p.distance).reduce(math.max);
  return far * Curves.easeOutCubic.transform(t.clamp(0.0, 1.0)) + 1;
}

class _WavefrontPainter extends CustomPainter {
  _WavefrontPainter(this.origin, this.wave) : super(repaint: wave);

  final Offset origin;
  final Animation<double> wave;

  @override
  void paint(Canvas canvas, Size size) {
    final t = wave.value;
    final fade = 1 - Curves.easeIn.transform(t);
    if (fade <= 0) return;
    canvas.drawCircle(
      origin,
      _waveRadius(origin, size, t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = Color.fromRGBO(255, 255, 255, 0.32 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  @override
  bool shouldRepaint(_WavefrontPainter old) =>
      old.origin != origin || old.wave != wave;
}
