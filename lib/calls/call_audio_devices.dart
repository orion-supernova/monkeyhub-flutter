import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_media.dart';
import 'widgets/call_chrome.dart'
    show CallAudioGlyphRoute, CallGlyphs, CallTrayGlyph;

/// Where a call's sound goes, and the picker that moves it.
///
/// Phones (iOS, Android): the speaker button follows the real output
/// (earpiece, loudspeaker, Bluetooth, a wired headset, a car, AirPlay).
/// With only the earpiece and the speaker it is the toggle it always was;
/// once a headset is a choice it opens a FaceTime-style list of routes.
/// The policy itself (headset wins, a tap on the speaker beats it, a route
/// moved outside the app is adopted) is still [decideCallAudioRoute]'s and
/// the services'; this only names the routes and carries a pick to the
/// native side.
///
/// Desktop and web: no route policy at all (the OS routes), so the control
/// is a microphone and speaker picker over the system's devices.

/// One kind of output, across both phone platforms.
enum CallAudioOutputKind {
  earpiece,
  speaker,
  bluetooth,
  headphones,
  car,
  airplay,
  other,
}

/// The native names for an output: iOS's `CallAudioRouter` (`receiver`,
/// `speaker`, `bluetooth`, `headphones`, `car`, `airplay`, `other`) and
/// flutter_webrtc's Android AudioSwitch type names (`earpiece`, `speaker`,
/// `bluetooth`, `wired-headset`). Null for `none` (no live session) and
/// anything unknown.
CallAudioOutputKind? callAudioOutputKindFrom(String? name) => switch (name) {
      'receiver' || 'earpiece' => CallAudioOutputKind.earpiece,
      'speaker' => CallAudioOutputKind.speaker,
      'bluetooth' => CallAudioOutputKind.bluetooth,
      'headphones' || 'wired-headset' => CallAudioOutputKind.headphones,
      'car' => CallAudioOutputKind.car,
      'airplay' => CallAudioOutputKind.airplay,
      'other' => CallAudioOutputKind.other,
      _ => null,
    };

/// Anything but the phone's own earpiece and loudspeaker.
bool isHeadsetOutput(CallAudioOutputKind? kind) =>
    kind != null &&
    kind != CallAudioOutputKind.earpiece &&
    kind != CallAudioOutputKind.speaker;

/// One row of the phone route sheet.
@immutable
class CallAudioRouteOption {
  const CallAudioRouteOption({
    required this.kind,
    required this.id,
    this.name,
    this.selected = false,
  });

  /// iOS's route map (`kind`, `uid`, `name`, `selected`). Null for a kind
  /// this build does not know.
  static CallAudioRouteOption? fromMap(Map<Object?, Object?> m) {
    final kind = callAudioOutputKindFrom(m['kind']?.toString());
    if (kind == null) return null;
    final name = m['name']?.toString();
    return CallAudioRouteOption(
      kind: kind,
      id: m['uid']?.toString() ?? '',
      name: (name == null || name.isEmpty) ? null : name,
      selected: m['selected'] == true,
    );
  }

  final CallAudioOutputKind kind;

  /// What the native side selects it by. iOS: the input port's UID (the
  /// phone's own mic for the earpiece; empty for the speaker and for an
  /// output with no mic of its own). Android: the AudioSwitch type name.
  final String id;

  /// The device's own name ("Murat's AirPods Pro", "iPhone"), when known.
  final String? name;
  final bool selected;

  bool get isHeadset => isHeadsetOutput(kind);

  CallAudioRouteOption copyWith({bool? selected}) => CallAudioRouteOption(
        kind: kind,
        id: id,
        name: name,
        selected: selected ?? this.selected,
      );

  @override
  bool operator ==(Object other) =>
      other is CallAudioRouteOption &&
      other.kind == kind &&
      other.id == id &&
      other.name == name &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(kind, id, name, selected);

  @override
  String toString() =>
      'CallAudioRouteOption(${kind.name}, $id, $name${selected ? ', selected' : ''})';
}

/// Whether the speaker button opens the route sheet instead of toggling:
/// only when a route other than the earpiece and the speaker exists. With
/// just those two, a list would be a slower toggle.
bool callAudioNeedsPicker(Iterable<CallAudioRouteOption> routes) =>
    routes.any((r) => r.isHeadset);

