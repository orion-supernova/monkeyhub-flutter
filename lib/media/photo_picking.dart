import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'image_raster.dart';

/// What came back from the OS media picker.
///
/// Three outcomes, not two. A picker call can end with the user's pictures, or
/// with the user backing out — and it can also end with the platform holding
/// pictures it will not hand over. That third one is not hypothetical and not
/// rare: on iOS, `loadDataRepresentation` fails with
/// `Cannot load representation of type public.jpeg` for an asset that is still
/// in iCloud, was shared into the library, or needs a transcode the system
/// declines to do. `image_picker` reports it by THROWING out of the await, so
/// every call site that did not catch turned a chosen photo into an unhandled
/// exception, a cleared spinner and no explanation.
///
/// Worse for a multi-pick: the iOS plugin collects the batch and fails the
/// whole call if any single asset fails, so nine readable photos are discarded
/// along with the tenth. Nothing here can rescue those nine — the results live
/// inside the native picker and it is gone by then — but the user can be told
/// that a re-pick is worth their time, which is strictly better than a chat
/// that silently did nothing.
class MediaPick {
  const MediaPick._(this.files, this.unreadable);

  /// The user chose these, in the order the picker returned them.
  const MediaPick.chosen(List<XFile> files) : this._(files, false);

  /// Nothing to do: the user backed out, or refused library/camera access —
  /// which the OS has already said its piece about, so we say nothing.
  const MediaPick.none() : this._(const [], false);

  /// The platform had the user's choice and could not produce the bytes.
  const MediaPick.unreadable() : this._(const [], true);

  /// Empty on both a cancel and a refusal — check [unreadable] to tell those
  /// apart before treating an empty pick as "the user changed their mind".
  final List<XFile> files;

  /// Whether this pick is worth a word to the user. See the class doc.
  final bool unreadable;

  /// The one file the single-shot pickers return, or null.
  XFile? get file => files.isEmpty ? null : files.first;
}

/// Codes that mean "no pictures, and that is fine" rather than a failure to
/// report. The access ones are a permission the OS has already prompted for,
/// and `multiple_request` is a second picker opened over the first — a double
/// tap, which deserves silence rather than an error.
const Set<String> _quietCodes = {
  'photo_access_denied',
  'photo_access_restricted',
  'camera_access_denied',
  'camera_access_restricted',
  'multiple_request',
};

/// Several photographs from the library.
///
/// [limit] is honoured by the iOS and Android pickers and ignored by the
/// `file_selector`-backed web and desktop ones, so callers still have to trim
/// what comes back.
Future<MediaPick> pickPhotos({int? limit}) => _guarded(
  () => ImagePicker().pickMultiImage(
    imageQuality: pickerImageQuality,
    limit: limit,
  ),
);

/// One photograph, from the library or the system camera.
Future<MediaPick> pickPhoto({
  required ImageSource source,
  int? imageQuality = pickerImageQuality,
  double? maxWidth,
  CameraDevice preferredCameraDevice = CameraDevice.rear,
}) => _guarded(() async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    preferredCameraDevice: preferredCameraDevice,
  );
  return picked == null ? const <XFile>[] : <XFile>[picked];
});

/// One video from the library.
Future<MediaPick> pickVideo() => _guarded(() async {
  final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
  return picked == null ? const <XFile>[] : <XFile>[picked];
});

/// Runs [pick] and turns the platform's exceptions into an outcome.
///
/// `PlatformException` only: an error out of the plugin's own channel is the
/// failure this exists for, and a `TypeError` from our own code above should
/// still crash loudly in debug rather than being reported to the user as a
/// photograph that would not open.
Future<MediaPick> _guarded(Future<List<XFile>> Function() pick) async {
  try {
    final files = await pick();
    return files.isEmpty ? const MediaPick.none() : MediaPick.chosen(files);
  } on PlatformException catch (e) {
    debugPrint('[photo_picking] picker failed: ${e.code} ${e.message}');
    return _quietCodes.contains(e.code)
        ? const MediaPick.none()
        : const MediaPick.unreadable();
  }
}
