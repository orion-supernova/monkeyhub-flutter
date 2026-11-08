import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../media/file_url_cache.dart';
import '../../media/storage/media_image_cache.dart';

import '../../data/settings_store.dart';
import '../../theme/theme_preference.dart';
import '../../theme/theme_scope.dart';
import '../foundation/caps.dart';
import '../foundation/ui_kit.dart';
import '../../widgets/route_depth.dart';
import 'native_cut.dart';

/// A real iOS control (SwiftUI, Liquid Glass on iOS 26) inside the Flutter
/// layout: the [UiKit.liquid] kit's skins draw with these.
///
/// The control is NOT a platform view. It is a native view in one overlay
/// above the Flutter view (`ios/Runner/NativeControls.swift`, [NativeOverlay]
/// below): this widget only holds its place in the layout, and after every
/// frame its rectangle, the visible part of its scroll viewport (minus the
/// page bars, see [NativeCut]) and whether it may show at all go over in one
/// batched message. Flutter clips a platform view with a mask, and a masked
/// Liquid Glass view renders as a flat grey rectangle; the overlay clips with
/// plain rectangles and the glass stays live.
///
/// A native view is always above Flutter, so it hides (and [standIn], the
/// Flutter skin, takes its place) whenever Flutter draws something over it:
/// another route on top or animating in, an offstage tab, or a Flutter
/// overlay that called [NativeOverlay.suppress].
///
/// Dart owns all state: the [spec] goes over whenever it changes; what the
/// person does comes back as [onEvent] (`tap`, `changed`, `changeEnd`,
/// `submitted`, `select`, `focus`).
class NativeControl extends StatefulWidget {
  const NativeControl({
    super.key,
    required this.spec,
    this.onEvent,
    this.size,
    this.gestures = const {},
    this.handle,
    this.standIn,
  });

  /// Lets the owner move focus in a native text field (`focus` / `blur`).
  final NativeControlHandle? handle;

  final NativeSpec spec;
  final void Function(String event, Object? value)? onEvent;

  /// Fixed size. Null sizes to what the control reports (a text button, a
  /// menu label) after its first layout.
  final Size? size;

  /// Kept for call sites written for the platform-view version; the overlay
  /// receives its own touches, so nothing needs to win an arena any more.
  final Set<Factory<OneSequenceGestureRecognizer>> gestures;

  /// What shows while the native view cannot: the same control's Flutter
  /// skin. Null shows nothing.
  final Widget? standIn;

  /// Whether a native control can be drawn here at all.
  static bool get available => Caps.iOS && Caps.nativeGlass;

  /// Whether the liquid kit's skins should use native controls here.
  /// Components pass `liquid: NativeControl.readyIn(context) ? _liquid : null`
  /// to [KitSwitch]; with Settings › Glass › Native controls on "Just the tab
  /// bar" the liquid kit falls back to glass.
  static bool readyIn(BuildContext context) =>
      available &&
      UiKit.of(context) == UiKit.liquid &&
      UiKit.nativeControlsOf(context);

  @override
  State<NativeControl> createState() => _NativeControlState();
}

/// The Dart→native calls of one [NativeControl]: focus and blur of a text
/// field. A call made before the control exists natively is replayed once it
/// does (autofocus).
class NativeControlHandle {
  String? _id;
  String? _pending;

  void _attach(String? id) {
    _id = id;
    final pending = _pending;
    if (id != null && pending != null) {
      _pending = null;
      _invoke(pending);
    }
  }

  void _invoke(String method) {
    final id = _id;
    if (id == null) {
      _pending = method;
      return;
    }
    NativeOverlay._call(method, {'id': id});
  }

  void focus() => _invoke('focus');
  void blur() => _invoke('blur');
}

/// The one bridge to the native overlay. Every [NativeControl] registers
/// here; after each frame the overlay measures them all and sends what moved
/// in one `sync`.
class NativeOverlay {
  NativeOverlay._();

  static const MethodChannel _channel = MethodChannel('monkeyhub/native_overlay');
  static final Map<String, _NativeControlState> _controls = {};
  static int _nextId = 0;
  static bool _started = false;

  /// Flutter overlays drawn above native controls (a hold menu, a Flutter
  /// pull-down) bump this while open; every control hides meanwhile.
  static final ValueNotifier<int> suppressed = ValueNotifier<int>(0);

  /// Runs [body] with native controls hidden, for an overlay that is not a
  /// route (routes hide them on their own).
  static void suppress() => suppressed.value++;

  /// Flutter chrome that floats over the pages (the call pills): a native
  /// control is always above Flutter, so one under these would draw on top
  /// of them. Each frame's placement hides any control they overlap, and its
  /// Flutter stand-in, which Flutter layers correctly, draws instead.
  static final Set<BuildContext> _occluders = {};

  static bool _occluded(Rect rect, [Object? layer]) {
    for (final c in _occluders) {
      if (layer != null && identical(NativeLayer._of(c), layer)) continue;
      final w = c.widget;
      if (w is NativeOccluder && !w.enabled) continue;
      final box = c.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      if (box.size.isEmpty) continue;
      final r = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      if (r.overlaps(rect)) return true;
    }
    return false;
  }
  static void release() =>
      suppressed.value = suppressed.value > 0 ? suppressed.value - 1 : 0;

  static Future<void> _call(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (_) {}
  }

