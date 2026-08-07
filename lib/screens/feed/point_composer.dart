import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/chat_api.dart';
import '../../backend/feed_api.dart';
import '../../data/feed_store.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/image_raster.dart';
import '../../media/upload_service.dart';
import '../../models/moment.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/moment_rail.dart';
import '../image_crop_screen.dart';
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
/// text field is focused on open, and the photo is one optional button at the
/// bottom.
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

  Future<void> _pickPhoto() async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: pickerImageQuality,
      );
      final bytes = await picked?.readAsBytes();
      if (bytes == null || !mounted) return;
      final cropped = await ImageCropScreen.open(
        context,
        source: bytes,
        shape: CropShape.rect,
        ratioChoices: const [null, 1.0, 4 / 5, 16 / 9],
      );
      if (!mounted || cropped == null) return;
      setState(() => _image = cropped);
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
        storageId = await UploadService(widget.api).uploadFile(
          bytes: image.bytes,
          contentType: image.contentType,
        );
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
        _errorCode = ['DAILY_CAP_REACHED', 'CHILD_NOT_ALLOWED', 'CAPTION_TOO_LONG']
            .firstWhere(s.contains, orElse: () => 'UNKNOWN');
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l10n.pointComposerTitle, style: theme.displaySmall),
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
                  child: AspectRatio(
                    aspectRatio: _image!.width / _image!.height,
                    child: Image.memory(_image!.bytes, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: FocusableTap(
                    onTap: () => setState(() => _image = null),
                    semanticLabel: l10n.momentComposerRemovePhoto,
                    shape: FocusRingShape.circle,
                    child: GestureDetector(
                      onTap: () => setState(() => _image = null),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.divider),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: theme.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_errorCode != null) ...[
            const SizedBox(height: 12),
            Text(
              switch (_errorCode) {
                'DAILY_CAP_REACHED' => l10n.momentComposerErrorDailyCap,
                'CHILD_NOT_ALLOWED' => l10n.momentComposerErrorNotAllowed,
                'CAPTION_TOO_LONG' => l10n.momentComposerErrorTooLong,
                _ => l10n.momentComposerErrorGeneric,
              },
              style: theme.bodySoft.copyWith(color: theme.danger),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (_image == null)
                FocusableTap(
                  onTap: _busy ? null : _pickPhoto,
                  semanticLabel: l10n.pointComposerAddPhoto,
                  radius: theme.radiusMd,
                  child: GestureDetector(
                    onTap: _busy ? null : _pickPhoto,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 15,
                          color: theme.inkSoft,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.pointComposerAddPhoto,
                          style: theme.monoTiny,
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (remaining <= 40)
                Text(
                  '$remaining',
                  style: theme.monoTiny.copyWith(
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
            color: active ? theme.accent : theme.surfaceSunken,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: active ? theme.accent : theme.divider),
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
                    label,
                    style: theme.label.copyWith(
                      color: active ? theme.accentInk : theme.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                style: theme.monoTiny.copyWith(
                  color: active ? theme.accentInk : theme.inkMuted,
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
            color: theme.surfaceSunken,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.help_outline, size: 12, color: theme.accent),
              const SizedBox(width: 5),
              Text(
                l10n.pointsExplainerOpen,
                style: theme.monoTiny.copyWith(color: theme.accent),
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
    return FocusableTap(
      onTap: enabled ? onTap : null,
      semanticLabel: l10n.pointComposerAdd,
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
                  l10n.pointComposerAdd,
                  style: theme.label.copyWith(
                    color: enabled ? theme.accentInk : theme.inkMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
