import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../media/editor_geometry.dart';
import '../media/file_meta.dart' show formatFileSize, kMaxFileUploadBytes;
import '../media/image_raster.dart';
import '../media/media_send_options.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/destructive_sheet.dart';
import '../widgets/media_filmstrip.dart';
import '../widgets/send_button.dart';
import '../widgets/photo_chrome.dart';
import '../widgets/schedule_message_sheet.dart';
import '../widgets/spring_press.dart';
import '../widgets/still_blur.dart';
import 'review_route.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/glass_buttons.dart';
import '../widgets/glass_reveal.dart' show GlassStill;
import '../widgets/media_send_switches.dart';
import '../widgets/media_spoiler.dart' show kMediaSpoilerReveal;
import '../widgets/dust/spoiler_dust.dart';
import '../widgets/desktop_scroll.dart';
import '../widgets/editor_glyphs.dart';
import '../widgets/photo_send_flight.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import '../widgets/capture_glyphs.dart'
    show HdGlyph, SpoilerGlyph, ViewOnceGlyph;

/// Post-capture composer: draw on a photo, frame it, caption it, send it — or
/// several of them at once.
///
/// Everything the user does is held as *state over the original file* rather
/// than baked into pixels as they go — strokes are normalized 0..1 points, the
/// crop is a normalized rect. Nothing is rasterized until save. Three things
/// fall out of that, all of which the previous version got wrong:
///
///  * **Crop is reversible and can be re-entered at any time.** It used to push
///    a separate screen that re-encoded the image, which is why it had to be
///    disabled the moment you drew anything ("crop before drawing") — replacing
///    the pixels underneath widget-space strokes would have relocated them.
///  * **Preview and export agree by construction.** Both read the same
///    normalized data through the same mapping, instead of the painter using one
///    coordinate space and the exporter reconstructing another.
///  * **An unedited photo is passed through untouched.** No crop, no strokes, no
///    rotation means the caller gets the original bytes — not a re-encode.
///    The one exception is the size cap: an oversized photo is re-encoded down
///    unless HD is armed, because a 5 MB original is a cost paid by every
///    member of the room, not just the sender. See `kSendPhotoMaxEdge`.
///
/// **Several photos are one screen, not two.** Every photo in an
/// [EditorDraft] keeps its own strokes, crop, rotation and caption, and the
/// rail along the bottom moves between them. This replaced a separate "photo
/// tray" for multi-picks that could only reach the pen and the cropper by
/// pushing this screen on top of itself, one photo at a time.
///
/// Pops an [EditorOutcome] on send or retake, `null` on discard.
///
/// The photograph being edited, as opposed to the rail's thumbnails of it.
///
/// Keyed because they are all images, so a test reaching for "the image" to
/// drag across would otherwise be ambiguous.
@visibleForTesting
const Key cameraEditorStageImageKey = Key('camera-editor-stage-image');

/// The caption field, for tests that type into it.
@visibleForTesting
const Key cameraEditorCaptionKey = Key('camera-editor-caption');

class CameraEditorScreen extends StatefulWidget {
  const CameraEditorScreen({
    super.key,
    this.source,
    this.draft,
    this.canRetake = false,
    this.mirrored = false,
    this.allowDrawing = true,
    this.allowViewOnce = true,
    this.allowSpoiler = false,
    this.allowCaptions = false,
    this.maxPhotos = 1,
    this.galleryOverCamera = false,
    this.pickMore,
    this.allowSchedule = false,
    this.scheduleRefusal,
    this.confirmLabel,
    this.busyLabel,
    this.options,
    this.closeKeeps = false,
    this.initialCaption,
  }) : assert(source != null || draft != null);

  /// The encoded photo. Bytes rather than a `dart:io` File so this screen works
  /// in a browser, where a picked image is a `blob:` URL with no file behind it.
  ///
  /// Ignored when [draft] is given — the draft's photos are the photos.
  final Uint8List? source;

  /// The photos being composed, owned by the caller so they outlive this
  /// route. The camera's flow needs that: "take another" pops this screen back
  /// to the viewfinder, and the next capture reopens it on the same draft with
  /// one more photo in it. Null builds a one-photo draft from [source], owned
  /// and released here.
  final EditorDraft? draft;

  /// Whether there is a camera underneath to go back to. False for a photo
  /// chosen from the library — there is nothing to go back to — and the
  /// control is then absent rather than disabled.
  ///
  /// With [maxPhotos] of one it is a retake. With more, it is "take another":
  /// the photos already here stay in the draft.
  final bool canRetake;

  /// Whether [source] is a front-lens capture that still has to be reflected to
  /// match the preview the user framed it in.
  ///
  /// Treated exactly like rotation: applied eagerly to the display decode so
  /// what is on screen is the truth, and replayed against the full-resolution
  /// decode at export. It costs nothing extra either way — the display decode
  /// and the export rasterize both happen regardless — where flipping the
  /// encoded bytes at capture time would stall the shutter on a full-resolution
  /// re-encode.
  final bool mirrored;

  /// Whether the pen is offered at all.
  ///
  /// The feed's composers want a cropper, not a doodle surface: a highlight is
  /// a photograph, and a scribble on it is a chat gesture that means nothing on
  /// a board. False also makes every drawing path unreachable rather than
  /// merely hidden — `_penArmed` can only be set by the button this removes.
  final bool allowDrawing;

  /// Whether the circled "1" is offered.
  ///
  /// A board post is visible to your friends for a day by construction, so
  /// "view once" has nothing to mean there.
  final bool allowViewOnce;

  /// Whether the spoiler switch is offered: the photo reaches everyone under
  /// dust until tapped. Chat only, like view once; a board post or an avatar
  /// has nobody to hide it from.
  final bool allowSpoiler;

  /// The send's switches (view once, spoiler, HD), when the caller keeps
  /// them: the inline picker hands in its own, so a switch flipped here is
  /// the one its strip sends with. Null uses the draft's.
  final MediaSendOptions? options;

  /// The gallery's preview of one pick: the × goes back to the picks and
  /// KEEPS what was done here (the drawing, the crop, the caption), popping
  /// [EditorKeep]. Nothing to confirm, because nothing is thrown away.
  final bool closeKeeps;

  /// The caption the photo already has, for a preview reopened on a pick
  /// that was captioned before.
  final String? initialCaption;

  /// Whether each photo gets a caption field. Chat only — the feed's composers
  /// have a caption of their own, on the post rather than on the picture.
  final bool allowCaptions;

  /// How many photos one send may carry. One — every caller but chat — keeps
  /// this the single-photo editor it always was: no rail, no add buttons.
  final int maxPhotos;

  /// "Add from library" goes back to the camera underneath, which opens its
  /// own recents gallery, rather than to the OS picker. See
  /// [EditorAddFromLibrary].
  final bool galleryOverCamera;

  /// Fetches more photos from the OS picker, at most `remaining` of them, for
  /// a draft that has no camera underneath. Null hides "add from library"
  /// unless [galleryOverCamera] is set.
  final Future<List<Uint8List>> Function(int remaining)? pickMore;

  /// Whether holding the send arrow schedules the photos for later, the way
  /// holding Send schedules text. Chat only.
  final bool allowSchedule;

  /// Said instead of opening the schedule sheet, when this room refuses
  /// scheduling (a Chamber of Secrets room). The hold still answers — a hold
  /// that does nothing reads as a broken button.
  final String? scheduleRefusal;

  /// Label on the commit pill. Null keeps chat's SEND.
  final String? confirmLabel;

  /// Label on the commit pill while the export runs. Null keeps chat's SENDING.
  final String? busyLabel;

  /// [overCamera] pushes with no transition, for the camera's in-place review:
  /// the editor takes the preview's place in the frame after the shutter rather
  /// than presenting itself as a second screen. A photo from the library has no
  /// camera under it and animates in normally.
  static Future<EditorOutcome?> open(
    BuildContext context, {
    Uint8List? source,
    EditorDraft? draft,
    bool canRetake = false,
    bool mirrored = false,
    bool overCamera = false,
    bool allowDrawing = true,
    bool allowViewOnce = true,
    bool allowSpoiler = false,
    bool allowCaptions = false,
    int maxPhotos = 1,
    bool galleryOverCamera = false,
    Future<List<Uint8List>> Function(int remaining)? pickMore,
    bool allowSchedule = false,
    String? scheduleRefusal,
    String? confirmLabel,
    String? busyLabel,
    MediaSendOptions? options,
    bool closeKeeps = false,
    String? initialCaption,
  }) {
    final screen = CameraEditorScreen(
      source: source,
      draft: draft,
      canRetake: canRetake,
      mirrored: mirrored,
      allowDrawing: allowDrawing,
      allowViewOnce: allowViewOnce,
      allowSpoiler: allowSpoiler,
      allowCaptions: allowCaptions,
      maxPhotos: maxPhotos,
      galleryOverCamera: galleryOverCamera,
      pickMore: pickMore,
      allowSchedule: allowSchedule,
      scheduleRefusal: scheduleRefusal,
      confirmLabel: confirmLabel,
      busyLabel: busyLabel,
      options: options,
      closeKeeps: closeKeeps,
      initialCaption: initialCaption,
    );
    return Navigator.of(context).push<EditorOutcome>(
      overCamera
          ? reviewRoute<EditorOutcome>(screen)
          : editorRoute<EditorOutcome>(screen),
    );
  }

  @override
  State<CameraEditorScreen> createState() => _CameraEditorScreenState();
}

/// How the user left the editor.
sealed class EditorOutcome {
  const EditorOutcome();
}

/// One finished photograph and what to say under it.
class EditorPhoto {
  const EditorPhoto({required this.image, this.caption});

  final CroppedImage image;

  /// Trimmed, and null rather than empty. Always null on a view-once send —
  /// see [EditorSend.viewOnce].
  final String? caption;
}

/// Send these pictures, in the rail's order. The wrapper exists rather than
/// another field on [CroppedImage] because that type is shared with
/// `ImageCropScreen` (the avatar cropper), where "view once" is meaningless —
/// keeping the send-time decision out here means the raster types stay about
/// rasters.
class EditorSend extends EditorOutcome {
  const EditorSend({
    required this.photos,
    required this.viewOnce,
    this.spoiler = false,
    this.dropped = 0,
    this.scheduleAt,
  });

  /// Not now: queue the photos for this instant instead. Null sends them as
  /// soon as the composer closes.
  final DateTime? scheduleAt;

  final List<EditorPhoto> photos;

  /// The first photo — all a single-photo caller ever gets.
  CroppedImage get image => photos.first.image;

  /// Armed with the circled "1", for every photo in the send: the recipient
  /// may open each exactly once, and the files are deleted from the server
  /// afterwards. Captions are dropped when armed, because a message's text
  /// outlives its photo and would be the one part of it that did not vanish.
  final bool viewOnce;

  /// Sent as a spoiler, every photo of it: blurred under dust for everyone
  /// until tapped. See `ChatMessage.mediaSpoiler`.
  final bool spoiler;

  /// How many photos failed to export. Reported rather than swallowed: a send
  /// of five that quietly becomes a send of four is worse than one that says
  /// so.
  final int dropped;
}

/// Throw this one away and open the camera again — or, for a multi-photo
/// draft, keep everything and go take another.
///
/// A distinct outcome rather than a null pop, because the two mean opposite
/// things to the caller and the old screen conflated them — its RETAKE button
/// popped null, which dropped the user back in the chat instead of back at the
/// camera.
class EditorRetake extends EditorOutcome {
  const EditorRetake();
}

/// Back to the picks, keeping what was done (see
/// [CameraEditorScreen.closeKeeps]): [image] is the photo as edited, null
/// when nothing about the picture changed, and [caption] is what was written
/// under it (empty for none).
class EditorKeep extends EditorOutcome {
  const EditorKeep({this.image, this.caption = ''});

  final CroppedImage? image;
  final String caption;
}

/// Keep the draft and go back to the camera's recents gallery for another
/// photo. Only popped with [CameraEditorScreen.galleryOverCamera].
class EditorAddFromLibrary extends EditorOutcome {
  const EditorAddFromLibrary();
}