/// What the phone's speaker button looks like for the real [output] (null
/// while unknown: an older native build, Android before its first report),
/// falling back to the call's [speakerOn] flag.
///
/// Lit whenever the sound is somewhere you chose over the earpiece: the
/// loudspeaker, or a headset (which also shows its own glyph). Only the
/// phone at your ear reads unlit, so the lit state means "the sound is
/// out", the way the lit mic means it is live. [glyph] is the drawn one
/// (speaker waves, headphones); the car, AirPlay and anything else keep
/// their icon.
({IconData icon, bool active, CallTrayGlyph? glyph}) callAudioButtonLook({
  required CallAudioOutputKind? output,
  required bool speakerOn,
  String? name,
}) {
  const speaker = CallTrayGlyph.audio(CallAudioGlyphRoute.speaker);
  const earpiece = CallTrayGlyph.audio(CallAudioGlyphRoute.receiver);
  return switch (output) {
    CallAudioOutputKind.speaker =>
      (icon: CallGlyphs.speakerOn, active: true, glyph: speaker),
    CallAudioOutputKind.earpiece =>
      (icon: CallGlyphs.speakerOff, active: false, glyph: earpiece),
    CallAudioOutputKind.bluetooth => (
        icon: CallGlyphs.routeBluetooth,
        active: true,
        glyph: CallTrayGlyph.audio(callHeadsetGlyphRoute(output, name)),
      ),
    CallAudioOutputKind.headphones => (
        icon: CallGlyphs.routeWired,
        active: true,
        glyph: const CallTrayGlyph.audio(CallAudioGlyphRoute.headphones),
      ),
    CallAudioOutputKind.car =>
      (icon: CallGlyphs.routeCar, active: true, glyph: null),
    CallAudioOutputKind.airplay =>
      (icon: CallGlyphs.routeAirPlay, active: true, glyph: null),
    CallAudioOutputKind.other =>
      (icon: CallGlyphs.routeOther, active: true, glyph: null),
    null => speakerOn
        ? (icon: CallGlyphs.speakerOn, active: true, glyph: speaker)
        : (icon: CallGlyphs.speakerOff, active: false, glyph: earpiece),
  };
}

/// Which headset a drawn glyph shows: AirPods for a Bluetooth set whose
/// name says so ("Murat's AirPods Pro"), headphones for any other.
CallAudioGlyphRoute callHeadsetGlyphRoute(
  CallAudioOutputKind? output,
  String? name,
) =>
    output == CallAudioOutputKind.bluetooth &&
            (name ?? '').toLowerCase().contains('airpods')
        ? CallAudioGlyphRoute.airpods
        : CallAudioGlyphRoute.headphones;

/// The glyph for a row of the route sheet: the earpiece row is the phone
/// itself there, not the quiet speaker the button shows for it.
IconData callAudioRouteGlyph(CallAudioOutputKind kind) => switch (kind) {
      CallAudioOutputKind.earpiece => CallGlyphs.routePhone,
      CallAudioOutputKind.speaker => CallGlyphs.speakerOn,
      CallAudioOutputKind.bluetooth => CallGlyphs.routeBluetooth,
      CallAudioOutputKind.headphones => CallGlyphs.routeWired,
      CallAudioOutputKind.car => CallGlyphs.routeCar,
      CallAudioOutputKind.airplay => CallGlyphs.routeAirPlay,
      CallAudioOutputKind.other => CallGlyphs.routeOther,
    };

/// iOS's live input name ([CallAudioRoute.input]) is a headset's mic.
bool callMicOnHeadset(String? input) => switch (input) {
      'headset' || 'bluetooth' || 'car' => true,
      _ => false,
    };

/// Without an input report: the outputs whose own mic a call uses.
bool callMicFollowsOutput(CallAudioOutputKind? output) => switch (output) {
      CallAudioOutputKind.bluetooth ||
      CallAudioOutputKind.headphones ||
      CallAudioOutputKind.car =>
        true,
      _ => false,
    };

