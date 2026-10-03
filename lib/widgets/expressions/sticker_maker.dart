import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/chat_api.dart';
import '../../expressions/subject_cutout.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/image_raster.dart';
import '../../media/photo_picking.dart';
import '../../media/upload_service.dart';
import '../../theme/theme_scope.dart';
import '../app_toast.dart';
import '../reaction_picker_sheet.dart';
import '../meta_text.dart';

/// How a photo becomes a sticker when its subject is not lifted out.
enum StickerShape { circle, rounded, original }

/// The canvas every personal sticker is rendered onto, in pixels — the size
/// Telegram and WhatsApp both settle on.
const int kStickerCanvas = 512;

/// The server refuses a personal sticker over this (see
/// `expressions:createPersonalSticker`).
const int _kMaxStickerBytes = 1024 * 1024;

/// Picks a photo and walks the user through turning it into one of their own
/// stickers. Resolves when the sticker is saved or the user gives up.
///
/// Pushes a full-screen route, so it is only offered where one can be pushed
/// — the room screen, not the thread overlay.
Future<void> createPersonalSticker(
  BuildContext context, {
  required ChatApi api,
}) async {
  final l10n = AppLocalizations.of(context);
  final toast = AppToast.of(context);
  final nav = Navigator.of(context);
  final pick = await pickPhoto(source: ImageSource.gallery);
  if (pick.unreadable) {
    toast.show(l10n.mediaPickFailedMessage, tone: ToastTone.danger);
    return;
  }
  if (pick.files.isEmpty) return;
  final bytes = await pick.files.first.readAsBytes();
  final saved = await nav.push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => StickerMakerScreen(source: bytes, api: api),
    ),
  );
  if (saved == true) {
    toast.show(l10n.stickerMakerSaved, tone: ToastTone.success);
  }
}

/// Renders [source] as a sticker: fitted into a [canvas]-pixel square with a
/// margin, clipped to [shape] unless it is already a cut-out, and ringed with
/// a white outline — the die-cut look every messenger's stickers share, and
/// what keeps a dark subject legible on a dark theme.
///
/// The outline of a cut-out follows the subject's own silhouette: the subject
/// is stamped in white at offsets around a circle, then drawn over the top.
Future<ui.Image> renderSticker(
  ui.Image source, {
  required bool cutout,
  required StickerShape shape,
  int canvas = kStickerCanvas,
  double outline = 10,
}) async {
  final size = canvas.toDouble();
  final pad = outline + 8;
  final w = source.width.toDouble(), h = source.height.toDouble();
  final srcRect = Rect.fromLTWH(0, 0, w, h);

  // A shaped crop takes the middle square of the photo; a cut-out and the
  // original keep their own proportions.
  Rect crop = srcRect;
  if (!cutout && shape != StickerShape.original) {
    final side = math.min(w, h);
    crop = Rect.fromCenter(center: srcRect.center, width: side, height: side);
  }
  final avail = size - 2 * pad;
  final scale = avail / math.max(crop.width, crop.height);
  final dst = Rect.fromCenter(
    center: Offset(size / 2, size / 2),
    width: crop.width * scale,
    height: crop.height * scale,
  );

  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
  final paint = Paint()..filterQuality = FilterQuality.high;
  final white = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn);

  if (cutout) {
    const steps = 24;
    for (var i = 0; i < steps; i++) {
      final a = i * 2 * math.pi / steps;
      c.drawImageRect(source, crop,
          dst.shift(Offset(math.cos(a) * outline, math.sin(a) * outline)),
          white);
    }
    c.drawImageRect(source, crop, dst, paint);
  } else {
    final Path path;
    switch (shape) {
      case StickerShape.circle:
        path = Path()..addOval(dst);
      case StickerShape.rounded:
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(dst, Radius.circular(dst.width * 0.18)));
      case StickerShape.original:
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(dst, const Radius.circular(18)));
    }
    // The ring: the shape itself, grown by the outline, in white.
    final ring = Path()
      ..addPath(path, Offset.zero)
      ..fillType = PathFillType.nonZero;
    c.drawPath(
      ring,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline * 2
        ..strokeJoin = StrokeJoin.round,
    );
    c.save();
    c.clipPath(path);
    c.drawImageRect(source, crop, dst, paint);
    c.restore();
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(canvas, canvas);
  picture.dispose();
  return image;
}

