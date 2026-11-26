import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../data/settings_store.dart';

/// A street-map picture from OpenFreeMap, for platforms with no OS map
/// renderer (Android, Windows, Linux, web). Apple platforms use MapKit
/// instead; see `location_map_snapshot.dart`.
///
/// OpenFreeMap (openfreemap.org) serves OpenStreetMap vector tiles with no
/// key, no registration and no request limits. We do not host anything: the
/// viewer's device fetches the few tiles around the shared point straight from
/// OpenFreeMap and draws them once, here, into a still image with the
/// `vector_tile_renderer` package — the same image contract MapKit gives the
/// Apple side, so the bubble never runs a live map widget while scrolling.
///
/// Style: whichever is chosen in Settings › Maps ([currentStyle]); Liberty,
/// OpenFreeMap's most detailed and colourful, by default. Attribution is required by OpenFreeMap's terms and drawn by the
/// card ([attribution]).
///
/// Everything fails soft: no network, a style the renderer can't read, or a
/// tile that won't decode returns null and the caller keeps its drawn card.
abstract final class OpenFreeMapSnapshot {
  /// OpenFreeMap's required credit, verbatim.
  static const attribution =
      'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';

  static const _base = 'https://tiles.openfreemap.org';

  /// OpenMapTiles has no data past z14; deeper views draw a z14 tile larger.
  static const _maxDataZoom = 14;

  /// Web-Mercator metres per 256-px tile pixel at zoom 0 on the equator.
  static const _metersPerPixelZ0 = 156543.03392;

  /// The style chosen in Settings › Maps (Liberty, the colourful one, by
  /// default), by its name on tiles.openfreemap.org.
  static String get currentStyle => SettingsStore.instance.ofmStyle.name;

  static http.Client _client = http.Client();

  @visibleForTesting
  static set client(http.Client value) => _client = value;

  static final _styles = <String, Future<_Style?>>{};
  static Future<String?>? _tileUrl;

  /// Decoded tiles, shared between nearby bubbles (a street of shared pins
  /// is usually one or two tiles).
  static final Map<String, Future<vtr.Tile?>> _tiles = {};
  static const _tileCapacity = 32;

  /// Drops the decoded tiles ([MemoryTrim] hook). A render in flight keeps
  /// its own future; the next one re-fetches through the HTTP cache.
  static void trim() => _tiles.clear();

  /// Renders the view [spanMeters] wide around the point, at [size] logical
  /// pixels and [scale] device pixels per logical pixel.
  static Future<ui.Image?> render({
    required double latitude,
    required double longitude,
    required double spanMeters,
    required Size size,
    required double scale,
    required String styleName,
  }) {
    // Display zoom: the zoom at which the span fills the card's width.
    final zoom = zoomFor(
      latitude: latitude,
      spanMeters: spanMeters,
      widthPoints: size.width,
    );
    final tilePx = _tilePx(zoom, scale);
    // The card's top-left in world pixels at the display zoom.
    final worldPx = tilePx * (1 << _dataZoom(zoom));
    final cx = (longitude + 180) / 360 * worldPx;
    final latRad = latitude.clamp(-85.05, 85.05) * math.pi / 180;
    final cy =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        worldPx;
    return _renderRegion(
      zoom: zoom,
      left: ((cx - size.width / 2) * scale).roundToDouble() / scale,
      top: ((cy - size.height / 2) * scale).roundToDouble() / scale,
      size: size,
      scale: scale,
      styleName: styleName,
    );
  }

  /// One 256-point web-Mercator tile ([z]/[x]/[y]) for the full-screen map's
  /// tile layer. Past z14 it is a magnified part of a z14 data tile.
  static Future<ui.Image?> renderTile({
    required int z,
    required int x,
    required int y,
    required double scale,
    required String styleName,
  }) => _renderRegion(
    zoom: z.toDouble(),
    left: x * 256.0,
    top: y * 256.0,
    size: const Size(256, 256),
    scale: scale,
    styleName: styleName,
  );

  /// The web-Mercator zoom at which [spanMeters] spans [widthPoints].
  static double zoomFor({
    required double latitude,
    required double spanMeters,
    required double widthPoints,
  }) {
    final cosLat = math.cos(latitude * math.pi / 180).abs().clamp(0.01, 1.0);
    return (math.log(_metersPerPixelZ0 * cosLat * widthPoints / spanMeters) /
            math.ln2)
        .clamp(1.0, 20.0);
  }

  static int _dataZoom(double zoom) => math.min(zoom.floor(), _maxDataZoom);

  /// One data tile's edge, in logical pixels, at the display zoom. Snapped to
  /// whole device pixels (as is a card's origin) so neighbouring tiles meet
  /// exactly: an antialiased edge on a fractional pixel leaves a visible
  /// hairline seam between them.
  static double _tilePx(double zoom, double scale) =>
      (256 * math.pow(2, zoom - _dataZoom(zoom)) * scale).roundToDouble() /
      scale;