/// The photos of one send, while they are being composed.
///
/// Lives outside the editor so it can survive the editor popping — see
/// [CameraEditorScreen.draft]. Whoever creates one disposes it.
class EditorDraft {
  EditorDraft({MediaSendOptions? options})
      : options = options ?? MediaSendOptions();

  final List<_EditorPage> _pages = [];
  int _index = 0;

  /// The send's switches: view once, spoiler, HD. Decisions about the whole
  /// send, so they live here rather than on a page.
  final MediaSendOptions options;

  /// The circled "1". See [MediaSendOptions.viewOnce].
  bool get viewOnce => options.viewOnce;
  set viewOnce(bool v) => options.viewOnce = v;

  int get length => _pages.length;

  /// Which photo the editor opens on. [add] moves it to the newest; a draft
  /// built from a multi-pick wants the first.
  int get index => _index;
  set index(int i) => _index = _pages.isEmpty ? 0 : i.clamp(0, _pages.length - 1);
  bool get isEmpty => _pages.isEmpty;
  bool get isNotEmpty => _pages.isNotEmpty;

  /// Whether leaving now would throw away something the user did — more than
  /// one photo, or a word of caption. One untouched photo is not worth a
  /// confirmation; the shutter makes another.
  bool get hasWork =>
      _pages.length > 1 || _pages.any((p) => p.caption.trim().isNotEmpty);

  /// How many composers are showing this draft right now. While any is, [dispose]
  /// waits: a composer is still painted for the frames of its exit animation,
  /// AFTER the code that opened it has its answer and moves on to clean up —
  /// and a draft emptied under it there is a photo looked up that no longer
  /// exists.
  int _attached = 0;
  bool _disposed = false;

  void _attach() => _attached++;

  void _detach() {
    _attached--;
    if (_attached == 0 && _disposed) _release();
  }

  /// Appends a photo and makes it the current one.
  void add(Uint8List bytes, {bool mirrored = false}) {
    _pages.add(_EditorPage(source: bytes, mirrored: mirrored));
    _index = _pages.length - 1;
  }

  /// Lets go of every decoded picture. The draft stays usable — a page that is
  /// shown again decodes again.
  void releaseImages() {
    for (final p in _pages) {
      p.releaseImage();
    }
  }

  /// Lets go of everything, once no composer is showing it any more.
  void dispose() {
    _disposed = true;
    if (_attached == 0) _release();
  }

  void _release() {
    releaseImages();
    _pages.clear();
  }
}

/// A freehand stroke, in normalized image coordinates.
class _EditorStroke {
  _EditorStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;

  /// Fraction of the image's width, so a stroke keeps its visual weight
  /// whatever resolution the image is displayed or exported at.
  final double width;

  /// 0..1 fractions of the source image, in its current rotation.
  final List<Offset> points;
}

/// One photo of a draft and everything done to it.
class _EditorPage {
  _EditorPage({required this.source, required this.mirrored});

  final Uint8List source;
  final bool mirrored;

  /// The on-screen decode, mirrored and rotated to match. Held for the photo
  /// on screen only: at 2048 a side it is 16 MB of RGBA, and ten of them
  /// resident at once is how a send of ten photos runs a phone out of memory.
  ui.Image? display;
  Object? loadError;
  bool loading = false;

  /// Bumped whenever [display] is let go, so a decode that finishes after the
  /// photo was rotated, removed or scrolled past knows it is stale.
  int generation = 0;

  /// Quarter-turns clockwise the user has applied. Replayed against the
  /// full-resolution decode at export; the display image is rotated eagerly so
  /// what's on screen is always the truth.
  int rotations = 0;

  final List<_EditorStroke> strokes = [];
  final List<_EditorStroke> redo = [];

  /// Normalized crop, in the image's current rotation. The unit rect means
  /// uncropped, and is compared exactly — it is only ever set by a reset.
  Rect crop = const Rect.fromLTWH(0, 0, 1, 1);
  _AspectPreset preset = _AspectPreset.free;

  String caption = '';

  /// Whether the sent photo has to be rebuilt rather than passed through.
  ///
  /// `mirrored` counts: the bytes we were handed are the un-reflected capture,
  /// so passing them through would send the selfie backwards — the exact bug
  /// this flag exists to fix.
  bool get hasEdits =>
      mirrored ||
      strokes.isNotEmpty ||
      rotations != 0 ||
      crop != const Rect.fromLTWH(0, 0, 1, 1);

  void releaseImage() {
    display?.dispose();
    display = null;
    loading = false;
    generation++;
  }
}

enum _Tool { draw, crop }

/// Selectable crop ratios. `null` aspect is freeform.
class _AspectPreset {
  const _AspectPreset(this.label, this.aspect);
  final String label;

  /// Width / height in pixels. Null means free; [_original] is resolved from
  /// the image at use time.
  final double? aspect;

  static const free = _AspectPreset('FREE', null);
  static const original = _AspectPreset('ORIG', -1);
  static const values = <_AspectPreset>[
    free,
    original,
    _AspectPreset('1:1', 1),
    _AspectPreset('4:5', 4 / 5),
    _AspectPreset('16:9', 16 / 9),
  ];

  bool get isOriginal => aspect == -1;
}

/// Rotates [src] a quarter-turn clockwise into a new image.
Future<ui.Image> _rotateImageCW(ui.Image src) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.translate(src.height.toDouble(), 0);
  canvas.rotate(math.pi / 2);
  canvas.drawImage(
    src,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final rotated = await picture.toImage(src.height, src.width);
  picture.dispose();
  return rotated;
}

