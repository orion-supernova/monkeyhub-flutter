import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../media/image_raster.dart' show CroppedImage;
import '../media/photo_picking.dart' show kMaxPhotoSelection;
import '../theme/theme_scope.dart';
import 'photo_chrome.dart' show MediaDurationBadge;
import 'spring_press.dart';

/// One photo or video picked in the inline picker, in pick order. [edited]
/// is set once it has been through the editor, and is what gets sent.
class PickedMedia {
  PickedMedia(this.asset);

  final AssetEntity asset;
  CroppedImage? edited;

  bool get isVideo => asset.type == AssetType.video;
}

/// The inline picker's state: whether its panel is up, and what has been
/// picked, in order. Shared by the panel (the grid that picks) and the strip
/// over the composer (the picks, to edit, remove and send).
class InlinePickerController extends ChangeNotifier {
  InlinePickerController({this.max = kMaxPhotoSelection});

  /// The most one send may carry: the album cap.
  final int max;

  final List<PickedMedia> _picks = [];
  bool _open = false;

  bool get isOpen => _open;
  bool get hasPicks => _picks.isNotEmpty;
  List<PickedMedia> get picks => List.unmodifiable(_picks);

  /// 1-based place of [asset] in the picks, 0 when it is not picked.
  int orderOf(AssetEntity asset) =>
      _picks.indexWhere((p) => p.asset.id == asset.id) + 1;

  /// Picks or unpicks [asset]. False when it would go past [max].
  bool toggle(AssetEntity asset) {
    final i = _picks.indexWhere((p) => p.asset.id == asset.id);
    if (i >= 0) {
      _picks.removeAt(i);
    } else {
      if (_picks.length >= max) return false;
      _picks.add(PickedMedia(asset));
    }
    notifyListeners();
    return true;
  }

  void remove(PickedMedia m) {
    if (_picks.remove(m)) notifyListeners();
  }

  void markEdited(PickedMedia m, CroppedImage image) {
    m.edited = image;
    notifyListeners();
  }

  /// Hands the picks over (to be sent) and empties the strip.
  List<PickedMedia> take() {
    final out = List<PickedMedia>.of(_picks);
    _picks.clear();
    notifyListeners();
    return out;
  }

  void open() {
    if (_open) return;
    _open = true;
    notifyListeners();
  }

  void close() {
    if (!_open) return;
    _open = false;
    notifyListeners();
  }
}

/// The photo library as a grid in the keyboard's place: tap to pick, tap
/// again to unpick, each pick numbered in the order it will be sent. The
/// iMessage picker. What is picked waits in the strip over the composer
/// ([PickedMediaStrip]) until it is sent.
///
/// Phones only ([supported]): the library is `photo_manager`'s, which has no
/// desktop or web implementation; those keep the system picker.
class InlinePhotoPicker extends StatefulWidget {
  const InlinePhotoPicker({
    super.key,
    required this.controller,
    required this.height,
    this.onFull,
  });

  final InlinePickerController controller;
  final double height;

  /// A pick refused because [InlinePickerController.max] is reached.
  final VoidCallback? onFull;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  State<InlinePhotoPicker> createState() => _InlinePhotoPickerState();
}

enum _Access { unknown, prompt, granted, limited, denied }

class _InlinePhotoPickerState extends State<InlinePhotoPicker>
    with WidgetsBindingObserver {
  static const _page = 90;
  static const _option = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  _Access _access = _Access.unknown;
  final List<AssetEntity> _assets = [];
  bool _loading = false;
  bool _exhausted = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onPicks);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onPicks);
    super.dispose();
  }

  void _onPicks() {
    if (mounted) setState(() {});
  }

  /// Back from Settings (or the limited-library sheet): the answer may have
  /// changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  _Access _accessOf(PermissionState s) => switch (s) {
        PermissionState.authorized => _Access.granted,
        PermissionState.limited => _Access.limited,
        PermissionState.notDetermined => _Access.prompt,
        _ => _Access.denied,
      };

  Future<void> _refresh() async {
    _Access access;
    try {
      access = _accessOf(
          await PhotoManager.getPermissionState(requestOption: _option));
    } catch (e) {
      debugPrint('[inline_picker] permission state: $e');
      access = _Access.denied;
    }
    if (!mounted) return;
    setState(() => _access = access);
    // Opening the picker IS asking for the library, unlike the camera's
    // tray: ask at once rather than making the person tap "Allow" first.
    if (access == _Access.prompt) {
      await _request();
    } else if (access == _Access.granted || access == _Access.limited) {
      await _load(reset: true);
    }
  }

  Future<void> _request() async {
    try {
      final state =
          await PhotoManager.requestPermissionExtend(requestOption: _option);
      if (!mounted) return;
      setState(() => _access = _accessOf(state));
      if (state.hasAccess) await _load(reset: true);
    } catch (e) {
      debugPrint('[inline_picker] request: $e');
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _generation++;
      _assets.clear();
      _exhausted = false;
      _loading = false;
    }
    if (_loading || _exhausted) return;
    _loading = true;
    final generation = _generation;
    try {
      final page = await PhotoManager.getAssetListRange(
        start: _assets.length,
        end: _assets.length + _page,
        type: RequestType.common,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false),
          ],
        ),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _assets.addAll(page);
        _exhausted = page.length < _page;
      });
    } catch (e) {
      debugPrint('[inline_picker] load: $e');
    } finally {
      if (generation == _generation) _loading = false;
    }
  }

  void _tap(AssetEntity asset) {
    if (widget.controller.toggle(asset)) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.heavyImpact();
      widget.onFull?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    Widget body;
    switch (_access) {
      case _Access.unknown:
        body = const SizedBox.expand();
      case _Access.prompt:
        body = _Gate(
          text: l10n.galleryTrayAllowPrompt,
          button: l10n.galleryTrayAllowButton,
          onTap: _request,
        );
      case _Access.denied:
        body = _Gate(
          text: l10n.galleryTrayDeniedPrompt,
          button: l10n.galleryTraySettingsButton,
          onTap: () => PhotoManager.openSetting(),
        );
      case _Access.granted:
      case _Access.limited:
        body = _assets.isEmpty && _exhausted
            ? Center(
                child: Text(l10n.galleryTrayEmpty, style: theme.bodySoft),
              )
            : NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.extentAfter < 600) _load();
                  return false;
                },
                child: GridView.builder(
                  padding: const EdgeInsets.only(top: 2, bottom: 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _assets.length,
                  itemBuilder: (_, i) {
                    final asset = _assets[i];
                    return _Tile(
                      asset: asset,
                      order: widget.controller.orderOf(asset),
                      onTap: () => _tap(asset),
                    );
                  },
                ),
              );
        if (_access == _Access.limited) {
          body = Column(
            children: [
              _LimitedNote(
                text: l10n.galleryTrayLimitedNote,
                button: l10n.galleryTrayManageButton,
                onTap: () async {
                  try {
                    await PhotoManager.presentLimited(type: RequestType.common);
                  } catch (_) {}
                  if (mounted) await _load(reset: true);
                },
              ),
              Expanded(child: body),
            ],
          );
        }
    }
    return SizedBox(
      height: widget.height,
      child: ColoredBox(color: theme.background, child: body),
    );
  }
}

