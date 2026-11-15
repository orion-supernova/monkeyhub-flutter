import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/location_share.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/caps.dart';
import '../widgets/location_map_preview.dart';
import '../widgets/map_engine.dart';
import '../widgets/message_stamp.dart';
import '../widgets/open_free_map_snapshot.dart';
import '../widgets/open_free_map_tiles.dart';
import '../widgets/viewer_chrome.dart';

/// A shared location, full screen and movable, opened by tapping its bubble.
///
/// The map comes from the same [MapEngine] as the bubble's picture: a native
/// MapKit view on iOS and macOS, a native Google map on Android (both platform
/// views, `MapViewFactory.swift` / `MapViewFactory.kt`), or OpenFreeMap tiles
/// in `flutter_map` everywhere else.
///
/// Live shares move here by themselves. [share] is fed by the bubble every
/// time the message updates, and each new fix moves the marker; the camera
/// follows it until the viewer pans away, and the locate button brings it
/// back. That is the fix for having to tap "Open in maps" again for every
/// update: a maps app only ever gets one fixed coordinate.
class LocationMapScreen extends StatefulWidget {
  const LocationMapScreen({
    super.key,
    required this.share,
    required this.onOpenInMaps,
    required this.clock,
    this.title,
  });

  final ValueListenable<LocationShare> share;
  /// Hands the location to a maps app. Given this screen's context so the
  /// app picker sheet opens above the map, not under it.
  final Future<void> Function(BuildContext context) onOpenInMaps;
  final DateTime Function() clock;

  /// Who shared it; the bar's title.
  final String? title;