  /// Draws the [size] region whose top-left is ([left], [top]) in world
  /// pixels at [zoom].
  static Future<ui.Image?> _renderRegion({
    required double zoom,
    required double left,
    required double top,
    required Size size,
    required double scale,
    required String styleName,
  }) async {
    try {
      final style = await _style(styleName);
      final url = await (_tileUrl ??= _fetchTileUrl());
      if (style == null || url == null) {
        _tileUrl = null; // Retry the TileJSON next time.
        return null;
      }
      final dataZoom = _dataZoom(zoom);
      final tilesPerSide = 1 << dataZoom;
      final tilePx = _tilePx(zoom, scale);

      final x0 = (left / tilePx).floor();
      final x1 = ((left + size.width) / tilePx).floor();
      final y0 = math.max(0, (top / tilePx).floor());
      final y1 = math.min(tilesPerSide - 1, ((top + size.height) / tilePx).floor());

      final wanted = <({int x, int y, Future<vtr.Tile?> tile})>[];
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          final wrapped = ((x % tilesPerSide) + tilesPerSide) % tilesPerSide;
          wanted.add((
            x: x,
            y: y,
            tile: _tile(url, style.theme, dataZoom, wrapped, y),
          ));
        }
      }
      final tiles = await Future.wait(wanted.map((t) => t.tile));
      if (tiles.every((t) => t == null)) return null;

      final pixelW = (size.width * scale).round();
      final pixelH = (size.height * scale).round();
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        Rect.fromLTWH(0, 0, pixelW.toDouble(), pixelH.toDouble()),
      );
      canvas.scale(scale);
      final renderer = vtr.Renderer(theme: style.theme);
      final factor = tilePx / 256;
      for (var i = 0; i < wanted.length; i++) {
        final tile = tiles[i];
        if (tile == null) continue;
        final dx = wanted[i].x * tilePx - left;
        final dy = wanted[i].y * tilePx - top;
        // The part of this tile the card shows, in the tile's own 256 units.
        final tileClip = Rect.fromLTWH(
          -dx / factor,
          -dy / factor,
          size.width / factor,
          size.height / factor,
        ).intersect(const Rect.fromLTWH(0, 0, 256, 256));
        if (tileClip.isEmpty) continue;
        canvas.save();
        canvas.translate(dx, dy);
        canvas.scale(factor);
        renderer.render(
          canvas,
          vtr.TileSource(
            tileset: vtr.Tileset({'openmaptiles': tile}),
            spriteIndex: style.spriteIndex,
            spriteAtlas: style.spriteAtlas,
          ),
          clip: tileClip,
          zoomScaleFactor: factor,
          zoom: zoom,
          rotation: 0,
        );
        canvas.restore();
      }
      return await recorder.endRecording().toImage(pixelW, pixelH);
    } catch (e) {
      debugPrint('[openfreemap] render failed: $e');
      return null;
    }
  }

  static Future<_Style?> _style(String name) {
    final cached = _styles[name];
    if (cached != null) return cached;
    final future = _fetchStyle(name).then((style) {
      if (style == null) _styles.remove(name); // Retry next time.
      return style;
    });
    return _styles[name] = future;
  }

  static Future<_Style?> _fetchStyle(String name) async {
    final res = await _client.get(Uri.parse('$_base/styles/$name'));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final theme = vtr.ThemeReader().read(json);

    // Icons (POIs, road shields) are polish, not essential: a missing sprite
    // still renders the map.
    vtr.SpriteIndex? index;
    ui.Image? atlas;
    final sprite = json['sprite'];
    if (sprite is String) {
      try {
        final responses = await Future.wait([
          _client.get(Uri.parse('$sprite@2x.json')),
          _client.get(Uri.parse('$sprite@2x.png')),
        ]);
        if (responses.every((r) => r.statusCode == 200)) {
          index = vtr.SpriteIndexReader().read(
            jsonDecode(responses[0].body) as Map<String, dynamic>,
          );
          final codec = await ui.instantiateImageCodec(responses[1].bodyBytes);
          atlas = (await codec.getNextFrame()).image;
        }
      } catch (_) {
        index = null;
        atlas = null;
      }
    }
    return _Style(theme, index, atlas);
  }

  /// The tile URL template from OpenFreeMap's TileJSON. It carries a dated
  /// build path that changes weekly, so it is fetched, never hardcoded.
  static Future<String?> _fetchTileUrl() async {
    final res = await _client.get(Uri.parse('$_base/planet'));
    if (res.statusCode != 200) return null;
    final tiles = (jsonDecode(res.body) as Map<String, dynamic>)['tiles'];
    return tiles is List && tiles.isNotEmpty ? tiles.first as String : null;
  }

  static Future<vtr.Tile?> _tile(
    String template,
    vtr.Theme theme,
    int z,
    int x,
    int y,
  ) {
    final url = template
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
    final hit = _tiles.remove(url);
    if (hit != null) return _tiles[url] = hit;
    final future = () async {
      final res = await _client.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final vector = await compute(_decode, res.bodyBytes);
      return vtr.TileFactory(theme, const vtr.Logger.noop()).create(vector);
    }()
        .catchError((Object _) => null)
        .then((tile) {
          if (tile == null) _tiles.remove(url);
          return tile;
        });
    _tiles[url] = future;
    while (_tiles.length > _tileCapacity) {
      _tiles.remove(_tiles.keys.first);
    }
    return future;
  }
}

vtr.VectorTile _decode(Uint8List bytes) => vtr.VectorTileReader().read(bytes);

class _Style {
  _Style(this.theme, this.spriteIndex, this.spriteAtlas);
  final vtr.Theme theme;
  final vtr.SpriteIndex? spriteIndex;
  final ui.Image? spriteAtlas;
}
