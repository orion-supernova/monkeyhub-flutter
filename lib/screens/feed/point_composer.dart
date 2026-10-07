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
import '../../widgets/photo_chrome.dart' show MediaOverlayChip;
import '../../widgets/sheet_kit.dart';

import '../camera_editor_screen.dart';
import '../camera_screen.dart';
import 'points_explainer.dart';
import '../../l10n/text_case.dart';

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
  // Kept below the Dynamic Island by `showAdaptiveSheet`'s default.
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
  final _fieldKey = GlobalKey();
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
    _focus.addListener(_onFocus);
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
    _focus.removeListener(_onFocus);
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
            // Never popped here: this flow keeps one photo, so the editor
            // offers no "add from library".
            EditorAddFromLibrary() => const ReviewRetake<EditorSend>(),
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

  /// Keeps the note field in view once the keyboard is up. The body scrolls
  /// (a [SheetScrollBody]); without this, focusing the field on a small phone
  /// left it under the keyboard with the grid filling the view.
  void _onFocus() {
    if (!_focus.hasFocus) return;
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      final target = _fieldKey.currentContext;
      if (!mounted || target == null || !target.mounted) return;
      if (!_focus.hasFocus) return;
      Scrollable.ensureVisible(
        target,
        alignment: 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final remaining = _maxNote - _note.text.characters.length;
    final over = remaining < 0;

    // The footer button says what is missing rather than just greying out —
    // a disabled "Add a point" under five unpicked chips reads as broken.
    final String action;
    if (_tag == null) {
      action = l10n.pointComposerPickFirst;
    } else {
      action = l10n.pointComposerAdd;
    }

    // The shared sheet: × leading (the app's one chrome disc), the question
    // as the title, and the commit pinned as the footer — always on screen,
    // riding above the keyboard, however tall the body gets. No ✓ in the bar:
    // the footer button is the single commit.
    //
    // No height cap and no scroll view of its own. The old 0.82-screen
    // ConstrainedBox plus the keyboard inset asked for more than the screen,
    // the route clipped the TOP — the bar, under the Dynamic Island — and the
    // body's own scroll view ate every downward drag, so the sheet could not
    // be swiped away. `showAdaptiveSheet` now keeps the sheet below the
    // island, and [SheetScrollBody] hands a pull from the top to the sheet.
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.pointComposerTitle),
      padding: EdgeInsets.zero,
      footer: SheetActionButton(
        label: action,
        busy: _busy,
        onTap: _canPost && !over ? _post : null,
      ),
      child: SheetScrollBody(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The decision first: the category is what makes this a point.
            _TagGrid(
              selected: _tag,
              enabled: !_busy,
              onPick: (t) {
                setState(() => _tag = t);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(height: 6),
            // "Kerizlik points" is not a thing anyone has met before, so the
            // explainer is one tap away — under the choices it explains, not
            // above them where it used to push the decision down.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextLinkButton(
                label: l10n.pointsExplainerOpen,
                icon: CupertinoIcons.chevron_forward,
                fontSize: 15,
                onTap: () => showPointsExplainer(context),
              ),
            ),
            const SizedBox(height: 10),
            // The shared composer field, with the countdown inside it once
            // it matters.
            SheetTextField(
              key: _fieldKey,
              controller: _note,
              focusNode: _focus,
              maxLines: 6,
              minLines: 3,
              enabled: !_busy,
              hint: _tag == null
                  ? l10n.pointComposerNoteHint
                  : MomentTagChip.exampleFor(l10n, _tag!),
              trailing: remaining <= 40
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 8, 13),
                      child: Text(
                        '$remaining',
                        style: groupedMetaStyle(theme).copyWith(
                          color: over ? theme.danger : theme.inkMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            if (_image == null)
              // Two ways in, both offered — the camera FIRST, because a
              // point is usually logged in the thirty seconds after the
              // thing happened, when the picture does not exist yet.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SourceButton(
                    icon: CupertinoIcons.camera_fill,
                    label: l10n.momentComposerCapture,
                    onTap: _busy ? null : _capture,
                  ),
                  _SourceButton(
                    icon: CupertinoIcons.photo_fill_on_rectangle_fill,
                    label: l10n.momentComposerLibrary,
                    onTap: _busy ? null : _pickPhoto,
                  ),
                ],
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _Thumb(
                  image: _image!,
                  canEdit: _imageSource != null && !_busy,
                  onEdit: _editImage,
                  onRemove: _busy
                      ? null
                      : () => setState(() {
                          _image = null;
                          _imageSource = null;
                        }),
                ),
              ),
            if (_errorCode != null) ...[
              const SizedBox(height: 12),
              FormErrorBanner(switch (_errorCode) {
                'DAILY_CAP_REACHED' => l10n.momentComposerErrorDailyCap,
                'CHILD_NOT_ALLOWED' => l10n.momentComposerErrorNotAllowed,
                'CAPTION_TOO_LONG' => l10n.momentComposerErrorTooLong,
                'PICK_FAILED' => l10n.mediaPickFailedMessage,
                _ => l10n.momentComposerErrorGeneric,
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// The attached photo, small: an 88pt rounded thumbnail. Tap it to re-crop;
/// the × chip removes it.
///
/// Small on purpose. The old preview rendered up to 300pt tall, and a
/// portrait photo pushed the note and the button off the sheet — the picture
/// is the footnote of a point, not its body.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.image,
    required this.canEdit,
    required this.onEdit,
    required this.onRemove,
  });

  final CroppedImage image;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox.square(
      dimension: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SpringPress(
              onTap: canEdit ? onEdit : null,
              semanticLabel: l10n.momentComposerEditPhoto,
              focusRadius: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  image.bytes,
                  fit: BoxFit.cover,
                  // Decoded at thumbnail size, not the full crop.
                  cacheWidth: (88 * dpr).round(),
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: MediaOverlayChip(
              icon: CupertinoIcons.xmark,
              semanticLabel: l10n.momentComposerRemovePhoto,
              onTap: onRemove,
            ),
          ),
        ],
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
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      focusShape: FocusRingShape.capsule,
      child: Opacity(
        // Matches the rail's capture tile: show the control dimmed rather
        // than hiding it, so the surface still makes sense while it is busy.
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: quietFill(theme),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: theme.accent),
              const SizedBox(width: 6),
              Text(
                sentenceCaseOf(context, label),
                style: groupedSubtitleStyle(theme).copyWith(color: theme.ink),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The five categories as an equal-width grid.
///
/// A grid rather than the highlight composer's scrolling chip row: here the
/// category is the FIRST decision, not an afterthought, so every option has to
/// be visible at once. A horizontal scroller hides two of five behind a swipe
/// nobody performs.
///
/// Two equal columns, each row as tall as its taller cell, and the odd fifth
/// spanning the full width. A content-sized Wrap gave five different widths
/// and a ragged right edge that swung wildly between languages.
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
    Widget cell(MomentTag t) => _TagChoice(
          key: ValueKey(t.wire),
          tag: t,
          label: MomentTagChip.labelFor(l10n, t),
          hint: MomentTagChip.hintFor(l10n, t),
          active: selected == t,
          onTap: enabled ? () => onPick(t) : null,
        );
    const tags = MomentTag.values;
    final rows = <Widget>[];
    for (var i = 0; i < tags.length; i += 2) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(tags[i])),
              if (i + 1 < tags.length) ...[
                const SizedBox(width: 8),
                Expanded(child: cell(tags[i + 1])),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
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
    // accentInk on an accent fill, never white — NeonNight's accent is pure
    // yellow and Graphite's is near-white.
    final ink = active ? theme.accentInk : theme.ink;
    return Semantics(
      selected: active,
      child: SpringPress(
        onTap: onTap,
        semanticLabel: '$label — $hint',
        focusRadius: 14,
        child: AnimatedContainer(
          duration: theme.motionFast,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            // The accent, not bubbleFill: a picked option is a control state,
            // not a message.
            color: active ? theme.accent : quietFill(theme),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: theme.motionFast,
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? theme.accentInk.withValues(alpha: 0.18)
                          : theme.accent.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      MomentTagChip.iconFor(tag),
                      size: 15,
                      color: active ? theme.accentInk : theme.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _ChipTitle(text: sentenceCaseOf(context, label), color: ink)),
                  const SizedBox(width: 4),
                  // Its slot is always there, so picking a chip never
                  // re-wraps its title.
                  SizedBox.square(
                    dimension: 20,
                    child: AnimatedOpacity(
                      duration: theme.motionFast,
                      opacity: active ? 1 : 0,
                      child: _PickedCheck(theme: theme),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                sentenceCaseOf(context, hint),
                style: groupedMetaStyle(theme).copyWith(
                  color: active
                      ? theme.accentInk.withValues(alpha: 0.85)
                      : theme.inkMuted,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip's title: never an ellipsis, never a word broken in half.
///
/// Several words wrap onto a second line. One long word ("Demiştim" at 1.3×
/// in a phone-width half column) shrinks to fit instead — wrapping it would
/// split it mid-word. Not FitLabel: the grid's rows are IntrinsicHeight
/// (equal heights per row), and FitLabel measures with a LayoutBuilder, which
/// cannot answer intrinsic queries; a FittedBox can.
class _ChipTitle extends StatelessWidget {
  const _ChipTitle({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final style = groupedTitleStyle(theme).copyWith(
      fontWeight: FontWeight.w600,
      color: color,
    );
    if (text.trim().contains(' ')) return Text(text, style: style);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}

/// [SelectionCheck]'s picked state, inverted for a chip that is itself
/// accent-filled: an accentInk disc with an accent tick. The stock check is
/// accent on accent there — invisible.
class _PickedCheck extends StatelessWidget {
  const _PickedCheck({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.accentInk,
        ),
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.checkmark_alt,
          size: 14,
          color: theme.accent,
        ),
      );
}
