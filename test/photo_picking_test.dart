@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:monkeyhub/media/photo_picking.dart';

/// The crash this wrapper exists for.
///
/// `pickMultiImage` on iOS throws
/// `PlatformException(invalid_image, Cannot load representation of type
/// public.jpeg, NSItemProviderErrorDomain)` when the library hands over an
/// asset the system will not produce bytes for — the usual one being a photo
/// that is still only in iCloud. Every call site awaited it bare, so choosing
/// such a picture was an unhandled exception and a chat that had visibly done
/// nothing.
///
/// What is asserted here is the shape of the answer, because that is what the
/// call sites branch on: chosen, nothing, or a refusal worth a word. The
/// permission codes belong in the middle group — the OS has already put its
/// own prompt in front of the user, and following it with our copy would be
/// the app explaining a decision the user just made.
class _FakePicker extends ImagePickerPlatform {
  _FakePicker.throwing(this._error) : _files = const [];
  _FakePicker.returning(this._files) : _error = null;

  final PlatformException? _error;
  final List<XFile> _files;

  List<XFile> get _answer {
    final error = _error;
    if (error != null) throw error;
    return _files;
  }

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => _answer;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => _answer.firstOrNull;

  @override
  Future<XFile?> getVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async => _answer.firstOrNull;
}

void main() {
  PlatformException failing(String code) =>
      PlatformException(code: code, message: 'nope', details: 'a.domain');

  void platformThrows(String code) {
    ImagePickerPlatform.instance = _FakePicker.throwing(failing(code));
  }

  void platformReturns(List<XFile> files) {
    ImagePickerPlatform.instance = _FakePicker.returning(files);
  }

  group('a pick that worked', () {
    test('carries the files through in order', () async {
      platformReturns([XFile('a.jpg'), XFile('b.jpg')]);
      final pick = await pickPhotos(limit: 10);
      expect(pick.unreadable, isFalse);
      expect(pick.files.map((f) => f.path), ['a.jpg', 'b.jpg']);
      expect(pick.file?.path, 'a.jpg');
    });

    test('a single-shot pick exposes its one file', () async {
      platformReturns([XFile('one.jpg')]);
      expect((await pickPhoto(source: ImageSource.gallery)).file?.path,
          'one.jpg');
      expect((await pickVideo()).file?.path, 'one.jpg');
    });
  });

  group('backing out', () {
    test('is nothing to do, not a failure', () async {
      platformReturns(const []);
      for (final pick in [
        await pickPhotos(),
        await pickPhoto(source: ImageSource.gallery),
        await pickVideo(),
      ]) {
        expect(pick.files, isEmpty);
        expect(pick.unreadable, isFalse);
        expect(pick.file, isNull);
      }
    });
  });

  group('the platform refusing to produce the bytes', () {
    test('is reported rather than thrown — the iCloud photo case', () async {
      platformThrows('invalid_image');
      final pick = await pickPhotos(limit: 10);
      expect(pick.unreadable, isTrue);
      expect(pick.files, isEmpty);
    });

    test('reaches the single-photo and video pickers too', () async {
      platformThrows('invalid_image');
      expect((await pickPhoto(source: ImageSource.gallery)).unreadable, isTrue);
      expect((await pickVideo()).unreadable, isTrue);
    });

    test('covers the codes we have not enumerated', () async {
      // A code nobody has seen yet is a failure to report, not a silence:
      // the user chose something and it did not arrive.
      platformThrows('some_code_from_a_future_plugin');
      expect((await pickPhotos()).unreadable, isTrue);
    });
  });

  group('a refusal the OS has already explained', () {
    for (final code in [
      'photo_access_denied',
      'photo_access_restricted',
      'camera_access_denied',
      'camera_access_restricted',
    ]) {
      test('$code passes as a cancel', () async {
        platformThrows(code);
        final pick = await pickPhotos();
        expect(pick.unreadable, isFalse, reason: 'the OS prompted already');
        expect(pick.files, isEmpty);
      });
    }

    test('a second picker over the first is a double tap, not an error',
        () async {
      platformThrows('multiple_request');
      expect((await pickPhotos()).unreadable, isFalse);
    });
  });
}