class _CameraEditorScreenState extends State<CameraEditorScreen>
    with TickerProviderStateMixin {
  /// Cap for the on-screen decode. A 4032×3024 photo is ~48 MB of RGBA at full
  /// size and makes every drawn frame stutter; 2048 is comfortably past any
  /// phone screen, so the downscale is invisible. Export re-decodes at full
  /// resolution — the sent file is never limited by this.
  static const _maxDisplayEdge = 2048;

  static const _palette = <Color>[
    Color(0xFFFFFFFF),
    // Not pure black: at 0.045 of an image's width a #000 stroke over a dark
    // photo reads as a hole punched in it rather than as ink.
    Color(0xFF121212),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF0A84FF),
    Color(0xFFBF5AF2),
    Color(0xFFFF2D95),
  ];

  /// Brush size as a fraction of image width — continuous, so the slider can
  /// land anywhere between a fine line and a marker.
  static const _minWidth = 0.004;
  static const _maxWidth = 0.045;

  /// Bends the slider so the thin half of the range gets most of the travel.
  /// Linear, the bottom two thirds of the useful sizes live in the first tenth
  /// of the track and cannot be picked apart with a thumb.
  static const _widthGamma = 1.8;

  /// How far a pinch or a double tap may zoom into the photo.
  static const _maxZoom = 6.0;
  static const _doubleTapZoom = 2.5;

  static double _widthForSlider(double t) =>
      _minWidth +
      (_maxWidth - _minWidth) * math.pow(t.clamp(0.0, 1.0), _widthGamma);

  static double _sliderForWidth(double w) => math
      .pow(
        ((w - _minWidth) / (_maxWidth - _minWidth)).clamp(0.0, 1.0),
        1 / _widthGamma,
      )
      .toDouble();

  late final EditorDraft _draft =
      widget.draft ??
      (EditorDraft()..add(widget.source!, mirrored: widget.mirrored));

  bool _saving = false;

  /// Bumped as each tool acts, for its glyph's kick (see [GlyphKick]).
  int _rotateKicks = 0;
  int _undoKicks = 0;
  int _redoKicks = 0;

  /// The stage's quarter turn after a rotate: the new, already-rotated
  /// picture starts drawn a quarter back at the old picture's size and turns
  /// into place, so the photo is seen to turn instead of snapping.
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  /// The stage's size just before the rotate, for [_turn]'s first frame.
  Size? _turnFrom;

  /// The stage rect from the last layout.
  Rect? _lastStage;

  /// The stage's own layer, for the still a send flies down into the chat.
  final GlobalKey _shotKey = GlobalKey();

  /// Set as the photo leaves in its send flight: the stage stops drawing, so
  /// the picture is never on screen twice while this route goes.
  bool _flown = false;

  /// Covers reading back an "add from library" pick — whole-file reads behind
  /// an OS sheet that has already slid away.
  bool _adding = false;

  /// The send's switches: the caller's, or the draft's. HD is sticky (see
  /// `SettingsStore.photoHd`); [_saving] keeps a send in flight from changing
  /// under itself.
  late final MediaSendOptions _options = widget.options ?? _draft.options;

  bool get _hd => _options.hd;

  _EditorStroke? _current;

  /// The stage's spoiler preview. See [_SpoilerPreview].
  final GlobalKey _veilKey = GlobalKey();

  Color _color = _palette.first;
  double _width = 0.010;

  _Tool _tool = _Tool.draw;

  /// Whether the pen is out. The drawing gesture only exists while it is, which
  /// is the whole reason the tray is a toggle: the old screen listened for pans
  /// over the photo unconditionally, so every attempt to swipe the picture left
  /// a scribble on it.
  bool _penArmed = false;

  /// True between the start and end of a stroke. Fades the chrome out of the
  /// way so the picture is unobstructed while it is being drawn on.
  bool _drawing = false;

  /// True from a stroke's start until the chrome's fade back has settled at
  /// full strength: the window in which the chrome's media glass draws its
  /// blur-free twin (see [GlassStill]). Outlives [_drawing] by the length of
  /// the fade back, which is the half of the flicker a plain `_drawing` would
  /// leave in.
  bool _chromeDimmed = false;

  /// The crop as it was when crop mode was entered, so CANCEL can restore it.
  Rect? _cropOnEnter;
  _AspectPreset? _presetOnEnter;

  CropHandle? _activeHandle;

  /// Pinch and double-tap zoom on the photo. Carried into the pen — zoom in,
  /// then pick the pen up to draw the detail — but reset by anything that
  /// changes what the frame is: crop, rotate, another photo.
  final TransformationController _zoom = TransformationController();
  late final AnimationController _zoomCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..addListener(_onZoomTick);
  Animation<Matrix4>? _zoomTween;
  Offset _doubleTapAt = Offset.zero;

  /// Mirrors [_zoomed] as state, so the viewer can hand one-finger drags to
  /// the swipe between photos at 1× and to panning once zoomed in.
  bool _isZoomed = false;

  /// How far the photo has been swiped sideways, toward the next one or the
  /// one before. A notifier, so a swipe repaints three transforms instead of
  /// rebuilding the screen on every pointer move.
  final ValueNotifier<double> _swipeDx = ValueNotifier(0);
  late final AnimationController _swipeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  double _pageWidth = 0;

  /// The space between two photos while one swipes past the other — the
  /// Photos gutter, so the edges never touch.
  static const _swipeGap = 16.0;

  final TextEditingController _caption = TextEditingController();

  /// What the caption field shows while view-once is armed: nothing, so the
  /// hint saying why reads in full. The typed caption stays in [_caption] and
  /// on the page, and comes back when view-once is turned off again.
  final TextEditingController _noCaption = TextEditingController();
  final FocusNode _captionFocus = FocusNode();

  /// Repaint signals. Painting is driven by these rather than `setState` so a
  /// drag repaints one layer instead of rebuilding the toolbar, palette and
  /// decoded image on every pointer move.
  final ValueNotifier<int> _committedRev = ValueNotifier(0);
  final ValueNotifier<int> _liveRev = ValueNotifier(0);

  // -------------------------------------------------------- the current page

  /// The photo on screen.
  ///
  /// Remembered as well as looked up, because the draft can be empty while
  /// this screen is still painting — removing the last photo pops the route,
  /// and the route animates away for a few frames after it. Those frames draw
  /// the photo that was there, not an index into an empty list.
  _EditorPage get _page {
    final pages = _draft._pages;
    if (pages.isEmpty) return _shown!;
    return _shown = pages[_draft._index.clamp(0, pages.length - 1)];
  }

  _EditorPage? _shown;

  ui.Image? get _display => _page.display;
  Object? get _loadError => _page.loadError;
  List<_EditorStroke> get _strokes => _page.strokes;
  List<_EditorStroke> get _redo => _page.redo;

  Rect get _crop => _page.crop;
  set _crop(Rect v) => _page.crop = v;

  _AspectPreset get _preset => _page.preset;
  set _preset(_AspectPreset v) => _page.preset = v;

  bool get _viewOnce => _options.viewOnce;

  bool get _multi => widget.maxPhotos > 1;
  bool get _hasRoom => _draft.length < widget.maxPhotos;

  @override
  void initState() {
    super.initState();
    _draft._attach();
    final seeded = widget.initialCaption;
    if (seeded != null && _page.caption.isEmpty) _page.caption = seeded;
    _caption.text = _page.caption;
    _options.addListener(_onOptions);
    _caption.addListener(_onCaptionChanged);
    _zoom.addListener(_onZoomChanged);
    _captionFocus.addListener(_onCaptionFocus);
    _ensureLoaded(_page);
  }

  void _onOptions() {
    // View once turns the caption off under the cursor; take the keyboard
    // with it rather than leave it up over nothing to type in.
    if (_viewOnce) _captionFocus.unfocus();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _options.removeListener(_onOptions);
    // The draft may outlive this route — the camera's "take another" — but its
    // decoded pictures should not: they are re-made in a frame when shown.
    _draft.releaseImages();
    // A last photo removed from the rail is out of the draft but was still
    // on screen until now.
    _shown?.releaseImage();
    if (widget.draft == null) _draft.dispose();
    _draft._detach();
    _zoomCtrl.dispose();
    _swipeCtrl.dispose();
    _turn.dispose();
    _swipeDx.dispose();
    _zoom.dispose();
    _caption.dispose();
    _noCaption.dispose();
    _captionFocus.dispose();
    _committedRev.dispose();
    _liveRev.dispose();
    super.dispose();
  }

  void _onCaptionChanged() {
    if (_draft.isNotEmpty) _page.caption = _caption.text;
  }

  void _onCaptionFocus() {
    if (mounted) setState(() {});
  }

  /// Decodes [page] for display, mirrored and rotated as the user left it.
  Future<void> _ensureLoaded(_EditorPage page) async {
    if (page.display != null || page.loading || page.loadError != null) return;
    page.loading = true;
    final generation = page.generation;
    ui.Image? image;
    try {
      image = await decodeImageBytes(page.source, maxEdge: _maxDisplayEdge);
      // Eagerly, like rotation, so what is on screen is always the truth and
      // every stroke the user draws lands in the same frame the export uses.
      if (page.mirrored) {
        final flipped = await flipImageHorizontally(image);
        image.dispose();
        image = flipped;
      }
      for (var i = 0; i < page.rotations; i++) {
        final turned = await _rotateImageCW(image!);
        image.dispose();
        image = turned;
      }
      if (!mounted || generation != page.generation) {
        image?.dispose();
        return;
      }
      page.display = image;
      page.loading = false;
      setState(() {});
    } catch (e) {
      // Said out loud. Swallowed into loadError alone, a decode that failed on
      // every image in the browser looked identical in the console to one that
      // never ran — which is how it survived a build and a deploy.
      debugPrint('[camera_editor] decode failed: $e');
      image?.dispose();
      if (!mounted || generation != page.generation) return;
      page.loading = false;
      setState(() => page.loadError = e);
    }
  }

  // ---------------------------------------------------------------- geometry

  Size get _imageSize {
    final img = _display;
    if (img == null) return const Size(1, 1);
    return Size(img.width.toDouble(), img.height.toDouble());
  }

  /// The normalized region currently on screen.
  ///
  /// Crop mode shows the whole image so the handles have somewhere to go;
  /// everything else shows the crop, which is what the user is actually making.
  Rect get _viewport =>
      _tool == _Tool.crop ? const Rect.fromLTWH(0, 0, 1, 1) : _crop;

  double? _resolvedAspect() {
    if (_preset.aspect == null) return null;
    if (_preset.isOriginal) return _imageSize.width / _imageSize.height;
    return _preset.aspect;
  }

  /// Localizes the FREE/ORIG chip labels. The numeric ratios ('1:1', '4:5',
  /// '16:9') are locale-invariant notation, so they pass through unchanged.
  String _presetLabel(_AspectPreset preset) {
    final l10n = AppLocalizations.of(context);
    if (preset == _AspectPreset.free) {
      return l10n.cameraEditorScreenCropPresetFree;
    }
    if (preset == _AspectPreset.original) {
      return l10n.cameraEditorScreenCropPresetOriginal;
    }
    return preset.label;
  }

  // -------------------------------------------------------------------- zoom

  bool get _zoomed => _zoom.value.getMaxScaleOnAxis() > 1.01;

  void _onZoomChanged() {
    final zoomed = _zoomed;
    if (zoomed != _isZoomed && mounted) setState(() => _isZoomed = zoomed);
  }

  void _onZoomTick() {
    final t = _zoomTween;
    if (t != null) _zoom.value = t.value;
  }

  void _animateZoomTo(Matrix4 target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _zoom.value = target;
      return;
    }
    _zoomTween = Matrix4Tween(begin: _zoom.value, end: target).animate(
      CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeOutCubic),
    );
    _zoomCtrl
      ..value = 0
      ..forward();
  }

  void _resetZoom({bool animate = true}) {
    if (!_zoomed) return;
    if (animate) {
      _animateZoomTo(Matrix4.identity());
    } else {
      _zoomCtrl.stop();
      _zoom.value = Matrix4.identity();
    }
  }

  /// In to 2.5× around the tap, or back out — the Photos double tap.
  void _toggleZoom() {
    if (_zoomed) {
      _animateZoomTo(Matrix4.identity());
      return;
    }
    HapticFeedback.selectionClick();
    final p = _doubleTapAt;
    _animateZoomTo(
      Matrix4.identity()
        ..translateByDouble(
          -p.dx * (_doubleTapZoom - 1),
          -p.dy * (_doubleTapZoom - 1),
          0.0,
          1.0,
        )
        ..scaleByDouble(_doubleTapZoom, _doubleTapZoom, _doubleTapZoom, 1.0),
    );
  }

  // ------------------------------------------------------------------- pages

  void _selectPage(int i) {
    if (i == _draft._index || i < 0 || i >= _draft.length || _saving) return;
    HapticFeedback.selectionClick();
    final previous = _page;
    setState(() {
      // Crop mode belongs to the photo it was entered on; the new one opens
      // framed the way it was left.
      if (_tool == _Tool.crop) _tool = _Tool.draw;
      _activeHandle = null;
      _draft._index = i;
    });
    previous.releaseImage();
    _resetZoom(animate: false);
    // Assigned after the index moved, so the listener writes the new page.
    _caption.text = _page.caption;
    _committedRev.value++;
    _ensureLoaded(_page);
  }

  void _removePage(int i) {
    if (_saving || i < 0 || i >= _draft.length) return;
    HapticFeedback.lightImpact();
    final removed = _draft._pages.removeAt(i);
    if (_draft.isEmpty) {
      // Still painted while the route animates away; dispose lets it go.
      // Nothing left to send. Over the camera that means "back to the
      // viewfinder"; anywhere else the screen has nothing to show.
      Navigator.of(context).pop(widget.canRetake ? const EditorRetake() : null);
      return;
    }
    removed.releaseImage();
    setState(() {
      final idx = _draft._index;
      _draft._index = i < idx ? idx - 1 : idx.clamp(0, _draft.length - 1);
      if (_tool == _Tool.crop) _tool = _Tool.draw;
    });
    _resetZoom(animate: false);
    _caption.text = _page.caption;
    _committedRev.value++;
    _ensureLoaded(_page);
  }

  /// "Add from library": back to the camera's own gallery, or the OS picker
  /// where there is no camera.
  Future<void> _addFromLibrary() async {
    if (_saving || _adding || !_hasRoom) return;
    HapticFeedback.selectionClick();
    _captionFocus.unfocus();
    if (widget.galleryOverCamera) {
      Navigator.of(context).pop(const EditorAddFromLibrary());
      return;
    }
    final pickMore = widget.pickMore;
    if (pickMore == null) return;
    setState(() => _adding = true);
    try {
      final more = await pickMore(widget.maxPhotos - _draft.length);
      if (!mounted || more.isEmpty) return;
      final previous = _page;
      setState(() {
        for (final bytes in more.take(widget.maxPhotos - _draft.length)) {
          _draft.add(bytes);
        }
        if (_tool == _Tool.crop) _tool = _Tool.draw;
      });
      if (!identical(previous, _page)) previous.releaseImage();
      _resetZoom(animate: false);
      _caption.text = _page.caption;
      _committedRev.value++;
      _ensureLoaded(_page);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _takeAnother() {
    if (_saving) return;
    HapticFeedback.selectionClick();
    _captionFocus.unfocus();
    Navigator.of(context).pop(const EditorRetake());
  }

  /// The ×. Confirms first when there is more to lose than one fresh photo.
  Future<void> _discard() async {
    if (_saving) return;
    HapticFeedback.selectionClick();
    _captionFocus.unfocus();
    if (widget.closeKeeps) return _keep();
    if (_draft.hasWork) {
      final l10n = AppLocalizations.of(context);
      final go = await showConfirmSheet(
        context,
        headline: l10n.cameraEditorScreenDiscardAllTitle(_draft.length),
        body: l10n.cameraEditorScreenDiscardAllBody,
        confirmLabel: l10n.cameraEditorScreenDiscardAllConfirm,
      );
      if (!go || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  /// The gallery preview's ×: back to the picks with what was done here.
  /// Only a photo that was actually edited is exported; an untouched one goes
  /// back as the pick it was.
  Future<void> _keep() async {
    final page = _page;
    final caption = page.caption.trim();
    if (!page.hasEdits) {
      Navigator.of(context).pop(EditorKeep(caption: caption));
      return;
    }
    setState(() => _saving = true);
    final (image, _) = await _exportPage(page);
    if (!mounted) return;
    Navigator.of(context).pop(EditorKeep(image: image, caption: caption));
  }

  // ------------------------------------------------------------------- tools

  void _selectTool(_Tool tool) {
    if (_tool == tool || _saving) return;
    HapticFeedback.selectionClick();
    _captionFocus.unfocus();
    if (tool == _Tool.crop) _resetZoom();
    setState(() {
      if (tool == _Tool.crop) {
        _cropOnEnter = _crop;
        _presetOnEnter = _preset;
        // Framing and drawing are different jobs; carrying the pen into crop
        // mode would only put a tray over the handles.
        _penArmed = false;
      }
      _tool = tool;
      _activeHandle = null;
    });
  }

  void _togglePen() {
    if (_saving) return;
    HapticFeedback.selectionClick();
    _captionFocus.unfocus();
    setState(() => _penArmed = !_penArmed);
  }

  void _cancelCrop() {
    HapticFeedback.selectionClick();
    setState(() {
      _crop = _cropOnEnter ?? const Rect.fromLTWH(0, 0, 1, 1);
      _preset = _presetOnEnter ?? _AspectPreset.free;
      _tool = _Tool.draw;
    });
  }

  void _resetCrop() {
    HapticFeedback.lightImpact();
    setState(() {
      _crop = const Rect.fromLTWH(0, 0, 1, 1);
      _preset = _AspectPreset.free;
    });
  }

  void _selectPreset(_AspectPreset preset) {
    HapticFeedback.selectionClick();
    setState(() {
      _preset = preset;
      final aspect = _resolvedAspect();
      if (aspect != null) {
        _crop = centeredCrop(aspect: aspect, imageSize: _imageSize);
      }
    });
  }

  /// Rotates the decoded image eagerly and carries the annotations with it.
  ///
  /// Same reasoning as the avatar cropper: folding rotation into a transform
  /// matrix would leave every downstream rect axis-unaligned, so the image is
  /// re-rasterized and the normalized geometry rotated to match. `rotations`
  /// records it so export can reproduce the same turn on the full-resolution
  /// decode.
  Future<void> _rotate90() async {
    final src = _display;
    if (src == null || _saving) return;
    HapticFeedback.selectionClick();
    setState(() => _rotateKicks++);
    _resetZoom(animate: false);
    final page = _page;
    final generation = page.generation;

    final rotated = await _rotateImageCW(src);
    if (!mounted || generation != page.generation || page.display != src) {
      rotated.dispose();
      return;
    }

    // A turn still running is finished where it is; the next starts from
    // the stage as it stands.
    _turnFrom = _lastStage?.size;
    setState(() {
      page.display?.dispose();
      page.display = rotated;
      page.rotations = (page.rotations + 1) % 4;
      page.crop = rotateRectCW(page.crop);
      for (final s in page.strokes) {
        for (var i = 0; i < s.points.length; i++) {
          s.points[i] = rotateNormCW(s.points[i]);
        }
      }
      // A preset locked to the source's own ratio flips with it.
      if (page.preset.isOriginal) {
        final aspect = _resolvedAspect();
        if (aspect != null) {
          page.crop = centeredCrop(aspect: aspect, imageSize: _imageSize);
        }
      }
    });
    _committedRev.value++;
    if (_turnFrom != null && !MediaQuery.disableAnimationsOf(context)) {
      _turn.forward(from: 0);
    }
  }

  /// [stage] as [_turn] has it: turning a quarter clockwise into place and
  /// growing or shrinking from the old fit to the new one.
  Widget _turning(Widget stage, Rect rect) {
    return AnimatedBuilder(
      animation: _turn,
      // The picture rasterises once; every frame of the turn is a matrix.
      child: RepaintBoundary(child: stage),
      builder: (context, child) {
        final from = _turnFrom;
        final t = _turn.value;
        if (from == null || !_turn.isAnimating || rect.isEmpty) return child!;
        // A little past square and back: the frame settles, it doesn't stop.
        final e = const Cubic(0.3, 1.18, 0.45, 1).transform(t);
        final s0 = from.width / rect.height;
        final scale = s0 + (1 - s0) * e;
        final angle = -math.pi / 2 * (1 - e);
        final c = rect.center;
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(c.dx, c.dy, 0, 1)
            ..rotateZ(angle)
            ..scaleByDouble(scale, scale, 1, 1)
            ..translateByDouble(-c.dx, -c.dy, 0, 1),
          child: child,
        );
      },
    );
  }

  // ---------------------------------------------------------------- drawing

  Offset _clampUnit(Offset n) =>
      Offset(n.dx.clamp(0.0, 1.0), n.dy.clamp(0.0, 1.0));

  /// The brush, in image-width fractions, as it should land right now.
  ///
  /// Divided by the zoom so a stroke drawn while zoomed in keeps the weight
  /// the user sees on screen — zooming in is how you draw the fine detail,
  /// and a marker that grows 4× with the picture would defeat it.
  double get _strokeWidthNow =>
      _width / math.max(1.0, _zoom.value.getMaxScaleOnAxis());

  void _drawStart(Offset local, Rect stage) {
    if (_saving) return;
    if (!stage.contains(local)) return;
    HapticFeedback.selectionClick();
    setState(() => _drawing = _chromeDimmed = true);
    _current = _EditorStroke(
      color: _color,
      width: _strokeWidthNow,
      points: [
        _clampUnit(stageToNorm(local, viewport: _viewport, stage: stage)),
      ],
    );
    _liveRev.value++;
  }

  void _drawUpdate(Offset local, Rect stage) {
    final stroke = _current;
    if (stroke == null) return;
    stroke.points.add(
      _clampUnit(stageToNorm(local, viewport: _viewport, stage: stage)),
    );
    _liveRev.value++;
  }

  void _drawEnd() {
    final stroke = _current;
    _current = null;
    _liveRev.value++;
    // Twice per stroke, not once per pointer move — the live stroke itself is
    // still driven by the repaint notifier, not by rebuilding.
    if (_drawing) setState(() => _drawing = false);
    if (stroke == null) return;
    _commit(stroke);
  }

  void _drawDot(Offset local, Rect stage) {
    if (_saving || !stage.contains(local)) return;
    HapticFeedback.selectionClick();
    _commit(
      _EditorStroke(
        color: _color,
        width: _strokeWidthNow,
        points: [
          _clampUnit(stageToNorm(local, viewport: _viewport, stage: stage)),
        ],
      ),
    );
  }

  void _commit(_EditorStroke stroke) {
    _strokes.add(stroke);
    // A new stroke forks the history — anything that was undone is gone.
    _redo.clear();
    _committedRev.value++;
    // Enables/disables undo, redo and USE PHOTO.
    setState(() {});
  }

  void _undo() {
    if (_strokes.isEmpty || _saving) return;
    HapticFeedback.lightImpact();
    _undoKicks++;
    _redo.add(_strokes.removeLast());
    _committedRev.value++;
    setState(() {});
  }

  void _redoStroke() {
    if (_redo.isEmpty || _saving) return;
    HapticFeedback.lightImpact();
    _redoKicks++;
    _strokes.add(_redo.removeLast());
    _committedRev.value++;
    setState(() {});
  }

  void _clearStrokes() {
    if (_strokes.isEmpty || _saving) return;
    HapticFeedback.mediumImpact();
    // Moved rather than dropped, and in reverse, so redo rebuilds them in the
    // order they were drawn.
    while (_strokes.isNotEmpty) {
      _redo.add(_strokes.removeLast());
    }
    _committedRev.value++;
    setState(() {});
  }

  // ------------------------------------------------------------------ export

  /// Hold on the send arrow: the schedule sheet, then the same export a send
  /// does, handed back with the instant to queue it for.
  Future<void> _schedule() async {
    if (_saving || _display == null) return;
    _captionFocus.unfocus();
    final refusal = widget.scheduleRefusal;
    if (refusal != null) {
      AppToast.of(context).show(refusal);
      return;
    }
    // No haptic of its own: the hold that got here already landed its heavy
    // impact (see HoldRingButton).
    final l10n = AppLocalizations.of(context);
    // What is being committed to a date: the first caption, or how many
    // photos there are when nobody wrote one.
    final caption = _draft._pages
        .map((p) => p.caption.trim())
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    final choice = await showScheduleMessageSheet(
      context,
      preview: caption.isNotEmpty
          ? caption
          : (_draft.length > 1
                ? l10n.photoTrayCountLabel(_draft.length)
                : l10n.attachmentMenuPhotoLabel),
    );
    if (choice is! ScheduleAt || !mounted) return;
    await _save(scheduleAt: choice.at);
  }

  /// Whether this send flies its picture into the chat: chat's own preview
  /// (captions are chat's), one photo going now, and not view once, whose
  /// bubble is sealed and has no picture to land on. A multi-photo send
  /// lands as a stack and the inline picker's sends its whole selection, so
  /// neither has one bubble that is this picture.
  bool _fliesOnSend(DateTime? scheduleAt) =>
      scheduleAt == null &&
      widget.allowCaptions &&
      !widget.closeKeeps &&
      widget.confirmLabel == null &&
      !_viewOnce &&
      _draft.length == 1;

  /// A still of the stage as it is on screen, for [PhotoSendFlight]: the
  /// image, the part of it that is the picture, and where that sits.
  ({ui.Image image, Rect src, Rect from})? _stageShot() {
    final box = _shotKey.currentContext?.findRenderObject();
    final stage = _lastStage;
    if (box is! RenderRepaintBoundary || !box.attached || stage == null) {
      return null;
    }
    try {
      // Capped: the still shrinks to a bubble, and a 3x copy of a full
      // screen is memory spent on pixels nobody sees.
      final ratio = math.min(2.0, MediaQuery.devicePixelRatioOf(context));
      final image = box.toImageSync(pixelRatio: ratio);
      final src = Rect.fromLTRB(
        stage.left * ratio,
        stage.top * ratio,
        stage.right * ratio,
        stage.bottom * ratio,
      );
      final from = MatrixUtils.transformRect(box.getTransformTo(null), stage);
      return (image: image, src: src, from: from);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save({DateTime? scheduleAt}) async {
    if (_saving || _display == null) return;
    // Before anything changes on screen: the still is what was being looked
    // at when Send was tapped.
    final shot = _fliesOnSend(scheduleAt) ? _stageShot() : null;
    _captionFocus.unfocus();
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);

    // Sequential, not `Future.wait`: each export can be a full-resolution
    // decode and a JPEG encode, and ten of those at once is ten 12 megapixel
    // bitmaps resident before a single one has been sent. In order, too — the
    // rail's order is the order they arrive in the conversation.
    final out = <EditorPhoto>[];
    var dropped = 0;
    var downgraded = 0;
    for (final page in List.of(_draft._pages)) {
      final (image, wasDowngraded) = await _exportPage(page);
      if (!mounted) {
        shot?.image.dispose();
        return;
      }
      if (wasDowngraded) downgraded++;
      if (image == null) {
        dropped++;
        continue;
      }
      final caption = page.caption.trim();
      out.add(
        EditorPhoto(
          image: image,
          caption: _viewOnce || caption.isEmpty ? null : caption,
        ),
      );
    }
    if (out.isEmpty) {
      shot?.image.dispose();
      toast.show(l10n.photoTrayLoadFailedSnack, tone: ToastTone.danger);
      setState(() => _saving = false);
      return;
    }
    // Per photo, so it names how many: in a set of five, only the ones that
    // were actually over the cap lost their HD.
    if (downgraded > 0) {
      toast.show(l10n.photoHdOverCapSnack(
        downgraded,
        formatFileSize(kMaxFileUploadBytes),
      ));
    }
    if (shot != null) {
      PhotoSendFlight.launch(
        context,
        image: shot.image,
        src: shot.src,
        from: shot.from,
      );
      setState(() => _flown = true);
    }
    Navigator.of(context).pop(
      EditorSend(
        photos: out,
        viewOnce: _viewOnce,
        spoiler: widget.allowSpoiler && _options.spoiler,
        dropped: dropped,
        scheduleAt: scheduleAt,
      ),
    );
  }

  /// Produces the bytes to send for [page], and whether HD had to give way.
  ///
  /// HD sends the full resolution, and a large sensor's full resolution can
  /// pass the upload cap that every other send respects. Such a photo goes at
  /// standard quality instead, and the caller says so, rather than going up
  /// as a file the upload budget cannot hold.
  Future<(CroppedImage?, bool)> _exportPage(_EditorPage page) async {
    if (!_hd) return (await _exportPageAs(page, hd: false), false);
    final image = await _exportPageAs(page, hd: true);
    if (image == null || image.bytes.length <= kMaxFileUploadBytes) {
      return (image, false);
    }
    return (await _exportPageAs(page, hd: false), true);
  }

  /// Produces the bytes to send for [page] at [hd] or standard quality. Null
  /// when it cannot be decoded.
  Future<CroppedImage?> _exportPageAs(_EditorPage page, {required bool hd}) async {
    // Untouched photo: hand back the original bytes. Re-encoding would cost a
    // JPEG generation and a full-resolution rasterize to produce something
    // meant to be identical to what we were given.
    //
    // The rule about WHEN that is allowed — HD, or already inside the cap —
    // lives in `prepareUneditedForSend` rather than here, so every path that
    // sends an unedited picture applies the same three lines.
    if (!page.hasEdits) {
      final ready = await prepareUneditedForSend(page.source, hd: hd);
      if (ready != null) return ready;
      // Null means a header we could not read or a decode that failed. Not a
      // reason to lose the send: fall through to the full export path below,
      // which takes its dimensions from a real decode and applies the same cap.
    }

    ui.Image? full;
    try {
      // Full resolution, deliberately uncapped: the file the user sends is the
      // one they gave us, at the size they gave it to us. A tall photo stays
      // tall.
      full = await decodeImageBytes(page.source);
      final srcW = full.width.toDouble();
      final srcH = full.height.toDouble();
      // Rotation swaps the axes an odd number of times.
      final rotated =
          page.rotations.isOdd ? Size(srcH, srcW) : Size(srcW, srcH);

      final crop = page.crop;
      final cropPx = Rect.fromLTRB(
        crop.left * rotated.width,
        crop.top * rotated.height,
        crop.right * rotated.width,
        crop.bottom * rotated.height,
      );
      final outW = math.max(1, cropPx.width.round());
      final outH = math.max(1, cropPx.height.round());
      final dst = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());

      // The cap is applied to the RASTER, not to the drawing space. Everything
      // below — the crop translate, the rotation, the stroke widths, which are
      // a fraction of `rotated.width` — keeps working in full crop resolution
      // and needs no knowledge that a cap exists; only the canvas transform and
      // the output bitmap size do. Capping the source decode instead would be
      // cheaper, but a tight crop out of a pre-shrunk image loses detail the
      // user explicitly framed for.
      final scale = hd
          ? 1.0
          : math.min(1.0, kSendPhotoMaxEdge / math.max(outW, outH));
      final rasterW = math.max(1, (outW * scale).round());
      final rasterH = math.max(1, (outH * scale).round());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, rasterW.toDouble(), rasterH.toDouble()),
      );
      // Before the save/restore pair below, so it survives the restore and
      // still governs the strokes drawn after it.
      if (scale != 1.0) canvas.scale(scale);
      // Opaque backdrop: rasterToJpegBytes reads PREMULTIPLIED rawRgba, which
      // only equals straight RGBA where alpha is 255.
      canvas.drawRect(dst, Paint()..color = const Color(0xFF000000));

      canvas.save();
      // Shift the crop's origin to the canvas origin, then place the image in
      // rotated space. Composing the two means the crop rect needs no rotation
      // maths of its own — it is already expressed in the rotated frame.
      canvas.translate(-cropPx.left, -cropPx.top);
      _applyRotation(canvas, page.rotations, srcW, srcH);
      // After the rotation the canvas is back in the image's own unrotated
      // frame, which is where the display copy was flipped — so applying it
      // here replays the same order the user saw: mirror, then rotate.
      if (page.mirrored) mirrorCanvasHorizontally(canvas, srcW);
      canvas.drawImage(
        full,
        Offset.zero,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.medium,
      );
      canvas.restore();

      for (final stroke in page.strokes) {
        _paintStroke(
          canvas,
          stroke,
          viewport: crop,
          stage: dst,
          // Stroke width is a fraction of image width, and `dst` is 1:1 with
          // rotated pixels, so this is the same visual weight as on screen.
          strokeWidth: stroke.width * rotated.width,
        );
      }

      final picture = recorder.endRecording();
      final raster = await picture.toImage(rasterW, rasterH);
      picture.dispose();

      return await rasterToJpegBytes(
        raster,
        quality: hd ? kSendPhotoHdQuality : kSendPhotoQuality,
      );
    } catch (e) {
      debugPrint('[camera_editor] export failed: $e');
      return null;
    } finally {
      full?.dispose();
    }
  }

  /// Places the unrotated image into the rotated frame, for [rotations]
  /// quarter-turns clockwise of a [w]×[h] image.
  static void _applyRotation(Canvas canvas, int rotations, double w, double h) {
    switch (rotations) {
      case 1:
        canvas.translate(h, 0);
        canvas.rotate(math.pi / 2);
      case 2:
        canvas.translate(w, h);
        canvas.rotate(math.pi);
      case 3:
        canvas.translate(0, w);
        canvas.rotate(3 * math.pi / 2);
      default:
        break;
    }
  }

  /// Paints one stroke, mapping its normalized points into [stage].
  ///
  /// Shared by the on-screen painters and the exporter — the single reason the
  /// two can't drift apart.
  static void _paintStroke(
    Canvas canvas,
    _EditorStroke stroke, {
    required Rect viewport,
    required Rect stage,
    required double strokeWidth,
  }) {
    final pts = [
      for (final n in stroke.points)
        normToStage(n, viewport: viewport, stage: stage),
    ];
    if (pts.isEmpty) return;

    if (pts.length == 1) {
      // A tap is a dot. The old renderer skipped anything under two points, in
      // both the preview and the export, so a tap drew nothing at all.
      canvas.drawCircle(
        pts.first,
        strokeWidth / 2,
        Paint()
          ..color = stroke.color
          ..isAntiAlias = true,
      );
      return;
    }

    canvas.drawPath(
      strokePath(pts),
      Paint()
        ..color = stroke.color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  // -------------------------------------------------------------------- view

  /// The photo is the screen, on black — the gallery's black, not a blurred
  /// copy of the picture: the copy read as a smudge around the real thing.
  /// Chrome floats over it on glass, with the same top and bottom scrims the
  /// gallery uses so it stays legible over a bright photo.
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final cropping = _tool == _Tool.crop;
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final typing = _captionFocus.hasFocus;

    // Full-bleed while drawing. Crop is the exception: its handles live on the
    // picture's edges, so the picture is pulled clear of the chrome for as long
    // as the user is framing.
    final stagePad = cropping
        ? EdgeInsets.fromLTRB(24, safe.top + 64, 24, safe.bottom + 132)
        : EdgeInsets.zero;
    final interactive =
        !cropping && !_penArmed && _display != null && !_saving && !typing;

    // The gallery's preview: a system back is the ×, and keeps the work.
    return PopScope(
      canPop: !widget.closeKeeps,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _discard();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      // The keyboard lifts the caption bar, not the photo: resizing the stage
      // under a rising keyboard made the picture shrink and jump.
      resizeToAvoidBottomInset: false,
      body: BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              padding: stagePad,
              duration: theme.motionMed,
              curve: Curves.easeOutCubic,
              child: _flown
                  ? const SizedBox.expand()
                  : _swipeable(
                _zoomable(_stage(), interactive: interactive),
                // Not gated on the decode, unlike zoom: the photo swiped to is
                // drawn from its preview at once, and a quick second swipe
                // must not be dropped while the first one's decode runs.
                enabled: !cropping &&
                    !_penArmed &&
                    !_saving &&
                    !typing &&
                    !_isZoomed &&
                    _draft.length > 1,
              ),
            ),
            // While the caption is being typed, a tap on the photo puts the
            // keyboard away — the one thing anybody means by it.
            if (typing)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _captionFocus.unfocus,
                  child: const ColoredBox(color: Color(0x59000000)),
                ),
              ),
            // Nothing here sets an opaque hit-test behaviour except the controls
            // themselves, so the gaps between them stay drawable.
            IgnorePointer(
              ignoring: _drawing,
              child: AnimatedOpacity(
                opacity: _drawing ? 0.16 : 1,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                onEnd: () {
                  if (mounted && !_drawing && _chromeDimmed) {
                    setState(() => _chromeDimmed = false);
                  }
                },
                // The chrome is media glass, and glass inside a fading layer
                // blurs the layer's empty buffer instead of the photo: a flat
                // wash at 16% and a snap to frost when the fade back ends.
                // Still discs have no blur to get wrong.
                child: GlassStill(
                still: _chromeDimmed,
                child: Stack(
                  children: [
                    if (!cropping) ...[
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: MediaScrim(height: safe.top + 96, fromTop: true),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: MediaScrim(
                          height: safe.bottom + keyboard + 180,
                        ),
                      ),
                    ],
                    SafeArea(
                      child: Stack(
                        children: [
                          Positioned(
                            left: 12,
                            right: 12,
                            top: 6,
                            child: _topRail(theme, cropping),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 10,
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 120),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.only(
                                bottom: math.max(0.0, keyboard - safe.bottom),
                              ),
                              child: _bottomRail(theme, cropping),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
            if (_saving || _adding)
              // Opaque on purpose: a stray tap on a thumbnail mid-export would
              // reorder the send that is running.
              Positioned.fill(
                child: AbsorbPointer(
                  // Only a library read gets the dim and the spinner. A send
                  // says so on its own button, and a grey veil dropping over
                  // the photo the instant Send is tapped read as an error,
                  // not as "it's going".
                  child: _adding
                      ? ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Center(child: PhotoSpinner()),
                        )
                      : const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  /// Pinch and double-tap zoom over the stage, while nothing else wants the
  /// gestures. With the pen out or the crop handles up the zoom is held as a
  /// plain transform instead: those gestures belong to the tool, and a scale
  /// recognizer in the same arena would fight them for every drag.
  Widget _zoomable(Widget stage, {required bool interactive}) {
    if (!interactive) {
      return AnimatedBuilder(
        animation: _zoom,
        builder: (_, child) => Transform(transform: _zoom.value, child: child),
        child: stage,
      );
    }
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _zoom,
        minScale: 1,
        maxScale: _maxZoom,
        // At 1× a one-finger drag is a swipe to the next photo, not a pan
        // with nowhere to go; pinching still zooms.
        panEnabled: _isZoomed || _draft.length < 2,
        child: stage,
      ),
    );
  }

  /// Swipes between the draft's photos, the Photos way: the picture follows
  /// the finger with its neighbour sliding in beside it, and a release past a
  /// quarter of the screen — or a flick — carries on to it.
  ///
  /// Only at 1× with no tool out. Zoomed in, the same drag pans the photo;
  /// with the pen or the crop handles up, it belongs to the tool.
  Widget _swipeable(Widget current, {required bool enabled}) {
    if (_draft.length < 2) return current;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        _pageWidth = w;
        final i = _draft._index;
        final prev = i > 0 ? _draft._pages[i - 1] : null;
        final next = i < _draft.length - 1 ? _draft._pages[i + 1] : null;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: enabled ? (_) => _swipeCtrl.stop() : null,
          onHorizontalDragUpdate: enabled
              ? (d) {
                  var dx = _swipeDx.value + d.delta.dx;
                  // Past the first or the last photo it gives a little and
                  // no more, so the edge is felt rather than hit.
                  if ((dx > 0 && prev == null) || (dx < 0 && next == null)) {
                    dx = _swipeDx.value + d.delta.dx * 0.3;
                  }
                  _swipeDx.value = dx;
                }
              : null,
          onHorizontalDragEnd: enabled
              ? (d) => _endSwipe(
                  d.velocity.pixelsPerSecond.dx,
                  hasPrev: prev != null,
                  hasNext: next != null,
                )
              : null,
          onHorizontalDragCancel: enabled
              ? () => _endSwipe(0, hasPrev: false, hasNext: false)
              : null,
          child: ValueListenableBuilder<double>(
            valueListenable: _swipeDx,
            child: current,
            builder: (context, dx, child) => Stack(
              fit: StackFit.expand,
              children: [
                if (prev != null && dx > 0)
                  Transform.translate(
                    offset: Offset(dx - w - _swipeGap, 0),
                    child: _PagePreview(page: prev),
                  ),
                Transform.translate(offset: Offset(dx, 0), child: child),
                if (next != null && dx < 0)
                  Transform.translate(
                    offset: Offset(dx + w + _swipeGap, 0),
                    child: _PagePreview(page: next),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _endSwipe(
    double velocity, {
    required bool hasPrev,
    required bool hasNext,
  }) {
    final w = _pageWidth;
    final dx = _swipeDx.value;
    var step = 0;
    if (hasNext && (dx < -w * 0.25 || (velocity < -500 && dx < 0))) {
      step = 1;
    } else if (hasPrev && (dx > w * 0.25 || (velocity > 500 && dx > 0))) {
      step = -1;
    }
    final target = step == 0 ? 0.0 : -step * (w + _swipeGap);
    final tween = Tween<double>(begin: dx, end: target).animate(
      CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOutCubic),
    );
    void tick() => _swipeDx.value = tween.value;
    tween.addListener(tick);
    _swipeCtrl
      ..value = 0
      ..duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
      );
    _swipeCtrl.forward().whenCompleteOrCancel(() {
      tween.removeListener(tick);
      if (!mounted) return;
      if (step != 0 && _swipeDx.value == target) {
        // The neighbour that slid in is drawn in the same place by the stage
        // until its own decode lands, so the hand-over has no seam.
        _selectPage(_draft._index + step);
      }
      _swipeDx.value = 0;
    });
  }

  Widget _topRail(AppTheme theme, bool cropping) {
    final ready = _display != null && !_saving;
    final l10n = AppLocalizations.of(context);
    // Undo and redo arrive TOGETHER and keep their places: undo on the left,
    // redo on the right, the one with nothing to do dimmed rather than gone.
    // Shown and hidden one at a time, undoing the last stroke removed undo
    // and slid redo under the finger — so tapping undo repeatedly undid,
    // then redid, then undid again.
    final hasHistory =
        !cropping && (_penArmed || _strokes.isNotEmpty || _redo.isNotEmpty);
    final history = [
      if (hasHistory) ...[
        GlassGroupItem(
          glyph: GlyphKick(
            trigger: _undoKicks,
            builder: (_, k) => UndoGlyph(
              color: _saving || _strokes.isEmpty
                  ? MediaGlass.inkDisabled
                  : MediaGlass.ink,
              kick: k,
            ),
          ),
          semanticLabel: l10n.cameraEditorScreenUndoSemanticLabel,
          onTap: _saving || _strokes.isEmpty ? null : _undo,
        ),
        GlassGroupItem(
          glyph: GlyphKick(
            trigger: _redoKicks,
            builder: (_, k) => UndoGlyph(
              color: _saving || _redo.isEmpty
                  ? MediaGlass.inkDisabled
                  : MediaGlass.ink,
              redo: true,
              kick: k,
            ),
          ),
          semanticLabel: l10n.cameraEditorScreenRedoSemanticLabel,
          onTap: _saving || _redo.isEmpty ? null : _redoStroke,
        ),
      ],
    ];
    final frame = [
      if (cropping && _crop != const Rect.fromLTWH(0, 0, 1, 1))
        GlassGroupItem(
          icon: CupertinoIcons.arrow_2_circlepath,
          semanticLabel: l10n.cameraEditorScreenResetCropSemanticLabel,
          onTap: _saving ? null : _resetCrop,
        ),
      // Drawn, and turning the way the photo does: clockwise. The icon
      // font's rotate_left promised the opposite of what a tap did.
      GlassGroupItem(
        glyph: GlyphKick(
          trigger: _rotateKicks,
          duration: const Duration(milliseconds: 520),
          builder: (_, k) => RotateGlyph(
            color: ready ? MediaGlass.ink : MediaGlass.inkDisabled,
            kick: k,
          ),
        ),
        semanticLabel: l10n.cameraEditorScreenRotateSemanticLabel,
        onTap: ready ? _rotate90 : null,
      ),
      // Crop lives up here, icon only, as the second of the two things you
      // can do to the frame itself.
      if (!cropping)
        GlassGroupItem(
          glyph: CropGlyph(
            color: ready ? MediaGlass.ink : MediaGlass.inkDisabled,
          ),
          semanticLabel: l10n.cameraEditorScreenCropSemanticLabel,
          onTap: ready ? () => _selectTool(_Tool.crop) : null,
        ),
    ];
    return Row(
      children: [
        // An ×, not a back chevron, even where this is pushed plainly: it
        // discards the photo (or the crop), which is an act, not navigation.
        GlassCloseButton(
          tone: GlassTone.media,
          semanticLabel: cropping
              ? l10n.cameraEditorScreenCancelCropSemanticLabel
              : widget.closeKeeps
              ? MaterialLocalizations.of(context).closeButtonLabel
              : (_draft.length > 1
                    ? l10n.photoTrayDiscardSemanticLabel
                    : l10n.cameraEditorScreenDiscardPhotoSemanticLabel),
          enabled: !_saving,
          onTap: cropping ? _cancelCrop : _discard,
        ),
        const Spacer(),
        // Only while drawing is in play — a greyed pair over a photo nobody is
        // drawing on is noise. Grouped the iOS 26 way: one pill.
        if (history.isNotEmpty) ...[
          GlassButtonGroup(haptic: false, items: history),
          const SizedBox(width: 8),
        ],
        GlassButtonGroup(haptic: false, items: frame),
      ],
    );
  }

  Widget _stage() {
    if (_loadError != null) {
      // No browser decodes HEIC, and image_picker_for_web hands the original
      // blob straight through when its own canvas resize fails on one — so a
      // HEIC picked on the web lands here every time. Naming the reason beats
      // "couldn't open that image", which reads as our bug and leaves the user
      // with nothing to try.
      final heic =
          kIsWeb && sniffImageContentType(_page.source) == 'image/heic';
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          heic
              ? l10n.cameraEditorScreenHeicUnsupportedMessage
              : l10n.cameraEditorScreenImageLoadFailedMessage,
          textAlign: TextAlign.center,
          style: ThemeScope.of(context).body.copyWith(
            color: MediaGlass.inkDim,
            fontSize: 15,
            height: 1.35,
            decoration: TextDecoration.none,
          ),
        ),
      );
    }
    final img = _display;
    if (img == null) {
      // A photo just swiped or tapped to: its quick preview holds the frame
      // while the full decode runs, rather than a spinner flashing between
      // two pictures.
      if (_draft.length > 1) return _PagePreview(page: _page);
      return const Center(child: PhotoSpinner());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final viewport = _viewport;
        final stage = fitContain(
          box: box,
          aspect: pixelAspect(viewport, _imageSize),
        );
        if (stage.isEmpty) return const SizedBox.shrink();

        // Where the WHOLE image lands, which equals `stage` while cropping and
        // overflows it once a crop is applied. One expression covers both, so
        // the clip does the work instead of a branch.
        final imageRect = Rect.fromPoints(
          normToStage(Offset.zero, viewport: viewport, stage: stage),
          normToStage(const Offset(1, 1), viewport: viewport, stage: stage),
        );
        final strokeScale = stage.width / viewport.width;
        _lastStage = stage;

        return _turning(Stack(
          children: [
            // Positioned.fill, so the clip and the layers inside it are
            // handed tight box-sized constraints. Left as a loose child, the
            // inner Stack would have only positioned children and would have
            // to infer its size from the constraints it happened to get.
            Positioned.fill(
              child: RepaintBoundary(
                key: _shotKey,
                child: ClipRect(
                clipper: _StageClip(stage),
                // What the recipient will see: with Spoiler on the photo
                // sits under the same blur and dust as in the chat. Lifted
                // while the pen is out or the frame is being cropped, so the
                // work is done on the real picture.
                child: _SpoilerPreview(
                  // Carried across the zoom wrapper's swap (picking up the
                  // pen rebuilds the stage under a different parent), so a
                  // veil mid-flight keeps flying instead of snapping.
                  key: _veilKey,
                  veiled: widget.allowSpoiler &&
                      _options.spoiler &&
                      !_penArmed &&
                      _tool != _Tool.crop,
                  center: stage.center,
                  seed: _page.hashCode & 0x7fffffff,
                  builder: (keyed) => Stack(
                  children: [
                    Positioned.fromRect(
                      rect: imageRect,
                      child: RawImage(
                        key: keyed ? cameraEditorStageImageKey : null,
                        image: img,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    // Committed strokes and the in-progress one paint on
                    // separate boundaries: dragging then re-rasterizes only
                    // the live layer, leaving the decoded photo and the
                    // finished strokes alone.
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _StrokesPainter(
                            strokes: _strokes,
                            viewport: viewport,
                            stage: stage,
                            strokeScale: strokeScale,
                            revision: _committedRev,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _LiveStrokePainter(
                            current: () => _current,
                            viewport: viewport,
                            stage: stage,
                            strokeScale: strokeScale,
                            revision: _liveRev,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
              ),
            ),
            if (_tool == _Tool.crop) ..._cropLayers(stage, viewport),
            // Only while the pen is out. Mounted unconditionally, as it used
            // to be, every stray swipe across the photo left a mark on it.
            if (_tool == _Tool.draw && _penArmed)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _drawDot(d.localPosition, stage),
                  onPanStart: (d) => _drawStart(d.localPosition, stage),
                  onPanUpdate: (d) => _drawUpdate(d.localPosition, stage),
                  onPanEnd: (_) => _drawEnd(),
                  onPanCancel: _drawEnd,
                ),
              ),
          ],
        ), stage);
      },
    );
  }

  // --------------------------------------------------------------- crop mode

  List<Widget> _cropLayers(Rect stage, Rect viewport) {
    final cropStage = Rect.fromPoints(
      normToStage(_crop.topLeft, viewport: viewport, stage: stage),
      normToStage(_crop.bottomRight, viewport: viewport, stage: stage),
    );
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _CropOverlayPainter(stage: stage, crop: cropStage),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            _activeHandle = _hitHandle(d.localPosition, cropStage);
            if (_activeHandle != null) HapticFeedback.selectionClick();
          },
          onPanUpdate: (d) {
            final handle = _activeHandle;
            if (handle == null) return;
            // Screen delta → normalized delta, through the same mapping
            // everything else uses.
            final delta = Offset(
              d.delta.dx / stage.width * viewport.width,
              d.delta.dy / stage.height * viewport.height,
            );
            setState(() {
              _crop = resizeCrop(
                crop: _crop,
                handle: handle,
                delta: delta,
                imageSize: _imageSize,
                aspect: _resolvedAspect(),
              );
            });
          },
          onPanEnd: (_) => _activeHandle = null,
          onPanCancel: () => _activeHandle = null,
        ),
      ),
    ];
  }

  /// Which handle a touch at [p] grabs.
  ///
  /// Corners win over edges so the two never fight in the overlap, and the slop
  /// is a finger's worth rather than the hairline the handles are drawn at.
  static CropHandle? _hitHandle(Offset p, Rect crop) {
    const slop = 30.0;
    bool near(double a, double b) => (a - b).abs() <= slop;
    final withinX = p.dx >= crop.left - slop && p.dx <= crop.right + slop;
    final withinY = p.dy >= crop.top - slop && p.dy <= crop.bottom + slop;
    if (!withinX || !withinY) return null;

    final onLeft = near(p.dx, crop.left);
    final onRight = near(p.dx, crop.right);
    final onTop = near(p.dy, crop.top);
    final onBottom = near(p.dy, crop.bottom);

    if (onLeft && onTop) return CropHandle.topLeft;
    if (onRight && onTop) return CropHandle.topRight;
    if (onLeft && onBottom) return CropHandle.bottomLeft;
    if (onRight && onBottom) return CropHandle.bottomRight;
    if (onLeft) return CropHandle.left;
    if (onRight) return CropHandle.right;
    if (onTop) return CropHandle.top;
    if (onBottom) return CropHandle.bottom;
    return crop.contains(p) ? CropHandle.move : null;
  }

  // ------------------------------------------------------------ bottom chrome

  /// Everything along the bottom edge. [AnimatedSize] carries the height change
  /// when the pen tray opens or the view-once note appears, so the rail rises
  /// rather than jumping.
  Widget _bottomRail(AppTheme theme, bool cropping) {
    return AnimatedSize(
      duration: theme.motionMed,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      // Unclipped: a note dropping in rides above the growing box, and a
      // clip cut it in half for the length of the rise.
      clipBehavior: Clip.none,
      child: cropping ? _cropRail(theme) : _drawRail(theme),
    );
  }

  Widget _cropRail(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scaled down, never clipped, when a translation's presets
          // ("Serbest", "Orijinal") outgrow a narrow phone.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: LiquidGlass(
              tone: GlassTone.media,
              shape: LiquidGlassShape.rounded,
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final preset in _AspectPreset.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _Chip(
                          label: _presetLabel(preset),
                          selected: preset == _preset,
                          accent: theme.accent,
                          accentInk: theme.accentInk,
                          onTap: _saving ? null : () => _selectPreset(preset),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              GlassPillButton(
                tone: GlassTone.media,
                label: AppLocalizations.of(
                  context,
                ).cameraEditorScreenCropDoneButton,
                icon: CupertinoIcons.checkmark,
                tint: theme.accent,
                onTap: _saving || _display == null
                    ? null
                    : () => _selectTool(_Tool.draw),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawRail(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final canCamera = widget.canRetake && (!_multi || _hasRoom);
    final canLibrary =
        _multi &&
        _hasRoom &&
        (widget.galleryOverCamera || widget.pickMore != null);
    // Where a photo comes from, grouped the iOS 26 way: one piece of glass.
    final sources = [
      if (canLibrary)
        GlassGroupItem(
          icon: CupertinoIcons.photo_on_rectangle,
          semanticLabel: l10n.photoTrayAddMoreSemanticLabel,
          onTap: _saving || _adding ? null : _addFromLibrary,
        ),
      if (canCamera)
        GlassGroupItem(
          icon: CupertinoIcons.camera,
          semanticLabel: _multi
              ? l10n.cameraEditorScreenAddFromCameraSemanticLabel
              : l10n.cameraEditorScreenRetakeSemanticLabel,
          onTap: _saving ? null : _takeAnother,
        ),
    ];
    // What happens to the picture and to the send, in one pill: the shared
    // send switches every picture preview offers, drawn glyphs that morph.
    final switches = mediaSendSwitchItems(
      context,
      options: _options,
      enabled: !_saving,
      viewOnce: widget.allowViewOnce,
      spoiler: widget.allowSpoiler,
      penArmed: widget.allowDrawing ? _penArmed : null,
      onPen: _togglePen,
    );
    final ready = !_saving && _display != null;
    // Chat's send is the round accent arrow every iOS messenger uses; a
    // caller with its own word for it ("Use photo") gets that word on the
    // prominent glass capsule instead.
    final Widget commit = widget.confirmLabel == null
        ? SendButton(
            busy: _saving,
            semanticLabel: l10n.cameraEditorScreenSendButton,
            onSend: ready ? _save : null,
            // Hold to send later — the chat composer's own button, so the
            // same hand that schedules a text schedules a photo.
            onSchedule: ready && widget.allowSchedule ? _schedule : null,
          )
        : GlassPillButton(
            tone: GlassTone.media,
            label: _saving
                ? (widget.busyLabel ?? l10n.cameraEditorScreenSendingButton)
                : widget.confirmLabel!,
            tint: theme.accent,
            onTap: ready ? _save : null,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Only while armed — in crop mode the rail means "commit the frame",
        // and a note about sending would answer a question the user isn't
        // asking yet.
        // One note at most, the weightiest armed switch's: three stacked
        // capsules over a photo would be a form, not a reminder.
        //
        // Only when HD is armed, for HD. The compressed default needs no
        // caption — it is what every photo has always looked like to the
        // recipient, and narrating it would turn a good default into a
        // decision.
        _notes(theme, l10n),
        if (_penArmed)
          Padding(
            key: const ValueKey('pen'),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _penTray(theme),
          ),
        if (_draft.length > 1)
          Padding(
            key: const ValueKey('filmstrip'),
            padding: const EdgeInsets.only(bottom: 4),
            child: MediaFilmstrip(
              count: _draft.length,
              index: _draft._index,
              onTap: _selectPage,
              onRemove: _saving ? null : _removePage,
              removeSemanticLabel: l10n.photoTrayRemoveSemanticLabel,
              tileSemanticLabel: (i, total) =>
                  l10n.photoChromeThumbnailSemanticLabel(i, total),
              // The page itself: a removal slides the photos after it
              // along instead of repainting them one place to the left.
              tileKey: (i) => _draft._pages[i],
              thumbnailBuilder: (context, i) => _PageThumb(
                page: _draft._pages[i],
              ),
            ),
          ),
        // Keyed, like everything in this column that can come and go above
        // it: a note appearing must not remount the switches mid-morph.
        Padding(
          key: const ValueKey('rail'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (sources.isNotEmpty) ...[
                GlassButtonGroup(haptic: false, items: sources),
                const SizedBox(width: 8),
              ],
              GlassButtonGroup(items: switches, haptic: false),
              const Spacer(),
              if (!widget.allowCaptions) commit,
            ],
          ),
        ),
        // The message bar: what to say under this photo, and send — where
        // every chat app keeps the two.
        if (widget.allowCaptions)
          Padding(
            key: const ValueKey('caption'),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _captionField(theme)),
                const SizedBox(width: 8),
                commit,
              ],
            ),
          ),
      ],
    );
  }

  /// One caption per photo, on the same glass as the controls around it.
  ///
  /// Off while view-once is armed, and says so: the message text outlives the
  /// photo, so a caption is the one part of a view-once send that would not
  /// disappear.
  Widget _captionField(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final enabled = !_viewOnce && !_saving;
    final style = theme.body.copyWith(
      color: MediaGlass.ink,
      fontSize: 16,
      height: 1.3,
      decoration: TextDecoration.none,
    );
    return LiquidGlass(
      tone: GlassTone.media,
      shape: LiquidGlassShape.rounded,
      radius: 20,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 9, 14, 9),
          child: TextField(
            key: cameraEditorCaptionKey,
            controller: _viewOnce ? _noCaption : _caption,
            focusNode: _captionFocus,
            enabled: enabled,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            keyboardAppearance: Brightness.dark,
            cursorColor: theme.accent,
            style: style,
            decoration: InputDecoration.collapsed(
              hintText: _viewOnce
                  ? l10n.cameraEditorScreenCaptionViewOnceHint
                  : l10n.cameraEditorScreenCaptionHint,
              hintStyle: style.copyWith(color: MediaGlass.inkDim),
            ),
          ),
        ),
      ),
    );
  }

  /// The one note above the rail ("Sends in full resolution", "Opens
  /// once"), on the shared media capsule, wearing the armed switch's own
  /// glyph so the two read as one thing.
  ///
  /// A new note drops in from the rail and the old one sinks back into it,
  /// and the glyph arms itself as it lands (the ring floods, the eye shuts,
  /// the badge traces round HD). The capsule's glass goes flat for the
  /// length of the move and frosts when it settles: a blur is never
  /// animated (see [GlassStill]).
  Widget _notes(AppTheme theme, AppLocalizations l10n) {
    final SendSwitch? kind = _viewOnce
        ? SendSwitch.viewOnce
        : (widget.allowSpoiler && _options.spoiler)
        ? SendSwitch.spoiler
        : _hd
        ? SendSwitch.hd
        : null;
    Widget? note;
    if (kind != null) {
      final text = switch (kind) {
        SendSwitch.viewOnce => l10n.cameraEditorScreenViewOnceNote,
        SendSwitch.spoiler => l10n.mediaSendSpoilerNote,
        _ => l10n.cameraEditorScreenHdNote,
      };
      final ink = theme.accent;
      note = Padding(
        key: ValueKey(kind),
        padding: const EdgeInsets.only(bottom: 10),
        child: MediaNoteCapsule(
          glyph: TweenAnimationBuilder<double>(
            tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (_, on, _) => RepaintBoundary(
              child: switch (kind) {
                SendSwitch.viewOnce => ViewOnceGlyph(
                    color: ink,
                    knockout: const Color(0xFF2C2C30),
                    on: on,
                    size: 16,
                  ),
                SendSwitch.spoiler =>
                  SpoilerGlyph(color: ink, on: on, burst: on, size: 16),
                _ => HdGlyph(color: ink, on: on, kick: on, size: 16),
              },
            ),
          ),
          text: sentenceCaseOf(context, text),
        ),
      );
    }
    final calm = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: calm ? Duration.zero : const Duration(milliseconds: 320),
      reverseDuration: calm ? Duration.zero : const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeInCubic,
      // Bottom-anchored, so a note leaving does not tug the rail.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, a) => AnimatedBuilder(
        animation: a,
        child: child,
        builder: (context, child) {
          final t = a.value;
          return GlassStill(
            still: a.status != AnimationStatus.completed,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - t)),
              child: Transform.scale(
                scale: 0.82 + 0.18 * t,
                alignment: Alignment.bottomCenter,
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              ),
            ),
          );
        },
      ),
      child: note,
    );
  }

  /// Colours and brush size — hidden until the pen is out, which is the point:
  /// the old screen showed the whole palette permanently, to a user who most of
  /// the time only wanted to look at their photo and send it.
  Widget _penTray(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlass(
        tone: GlassTone.media,
        shape: LiquidGlassShape.rounded,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: HorizontalWheelScroll(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in _palette)
                              _Swatch(
                                color: c,
                                selected: _color == c,
                                onTap: _saving
                                    ? null
                                    : () => setState(() => _color = c),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    tone: GlassTone.media,
                    // Not CupertinoIcons.clear — that is the same glyph as
                    // xmark, which is the discard button at the top of the
                    // screen. Two controls that throw away very different
                    // amounts of work must not look identical.
                    icon: CupertinoIcons.trash,
                    semanticLabel: AppLocalizations.of(
                      context,
                    ).cameraEditorScreenClearDrawingSemanticLabel,
                    iconSize: 17,
                    onTap: _strokes.isEmpty || _saving ? null : _clearStrokes,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  // A live dot, at the colour and roughly the weight the stroke
                  // will land at. Scaled to read as a preview, not to match the
                  // true on-screen width — 0.045 of a photo is far wider than
                  // this tray.
                  SizedBox(
                    width: 24,
                    child: Center(
                      child: Container(
                        width: 5 + _width * 300,
                        height: 5 + _width * 300,
                        decoration: BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MediaGlass.stroke,
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WidthSlider(
                      value: _sliderForWidth(_width),
                      accent: theme.accent,
                      enabled: !_saving,
                      onChanged: (t) =>
                          setState(() => _width = _widthForSlider(t)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [image] of [page] flipped and turned the way the user left it — the one
/// place the rail tile and the swipe preview learn how, so they cannot come
/// to disagree about which way up a photo is.
Widget _asTurned(_EditorPage page, Widget image) {
  if (page.mirrored) {
    image = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
      child: image,
    );
  }
  if (page.rotations == 0) return image;
  return RotatedBox(quarterTurns: page.rotations, child: image);
}

/// A photo of the draft drawn whole, as the user has turned it — the
/// neighbour that slides in under a swipe, and the stand-in while the photo
/// swiped to decodes for real. Decoded at the screen's width, not the
/// stage's 2048, so a swipe costs a screenful of pixels.
/// The editor's spoiler preview: the stage under the blur, shade and dust
/// the chat will draw, so Spoiler is seen, not just switched.
///
/// It goes on and comes off the way a recipient opens one: a disc from the
/// middle of the picture. Turning it on, the veil swells out from the centre
/// with a bright rim riding its edge; turning it off (or picking up the pen)
/// a hole opens from the centre and pushes it out past the corners, which is
/// the tap-to-reveal the other side will see, rehearsed.
///
/// The blur itself never animates: at rest it is one [ImageFiltered] over the
/// real stage; in flight a still blurred copy is clipped by the moving disc
/// over the sharp one. [builder] is asked for that copy with `keyed` false,
/// so the stage image's key stays on the one real picture.
class _SpoilerPreview extends StatefulWidget {
  const _SpoilerPreview({
    super.key,
    required this.veiled,
    required this.center,
    required this.seed,
    required this.builder,
  });

  final bool veiled;

  /// Where the disc grows from: the picture's centre, in this box.
  final Offset center;
  final int seed;
  final Widget Function(bool keyed) builder;

  /// A touch heavier than the bubble's 20: the same blur reads weaker on a
  /// full screen than on a 260pt bubble.
  static const double _sigma = 28;

  @override
  State<_SpoilerPreview> createState() => _SpoilerPreviewState();
}

class _SpoilerPreviewState extends State<_SpoilerPreview>
    with SingleTickerProviderStateMixin {
  /// 1 veiled, 0 sharp.
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: kMediaSpoilerReveal,
    value: widget.veiled ? 1 : 0,
  )..addStatusListener((_) {
      if (mounted) setState(() {});
    });

  @override
  void didUpdateWidget(_SpoilerPreview old) {
    super.didUpdateWidget(old);
    if (old.veiled == widget.veiled) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.value = widget.veiled ? 1 : 0;
    } else if (widget.veiled) {
      _t.forward();
    } else {
      _t.reverse();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moving = _t.isAnimating;
    final rest = !moving && _t.value == 1;
    final shown = moving || rest;
    // Covering: the veil is the inside of a growing disc. Lifting: it is the
    // outside of one, a hole opening from the centre.
    final covering = _t.status == AnimationStatus.forward;
    return Stack(
      fit: StackFit.expand,
      children: [
        // A still, blurred once at rest rather than every frame the dust
        // over it moves (see [StillBlur]).
        StillBlur(
          enabled: rest,
          sigma: _SpoilerPreview._sigma,
          child: widget.builder(true),
        ),
        if (shown)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _t,
                builder: (context, veil) => moving
                    ? ClipPath(
                        clipper: _VeilDiscClipper(
                          widget.center,
                          covering ? _t.value : 1 - _t.value,
                          outside: !covering,
                        ),
                        child: veil,
                      )
                    : veil!,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (moving)
                      ImageFiltered(
                        key: const ValueKey('copy'),
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: _SpoilerPreview._sigma,
                          sigmaY: _SpoilerPreview._sigma,
                          tileMode: TileMode.mirror,
                        ),
                        child: widget.builder(false),
                      ),
                    const ColoredBox(
                      key: ValueKey('shade'),
                      color: Color(0x2E000000),
                    ),
                    SpoilerDust(
                      key: const ValueKey('dust'),
                      seed: widget.seed,
                      brightness: 1.25,
                      active: widget.veiled,
                      fade: kMediaSpoilerReveal,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (moving)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _VeilRimPainter(
                  widget.center,
                  _t,
                  covering: covering,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The disc [_SpoilerPreview] moves: from nothing at [center] to past the
/// box's far corner, eased out so it bursts and slows into the edges. With
/// [outside], everything but the disc.
class _VeilDiscClipper extends CustomClipper<Path> {
  _VeilDiscClipper(this.center, this.t, {this.outside = false});

  final Offset center;
  final double t;
  final bool outside;

  @override
  Path getClip(Size size) {
    final disc = Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: _veilRadius(center, size, t)),
      );
    if (!outside) return disc;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      disc,
    );
  }

  @override
  bool shouldReclip(_VeilDiscClipper old) =>
      old.center != center || old.t != t || old.outside != outside;
}

double _veilRadius(Offset o, Size size, double t) {
  final far = [
    o,
    Offset(size.width - o.dx, o.dy),
    Offset(o.dx, size.height - o.dy),
    Offset(size.width - o.dx, size.height - o.dy),
  ].map((p) => p.distance).reduce(math.max);
  return far * Curves.easeOutCubic.transform(t.clamp(0.0, 1.0)) + 1;
}

/// The soft bright rim riding the disc's edge, fading as it reaches the
/// corners: the chat's reveal wavefront, here in both directions.
class _VeilRimPainter extends CustomPainter {
  _VeilRimPainter(this.center, this.t, {required this.covering})
      : super(repaint: t);

  final Offset center;
  final Animation<double> t;
  final bool covering;

  @override
  void paint(Canvas canvas, Size size) {
    final p = covering ? t.value : 1 - t.value;
    final fade = 1 - Curves.easeIn.transform(p);
    if (fade <= 0) return;
    canvas.drawCircle(
      center,
      _veilRadius(center, size, p),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = Color.fromRGBO(255, 255, 255, 0.32 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  @override
  bool shouldRepaint(_VeilRimPainter old) =>
      old.center != center || old.t != t || old.covering != covering;
}

class _PagePreview extends StatelessWidget {
  const _PagePreview({required this.page});
  final _EditorPage page;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width *
        MediaQuery.devicePixelRatioOf(context);
    return Center(
      child: _asTurned(
        page,
        Image.memory(
          page.source,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          cacheWidth: width.round(),
        ),
      ),
    );
  }
}

/// A rail tile: the photo as the user has turned it.
///
/// Decoded small from the source rather than from the stage's display image —
/// only the photo on screen keeps one — and turned to match, so a rotated
/// photo does not look unrotated on its own tile.
class _PageThumb extends StatelessWidget {
  const _PageThumb({required this.page});
  final _EditorPage page;

  @override
  Widget build(BuildContext context) {
    return _asTurned(
      page,
      Image.memory(
        page.source,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        // A rail of 54pt tiles decoding twelve megapixels apiece is how a send
        // of ten photographs runs the device out of memory before it has
        // uploaded anything.
        cacheWidth:
            (MediaFilmstrip.tileSize * MediaQuery.devicePixelRatioOf(context))
                .round(),
      ),
    );
  }
}

// ------------------------------------------------------------------ painters

/// Clips the stage to the region the image actually occupies, so strokes and
/// cropped-away pixels don't paint into the letterbox margins.
class _StageClip extends CustomClipper<Rect> {
  const _StageClip(this.stage);
  final Rect stage;

  @override
  Rect getClip(Size size) => stage;

  @override
  bool shouldReclip(_StageClip old) => old.stage != stage;
}

/// Paints the finished strokes.
///
/// `repaint: revision` is what actually drives this. The previous painter's
/// `shouldRepaint` was `!identical(old.strokes, strokes) || old.strokes.length
/// != strokes.length` against a single `final List` that never changed
/// identity — so the first clause was always false and the second compared the
/// list's length to its own. It returned false unconditionally, and the strokes
/// were never drawn. Hence a repaint signal that cannot be satisfied by the
/// object it is watching, plus a `shouldRepaint` that compares values.
class _StrokesPainter extends CustomPainter {
  _StrokesPainter({
    required this.strokes,
    required this.viewport,
    required this.stage,
    required this.strokeScale,
    required this.revision,
  }) : _revision = revision.value,
       super(repaint: revision);

  final List<_EditorStroke> strokes;
  final Rect viewport;
  final Rect stage;
  final double strokeScale;
  final ValueNotifier<int> revision;
  final int _revision;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _CameraEditorScreenState._paintStroke(
        canvas,
        stroke,
        viewport: viewport,
        stage: stage,
        strokeWidth: stroke.width * strokeScale,
      );
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) =>
      old._revision != _revision ||
      old.viewport != viewport ||
      old.stage != stage ||
      old.strokeScale != strokeScale;
}

/// Paints only the stroke under the finger, on its own layer.
class _LiveStrokePainter extends CustomPainter {
  _LiveStrokePainter({
    required this.current,
    required this.viewport,
    required this.stage,
    required this.strokeScale,
    required this.revision,
  }) : _revision = revision.value,
       super(repaint: revision);

  /// Read through a closure rather than captured by value: the stroke is
  /// mutated in place as points arrive, and the painter is not rebuilt for each
  /// one — the repaint notifier is what fires.
  final _EditorStroke? Function() current;
  final Rect viewport;
  final Rect stage;
  final double strokeScale;
  final ValueNotifier<int> revision;
  final int _revision;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = current();
    if (stroke == null) return;
    _CameraEditorScreenState._paintStroke(
      canvas,
      stroke,
      viewport: viewport,
      stage: stage,
      strokeWidth: stroke.width * strokeScale,
    );
  }

  @override
  bool shouldRepaint(_LiveStrokePainter old) =>
      old._revision != _revision ||
      old.viewport != viewport ||
      old.stage != stage ||
      old.strokeScale != strokeScale;
}

/// Dims everything outside the crop, and draws the grab affordances.
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.stage, required this.crop});

  final Rect stage;
  final Rect crop;

  @override
  void paint(Canvas canvas, Size size) {
    // Difference path rather than a saveLayer punch-out: the overlay wants a
    // tint over the discarded area, not a hole, and a saveLayer would allocate
    // an offscreen target on a surface that repaints on every drag frame.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(stage),
        Path()..addRect(crop),
      ),
      Paint()..color = const Color(0xFF000000).withValues(alpha: 0.6),
    );

    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawRect(crop, hairline);

    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.35);
    for (var i = 1; i < 3; i++) {
      final dx = crop.left + crop.width * i / 3;
      final dy = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(dx, crop.top), Offset(dx, crop.bottom), thin);
      canvas.drawLine(Offset(crop.left, dy), Offset(crop.right, dy), thin);
    }

    // Corner brackets and edge ticks — the visible half of what `_hitHandle`
    // makes grabbable.
    final heavy = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square
      ..color = Colors.white;
    final arm = math.min(24.0, math.min(crop.width, crop.height) / 3);
    for (final (corner, sx, sy) in [
      (crop.topLeft, 1.0, 1.0),
      (crop.topRight, -1.0, 1.0),
      (crop.bottomLeft, 1.0, -1.0),
      (crop.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner.translate(arm * sx, 0), heavy);
      canvas.drawLine(corner, corner.translate(0, arm * sy), heavy);
    }
    final tick = arm * 0.6;
    canvas.drawLine(
      Offset(crop.center.dx - tick / 2, crop.top),
      Offset(crop.center.dx + tick / 2, crop.top),
      heavy,
    );
    canvas.drawLine(
      Offset(crop.center.dx - tick / 2, crop.bottom),
      Offset(crop.center.dx + tick / 2, crop.bottom),
      heavy,
    );
    canvas.drawLine(
      Offset(crop.left, crop.center.dy - tick / 2),
      Offset(crop.left, crop.center.dy + tick / 2),
      heavy,
    );
    canvas.drawLine(
      Offset(crop.right, crop.center.dy - tick / 2),
      Offset(crop.right, crop.center.dy + tick / 2),
      heavy,
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.stage != stage || old.crop != crop;
}

// ------------------------------------------------------------------- controls

/// Aspect-ratio chip in the crop rail: a media-glass capsule (the theme's
/// filter capsule would be a slab of page colour over the photo), lit with
/// the accent when picked. 13pt, sentence case, untracked — it was 11pt
/// caps with 1pt tracking.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.accentInk,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color accentInk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = sentenceCaseOf(context, label);
    return SpringPress(
      onTap: onTap,
      semanticLabel: text,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.capsule,
      haptic: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        constraints: const BoxConstraints(minHeight: 34),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : MediaGlass.fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: ThemeScope.of(context).body.copyWith(
            color: selected ? accentInk : MediaGlass.ink,
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// One ink colour.
///
/// [FocusableTap], unlike the bare `GestureDetector` this replaces — the
/// swatches and the width control were the only two things on this screen a
/// keyboard or a screen reader could not reach.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      semanticLabel: AppLocalizations.of(
        context,
      ).cameraEditorScreenInkColorSemanticLabel,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.circle,
      haptic: false,
      child: SizedBox(
        width: 38,
        height: 34,
        child: Center(
          // The selected swatch grows and gains a ring, rather than only
          // changing its border weight — at 28pt a 1px border difference is
          // not a signal anyone reads.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            width: selected ? 30 : 24,
            height: selected ? 30 : 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? MediaGlass.ink : MediaGlass.stroke,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Continuous brush-size control.
///
/// Hand-rolled rather than a Material [Slider]: that widget paints a hover and
/// focus overlay and carries a theme this screen deliberately does not use.
/// Reports a 0..1 position; the caller decides what width that means.
class _WidthSlider extends StatelessWidget {
  const _WidthSlider({
    required this.value,
    required this.accent,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final Color accent;
  final bool enabled;
  final ValueChanged<double> onChanged;

  static const _track = 3.0;
  static const _thumb = 18.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // The thumb's centre can only travel between its own two radii, so the
        // position maps into that inner span rather than the full width.
        final span = math.max(1.0, width - _thumb);

        void report(double dx) {
          if (!enabled) return;
          onChanged(((dx - _thumb / 2) / span).clamp(0.0, 1.0));
        }

        final t = value.clamp(0.0, 1.0);
        final centre = _thumb / 2 + span * t;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => report(d.localPosition.dx),
          onHorizontalDragStart: (d) => report(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
          child: SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: MediaGlass.fill,
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  width: centre,
                  child: Container(
                    height: _track,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: enabled ? 1 : 0.4),
                      borderRadius: BorderRadius.circular(_track),
                    ),
                  ),
                ),
                Positioned(
                  left: centre - _thumb / 2,
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: const BoxDecoration(
                      color: MediaGlass.ink,
                      shape: BoxShape.circle,
                      boxShadow: [MediaGlass.shadow],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
