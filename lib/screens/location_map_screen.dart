import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors, Material, MaterialType;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/location_share.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../ui/foundation/caps.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/app_toast.dart';
import '../widgets/ios_kit.dart';
import '../widgets/location_address.dart';
import '../widgets/location_map_preview.dart';
import '../widgets/location_map_snapshot.dart';
import '../widgets/location_pin.dart';
import '../widgets/map_engine.dart';
import '../widgets/message_stamp.dart';
import '../widgets/open_free_map_snapshot.dart';
import '../widgets/open_free_map_tiles.dart';
import '../widgets/settings_pickers.dart' show GroupedFooter;
import '../widgets/sheet_kit.dart';
import '../widgets/user_avatar.dart';
import '../widgets/viewer_chrome.dart';

/// What the bubble hands the full-screen map: where it flies from and the
/// picture it already shows, so the opening is one continuous motion.
class LocationMapOrigin {
  const LocationMapOrigin({
    required this.rect,
    required this.radius,
    required this.spanMeters,
    this.picture,
  });

  /// The bubble's map card, in global coordinates.
  final Rect rect;
  final double radius;

  /// How many metres the card's width covers. The full-screen map opens at
  /// the same scale, so the picture that flies up lands on the same streets.
  final double spanMeters;
  final MapPicture? picture;
}

/// A shared location, full screen, opened by tapping its bubble.
///
/// Grows out of the bubble's map card (the card's own picture flies to full
/// width at the same scale, then the live map fades in under it), and goes
/// back into it on close.
///
/// The map is the same [MapEngine] as the card: a native MapKit view on iOS
/// and macOS, a native Google map on Android (`MapViewFactory.swift` /
/// `.kt`), or OpenFreeMap tiles in `flutter_map`. On it: the sharer's face
/// with their name, the accuracy ring, and for a live share the path walked
/// since the map opened. Around it: the address, map type / traffic / my
/// location settings, "show us both", and a card with the person, their
/// distance from you, the time left, Directions, Share, Copy, and Stop
/// sharing on your own share.
///
/// Live shares move by themselves: [share] is fed by the bubble on every
/// message update and each fix glides the face to its new spot. The camera
/// follows until the viewer moves the map; the locate button resumes it.
class LocationMapScreen extends StatefulWidget {
  const LocationMapScreen({
    super.key,
    required this.share,
    required this.onOpenInMaps,
    required this.clock,
    this.name,
    this.author,
    this.api,
    this.isMine = false,
    this.onStopSharing,
    this.origin,
    this.initialTrail = const [],
  });

  final ValueListenable<LocationShare> share;

  /// Hands the location to a maps app. Given this screen's context so the
  /// app picker opens above the map.
  final Future<void> Function(BuildContext context) onOpenInMaps;
  final DateTime Function() clock;

  /// The sharer's display name.
  final String? name;
  final ChatUser? author;
  final ChatApi? api;
  final bool isMine;

  /// Present only on the share this device is publishing right now.
  final Future<void> Function()? onStopSharing;
  final LocationMapOrigin? origin;

  /// Positions the bubble already saw this share pass through.
  final List<LatLng> initialTrail;

