import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../media/file_meta.dart' show formatFileSize, kMaxFileUploadBytes;
import '../media/image_raster.dart' show CroppedImage;
import '../media/photo_picking.dart' show kMaxPhotoSelection;
import '../theme/theme_scope.dart';
import 'app_toast.dart';
import 'glass_buttons.dart';
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

/// What a library item weighs, from the library's own records: no download,
/// so asking for an iCloud clip's size does not fetch the clip. Asked once
/// per item for the app's session. Null when the library will not say.
abstract final class AssetSizes {
  static final Map<String, int?> _known = {};
  static final Map<String, Future<int?>> _asking = {};

  /// Already answered: the size, or null for "will not say" as well as for
  /// "not asked yet". See [isKnown].
  static int? known(AssetEntity asset) => _known[asset.id];
  static bool isKnown(AssetEntity asset) => _known.containsKey(asset.id);

  static Future<int?> of(AssetEntity asset) {
    if (_known.containsKey(asset.id)) return Future.value(_known[asset.id]);
    return _asking[asset.id] ??= () async {
      int? bytes;
      try {
        final n = await asset.fileSize;
        bytes = n > 0 ? n : null;
      } catch (_) {}
      _known[asset.id] = bytes;
      _asking.remove(asset.id);
      return bytes;
    }();
  }

  /// A video over the upload cap: it is compressed to fit when it is sent.
  static bool overCap(int? bytes) =>
      bytes != null && bytes > kMaxFileUploadBytes;
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

  // ───────────── the sheet: the keyboard's place, or the whole room ─────────────

  /// Drives the panel between where the keyboard was and the whole room.
  /// Attached while the panel is up (the [InlinePhotoPicker] owns the sheet).
  final DraggableScrollableController sheet = DraggableScrollableController();

  /// The sheet's resting size, as a fraction of the room: the keyboard's
  /// place. Kept current by the sheet as the room's height changes.
  double _restingSize = 0;

  /// The panel has been pulled up past its resting height. The system back
  /// brings it down before it closes it.
  bool get isExpanded =>
      _open && sheet.isAttached && sheet.size > _restingSize + 0.005;

  /// Up to the whole room, as a drag up would take it.
  void expand() => _settle(1);

  /// Back down to the keyboard's place.
  void collapse() => _settle(_restingSize);

  /// Down and away, as a drag down from rest takes it; the picks stay.
  void dismiss() {
    if (!_open) return;
    if (!sheet.isAttached) return close();
    _settle(0);
  }

  void _settle(double size) {
    if (!_open || !sheet.isAttached) return;
    sheet.animateTo(
      size,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    sheet.dispose();
    super.dispose();
  }
}

/// The photo library as a grid in the keyboard's place: tap to pick, tap
/// again to unpick, each pick numbered in the order it will be sent. The
/// iMessage picker. What is picked waits in the strip over the composer
/// ([PickedMediaStrip]) until it is sent.
///
/// It rests in the keyboard's place and pulls up to fill the room, the way
/// Telegram's does: drag the grabber, or drag the grid itself (the sheet
/// grows before the grid scrolls, and a pull down from the top of the grid
/// brings it back). Full, a bar names the picks and "Add" brings it down to
/// the composer to send them.
///
/// So it lays over the room rather than sitting in the composer's column:
/// put it in a `Positioned.fill` over the whole room, and hold its resting
/// place in the column with a box [height] + [bottomPadding] tall. The whole
/// sheet is one room-height layer that the drag moves; the grid is never
/// laid out again while it does.
///
/// Phones only ([supported]): the library is `photo_manager`'s, which has no
/// desktop or web implementation; those keep the system picker.
class InlinePhotoPicker extends StatefulWidget {
  const InlinePhotoPicker({
    super.key,
    required this.controller,
    required this.height,
    this.bottomPadding = 0,
    this.onFull,
  });

  final InlinePickerController controller;

  /// The resting panel's height: the keyboard's.
  final double height;