  static Future<void> open(
    BuildContext context, {
    required ValueListenable<LocationShare> share,
    required Future<void> Function(BuildContext context) onOpenInMaps,
    required DateTime Function() clock,
    String? title,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => LocationMapScreen(
          share: share,
          onOpenInMaps: onOpenInMaps,
          clock: clock,
          title: title,
        ),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  MapEngine? _engine;
  MethodChannel? _native;
  final _ofm = MapController();
  bool _ofmReady = false;

  /// The camera follows a live share until the viewer moves the map.
  bool _follow = true;

  Timer? _tick;
  late DateTime _now = widget.clock();
  late LocationShare _shown = widget.share.value;

  /// Wide enough to see the streets around the point, and the reported
  /// accuracy ring when there is one.
  late final double _spanMeters = (spanMetersFor(_shown.accuracyM) * 2.5)
      .clamp(600.0, 12000.0);

  @override
  void initState() {
    super.initState();
    widget.share.addListener(_moved);
    final known = MapEngines.current;
    if (known != null) {
      _engine = known;
    } else {
      MapEngines.resolve().then((e) {
        if (mounted) setState(() => _engine = e);
      });
    }
    _syncTick();
  }

  @override
  void dispose() {
    widget.share.removeListener(_moved);
    _tick?.cancel();
    _ofm.dispose();
    super.dispose();
  }

  void _syncTick() {
    final live = _shown.stateAt(widget.clock()) == LiveShareState.live;
    if (live) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _now = widget.clock());
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _moved() {
    final next = widget.share.value;
    if (next.latitude == _shown.latitude &&
        next.longitude == _shown.longitude &&
        next.accuracyM == _shown.accuracyM) {
      setState(() => _shown = next); // Times only (updated / ended).
      _syncTick();
      return;
    }
    setState(() => _shown = next);
    _syncTick();
    _native?.invokeMethod<void>('update', {
      'latitude': next.latitude,
      'longitude': next.longitude,
      'accuracyM': next.accuracyM,
      'follow': _follow,
    });
    if (_ofmReady && _follow) {
      _ofm.move(LatLng(next.latitude, next.longitude), _ofm.camera.zoom);
    }
  }

  void _recenter() {
    HapticFeedback.selectionClick();
    setState(() => _follow = true);
    _native?.invokeMethod<void>('recenter');
    if (_ofmReady) {
      _ofm.move(LatLng(_shown.latitude, _shown.longitude), _initialZoom);
    }
  }

  /// The zoom at which [_spanMeters] fills roughly a phone's width.
  double get _initialZoom => OpenFreeMapSnapshot.zoomFor(
    latitude: _shown.latitude,
    spanMeters: _spanMeters,
    widthPoints: 390,
  );

  bool _dark(AppTheme theme) => theme.background.computeLuminance() < 0.4;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final state = _shown.stateAt(_now);

    return ColoredBox(
      color: theme.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Any touch on the map stops the camera chasing a live share; the
          // locate button turns it back on. A Listener sees pointers without
          // taking them from the map's own gestures.
          Listener(
            onPointerDown: (_) {
              if (_follow) setState(() => _follow = false);
            },
            child: _map(theme),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ViewerTopBar(
              band: true,
              onClose: () => Navigator.of(context).maybePop(),
              title: widget.title,
              subtitle: _status(l10n, state),
              actions: [
                ViewerChromeButton(
                  icon: _follow
                      ? CupertinoIcons.location_fill
                      : CupertinoIcons.location,
                  semanticLabel: l10n.locationMapRecenter,
                  onTap: _recenter,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: Center(child: _openButton(theme, l10n)),
            ),
          ),
        ],
      ),
    );
  }

  String _status(AppLocalizations l10n, LiveShareState state) {
    final acc = _shown.accuracyM;
    final where = acc == null
        ? formatCoordinates(_shown.latitude, _shown.longitude)
        : '${formatCoordinates(_shown.latitude, _shown.longitude)}  '
              '${l10n.locationBubbleAccuracy(acc.round())}';
    switch (state) {
      case LiveShareState.live:
        final until = l10n.locationBubbleLiveUntil(
          formatClockTime(_shown.liveExpiresAt!),
        );
        return _shown.isStaleAt(_now)
            ? '$until · ${l10n.locationBubbleNoRecentUpdate}'
            : until;
      case LiveShareState.ended:
        return l10n.locationBubbleLiveEnded(
          formatClockTime(_shown.liveEndedAt ?? _shown.liveExpiresAt!),
        );
      case LiveShareState.fixed:
        return where;
    }
  }

  Widget _openButton(AppTheme theme, AppLocalizations l10n) {
    final label = l10n.locationBubbleOpenInMaps;
    void open() {
      HapticFeedback.lightImpact();
      widget.onOpenInMaps(context);
    }

    return FocusableTap(
      onTap: open,
      shape: FocusRingShape.capsule,
      semanticLabel: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: locationMapAccent(theme),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.map_fill,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                CupertinoIcons.arrow_up_right,
                size: 13,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _map(AppTheme theme) {
    final engine = _engine;
    if (engine == null) return const SizedBox.expand();
    final dark = _dark(theme);
    final params = <String, Object?>{
      'latitude': _shown.latitude,
      'longitude': _shown.longitude,
      'accuracyM': _shown.accuracyM,
      'spanMeters': _spanMeters,
      'dark': dark,
    };
    void created(int id) {
      _native = MethodChannel('monkeyhub/map_view_$id');
    }

    const viewType = 'monkeyhub/map_view';
    // Platform views get every gesture: the map is the whole screen, and the
    // only Flutter chrome over it is buttons.
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
        return _openFreeMap(theme, dark);
    }
  }

  Widget _openFreeMap(AppTheme theme, bool dark) {
    final point = LatLng(_shown.latitude, _shown.longitude);
    final accent = locationMapAccent(theme);
    final acc = _shown.accuracyM;
    final ended = _shown.stateAt(_now) == LiveShareState.ended;
    return FlutterMap(
      mapController: _ofm,
      options: MapOptions(
        initialCenter: point,
        initialZoom: _initialZoom,
        minZoom: 2,
        maxZoom: 20,
        backgroundColor: dark
            ? const Color(0xFF0C0C0C)
            : const Color(0xFFF8F4F0),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _ofmReady = true,
      ),
      children: [
        TileLayer(
          tileProvider: OpenFreeMapTileProvider(
            dark: dark,
            scale: MediaQuery.devicePixelRatioOf(context),
          ),
          maxNativeZoom: 20,
          maxZoom: 20,
          // A tile that failed (offline, OpenFreeMap down) is simply absent;
          // the next pan asks again. Nothing to log per tile.
          errorTileCallback: (_, _, _) {},
          // OpenFreeMap asks clients to identify themselves generically; no
          // user details, ever.
          userAgentPackageName: 'app.monkeyhub',
        ),
        if (acc != null && acc > 0)
          CircleLayer(
            circles: [
              CircleMarker(
                point: point,
                radius: acc,
                useRadiusInMeter: true,
                color: accent.withValues(alpha: 0.12),
                borderColor: accent.withValues(alpha: 0.35),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 26,
              height: 26,
              child: _Dot(
                color: ended ? theme.inkMuted : accent,
                ring: theme.surface,
                hollow: ended,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Text(
                OpenFreeMapSnapshot.attribution,
                style: TextStyle(
                  inherit: false,
                  fontSize: 10,
                  color: dark
                      ? const Color(0x99FFFFFF)
                      : const Color(0x8C000000),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The bubble's marker, at full-screen size.
class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.ring, required this.hollow});

  final Color color;
  final Color ring;
  final bool hollow;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: ring.withValues(alpha: 0.95),
      border: Border.all(color: color, width: 2.2),
      boxShadow: const [
        BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    alignment: Alignment.center,
    child: hollow
        ? null
        : Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
  );
}