  static void _start() {
    if (_started) return;
    _started = true;
    // A hot restart leaves the previous run's views on screen.
    _call('reset', const {});
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'event') return;
      final m = (call.arguments as Map).cast<String, Object?>();
      _controls[m['id']]?._event(m['name'] as String, m['value']);
    });
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (_controls.isEmpty) return;
      SchedulerBinding.instance.addPostFrameCallback((_) => _sync());
    });
  }

  static String _register(_NativeControlState state) {
    _start();
    final kind = state.widget.spec._map['kind'] as String?;
    final sig = state.widget.spec._map.toString();
    final pooled = _pool[kind];
    String id;
    if (pooled != null && pooled.isNotEmpty) {
      // The same control coming back (a tab revisited) gets its own view:
      // nothing in it changes, so not even one frame of other content.
      final same = pooled.lastIndexWhere((p) => _sigs[p] == sig);
      id = pooled.removeAt(same >= 0 ? same : pooled.length - 1);
    } else {
      id = 'nc${_nextId++}';
    }
    _controls[id] = state;
    _kinds[id] = kind;
    _sigs[id] = sig;
    // A control that registers between frames is placed after the next one.
    SchedulerBinding.instance.ensureVisualUpdate();
    return id;
  }

  /// Hidden native views of controls that went away, by kind, for the next
  /// control of that kind to adopt. A fresh glass view needs ~0.12s to take
  /// its first backdrop sample (until then its stand-in shows, then it swaps
  /// in with a bright first frame): every tab visit flickered its buttons
  /// and chips that way. An adopted view has sampled already and shows on
  /// its first frame; `set` only changes what it draws.
  ///
  /// Stateless glass kinds only: a text field, toggle, slider, picker or
  /// segmented control keeps state in its native view that would show
  /// through for a frame.
  static final Map<String?, List<String>> _pool = {};
  static final Map<String, String?> _kinds = {};
  static final Map<String, String> _sigs = {};
  static const Set<String> _poolable = {
    'symbolButton', 'button', 'buttonGroup', 'toolbar', 'titlePill', 'pinBar',
  };
  static const int _poolPerKind = 12;

  static void _unregister(String id, [Map<String, Object?>? last]) {
    _controls.remove(id);
    final kind = _kinds.remove(id);
    final pool = _pool[kind] ??= [];
    if (_poolable.contains(kind) && pool.length < _poolPerKind) {
      // Hidden now (a clip to nothing), kept for the next control of its
      // kind. At its last size: a glass view resized from nothing would
      // resample, and flash, when adopted.
      _call('sync', {
        'items': [
          {
            'id': id,
            'x': last?['x'] ?? 0.0, 'y': last?['y'] ?? 0.0,
            'w': last?['w'] ?? 0.0, 'h': last?['h'] ?? 0.0,
            'cx': 0.0, 'cy': 0.0, 'cw': 0.0, 'ch': 0.0,
            'visible': false, 'why': 'pooled',
          },
        ],
      });
      pool.add(id);
    } else {
      _sigs.remove(id);
      _call('remove', {'id': id});
    }
  }

  static void _sync() {
    final items = <Map<String, Object?>>[];
    for (final entry in _controls.entries) {
      final placement = entry.value._placement();
      if (placement == null) continue;
      items.add({'id': entry.key, ...placement});
    }
    if (items.isNotEmpty) _call('sync', {'items': items});
  }
}

class _NativeControlState extends State<NativeControl> {
  late final String _id = NativeOverlay._register(this);

  /// The spec the native side last received.
  Map<String, Object?>? _sent;
  Size? _reported;
  bool _revealed = false;
  Map<String, Object?>? _lastPlacement;
  ModalRoute<Object?>? _route;
  bool _tickerOn = true;
  double? Function()? _cutLine;

  /// The [NativeLayer] this control sits in, if any: scrims and occluders
  /// of its own layer are below it, not over it.
  Object? _layer;

  void _push(Map<String, Object?> spec) {
    if (_specEquals(spec, _sent)) return;
    _sent = spec;
    NativeOverlay._sigs[_id] = widget.spec._map.toString();
    // A rebuilt control can change kind (same state, new spec): pool it, or
    // not, as what it is now.
    NativeOverlay._kinds[_id] = widget.spec._map['kind'] as String?;
    NativeOverlay._call('set', {'id': _id, 'spec': spec});
  }

  Map<String, Object?> _resolved(BuildContext context) {
    final theme = ThemeScope.of(context);
    return {
      'dark': !theme.isLight,
      'tint': theme.accent.toARGB32(),
      'interactive': SettingsStore.instance.glassInteractive,
      ...widget.spec.toMap(),
    };
  }

  void _event(String name, Object? value) {
    if (!mounted) return;
    switch (name) {
      case 'size':
        final m = (value as Map).cast<String, Object?>();
        final size = Size(
          (m['width'] as num).toDouble(),
          (m['height'] as num).toDouble(),
        );
        if (widget.size == null && size != _reported) {
          setState(() => _reported = size);
        }
      case 'revealed':
        final on = value == true;
        if (on != _revealed) setState(() => _revealed = on);
      default:
        widget.onEvent?.call(name, value);
    }
  }

