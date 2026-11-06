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
  });

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

  /// Whether the liquid kit's skins should use native controls right now.
  /// Components pass `liquid: NativeControl.ready ? _native : null` to
  /// [KitSwitch], so with the flag off the liquid kit falls back to glass.
  static bool get ready => UiKits.nativeControlsReady && available;

  @override
  State<NativeControl> createState() => _NativeControlState();
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
  void dispose() {
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

  factory NativeSpec.textField({
    required String text,
    String placeholder = '',
    bool secure = false,
    String? contentType,
    String? keyboard,
    double height = 44,
    double cornerRadius = 22,
    bool enabled = true,
  }) => NativeSpec._({
    'kind': 'textField',
    'text': text,
    'placeholder': placeholder,
    'secure': secure,
    'contentType': ?contentType,
    'keyboard': ?keyboard,
    'size': height,
    'cornerRadius': cornerRadius,
    'enabled': enabled,
  });

  @override
  bool operator ==(Object other) =>
      other is NativeSpec && _specEquals(other._map, _map);

  @override
  int get hashCode => Object.hashAllUnordered(_map.keys);
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