/// Android: the route list from AudioSwitch's devices (flutter_webrtc's
/// `audiooutput` entries: type name as the id, the device's name as the
/// label) and the output in use ([current], a type name; null unknown).
/// AudioSwitch lists the earpiece only on a phone that has one.
@visibleForTesting
List<CallAudioRouteOption> androidRoutesFrom(
  Iterable<({String id, String label})> devices, {
  required String? current,
}) {
  final out = <CallAudioRouteOption>[];
  for (final d in devices) {
    final kind = callAudioOutputKindFrom(d.id);
    if (kind == null || out.any((o) => o.id == d.id)) continue;
    out.add(CallAudioRouteOption(
      kind: kind,
      id: d.id,
      // Only a Bluetooth device's name is its own ("Galaxy Buds2");
      // AudioSwitch's others are fixed English ("Earpiece", "Speakerphone")
      // and the sheet localizes those itself.
      name: kind == CallAudioOutputKind.bluetooth && d.label.isNotEmpty
          ? d.label
          : null,
      selected: d.id == current,
    ));
  }
  // Phone first, then speaker, then the headsets: the order iOS lists them.
  int rank(CallAudioOutputKind k) => switch (k) {
        CallAudioOutputKind.earpiece => 0,
        CallAudioOutputKind.speaker => 1,
        _ => 2,
      };
  out.sort((a, b) => rank(a.kind).compareTo(rank(b.kind)));
  return out;
}

/// The device a desktop/web list should show as checked: the one chosen
/// this session if it is still there, else the browser's `default` entry,
/// else none (the native desktop module names no default).
String? checkedDeviceId(Iterable<MediaDeviceInfo> devices, String? chosen) {
  if (chosen != null && devices.any((d) => d.deviceId == chosen)) {
    return chosen;
  }
  for (final d in devices) {
    if (d.deviceId == 'default') return d.deviceId;
  }
  return null;
}

/// Swaps the web call's microphone for [deviceId]: a new capture on that
/// device, `replaceTrack` on every sender carrying the old one (no
/// renegotiation), and the stream's track swapped in place so a peer
/// connection made later (a group call's late joiner, an ICE restart)
/// sends the new one too. The old track's `enabled` (mute) carries over.
///
/// Web only: on native desktop the audio device module switches the live
/// capture itself (`Helper.selectAudioInput`).
Future<bool> switchWebMicrophone({
  required String deviceId,
  required MediaStream? localStream,
  required Iterable<RTCPeerConnection> peerConnections,
}) async {
  final ls = localStream;
  if (ls == null) return false;
  final old = ls.getAudioTracks();
  final MediaStream fresh;
  try {
    fresh = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'deviceId': {'exact': deviceId},
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    });
  } catch (e) {
    debugPrint('switchWebMicrophone($deviceId) failed: $e');
    return false;
  }
  final tracks = fresh.getAudioTracks();
  if (tracks.isEmpty) return false;
  final track = tracks.first;
  track.enabled = old.isEmpty || old.first.enabled;
  final oldIds = {for (final t in old) t.id};
  for (final pc in peerConnections) {
    try {
      for (final sender in await pc.getSenders()) {
        if (oldIds.contains(sender.track?.id)) await sender.replaceTrack(track);
      }
    } catch (e) {
      debugPrint('switchWebMicrophone replaceTrack: $e');
    }
  }
  for (final t in old) {
    try {
      await ls.removeTrack(t);
      await t.stop();
    } catch (_) {}
  }
  await ls.addTrack(track);
  // Detach before disposing the wrapper, which would stop the track.
  try {
    await fresh.removeTrack(track);
    await fresh.dispose();
  } catch (_) {}
  return true;
}

/// The live audio-device state behind both call screens' audio control.
///
/// One for the app: there is one call audio route at a time. The screens
/// [attach] while up and [detach] on dispose; listening (iOS route pushes,
/// flutter_webrtc's device-change event) runs only while one is attached.
/// The desktop/web choices outlive the screen for the rest of the app's
/// session and are re-applied at the next call.
class CallAudioDevices extends ChangeNotifier {
  CallAudioDevices._();

  static final CallAudioDevices instance = CallAudioDevices._();

  static const _voip = MethodChannel('monkeyhub/voip');
  static const _callWindow = MethodChannel('monkeyhub/call_window');

  // ── Phones ───────────────────────────────────────────────────────────────

  /// The output in use; null while unknown.
  CallAudioOutputKind? get output => _output;
  CallAudioOutputKind? _output;

  /// The output's own name, when the platform gives one.
  String? get outputName => _outputName;
  String? _outputName;