  /// Where the control is and whether it may show, or null when nothing
  /// changed since the last sync.
  ///
  /// Two rules keep a transition free of flicker:
  ///
  /// - **Ride along** ([SettingsStore.nativeRideAlong], the default): a push,
  ///   pop or sheet does not hide native controls. Each follows its page
  ///   every frame (this rect includes the route's slide), so the incoming
  ///   page's buttons arrive as native glass and nothing swaps at the end.
  ///   A control only steps aside where something Flutter draws above it
  ///   covers it ([_covered]: a page sliding over it, a sheet's or dialog's
  ///   barrier), because a native view always draws above Flutter.
  /// - **Stand-in first**: when a native control must hide, its Flutter
  ///   stand-in is built first and the native view goes [_holdFrames] syncs
  ///   later, so there is never a frame with neither (the header that
  ///   vanished for a frame as a push began).
  Map<String, Object?>? _placement() {
    final box = context.findRenderObject();
    final laid = mounted && box is RenderBox && box.attached && box.hasSize;
    final rideAlong = SettingsStore.instance.nativeRideAlong;
    String? why;
    if (!laid) {
      why = 'unlaid';
    } else if (!_tickerOn) {
      why = 'ticker';
    } else if (NativeOverlay.suppressed.value != 0) {
      why = 'suppressed';
    } else if (!rideAlong && !_routeSettled()) {
      why = 'route';
    }
    Rect rect = Rect.zero;
    Rect clip = Rect.zero;
    // How much a barrier above (a sheet's or dialog's scrim) darkens this
    // control right now. The native view takes the same dim instead of
    // swapping to its stand-in, the way a native app's bar sits under a
    // sheet.
    var dimBy = 0.0;
    if (laid) {
      final b = box;
      rect = MatrixUtils.transformRect(
        b.getTransformTo(null),
        Offset.zero & b.size,
      );
    }
    if (why == null) {
      clip = _clip(rect);
      if (clip.isEmpty) {
        why = 'clipped';
      } else if (!_whole(clip, rect)) {
        // Liquid Glass under a clipping ancestor that cuts into it renders
        // offscreen as a flat grey box with only its uncut corners round
        // (seen on device at the page bar, a sheet's top and the chat
        // list's floating header). A partly visible control shows its
        // Flutter stand-in, which Flutter clips properly, and goes native
        // again once whole.
        why = 'partial';
      } else if (_fading()) {
        // A fade in progress above it (FadeTransition, AnimatedOpacity):
        // Liquid Glass ignores alpha, so the native view would sit crisp
        // over a half-faded page. Its stand-in fades properly until done.
        why = 'faded';
      } else if (NativeOverlay._occluded(rect, _layer)) {
        why = 'occluded';
      } else if (rideAlong) {
        final (:covered, :dim) = _cover(rect);
        if (covered) {
          why = 'covered';
        } else {
          dimBy = dim;
        }
      }
    }
    if (why == null) {
      // A Flutter scrim over this spot (the video note's dim): the same
      // native dim a sheet's barrier gets, and no touches through it.
      final scrim = NativeScrim._dimAt(rect, _layer);
      if (scrim > 0) dimBy = 1 - (1 - dimBy) * (1 - scrim);
    }
    final want = why == null;
    var send = want;
    if (want) {
      if (_standInWanted) {
        // Came back before the native view left: drop the extra stand-in.
        _holdLeft = 0;
        setState(() => _standInWanted = false);
      }
    } else if (_nativeUp && laid && _tickerOn && why != 'clipped') {
      // Stand-in first, native out a little later. Only where the stand-in
      // will actually show: not for an offstage page (ticker off) or one
      // clipped away or faded to nothing ('clipped', e.g. the composer's
      // mode button hidden under the record bloom), where holding the
      // native view up drew it, for three frames, over what replaced it.
      if (!_standInWanted) {
        _standInWanted = true;
        _holdLeft = _holdFrames;
        setState(() {});
      }
      if (_holdLeft > 0) {
        _holdLeft--;
        send = true;
        clip = rect;
        SchedulerBinding.instance.ensureVisualUpdate();
      }
    }
    final placement = <String, Object?>{
      'x': _r(rect.left),
      'y': _r(rect.top),
      'w': _r(rect.width),
      'h': _r(rect.height),
      'cx': _r(clip.left),
      'cy': _r(clip.top),
      'cw': _r(clip.width),
      'ch': _r(clip.height),
      'visible': send,
      'why': ?why,
      if (send && dimBy > 0) 'dim': (dimBy * 50).roundToDouble() / 50,
    };
    if (_specEquals(placement, _lastPlacement)) return null;
    _lastPlacement = placement;
    _nativeUp = send;
    if (!send) {
      _standInWanted = false;
      if (_revealed) setState(() => _revealed = false);
    }
    return placement;
  }

  /// Syncs a native view stays up once its stand-in is asked for: the
  /// asking frame, the frame that builds the stand-in, and one more for that
  /// frame's raster to reach the screen before the native view leaves.
  static const int _holdFrames = 3;
  int _holdLeft = 0;

  /// The stand-in is drawn although the native view may still be up: it is
  /// about to hide.
  bool _standInWanted = false;

  /// The last sync told the native side to show.
  bool _nativeUp = false;

  /// What draws above this control's route at [rect]: whether something
  /// covers it (a page above it, by its current mid-slide bounds, or a
  /// [NativeCover] card of a route above) and how much a barrier above dims
  /// it (scrim alpha times how far in it has faded).
  ({bool covered, double dim}) _cover(Rect rect) {
    final mine = _route;
    if (mine == null) return (covered: false, dim: 0.0);
    // A few points of lead, so the swap happens just before an incoming
    // page's edge reaches the control, under its shadow, not after.
    final probe = rect.inflate(6);
    var dim = 0.0;
    for (final u in RouteDepthObserver.live) {
      if (identical(u, mine) || !_isAbove(u, mine)) continue;
      var t = 1.0;
      if (u is TransitionRoute) {
        final a = u.animation;
        if (a != null) t = a.value;
        if (t <= 0) continue;
      }
      if (u is ModalRoute) {
        final barrier = u.barrierColor;
        if (barrier != null && barrier.a > 0) {
          // A sheet or dialog: its route fills the screen, but only its card
          // covers anything; the rest is scrim.
          dim = 1 - (1 - dim) * (1 - barrier.a * t.clamp(0.0, 1.0));
          if (NativeCover._overlaps(u, probe)) {
            return (covered: true, dim: 0.0);
          }
          continue;
        }
        final pageBox = u.subtreeContext?.findRenderObject();
        if (pageBox is RenderBox && pageBox.attached && pageBox.hasSize) {
          final page = MatrixUtils.transformRect(
            pageBox.getTransformTo(null),
            Offset.zero & pageBox.size,
          );
          if (page.overlaps(probe)) return (covered: true, dim: 0.0);
          continue;
        }
      }
      // A route whose bounds can't be read: assume it covers.
      return (covered: true, dim: 0.0);
    }
    return (covered: false, dim: dim);
  }