  /// What the room keeps clear below the panel at rest (the home indicator).
  /// The sheet paints it, so the panel reads as running to the screen's edge.
  final double bottomPadding;

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

/// Where a let-go drag sends the sheet.
enum _Stop { away, rest, full }

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
    widget.controller.sheet.addListener(_onSheet);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onPicks);
    widget.controller.sheet.removeListener(_onSheet);
    _size.dispose();
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
      if (asset.type == AssetType.video &&
          widget.controller.orderOf(asset) > 0) {
        _noteIfOverCap(asset);
      }
    } else {
      HapticFeedback.heavyImpact();
      widget.onFull?.call();
    }
  }

  /// A video over the upload cap is still picked: it is compressed to fit
  /// when sent, the way every other way of sending a video does it. Said
  /// now, at the pick, rather than as a surprise at SEND.
  Future<void> _noteIfOverCap(AssetEntity asset) async {
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    final bytes = await AssetSizes.of(asset);
    if (!mounted || !AssetSizes.overCap(bytes)) return;
    if (widget.controller.orderOf(asset) == 0) return;
    toast.show(
        l10n.inlinePickerVideoCompressNote(formatFileSize(kMaxFileUploadBytes)));
  }

  // ─────────────────────────── the sheet ───────────────────────────

  /// The grabber's strip, the only chrome the panel has at rest.
  static const _grip = 22.0;

  /// The bar that names the picks once the sheet is full.
  static const _bar = 52.0;

  /// The sheet's size as a fraction of the room, for the chrome that follows
  /// it (the bar, the corners, the scrim). The grid does not listen.
  final ValueNotifier<double> _size = ValueNotifier(0);

  bool _dragging = false;

  /// Whether the drag in hand started from a full sheet, so letting go
  /// clicks only when it lands somewhere else.
  bool _dragFromFull = false;

  void _onSheet() {
    final sheet = widget.controller.sheet;
    if (!sheet.isAttached) return;
    // Pulled all the way down: put away, as the keyboard would be. Checked
    // after the frame, so a sheet that only passes through 0 on its way back
    // up stays.
    if (sheet.size <= 0.001) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && sheet.isAttached && sheet.size <= 0.001) {
          widget.controller.close();
        }
      });
    }
    // The sheet reports a new size from inside its own rebuild when the room
    // changes height under it; the chrome hears it a frame later rather than
    // being marked dirty mid-build.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && sheet.isAttached) _size.value = sheet.size;
      });
    } else {
      _size.value = sheet.size;
    }
  }

  /// Keeps a resting sheet resting when the room's height changes under it
  /// (a rotation, the keyboard finishing its way down). The sheet tracks its
  /// initial size by itself only until it has first been moved; after that a
  /// shorter resting size would leave it standing above the composer's place.
  void _syncRest(double rest) {
    final c = widget.controller;
    final old = c._restingSize;
    if (old == rest) return;
    c._restingSize = rest;
    if (!c.sheet.isAttached || (c.sheet.size - old).abs() > 0.005) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dragging || !c.sheet.isAttached) return;
      if ((c.sheet.size - c._restingSize).abs() > 0.0005) {
        c.sheet.jumpTo(c._restingSize);
      }
    });
  }

  void _dragStart() {
    _dragging = true;
    _dragFromFull = widget.controller.isExpanded;
  }

  void _dragUpdate(double dy, double h) {
    final sheet = widget.controller.sheet;
    if (!sheet.isAttached) return;
    sheet.jumpTo((sheet.size - dy / h).clamp(0.0, 1.0));
  }

  void _dragEnd(double velocity) {
    if (!_dragging) return;
    _dragging = false;
    final c = widget.controller;
    if (!c.sheet.isAttached) return;
    final rest = c._restingSize;
    final size = c.sheet.size;
    // A flick goes one stop in its direction; a slow let-go goes to the
    // nearer stop, with rest holding on to most of the way down.
    final _Stop to;
    if (velocity > 300) {
      to = size > rest + 0.01 ? _Stop.rest : _Stop.away;
    } else if (velocity < -300) {
      to = size < rest - 0.01 ? _Stop.rest : _Stop.full;
    } else if (size > rest) {
      final t = rest >= 1 ? 0.0 : (size - rest) / (1 - rest);
      to = t > 0.5 ? _Stop.full : _Stop.rest;
    } else {
      to = size < rest * 0.6 ? _Stop.away : _Stop.rest;
    }
    final from = _dragFromFull ? _Stop.full : _Stop.rest;
    if (to != from) HapticFeedback.selectionClick();
    switch (to) {
      case _Stop.full:
        c.expand();
      case _Stop.rest:
        c.collapse();
      case _Stop.away:
        c.dismiss();
    }
  }

  void _tapGrabber() {
    HapticFeedback.selectionClick();
    final c = widget.controller;
    c.isExpanded ? c.collapse() : c.expand();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final topSafe = MediaQuery.paddingOf(context).top;
    final body = _body(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final rest =
            ((widget.height + widget.bottomPadding) / h).clamp(0.0, 1.0);
        _syncRest(rest);
        // The grid is laid out once, at the height it has when the sheet is
        // full, and only moves after that.
        final header = topSafe + _grip + _bar;
        double progress(double size) =>
            rest >= 1 ? 0 : ((size - rest) / (1 - rest)).clamp(0.0, 1.0);
        return Stack(
          children: [
            // Dims the room as the sheet comes up over it; a tap on what is
            // still showing sends it back down.
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _size,
                builder: (context, size, _) {
                  final t = progress(size);
                  if (t <= 0) return const SizedBox.shrink();
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.controller.collapse,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.4 * t),
                    ),
                  );
                },
              ),
            ),
            DraggableScrollableSheet(
              controller: widget.controller.sheet,
              initialChildSize: rest,
              // Down to nothing, so a pull down from rest puts it away
              // (see [_onSheet]); rest is a stop on the way.
              minChildSize: 0,
              maxChildSize: 1,
              snap: true,
              snapSizes: rest > 0 && rest < 1 ? [rest] : null,
              builder: (context, scroll) => OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: h,
                maxHeight: h,
                child: ValueListenableBuilder<double>(
                  valueListenable: _size,
                  child: body(scroll),
                  builder: (context, size, grid) {
                    final t = progress(size);
                    // Square at rest, where it stands in for the keyboard,
                    // and full, where it is the screen; a card in between.
                    final corner = 14 *
                        (t * 12).clamp(0.0, 1.0) *
                        ((1 - t) * 12).clamp(0.0, 1.0);
                    final reveal = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
                    // Its own text styles wherever it is put: no debug
                    // underlines from a host without a Material above it.
                    return Material(
                      type: MaterialType.transparency,
                      child: ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(corner)),
                      child: ColoredBox(
                        color: theme.background,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              top: topSafe * t + _grip + _bar * t,
                              height: h - header,
                              child: grid!,
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onVerticalDragStart: (_) => _dragStart(),
                                onVerticalDragUpdate: (d) =>
                                    _dragUpdate(d.delta.dy, h),
                                onVerticalDragEnd: (d) =>
                                    _dragEnd(d.velocity.pixelsPerSecond.dy),
                                onVerticalDragCancel: () => _dragEnd(0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(height: topSafe * t),
                                    _grabber(context, t),
                                    SizedBox(
                                      height: _bar * t,
                                      child: Visibility(
                                        visible: t >= 0.05,
                                        maintainState: true,
                                        child: Opacity(
                                          opacity: reveal,
                                          child: IgnorePointer(
                                            ignoring: reveal < 0.5,
                                            child: _headerBar(context),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _grabber(BuildContext context, double t) {
    final theme = ThemeScope.of(context);
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).galleryTrayHandleLabel,
      onTap: _tapGrabber,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tapGrabber,
        child: SizedBox(
          height: _grip,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 1 - t * 0.6,
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.inkMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              // How many of the most one send carries are picked: the cap
              // in view before it is hit, not only in the toast after.
              Positioned(
                right: 14,
                child: _PickCount(
                  count: widget.controller.picks.length,
                  max: widget.controller.max,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full: back down, what is picked, and "Add", which takes the picks down
  /// to the composer to be commented on and sent.
  Widget _headerBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final c = widget.controller;
    final count = c.picks.length;
    final add = l10n.galleryTrayAddSelectedButton(count);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GlassIconButton(
            icon: CupertinoIcons.chevron_down,
            semanticLabel: MaterialLocalizations.of(context).expandedIconTapHint,
            still: true,
            onTap: () {
              HapticFeedback.selectionClick();
              c.collapse();
            },
          ),
          Expanded(
            child: Text(
              sentenceCaseOf(
                context,
                count > 0
                    ? l10n.galleryTraySelectedTitle(count)
                    : l10n.galleryTrayRecentsTitle,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyEmph.copyWith(
                fontSize: 17,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Always the button's room, so the title stays centred as the
          // button comes and goes.
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: count > 0 ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: IgnorePointer(
                  ignoring: count == 0,
                  child: SpringPress(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      c.collapse();
                    },
                    semanticLabel: add,
                    focusShape: FocusRingShape.capsule,
                    haptic: false,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        sentenceCaseOf(context, add),
                        maxLines: 1,
                        style: theme.bodyEmph.copyWith(
                          color: theme.accentInk,
                          fontSize: 15,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What the sheet holds below its chrome: the grid on the
  /// sheet's [scroll] (so dragging the grid moves the sheet first), or the
  /// note that stands in for it, kept inside the resting panel's height so it
  /// shows at rest. Always something on [scroll]: the sheet is only attached
  /// (and only drags, from anywhere but the grabber) while it has one.
  Widget Function(ScrollController scroll) _body(
      BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final full = widget.controller.picks.length >= widget.controller.max;
    return (scroll) {
      Widget resting(Widget? child) => ListView(
            controller: scroll,
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: math.max(0, widget.height - _grip),
                child: child == null ? null : Center(child: child),
              ),
            ],
          );
      switch (_access) {
        case _Access.unknown:
          return resting(null);
        case _Access.prompt:
          return resting(_Gate(
            text: l10n.galleryTrayAllowPrompt,
            button: l10n.galleryTrayAllowButton,
            onTap: _request,
          ));
        case _Access.denied:
          return resting(_Gate(
            text: l10n.galleryTrayDeniedPrompt,
            button: l10n.galleryTraySettingsButton,
            onTap: () => PhotoManager.openSetting(),
          ));
        case _Access.granted:
        case _Access.limited:
          Widget body = _assets.isEmpty && _exhausted
              ? resting(Text(l10n.galleryTrayEmpty, style: theme.bodySoft))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.depth == 0 && n.metrics.extentAfter < 600) _load();
                    return false;
                  },
                  child: GridView.builder(
                    controller: scroll,
                    padding: EdgeInsets.only(
                        top: 2, bottom: 24 + widget.bottomPadding),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (_, i) {
                      final asset = _assets[i];
                      final order = widget.controller.orderOf(asset);
                      return _Tile(
                        asset: asset,
                        order: order,
                        // At the cap, what is left cannot be picked: it says
                        // so before a tap does.
                        dimmed: order == 0 && full,
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
                      await PhotoManager.presentLimited(
                          type: RequestType.common);
                    } catch (_) {}
                    if (mounted) await _load(reset: true);
                  },
                ),
                Expanded(child: body),
              ],
            );
          }
          return body;
      }
    };
  }
}

/// One square of the grid: the thumbnail, a video's length, and the pick
/// ring (empty, or the accent disc with the pick's number). A picked tile
/// eases in a little, the way iMessage marks one.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.asset,
    required this.order,
    required this.onTap,
    this.dimmed = false,
  });

  final AssetEntity asset;
  final int order;
  final VoidCallback onTap;

  /// The picks are at the cap and this is not one of them.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final picked = order > 0;
    return SpringPress(
      onTap: onTap,
      haptic: false,
      scale: 0.96,
      child: AnimatedOpacity(
        opacity: dimmed ? 0.35 : 1,
        duration: const Duration(milliseconds: 160),
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
          if (asset.type == AssetType.video)
            Positioned(
              right: 6,
              bottom: 6,
              child: _OverCapBadge(asset: asset),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: _OrderRing(order: order),
          ),
        ],
        ),
      ),
    );
  }
}

/// A video's size, on its tile, when it is over the upload cap: it will be
/// compressed to fit. Nothing on a video that goes as it is.
class _OverCapBadge extends StatefulWidget {
  const _OverCapBadge({required this.asset});

  final AssetEntity asset;

  @override
  State<_OverCapBadge> createState() => _OverCapBadgeState();
}

class _OverCapBadgeState extends State<_OverCapBadge> {
  int? _bytes;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(_OverCapBadge old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id) {
      _bytes = null;
      _read();
    }
  }

  void _read() {
    final asset = widget.asset;
    if (AssetSizes.isKnown(asset)) {
      _bytes = AssetSizes.known(asset);
      return;
    }
    AssetSizes.of(asset).then((bytes) {
      if (mounted && widget.asset.id == asset.id) {
        setState(() => _bytes = bytes);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (!AssetSizes.overCap(bytes)) return const SizedBox.shrink();
    return MediaDurationBadge(text: formatFileSize(bytes!));
  }
}

/// "3/10" beside the grabber while anything is picked.
class _PickCount extends StatelessWidget {
  const _PickCount({required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final at = count >= max;
    return AnimatedOpacity(
      opacity: count > 0 ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: Text(
        '$count/$max',
        style: theme.caption.copyWith(
          color: at ? theme.accent : theme.inkSoft,
          fontWeight: FontWeight.w600,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
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
/// each with a remove button. Tapping a photo opens it in the editor, a
/// video in the player.
///
/// One open at a time. Getting there waits on the library (a full-size
/// photo, a video's file, seconds when it lives in iCloud), and a second
/// tap in that wait used to stack a second editor on the first. Until
/// [onOpen] resolves the strip takes no more opens, and the tile being
/// opened shows a spinner.
///
/// A new pick lands at the end, and the strip follows it there: the newest
/// is always the one in view, however many came before it. A removal or an
/// edit leaves the strip where the person put it.
class PickedMediaStrip extends StatefulWidget {
  const PickedMediaStrip({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final InlinePickerController controller;

  /// Opens [m], resolving once whatever it opened is up (or has closed).
  final Future<void> Function(PickedMedia m) onOpen;

  @override
  State<PickedMediaStrip> createState() => _PickedMediaStripState();
}

class _PickedMediaStripState extends State<PickedMediaStrip> {
  static const double _h = 112;

  final ScrollController _scroll = ScrollController();
  late int _count = widget.controller.picks.length;

  /// The asset being opened, while [PickedMediaStrip.onOpen] is in flight.
  String? _opening;

  Future<void> _open(PickedMedia pick) async {
    if (_opening != null) return;
    setState(() => _opening = pick.asset.id);
    try {
      await widget.onOpen(pick);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPicks);
  }

  @override
  void didUpdateWidget(PickedMediaStrip old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onPicks);
      widget.controller.addListener(_onPicks);
      _count = widget.controller.picks.length;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPicks);
    _scroll.dispose();
    super.dispose();
  }

  void _onPicks() {
    final count = widget.controller.picks.length;
    final grew = count > _count;
    _count = count;
    setState(() {});
    if (!grew) return;
    // After the frame that lays the new tile out, when the end is where it
    // will stay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final picks = widget.controller.picks;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: picks.isEmpty
          ? const SizedBox(width: double.infinity)
          : SizedBox(
              height: _h,
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                itemCount: picks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _StripTile(
                  key: ValueKey(picks[i].asset.id),
                  pick: picks[i],
                  opening: _opening == picks[i].asset.id,
                  onTap: () => _open(picks[i]),
                  onRemove: () {
                    HapticFeedback.selectionClick();
                    widget.controller.remove(picks[i]);
                  },
                ),
              ),
            ),
    );
  }
}

class _StripTile extends StatelessWidget {
  const _StripTile({
    super.key,
    required this.pick,
    required this.opening,
    required this.onTap,
    required this.onRemove,
  });

  final PickedMedia pick;
  final bool opening;
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
          if (pick.isVideo && !opening)
            const Center(
              child: IgnorePointer(
                child: Icon(CupertinoIcons.play_circle_fill,
                    size: 30, color: Colors.white),
              ),
            ),
          // Faded in, so an open that is quick never flashes it.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: opening ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  child: opening
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : null,
                ),
              ),
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