  /// The call's voice is picked up by a headset's mic (AirPods, a wired
  /// set, the car), not the phone's: the mic button wears a headset badge.
  /// iOS says which input is live; Android's AudioSwitch moves the mic with
  /// a Bluetooth or wired output, so the output stands for it there.
  bool get micOnHeadset =>
      _input != null ? callMicOnHeadset(_input) : callMicFollowsOutput(_output);
  String? _input;

  /// What the route sheet lists. Empty: no sheet, the button toggles.
  List<CallAudioRouteOption> get routes => _routes;
  List<CallAudioRouteOption> _routes = const [];

  /// Whether the phone's speaker button should open the sheet.
  bool get needsPicker => callAudioNeedsPicker(_routes);

  // ── Desktop / web ────────────────────────────────────────────────────────

  List<MediaDeviceInfo> get inputs => _inputs;
  List<MediaDeviceInfo> _inputs = const [];
  List<MediaDeviceInfo> get outputs => _outputs;
  List<MediaDeviceInfo> _outputs = const [];

  /// Picked this session; null is the system's default.
  String? get chosenInputId => _chosenInputId;
  String? _chosenInputId;
  String? get chosenOutputId => _chosenOutputId;
  String? _chosenOutputId;

  /// Web: the renderers whose `<audio>` elements play the call, for
  /// `setSinkId`. Registered by the screens.
  final Set<RTCVideoRenderer> _sinks = {};

  /// Changes whenever anything a screen draws from here does, for their
  /// rebuild fingerprints.
  int get revision => _revision;
  int _revision = 0;

  int _attached = 0;
  StreamSubscription<CallAudioRoute>? _routeSub;
  Timer? _refreshTimer;

  static bool get _ios => !kIsWeb && Platform.isIOS;
  static bool get _android => !kIsWeb && Platform.isAndroid;

  /// Desktop or web: the device picker, not the phone route sheet.
  static bool get isDevicePickerPlatform => !isMobileCallPlatform;

  void attach() {
    if (_attached++ > 0) return;
    if (_ios) {
      ensureCallAudioRouteListener();
      _routeSub = callAudioRouteChanges.listen(_onIosRoute);
    } else {
      try {
        navigator.mediaDevices.ondevicechange = (_) => _scheduleRefresh();
      } catch (e) {
        debugPrint('CallAudioDevices: no device-change event: $e');
      }
    }
    unawaited(refresh().then((_) {
      if (isDevicePickerPlatform) unawaited(_reapplyDesktopChoices());
    }));
  }

