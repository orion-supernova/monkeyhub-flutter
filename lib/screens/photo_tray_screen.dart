import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/generated/app_localizations.dart';
import '../media/image_raster.dart';
import '../media/photo_picking.dart';
import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/media_filmstrip.dart';
import '../widgets/photo_backdrop.dart';
import '../widgets/photo_chrome.dart';
import 'camera_editor_screen.dart';

/// The most photographs one send may carry.
///
/// Not a technical limit — it is a courtesy one. Every recipient of a room
/// downloads every picture, and the difference between "they sent a few
/// photos" and "my chat is now a photo album I did not ask for" is somewhere
/// around here. It is also handed to the OS picker as its own limit, so the
/// refusal happens while the user is still choosing rather than after.
const int kMaxPhotoSelection = 10;

/// The blurred copy behind the stage, as opposed to the photograph itself or
/// the rail's thumbnails.
///
/// Keyed for the same reason [cameraEditorStageImageKey] is: a test reaching
/// for "the images on this screen" and counting them became ambiguous the
/// moment the backdrop landed, and an ambiguous count that fails loudly is the
/// good outcome — but it still needs an answer.
@visibleForTesting
const Key photoTrayBackdropImageKey = Key('photo-tray-backdrop-image');

/// What the tray hands back when the user commits.
class PhotoTraySend {
  const PhotoTraySend({
    required this.images,
    required this.viewOnce,
    required this.dropped,
  });

  /// Ready to upload, in the order the rail showed them.
  final List<CroppedImage> images;

  /// Armed with the circled "1", and it applies to all of them. A per-photo
  /// choice would be a second thing to explain on a screen whose whole job is
  /// to make sending several pictures feel like sending one.
  final bool viewOnce;

  /// How many of the chosen photographs could not be decoded at all. Reported
  /// rather than swallowed: a send of five that quietly becomes a send of four
  /// is worse than a send of four that says so.
  final int dropped;
}

/// Review and send several photographs at once.
///
/// The gallery used to hand back exactly one picture, because `pickImage` only
/// ever returns one — so sending four photos meant four trips through the
/// attachment sheet, the OS picker and the editor. This is the screen that
/// stands where the editor stands for a single photo: a full-bleed preview of
/// the one you are looking at, the whole selection on a rail underneath, and
/// one SEND.
///
/// A lone photograph never comes here. It goes straight to
/// [CameraEditorScreen], as it always has — a rail with one tile on it and a
/// count that says "1" is furniture built to answer a question nobody asked,
/// and the editor is a better screen for the case where all the attention is
/// on one picture anyway.
///
/// **Editing is delegated, not reimplemented.** The pen, the cropper, the
/// rotation and the export live in [CameraEditorScreen] and are reached from
/// the rail's edit button, which opens it on the current photo and takes its
/// export back. The alternative — a second, smaller editor for the multi case —
/// is how an app ends up with two croppers that disagree about what a rotation
/// does.
class PhotoTrayScreen extends StatefulWidget {
  const PhotoTrayScreen({super.key, required this.photos});

  /// Encoded bytes, one per chosen photograph, already read off the picker.
  /// Bytes rather than `XFile`s because on web there is no file behind one, and
  /// because the preview needs them decoded on the spot regardless.
  final List<Uint8List> photos;

  static Future<PhotoTraySend?> open(
    BuildContext context, {
    required List<Uint8List> photos,
  }) {
    return Navigator.of(context).push<PhotoTraySend>(
      MaterialPageRoute(builder: (_) => PhotoTrayScreen(photos: photos)),
    );
  }

  @override
  State<PhotoTrayScreen> createState() => _PhotoTrayScreenState();
}

/// One photograph on its way out.
class _TrayItem {
  _TrayItem.picked(this.bytes) : exported = null;

  /// Straight out of [CameraEditorScreen]: cropped, drawn on, already encoded
  /// at the size and quality it will be sent at.
  _TrayItem.edited(CroppedImage image)
      : bytes = image.bytes,
        exported = image;

  /// What the preview and the rail paint.
  final Uint8List bytes;

  /// Non-null once the editor has produced final bytes for this one, which the
  /// send then uses verbatim rather than putting a finished export back through
  /// the size policy a second time.
  ///
  /// It also freezes that photo's HD decision at the moment it was edited: the
  /// editor's own HD switch and this screen's are the same sticky preference,
  /// so they agree unless the switch is flipped *after* an edit — in which case
  /// the edited picture keeps the choice that was in force when it was
  /// exported, which is the one the user was actually looking at.
  final CroppedImage? exported;
}