  /// Whether [u] draws above [mine]. On one navigator, the deeper route.
  /// Across navigators, by the route that HOSTS the nested navigator: the
  /// shell's panes live in the root's base page, but a room's side pane
  /// (where a profile opens on a phone) lives inside the room's page. A
  /// route pushed on a nested navigator is above every route at or below
  /// its host; a route pushed on an outer navigator is above everything
  /// whose host sits below it. Base routes of nested navigators never count,
  /// so a pane's base page never hides the page around it.
  static bool _isAbove(Route<dynamic> u, Route<dynamic> mine) {
    final un = u.navigator;
    final mn = mine.navigator;
    final du = RouteDepthObserver.of(u);
    final dm = RouteDepthObserver.of(mine);
    if (un == null || mn == null || du == null || dm == null) return false;
    if (identical(un, mn)) return du > dm;
    if (du < 1) return false;
    if (_encloses(mn, un)) {
      final host = RouteDepthObserver.of(_hostIn(un, mn));
      return host != null && dm <= host;
    }
    if (_encloses(un, mn)) {
      final host = RouteDepthObserver.of(_hostIn(mn, un));
      return host != null && du > host;
    }
    return false;
  }

  static final Expando<Route<dynamic>> _hosts = Expando('nativeNavHost');

  /// The route of [outer] whose page holds the navigator [inner], cached:
  /// a navigator never moves to another page.
  static Route<dynamic>? _hostIn(NavigatorState inner, NavigatorState outer) {
    final cached = _hosts[inner];
    if (cached != null) return cached;
    for (final r in RouteDepthObserver.live) {
      if (!identical(r.navigator, outer) || r is! ModalRoute) continue;
      final page = r.subtreeContext;
      if (page == null) continue;
      var inside = false;
      inner.context.visitAncestorElements((e) {
        if (identical(e, page)) inside = true;
        return !inside;
      });
      if (inside) return _hosts[inner] = r;
    }
    return null;
  }

  /// [outer] is an ancestor navigator of [inner].
  static bool _encloses(NavigatorState outer, NavigatorState inner) {
    var n = inner.context.findAncestorStateOfType<NavigatorState>();
    while (n != null) {
      if (identical(n, outer)) return true;
      n = n.context.findAncestorStateOfType<NavigatorState>();
    }
    return false;
  }

  /// An animating ancestor fade sits between hidden and fully shown. A
  /// static [Opacity] (a dimmed, disabled look) does not count: that is a
  /// resting state, and the control keeps its native glass.
  bool _fading() {
    RenderObject? node = context.findRenderObject()?.parent;
    while (node != null) {
      if (node is RenderAnimatedOpacity) {
        final v = node.opacity.value;
        if (v >= 0.05 && v < 0.99) return true;
      }
      node = node.parent;
    }
    return false;
  }

  static double _r(double v) => (v * 2).roundToDouble() / 2;

  /// [clip] still holds all of [rect], give or take a rounding half-point.
  static bool _whole(Rect clip, Rect rect) =>
      clip.left <= rect.left + 0.5 &&
      clip.top <= rect.top + 0.5 &&
      clip.right >= rect.right - 0.5 &&
      clip.bottom >= rect.bottom - 0.5;

  bool _routeSettled() {
    final route = _route;
    if (route == null) return true;
    if (!route.isCurrent || !route.isActive) return false;
    final a = route.animation;
    final s = route.secondaryAnimation;
    return (a == null || a.status == AnimationStatus.completed) &&
        (s == null || s.status == AnimationStatus.dismissed);
  }

  /// The visible part of the control: every clipping ancestor (scroll
  /// viewports, ClipRects, collapsing AnimatedSizes) cut at the page bar
  /// ([NativeCut]). Empty when an ancestor hides it outright: a zero
  /// opacity (a fade-out), or offstage. A native view sees none of Flutter's
  /// compositing, so this walk is how it learns.
  Rect _clip(Rect rect) {
    var clip = rect;
    final box = context.findRenderObject();
    RenderObject? node = box?.parent;
    while (node != null) {
      if (node is RenderOpacity && node.opacity < 0.05) return Rect.zero;
      if (node is RenderAnimatedOpacity && node.opacity.value < 0.05) {
        return Rect.zero;
      }
      if (node is RenderOffstage && node.offstage) return Rect.zero;
      final clips = node is RenderClipRect ||
          node is RenderClipRRect ||
          node is RenderClipPath ||
          node is RenderClipOval ||
          (node is RenderViewportBase && node.clipBehavior != Clip.none);
      if (clips && node is RenderBox && node.hasSize) {
        clip = clip.intersect(
          MatrixUtils.transformRect(
            node.getTransformTo(null),
            Offset.zero & node.size,
          ),
        );
        if (clip.width <= 0 || clip.height <= 0) return Rect.zero;
      }
      node = node.parent;
    }
    final cut = _cutLine?.call();
    if (cut != null && clip.top < cut) {
      clip = Rect.fromLTRB(clip.left, cut, clip.right, clip.bottom);
    }
    if (clip.width <= 0 || clip.height <= 0) return Rect.zero;
    return clip;
  }

  @override
  void initState() {
    super.initState();
    widget.handle?._attach(_id);
    NativeOverlay.suppressed.addListener(_poke);
    SettingsStore.instance.addListener(_settingsChanged);
  }

  void _poke() => SchedulerBinding.instance.ensureVisualUpdate();

  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.animation?.removeListener(_poke);
      _route?.secondaryAnimation?.removeListener(_poke);
      _route = route;
      route?.animation?.addListener(_poke);
      route?.secondaryAnimation?.addListener(_poke);
    }
    _tickerOn = TickerMode.valuesOf(context).enabled;
    _cutLine = NativeCut.lineOf(context);
    _layer = NativeLayer._of(context);
  }

  @override
  void didUpdateWidget(NativeControl old) {
    super.didUpdateWidget(old);
    if (old.handle != widget.handle) {
      old.handle?._attach(null);
      widget.handle?._attach(_id);
    }
  }

  @override
  void dispose() {
    widget.handle?._attach(null);
    _route?.animation?.removeListener(_poke);
    _route?.secondaryAnimation?.removeListener(_poke);
    NativeOverlay.suppressed.removeListener(_poke);
    SettingsStore.instance.removeListener(_settingsChanged);
    NativeOverlay._unregister(_id, _lastPlacement);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _push(_resolved(context));
    final size = widget.size ?? _reported ?? const Size(44, 44);
    final standIn = widget.standIn;
    return SizedBox(
      // A full-width control takes the full width whether or not its
      // stand-in is drawn: an empty box would shrink to zero, read as
      // clipped, hide, bring the stand-in back, widen, show, and blink.
      width: size.width,
      height: size.height,
      child: standIn == null || (_revealed && !_standInWanted)
          ? null
          : Center(child: standIn),
    );
  }
}

