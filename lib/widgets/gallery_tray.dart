import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../media/image_raster.dart' show sniffImageContentType;
import '../theme/theme_scope.dart';
import 'app_toast.dart';
import 'glass_buttons.dart';
import 'liquid_glass.dart';
import 'photo_chrome.dart';
import 'spring_press.dart';

/// Where the tray rests.
///
///  * [hidden] — only the grabber, sitting above the shutter controls.
///  * [strip] — a row of the newest photos, newest on the left.
///  * [full] — the whole screen: a grid of the library, to pick one from.
enum GalleryTrayStop { hidden, strip, full }

/// How far into the photo library the app may look.
enum GalleryAccess { unknown, prompt, granted, limited, denied }

/// Lets the camera drive its tray: the library button opens it full, and the
/// newest photo is published for that button to wear as its face.
class GalleryTrayController {
  _GalleryTrayState? _state;

  /// The newest photo, once the library has been read. Null until then, and
  /// whenever there is no access — the button falls back to its glyph.
  final ValueNotifier<AssetEntity?> latest = ValueNotifier(null);

  void expand() => _state?._settleTo(GalleryTrayStop.full);
  void collapse() => _state?._settleTo(GalleryTrayStop.strip);

  /// Whether photos are being multi-selected. The system back clears the
  /// selection before it does anything else.
  bool get selecting => _state?._selecting ?? false;

  /// Drops the multi-selection, without adding anything.
  void clearSelection() => _state?._clearSelection();

  void dispose() => latest.dispose();
}

/// The recent-photos drawer under the in-app camera.
///
/// A strip of the newest photos sits above the shutter, the way every
/// messenger's camera does it: the picture you just took with the system
/// camera, or the screenshot you meant to send, is one tap away instead of
/// behind the library button, the OS picker and its multi-select. Drag the
/// grabber down and it gets out of the viewfinder; drag it up and it becomes a
/// full-screen grid of the library.
///
/// A tap hands one photo to the camera's review — the composer — at once. A
/// long press starts a multi-selection instead, where taps toggle and "Add"
/// hands them over together; only offered when [GalleryTray.onPickMany] is
/// set, since an avatar or a moment takes exactly one.
///
/// The whole sheet is one full-height layer translated by the drag, so a drag
/// moves pixels and never relays out the grid. Below the strip it is empty and
/// lets touches through to the shutter.
class GalleryTray extends StatefulWidget {
  const GalleryTray({
    super.key,
    required this.controller,
    required this.anchor,
    required this.onPick,
    this.onBrowseAll,
    this.onFullChanged,
    this.onPickMany,
    this.selectionRoom,
    this.selectionMax,
    this.onSettle,
    this.onSelectingChanged,
    this.videos = false,
  });

  /// Lists the library's videos instead of its photos: the camera's VIDEO
  /// mode, where the strip offers clips the way PHOTO mode offers pictures.
  /// Switching it reloads the strip in place.
  final bool videos;

  /// Whether this platform has a library to read. iOS and Android only:
  /// `photo_manager`'s macOS build needs entitlements this app does not
  /// carry, and the browser has no photo library at all.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  final GalleryTrayController controller;

  /// Distance from the bottom of the screen, safe area included, to the
  /// bottom of the strip — clear of the shutter and the mode switch.
  final double anchor;

  /// One tap on one photo. Awaited, so the tile can spin while its bytes come
  /// off the library (an iCloud original can take a moment).
  final Future<void> Function(AssetEntity asset) onPick;

  /// The OS picker, for albums and multi-select. Null hides the button.
  final VoidCallback? onBrowseAll;

  /// Fires when the sheet settles full, or starts to leave it. The camera
  /// pauses its preview behind a grid that covers it.
  final ValueChanged<bool>? onFullChanged;

  /// "Add" at the end of a multi-selection, in the order the photos were
  /// picked. Null keeps the tray single-pick: a long press does nothing.
  final Future<void> Function(List<AssetEntity> assets)? onPickMany;

  /// How many more photos the caller can take right now. A selection stops
  /// growing there rather than failing at "Add".
  final int Function()? selectionRoom;

  /// The caller's overall cap, for the message when [selectionRoom] runs out.
  final int? selectionMax;

