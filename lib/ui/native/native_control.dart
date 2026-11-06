import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../theme/theme_preference.dart';
import '../../theme/theme_scope.dart';
import '../foundation/caps.dart';
import '../foundation/ui_kit.dart';

/// A real iOS control (SwiftUI, Liquid Glass on iOS 26) inside the Flutter
/// tree: the [UiKit.liquid] kit's skins draw with these.
///
/// One `UiKitView` per control, rendered by `ios/Runner/NativeControls.swift`.
/// Dart owns all state: the [spec] goes over on creation and again whenever it
/// changes; what the person does comes back as [onEvent] (`tap`, `changed`,
/// `changeEnd`, `submitted`, `select`, `focus`).
///
/// **Cost.** Any platform view on screen drops every Flutter list to bursts of
/// 60 Hz (flutter/flutter#190815) and doubles a nearby BackdropFilter's cost
/// (#138656). That is why the kit only uses these when
/// [UiKits.nativeControlsReady] is on, and why docs/architecture/
/// ui-architecture.html §4 says which controls should become sibling views
/// (like the native tab bar) instead.
class NativeControl extends StatefulWidget {
  const NativeControl({
    super.key,
    required this.spec,
    this.onEvent,
    this.size,
    this.gestures = const {},
    this.handle,
  });

  /// Lets the owner move focus in a native text field (`focus` / `blur`).
  final NativeControlHandle? handle;

  final NativeSpec spec;
  final void Function(String event, Object? value)? onEvent;

  /// Fixed size. Null sizes to what the control reports (a text button, a
  /// menu label) after its first layout.
  final Size? size;

  /// Gestures the native control must win over an enclosing Flutter
  /// scrollable: a slider or segmented control in a vertical list needs a
  /// horizontal drag; a button needs nothing.
  final Set<Factory<OneSequenceGestureRecognizer>> gestures;

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
/// field. A call made before the platform view exists is replayed once it
/// does (autofocus).
class NativeControlHandle {
  MethodChannel? _channel;
  String? _pending;

  void _attach(MethodChannel? channel) {
    _channel = channel;
    final pending = _pending;
    if (channel != null && pending != null) {
      _pending = null;
      _invoke(pending);
    }
  }

  void _invoke(String method) {
    final channel = _channel;
    if (channel == null) {
      _pending = method;
      return;
    }
    channel.invokeMethod<void>(method).catchError((Object _) {});
  }

  void focus() => _invoke('focus');
  void blur() => _invoke('blur');
}

class _NativeControlState extends State<NativeControl> {
  MethodChannel? _channel;

  /// The spec the native side last received, and the newest one built.
  Map<String, Object?>? _sent;
  Map<String, Object?>? _latest;
  Size? _reported;

  void _push(Map<String, Object?> spec) {
    final channel = _channel;
    if (channel == null || _specEquals(spec, _sent)) return;
    _sent = spec;
    channel.invokeMethod('update', spec).catchError((Object _) {});
  }

  Map<String, Object?> _resolved(BuildContext context) {
    final theme = ThemeScope.of(context);
    return {
      'dark': !theme.isLight,
      'tint': theme.accent.toARGB32(),
      ...widget.spec.toMap(),
    };
  }

  void _created(int id) {
    final channel = MethodChannel('monkeyhub/native_control/$id');
    _channel = channel;
    widget.handle?._attach(channel);
    // A rebuild between creating the view and its channel opening changed
    // the spec the view was created with.
    final latest = _latest;
    if (latest != null) _push(latest);
    channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'size') {
        final m = (call.arguments as Map).cast<String, Object?>();
        final size = Size(
          (m['width'] as num).toDouble(),
          (m['height'] as num).toDouble(),
        );
        if (widget.size == null && size != _reported) {
          setState(() => _reported = size);
        }
        return;
      }
      widget.onEvent?.call(call.method, call.arguments);
    });
  }

  @override
  void didUpdateWidget(NativeControl old) {
    super.didUpdateWidget(old);
    if (old.handle != widget.handle) {
      old.handle?._attach(null);
      widget.handle?._attach(_channel);
    }
  }

  @override
  void dispose() {
    widget.handle?._attach(null);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spec = _latest = _resolved(context);
    _push(spec);
    final size = widget.size ?? _reported ?? const Size(44, 44);
    return SizedBox(
      width: size.width.isFinite ? size.width : null,
      height: size.height,
      child: UiKitView(
        viewType: 'monkeyhub/native_control',
        creationParams: _sent ??= spec,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _created,
        gestureRecognizers: widget.gestures,
      ),
    );
  }
}

/// What a [NativeControl] draws. Built with the named constructors; the map is
/// the wire format `NativeControls.swift` decodes (every field optional there).
@immutable
class NativeSpec {
  const NativeSpec._(this._map);

  final Map<String, Object?> _map;

  Map<String, Object?> toMap() => _map;

  /// The round chrome button: a 44 pt glass circle, a 17 pt SF Symbol.
  factory NativeSpec.symbolButton({
    required String symbol,
    required String label,
    bool prominent = false,
    bool destructive = false,
    bool enabled = true,
    double size = 44,
    double symbolSize = 17,
  }) => NativeSpec._({
    'kind': 'symbolButton',
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