class _PhotoTrayScreenState extends State<PhotoTrayScreen> {
  late final List<_TrayItem> _items = [
    for (final b in widget.photos) _TrayItem.picked(b),
  ];
  late final PageController _pager = PageController();
  int _index = 0;

  bool _viewOnce = false;

  /// Seeded from the sticky preference and written back on toggle, exactly as
  /// the editor does — the choice is about how this user sends photographs, not
  /// about which screen they happened to send them from.
  bool _hd = SettingsStore.instance.photoHd;

  /// Covers the export, and the read-back of an "add more" pick. Both are
  /// whole-image work behind an OS sheet that has already slid away.
  bool _busy = false;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _setBusy(bool busy) {
    if (!mounted || _busy == busy) return;
    setState(() => _busy = busy);
  }

  void _jumpTo(int i) {
    if (i == _index) return;
    // Jumped rather than animated, for the same reason the fullscreen gallery
    // jumps: the rail can be a long way from the page, and riding eight
    // photographs past someone to answer a tap on the ninth is a wait.
    _pager.jumpToPage(i);
  }

  void _remove(int i) {
    setState(() {
      _items.removeAt(i);
      if (_items.isEmpty) return;
      // Stay on the same picture where there still is one, and step back off
      // the end where there is not.
      final next = i < _index ? _index - 1 : _index.clamp(0, _items.length - 1);
      _index = next;
    });
    if (_items.isEmpty) {
      // Nothing left to send. Popping is the honest outcome — an empty tray
      // with a dead SEND button is a screen with nothing on it.
      Navigator.of(context).pop();
      return;
    }
    // After the frame that rebuilt the shorter `PageView`, or the controller is
    // asked to jump to a page that has not been laid out yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pager.hasClients) _pager.jumpToPage(_index);
    });
  }

  /// Opens the editor on the current photograph and takes its export back.
  Future<void> _edit() async {
    final i = _index;
    if (i < 0 || i >= _items.length) return;
    final outcome = await CameraEditorScreen.open(
      context,
      source: _items[i].bytes,
      // The tray owns this decision for the whole send; offering it again per
      // photo would be two switches that mean different things wearing the same
      // circled "1".
      allowViewOnce: false,
      confirmLabel: AppLocalizations.of(context).cameraEditorScreenCropDoneButton,
    );
    if (!mounted || outcome is! EditorSend) return;
    // Index re-read rather than reused: the editor is a route, and nothing
    // stops the rail having been rearranged under it on a slow device.
    if (i >= _items.length) return;
    setState(() => _items[i] = _TrayItem.edited(outcome.image));
  }

  /// A second trip through the OS picker, appending to what is already here.
  Future<void> _addMore() async {
    final remaining = kMaxPhotoSelection - _items.length;
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    if (remaining <= 0) {
      toast.show(l10n.photoTrayLimitSnack(kMaxPhotoSelection));
      return;
    }
    _setBusy(true);
    try {
      final pick = await pickPhotos(limit: remaining);
      if (!mounted) return;
      // The whole second trip lost to one asset the platform would not produce
      // — see [MediaPick]. The rail keeps what it already had, so this is an
      // add that did not happen rather than a selection thrown away.
      if (pick.unreadable) {
        toast.show(
          l10n.mediaPickFailedMessage,
          tone: ToastTone.danger,
        );
        return;
      }
      if (pick.files.isEmpty) return;
      final read = await readPickedPhotos(pick.files);
      if (!mounted || read.bytes.isEmpty) return;
      setState(() {
        _items.addAll(read.bytes.map(_TrayItem.picked));
      });
      if (read.dropped > 0) {
        toast.show(
          l10n.photoTrayLoadFailedSnack,
          tone: ToastTone.danger,
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  /// Flips HD and writes the choice back to the sticky preference.
  ///
  /// Not awaited: the write is a secure-storage round trip and the toggle must
  /// feel instant. Local state is the source of truth for the send that
  /// follows, so a slow or failed write costs the stickiness, never the photos.
  void _toggleHd() {
    setState(() => _hd = !_hd);
    unawaited(SettingsStore.instance.setPhotoHd(_hd));
  }

  Future<void> _send() async {
    if (_busy || _items.isEmpty) return;
    _setBusy(true);
    final out = <CroppedImage>[];
    var dropped = 0;
    // Sequential, not `Future.wait`. Each unedited photo over the cap costs a
    // full-resolution decode and a JPEG encode; ten of those started at once
    // is ten simultaneous copies of a 12 megapixel bitmap, which is how a
    // mid-range handset runs out of memory holding pictures nobody has sent
    // yet. In order, too — the rail's order is the order they arrive in the
    // conversation.
    for (final item in _items) {
      final ready =
          item.exported ?? await prepareUneditedForSend(item.bytes, hd: _hd);
      if (ready == null) {
        dropped++;
      } else {
        out.add(ready);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      PhotoTraySend(images: out, viewOnce: _viewOnce, dropped: dropped),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: BackdropGroup(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The one fullscreen photo surface in the app that was still
            // missing a backdrop, and the one where it shows worst. The stage
            // below is a band roughly 200pt shorter than the screen, so a
            // `contain` fit on a TALL picture — a screenshot, which is the
            // exact shape of the phone it is being sent from — is scaled down
            // to that band's height and leaves a black gutter down both sides.
            // The picture was right; the frame around it was wrong. Same fix
            // as the editor and every viewer: the photograph's own colour,
            // blurred past recognition, continues past the frame.
            //
            // Crossfaded rather than swapped, because paging is a deliberate
            // move between two pictures and a hard cut in the background reads
            // as a flash. Keyed on the bytes so an edit re-runs it too.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              // Taking the last photo back empties the tray, and the pop that
              // follows is a frame late — there is one build with nothing to
              // draw. Everything else on this screen already survives it by
              // being driven off `_items.length`; this one has to say so.
              child: _items.isEmpty
                  ? const SizedBox.shrink()
                  : PhotoBackdrop(
                      key: ValueKey(_items[_index].bytes),
                      image: Image.memory(
                        _items[_index].bytes,
                        key: photoTrayBackdropImageKey,
                        fit: BoxFit.cover,
                        // It is about to be blurred by 34 logical pixels; a
                        // full decode of a 12-megapixel original here would be
                        // megabytes spent on detail that never reaches the
                        // screen.
                        cacheWidth: kPhotoBackdropDecodeWidth,
                        gaplessPlayback: true,
                      ),
                    ),
            ),
            // The stage is pulled clear of the rails rather than sitting
            // full-bleed under them: a photograph whose bottom third is behind
            // a strip of its own thumbnails is one you cannot actually check
            // before sending, which is the only reason this screen exists.
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                safe.top + 56,
                0,
                safe.bottom + MediaFilmstrip.height + 74,
              ),
              child: PageView.builder(
                controller: _pager,
                itemCount: _items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Image.memory(
                      _items[i].bytes,
                      fit: BoxFit.contain,
                      // Keyed to the bytes so an edit swaps the picture rather
                      // than repainting the old decode: `Image.memory` compares
                      // providers by list identity, and a `setState` that hands
                      // it a different list at the same index is otherwise
                      // indistinguishable from a rebuild.
                      key: ValueKey(_items[i].bytes),
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: safe.top + 6,
              child: _TopRail(
                count: _items.length,
                onDiscard: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomRail(
                theme: theme,
                items: _items,
                index: _index,
                viewOnce: _viewOnce,
                hd: _hd,
                busy: _busy,
                onTapThumb: _jumpTo,
                onRemove: _busy ? null : _remove,
                onAddMore: _busy || _items.length >= kMaxPhotoSelection
                    ? null
                    : _addMore,
                onEdit: _busy ? null : _edit,
                onToggleViewOnce: _busy
                    ? null
                    : () => setState(() => _viewOnce = !_viewOnce),
                onToggleHd: _busy ? null : _toggleHd,
                onSend: _busy ? null : _send,
              ),
            ),
            if (_busy)
              // Opaque on purpose: the export is the one moment on this screen
              // where a stray tap on SEND or on a thumbnail would either start
              // a second export or reorder the one already running.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Semantics(
                        label: l10n.cameraEditorScreenSendingButton,
                        child: const PhotoSpinner(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopRail extends StatelessWidget {
  const _TopRail({required this.count, required this.onDiscard});

  final int count;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        PhotoGlassButton(
          icon: CupertinoIcons.xmark,
          semanticLabel: l10n.photoTrayDiscardSemanticLabel,
          size: 38,
          iconSize: 17,
          onTap: onDiscard,
        ),
        const Spacer(),
        PhotoGlassSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              l10n.photoTrayCountLabel(count),
              style: const TextStyle(
                color: PhotoChrome.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                // Explicit, not inherited: this chrome floats over a photo and
                // must never fall back to Flutter's debug text style, which
                // paints yellow underlines.
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const Spacer(),
        // Balances the X so the count sits on the screen's centre line rather
        // than 19pt to the right of it.
        const SizedBox(width: 38),
      ],
    );
  }
}

class _BottomRail extends StatelessWidget {
  const _BottomRail({
    required this.theme,
    required this.items,
    required this.index,
    required this.viewOnce,
    required this.hd,
    required this.busy,
    required this.onTapThumb,
    required this.onRemove,
    required this.onAddMore,
    required this.onEdit,
    required this.onToggleViewOnce,
    required this.onToggleHd,
    required this.onSend,
  });

  final AppTheme theme;
  final List<_TrayItem> items;
  final int index;
  final bool viewOnce;
  final bool hd;
  final bool busy;
  final void Function(int i) onTapThumb;
  final void Function(int i)? onRemove;
  final VoidCallback? onAddMore;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleViewOnce;
  final VoidCallback? onToggleHd;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MediaFilmstrip(
          count: items.length,
          index: index,
          onTap: onTapThumb,
          onRemove: onRemove,
          removeSemanticLabel: l10n.photoTrayRemoveSemanticLabel,
          tileSemanticLabel: (i, total) =>
              l10n.photoChromeThumbnailSemanticLabel(i, total),
          thumbnailBuilder: (_, i) => Image.memory(
            items[i].bytes,
            fit: BoxFit.cover,
            key: ValueKey(items[i].bytes),
            gaplessPlayback: true,
            // A rail of 54pt tiles decoding twelve megapixels apiece is how a
            // send of ten photographs runs the device out of memory before it
            // has uploaded anything. The tile is square, so one axis is enough.
            cacheWidth: (MediaFilmstrip.tileSize *
                    MediaQuery.devicePixelRatioOf(context))
                .round(),
          ),
          trailing: onAddMore == null
              ? null
              : _AddMoreTile(onTap: onAddMore!, theme: theme),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 10),
          child: Row(
            children: [
              PhotoGlassButton(
                icon: CupertinoIcons.crop_rotate,
                semanticLabel: l10n.photoTrayEditSemanticLabel,
                size: 38,
                iconSize: 17,
                onTap: onEdit,
              ),
              const SizedBox(width: 8),
              PhotoViewOnceToggle(
                active: viewOnce,
                accent: theme.accent,
                accentInk: theme.accentInk,
                onTap: onToggleViewOnce,
              ),
              const SizedBox(width: 8),
              PhotoHdToggle(
                active: hd,
                accent: theme.accent,
                accentInk: theme.accentInk,
                onTap: onToggleHd,
              ),
              const Spacer(),
              PhotoGlassPill(
                label: busy
                    ? l10n.cameraEditorScreenSendingButton
                    : l10n.cameraEditorScreenSendButton,
                icon: busy ? null : CupertinoIcons.arrow_up,
                tint: theme.accent,
                onTap: onSend,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The rail's trailing "+", for going back to the picker without losing what is
/// already staged.
class _AddMoreTile extends StatelessWidget {
  const _AddMoreTile({required this.onTap, required this.theme});

  final VoidCallback onTap;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    // `FocusableTap` is inside `PhotoGlassButton`; this is a plain square
    // rather than one of those because it has to match the tiles beside it,
    // which are square. Never an InkWell — this app draws no ink anywhere.
    return PhotoGlassSurface(
      radius: 9,
      shadow: false,
      child: PhotoGlassButton(
        icon: CupertinoIcons.plus,
        semanticLabel: AppLocalizations.of(context).photoTrayAddMoreSemanticLabel,
        size: MediaFilmstrip.tileSize,
        iconSize: 20,
        // Transparent: the glass surface behind it is already the fill, and a
        // second one over it would read as a raised button on a flat rail.
        tint: const Color(0x00000000),
        iconColor: theme.accent,
        onTap: onTap,
      ),
    );
  }
}

/// Bytes read back off a set of picked files, and how many could not be.
class PickedPhotos {
  const PickedPhotos({required this.bytes, required this.dropped});
  final List<Uint8List> bytes;
  final int dropped;
}

/// Reads every picked file into memory, keeping the picker's order.
///
/// One failure does not lose the batch. A picture the platform declines to
/// hand over — an iCloud asset that never came down, a content provider that
/// died between the pick and the read — is counted and skipped, because the
/// other nine are still perfectly sendable and refusing all of them would
/// punish the user for the one.
///
/// Sequential rather than `Future.wait`: these are whole-file reads across a
/// platform channel, and ten of them in flight at once is ten full-size images
/// resident simultaneously before a single one has been shown.
Future<PickedPhotos> readPickedPhotos(List<XFile> picked) async {
  final out = <Uint8List>[];
  var dropped = 0;
  for (final file in picked) {
    try {
      out.add(await file.readAsBytes());
    } catch (e) {
      debugPrint('[photo_tray] could not read a picked photo: $e');
      dropped++;
    }
  }
  return PickedPhotos(bytes: out, dropped: dropped);
}