  /// Fires the moment a settle is decided — a drag let go, a button, the
  /// controller — with where the sheet is going. The camera uses a sheet
  /// leaving full to hand back to the composer that opened it.
  final ValueChanged<GalleryTrayStop>? onSettle;

  /// Fires when a multi-selection starts or ends.
  final ValueChanged<bool>? onSelectingChanged;

  /// Loads [asset] as bytes the composer can take: a JPEG on iOS (the plugin's
  /// full-size rendition, orientation applied), the original elsewhere — and a
  /// large JPEG re-render for a HEIC original, which a recipient on another
  /// platform could not open. Null when the library will not produce it.
  static Future<Uint8List?> loadBytes(AssetEntity asset) async {
    try {
      final file = await asset.file;
      Uint8List? bytes = await file?.readAsBytes();
      if (bytes == null || sniffImageContentType(bytes) == 'image/heic') {
        final long = math.max(asset.width, asset.height);
        final scale = long > 4096 ? 4096 / long : 1.0;
        bytes = await asset.thumbnailDataWithSize(
          ThumbnailSize(
            math.max(1, (asset.width * scale).round()),
            math.max(1, (asset.height * scale).round()),
          ),
          format: ThumbnailFormat.jpeg,
          quality: 92,
        );
      }
      return bytes;
    } catch (e) {
      debugPrint('[gallery_tray] could not load ${asset.id}: $e');
      return null;
    }
  }

  @override
  State<GalleryTray> createState() => _GalleryTrayState();
}

/// Survives the camera closing, for the length of the app session: someone
/// who pushed the strip away does not want it back on the next shot. Null
/// until they have moved it themselves.
GalleryTrayStop? _rememberedStop;