/// The size a labelled native button ([NativeSpec.button]) draws at, measured
/// here because a platform view needs its box before SwiftUI has laid out:
/// the label at the system button font (15 pt below 34 pt tall, 17 pt above),
/// plus the glass button's own side padding and an optional symbol.
Size nativeButtonSize(
  BuildContext context,
  String label, {
  required double height,
  bool symbol = false,
}) {
  final small = height <= 34;
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontSize: small ? 15 : 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final pad = small ? 12.0 : (height <= 40 ? 16.0 : 20.0);
  final width =
      painter.width + pad * 2 + (symbol ? (small ? 21.0 : 23.0) : 0) + 2;
  painter.dispose();
  return Size(width.ceilToDouble(), height);
}

/// What a [NativeControl] draws. Built with the named constructors; the map is
/// the wire format `NativeControls.swift` decodes (every field optional there).
@immutable
class NativeSpec {
  const NativeSpec._(this._map);

  final Map<String, Object?> _map;

  Map<String, Object?> toMap() => _map;

  /// The round chrome button: a 44 pt glass circle, a 17 pt SF Symbol.
  /// [passthrough] draws it only: touches fall through to the Flutter
  /// gestures under it (the composer's hold-to-record mode button).
  factory NativeSpec.symbolButton({
    required String symbol,
    required String label,
    bool prominent = false,
    bool destructive = false,
    bool enabled = true,
    double size = 44,
    double symbolSize = 17,
    bool passthrough = false,
    String? badge,
    bool badgeQuiet = false,
    int kickTick = 0,
    bool accentSymbol = false,
  }) => NativeSpec._({
    'kind': 'symbolButton',
    'passthrough': passthrough,
    'badge': ?badge,
    'badgeQuiet': badgeQuiet,
    'kickTick': kickTick,
    'accentLabel': accentSymbol,
    'symbol': symbol,
    'label': label,
    'prominent': prominent,
    'destructive': destructive,
    'enabled': enabled,
    'size': size,
    'symbolSize': symbolSize,
  });

  /// A labelled glass button; [prominent] is the tinted primary action.
  /// [passthrough] draws it only (see [NativeSpec.symbolButton]): for a
  /// button inside a scrolling row, where a drag that starts on it must
  /// scroll, the caller takes the tap in Flutter instead.
  factory NativeSpec.button({
    required String label,
    String? symbol,
    bool prominent = false,
    bool destructive = false,
    bool enabled = true,
    bool fill = false,
    double height = 50,
    bool passthrough = false,
  }) => NativeSpec._({
    'kind': 'button',
    'passthrough': passthrough,
    'label': label,
    'symbol': ?symbol,
    'prominent': prominent,
    'destructive': destructive,
    'enabled': enabled,
    'fill': fill,
    'size': height,
  });

  factory NativeSpec.toggle({
    required bool value,
    required String label,
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'toggle',
    'value': value,
    'label': label,
    'enabled': enabled,
  });

  /// [options] are (value, label) pairs; [selected] is a value.
  factory NativeSpec.segmented({
    required List<({String value, String label})> options,
    required String selected,
    String label = '',
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'segmented',
    'options': [
      for (final o in options) {'value': o.value, 'label': o.label},
    ],
    'selected': selected,
    'label': label,
    'enabled': enabled,
  });

  /// [step] 0 is continuous (never sent to SwiftUI as a step; it traps).
  factory NativeSpec.slider({
    required double value,
    double min = 0,
    double max = 1,
    double step = 0,
    String label = '',
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'slider',
    'doubleValue': value,
    'min': min,
    'max': max,
    'step': step,
    'label': label,
    'enabled': enabled,
  });

  /// A line of text on a glass capsule that is not a control (a hint, a
  /// tooltip). Always draws only: touches fall through to Flutter.
  factory NativeSpec.glassLabel({
    required String text,
    double fontSize = 11,
  }) => NativeSpec._({
    'kind': 'glassLabel',
    'label': text,
    'symbolSize': fontSize,
    'passthrough': true,
  });

  /// The chat composer's growing text view in a glass capsule (see
  /// `NativeComposerField`). [text] and the selection apply only when
  /// [textRev] changes; [trailingSymbol] draws a button at the end
  /// (`trailing` event), shown as a keyboard while [trailingOn].
  factory NativeSpec.composerField({
    required String text,
    required int textRev,
    int? selStart,
    int? selEnd,
    String placeholder = '',
    int maxLines = 5,
    double minHeight = 44,
    double cornerRadius = 22,
    String? trailingSymbol,
    bool trailingOn = false,
    String trailingLabel = '',
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'composerField',
    'text': text,
    'textRev': textRev,
    'selStart': ?selStart,
    'selEnd': ?selEnd,
    'placeholder': placeholder,
    'maxLines': maxLines,
    'size': minHeight,
    'cornerRadius': cornerRadius,
    'symbol': ?trailingSymbol,
    'value': trailingOn,
    'label': trailingLabel,
    'enabled': enabled,
  });