  static Future<void> open(
    BuildContext context, {
    required ValueListenable<LocationShare> share,
    required Future<void> Function(BuildContext context) onOpenInMaps,
    required DateTime Function() clock,
    String? name,
    ChatUser? author,
    ChatApi? api,
    bool isMine = false,
    Future<void> Function()? onStopSharing,
    LocationMapOrigin? origin,
    List<LatLng> initialTrail = const [],
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        // Opening is the screen's own animation (it waits for the live map
        // to draw first); closing runs on the route's.
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 300),
        // The screen draws its own flight from these animations.
        transitionsBuilder: (_, _, _, child) => child,
        pageBuilder: (_, _, _) => LocationMapScreen(
          share: share,
          onOpenInMaps: onOpenInMaps,
          clock: clock,
          name: name,
          author: author,
          api: api,
          isMine: isMine,
          onStopSharing: onStopSharing,
          origin: origin,
          initialTrail: initialTrail,
        ),
      ),
    );
  }

  @override
  State<LocationMapScreen> createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen>
    with SingleTickerProviderStateMixin {
  MapEngine? _engine;
  MethodChannel? _native;
  final _ofm = MapController();
  bool _ofmReady = false;

  /// The live map has drawn; the flying picture can step aside.
  bool _mapReady = false;

  /// The opening flight. Started once the live map has drawn (or after a
  /// short wait at most), so what grows out of the card is the real map, not
  /// a picture with a blank screen around it.
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 440),
  );
  Timer? _openFallback;

  void _startFlight() {
    _openFallback?.cancel();
    if (!_open.isAnimating && _open.value == 0) _open.forward();
  }

  /// The camera follows a live share until the viewer moves the map.
  bool _follow = true;

  LocationPinImage? _pin;
  bool _pinTried = false;

  bool _pinEnded = false;

  LocationShare? _geocodedAt;

  LocationFix? _me;
  bool _meAllowed = false;

  late final List<LatLng> _trail = [...widget.initialTrail];
  Timer? _tick;
  Timer? _readyFallback;
  late DateTime _now = widget.clock();
  late LocationShare _shown = widget.share.value;
  late ({String title, String subtitle})? _address = LocationAddress.peek(
    _shown.latitude,
    _shown.longitude,
  );
  bool _stopping = false;

  late final double _spanMeters =
      widget.origin?.spanMeters ??
      (spanMetersFor(_shown.accuracyM) * 2.5).clamp(600.0, 12000.0);

  bool get _live => _shown.stateAt(_now) == LiveShareState.live;
  bool get _ended => _shown.stateAt(_now) == LiveShareState.ended;
  bool get _systemMaps =>
      _engine == MapEngine.appleMaps || _engine == MapEngine.googleMaps;

  @override
  void initState() {
    super.initState();
    widget.share.addListener(_moved);
    SettingsStore.instance.addListener(_settingsChanged);
    if (_live) _addTrail(_shown);
    final known = MapEngines.current;
    if (known != null) {
      _engine = known;
    } else {
      MapEngines.resolve().then((e) {
        if (mounted) setState(() => _engine = e);
      });
    }
    _syncTick();
    _geocode();
    _locateMe();
    // A map that never says it drew still has to show eventually.
    _readyFallback = Timer(const Duration(milliseconds: 2500), _markReady);
    // With no card to grow from there is nothing to wait for; with one, the
    // card holds for the live map at most this long.
    if (widget.origin == null) {
      _open.value = 1;
    } else {
      _openFallback = Timer(const Duration(milliseconds: 450), _startFlight);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pinTried) {
      _pinTried = true;
      _renderPin();
    }
  }

  @override
  void dispose() {
    widget.share.removeListener(_moved);
    SettingsStore.instance.removeListener(_settingsChanged);
    _native?.setMethodCallHandler(null);
    _tick?.cancel();
    _readyFallback?.cancel();
    _openFallback?.cancel();
    _open.dispose();
    _ofm.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  void _syncTick() {
    if (_live) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final wasLive = _live;
        setState(() => _now = widget.clock());
        if (wasLive && !_live) _onEnded();
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  void _onEnded() {
    _syncTick();
    if (!_pinEnded) _renderPin();
  }

  void _addTrail(LocationShare s) {
    final p = LatLng(s.latitude, s.longitude);
    if (_trail.isNotEmpty &&
        _trail.last.latitude == p.latitude &&
        _trail.last.longitude == p.longitude) {
      return;
    }
    _trail.add(p);
    if (_trail.length > 400) _trail.removeAt(0);
  }

  List<List<double>> get _trailArgs => [
    for (final p in _trail) [p.latitude, p.longitude],
  ];

  void _moved() {
    final next = widget.share.value;
    final moved =
        next.latitude != _shown.latitude ||
        next.longitude != _shown.longitude ||
        next.accuracyM != _shown.accuracyM;
    final wasLive = _live;
    setState(() {
      _shown = next;
      _now = widget.clock();
    });
    if (wasLive && !_live) _onEnded();
    _syncTick();
    if (!moved) return;
    if (_live) _addTrail(next);
    _native?.invokeMethod<void>('update', {
      'latitude': next.latitude,
      'longitude': next.longitude,
      'accuracyM': next.accuracyM,
      'follow': _follow,
      'trail': _trailArgs,
    });
    if (_ofmReady && _follow) {
      _ofm.move(LatLng(next.latitude, next.longitude), _ofm.camera.zoom);
    }
    _geocode();
  }

  Future<void> _renderPin() async {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final scale = MediaQuery.devicePixelRatioOf(context);
    final name = widget.name ?? widget.author?.displayName ?? '';
    final ended = _ended;
    final pin = await LocationPinImage.render(
      theme: theme,
      label: widget.isMine
          ? (name.isEmpty ? l10n.locationMapYou : l10n.locationMapNameYou(name))
          : name,
      user: widget.author,
      api: widget.api,
      ring: ended ? theme.inkMuted : locationMapAccent(theme),
      scale: scale,
    );
    if (!mounted) return;
    setState(() {
      _pin = pin ?? _pin;
      _pinEnded = ended;
    });
    if (pin != null) {
      _native?.invokeMethod<void>('update', {
        'latitude': _shown.latitude,
        'longitude': _shown.longitude,
        'accuracyM': _shown.accuracyM,
        'follow': false,
        ..._pinArgs(pin),
      });
    }
  }

  Map<String, Object?> _pinArgs(LocationPinImage? pin) => pin == null
      ? const {}
      : {'pinImage': pin.png, 'pinScale': pin.scale, 'pinAnchorY': pin.anchorY};

  /// The street name over the map, from the shared OS-geocoder cache; asked
  /// again only once a live share has moved a block or so.
  Future<void> _geocode() async {
    final at = _shown;
    final last = _geocodedAt;
    if (last != null &&
        at.distanceMetersTo(last.latitude, last.longitude) < 120) {
      return;
    }
    _geocodedAt = at;
    final r = await LocationAddress.lookup(at.latitude, at.longitude);
    if (mounted && r != null) setState(() => _address = r);
  }

  /// Your own position, for the distance line and the "both of us" view.
  /// Only when location is already allowed: opening a map never prompts.
  Future<void> _locateMe() async {
    if (!SettingsStore.instance.mapShowMe || widget.isMine) return;
    final service = LocationService.instance;
    try {
      if (await service.check() != LocationAvailability.ready) return;
      if (!mounted) return;
      setState(() => _meAllowed = true);
      _native?.invokeMethod<void>('setShowsUser', {'on': true});
      final quick = await service.lastKnownFix();
      if (mounted && quick != null) setState(() => _me = quick);
      final fresh = await service.currentFix();
      if (mounted && fresh != null) setState(() => _me = fresh);
    } catch (_) {}
  }

  void _settingsChanged() {
    final s = SettingsStore.instance;
    _native?.invokeMethod<void>('setMapType', {'type': _typeName(s.mapStyle)});
    _native?.invokeMethod<void>('setTraffic', {'on': s.mapTraffic});
    _native?.invokeMethod<void>('setShowsUser', {
      'on': s.mapShowMe && _meAllowed,
    });
    if (mounted) setState(() {});
  }

  static String _typeName(MapStyle s) => switch (s) {
    MapStyle.map => 'standard',
    MapStyle.hybrid => 'hybrid',
    MapStyle.satellite => 'satellite',
  };

  void _markReady() {
    _readyFallback?.cancel();
    if (mounted && !_mapReady) setState(() => _mapReady = true);
    if (mounted) _startFlight();
  }

  Future<dynamic> _fromNative(MethodCall call) async {
    switch (call.method) {
      case 'ready':
        _markReady();
      case 'gesture':
        if (_follow && mounted) setState(() => _follow = false);
    }
    return null;
  }

  // ------------------------------------------------------------- actions

  void _recenter() {
    HapticFeedback.selectionClick();
    setState(() => _follow = true);
    _native?.invokeMethod<void>('recenter');
    if (_ofmReady) {
      _ofm.move(LatLng(_shown.latitude, _shown.longitude), _initialZoom);
    }
  }

  void _showBoth() {
    final me = _me;
    if (me == null) return _recenter();
    HapticFeedback.selectionClick();
    setState(() => _follow = false);
    _native?.invokeMethod<void>('showBoth');
    if (_ofmReady) {
      _ofm.fitCamera(
        CameraFit.coordinates(
          coordinates: [
            LatLng(_shown.latitude, _shown.longitude),
            LatLng(me.latitude, me.longitude),
          ],
          padding: const EdgeInsets.fromLTRB(60, 160, 60, 280),
          maxZoom: 17,
        ),
      );
    }
  }

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    final lat = _shown.latitude.toStringAsFixed(6);
    final lng = _shown.longitude.toStringAsFixed(6);
    final url = Caps.nativeApple
        ? 'https://maps.apple.com/?ll=$lat,$lng&q=$lat,$lng'
        : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final name = widget.name;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: name == null || name.isEmpty ? url : '$name\n$url',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  void _copy() {
    HapticFeedback.selectionClick();
    Clipboard.setData(
      ClipboardData(text: formatCoordinates(_shown.latitude, _shown.longitude)),
    );
    AppToast.of(
      context,
    ).show(AppLocalizations.of(context).locationBubbleCoordinatesCopied);
  }

  Future<void> _stop() async {
    final stop = widget.onStopSharing;
    if (stop == null || _stopping) return;
    HapticFeedback.mediumImpact();
    setState(() => _stopping = true);
    try {
      await stop();
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  Future<void> _openSettings() async {
    HapticFeedback.selectionClick();
    await showAdaptiveSheet<void>(
      context,
      useRootNavigator: true,
      builder: (_) => _MapSettingsSheet(
        systemMaps: _systemMaps,
        onShowMe: (on) async {
          if (on && !_meAllowed) {
            final ok =
                await LocationService.instance.ensureAvailable() ==
                LocationAvailability.ready;
            if (!ok) return;
          }
          await SettingsStore.instance.setMapShowMe(on);
          if (on) _locateMe();
        },
      ),
    );
  }

  double get _initialZoom => OpenFreeMapSnapshot.zoomFor(
    latitude: _shown.latitude,
    spanMeters: _spanMeters,
    widthPoints: MediaQuery.sizeOf(context).width,
  );

  bool _dark(AppTheme theme) => theme.background.computeLuminance() < 0.4;

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final route = ModalRoute.of(context)?.animation;
    // Out: the screen's own controller (it waits for the live map). Back:
    // the route's reverse. Their product is one 0..1 flight either way.
    final opening = CurvedAnimation(
      parent: _open,
      curve: Curves.easeInOutCubicEmphasized,
    );
    final closing = route == null
        ? const AlwaysStoppedAnimation(1.0)
        : CurvedAnimation(
            parent: route,
            curve: Curves.linear,
            reverseCurve: Curves.easeInOutCubic,
          );
    final flight = _FlightProduct(opening, closing);
    final screen = MediaQuery.sizeOf(context);
    // Built once per frame of the flight, not per animation tick of the
    // contents: the map itself never rebuilds while it flies.
    final map = Listener(
      onPointerDown: (_) {
        if (_follow && _engine == MapEngine.openFreeMap) {
          setState(() => _follow = false);
        }
      },
      child: _map(theme),
    );

    return Material(
      // Gives the card's text a style to inherit; without one Flutter draws
      // its debug underline.
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: flight,
        builder: (context, _) {
          final t = flight.value.clamp(0.0, 1.0);
          final settled =
              (route == null || route.status == AnimationStatus.completed) &&
              _open.isCompleted;
          final chrome = const Interval(0.6, 1).transform(t);
          return Stack(
            fit: StackFit.expand,
            children: [
              _flight(theme, screen, t, settled, map),
              Opacity(
                opacity: chrome,
                child: IgnorePointer(
                  ignoring: !settled,
                  child: _chrome(theme, chrome),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// A container transform out of the bubble's card.
  ///
  /// The whole full-screen map (live map, with the card's own picture over
  /// its middle until the live one has drawn) starts life shrunk to the card:
  /// same rectangle, same corners, same metres per point, so frame one IS the
  /// card. It then grows to the screen while the clip opens with it. Nothing
  /// swaps or pops mid-flight; the picture only steps aside once settled and
  /// the live map has drawn, and comes back for the trip home.
  Widget _flight(
    AppTheme theme,
    Size screen,
    double t,
    bool settled,
    Widget map,
  ) {
    final origin = widget.origin;
    final full = Offset.zero & screen;
    final content = SizedBox.fromSize(
      size: screen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: theme.background),
          map,
          _picture(screen, settled, t),
        ],
      ),
    );
    if (origin == null) {
      // Nothing to grow from (opened without a card): a quiet fade and lift.
      return Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.96 + 0.04 * t, child: content),
      );
    }
    final clip = Rect.lerp(origin.rect, full, t)!;
    final scale = _lerp(origin.rect.width / screen.width, 1, t);
    final radius = _lerp(origin.radius, _screenRadius, t);
    final centre = screen.center(Offset.zero);
    final matrix = Matrix4.identity()
      ..translateByDouble(clip.center.dx, clip.center.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-centre.dx, -centre.dy, 0, 1);
    return ClipRRect(
      clipper: _RectClip(clip, radius),
      child: Transform(transform: matrix, child: content),
    );
  }

  /// Square at the end: the map lands as the screen itself.
  static const double _screenRadius = 0;

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// The card's picture, at full width and the card's aspect, centred where
  /// the live map puts the point: identical to the card at frame one, and to
  /// the live map underneath once it has drawn.
  Widget _picture(Size screen, bool settled, double t) {
    final picture = widget.origin?.picture;
    final origin = widget.origin;
    if (origin == null || picture == null) return const SizedBox.shrink();
    final aspect = origin.rect.height / origin.rect.width;
    // In flight, once the live map has drawn, the picture hands over to it
    // while both are moving (the eye does not catch a crossfade mid-motion),
    // and takes over again as the map lands back on the card. Settled, it is
    // simply gone, or still covering a map that has not drawn yet.
    final double opacity;
    if (!_mapReady) {
      opacity = 1;
    } else if (settled) {
      opacity = 0;
    } else {
      opacity = 1 - const Interval(0.2, 0.7).transform(t);
    }
    return Center(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: opacity,
          // Instant while the flight drives it frame by frame; a short fade
          // only for a map that draws after it has landed.
          duration: Duration(milliseconds: settled ? 220 : 0),
          curve: Curves.easeOut,
          child: SizedBox(
            width: screen.width,
            height: screen.width * aspect,
            child: Image(
              image: picture.image,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chrome(AppTheme theme, double t) {
    final l10n = AppLocalizations.of(context);
    final address = _address;
    final String title;
    final String? subtitle;
    if (_live || _ended) {
      title = l10n.locationMapTitleLive;
      subtitle = address == null
          ? null
          : [
              address.title,
              address.subtitle,
            ].where((s) => s.isNotEmpty).join(', ');
    } else {
      title = (address?.title.isNotEmpty ?? false)
          ? address!.title
          : l10n.locationMapTitlePinned;
      subtitle = address?.subtitle;
    }
    final slide = (1 - t) * 24;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -slide,
          left: 0,
          right: 0,
          child: ViewerTopBar(
            band: true,
            onClose: () => Navigator.of(context).maybePop(),
            title: title,
            subtitle: subtitle,
          ),
        ),
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + 64,
          child: _controls(theme, l10n),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -slide,
          child: _card(theme, l10n),
        ),
      ],
    );
  }

  Widget _controls(AppTheme theme, AppLocalizations l10n) {
    Widget button(IconData icon, String label, VoidCallback onTap) =>
        FocusableTap(
          onTap: onTap,
          semanticLabel: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(icon, size: 21, color: locationMapAccent(theme)),
            ),
          ),
        );
    final divider = Container(
      width: 30,
      height: 0.6,
      color: theme.inkMuted.withValues(alpha: 0.25),
    );
    return Container(
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            CupertinoIcons.square_stack_3d_up,
            l10n.locationMapSettings,
            _openSettings,
          ),
          divider,
          button(
            _follow ? CupertinoIcons.location_fill : CupertinoIcons.location,
            l10n.locationMapRecenter,
            _recenter,
          ),
          if (_me != null) ...[
            divider,
            button(
              CupertinoIcons.person_2_fill,
              l10n.locationMapShowBoth,
              _showBoth,
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(AppTheme theme, AppLocalizations l10n) {
    final name = widget.isMine
        ? l10n.locationMapYou
        : (widget.name ?? widget.author?.displayName ?? '');
    final lines = <({String text, bool warn})>[];
    if (_live) {
      lines.add((
        text: l10n.locationBubbleLiveUntil(
          formatClockTime(_shown.liveExpiresAt!),
        ),
        warn: false,
      ));
      if (_shown.isStaleAt(_now)) {
        lines.add((text: l10n.locationBubbleNoRecentUpdate, warn: true));
      }
    } else if (_ended) {
      lines.add((
        text: l10n.locationBubbleLiveEnded(
          formatClockTime(_shown.liveEndedAt ?? _shown.liveExpiresAt!),
        ),
        warn: false,
      ));
    }
    final detail = <String>[];
    final me = _me;
    if (me != null) {
      detail.add(
        l10n.locationMapAway(
          _distance(_shown.distanceMetersTo(me.latitude, me.longitude)),
        ),
      );
    }
    final updated = _shown.liveUpdatedAt;
    if (_live && updated != null && !_shown.isStaleAt(_now)) {
      detail.add(l10n.locationMapUpdatedAt(formatClockTime(updated)));
    }
    if (!_live && !_ended) {
      final acc = _shown.accuracyM;
      detail.add(
        acc == null
            ? formatCoordinates(_shown.latitude, _shown.longitude)
            : '${formatCoordinates(_shown.latitude, _shown.longitude)}  '
                  '${l10n.locationBubbleAccuracy(acc.round())}',
      );
    }
    if (detail.isNotEmpty) lines.add((text: detail.join(' · '), warn: false));

    final muted = theme.inkMuted;
    final user = widget.author;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (user != null)
                  UserAvatar(
                    user: user,
                    api: widget.api,
                    size: 46,
                    showStatus: false,
                    ring: true,
                    ringColor: _ended ? muted : locationMapAccent(theme),
                  )
                else
                  Icon(
                    CupertinoIcons.location_solid,
                    size: 30,
                    color: locationMapAccent(theme),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.body.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.ink,
                          letterSpacing: 0,
                        ),
                      ),
                      for (final line in lines)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            line.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.body.copyWith(
                              fontSize: 13.5,
                              color: line.warn ? theme.danger : muted,
                              letterSpacing: 0,
                              height: 1.25,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.onStopSharing != null && _live) ...[
                  const SizedBox(width: 8),
                  _pill(
                    theme,
                    label: l10n.locationBubbleStopSharing,
                    color: theme.danger,
                    filled: false,
                    busy: _stopping,
                    onTap: _stop,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _pill(
                    theme,
                    label: l10n.locationMapDirections,
                    icon: CupertinoIcons.arrow_turn_up_right,
                    color: locationMapAccent(theme),
                    filled: true,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onOpenInMaps(context);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                _round(
                  theme,
                  CupertinoIcons.square_arrow_up,
                  l10n.locationMapShare,
                  _share,
                ),
                const SizedBox(width: 10),
                _round(
                  theme,
                  CupertinoIcons.doc_on_doc,
                  l10n.locationBubbleCoordinatesCopied,
                  _copy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _distance(double m) {
    if (m < 1000) return '${(m / 10).round() * 10} m';
    if (m < 10000) return '${(m / 1000).toStringAsFixed(1)} km';
    return '${(m / 1000).round()} km';
  }

  Widget _pill(
    AppTheme theme, {
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback onTap,
    IconData? icon,
    bool busy = false,
  }) {
    final fg = filled ? Colors.white : color;
    return FocusableTap(
      onTap: busy ? null : onTap,
      shape: FocusRingShape.capsule,
      semanticLabel: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                CupertinoActivityIndicator(color: fg, radius: 8)
              else if (icon != null)
                Icon(icon, size: 17, color: fg),
              if (busy || icon != null) const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.body.copyWith(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _round(
    AppTheme theme,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) => FocusableTap(
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
          color: theme.inkMuted.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 19, color: theme.ink),
      ),
    ),
  );

  // ---------------------------------------------------------------- maps

  Widget _map(AppTheme theme) {
    final engine = _engine;
    // Created at once, under the flying picture; the face is handed over
    // when it is drawn, and any swap happens hidden under the picture.
    if (engine == null) return const SizedBox.expand();
    final dark = _dark(theme);
    final settings = SettingsStore.instance;
    final params = <String, Object?>{
      'latitude': _shown.latitude,
      'longitude': _shown.longitude,
      'accuracyM': _shown.accuracyM,
      'spanMeters': _spanMeters,
      'dark': dark,
      'mapType': _typeName(settings.mapStyle),
      'traffic': settings.mapTraffic,
      'showsUser': settings.mapShowMe && _meAllowed,
      'trail': _trailArgs,
      ..._pinArgs(_pin),
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
        return _openFreeMap(theme, dark);
    }
  }

  Widget _openFreeMap(AppTheme theme, bool dark) {
    final point = LatLng(_shown.latitude, _shown.longitude);
    final accent = locationMapAccent(theme);
    final acc = _shown.accuracyM;
    final pin = _pin;
    final me = _me;
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
        onMapReady: () {
          _ofmReady = true;
          // Tiles draw progressively; give the first ones a moment.
          Timer(const Duration(milliseconds: 350), _markReady);
        },
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
          userAgentPackageName: 'app.monkeyhub',
        ),
        if (_trail.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: List.of(_trail),
                color: accent.withValues(alpha: 0.55),
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
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
            if (me != null && SettingsStore.instance.mapShowMe)
              Marker(
                point: LatLng(me.latitude, me.longitude),
                width: 22,
                height: 22,
                child: const _MeDot(),
              ),
            Marker(
              point: point,
              width: pin?.size.width ?? 26,
              height: pin?.size.height ?? 26,
              alignment: pin == null
                  ? Alignment.center
                  : Alignment(0, 1 - 2 * pin.anchorY),
              child: pin == null
                  ? _Dot(
                      color: _ended ? theme.inkMuted : accent,
                      ring: theme.surface,
                      hollow: _ended,
                    )
                  : Image.memory(
                      pin.png,
                      scale: pin.scale,
                      gaplessPlayback: true,
                    ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.topLeft,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 60, 10, 0),
              child: Text(
                OpenFreeMapSnapshot.attribution,
                style: TextStyle(
                  inherit: false,
                  fontSize: 9.5,
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

/// Map type, traffic and your own position. Satellite and traffic only exist
/// on the OS maps; on OpenFreeMap the sheet says where to get them.
class _MapSettingsSheet extends StatelessWidget {
  const _MapSettingsSheet({required this.systemMaps, required this.onShowMe});

  final bool systemMaps;
  final Future<void> Function(bool on) onShowMe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final store = SettingsStore.instance;
        return SheetFrame(
          title: l.locationMapSettings,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (systemMaps)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: IosSegmentedControl<MapStyle>(
                    value: store.mapStyle,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      store.setMapStyle(v);
                    },
                    segments: [
                      IosSegment(value: MapStyle.map, label: l.mapStyleMap),
                      IosSegment(
                        value: MapStyle.hybrid,
                        label: l.mapStyleHybrid,
                      ),
                      IosSegment(
                        value: MapStyle.satellite,
                        label: l.mapStyleSatellite,
                      ),
                    ],
                  ),
                ),
              GroupedSection(
                children: [
                  if (systemMaps)
                    GroupedRow.toggle(
                      icon: CupertinoIcons.car_detailed,
                      tone: TileTone.orange,
                      title: l.mapTraffic,
                      value: store.mapTraffic,
                      onChanged: store.setMapTraffic,
                    ),
                  GroupedRow.toggle(
                    icon: CupertinoIcons.location_fill,
                    tone: TileTone.blue,
                    title: l.mapShowMyLocation,
                    value: store.mapShowMe,
                    onChanged: onShowMe,
                  ),
                ],
              ),
              if (!systemMaps) GroupedFooter(l.mapStyleOpenFreeMapNote),
            ],
          ),
        );
      },
    );
  }
}

/// Your own position on the OpenFreeMap map: the system's blue dot.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFF0A84FF),
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(color: Color(0x40000000), blurRadius: 5, offset: Offset(0, 1)),
      ],
    ),
  );
}

/// The plain marker for when no face could be drawn.
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

/// The flight's clip: a rounded rectangle that opens from the card to the
/// screen.
class _RectClip extends CustomClipper<RRect> {
  const _RectClip(this.rect, this.radius);

  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_RectClip old) => old.rect != rect || old.radius != radius;
}

/// Two 0..1 animations multiplied: the screen's opening flight and the
/// route's closing one, so the layout reads a single progress value.
class _FlightProduct extends CompoundAnimation<double> {
  _FlightProduct(Animation<double> first, Animation<double> next)
    : super(first: first, next: next);

  @override
  double get value => first.value * next.value;
}
