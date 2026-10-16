import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PathOperation;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/spoiler_store.dart';
import '../l10n/generated/app_localizations.dart';
import 'dust/spoiler_dust.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: kMediaSpoilerReveal,
  )..addStatusListener(_onWave);

  /// Where the tap landed, in the cover's own box.
  Offset? _origin;
  late bool _open = _stored;

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
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  void _onWave(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() => _open = true);
    }
  }

  void _reveal(Offset at) {
    if (_open || _wave.isAnimating) return;
    HapticFeedback.lightImpact();
    final key = widget.revealKey;
    if (key != null) {
      SpoilerStore.instance.reveal(MediaSpoilerCover.storeKey(key));
    }
    widget.onRevealed?.call();
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _open = true);
      return;
    }
    setState(() => _origin = at);
    _wave.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final sealed = widget.sealed && !_open;
    final revealing = sealed && _origin != null;
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
                  if (revealing)
                    // The sharp picture, inside the growing disc.
                    IgnorePointer(
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
                      child: CustomPaint(
                        painter: _WavefrontPainter(_origin!, _wave),
                      ),
                    ),
                  if (widget.dust)
                  IgnorePointer(
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
      child: GestureDetector(
        behavior: sealed ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
        onTapUp: sealed ? (d) => _reveal(d.localPosition) : null,
        child: cover,
      ),
    );
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