class StickerMakerScreen extends StatefulWidget {
  const StickerMakerScreen({
    super.key,
    required this.source,
    required this.api,
  });

  final Uint8List source;
  final ChatApi api;

  @override
  State<StickerMakerScreen> createState() => _StickerMakerScreenState();
}

class _StickerMakerScreenState extends State<StickerMakerScreen> {
  static const _quickEmoji = ['🙂', '😂', '😍', '😎', '🥳', '👍', '❤️', '😭'];

  ui.Image? _photo;
  ui.Image? _cutoutImage;
  bool _cutoutAvailable = false;
  bool _useCutout = false;
  bool _working = true;
  bool _saving = false;
  StickerShape _shape = StickerShape.circle;
  String _emoji = _quickEmoji.first;
  ui.Image? _preview;
  int _renderGen = 0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _photo?.dispose();
    _cutoutImage?.dispose();
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      // Decoded at a bounded size: a 12 MP photo is far more than a 512px
      // sticker needs, and the cut-out model is no better for the extra.
      final photo = await decodeImageBytes(widget.source, maxEdge: 1600);
      if (!mounted) {
        photo.dispose();
        return;
      }
      _photo = photo;
      final cut = await SubjectCutout.cutout(widget.source);
      if (cut != null) {
        _cutoutImage = await decodeImageBytes(cut, maxEdge: 1600);
      }
      if (!mounted) return;
      setState(() {
        _cutoutAvailable = _cutoutImage != null;
        _useCutout = _cutoutAvailable;
        _working = false;
      });
      await _render();
    } catch (e) {
      debugPrint('[sticker-maker] prepare failed: $e');
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _render() async {
    final source = _useCutout ? _cutoutImage : _photo;
    if (source == null) return;
    final gen = ++_renderGen;
    final image = await renderSticker(source, cutout: _useCutout, shape: _shape);
    if (!mounted || gen != _renderGen) {
      image.dispose();
      return;
    }
    setState(() {
      _preview?.dispose();
      _preview = image;
    });
  }

  Future<void> _pickMoreEmoji() async {
    final e = await showReactionPicker(context);
    if (e != null && mounted) setState(() => _emoji = e);
  }

  Future<void> _save() async {
    final source = _useCutout ? _cutoutImage : _photo;
    if (source == null || _saving) return;
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    setState(() => _saving = true);
    try {
      Uint8List? png;
      // Smaller canvases until it fits the server's cap. A detailed photo at
      // 512px is occasionally over a megabyte as PNG; 384px never is.
      for (final size in const [kStickerCanvas, 448, 384]) {
        final image = await renderSticker(source,
            cutout: _useCutout, shape: _shape, canvas: size);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (data == null) continue;
        png = data.buffer.asUint8List();
        if (png.length <= _kMaxStickerBytes) break;
      }
      if (png == null || png.length > _kMaxStickerBytes) {
        throw StateError('sticker too large');
      }
      final storageId = await UploadService(widget.api)
          .uploadFile(bytes: png, contentType: 'image/png');
      await widget.api.createPersonalSticker(
        storageId: storageId,
        emoji: _emoji,
        width: kStickerCanvas.toDouble(),
        height: kStickerCanvas.toDouble(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[sticker-maker] save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      toast.show(
        e.toString().contains('TOO_MANY_STICKERS')
            ? l10n.stickerMakerTooMany
            : l10n.stickerMakerFailed,
        tone: ToastTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final ready = !_working && _preview != null;
    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: DefaultTextStyle(
          style: theme.body.copyWith(
            color: theme.ink,
            decoration: TextDecoration.none,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                child: Row(
                  children: [
                    FocusableTap(
                      onTap: () => Navigator.of(context).pop(false),
                      semanticLabel:
                          MaterialLocalizations.of(context).closeButtonLabel,
                      shape: FocusRingShape.circle,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(false),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(CupertinoIcons.xmark,
                              size: 20, color: theme.ink),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l10n.stickerMakerTitle,
                        textAlign: TextAlign.center,
                        style: theme.bodyEmph,
                      ),
                    ),
                    FocusableTap(
                      onTap: ready && !_saving ? _save : null,
                      semanticLabel: l10n.stickerMakerSave,
                      radius: 999,
                      child: GestureDetector(
                        onTap: ready && !_saving ? _save : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: ready
                                ? theme.accent
                                : theme.ink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: _saving
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CupertinoActivityIndicator(
                                    color: theme.accentInk,
                                    radius: 8,
                                  ),
                                )
                              : Text(
                                  l10n.stickerMakerSave,
                                  style: labelText(theme).copyWith(
                                    color: ready
                                        ? theme.accentInk
                                        : theme.inkMuted,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(theme.radiusLg),
                        child: CustomPaint(
                          painter: _Checkerboard(
                            a: theme.surfaceRaised,
                            b: theme.surfaceSunken,
                          ),
                          child: _preview == null
                              ? const Center(child: CupertinoActivityIndicator())
                              : Semantics(
                                  image: true,
                                  label: l10n.stickerMakerPreview,
                                  child: RawImage(
                                    image: _preview,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_cutoutAvailable)
                _OptionRow(
                  label: l10n.stickerMakerRemoveBackground,
                  child: CupertinoSwitch(
                    value: _useCutout,
                    activeTrackColor: theme.accent,
                    onChanged: (v) {
                      setState(() => _useCutout = v);
                      _render();
                    },
                  ),
                ),
              if (!_useCutout)
                _OptionRow(
                  label: l10n.stickerMakerShape,
                  child: CupertinoSlidingSegmentedControl<StickerShape>(
                    groupValue: _shape,
                    onValueChanged: (s) {
                      if (s == null) return;
                      setState(() => _shape = s);
                      _render();
                    },
                    children: {
                      StickerShape.circle: Icon(CupertinoIcons.circle,
                          size: 18, color: theme.ink,
                          semanticLabel: l10n.stickerMakerShapeCircle),
                      StickerShape.rounded: Icon(CupertinoIcons.app,
                          size: 18, color: theme.ink,
                          semanticLabel: l10n.stickerMakerShapeRounded),
                      StickerShape.original: Icon(CupertinoIcons.crop,
                          size: 18, color: theme.ink,
                          semanticLabel: l10n.stickerMakerShapeOriginal),
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.stickerMakerEmojiLabel,
                    style: theme.caption.copyWith(color: theme.inkMuted),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final e in {..._quickEmoji, _emoji})
                      _EmojiChoice(
                        emoji: e,
                        selected: e == _emoji,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _emoji = e);
                        },
                      ),
                    _EmojiChoice(
                      emoji: null,
                      selected: false,
                      onTap: _pickMoreEmoji,
                      semanticLabel: l10n.stickerMakerMoreEmoji,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.body)),
          child,
        ],
      ),
    );
  }
}

class _EmojiChoice extends StatelessWidget {
  const _EmojiChoice({
    required this.emoji,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  /// Null draws the "more…" button.
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel ?? emoji,
      selected: selected,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // A neutral disc with a ring when chosen, not an accent wash.
            color: theme.ink.withValues(alpha: selected ? 0.12 : 0.06),
            border: Border.all(
              color: selected ? theme.accent : theme.ink.withValues(alpha: 0),
              width: 1.6,
            ),
          ),
          child: emoji == null
              ? Icon(CupertinoIcons.ellipsis, size: 18, color: theme.inkMuted)
              : Text(emoji!, style: const TextStyle(fontSize: 22, height: 1)),
        ),
      ),
    );
  }
}

/// The transparency checkerboard behind the preview, in theme tones.
class _Checkerboard extends CustomPainter {
  const _Checkerboard({required this.a, required this.b});

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 14.0;
    final pa = Paint()..color = a;
    final pb = Paint()..color = b;
    canvas.drawRect(Offset.zero & size, pa);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        if (((x / cell).floor() + (y / cell).floor()).isOdd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), pb);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Checkerboard old) => old.a != a || old.b != b;
}
