@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A source scan, not a behaviour test, because the failure it guards against
/// cannot be reproduced from the VM: `flutter_web_sdk`'s `ImageDescriptor` is a
/// different class from the one `dart:ui` compiles against off the web, and only
/// the web one throws.
///
/// `ImageDescriptor.encoded` in a browser parses nothing — it wraps the bytes
/// and leaves every field null, so `width`, `height` and `bytesPerPixel` all
/// throw `UnsupportedError` (flutter_web_sdk/lib/ui/painting.dart). Code that
/// asks a descriptor for a dimension therefore fails on every image on web,
/// compiles clean, and passes every VM test.
///
/// That is exactly how it shipped twice: the chat editor and the avatar cropper
/// each kept a copy. `decodeImageBytes` and `imageBytesSize` are the sanctioned
/// way in, and `imageBytesSize` is allowed the descriptor because it is behind a
/// `kIsWeb` guard with a pure-Dart header parser on the other side.
void main() {
  test('nothing outside image_raster.dart reaches for an ImageDescriptor', () {
    const allowed = 'lib/media/image_raster.dart';

    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path == allowed) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        // Prose about the trap is the point of the trap, not a violation of it.
        if (line.startsWith('//') || line.startsWith('*')) continue;
        if (line.contains('ImageDescriptor')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'ImageDescriptor.width/height throw UnsupportedError on web. Use '
          'decodeImageBytes or imageBytesSize from $allowed instead.\n'
          'Found at: ${offenders.join(', ')}',
    );
  });
}
