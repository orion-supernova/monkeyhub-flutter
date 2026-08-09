import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// The card a location bubble draws instead of a map.
///
/// ─────────────────────────────────────────────────────────────────────────
/// WHY THIS DRAWS A GRATICULE AND NOT A STREET MAP
/// ─────────────────────────────────────────────────────────────────────────
///
/// The requirement was a location preview with **no API key and unlimited
/// usage**, production ready. Those three cannot all be satisfied by a real
/// slippy map, and pretending otherwise would ship something that works in
/// development and breaks — or gets the app blocked — in production. The
/// options were examined properly; here is what each one actually costs.
///
/// **OpenStreetMap's public tile servers (`tile.openstreetmap.org`).** The
/// obvious keyless answer, and the wrong one. The OSMF Tile Usage Policy names
/// "heavy use (e.g. distributing a heavy-usage app)" as forbidden, requires an
/// identifying User-Agent, and the operators do block applications that ignore
/// it. Those servers are donated infrastructure for the OSM project, not a free
/// CDN for a messaging app's transcripts. Shipping against them is not a
/// technical risk to be mitigated with caching — it is using someone else's
/// donations without asking, until they notice.
///
/// **Keyless commercial hosts.** There aren't any that permit this. Stamen
/// moved to Stadia Maps (key required). Wikimedia's tiles are contractually
/// restricted to Wikimedia projects and enforce it on Referer. Carto's
/// basemaps are for Carto customers. Every "free tier" that exists is a free
/// tier *with a key*, which is exactly what this feature was told not to need.
///
/// **OpenFreeMap** deserves a straight answer because it genuinely does
/// advertise no key and no limits. Two things ruled it out. It serves vector
/// tiles, so consuming it means a MapLibre GL renderer — either a native SDK or
/// a Dart vector renderer — which is a large dependency and a real per-frame
/// cost inside a scrolling transcript. And it is donation-funded infrastructure
/// run by one person; "unlimited" there is a generous offer, not an SLA, and a
/// transcript that renders empty grey rectangles the week it goes down is not
/// production ready either.
///
/// **The objection that applies to ALL of them, and that decided it.** Any
/// fetched tile means that every time a recipient scrolls past this bubble,
/// their device tells a third-party host both their IP address and the exact
/// coordinates somebody privately shared with them. In an app with a per-field
/// visibility lens, view-once photos that deliberately avoid a disk cache, and
/// a guardian policy over children's accounts, quietly forwarding shared
/// positions to a CDN would contradict the rest of the product. The large
/// messengers avoid this by rendering map previews on their OWN servers and
/// serving them as images — an option available to anyone willing to run a tile
/// server, and to nobody who wants zero infrastructure.
///
/// **So this draws, and it draws only true things.** The graticule lines are
/// real parallels and meridians at the stated spacing, latitude-corrected, and
/// the position sits at its real offset within its cell. The scale bar is
/// measured. The accuracy ring is the radius the device reported, at the same
/// scale, and is omitted entirely when the device reported nothing rather than
/// drawn at a flattering guess. North is up because up is north.
///
/// It is deliberately NOT a procedurally-generated fake street grid, which was
/// the tempting version: invented roads would read as a map and be a lie about
/// the surroundings of somebody's actual position. What this card claims is
/// exactly what it can support — where the point is, how precisely it is known,
/// and how far across the view is — and the tap target next to it opens the
/// real thing in the maps app the user already has.
///
/// **What upgrading would take**, if the honest limit here is later judged too
/// austere: run a tile server (or a static-map renderer) on the same
/// infrastructure as the Convex deployment, and replace this widget's body with
/// a cached image fetch against it. Nothing else in the feature changes — the
/// model, the expiry rules, the publisher and the bubble are all independent of
/// how the rectangle is filled. That is why this is one leaf widget with no
/// callers reaching inside it.
class LocationMapPreview extends StatelessWidget {
  const LocationMapPreview({
    super.key,
    required this.theme,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.pulse = 0,
    this.dimmed = false,
  });

  final AppTheme theme;
  final double latitude;
  final double longitude;

  /// Radius of the accuracy ring, in metres. Null draws no ring at all — see
  /// the class comment on why an unknown accuracy is not rendered as a
  /// confident one.
  final double? accuracyM;

  /// 0→1, driving the live share's expanding halo. Zero (the default) draws a
  /// static marker, which is what a fixed share and an ended one both want.
  final double pulse;

  /// Draw as finished: desaturated grid, hollow marker. Used for a live share
  /// that has ended, so it is visibly not the same thing as one that is running.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GraticulePainter(
        theme: theme,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        pulse: pulse,
        dimmed: dimmed,
        textDirection: Directionality.of(context),
      ),
      // Sized by the parent; the painter fills whatever it is given.
      child: const SizedBox.expand(),
    );
  }
}

