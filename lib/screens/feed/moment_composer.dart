import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/file_meta.dart';
import '../../media/image_raster.dart';
import '../../media/photo_picking.dart';
import '../../media/upload_service.dart';
import '../../media/video_poster.dart';
import '../../models/moment.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/meta_text.dart';
import '../../widgets/sheet_kit.dart';
import '../camera_editor_screen.dart';
import '../camera_screen.dart';

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
    builder: (_) => _MomentComposer(api: api, feedApi: feedApi, userId: userId),
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

  /// The bytes the crop was made FROM.
  ///
  /// Re-editing has to start from the original, not from the previous export:
  /// cropping a crop re-encodes a JPEG that was already re-encoded, and three
  /// passes of that is visibly mushy. Costs one extra buffer for the life of
  /// the sheet, which is the same order as the picked photo itself.
  Uint8List? _imageSource;
  bool _sourceMirrored = false;

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
    // Resolved before the first await: everything below crosses an async gap,
    // and `AppLocalizations.of` after one is the lint this repo treats as an
    // error.
    final l10n = AppLocalizations.of(context);
    // Raise the scrim BEFORE the picker: `ImagePicker.pickImage` with
    // `imageQuality` re-encodes the asset AFTER the native sheet has already
    // dismissed, which for a 12MP HEIC is seconds of the user staring at an
    // apparently unchanged screen.
    setState(() => _busy = true);
    try {
      // Captured out of the review closure so re-editing can start from the
      // ORIGINAL frame rather than the JPEG the editor exported. Cropping an
      // export re-encodes an already-re-encoded JPEG, and two or three passes
      // of that is visibly mushy.
      Uint8List? rawFrame;
      var rawMirrored = false;
      final result = await CameraScreen.open<EditorSend>(
        context,
        initialLens: CameraLensDirection.back,
        review: (context, photo) async {
          rawFrame = photo.bytes;
          rawMirrored = photo.mirrored;
          final outcome = await CameraEditorScreen.open(
            context,
            source: photo.bytes,
            // The camera route is still mounted underneath — that is the whole
            // contract of `CameraScreen.review` — so RETAKE can restore the
            // live preview instead of unwinding to this sheet.
            canRetake: true,
            mirrored: photo.mirrored,
            overCamera: true,
            allowDrawing: false,
            allowViewOnce: false,
            confirmLabel: l10n.imageCropScreenDefaultConfirmLabel,
            busyLabel: l10n.imageCropScreenSavingButton,
          );
          return switch (outcome) {
            EditorRetake() => const ReviewRetake<EditorSend>(),
            final EditorSend send => ReviewDone(send),
            null => const ReviewDone<EditorSend>(null),
          };
        },
      );
      if (!mounted) return;
      switch (result) {
        case CameraReviewed(:final value):
          if (value != null) {
            setState(() {
              _image = value.image;
              _imageSource = rawFrame ?? value.image.bytes;
              _sourceMirrored = rawFrame != null && rawMirrored;
              _video = null;
            });
          }
        case CameraRecorded():
        // Unreachable: this call site opens the camera with `allowVideo` left
        // off, so the VIDEO position never appears and nothing can record.
        // Named rather than defaulted so that turning video on here becomes a
        // compile error to answer rather than a clip silently dropped.
        break;
      case CameraPickLibrary():
          await _pickFromLibrary();
        case CameraUnavailable():
          // No in-app camera (web, or a denied permission). The system camera
          // is still a way through.
          final picked = await pickPhoto(source: ImageSource.camera);
          await _cropInto(await picked.file?.readAsBytes());
        case null:
          break; // backed out
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromLibrary() async {
    // The `pickerImageQuality` [pickPhoto] passes also normalizes EXIF
    // orientation on Android, which the crop screen relies on — it does not
    // read the orientation tag itself.
    final pick = await pickPhoto(source: ImageSource.gallery);
    // Down the composer's own error line rather than a snackbar: that is where
    // every other failure on this screen already goes, and a refusal that said
    // nothing would look like a picture the composer had rejected.
    if (pick.unreadable) {
      if (mounted) setState(() => _errorCode = 'PICK_FAILED');
      return;
    }
    await _cropInto(await pick.file?.readAsBytes());
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
      final pick = await pickVideo();
      if (pick.unreadable) {
        if (mounted) setState(() => _errorCode = 'PICK_FAILED');
        return;
      }
      final picked = pick.file;
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

  /// Opens the same editor chat uses — a crop rect you drag by its edges and
  /// corners, not a fixed window with the picture sliding underneath it.
  Future<void> _cropInto(Uint8List? source, {bool mirrored = false}) async {
    if (source == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final outcome = await CameraEditorScreen.open(
      context,
      source: source,
      mirrored: mirrored,
      // Nothing underneath to retake — this is a library pick or the system
      // camera, both of which have already gone away by now.
      allowDrawing: false,
      allowViewOnce: false,
      confirmLabel: l10n.imageCropScreenDefaultConfirmLabel,
      busyLabel: l10n.imageCropScreenSavingButton,
    );
    if (!mounted || outcome is! EditorSend) return;
    setState(() {
      _image = outcome.image;
      _imageSource = source;
      _sourceMirrored = mirrored;
      _video = null;
    });
  }

  /// Re-opens the cropper on the ORIGINAL bytes.
  ///
  /// Backing out of the crop screen used to drop you back here with no way to
  /// return to it short of picking the photo again — which is exactly the
  /// moment you have just changed your mind twice and are least willing to.
  Future<void> _editImage() async {
    final source = _imageSource;
    if (source == null) return;
    await _cropInto(source, mirrored: _sourceMirrored);
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
          } catch (_) {
            /* the glyph is a fine fallback */
          }
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
    'PICK_FAILED' => l10n.mediaPickFailedMessage,
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
      // Scrolls, and is bounded. A 9:16 photo previewed at full aspect ratio
      // is taller than the viewport on its own, which pushed POST off the
      // bottom of an unscrollable sheet with no way to reach it. Both halves
      // of that are fixed: the preview is capped below, and what is left over
      // scrolls.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: SheetHandle()),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  sentenceCaseOf(context, l10n.momentComposerTitle),
                  style: theme.bodyEmph.copyWith(
                    fontSize: 17,
                    color: theme.ink,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _MediaSlot(
                image: _image,
                video: _video,
                busy: _busy,
                onCapture: _capture,
                onLibrary: _pickFromLibrary,
                onVideo: _pickVideo,
                onEdit: _imageSource == null ? null : _editImage,
                onClear: () => setState(() {
                  _image = null;
                  _imageSource = null;
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
                      style: metaText(
                        theme,
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
        ),
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
    required this.onEdit,
    required this.onClear,
  });

  final CroppedImage? image;
  final ({Uint8List bytes, Uint8List? poster, String name})? video;
  final bool busy;
  final VoidCallback onCapture;
  final VoidCallback onLibrary;
  final VoidCallback onVideo;

  /// Re-opens the cropper on the original bytes. Null when there is nothing to
  /// re-edit — a video, or a camera capture whose raw frame was not kept.
  final VoidCallback? onEdit;
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
                CupertinoIcons.play_circle_fill,
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
            child: _SlotChip(
              icon: CupertinoIcons.xmark,
              label: l10n.momentComposerRemovePhoto,
              onTap: busy ? null : onClear,
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
            child: ConstrainedBox(
              // Capped. A 9:16 photo at its true aspect ratio is taller than
              // the phone, and an uncapped preview is what pushed POST off the
              // bottom of the sheet.
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: img.width / img.height,
                // Image.memory, not RemoteImage: these bytes have not been
                // uploaded yet and there is no storage id to resolve.
                child: Image.memory(img.bytes, fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Row(
              children: [
                if (onEdit != null) ...[
                  _SlotChip(
                    icon: CupertinoIcons.crop,
                    label: l10n.momentComposerEditPhoto,
                    onTap: busy ? null : onEdit,
                  ),
                  const SizedBox(width: 6),
                ],
                _SlotChip(
                  icon: CupertinoIcons.xmark,
                  label: l10n.momentComposerRemovePhoto,
                  onTap: busy ? null : onClear,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _SlotButton(
            icon: CupertinoIcons.camera_fill,
            label: l10n.momentComposerCapture,
            onTap: busy ? null : onCapture,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SlotButton(
            icon: CupertinoIcons.photo_fill_on_rectangle_fill,
            label: l10n.momentComposerLibrary,
            onTap: busy ? null : onLibrary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SlotButton(
            icon: CupertinoIcons.videocam_fill,
            label: l10n.momentComposerVideo,
            onTap: busy ? null : onVideo,
          ),
        ),
      ],
    );
  }
}

/// A small circular control floating over the media preview.
class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // A dark translucent disc over the photo — the Photos edit control —
        // so it reads on any picture, light or dark.
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: const BoxDecoration(
            color: Color(0x8C000000),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
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
    // A soft tile with its glyph in an accent disc — the share-sheet action
    // shape — dipping on a spring under the thumb.
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: theme.ink.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: quietFill(theme),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: theme.accent),
              ),
              const SizedBox(height: 8),
              Text(
                sentenceCaseOf(context, label),
                style: metaText(theme, color: theme.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
    return SpringPress(
      onTap: enabled ? onTap : null,
      semanticLabel: l10n.momentComposerPost,
      child: AnimatedContainer(
        duration: theme.motionFast,
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? theme.bubbleFill(isMine: true)
              : theme.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CupertinoActivityIndicator(
                  radius: 9,
                  color: theme.accentInk,
                ),
              )
            : Text(
                sentenceCaseOf(context, l10n.momentComposerPost),
                style: theme.body.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: enabled ? theme.accentInk : theme.inkMuted,
                ),
              ),
      ),
    );
  }
}
