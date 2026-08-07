import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/file_meta.dart';
import '../../media/image_raster.dart';
import '../../media/upload_service.dart';
import '../../media/video_poster.dart';
import '../../models/moment.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../camera_screen.dart';
import '../image_crop_screen.dart';

/// Composes a HIGHLIGHT: a picture or a video, and a few words about it.
///
/// Points live in `point_composer.dart` and are a different act entirely — a
/// sentence about something that happened, with the photo optional. Merging
/// them into one sheet made highlights feel like they needed a score and points
/// feel like they needed a camera, and neither is true. They still write the
/// same row; only the composing is separate, which is where it matters.
///
/// Returns true when something was published, so the caller can react.
Future<bool> showMomentComposer(
  BuildContext context, {
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
}) async {
  final posted = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _MomentComposer(
      api: api,
      feedApi: feedApi,
      userId: userId,
    ),
  );
  return posted == true;
}

class _MomentComposer extends StatefulWidget {
  const _MomentComposer({
    required this.api,
    required this.feedApi,
    required this.userId,
  });

  final ChatApi api;
  final FeedApi feedApi;
  final String userId;

  @override
  State<_MomentComposer> createState() => _MomentComposerState();
}

class _MomentComposerState extends State<_MomentComposer> {
  final _caption = TextEditingController();
  CroppedImage? _image;

  /// A picked video, held as bytes with its poster frame. Mutually exclusive
  /// with [_image] — a moment carries one piece of media, not a gallery.
  ({Uint8List bytes, Uint8List? poster, String name})? _video;
  bool _busy = false;
  String? _errorCode;

  /// Matches `MAX_CAPTION` in backend/convex/feed.ts. Duplicated rather than
  /// shared because this repo has no Dart↔TypeScript constants mechanism —
  /// error codes are literals on both sides too.
  static const _maxCaption = 280;

  @override
  void initState() {
    super.initState();
    _caption.addListener(_onTyped);
  }

  @override
  void dispose() {
    _caption.removeListener(_onTyped);
    _caption.dispose();
    super.dispose();
  }

  void _onTyped() {
    // Only the counter and the enabled-ness of Post depend on this, so rebuild
    // rather than tracking a finer-grained listenable for two glyphs.
    setState(() {});
  }

  bool get _canPost =>
      !_busy &&
      (_image != null || _video != null || _caption.text.trim().isNotEmpty);

  Future<void> _capture() async {
    // Raise the scrim BEFORE the picker: `ImagePicker.pickImage` with
    // `imageQuality` re-encodes the asset AFTER the native sheet has already
    // dismissed, which for a 12MP HEIC is seconds of the user staring at an
    // apparently unchanged screen.
    setState(() => _busy = true);
    try {
      final result = await CameraScreen.open<CroppedImage>(
        context,
        initialLens: CameraLensDirection.back,
        review: (context, photo) async => ReviewDone(
          await ImageCropScreen.open(
            context,
            source: photo.bytes,
            shape: CropShape.rect,
            // A highlight is a picture, not an avatar — keep the frame the
            // user actually shot rather than forcing it square.
            aspectRatio: null,
            mirrored: photo.mirrored,
            overCamera: true,
          ),
        ),
      );
      if (!mounted) return;
      switch (result) {
        case CameraReviewed(:final value):
          if (value != null) {
            setState(() {
              _image = value;
              _video = null;
            });
          }
        case CameraPickLibrary():
          await _pickFromLibrary();
        case CameraUnavailable():
          // No in-app camera (web, or a denied permission). The system camera
          // is still a way through.
          final picked = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: pickerImageQuality,
          );
          await _cropInto(await picked?.readAsBytes());
        case null:
          break; // backed out
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromLibrary() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Also normalizes EXIF orientation on Android, which the crop screen
      // relies on — it does not read the orientation tag itself.
      imageQuality: pickerImageQuality,
    );
    await _cropInto(await picked?.readAsBytes());
  }

  /// Picks a video from the library.
  ///
  /// Gallery only — there is no in-app video recording yet (`CameraScreen` is
  /// stills, `enableAudio: false`). This is the same path chat already uses, so
  /// it inherits the poster extraction, the size cap and the web caveats
  /// wholesale rather than growing a second video pipeline.
  Future<void> _pickVideo() async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;