/// How wide the card is, in metres, for a given reported accuracy.
///
/// Scaled off the accuracy rather than fixed, so the view always contains the
/// uncertainty it is drawing: a 500 m fix on a 250 m card would put a ring
/// larger than the card around a dot in the middle of it, which reads as
/// precision. Six times the radius leaves the ring occupying a third of the
/// width — visible as a real qualification of the dot, not as decoration.
///
/// The floor is a street-level view for a good fix. The ceiling stops a
/// catastrophically vague fix (a desktop Wi-Fi lookup can be tens of
/// kilometres) from zooming out to a view where the grid is meaningless; past
/// it the ring is simply clipped, and the readout says the accuracy in numbers.
@visibleForTesting
double spanMetersFor(double? accuracyM) {
  const floor = 250.0;
  const ceiling = 6000.0;
  if (accuracyM == null || accuracyM <= 0) return floor;
  return (accuracyM * 6).clamp(floor, ceiling);
}

/// Metres between graticule lines, chosen so the spacing on screen stays
/// legible at any span.
///
/// Walks a 1-2-5 ladder — the same progression every scale bar and chart axis
/// uses — and takes the first step that puts fewer than about eight lines
/// across the card. Round numbers matter here because the scale bar prints one
/// of them: "100 m" is a measurement a reader can carry to the next bubble,
/// "137 m" is noise.
@visibleForTesting
double graticuleStepMeters(double spanMeters) {
  const ladder = [
    10.0, 20.0, 50.0, 100.0, 200.0, 500.0,
    1000.0, 2000.0, 5000.0, 10000.0,
  ];
  for (final step in ladder) {
    if (spanMeters / step <= 8) return step;
  }
  return ladder.last;
}

/// Metres per degree of latitude. Constant enough at this scale — the WGS-84
/// spread from equator to pole is under half a percent, which is invisible on a
/// grid drawn to the nearest pixel.
const double _metersPerDegreeLat = 111320.0;

class _GraticulePainter extends CustomPainter {
  _GraticulePainter({
    required this.theme,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.pulse,
    required this.dimmed,
    required this.textDirection,
  });

  final AppTheme theme;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double pulse;
  final bool dimmed;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final centre = rect.center;

    final spanM = spanMetersFor(accuracyM);
    final pxPerMeter = size.width / spanM;
    final stepM = graticuleStepMeters(spanM);
    final stepPx = stepM * pxPerMeter;

    canvas.save();
    canvas.clipRect(rect);

    // Ground.
    canvas.drawRect(rect, Paint()..color = theme.surfaceSunken);

    _paintGraticule(canvas, size, centre, stepM, stepPx);
    _paintAccuracyRing(canvas, centre, pxPerMeter);
    _paintMarker(canvas, centre);
    _paintScaleBar(canvas, size, stepM, stepPx);
    _paintNorth(canvas, size);

