import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/image_raster.dart';
import '../../media/photo_picking.dart';
import '../../media/upload_service.dart';
import '../../models/moment.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/moment_rail.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/meta_text.dart';
import '../../widgets/sheet_kit.dart' show sentenceCaseOf;
import '../camera_editor_screen.dart';
import '../camera_screen.dart';
import 'points_explainer.dart';

/// Logs a point: what happened, and which kind of thing it was.
///
/// **Deliberately not the highlight composer.** They write the same row, but
/// they are different acts. A highlight starts with a picture — you saw
/// something and want to show it. A point starts with a sentence — "washed the
/// car, it rained at four" — and a photo is usually beside the point, sometimes
/// impossible, and never the reason you are here. Making people open a camera
/// sheet to type one line was the single biggest thing wrong with the first
/// version of this.
///
/// So: the category is picked first (it is what makes this a point at all), the
/// text field is focused on open, and the photo is optional and last.
///
/// **Optional is not the same as second-class.** For a long time the only way
/// to attach one here was the library — you could photograph the thing your
/// point is about, leave the app, save it, come back and go looking for it.
/// The camera is the shorter half of that, and it is the same in-app camera and
/// the same cropper the highlight composer uses, right down to RETAKE.
Future<bool> showPointComposer(
  BuildContext context, {
  required ChatApi api,
  required FeedApi feedApi,
  required String userId,
  MomentTag? initialTag,
}) async {
  final posted = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _PointComposer(
      api: api,
      feedApi: feedApi,
      userId: userId,
      initialTag: initialTag,
    ),
  );
  return posted == true;
}

class _PointComposer extends StatefulWidget {
  const _PointComposer({
    required this.api,
    required this.feedApi,
    required this.userId,
    this.initialTag,
  });

  final ChatApi api;
  final FeedApi feedApi;
  final String userId;
  final MomentTag? initialTag;

  @override
  State<_PointComposer> createState() => _PointComposerState();
}

class _PointComposerState extends State<_PointComposer> {
  final _note = TextEditingController();
  final _focus = FocusNode();
  MomentTag? _tag;
  CroppedImage? _image;

  /// The bytes the crop was made FROM.
  ///
  /// Re-editing has to start from the original, not from the previous export:
  /// cropping a crop re-encodes a JPEG that was already re-encoded, and three
  /// passes of that is visibly mushy. Same reasoning, and the same cost, as the
  /// highlight composer's.
  Uint8List? _imageSource;
  bool _sourceMirrored = false;

  bool _busy = false;
  String? _errorCode;

  /// Matches `MAX_CAPTION` in backend/convex/feed.ts.
  static const _maxNote = 280;

