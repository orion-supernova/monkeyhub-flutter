import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'open_free_map_snapshot.dart';

/// OpenFreeMap tiles for `flutter_map`, drawn by [OpenFreeMapSnapshot] — the
/// same renderer, style and tile cache as the bubble pictures, so the
/// full-screen map is the bubble's map, larger and movable.
///
/// Each 256-point tile is rendered once, at [scale] device pixels per point,
/// and cached by Flutter's image cache like any other picture.
class OpenFreeMapTileProvider extends TileProvider {
  OpenFreeMapTileProvider({required this.dark, required this.scale});

  final bool dark;
  final double scale;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _OpenFreeMapTile(
        z: coordinates.z,
        x: coordinates.x,
        y: coordinates.y,
        dark: dark,
        scale: scale,
      );
}

@immutable
class _OpenFreeMapTile extends ImageProvider<_OpenFreeMapTile> {
  const _OpenFreeMapTile({
    required this.z,
    required this.x,
    required this.y,
    required this.dark,
    required this.scale,
  });

  final int z;
  final int x;
  final int y;
  final bool dark;
  final double scale;

  @override
  Future<_OpenFreeMapTile> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _OpenFreeMapTile key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_load());

  Future<ImageInfo> _load() async {
    final image = await OpenFreeMapSnapshot.renderTile(
      z: z,
      x: x,
      y: y,
      scale: scale,
      dark: dark,
    );
    // flutter_map treats a failed tile as missing and keeps the layer going;
    // the next pan asks again.
    if (image == null) throw StateError('OpenFreeMap tile $z/$x/$y failed');
    return ImageInfo(image: image, scale: scale);
  }

  @override
  bool operator ==(Object other) =>
      other is _OpenFreeMapTile &&
      other.z == z &&
      other.x == x &&
      other.y == y &&
      other.dark == dark &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(z, x, y, dark, scale);
}