  /// A one-line field. [text] is only applied natively when [textRev]
  /// changes (an external edit): typing never echoes back.
  factory NativeSpec.textField({
    required String text,
    int textRev = 0,
    String placeholder = '',
    bool secure = false,
    String? contentType,
    String? keyboard,
    String? leadingSymbol,
    String? submitLabel,
    bool clearButton = false,
    bool plain = false,
    String? capitalization,
    bool? autocorrect,
    double height = 44,
    double cornerRadius = 22,
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'textField',
    'text': text,
    'textRev': textRev,
    'placeholder': placeholder,
    'secure': secure,
    'contentType': ?contentType,
    'keyboard': ?keyboard,
    'leadingSymbol': ?leadingSymbol,
    'submitLabel': ?submitLabel,
    'clearButton': clearButton,
    'plain': plain,
    'capitalization': ?capitalization,
    'autocorrect': ?autocorrect,
    'size': height,
    'cornerRadius': cornerRadius,
    'enabled': enabled,
  });

  /// The search capsule: magnifier, clear button, "search" return key.
  factory NativeSpec.searchField({
    required String text,
    int textRev = 0,
    String placeholder = '',
    String submitLabel = 'search',
    double height = 44,
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'searchField',
    'text': text,
    'textRev': textRev,
    'placeholder': placeholder,
    'submitLabel': submitLabel,
    'size': height,
    'enabled': enabled,
  });

  /// Symbol buttons sharing one glass capsule. Taps arrive as `select` with
  /// the option's value. [size] is each slot's width and height.
  factory NativeSpec.buttonGroup({
    required List<NativeOptionSpec> options,
    double size = 44,
    double symbolSize = 17,
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'buttonGroup',
    'options': [for (final o in options) o.toMap()],
    'size': size,
    'symbolSize': symbolSize,
    'enabled': enabled,
  });

  /// Separate glass discs in a GlassEffectContainer: discs closer than
  /// [blend] (default [spacing]) blend into one shape like the iOS 26
  /// toolbar, so a [blend] above [spacing] merges neighbours at rest. Taps
  /// arrive as `select`.
  factory NativeSpec.toolbar({
    required List<NativeOptionSpec> options,
    double size = 44,
    double symbolSize = 17,
    double spacing = 8,
    double? blend,
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'toolbar',
    'options': [for (final o in options) o.toMap()],
    'size': size,
    'symbolSize': symbolSize,
    'spacing': spacing,
    'blend': ?blend,
    'enabled': enabled,
  });

  /// A pull-down menu: a glass button (symbol, or label with chevron) that
  /// morphs into the system menu. A pick arrives as `select` with the id.
  factory NativeSpec.menu({
    String? label,
    String? symbol,
    required List<NativeMenuItemSpec> items,
    double size = 44,
    double symbolSize = 17,
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'menu',
    'label': label ?? '',
    'symbol': ?symbol,
    'items': [for (final i in items) i.toMap()],
    'size': size,
    'symbolSize': symbolSize,
    'enabled': enabled,
  });

  /// The system date picker. [mode] date | time | dateTime; [style] compact |
  /// wheel | graphical. Dates travel as epoch milliseconds (`changed`).
  factory NativeSpec.datePicker({
    required int ms,
    int? minMs,
    int? maxMs,
    String mode = 'dateTime',
    String style = 'compact',
    String label = '',
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'datePicker',
    'dateMs': ms.toDouble(),
    'minDateMs': ?minMs?.toDouble(),
    'maxDateMs': ?maxMs?.toDouble(),
    'dateMode': mode,
    'dateStyle': style,
    'label': label,
    'enabled': enabled,
  });

  /// The chat header's title capsule. The avatar is a cached picture file
  /// ([avatarPath]), else [avatarSymbol] on a quiet disc, else [initials] on
  /// [avatarColor]. Events: `tap` (the capsule), `avatar` (the picture).
  factory NativeSpec.titlePill({
    required String title,
    String subtitle = '',
    Color? subtitleColor,
    String? avatarPath,
    String? avatarSymbol,
    String initials = '',
    Color? avatarColor,
    double avatarSize = 34,
    double height = 44,
  }) => NativeSpec._({
    'kind': 'titlePill',
    'label': title,
    'subtitle': subtitle,
    'subtitleColor': ?subtitleColor?.toARGB32(),
    'avatarPath': ?avatarPath,
    'avatarSymbol': ?avatarSymbol,
    'initials': initials,
    'avatarColor': ?avatarColor?.toARGB32(),
    'avatarSize': avatarSize,
    'size': height,
  });

  /// The pinned-message bar: [title] (the sender) and [preview] on one line,
  /// [count] position ticks. Events: `tap` (jump), `list`.
  factory NativeSpec.pinBar({
    required String title,
    String preview = '',
    int count = 1,
    int activeIndex = 0,
    double height = 44,
    double cornerRadius = 22,
  }) => NativeSpec._({
    'kind': 'pinBar',
    'label': title,
    'subtitle': preview,
    'count': count,
    'activeIndex': activeIndex,
    'size': height,
    'cornerRadius': cornerRadius,
  });

  @override
  bool operator ==(Object other) =>
      other is NativeSpec && _specEquals(other._map, _map);

  @override
  int get hashCode => Object.hashAllUnordered(_map.keys);
}

/// One slot of a native [NativeSpec.buttonGroup] / [NativeSpec.toolbar].
@immutable
class NativeOptionSpec {
  const NativeOptionSpec({
    required this.value,
    required this.label,
    this.symbol,
    this.disabled = false,
    this.destructive = false,
  });

  final String value;
  final String label;
  final String? symbol;
  final bool disabled;
  final bool destructive;

  Map<String, Object?> toMap() => {
    'value': value,
    'label': label,
    'symbol': ?symbol,
    'disabled': disabled,
    'destructive': destructive,
  };
}

/// One row of a native [NativeSpec.menu]. A [divider] row has no label.
@immutable
class NativeMenuItemSpec {
  const NativeMenuItemSpec({
    required this.id,
    this.label = '',
    this.symbol,
    this.destructive = false,
    this.disabled = false,
    this.checked,
    this.divider = false,
  });

  const NativeMenuItemSpec.divider()
    : id = '',
      label = '',
      symbol = null,
      destructive = false,
      disabled = false,
      checked = null,
      divider = true;

