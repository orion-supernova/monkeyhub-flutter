import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The macOS menu-bar item's on/off switch, as seen from Dart.
///
/// The preference itself lives in native `UserDefaults` (see
/// `AppChrome.menuBarVisible`, macos/Runner/AppChrome.swift) rather than in
/// [SettingsStore]. It has to be readable during
/// `applicationDidFinishLaunching`, which is long before the engine has booted
/// and could be asked anything — and a menu-bar icon that pops into place a
/// second after launch, every launch, reads as a glitch. So this class is a
/// remote control for that value rather than a second copy of it, and it
/// re-reads on every [load] instead of trusting what it wrote last: macOS lets
/// the user ⌘-drag the item off the menu bar, and that gesture changes the
/// preference without passing through here.
class MacAppChrome extends ChangeNotifier {
  MacAppChrome._();
  static final MacAppChrome instance = MacAppChrome._();

  static const _ch = MethodChannel('monkeyhub/desktop');

  /// `kIsWeb` first, and that ordering is the whole reason this isn't a
  /// `Platform.isMacOS` check: on Flutter web `defaultTargetPlatform` is
  /// derived from the user agent, so Safari on a Mac reports `macOS` — and
  /// there is no menu bar to put anything in.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  bool? _visible;

  /// Null until [load] has answered. The settings row renders nothing at all
  /// in that window rather than guessing a default, so the switch never flips
  /// under the reader a frame after they open the screen.
  bool? get visible => _visible;

  Future<void> load() async {
    if (!isSupported) return;
    try {
      final value = await _ch.invokeMethod<bool>('getMenuBarVisible');
      if (value == null || value == _visible) return;
      _visible = value;
      notifyListeners();
    } catch (e) {
      // An older Runner without the channel. Leaving [visible] null keeps the
      // row hidden, which is the right outcome: there is nothing to control.
      debugPrint('MacAppChrome.load failed: $e');
    }
  }

  /// Optimistic — the switch moves on the tap, not on the round trip. The
  /// native side is in this same process and cannot meaningfully fail; if it
  /// somehow does, the next [load] corrects the switch.
  Future<void> setVisible(bool value) async {
    if (!isSupported || value == _visible) return;
    _visible = value;
    notifyListeners();
    try {
      await _ch.invokeMethod('setMenuBarVisible', {'visible': value});
    } catch (e) {
      debugPrint('MacAppChrome.setVisible failed: $e');
    }
  }
}