class _GalleryTrayState extends State<GalleryTray>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _handle = 26.0;
  static const _thumb = 64.0;
  static const _strip = _thumb + 10;
  static const _header = 52.0;
  static const _note = 34.0;
  static const _page = 90;

  /// Shared by the strip and the grid so a photo decoded for one is already
  /// in the image cache for the other.
  static const _thumbSize = ThumbnailSize.square(240);

  /// The sheet's top edge, in the tray's own coordinates.
  late final AnimationController _y = AnimationController.unbounded(
    vsync: this,
  );

  final ScrollController _grid = ScrollController();

  GalleryTrayStop _stop = _rememberedStop ?? GalleryTrayStop.strip;

  /// Where the sheet rested when the current drag began. A drag is judged
  /// against it: leaving a stop takes a quarter of the way to the next one,
  /// not half, so one deliberate swipe is always enough.
  GalleryTrayStop _dragFrom = GalleryTrayStop.strip;
  bool _dragging = false;
  bool _full = false;
  _Geometry? _geo;

  GalleryAccess _access = GalleryAccess.unknown;
  final List<AssetEntity> _assets = [];
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _picking;

  /// The multi-selection, in the order it was picked. Empty is "not
  /// selecting": the mode ends with its last photo.
  final List<AssetEntity> _selection = [];

  /// The last non-zero count, so the bar fading out does not read "Add (0)".
  int _shownCount = 1;
  bool _adding = false;

  static final _filter = FilterOptionGroup(
    orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
  );

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(GalleryTray old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._state = this;
    }
    if (old.videos != widget.videos) {
      _clearSelection();
      if (_access == GalleryAccess.granted ||
          _access == GalleryAccess.limited) {
        unawaited(_load(reset: true));
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    WidgetsBinding.instance.removeObserver(this);
    _y.dispose();
    _grid.dispose();
    super.dispose();
  }

  /// Back from Settings, or from the limited-library picker: the answer to
  /// "what may we see" may have changed while the app was away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  // ------------------------------------------------------------------ library

  static const _option = PermissionRequestOption(
    // Both kinds, asked once: the strip lists videos in the camera's VIDEO
    // mode, and a second prompt on the mode switch would be a question about
    // the same library.
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  GalleryAccess _accessOf(PermissionState s) => switch (s) {
    PermissionState.authorized => GalleryAccess.granted,
    PermissionState.limited => GalleryAccess.limited,
    PermissionState.notDetermined => GalleryAccess.prompt,
    _ => GalleryAccess.denied,
  };

  /// Reads the permission without asking for it, and the first page of photos
  /// if there is one to read. Asking is the user's tap on "Allow" — a prompt
  /// for the photo library on the way into the CAMERA is a question about
  /// something they did not come here to do.
  Future<void> _refresh() async {
    GalleryAccess access;
    try {
      access = _accessOf(
        await PhotoManager.getPermissionState(requestOption: _option),
      );
    } catch (e) {
      // No plugin (a test, an unsupported build): behave as a library that
      // has nothing in it rather than one that is broken.
      debugPrint('[gallery_tray] permission state: $e');
      access = GalleryAccess.denied;
    }
    if (!mounted) return;
    setState(() => _access = access);
    // Someone who said no does not need a card about it over every shot.
    // The grabber stays, and pulling it up still explains the way back.
    if (access == GalleryAccess.denied &&
        _rememberedStop == null &&
        _stop == GalleryTrayStop.strip) {
      _settleTo(GalleryTrayStop.hidden, remember: false);
    }
    if (access == GalleryAccess.granted || access == GalleryAccess.limited) {
      await _load(reset: true);
    } else {
      _assets.clear();
      widget.controller.latest.value = null;
    }
  }

  Future<void> _requestAccess() async {
    HapticFeedback.selectionClick();
    try {
      final state = await PhotoManager.requestPermissionExtend(
        requestOption: _option,
      );
      if (!mounted) return;
      setState(() => _access = _accessOf(state));
      if (state.hasAccess) await _load(reset: true);
    } catch (e) {
      debugPrint('[gallery_tray] request: $e');
    }
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();
    try {
      await PhotoManager.openSetting();
    } catch (_) {}
  }

  Future<void> _manageLimited() async {
    HapticFeedback.selectionClick();
    try {
      await PhotoManager.presentLimited(type: RequestType.common);
    } catch (_) {}
    if (mounted) await _load(reset: true);
  }

  /// Bumped by every reset, so a page that was in flight for the other kind
  /// (a mode switch mid-load) is dropped instead of landing in this one.
  int _generation = 0;

  Future<void> _load({bool reset = false}) async {
    if (_loadingMore && !reset) return;
    _loadingMore = true;
    if (reset) _generation++;
    final generation = _generation;
    final start = reset ? 0 : _assets.length;
    try {
      final page = await PhotoManager.getAssetListRange(
        start: start,
        end: start + _page,
        type: widget.videos ? RequestType.video : RequestType.image,
        filterOption: _filter,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        if (reset) _assets.clear();
        _assets.addAll(page);
        _hasMore = page.length == _page;
      });
      widget.controller.latest.value = _assets.isEmpty ? null : _assets.first;
    } catch (e) {
      debugPrint('[gallery_tray] load: $e');
      if (mounted) setState(() => _hasMore = false);
    } finally {
      // A superseded load leaves the flag to the one that replaced it.
      if (generation == _generation) _loadingMore = false;
    }
  }

  Future<void> _pick(AssetEntity asset) async {
    if (_picking != null || _adding) return;
    HapticFeedback.selectionClick();
    setState(() => _picking = asset.id);
    try {
      await widget.onPick(asset);
    } finally {
      if (mounted) setState(() => _picking = null);
    }
  }

  // ---------------------------------------------------------------- selection

  bool get _selecting => _selection.isNotEmpty;

  /// Null outside multi-select; 0 for a photo that is not picked; otherwise
  /// its place in the order, from 1.
  int? _orderOf(AssetEntity asset) {
    if (!_selecting) return null;
    return _selection.indexWhere((a) => a.id == asset.id) + 1;
  }

  void _changeSelection(VoidCallback change) {
    final was = _selecting;
    setState(change);
    if (_selecting) _shownCount = _selection.length;
    if (was != _selecting) widget.onSelectingChanged?.call(_selecting);
  }

  void _clearSelection() {
    if (!_selecting || !mounted) return;
    _changeSelection(_selection.clear);
  }

  /// Whether a selection of [count] fits what the caller can still take.
  bool _fits(int count) {
    final room = widget.selectionRoom?.call();
    if (room == null || count <= room) return true;
    HapticFeedback.heavyImpact();
    AppToast.of(context).show(
      AppLocalizations.of(
        context,
      ).roomScreenMaxSelectionSnack(widget.selectionMax ?? math.max(room, 1)),
    );
    return false;
  }

  void _longPress(AssetEntity asset) {
    if (widget.onPickMany == null || _picking != null || _adding) return;
    if (_selecting) return _toggle(asset);
    if (!_fits(1)) return;
    HapticFeedback.mediumImpact();
    _changeSelection(() => _selection.add(asset));
  }

  void _toggle(AssetEntity asset) {
    final i = _selection.indexWhere((a) => a.id == asset.id);
    if (i < 0 && !_fits(_selection.length + 1)) return;
    HapticFeedback.selectionClick();
    _changeSelection(() {
      if (i >= 0) {
        _selection.removeAt(i);
      } else {
        _selection.add(asset);
      }
    });
  }

  Future<void> _addSelected() async {
    final add = widget.onPickMany;
    if (add == null || !_selecting || _adding || _picking != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _adding = true);
    try {
      await add(List.of(_selection));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  // ----------------------------------------------------------------- movement

  double _yFor(GalleryTrayStop stop, _Geometry g) => switch (stop) {
    GalleryTrayStop.hidden => g.hidden,
    GalleryTrayStop.strip => g.strip,
    GalleryTrayStop.full => g.full,
  };

  void _setFull(bool full) {
    if (_full == full) return;
    _full = full;
    widget.onFullChanged?.call(full);
  }

  void _settleTo(
    GalleryTrayStop stop, {
    double velocity = 0,
    bool remember = true,
  }) {
    if (!mounted) return;
    _stop = stop;
    // Pushed down to the grabber, the photos are gone; so is what was picked
    // among them.
    if (stop == GalleryTrayStop.hidden) _clearSelection();
    widget.onSettle?.call(stop);
    final g = _geo;
    if (g == null) return; // laid out at [_stop] on the first build
    if (stop != GalleryTrayStop.full) {
      if (remember) _rememberedStop = stop;
      _setFull(false);
    }
    final target = _yFor(stop, g);
    if (MediaQuery.disableAnimationsOf(context)) {
      _y.value = target;
      if (stop == GalleryTrayStop.full) _setFull(true);
      return;
    }
    // Slightly under critical damping: it lands with the faint settle of a
    // UIKit sheet rather than the dead stop of a curve.
    final sim = SpringSimulation(
      const SpringDescription(mass: 1, stiffness: 420, damping: 38),
      _y.value,
      target,
      velocity,
    );
    _y.animateWith(sim).whenCompleteOrCancel(() {
      if (!mounted || _stop != stop || _dragging) return;
      if (stop == GalleryTrayStop.full) _setFull(true);
    });
  }

  void _dragStart() {
    _y.stop();
    _dragFrom = _stop;
    _dragging = true;
    // The camera wakes up as soon as the grid starts to uncover it, not when
    // the sheet has finished leaving.
    _setFull(false);
  }

  void _dragUpdate(double dy) {
    final g = _geo;
    if (g == null) return;
    _y.value = (_y.value + dy).clamp(g.full, g.hidden);
  }

  void _dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    final g = _geo;
    if (g == null) return;
    final y = _y.value;
    final stops = [
      (GalleryTrayStop.full, g.full),
      (GalleryTrayStop.strip, g.strip),
      (GalleryTrayStop.hidden, g.hidden),
    ];
    GalleryTrayStop target;
    if (velocity.abs() > 300) {
      // A flick goes one stop in the direction it was thrown, from wherever
      // the finger let go — not to the nearest, which is where it started.
      final ahead = velocity < 0
          ? stops.lastWhere((s) => s.$2 < y - 1, orElse: () => stops.first)
          : stops.firstWhere((s) => s.$2 > y + 1, orElse: () => stops.last);
      target = ahead.$1;
    } else {
      // An unhurried drag: the two stops either side of the finger, and a
      // quarter of the way out of the one it started from commits to the
      // other. Nearest-stop needed half of a screen-tall gap, which read as
      // a swipe that did nothing and had to be repeated.
      final above = stops.lastWhere(
        (s) => s.$2 <= y,
        orElse: () => stops.first,
      );
      final below = stops.firstWhere(
        (s) => s.$2 >= y,
        orElse: () => stops.last,
      );
      if (above.$1 == below.$1) {
        target = above.$1;
      } else {
        final f = (y - above.$2) / (below.$2 - above.$2);
        final from = _yFor(_dragFrom, g);
        final cut = from <= above.$2 + 0.5
            ? 0.25
            : from >= below.$2 - 0.5
            ? 0.75
            : 0.5;
        target = f < cut ? above.$1 : below.$1;
      }
    }
    if (target != _stop) HapticFeedback.selectionClick();
    _settleTo(target, velocity: velocity);
  }

  void _tapHandle() {
    HapticFeedback.selectionClick();
    _settleTo(switch (_stop) {
      GalleryTrayStop.hidden => GalleryTrayStop.strip,
      GalleryTrayStop.strip => GalleryTrayStop.hidden,
      GalleryTrayStop.full => GalleryTrayStop.strip,
    });
  }

  /// Pulling the grid down from its top drags the sheet, the way a UIKit
  /// sheet hands a scroll view's overscroll to itself.
  bool _onGridScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final g = _geo;
    if (g == null) return false;
    if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      if (!_dragging) _dragStart();
      _dragUpdate(-n.overscroll);
    } else if (n is ScrollUpdateNotification &&
        _dragging &&
        n.dragDetails != null &&
        _y.value > g.full + 0.5) {
      // Sheet already pulled down and the finger turns back up: the sheet
      // rises first, and the grid only scrolls once it is home.
      final d = n.scrollDelta ?? 0;
      if (d > 0) {
        _dragUpdate(-d);
        if (_grid.hasClients && _grid.offset != 0) _grid.jumpTo(0);
      }
    } else if (n is ScrollEndNotification && _dragging) {
      _dragEnd(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  // --------------------------------------------------------------------- view

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final limited = _access == GalleryAccess.limited;
    // Everything that does not depend on where the sheet is, built once per
    // state change rather than once per frame of a drag: the animation below
    // hands these same instances back, so the grid's tiles and the strip's
    // thumbnails are never rebuilt by movement alone.
    final stripZone = _dragZone(_stripBody(context));
    final grid = _gridBody(context);
    final header = _headerRow(context);
    final note = limited ? _limitedNote(context) : null;
    final bar = _selectionBar(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final bottomOfStrip = h - widget.anchor;
        final g = _Geometry(
          full: 0,
          strip: bottomOfStrip - _strip - _handle,
          hidden: bottomOfStrip - _handle,
        );
        final first = _geo == null;
        final moved = _geo != null && _geo != g;
        _geo = g;
        if (first || (moved && !_dragging && !_y.isAnimating)) {
          _y.value = _yFor(_stop, g);
        }
        final gridTop = safe.top + _handle + _header + (limited ? _note : 0);

        return AnimatedBuilder(
          animation: _y,
          builder: (context, _) {
            final y = _y.value;
            // 0 at the strip, 1 at full screen.
            final t = ((g.strip - y) / (g.strip - g.full)).clamp(0.0, 1.0);
            // 1 at the strip, 0 once it is pushed down to the grabber.
            final reveal =
                ((g.hidden - y) / (g.hidden - g.strip)).clamp(0.0, 1.0);
            final stripOpacity = (reveal * (1 - t * 2.5)).clamp(0.0, 1.0);
            final gridOpacity = ((t - 0.3) / 0.6).clamp(0.0, 1.0);
            final top = safe.top * t;
            // Above the grabber at the strip, down at the bottom edge once it
            // is a gallery: the "Add" rides with the sheet between the two.
            final barTop =
                (y - _barHeight - 10) * (1 - t) +
                (h - safe.bottom - _barHeight - 16) * t;

            // Every child is here on every frame, in the same order. The dim
            // used to be inserted ahead of the sheet the moment it rose off
            // the strip; unkeyed, the Stack then matched the sheet's element
            // to the dim and built the sheet afresh, which killed the drag
            // under the finger. That was the "takes two swipes", both ways:
            // the spring settling onto the strip removed the dim again.
            return Stack(
              children: [
                // The camera dims under a rising sheet, like any iOS sheet.
                Positioned.fill(
                  child: IgnorePointer(
                    child: t > 0
                        ? ColoredBox(
                            color: Colors.black.withValues(alpha: 0.45 * t),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: y,
                  height: h,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          // Solid once it is a gallery: it covers the
                          // viewfinder, and taps on it are taps on the sheet.
                          ignoring: t < 0.5,
                          child: Opacity(
                            opacity: t,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B0B0D),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(28 * (1 - t)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: top + _handle + _header +
                            (limited ? _note : 0),
                        height: h - gridTop,
                        child: IgnorePointer(
                          ignoring: gridOpacity < 0.95,
                          child: Opacity(opacity: gridOpacity, child: grid),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: top,
                        child: _dragZone(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _grabber(context, t),
                              SizedBox(
                                height: _header * t,
                                child: Visibility(
                                  visible: t >= 0.05,
                                  maintainState: true,
                                  child: Opacity(
                                    opacity: ((t - 0.5) / 0.5)
                                        .clamp(0.0, 1.0),
                                    child: header,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: note == null ? 0 : _note * t,
                                child: note == null || t < 0.05
                                    ? null
                                    : Opacity(
                                        opacity: ((t - 0.5) / 0.5)
                                            .clamp(0.0, 1.0),
                                        child: note,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: _handle,
                        height: _strip,
                        child: IgnorePointer(
                          ignoring: stripOpacity < 0.5,
                          child: Opacity(
                            opacity: stripOpacity,
                            child: stripZone,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: barTop,
                  height: _barHeight,
                  child: Opacity(
                    opacity: math.max(reveal, t),
                    child: bar,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const _barHeight = 46.0;

  /// Cancel and "Add (N)", for a multi-selection. Always built, faded and
  /// slid in and out, so it never shifts the Stack around it.
  Widget _selectionBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final label = l10n.galleryTrayAddSelectedButton(_shownCount);
    final on = _selecting;
    return IgnorePointer(
      ignoring: !on,
      child: AnimatedSlide(
        offset: on ? Offset.zero : const Offset(0, 0.4),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassIconButton(
                tone: GlassTone.media,
                icon: CupertinoIcons.xmark,
                size: _barHeight,
                semanticLabel: l10n.galleryTrayCancelSelectionLabel,
                // It rides the sheet's drag; a moving blur is never drawn.
                still: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _clearSelection();
                },
              ),
              const SizedBox(width: 10),
              SpringPress(
                onTap: _adding ? null : _addSelected,
                semanticLabel: label,
                focusShape: FocusRingShape.capsule,
                haptic: false,
                child: Container(
                  height: _barHeight,
                  constraints: const BoxConstraints(minWidth: 132),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [MediaGlass.shadow],
                  ),
                  alignment: Alignment.center,
                  child: _adding
                      ? PhotoSpinner(size: 18, color: theme.accentInk)
                      : Text(
                          sentenceCaseOf(context, label),
                          maxLines: 1,
                          style: theme.body.copyWith(
                            color: theme.accentInk,
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragZone(Widget child) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onVerticalDragStart: (_) => _dragStart(),
    onVerticalDragUpdate: (d) => _dragUpdate(d.delta.dy),
    onVerticalDragEnd: (d) => _dragEnd(d.velocity.pixelsPerSecond.dy),
    onVerticalDragCancel: () => _dragEnd(0),
    child: child,
  );

  Widget _grabber(BuildContext context, double t) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).galleryTrayHandleLabel,
      onTap: _tapHandle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tapHandle,
        child: SizedBox(
          height: _handle,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: Color.lerp(
                  MediaGlass.ink.withValues(alpha: 0.9),
                  MediaGlass.inkDim,
                  t,
                ),
                borderRadius: BorderRadius.circular(3),
                // Carries the white bar over a white wall in the viewfinder.
                boxShadow: t > 0.5
                    ? null
                    : const [
                        BoxShadow(color: Color(0x66000000), blurRadius: 6),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GlassIconButton(
            tone: GlassTone.media,
            icon: CupertinoIcons.chevron_down,
            semanticLabel: l10n.galleryTrayBackToCameraLabel,
            // It fades in with the sheet; a fading blur is never drawn.
            still: true,
            onTap: () {
              HapticFeedback.selectionClick();
              _settleTo(GalleryTrayStop.strip);
            },
          ),
          Expanded(
            child: Text(
              sentenceCaseOf(
                context,
                _selecting
                    ? l10n.galleryTraySelectedTitle(_selection.length)
                    : l10n.galleryTrayRecentsTitle,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.body.copyWith(
                color: MediaGlass.ink,
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (widget.onBrowseAll != null)
            GlassIconButton(
              tone: GlassTone.media,
              icon: CupertinoIcons.square_grid_2x2,
              semanticLabel: l10n.galleryTrayAllPhotosLabel,
              still: true,
              onTap: widget.onBrowseAll,
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _limitedNote(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final style = theme.body.copyWith(
      fontSize: 13,
      height: 1.2,
      decoration: TextDecoration.none,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.galleryTrayLimitedNote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style.copyWith(color: MediaGlass.inkDim),
            ),
          ),
          SpringPress(
            onTap: _manageLimited,
            semanticLabel: l10n.galleryTrayManageButton,
            scale: PressSpec.scaleSmall,
            focusShape: FocusRingShape.capsule,
            haptic: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(
                sentenceCaseOf(context, l10n.galleryTrayManageButton),
                style: style.copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What sits where photos would, when there are none to show.
  Widget? _gate(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (_access) {
      GalleryAccess.unknown => null,
      GalleryAccess.prompt => _GateCard(
        icon: CupertinoIcons.photo_on_rectangle,
        text: l10n.galleryTrayAllowPrompt,
        action: l10n.galleryTrayAllowButton,
        onTap: _requestAccess,
      ),
      GalleryAccess.denied => _GateCard(
        icon: CupertinoIcons.lock,
        text: l10n.galleryTrayDeniedPrompt,
        action: l10n.galleryTraySettingsButton,
        onTap: _openSettings,
      ),
      _ when _assets.isEmpty && !_loadingMore => _GateCard(
        icon: CupertinoIcons.photo,
        text: l10n.galleryTrayEmpty,
      ),
      _ => null,
    };
  }

  Widget _stripBody(BuildContext context) {
    final gate = _gate(context);
    if (gate != null) return Center(child: gate);
    final l10n = AppLocalizations.of(context);
    final limited = _access == GalleryAccess.limited;
    final count = _assets.length + (limited ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i >= _assets.length) {
            // Limited access: the way to let more of the library in.
            return _AddTile(
              size: _thumb,
              semanticLabel: l10n.galleryTrayManageButton,
              onTap: _manageLimited,
            );
          }
          if (i >= _assets.length - 10 && _hasMore) unawaited(_load());
          final asset = _assets[i];
          return _Thumb(
            asset: asset,
            size: _thumb,
            radius: 12,
            busy: _picking == asset.id,
            order: _orderOf(asset),
            semanticLabel: l10n.galleryTrayPhotoLabel(i + 1),
            onTap: _selecting ? () => _toggle(asset) : () => _pick(asset),
            onLongPress: widget.onPickMany == null
                ? null
                : () => _longPress(asset),
          );
        },
      ),
    );
  }

  Widget _gridBody(BuildContext context) {
    final gate = _gate(context);
    if (gate != null) {
      return Align(
        alignment: const Alignment(0, -0.4),
        child: gate,
      );
    }
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return LayoutBuilder(
      builder: (context, c) {
        final columns = math.max(4, (c.maxWidth / 130).floor());
        return NotificationListener<ScrollNotification>(
          onNotification: _onGridScroll,
          child: GridView.builder(
            controller: _grid,
            // Clamping, so pulling down at the top is an overscroll this
            // sheet can take rather than a bounce the grid keeps.
            physics: const ClampingScrollPhysics(),
            // Room under the last row for the "Add" bar while selecting.
            padding: EdgeInsets.fromLTRB(
              2,
              2,
              2,
              bottom + 12 + (_selecting ? _barHeight + 16 : 0),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: _assets.length,
            itemBuilder: (context, i) {
              if (i >= _assets.length - 30 && _hasMore) unawaited(_load());
              final asset = _assets[i];
              return _Thumb(
                asset: asset,
                radius: 0,
                busy: _picking == asset.id,
                order: _orderOf(asset),
                semanticLabel: l10n.galleryTrayPhotoLabel(i + 1),
                onTap: _selecting ? () => _toggle(asset) : () => _pick(asset),
                onLongPress: widget.onPickMany == null
                    ? null
                    : () => _longPress(asset),
              );
            },
          ),
        );
      },
    );
  }
}

@immutable
class _Geometry {
  const _Geometry({
    required this.full,
    required this.strip,
    required this.hidden,
  });

  final double full;
  final double strip;
  final double hidden;

  @override
  bool operator ==(Object other) =>
      other is _Geometry &&
      other.full == full &&
      other.strip == strip &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(full, strip, hidden);
}

/// One photo: a square crop of its thumbnail, a spinner while it is being
/// fetched for the composer.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.asset,
    required this.radius,
    required this.busy,
    required this.semanticLabel,
    required this.onTap,
    this.size,
    this.order,
    this.onLongPress,
  });

  final AssetEntity asset;
  final double? size;
  final double radius;
  final bool busy;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Null outside multi-select; 0 when this photo is not picked; otherwise
  /// its place in the order, from 1.
  final int? order;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: AssetEntityImageProvider(
        asset,
        isOriginal: false,
        thumbnailSize: _GalleryTrayState._thumbSize,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // Fades in rather than popping, so a fast scroll reads as photos
      // arriving and not as tiles flashing.
      frameBuilder: (context, child, frame, sync) {
        if (sync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: child,
        );
      },
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    final picked = (order ?? 0) > 0;
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0x1FFFFFFF)),
          // A picked photo draws in from its edges, the way the system
          // picker marks it, so the order badges are not the only tell.
          AnimatedScale(
            scale: picked ? 0.86 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(picked ? 8 : radius),
              child: image,
            ),
          ),
          if (radius > 0)
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: MediaGlass.stroke, width: 0.6),
              ),
            ),
          if (asset.type == AssetType.video)
            Positioned(
              left: 4,
              bottom: 4,
              child: MediaDurationBadge(
                duration: Duration(seconds: asset.duration),
              ),
            ),
          if (busy)
            const ColoredBox(
              color: kMediaScrim,
              child: Center(child: PhotoSpinner(size: 20)),
            ),
          if (order != null)
            Positioned(
              top: 5,
              right: 5,
              child: _OrderBadge(order: order!),
            ),
        ],
      ),
    );
    return SpringPress(
      onTap: busy ? null : onTap,
      onLongPress: busy ? null : onLongPress,
      semanticLabel: picked ? '$semanticLabel, $order' : semanticLabel,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.rounded,
      focusRadius: radius,
      haptic: false,
      child: size == null
          ? tile
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: const [MediaGlass.shadow],
              ),
              child: SizedBox.square(dimension: size, child: tile),
            ),
    );
  }
}

/// A photo's place in a multi-selection: an empty ring until it is picked,
/// then its number on the accent.
class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final on = order > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? theme.accent : const Color(0x33000000),
        border: Border.all(
          color: on ? theme.accent : MediaGlass.ink,
          width: 1.5,
        ),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 3)],
      ),
      child: on
          ? Text(
              '$order',
              style: theme.body.copyWith(
                color: theme.accentInk,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            )
          : null,
    );
  }
}

/// The strip's trailing "+" under limited access.
class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.size,
    required this.semanticLabel,
    required this.onTap,
  });

  final double size;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: PressSpec.scaleSmall,
      focusShape: FocusRingShape.rounded,
      focusRadius: 12,
      haptic: false,
      child: LiquidGlass(
        tone: GlassTone.media,
        shape: LiquidGlassShape.rounded,
        radius: 12,
        still: true,
        size: Size.square(size),
        child: Icon(
          CupertinoIcons.plus,
          size: 22,
          color: ThemeScope.of(context).accent,
        ),
      ),
    );
  }
}

/// A one-line explanation, and the one thing to do about it.
///
/// Still media glass — no blur: it rides the strip's fade and the sheet's
/// drag, and a blur is never animated in this app.
class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.icon,
    required this.text,
    this.action,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final style = theme.body.copyWith(
      color: MediaGlass.ink,
      fontSize: 14,
      height: 1.25,
      decoration: TextDecoration.none,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LiquidGlass(
      tone: GlassTone.media,
      shape: LiquidGlassShape.capsule,
      still: true,
      padding: EdgeInsets.fromLTRB(14, 8, action == null ? 16 : 8, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: MediaGlass.inkDim),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (action != null && onTap != null) ...[
            const SizedBox(width: 10),
            SpringPress(
              onTap: onTap,
              semanticLabel: action,
              scale: PressSpec.scaleSmall,
              focusShape: FocusRingShape.capsule,
              haptic: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sentenceCaseOf(context, action!),
                  style: style.copyWith(
                    color: theme.accentInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