    canvas.restore();
  }

  /// The grid. These are real parallels and meridians: the offset of the
  /// nearest line from the centre is this point's own position within its cell,
  /// so the pin's placement between the lines is information rather than
  /// decoration.
  void _paintGraticule(
    Canvas canvas,
    Size size,
    Offset centre,
    double stepM,
    double stepPx,
  ) {
    if (stepPx <= 2) return; // Degenerate; nothing legible to draw.

    final ink = dimmed ? theme.inkMuted : theme.accent;
    final minor = Paint()
      ..color = ink.withValues(alpha: dimmed ? 0.10 : 0.16)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final major = Paint()
      ..color = ink.withValues(alpha: dimmed ? 0.16 : 0.28)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Degrees per grid step. Longitude is corrected by cos(latitude), which is
    // the one piece of arithmetic that makes this a graticule rather than a
    // decorative grid: without it the cells stop being square as you move away
    // from the equator, and the pin's offset within its cell stops meaning
    // anything.
    final degLat = stepM / _metersPerDegreeLat;
    final cosLat = math.cos(latitude * math.pi / 180).abs();
    final degLng = cosLat < 1e-6
        ? degLat // At the poles a meridian spacing is meaningless; fall back.
        : stepM / (_metersPerDegreeLat * cosLat);

    // How far the point sits past the last line, as a fraction of a cell.
    double frac(double value, double step) {
      final r = value / step;
      return r - r.floorToDouble();
    }

    final latFrac = frac(latitude, degLat);
    final lngFrac = frac(longitude, degLng);

    // Horizontal lines (parallels). Latitude increases upward, so the nearest
    // line BELOW the point is `latFrac` of a cell down from it on screen.
    final firstBelowY = centre.dy + latFrac * stepPx;
    var lineIndex = 0;
    for (var y = firstBelowY; y >= -stepPx; y -= stepPx, lineIndex++) {
      if (y > size.height + stepPx) continue;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        lineIndex % 5 == 0 ? major : minor,
      );
    }
    lineIndex = 1;
    for (var y = firstBelowY + stepPx; y <= size.height + stepPx; y += stepPx) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        lineIndex % 5 == 0 ? major : minor,
      );
      lineIndex++;
    }

    // Vertical lines (meridians). Longitude increases eastward, i.e. rightward.
    final firstWestX = centre.dx - lngFrac * stepPx;
    lineIndex = 0;
    for (var x = firstWestX; x >= -stepPx; x -= stepPx, lineIndex++) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        lineIndex % 5 == 0 ? major : minor,
      );
    }
    lineIndex = 1;
    for (var x = firstWestX + stepPx; x <= size.width + stepPx; x += stepPx) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        lineIndex % 5 == 0 ? major : minor,
      );
      lineIndex++;
    }
  }

  /// The reported horizontal accuracy, at the same scale as the grid.
  ///
  /// Nothing is drawn when the device reported no accuracy. That is the honest
  /// rendering: an absent ring says "unknown", and any radius drawn in its place
  /// would say "this much", which nobody measured.
  void _paintAccuracyRing(Canvas canvas, Offset centre, double pxPerMeter) {
    final acc = accuracyM;
    if (acc == null || acc <= 0) return;
    final r = acc * pxPerMeter;
    if (r < 3) return; // Smaller than the marker; the marker already says it.
    final tint = dimmed ? theme.inkMuted : theme.accent;
    canvas.drawCircle(
      centre,
      r,
      Paint()..color = tint.withValues(alpha: dimmed ? 0.06 : 0.12),
    );
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..color = tint.withValues(alpha: dimmed ? 0.20 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintMarker(Canvas canvas, Offset centre) {
    final tint = dimmed ? theme.inkMuted : theme.accent;

    // The live halo. Expands and fades on each cycle — the one animated thing
    // on the card, and the only signal a still screenshot cannot carry, which is
    // why the bubble also says "live until" in words beside it.
    if (pulse > 0 && !dimmed) {
      final t = pulse.clamp(0.0, 1.0);
      canvas.drawCircle(
        centre,
        10 + 22 * t,
        Paint()..color = tint.withValues(alpha: 0.28 * (1 - t)),
      );
    }

    // A dot, not a teardrop pin. A pin's point is its position and its body
    // hangs above it, which at this size puts the visual centre of mass several
    // pixels north of the place being described. A concentric dot is centred on
    // what it means.
    canvas.drawCircle(
      centre,
      8.5,
      Paint()..color = theme.surface.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      centre,
      8.5,
      Paint()
        ..color = tint.withValues(alpha: dimmed ? 0.5 : 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    if (!dimmed) {
      canvas.drawCircle(centre, 3.6, Paint()..color = tint);
    }
  }

  /// A measured scale bar, exactly one graticule cell wide.
  ///
  /// Tied to the grid rather than sized independently so the number under it
  /// also labels the grid — one measurement stated once, which is why the step
  /// ladder above insists on round values.
  void _paintScaleBar(Canvas canvas, Size size, double stepM, double stepPx) {
    if (stepPx < 24 || stepPx > size.width - 24) return;
    const pad = 10.0;
    final y = size.height - pad - 6;
    final x0 = pad;
    final x1 = pad + stepPx;
    final paint = Paint()
      ..color = theme.ink.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), paint);
    canvas.drawLine(Offset(x0, y - 3), Offset(x0, y + 3), paint);
    canvas.drawLine(Offset(x1, y - 3), Offset(x1, y + 3), paint);

    final label = stepM >= 1000
        ? '${(stepM / 1000).toStringAsFixed(stepM % 1000 == 0 ? 0 : 1)} km'
        : '${stepM.toStringAsFixed(0)} m';
    _text(canvas, label, Offset(x0, y - 18));
  }

  void _paintNorth(Canvas canvas, Size size) {
    // North is up, so saying so is a fact and not a compass. It earns its space
    // by telling a reader the card is oriented at all — without it, an abstract
    // grid could be at any rotation.
    _text(canvas, 'N', Offset(size.width - 22, 8), alpha: 0.45);
  }

  void _text(Canvas canvas, String s, Offset at, {double alpha = 0.55}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: theme.monoTiny.copyWith(
          color: theme.ink.withValues(alpha: alpha),
          letterSpacing: 0.6,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_GraticulePainter old) =>
      old.latitude != latitude ||
      old.longitude != longitude ||
      old.accuracyM != accuracyM ||
      old.pulse != pulse ||
      old.dimmed != dimmed ||
      old.theme != theme;
}
