import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'
    show Colors, Material, MaterialType, MaterialPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/location_share.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/caps.dart';
import '../widgets/location_address.dart';
import '../widgets/location_map_preview.dart';
import '../widgets/map_engine.dart';
import '../widgets/open_free_map_snapshot.dart';
import '../widgets/open_free_map_tiles.dart';
import '../widgets/location_share_sheet.dart' show LocationShareChoice;
import '../widgets/place_search.dart';

/// Sending a location: one map, opened from the attachment menu.
///
/// The pin starts on you, and the first row says so: "Send current location,
/// accurate to 5 m" (sent from a fresh fix). Move the map and that same row
/// becomes "Send this location" with the street under the pin; the locate
/// button turns it back. "Share live location" opens its durations inline,
/// and nearby places and search sit under it. Current, chosen, live and nearby
/// are one surface rather than a menu of modes, and sending where you are is
/// still one tap.
///
/// The panel is a sheet: drag it (or scroll the list) up to nearly full
/// screen when browsing places, back down to see the map.
///
/// Move the map and the pin lifts off while it moves, lands with a tick when
/// it stops, and the panel underneath names the street it landed on. Search
/// jumps the map to an address or a place; "Nearby places" (Apple only:
/// MapKit's points of interest are free, Google's are billed) lists what is
/// around the pin and sends one with a tap. "Send this location" sends the
/// pin.
///
/// The same [MapEngine] as everywhere else: MapKit or Google as a native view
/// in picker mode (`MapViewFactory.swift` / `.kt`: no marker, reports the
/// centre on `cameraIdle`), or OpenFreeMap in `flutter_map`.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.start, this.allowLive = true});

  /// False where live shares are not allowed (a room whose messages expire);
  /// the live row is left out.
  final bool allowLive;

  /// Where to open: your position if known, else a wide view of the world.
  final LocationFix? start;

  static Future<LocationShareChoice?> open(
    BuildContext context, {
    LocationFix? start,
    bool allowLive = true,
  }) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<LocationShareChoice>(
      fullscreenDialog: true,
      builder: (_) => LocationPickerScreen(start: start, allowLive: allowLive),
    ),
  );

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapEngine? _engine;
  MethodChannel? _native;
  final _ofm = MapController();
  bool _ofmReady = false;

  late LatLng _center = widget.start == null
      ? const LatLng(30, 15)
      : LatLng(widget.start!.latitude, widget.start!.longitude);
  bool _moving = false;
  Timer? _ofmIdle;

  ({String title, String subtitle})? _address;
  String? _pickedName;
  List<PlaceResult> _nearby = const [];
  LatLng? _nearbyAt;

  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  List<PlaceResult>? _results;
  Timer? _searchDebounce;
  int _searchSeq = 0;

  bool _meAllowed = false;

  double get _startSpan => widget.start == null ? 8000000 : 500;

  @override
  void initState() {
    super.initState();
    final known = MapEngines.current;
    if (known != null) {
      _engine = known;
    } else {
      MapEngines.resolve().then((e) {
        if (mounted) setState(() => _engine = e);
      });
    }
    _query.addListener(_onQuery);
    _searchFocus.addListener(() => setState(() {}));
    LocationService.instance.check().then((a) {
      if (mounted && a == LocationAvailability.ready) {
        setState(() => _meAllowed = true);
        _native?.invokeMethod<void>('setShowsUser', {'on': true});
      }
    });
    if (widget.start != null) _settled(_center, haptic: false);
  }

  @override
  void dispose() {
    _sheet.dispose();
    _native?.setMethodCallHandler(null);
    _ofmIdle?.cancel();
    _searchDebounce?.cancel();
    _query.dispose();
    _searchFocus.dispose();
    _ofm.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ the pin

  /// A search result's name survives the map's own flight to it; any move
  /// after that is the user's, and the name no longer applies.
  bool _keepName = false;

  void _startedMoving() {
    if (_moving) return;
    setState(() {
      _moving = true;
      if (!_keepName) _pickedName = null;
    });
  }

  /// The map came to rest: name the spot, and refresh what is nearby once it
  /// has moved a street or so.
  void _settled(LatLng at, {bool haptic = true}) {
    final wasMoving = _moving;
    _keepName = false;
    setState(() {
      _center = at;
      _moving = false;
      _address = LocationAddress.peek(at.latitude, at.longitude);
    });
    if (haptic && wasMoving) HapticFeedback.selectionClick();
    LocationAddress.lookup(at.latitude, at.longitude).then((r) {
      if (!mounted || _center != at) return;
      setState(() => _address = r);
    });
    final last = _nearbyAt;
    if (PlaceSearch.nearbySupported &&
        (last == null ||
            const Distance().as(LengthUnit.Meter, last, at) > 150)) {
      _nearbyAt = at;
      PlaceSearch.nearby(at.latitude, at.longitude).then((list) {
        if (mounted && _nearbyAt == at) setState(() => _nearby = list);
      });
    }
  }

  Future<dynamic> _fromNative(MethodCall call) async {
    switch (call.method) {
      case 'cameraMoving':
        _startedMoving();
      case 'cameraIdle':
        final args = call.arguments;
        if (args is Map) {
          final lat = args['latitude'];
          final lng = args['longitude'];
          if (lat is num && lng is num) {
            _settled(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
    }
    return null;
  }

  void _moveTo(LatLng to, {double spanMeters = 400}) {
    _native?.invokeMethod<void>('moveTo', {
      'latitude': to.latitude,
      'longitude': to.longitude,
      'spanMeters': spanMeters,
      'animated': true,
    });
    if (_ofmReady) {
      _ofm.move(
        to,
        OpenFreeMapSnapshot.zoomFor(
          latitude: to.latitude,
          spanMeters: spanMeters,
          widthPoints: MediaQuery.sizeOf(context).width,
        ),
      );
      _settled(to, haptic: false);
    }
  }

  Future<void> _goToMe() async {
    HapticFeedback.selectionClick();
    final fix =
        await LocationService.instance.lastKnownFix() ?? widget.start;
    if (fix == null || !mounted) return;
    _moveTo(LatLng(fix.latitude, fix.longitude), spanMeters: 500);
  }

  void _send(double lat, double lng) => _finish(
    LocationShareChoice.place((latitude: lat, longitude: lng)),
  );

  void _finish(LocationShareChoice choice) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(choice);
  }

  /// The pin is still on you (within a few metres of where the map opened).
  bool get _onMe {
    final start = widget.start;
    if (start == null) return false;
    return const Distance().as(
          LengthUnit.Meter,
          LatLng(start.latitude, start.longitude),
          _center,
        ) <
        25;
  }

  bool _liveOpen = false;

  /// The duration picked under "Share live location", waiting for the
  /// confirm button: a chip only chooses, so a wrong tap can be changed or
  /// the whole screen closed before anything starts.
  LiveShareDuration? _livePick;

  /// How far the panel sheet is pulled up, as a fraction of the screen; the
  /// locate button rides on its top edge.
  double _sheetExtent = _sheetRest;
  static const double _sheetRest = 0.4;
  final _sheet = DraggableScrollableController();

  // -------------------------------------------------------------- search

  void _onQuery() {
    final q = _query.text.trim();
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      if (_results != null) setState(() => _results = null);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final seq = ++_searchSeq;
      final found = await PlaceSearch.search(
        q,
        _center.latitude,
        _center.longitude,
      );
      if (mounted && seq == _searchSeq) setState(() => _results = found);
    });
  }

  void _pickResult(PlaceResult r) {
    HapticFeedback.selectionClick();
    _searchFocus.unfocus();
    _query.clear();
    // Keep the name the place was found by: the geocoder would only give its
    // street.
    _keepName = true;
    setState(() {
      _results = null;
      _pickedName = r.title;
    });
    _moveTo(LatLng(r.latitude, r.longitude), spanMeters: 350);
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final searching = _searchFocus.hasFocus || _results != null;
    final padding = MediaQuery.paddingOf(context);
    final height = MediaQuery.sizeOf(context).height;
    final topBar = padding.top + (PlaceSearch.searchSupported ? 112 : 66);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: theme.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _map(theme),
            IgnorePointer(child: _Pin(lifted: _moving, theme: theme)),
            if (!searching) ...[
              // On the sheet's top edge, and gone once the sheet covers the
              // map: there is nothing left to locate on.
              if (_sheetExtent < 0.6)
                Positioned(
                  right: 14,
                  bottom: _sheetExtent * height + 14,
                  child: _roundButton(
                    theme,
                    CupertinoIcons.location_fill,
                    l10n.locationPickerMyLocation,
                    _goToMe,
                  ),
                ),
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (n) {
                  if ((n.extent - _sheetExtent).abs() > 0.004) {
                    setState(() => _sheetExtent = n.extent);
                  }
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: _sheetRest,
                  minChildSize: 0.22,
                  maxChildSize: 1 - (topBar + 8) / height,
                  snap: true,
                  snapSizes: const [_sheetRest],
                  builder: (context, scroll) =>
                      _panel(theme, l10n, padding, scroll),
                ),
              ),
            ],
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _top(theme, l10n, padding),
            ),
            if (searching)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                top: topBar,
                child: _resultsPanel(theme, l10n),
              ),
          ],
        ),
      ),
    );
  }

  Widget _top(AppTheme theme, AppLocalizations l10n, EdgeInsets padding) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, padding.top + 6, 12, 10),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.97),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _roundButton(
                    theme,
                    CupertinoIcons.xmark,
                    CupertinoLocalizations.of(context).modalBarrierDismissLabel,
                    () => Navigator.of(context).maybePop(),
                    flat: true,
                  ),
                ),
                Text(
                  l10n.locationPickerTitle,
                  style: theme.body.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (PlaceSearch.searchSupported) ...[
            const SizedBox(height: 8),
            CupertinoSearchTextField(
              controller: _query,
              focusNode: _searchFocus,
              placeholder: l10n.locationPickerSearch,
              style: theme.body.copyWith(color: theme.ink, letterSpacing: 0),
              backgroundColor: theme.inkMuted.withValues(alpha: 0.12),
              onSubmitted: (_) => _onQuery(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _panel(
    AppTheme theme,
    AppLocalizations l10n,
    EdgeInsets padding,
    ScrollController scroll,
  ) {
    final accent = locationMapAccent(theme);
    final start = widget.start;
    final onMe = _onMe && !_moving;
    final address = _address;
    final street = address == null
        ? null
        : [address.title, address.subtitle]
              .where((s) => s.isNotEmpty)
              .join(', ');

    // The first row: you, or the spot under the pin.
    final Widget primary;
    if (onMe) {
      final acc = start!.accuracyM;
      primary = _row(
        theme,
        leading: _disc(accent, CupertinoIcons.location_fill),
        title: l10n.locationSheetSendCurrent,
        titleColor: accent,
        subtitle: [
          if (acc != null) l10n.locationPickerAccurate(acc.round()),
          ?street,
        ].join(' · '),
        onTap: () => _finish(const LocationShareChoice.now()),
      );
    } else {
      final String detail;
      if (_moving) {
        detail = l10n.locationPickerMoving;
      } else if (_pickedName != null) {
        detail = [
          _pickedName!,
          if (address != null && address.title.isNotEmpty) address.title,
        ].join(' · ');
      } else {
        detail =
            street ?? formatCoordinates(_center.latitude, _center.longitude);
      }
      primary = _row(
        theme,
        leading: _disc(accent, CupertinoIcons.paperplane_fill),
        title: l10n.locationPickerSendThis,
        titleColor: accent,
        subtitle: detail,
        onTap: _moving
            ? null
            : () => _send(_center.latitude, _center.longitude),
      );
    }

    final live = widget.allowLive && start != null;
    String durationLabel(LiveShareDuration d) => switch (d) {
      LiveShareDuration.fifteenMinutes => l10n.locationShareFor15Minutes,
      LiveShareDuration.oneHour => l10n.locationShareFor1Hour,
      LiveShareDuration.eightHours => l10n.locationShareFor8Hours,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 18),
        ],
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.only(bottom: padding.bottom + 12),
        children: [
          // The grab handle: the sheet is meant to be pulled up.
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 38,
              height: 5,
              decoration: BoxDecoration(
                color: theme.inkMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          primary,
          if (live) ...[
            _row(
              theme,
              leading: _disc(
                const Color(0xFF30B350),
                CupertinoIcons.dot_radiowaves_left_right,
              ),
              title: l10n.locationPickerShareLive,
              subtitle: l10n.locationSheetLiveDetail,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _liveOpen = !_liveOpen);
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_liveOpen
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(70, 2, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final d in LiveShareDuration.values)
                                _chip(
                                  theme,
                                  durationLabel(d),
                                  selected: _livePick == d,
                                  () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _livePick = d);
                                  },
                                ),
                            ],
                          ),
                          if (_livePick != null) ...[
                            const SizedBox(height: 10),
                            _startLive(theme, l10n, _livePick!),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
          if (PlaceSearch.nearbySupported) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(
                l10n.locationPickerNearby,
                style: theme.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.inkMuted,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (_nearby.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: CupertinoActivityIndicator(),
              )
            else
              for (final p in _nearby)
                _row(
                  theme,
                  leading: _placeIcon(theme),
                  title: p.title,
                  subtitle: p.subtitle,
                  onTap: () => _send(p.latitude, p.longitude),
                ),
          ],
        ],
      ),
    );
  }

  Widget _disc(Color color, IconData icon) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, size: 19, color: Colors.white),
  );

  /// Starts the live share for [d]. Its own button, after the chip, so the
  /// choice is confirmed rather than taken on the first tap.
  Widget _startLive(
    AppTheme theme,
    AppLocalizations l10n,
    LiveShareDuration d,
  ) {
    const green = Color(0xFF30B350);
    void go() => _finish(LocationShareChoice.live(d));
    return FocusableTap(
      onTap: go,
      shape: FocusRingShape.capsule,
      semanticLabel: l10n.locationPickerShareLive,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: go,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.dot_radiowaves_left_right,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.locationPickerShareLive,
                style: theme.body.copyWith(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    AppTheme theme,
    String label,
    VoidCallback onTap, {
    bool selected = false,
  }) {
    const green = Color(0xFF30B350);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.capsule,
      semanticLabel: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: green.withValues(alpha: selected ? 0.3 : 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? green : const Color(0x00000000),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: theme.body.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: green,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultsPanel(AppTheme theme, AppLocalizations l10n) {
    final results = _results;
    return Container(
      color: theme.surface,
      child: results == null
          ? const SizedBox.shrink()
          : results.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Text(
                l10n.locationPickerNoResults,
                textAlign: TextAlign.center,
                style: theme.body.copyWith(
                  color: theme.inkMuted,
                  letterSpacing: 0,
                ),
              ),
            )
          : ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(top: 6),
              itemCount: results.length,
              itemBuilder: (_, i) {
                final r = results[i];
                return _row(
                  theme,
                  leading: _placeIcon(theme),
                  title: r.title,
                  subtitle: r.subtitle,
                  onTap: () => _pickResult(r),
                );
              },
            ),
    );
  }

  Widget _placeIcon(AppTheme theme) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: theme.inkMuted.withValues(alpha: 0.14),
      shape: BoxShape.circle,
    ),
    child: Icon(CupertinoIcons.placemark_fill, size: 19, color: theme.ink),
  );

  Widget _row(
    AppTheme theme, {
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? titleColor,
  }) => FocusableTap(
    onTap: onTap,
    semanticLabel: '$title, $subtitle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.body.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? theme.ink,
                      letterSpacing: 0,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.body.copyWith(
                        fontSize: 13,
                        color: theme.inkMuted,
                        letterSpacing: 0,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _roundButton(
    AppTheme theme,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool flat = false,
  }) => FocusableTap(
    onTap: onTap,
    shape: FocusRingShape.capsule,
    semanticLabel: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: flat
              ? theme.inkMuted.withValues(alpha: 0.14)
              : theme.surface.withValues(alpha: 0.97),
          shape: BoxShape.circle,
          boxShadow: flat
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
        ),
        child: Icon(
          icon,
          size: 19,
          color: flat ? theme.ink : locationMapAccent(theme),
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------- maps

  Widget _map(AppTheme theme) {
    final engine = _engine;
    if (engine == null) return const SizedBox.expand();
    final dark = theme.background.computeLuminance() < 0.4;
    final params = <String, Object?>{
      'latitude': _center.latitude,
      'longitude': _center.longitude,
      'spanMeters': _startSpan,
      'dark': dark,
      'picker': true,
      'showsUser': _meAllowed,
      'mapType': switch (SettingsStore.instance.mapStyle) {
        MapStyle.map => 'standard',
        MapStyle.hybrid => 'hybrid',
        MapStyle.satellite => 'satellite',
      },
    };
    void created(int id) {
      final channel = MethodChannel('monkeyhub/map_view_$id');
      channel.setMethodCallHandler(_fromNative);
      _native = channel;
    }

    const viewType = 'monkeyhub/map_view';
    final gestures = <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
    };
    switch (engine) {
      case MapEngine.appleMaps:
        if (Caps.macOS) {
          return AppKitView(
            viewType: viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: created,
            gestureRecognizers: gestures,
          );
        }
        return UiKitView(
          viewType: viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: created,
          gestureRecognizers: gestures,
        );
      case MapEngine.googleMaps:
        return AndroidView(
          viewType: viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: created,
          gestureRecognizers: gestures,
        );
      case MapEngine.openFreeMap:
        return FlutterMap(
          mapController: _ofm,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: OpenFreeMapSnapshot.zoomFor(
              latitude: _center.latitude,
              spanMeters: _startSpan,
              widthPoints: MediaQuery.sizeOf(context).width,
            ),
            minZoom: 2,
            maxZoom: 20,
            backgroundColor: SettingsStore.instance.ofmStyle.isDark
                ? const Color(0xFF0C0C0C)
                : const Color(0xFFF8F4F0),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () => _ofmReady = true,
            onPositionChanged: (camera, hasGesture) {
              if (!hasGesture) return;
              _startedMoving();
              _ofmIdle?.cancel();
              _ofmIdle = Timer(
                const Duration(milliseconds: 250),
                () => _settled(camera.center),
              );
            },
          ),
          children: [
            TileLayer(
              tileProvider: OpenFreeMapTileProvider(
                styleName: OpenFreeMapSnapshot.currentStyle,
                scale: MediaQuery.devicePixelRatioOf(context),
              ),
              maxNativeZoom: 20,
              maxZoom: 20,
              errorTileCallback: (_, _, _) {},
              userAgentPackageName: 'app.monkeyhub',
            ),
          ],
        );
    }
  }
}

/// The pin fixed at the centre of the map. Its tip is the exact point. It
/// lifts off the map while the map moves (its shadow stays behind and
/// spreads) and lands when the map stops.
class _Pin extends StatelessWidget {
  const _Pin({required this.lifted, required this.theme});

  final bool lifted;
  final AppTheme theme;

  static const double _head = 30;
  static const double _stem = 14;

  @override
  Widget build(BuildContext context) {
    final accent = locationMapAccent(theme);
    final lift = lifted ? 12.0 : 0.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cx = c.maxWidth / 2;
        final cy = c.maxHeight / 2;
        return Stack(
          children: [
            // The shadow, on the ground at the point.
            Positioned(
              left: cx - 9,
              top: cy - 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 18,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: Colors.black.withValues(alpha: lifted ? 0.18 : 0.32),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: lifted ? Curves.easeOutBack : Curves.easeOutCubic,
              left: cx - _head / 2,
              top: cy - _head - _stem - lift,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _head,
                    height: _head,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Container(
                    width: 2.5,
                    height: _stem,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