      // Before readAsBytes, and only off web: `XFile.path` is a real
      // filesystem path on mobile, which is what the extractor needs. On web
      // it is a `blob:` URL with nothing behind it, and video_thumbnail has no
      // web implementation to receive it — so a video composed there keeps the
      // play glyph permanently. That is a designed state, not a placeholder.
      final poster = kIsWeb ? null : await VideoPoster.extract(picked.path);
      final bytes = await picked.readAsBytes();

      if (!mounted) return;
      if (bytes.length > kMaxFileUploadBytes) {
        // Refused at PICK time rather than at upload time on purpose: past the
        // repository's retained-bytes cap a failed send has no bytes left to
        // retry from, which is a dead end.
        setState(() => _errorCode = 'TOO_BIG');
        return;
      }
      setState(() {
        _video = (bytes: bytes, poster: poster, name: picked.name);
        _image = null;
        _errorCode = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cropInto(Uint8List? source) async {
    if (source == null || !mounted) return;
    final cropped = await ImageCropScreen.open(
      context,
      source: source,
      shape: CropShape.rect,
    );
    if (!mounted || cropped == null) return;
    setState(() {
      _image = cropped;
      _video = null;
    });
  }

  Future<void> _post() async {
    if (!_canPost) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    // Captured before the first await: using `context` after one to read
    // localizations or pop is the async-gap trap this codebase guards
    // everywhere.
    final navigator = Navigator.of(context);
    try {
      final uploader = UploadService(widget.api);
      String? storageId;
      String? posterId;
      var kind = MomentMedia.none;

      final image = _image;
      final video = _video;
      if (image != null) {
        storageId = await uploader.uploadFile(
          bytes: image.bytes,
          contentType: image.contentType,
        );
        kind = MomentMedia.image;
      } else if (video != null) {
        // Poster first, best-effort: if it fails the video still sends and the
        // card falls back to the play glyph, which is the same outcome web and
        // desktop get permanently.
        final posterBytes = video.poster;
        if (posterBytes != null) {
          try {
            posterId = await uploader.uploadFile(
              bytes: posterBytes,
              contentType: 'image/jpeg',
            );
          } catch (_) {/* the glyph is a fine fallback */}
        }
        storageId = await uploader.uploadFile(
          bytes: video.bytes,
          contentType: mimeTypeForFileName(video.name),
        );
        kind = MomentMedia.video;
      }
      await widget.feedApi.post(
        userId: widget.userId,
        // The AUTHOR's local day — the server cannot derive it, and assuming
        // UTC would file an evening moment under tomorrow for half the world.
        dayKey: FeedStore.instance.dayKey,
        caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
        mediaStorageId: storageId,
        posterStorageId: posterId,
        mediaKind: kind,
      );
      if (!mounted) return;
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      // Convex wraps thrown errors in a longer server string, so these are
      // matched by substring — equality never works here.
      final s = e.toString();
      setState(() {
        _busy = false;
        _errorCode = [
          'DAILY_CAP_REACHED',
          'CHILD_NOT_ALLOWED',
          'CAPTION_TOO_LONG',
          'EMPTY_MOMENT',
        ].firstWhere(s.contains, orElse: () => 'UNKNOWN');
      });
    }
  }

  String _errorText(AppLocalizations l10n) => switch (_errorCode) {
    'DAILY_CAP_REACHED' => l10n.momentComposerErrorDailyCap,
    'CHILD_NOT_ALLOWED' => l10n.momentComposerErrorNotAllowed,
    'CAPTION_TOO_LONG' => l10n.momentComposerErrorTooLong,
    'EMPTY_MOMENT' => l10n.momentComposerErrorEmpty,
    'TOO_BIG' => l10n.momentComposerErrorTooBig,
    _ => l10n.momentComposerErrorGeneric,
  };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final remaining = _maxCaption - _caption.text.characters.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        // Lift clear of the keyboard: this sheet's whole content is a text
        // field and a button, and both must stay reachable while typing.
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: theme.sheetDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.momentComposerTitle, style: theme.displaySmall),
          const SizedBox(height: 16),
          _MediaSlot(
            image: _image,
            video: _video,
            busy: _busy,
            onCapture: _capture,
            onLibrary: _pickFromLibrary,
            onVideo: _pickVideo,
            onClear: () => setState(() {
              _image = null;
              _video = null;
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _caption,
            maxLines: 3,
            minLines: 1,
            enabled: !_busy,
            style: theme.body,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.momentComposerCaptionHint,
              hintStyle: theme.bodySoft.copyWith(color: theme.inkMuted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Spacer(),
              // Only warn as the limit approaches — a permanent counter on a
              // 280-character field is noise for the 280th of posts that get
              // anywhere near it.
              if (remaining <= 40)
                Text(
                  '$remaining',
                  style: theme.monoTiny.copyWith(
                    color: remaining < 0 ? theme.danger : theme.inkMuted,
                  ),
                ),
            ],
          ),
          if (_errorCode != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText(l10n),
              style: theme.bodySoft.copyWith(color: theme.danger),
            ),
          ],
          const SizedBox(height: 18),
          _PostButton(
            enabled: _canPost && remaining >= 0,
            busy: _busy,
            onTap: _post,
          ),
        ],
      ),
    );
  }
}