  void detach() {
    if (_attached == 0 || --_attached > 0) return;
    unawaited(_routeSub?.cancel());
    _routeSub = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!_ios) {
      try {
        navigator.mediaDevices.ondevicechange = null;
      } catch (_) {}
    }
    // The phone route is the call's; the next call reports its own.
    _output = null;
    _outputName = null;
    _input = null;
    _routes = const [];
    _sinks.clear();
    _bump();
  }

  void _bump() {
    _revision++;
    notifyListeners();
  }

  /// A device came or went, or AudioSwitch moved: look again, twice, since
  /// Android's own selection lands a beat after its device-list event.
  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    unawaited(refresh());
    _refreshTimer = Timer(const Duration(milliseconds: 400), () {
      _refreshTimer = null;
      unawaited(refresh());
    });
  }

  /// Reads the current routes or devices from the platform.
  Future<void> refresh() async {
    if (_attached == 0) return;
    try {
      if (_ios) {
        await _refreshIos();
      } else if (_android) {
        await _refreshAndroid();
      } else {
        await _refreshDesktop();
      }
    } catch (e) {
      debugPrint('CallAudioDevices.refresh failed: $e');
    }
  }

  // ── iOS ──────────────────────────────────────────────────────────────────

  Future<void> _refreshIos() async {
    final Object? snap;
    try {
      snap = await _voip.invokeMethod<Object?>('callAudioRoutes');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
    if (snap is! Map) return;
    _applyIosSnapshot(
      output: snap['output']?.toString(),
      portName: snap['portName']?.toString(),
      input: snap['input']?.toString(),
      routes: [
        for (final r in (snap['routes'] as List?) ?? const [])
          if (r is Map) r,
      ],
    );
  }

  void _onIosRoute(CallAudioRoute route) => _applyIosSnapshot(
        output: route.output,
        portName: route.portName,
        input: route.input,
        routes: route.routes,
      );

  void _applyIosSnapshot({
    required String? output,
    required String? portName,
    required String? input,
    required List<Map<Object?, Object?>> routes,
  }) {
    final kind = callAudioOutputKindFrom(output);
    final parsed = [
      for (final r in routes) ?CallAudioRouteOption.fromMap(r),
    ];
    if (kind == _output &&
        portName == _outputName &&
        input == _input &&
        listEquals(parsed, _routes)) {
      return;
    }
    _output = kind;
    _outputName = portName;
    _input = input;
    _routes = parsed;
    _bump();
  }

  // ── Android ──────────────────────────────────────────────────────────────

  Future<void> _refreshAndroid() async {
    final devices = await Helper.enumerateDevices('audiooutput');
    String? current;
    String? name;
    try {
      final now = await _callWindow.invokeMethod<Object?>('audioOutput');
      if (now is Map) {
        current = now['kind']?.toString();
        name = now['name']?.toString();
      }
    } catch (_) {
      // An older native build: no report, the flag stands in.
    }
    final routes = androidRoutesFrom(
      [for (final d in devices) (id: d.deviceId, label: d.label)],
      current: current,
    );
    // A pinned device that went away: let AudioSwitch's own order decide
    // again instead of re-asserting a ghost when it comes back.
    final pin = androidPinnedCallOutput;
    if (pin != null && !routes.any((r) => r.id == pin)) {
      pinAndroidCallOutput(null);
    }
    final kind = callAudioOutputKindFrom(current);
    final label = routes
        .where((r) => r.selected)
        .map((r) => r.name)
        .firstOrNull;
    final outName = isHeadsetOutput(kind) ? (label ?? name) : null;
    if (kind == _output &&
        outName == _outputName &&
        listEquals(routes, _routes)) {
      return;
    }
    _output = kind;
    _outputName = outName;
    _routes = routes;
    _bump();
  }

  // ── Phone selection ──────────────────────────────────────────────────────

  /// Moves the call to [route]. [setSpeaker] is the call service's
  /// `selectSpeaker`: the loudspeaker side goes through the services' one
  /// route writer (so the policy, the flag and the native session stay in
  /// step), and the headset or earpiece pick rides on top of it.
  ///
  /// The microphone follows on both platforms: iOS routes a Bluetooth
  /// headset's mic and speaker together during a call, and choosing the
  /// phone means the phone's mic (`setPreferredInput`). Android's
  /// communication device is likewise one device for both directions.
  Future<void> selectRoute(
    CallAudioRouteOption route, {
    required Future<void> Function(bool on) setSpeaker,
  }) async {
    final toSpeaker = route.kind == CallAudioOutputKind.speaker;
    // Answer on the tap; the next report confirms or corrects it.
    _routes = [
      for (final r in _routes) r.copyWith(selected: r == route),
    ];
    _output = route.kind;
    _outputName = route.isHeadset ? route.name : null;
    // The mic follows the pick until the platform says otherwise.
    _input = null;
    _bump();
    if (_ios) {
      await setSpeaker(toSpeaker);
      if (!toSpeaker) {
        try {
          await _voip.invokeMethod<bool>('selectCallAudioInput', {
            'uid': route.id.isEmpty ? null : route.id,
          });
        } catch (e) {
          debugPrint('CallAudioDevices: selectCallAudioInput failed: $e');
        }
      }
      unawaited(refresh());
    } else if (_android) {
      pinAndroidCallOutput(toSpeaker ? null : route.id);
      await setSpeaker(toSpeaker);
      _scheduleRefresh();
    }
  }

  // ── Desktop / web ────────────────────────────────────────────────────────

  Future<void> _refreshDesktop() async {
    final all = await navigator.mediaDevices.enumerateDevices();
    final ins = [for (final d in all) if (d.kind == 'audioinput') d];
    final outs = [for (final d in all) if (d.kind == 'audiooutput') d];
    final changed = !_sameDevices(ins, _inputs) || !_sameDevices(outs, _outputs);
    final hadIn = _inputs.any((d) => d.deviceId == _chosenInputId);
    final hadOut = _outputs.any((d) => d.deviceId == _chosenOutputId);
    _inputs = ins;
    _outputs = outs;
    if (changed) {
      _bump();
      // Hot-plug on native desktop: a chosen device that came back is
      // taken again; one that went away hands over to the first one left,
      // since the audio module may otherwise keep a dead device.
      final hasOut = outs.any((d) => d.deviceId == _chosenOutputId);
      if (!kIsWeb) {
        final hasIn = ins.any((d) => d.deviceId == _chosenInputId);
        if (_chosenInputId != null && hasIn != hadIn) {
          final id = hasIn ? _chosenInputId : ins.firstOrNull?.deviceId;
          if (id != null) unawaited(_nativeSelectInput(id));
        }
        if (_chosenOutputId != null && hasOut != hadOut) {
          final id = hasOut ? _chosenOutputId : outs.firstOrNull?.deviceId;
          if (id != null) unawaited(_nativeSelectOutput(id));
        }
      } else if (_chosenOutputId != null && hasOut != hadOut) {
        unawaited(reapplyWebSink());
      }
    }
  }

  static bool _sameDevices(List<MediaDeviceInfo> a, List<MediaDeviceInfo> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].deviceId != b[i].deviceId || a[i].label != b[i].label) {
        return false;
      }
    }
    return true;
  }

  /// Whether the speaker section can be offered. Web: only where the
  /// browser lists outputs, which is where `setSinkId` exists (Chromium;
  /// Safari lists none and cannot route).
  bool get outputSelectable => _outputs.isNotEmpty;

  /// Takes [deviceId] as the microphone. [switchWeb] does the web swap
  /// (it needs the call's stream and connections; see
  /// [switchWebMicrophone]).
  Future<bool> selectInput(
    String deviceId, {
    Future<bool> Function(String deviceId)? switchWeb,
  }) async {
    final previous = _chosenInputId;
    _chosenInputId = deviceId;
    _bump();
    final bool ok;
    if (kIsWeb) {
      ok = switchWeb == null ? false : await switchWeb(deviceId);
    } else {
      ok = await _nativeSelectInput(deviceId);
    }
    if (!ok) {
      _chosenInputId = previous;
      _bump();
    }
    return ok;
  }

  /// Takes [deviceId] as the speaker.
  Future<bool> selectOutput(String deviceId) async {
    final previous = _chosenOutputId;
    _chosenOutputId = deviceId;
    _bump();
    final ok = kIsWeb
        ? await reapplyWebSink()
        : await _nativeSelectOutput(deviceId);
    if (!ok) {
      _chosenOutputId = previous;
      _bump();
    }
    return ok;
  }

  Future<bool> _nativeSelectInput(String id) async {
    try {
      await Helper.selectAudioInput(id);
      return true;
    } catch (e) {
      debugPrint('CallAudioDevices: selectAudioInput($id) failed: $e');
      return false;
    }
  }

  Future<bool> _nativeSelectOutput(String id) async {
    try {
      await Helper.selectAudioOutput(id);
      return true;
    } catch (e) {
      debugPrint('CallAudioDevices: selectAudioOutput($id) failed: $e');
      return false;
    }
  }

  /// A new call on desktop: the session's earlier picks, applied again
  /// where the devices still exist. Web's mic is the call's own capture,
  /// so only the sink applies there; the mic comes back on the next pick.
  Future<void> _reapplyDesktopChoices() async {
    if (kIsWeb) {
      await reapplyWebSink();
      return;
    }
    final inId = _chosenInputId;
    if (inId != null && _inputs.any((d) => d.deviceId == inId)) {
      await _nativeSelectInput(inId);
    }
    final outId = _chosenOutputId;
    if (outId != null && _outputs.any((d) => d.deviceId == outId)) {
      await _nativeSelectOutput(outId);
    }
  }

  /// Web: the renderers that play the call's audio. Their `<audio>`
  /// element exists once a stream is bound, so the screens call
  /// [reapplyWebSink] after binding.
  void registerWebSinks(Iterable<RTCVideoRenderer> renderers) {
    if (!kIsWeb) return;
    _sinks.addAll(renderers);
  }

  void unregisterWebSinks(Iterable<RTCVideoRenderer> renderers) {
    _sinks.removeAll(renderers);
  }

  /// Points every registered renderer at the chosen speaker. True when at
  /// least one took it (or there is nothing to point yet).
  Future<bool> reapplyWebSink() async {
    final id = _chosenOutputId;
    if (!kIsWeb || id == null) return true;
    if (_sinks.isEmpty) return true;
    var any = false;
    for (final r in _sinks.toList()) {
      try {
        if (await r.audioOutput(id)) any = true;
      } catch (_) {}
    }
    return any;
  }
}