  @override
  void initState() {
    super.initState();
    _tag = widget.initialTag;
    _note.addListener(_onTyped);
    // A point is a sentence. Opening straight into the keyboard is the whole
    // difference between "log it in four seconds" and "log it later, probably
    // never".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _note.removeListener(_onTyped);
    _note.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTyped() => setState(() {});

  /// A point MUST have a category — that is what distinguishes it from a
  /// highlight. Text is optional in principle (the tag alone says something)
  /// but the button stays off until there is either a note or a photo, because
  /// a bare tally mark with no story is not worth anyone's attention.
  bool get _canPost =>
      !_busy &&
      _tag != null &&
      (_note.text.trim().isNotEmpty || _image != null);

  /// Shoot one now.
  ///
  /// Lifted wholesale from the highlight composer rather than reinvented: the
  /// in-app camera, reviewing in the cropper ON TOP of the still-mounted camera
  /// route (which is what makes RETAKE free), and the two fallbacks — the OS
  /// picker when the library button is used from inside it, and the system
  /// camera on web or a denied permission.
  Future<void> _capture() async {
    // Resolved before the first await: `AppLocalizations.of` after one is the
    // lint this repo treats as an error.
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      // Captured out of the review closure so re-editing can start from the
      // ORIGINAL frame rather than the JPEG the editor exported.
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
            // contract of `CameraScreen.review` — so RETAKE restores the live
            // preview instead of unwinding to this sheet.
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
              _errorCode = null;
            });
          }
        case CameraRecorded():
        // Unreachable: opened with `allowVideo` left off, so the VIDEO position
        // never appears and nothing can record. Named rather than defaulted so
        // that turning video on here becomes a compile error to answer rather
        // than a clip silently dropped.
        break;
        case CameraPickLibrary():
          await _pickFromLibrary();
        case CameraUnavailable():
          // No in-app camera (web, or a denied permission). The system camera
          // is still a way through.
          final picked = await pickPhoto(source: ImageSource.camera);
          if (picked.unreadable) {
            if (mounted) setState(() => _errorCode = 'PICK_FAILED');
            return;
          }
          await _cropInto(await picked.file?.readAsBytes());
        case null:
          break; // backed out
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Choose one that already exists.
  Future<void> _pickPhoto() async {
    setState(() => _busy = true);
    try {
      await _pickFromLibrary();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromLibrary() async {
    // The `pickerImageQuality` [pickPhoto] passes also normalizes EXIF
    // orientation on Android, which the crop screen relies on — it does not
    // read the orientation tag itself.
    final pick = await pickPhoto(source: ImageSource.gallery);
    // Reported on the composer's own error line, where the post failures go —
    // a refusal that said nothing would look like a picture the composer had
    // rejected.
    if (pick.unreadable) {
      if (mounted) setState(() => _errorCode = 'PICK_FAILED');
      return;
    }
    await _cropInto(await pick.file?.readAsBytes());
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
      _errorCode = null;
    });
  }

  /// Re-opens the cropper on the ORIGINAL bytes.
  ///
  /// Backing out of the crop screen used to drop you back here with no way to
  /// return to it short of picking the photo again — which is exactly the
  /// moment you have just changed your mind twice and are least willing to.
  Future<void> _editImage() async {
    final source = _imageSource;
    if (source == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _cropInto(source, mirrored: _sourceMirrored);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    if (!_canPost) return;
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    final navigator = Navigator.of(context);
    try {
      String? storageId;
      final image = _image;
      if (image != null) {
        storageId = await UploadService(
          widget.api,
        ).uploadFile(bytes: image.bytes, contentType: image.contentType);
      }
      await widget.feedApi.post(
        userId: widget.userId,
        dayKey: FeedStore.instance.dayKey,
        tag: _tag,
        caption: _note.text.trim().isEmpty ? null : _note.text.trim(),
        mediaStorageId: storageId,
        mediaKind: storageId == null ? MomentMedia.none : MomentMedia.image,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      setState(() {
        _busy = false;
        _errorCode = [
          'DAILY_CAP_REACHED',
          'CHILD_NOT_ALLOWED',
          'CAPTION_TOO_LONG',
        ].firstWhere(s.contains, orElse: () => 'UNKNOWN');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final remaining = _maxNote - _note.text.characters.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: theme.sheetDecoration(),
      // Scrolls, and is bounded — the same fix the highlight composer already
      // carries. An unscrollable Column in an `isScrollControlled` sheet simply
      // clips whatever runs past the viewport, and with the keyboard up and a
      // photo attached what got clipped was ADD POINT itself: the button you
      // need to finish is the one that disappears.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sentenceCaseOf(context, l10n.pointComposerTitle),
                      style: theme.displaySmall.copyWith(color: theme.ink),
                    ),
                  ),
                  // The concept needs explaining — "kerizlik points" is not a thing
                  // anyone has met before. One tap, right where the question
                  // occurs to you.
                  _WhatIsThis(onTap: () => showPointsExplainer(context)),
                ],
              ),
              const SizedBox(height: 16),
              _TagGrid(
                selected: _tag,
                enabled: !_busy,
                onPick: (t) {
                  setState(() => _tag = t);
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                focusNode: _focus,
                maxLines: 4,
                minLines: 2,
                enabled: !_busy,
                style: theme.body,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _tag == null
                      ? l10n.pointComposerNoteHint
                      : MomentTagChip.exampleFor(l10n, _tag!),
                  hintStyle: theme.bodySoft.copyWith(color: theme.inkMuted),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              if (_image != null) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                      // Capped at the same 300 the highlight composer's `_MediaSlot`
                      // uses. A 9:16 portrait rendered at its true ratio is taller
                      // than the sheet on its own; keep the two in step.
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: AspectRatio(
                          aspectRatio: _image!.width / _image!.height,
                          child: Image.memory(_image!.bytes, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Row(
                        children: [
                          // Only when the original bytes were kept — a re-crop
                          // has to start from those, never from the export.
                          if (_imageSource != null) ...[
                            _PhotoChip(
                              icon: CupertinoIcons.crop,
                              label: l10n.momentComposerEditPhoto,
                              onTap: _busy ? null : _editImage,
                            ),
                            const SizedBox(width: 6),
                          ],
                          _PhotoChip(
                            icon: CupertinoIcons.xmark,
                            label: l10n.momentComposerRemovePhoto,
                            onTap: _busy
                                ? null
                                : () => setState(() {
                                    _image = null;
                                    _imageSource = null;
                                  }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                Text(switch (_errorCode) {
                  'DAILY_CAP_REACHED' => l10n.momentComposerErrorDailyCap,
                  'CHILD_NOT_ALLOWED' => l10n.momentComposerErrorNotAllowed,
                  'CAPTION_TOO_LONG' => l10n.momentComposerErrorTooLong,
                  'PICK_FAILED' => l10n.mediaPickFailedMessage,
                  _ => l10n.momentComposerErrorGeneric,
                }, style: theme.bodySoft.copyWith(color: theme.danger)),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  // Two ways in, both offered — the camera FIRST, because a
                  // point is usually logged in the thirty seconds after the
                  // thing happened, when the picture does not exist yet.
                  // Hidden once there is a photo: the chips on the preview own
                  // changing it from there.
                  if (_image == null) ...[
                    _SourceButton(
                      icon: CupertinoIcons.camera_fill,
                      label: l10n.momentComposerCapture,
                      onTap: _busy ? null : _capture,
                    ),
                    const SizedBox(width: 8),
                    _SourceButton(
                      icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                      label: l10n.momentComposerLibrary,
                      onTap: _busy ? null : _pickPhoto,
                    ),
                  ],
                  const Spacer(),
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
              const SizedBox(height: 14),
              _AddButton(
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

/// One of the two ways to attach a picture.
///
/// A bordered capsule rather than the highlight composer's big square tiles:
/// there the picture is the *point* and its slot deserves the room, here it is
/// an afterthought that must not out-shout the sentence above it or push ADD
/// POINT down the sheet.
class _SourceButton extends StatelessWidget {
  const _SourceButton({
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
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          // Matches the rail's capture tile: show the control dimmed rather
          // than hiding it, so the surface still makes sense while it is busy.
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: theme.accent),
                const SizedBox(width: 6),
                Text(
                  sentenceCaseOf(context, label),
                  style: metaText(theme, color: theme.ink),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small circular control floating over the chosen picture — re-crop, remove.
///
/// A near-twin of the highlight composer's `_SlotChip`, and deliberately so:
/// the two composers put the same two controls in the same corner of the same
/// preview, and a 5pt-vs-6pt difference between them is the kind of drift
/// nobody notices and everybody feels.
class _PhotoChip extends StatelessWidget {
  const _PhotoChip({
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

/// The five categories as a two-row grid.
///
/// A grid rather than the highlight composer's scrolling chip row: here the
/// category is the FIRST decision, not an afterthought, so every option has to
/// be visible at once. A horizontal scroller hides two of five behind a swipe
/// nobody performs.
class _TagGrid extends StatelessWidget {
  const _TagGrid({
    required this.selected,
    required this.enabled,
    required this.onPick,
  });

  final MomentTag? selected;
  final bool enabled;
  final void Function(MomentTag) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in MomentTag.values)
          _TagChoice(
            key: ValueKey(t.wire),
            tag: t,
            label: MomentTagChip.labelFor(l10n, t),
            hint: MomentTagChip.hintFor(l10n, t),
            active: selected == t,
            onTap: enabled ? () => onPick(t) : null,
          ),
      ],
    );
  }
}

class _TagChoice extends StatelessWidget {
  const _TagChoice({
    super.key,
    required this.tag,
    required this.label,
    required this.hint,
    required this.active,
    required this.onTap,
  });

  final MomentTag tag;
  final String label;
  final String hint;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: '$label — $hint',
      selected: active,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active
                ? theme.bubbleFill(isMine: true)
                : theme.ink.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MomentTagChip.iconFor(tag),
                    size: 13,
                    // accentInk on an accent fill, never white — NeonNight's
                    // accent is pure yellow and Graphite's is near-white.
                    color: active ? theme.accentInk : theme.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sentenceCaseOf(context, label),
                    style: labelText(
                      theme,
                      color: active ? theme.accentInk : theme.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                sentenceCaseOf(context, hint),
                style: metaText(
                  theme,
                  color: active
                      ? theme.accentInk.withValues(alpha: 0.85)
                      : theme.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small circled question mark that opens the explainer.
class _WhatIsThis extends StatelessWidget {
  const _WhatIsThis({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: l10n.pointsExplainerOpen,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.question_circle, size: 14, color: theme.accent),
              const SizedBox(width: 5),
              Text(
                sentenceCaseOf(context, l10n.pointsExplainerOpen),
                style: metaText(theme, color: theme.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
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
      semanticLabel: l10n.pointComposerAdd,
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(theme.accentInk),
                ),
              )
            : Text(
                sentenceCaseOf(context, l10n.pointComposerAdd),
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