  final String id;
  final String label;
  final String? symbol;
  final bool destructive;
  final bool disabled;
  final bool? checked;
  final bool divider;

  Map<String, Object?> toMap() => {
    'id': id,
    'label': label,
    'symbol': ?symbol,
    'destructive': destructive,
    'disabled': disabled,
    'checked': ?checked,
    'divider': divider,
  };
}

/// The SF Symbol for a [CupertinoIcons] glyph the shared buttons use, or null
/// when there is no exact one (the button then keeps its Flutter skin rather
/// than show a wrong symbol).
String? sfSymbolFor(IconData? icon) => _symbols[icon];

final Map<IconData, String> _symbols = {
  CupertinoIcons.chevron_back: 'chevron.backward',
  CupertinoIcons.chevron_left: 'chevron.left',
  CupertinoIcons.chevron_right: 'chevron.right',
  CupertinoIcons.chevron_forward: 'chevron.forward',
  CupertinoIcons.chevron_down: 'chevron.down',
  CupertinoIcons.chevron_up: 'chevron.up',
  CupertinoIcons.xmark: 'xmark',
  CupertinoIcons.ellipsis: 'ellipsis',
  CupertinoIcons.ellipsis_circle: 'ellipsis.circle',
  CupertinoIcons.plus: 'plus',
  CupertinoIcons.search: 'magnifyingglass',
  CupertinoIcons.share: 'square.and.arrow.up',
  CupertinoIcons.trash: 'trash',
  CupertinoIcons.pencil: 'pencil',
  CupertinoIcons.square_pencil: 'square.and.pencil',
  CupertinoIcons.camera: 'camera',
  CupertinoIcons.camera_fill: 'camera.fill',
  CupertinoIcons.phone: 'phone',
  CupertinoIcons.phone_fill: 'phone.fill',
  CupertinoIcons.video_camera: 'video',
  CupertinoIcons.video_camera_solid: 'video.fill',
  CupertinoIcons.info: 'info',
  CupertinoIcons.question: 'questionmark',
  CupertinoIcons.question_circle: 'questionmark.circle',
  CupertinoIcons.gear: 'gearshape',
  CupertinoIcons.settings: 'gearshape',
  CupertinoIcons.person_add: 'person.badge.plus',
  CupertinoIcons.person_crop_circle: 'person.crop.circle',
  CupertinoIcons.bell: 'bell',
  CupertinoIcons.bell_slash: 'bell.slash',
  CupertinoIcons.heart: 'heart',
  CupertinoIcons.heart_fill: 'heart.fill',
  CupertinoIcons.arrow_down_to_line: 'arrow.down.to.line',
  CupertinoIcons.arrow_up: 'arrow.up',
  CupertinoIcons.arrow_down: 'arrow.down',
  CupertinoIcons.checkmark: 'checkmark',
  CupertinoIcons.checkmark_alt: 'checkmark',
  CupertinoIcons.flag: 'flag',
  CupertinoIcons.pin: 'pin',
  CupertinoIcons.bookmark: 'bookmark',
  CupertinoIcons.paperplane: 'paperplane',
  CupertinoIcons.paperplane_fill: 'paperplane.fill',
  CupertinoIcons.mic: 'mic',
  CupertinoIcons.mic_fill: 'mic.fill',
  CupertinoIcons.photo: 'photo',
  CupertinoIcons.slider_horizontal_3: 'slider.horizontal.3',
  CupertinoIcons.line_horizontal_3_decrease: 'line.3.horizontal.decrease',
  CupertinoIcons.qrcode: 'qrcode',
  CupertinoIcons.qrcode_viewfinder: 'qrcode.viewfinder',
  CupertinoIcons.arrow_counterclockwise: 'arrow.counterclockwise',
  CupertinoIcons.arrow_clockwise: 'arrow.clockwise',
  CupertinoIcons.play_fill: 'play.fill',
  CupertinoIcons.pause_fill: 'pause.fill',
  // CupertinoIcons aliases (share = square_arrow_up, delete = trash,
  // person_add = person_badge_plus, videocam_fill = video_camera_solid)
  // share one key above.
  CupertinoIcons.arrowshape_turn_up_right: 'arrowshape.turn.up.right',
  CupertinoIcons.arrow_2_circlepath: 'arrow.2.circlepath',
  CupertinoIcons.photo_on_rectangle: 'photo.on.rectangle',
  CupertinoIcons.phone_badge_plus: 'phone.badge.plus',
  CupertinoIcons.square_grid_2x2: 'square.grid.2x2',
  CupertinoIcons.camera_rotate: 'camera.rotate',
  CupertinoIcons.rotate_left: 'rotate.left',
  CupertinoIcons.moon: 'moon',
  CupertinoIcons.moon_fill: 'moon.fill',
  CupertinoIcons.bubble_left: 'bubble.left',
  CupertinoIcons.star: 'star',
  CupertinoIcons.star_slash: 'star.slash',
  CupertinoIcons.arrow_down_left: 'arrow.down.left',
  CupertinoIcons.arrow_up_right: 'arrow.up.right',
  CupertinoIcons.sparkles: 'sparkles',
  CupertinoIcons.chevron_up_chevron_down: 'chevron.up.chevron.down',
  CupertinoIcons.eye: 'eye',
  CupertinoIcons.eye_slash: 'eye.slash',
  CupertinoIcons.xmark_circle_fill: 'xmark.circle.fill',
  CupertinoIcons.exclamationmark_circle_fill: 'exclamationmark.circle.fill',
};

/// Structural equality over the wire format: maps, lists and primitives.
bool _specEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_specEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_specEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// The local file of a stored picture, for a native view to draw: the URL
/// from [FileUrlCache], the bytes from the same disk cache the Flutter
/// images use. Null when it cannot be had (offline and never fetched).
Future<String?> nativeImageFile(
  String storageId,
  Future<String?> Function() fetchUrl,
) async {
  try {
    final url = await FileUrlCache.instance.resolve(storageId, fetchUrl);
    if (url == null) return null;
    final file = await MediaImageCache.manager.getSingleFile(url);
    return file.path;
  } catch (_) {
    return null;
  }
}