/// One square of the grid: the thumbnail, a video's length, and the pick
/// ring (empty, or the accent disc with the pick's number). A picked tile
/// eases in a little, the way iMessage marks one.
class _Tile extends StatelessWidget {
  const _Tile({required this.asset, required this.order, required this.onTap});

  final AssetEntity asset;
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = order > 0;
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: 0.96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedScale(
            scale: picked ? 0.9 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(picked ? 8 : 0),
              child: Image(
                // Shared with the camera's tray, so the two reuse one decode.
                image: AssetEntityImageProvider(
                  asset,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize.square(240),
                ),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          ),
          if (asset.type == AssetType.video)
            Positioned(
              left: 6,
              bottom: 6,
              child: MediaDurationBadge(
                duration: Duration(seconds: asset.duration),
                icon: CupertinoIcons.video_camera_solid,
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: _OrderRing(order: order),
          ),
        ],
      ),
    );
  }
}

class _OrderRing extends StatelessWidget {
  const _OrderRing({required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    final t = ThemeScope.of(context);
    final on = order > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? t.accent : const Color(0x33000000),
        border: Border.all(
          color: on ? t.accent : Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3)],
      ),
      child: on
          ? Text(
              '$order',
              style: t.body.copyWith(
                color: t.accentInk,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate({required this.text, required this.button, required this.onTap});

  final String text;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.photo_on_rectangle,
                size: 34, color: theme.inkSoft),
            const SizedBox(height: 12),
            Text(text, style: theme.bodySoft, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            SpringPress(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(button,
                    style: theme.bodyEmph.copyWith(color: theme.accentInk)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitedNote extends StatelessWidget {
  const _LimitedNote(
      {required this.text, required this.button, required this.onTap});

  final String text;
  final String button;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: theme.caption.copyWith(color: theme.inkSoft),
                maxLines: 2),
          ),
          SpringPress(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(button,
                  style: theme.caption.copyWith(
                      color: theme.accent, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The picks, waiting over the composer: large thumbnails in send order,
/// each with a remove button. Tapping a photo opens it in the editor.
class PickedMediaStrip extends StatelessWidget {
  const PickedMediaStrip({
    super.key,
    required this.controller,
    required this.onEdit,
  });

  final InlinePickerController controller;
  final void Function(PickedMedia m) onEdit;

  static const double _h = 112;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final picks = controller.picks;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: picks.isEmpty
              ? const SizedBox(width: double.infinity)
              : SizedBox(
                  height: _h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    itemCount: picks.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _StripTile(
                      key: ValueKey(picks[i].asset.id),
                      pick: picks[i],
                      onTap: () => onEdit(picks[i]),
                      onRemove: () {
                        HapticFeedback.selectionClick();
                        controller.remove(picks[i]);
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _StripTile extends StatelessWidget {
  const _StripTile({
    super.key,
    required this.pick,
    required this.onTap,
    required this.onRemove,
  });

  final PickedMedia pick;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final edited = pick.edited;
    final ImageProvider image = edited != null
        ? MemoryImage(edited.bytes)
        : AssetEntityImageProvider(
            pick.asset,
            isOriginal: false,
            thumbnailSize: const ThumbnailSize.square(240),
          );
    return SizedBox(
      width: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: SpringPress(
              onTap: onTap,
              scale: 0.95,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(image: image, fit: BoxFit.cover),
              ),
            ),
          ),
          if (pick.isVideo)
            const Center(
              child: IgnorePointer(
                child: Icon(CupertinoIcons.play_circle_fill,
                    size: 30, color: Colors.white),
              ),
            ),
          Positioned(
            top: -6,
            right: -6,
            child: SpringPress(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.7),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(CupertinoIcons.xmark,
                    size: 11, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