/// The picture slot: two buttons when empty, the framed shot when full.
class _MediaSlot extends StatelessWidget {
  const _MediaSlot({
    required this.image,
    required this.video,
    required this.busy,
    required this.onCapture,
    required this.onLibrary,
    required this.onVideo,
    required this.onClear,
  });

  final CroppedImage? image;
  final ({Uint8List bytes, Uint8List? poster, String name})? video;
  final bool busy;
  final VoidCallback onCapture;
  final VoidCallback onLibrary;
  final VoidCallback onVideo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final img = image;
    final vid = video;

    if (vid != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusLg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: vid.poster != null
                  // Image.memory, not RemoteImage: nothing is uploaded yet.
                  ? Image.memory(vid.poster!, fit: BoxFit.cover)
                  : ColoredBox(color: theme.surfaceSunken),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 34,
                // On web and desktop there is no poster at all — video_thumbnail
                // has no implementation there — so this glyph over a flat
                // surface is the designed state, not a loading placeholder.
                color: theme.ink.withValues(alpha: 0.85),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: FocusableTap(
              onTap: busy ? null : onClear,
              semanticLabel: l10n.momentComposerRemovePhoto,
              shape: FocusRingShape.circle,
              child: GestureDetector(
                onTap: busy ? null : onClear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.divider),
                  ),
                  child: Icon(Icons.close, size: 14, color: theme.inkSoft),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (img != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radiusLg),
            child: AspectRatio(
              aspectRatio: img.width / img.height,
              // Image.memory, not RemoteImage: these bytes have not been
              // uploaded yet and there is no storage id to resolve.
              child: Image.memory(img.bytes, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: FocusableTap(
              onTap: busy ? null : onClear,
              semanticLabel: l10n.momentComposerRemovePhoto,
              shape: FocusRingShape.circle,
              child: GestureDetector(
                onTap: busy ? null : onClear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.divider),
                  ),
                  child: Icon(Icons.close, size: 14, color: theme.inkSoft),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _SlotButton(
            icon: Icons.photo_camera_outlined,
            label: l10n.momentComposerCapture,
            onTap: busy ? null : onCapture,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SlotButton(
            icon: Icons.photo_library_outlined,
            label: l10n.momentComposerLibrary,
            onTap: busy ? null : onLibrary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SlotButton(
            icon: Icons.videocam_outlined,
            label: l10n.momentComposerVideo,
            onTap: busy ? null : onVideo,
          ),
        ),
      ],
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: theme.surfaceSunken,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(color: theme.divider),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: theme.accent),
                const SizedBox(height: 8),
                Text(label, style: theme.monoTiny, maxLines: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  const _PostButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: enabled ? onTap : null,
      semanticLabel: l10n.momentComposerPost,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: enabled ? theme.accent : theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          alignment: Alignment.center,
          child: busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(theme.accentInk),
                  ),
                )
              : Text(
                  l10n.momentComposerPost,
                  style: theme.label.copyWith(
                    color: enabled ? theme.accentInk : theme.inkMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
