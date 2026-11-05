import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A screen that holds still while the phone turns, the way WhatsApp's and
/// the system camera do: the layout stays portrait, and only the things that
/// have an "up" (glyphs, thumbnails) turn in place to stay upright.
///
/// Three pieces, kept together because they must agree on one convention:
///
///  * [quarterTurnsFor]: how far content must turn, clockwise, to sit upright
///    in a portrait-locked layout while the device is held [o]. The same map
///    the camera plugin's own `CameraPreview` applies on Android, so the live
///    preview and the glyphs over it can never disagree about which way is up.
///  * [glyphTurnsFor]: the turn a glyph needs, which is the opposite one.
///  * [DeviceTurn]: the glyphs' answer, handed down the tree.
///  * [TurnWithDevice]: turns its child by it, animated the short way round.

/// Clockwise quarter turns that keep content upright in a portrait-locked
/// layout while the device is physically held [o].
int quarterTurnsFor(DeviceOrientation o) => switch (o) {
  DeviceOrientation.portraitUp => 0,
  DeviceOrientation.landscapeRight => 1,
  DeviceOrientation.portraitDown => 2,
  DeviceOrientation.landscapeLeft => 3,
};

/// Clockwise quarter turns that keep a GLYPH upright in a portrait-locked
/// layout while the device is physically held [o]: the opposite of
/// [quarterTurnsFor].
///
/// The two are not the same question. [quarterTurnsFor] is the plugin's
/// preview convention, a correction for how the sensor's frames arrive, and
/// it is right for the picture. A glyph has no frames, only the screen under
/// it: the phone turned a quarter one way, so the glyph turns a quarter the
/// other way to stay level with the world. `DeviceOrientation.landscapeLeft`
/// is the phone's top on the left (turned counter-clockwise), so the glyph
/// turns one quarter clockwise. Sharing the preview's map is what made every
/// button on the camera spin the wrong way, ending up upside down.
int glyphTurnsFor(DeviceOrientation o) => (4 - quarterTurnsFor(o)) % 4;

/// [p], a point normalised to a portrait-locked layout, in the frame of a
/// layout that had turned with the device: what an API that assumes the UI
/// rotates (iOS's camera focus point) expects to be handed. The inverse of
/// turning by [quarterTurns] clockwise, applied one turn at a time.
Offset unturnNormalised(Offset p, int quarterTurns) {
  var q = p;
  for (var i = 0; i < quarterTurns % 4; i++) {
    q = Offset(q.dy, 1 - q.dx);
  }
  return q;
}

/// Whether this device's screens should hold portrait rather than reflow: a
/// phone. A tablet has room for a real landscape layout and keeps it; desktop
/// and web windows are not held a way up at all.
bool holdsPortrait(BuildContext context) {
  if (kIsWeb) return false;
  final mobile = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;
  return mobile && MediaQuery.sizeOf(context).shortestSide < 600;
}

/// The quarter turns [TurnWithDevice] reads. Absent means upright.
class DeviceTurn extends InheritedWidget {
  const DeviceTurn({
    super.key,
    required this.quarterTurns,
    required super.child,
  });

  final int quarterTurns;

  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DeviceTurn>()?.quarterTurns ??
      0;

  @override
  bool updateShouldNotify(DeviceTurn oldWidget) =>
      oldWidget.quarterTurns != quarterTurns;
}

/// Turns [child] to stay upright as the device turns, per the nearest
/// [DeviceTurn]. Paint-only (no relayout), so a square glyph or thumbnail
/// turns inside its own slot and nothing around it moves.
///
/// Always the short way round: from landscape-left to portrait is a quarter
/// turn back, never three quarters forward.
class TurnWithDevice extends StatefulWidget {
  const TurnWithDevice({super.key, required this.child});

  final Widget child;

  @override
  State<TurnWithDevice> createState() => _TurnWithDeviceState();
}

class _TurnWithDeviceState extends State<TurnWithDevice> {
  /// Accumulated, so the animation can run past a whole turn either way.
  double? _turns;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final target = DeviceTurn.of(context);
    final cur = _turns;
    if (cur == null) {
      _turns = target / 4;
      return;
    }
    final now = (cur * 4).round();
    var delta = (target - now) % 4; // 0..3
    if (delta == 3) delta = -1;
    _turns = (now + delta) / 4;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: _turns ?? 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );
  }
}