/// One choice in [showNativeActionSheet].
@immutable
class NativeSheetAction {
  const NativeSheetAction({
    required this.id,
    required this.label,
    this.destructive = false,
    this.cancel = false,
  });

  final String id;
  final String label;
  final bool destructive;
  final bool cancel;
}

/// The system action sheet (an [alert] when asked): a real iOS sheet, Liquid
/// Glass on iOS 26. Use only where [NativeControl.readyIn]; answers the
/// picked action's id, null when dismissed or cancelled.
Future<String?> showNativeActionSheet({
  String title = '',
  String message = '',
  required List<NativeSheetAction> actions,
  bool alert = false,
}) async {
  try {
    return await NativeOverlay._channel.invokeMethod<String>('actionSheet', {
      'title': title,
      'message': message,
      'alert': alert,
      'actions': [
        for (final a in actions)
          {
            'id': a.id,
            'label': a.label,
            'destructive': a.destructive,
            'cancel': a.cancel,
          },
      ],
    });
  } catch (_) {
    return null;
  }
}

/// Marks Flutter chrome that floats above the pages (the call pills) so no
/// native control draws over it: see [NativeOverlay._occluders]. Costs a
/// rect test per native control per frame while mounted, nothing otherwise.
class NativeOccluder extends StatefulWidget {
  const NativeOccluder({super.key, this.enabled = true, required this.child});

  /// Off: covers nothing, but stays in the tree (switching it never
  /// remounts [child]). For chrome that is always mounted and only
  /// sometimes drawn, such as the record bloom, idle over the composer.
  final bool enabled;
  final Widget child;

  @override
  State<NativeOccluder> createState() => _NativeOccluderState();
}

class _NativeOccluderState extends State<NativeOccluder> {
  @override
  void initState() {
    super.initState();
    NativeOverlay._occluders.add(context);
  }

  @override
  void dispose() {
    NativeOverlay._occluders.remove(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The visible card of a route that otherwise only dims (a sheet, a
/// dialog): a native control under the card steps aside to its stand-in;
/// one elsewhere stays native and dims with the scrim. See
/// [_NativeControlState._cover].
class NativeCover extends StatefulWidget {
  const NativeCover({super.key, required this.child});

  final Widget child;

  static final Map<Route<dynamic>, Set<BuildContext>> _byRoute = {};

  static bool _overlaps(Route<dynamic> route, Rect probe) {
    for (final c in _byRoute[route] ?? const <BuildContext>{}) {
      final box = c.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final r = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      if (r.overlaps(probe)) return true;
    }
    return false;
  }

  @override
  State<NativeCover> createState() => _NativeCoverState();
}

class _NativeCoverState extends State<NativeCover> {
  Route<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _leave();
    _route = route;
    if (route != null) {
      (NativeCover._byRoute[route] ??= <BuildContext>{}).add(context);
    }
  }

  void _leave() {
    final r = _route;
    if (r == null) return;
    final set = NativeCover._byRoute[r];
    set?.remove(context);
    if (set != null && set.isEmpty) NativeCover._byRoute.remove(r);
  }

  @override
  void dispose() {
    _leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A Flutter layer drawn above the pages (an overlay's content, e.g. the
/// video-note capture): the [NativeOccluder]s and [NativeScrim]s inside it
/// cover native controls BELOW it, never the ones that sit in it with them
/// (the capture's flip and flash buttons, over its own dim).
class NativeLayer extends StatefulWidget {
  const NativeLayer({super.key, required this.child});

  final Widget child;

  static Object? _of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_NativeLayerScope>()?.id;

  @override
  State<NativeLayer> createState() => _NativeLayerState();
}

class _NativeLayerState extends State<NativeLayer> {
  final Object _id = Object();

  @override
  Widget build(BuildContext context) =>
      _NativeLayerScope(id: _id, child: widget.child);
}

class _NativeLayerScope extends InheritedWidget {
  const _NativeLayerScope({required this.id, required super.child});

  final Object id;

  @override
  bool updateShouldNotify(_NativeLayerScope old) => !identical(old.id, id);
}

/// A Flutter dim drawn over the pages outside any route (a route's barrier
/// is handled already): native controls under it take the same native dim
/// and no touches, instead of staying bright on a darkened screen.
/// [alpha] is the darkening at the top; below [fadeFrom] (a fraction of the
/// scrim's height) it fades linearly to nothing at the bottom, as the
/// gradient it describes does.
class NativeScrim extends StatefulWidget {
  const NativeScrim({
    super.key,
    required this.alpha,
    this.fadeFrom = 1,
    required this.child,
  });

  final double alpha;
  final double fadeFrom;
  final Widget child;

  static final Set<_NativeScrimState> _live = {};

  static double _dimAt(Rect rect, Object? layer) {
    var dim = 0.0;
    for (final s in _live) {
      final a = s.widget.alpha;
      if (a <= 0) continue;
      if (layer != null && identical(NativeLayer._of(s.context), layer)) {
        continue;
      }
      final box = s.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final r = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      if (!r.overlaps(rect) || r.height <= 0) continue;
      final y = ((rect.center.dy - r.top) / r.height).clamp(0.0, 1.0);
      final from = s.widget.fadeFrom;
      final k = y <= from || from >= 1 ? 1.0 : (1 - (y - from) / (1 - from));
      dim = 1 - (1 - dim) * (1 - (a * k).clamp(0.0, 1.0));
    }
    return dim;
  }

  @override
  State<NativeScrim> createState() => _NativeScrimState();
}

class _NativeScrimState extends State<NativeScrim> {
  @override
  void initState() {
    super.initState();
    NativeScrim._live.add(this);
  }

  @override
  void didUpdateWidget(NativeScrim old) {
    super.didUpdateWidget(old);
    if (old.alpha != widget.alpha) SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    NativeScrim._live.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
