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
    final id = 'nc${_nextId++}';
    _controls[id] = state;
    // A control that registers between frames is placed after the next one.
    SchedulerBinding.instance.ensureVisualUpdate();
    return id;
  }

  static void _unregister(String id) {
    _controls.remove(id);
    _call('remove', {'id': id});
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

  void _push(Map<String, Object?> spec) {
    if (_specEquals(spec, _sent)) return;
    _sent = spec;
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
  Map<String, Object?>? _placement() {
    final box = context.findRenderObject();
    String? why;
    if (!mounted || box is! RenderBox || !box.attached || !box.hasSize) {
      why = 'unlaid';
    } else if (!_tickerOn) {
      why = 'ticker';
    } else if (NativeOverlay.suppressed.value != 0) {
      why = 'suppressed';
    } else if (!_routeSettled()) {
      why = 'route';
    }
    Rect rect = Rect.zero;
    Rect clip = Rect.zero;
    if (why == null) {
      final b = box as RenderBox;
      rect = MatrixUtils.transformRect(
        b.getTransformTo(null),
        Offset.zero & b.size,
      );
      clip = _clip(rect);
      if (clip.isEmpty) why = 'clipped';
    }
    final visible = why == null;
    final placement = <String, Object?>{
      'x': _r(rect.left),
      'y': _r(rect.top),
      'w': _r(rect.width),
      'h': _r(rect.height),
      'cx': _r(clip.left),
      'cy': _r(clip.top),
      'cw': _r(clip.width),
      'ch': _r(clip.height),
      'visible': visible,
      'why': ?why,
    };
    if (_specEquals(placement, _lastPlacement)) return null;
    _lastPlacement = placement;
    // Hiding is immediate on this side: the stand-in shows the same frame.
    if (!visible && _revealed) setState(() => _revealed = false);
    return placement;
  }

  static double _r(double v) => (v * 2).roundToDouble() / 2;

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
    NativeOverlay._unregister(_id);
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
      child: _revealed || standIn == null
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
  }) => NativeSpec._({
    'kind': 'symbolButton',
    'passthrough': passthrough,
    'symbol': symbol,
    'label': label,
    'prominent': prominent,
    'destructive': destructive,
    'enabled': enabled,
    'size': size,
    'symbolSize': symbolSize,
  });

  /// A labelled glass button; [prominent] is the tinted primary action.
  factory NativeSpec.button({
    required String label,
    String? symbol,
    bool prominent = false,
    bool destructive = false,
    bool enabled = true,
    bool fill = false,
    double height = 50,
  }) => NativeSpec._({
    'kind': 'button',
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
