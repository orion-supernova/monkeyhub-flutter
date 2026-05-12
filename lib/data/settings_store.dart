import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// User-selectable preferences persisted across launches.
///
/// All values live in the platform secure store so they survive reinstall —
/// matches v02's habit of keeping the theme alive across uninstall.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kTheme = 'mh.theme';
  static const _kLayout = 'mh.roomLayout';
  static const _kNav = 'mh.nav';
  static const _kSection = 'mh.section';
  static const _kPushEnabled = 'mh.pushEnabled';
  static const _kCaptureProtection = 'mh.captureProtection';

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _themeId;
  RoomLayout _roomLayout = RoomLayout.list;
  NavStyle _navStyle = NavStyle.radial;
  HomeSection _section = HomeSection.chat;
  bool _pushEnabled = true;
  bool _captureProtection = false;

  String? get themeId => _themeId;
  RoomLayout get roomLayout => _roomLayout;
  NavStyle get navStyle => _navStyle;
  HomeSection get section => _section;
  bool get pushEnabled => _pushEnabled;
  bool get captureProtection => _captureProtection;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _themeId = await _storage.read(key: _kTheme);
      final lay = await _storage.read(key: _kLayout);
      _roomLayout = lay == 'grid' ? RoomLayout.grid : RoomLayout.list;
      final nav = await _storage.read(key: _kNav);
      _navStyle = nav == 'pill' ? NavStyle.pill : NavStyle.radial;
      final sec = await _storage.read(key: _kSection);
      _section = HomeSection.parse(sec);
      final push = await _storage.read(key: _kPushEnabled);
      _pushEnabled = push != 'false'; // default true
      final cap = await _storage.read(key: _kCaptureProtection);
      _captureProtection = cap == 'true'; // default false
    } catch (_) {/* secure storage unavailable in test harness */}
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeId(String id) async {
    if (_themeId == id) return;
    _themeId = id;
    notifyListeners();
    await _storage.write(key: _kTheme, value: id);
  }

  Future<void> setRoomLayout(RoomLayout l) async {
    if (_roomLayout == l) return;
    _roomLayout = l;
    notifyListeners();
    await _storage.write(key: _kLayout, value: l.name);
  }

  Future<void> setNavStyle(NavStyle s) async {
    if (_navStyle == s) return;
    _navStyle = s;
    notifyListeners();
    await _storage.write(key: _kNav, value: s.name);
  }

  Future<void> setSection(HomeSection s) async {
    if (_section == s) return;
    _section = s;
    notifyListeners();
    await _storage.write(key: _kSection, value: s.name);
  }

  Future<void> setPushEnabled(bool v) async {
    if (_pushEnabled == v) return;
    _pushEnabled = v;
    notifyListeners();
    await _storage.write(key: _kPushEnabled, value: v ? 'true' : 'false');
  }

  Future<void> setCaptureProtection(bool v) async {
    if (_captureProtection == v) return;
    _captureProtection = v;
    notifyListeners();
    await _storage.write(key: _kCaptureProtection, value: v ? 'true' : 'false');
  }
}

enum RoomLayout { list, grid }

enum NavStyle { radial, pill }

enum HomeSection {
  chat,
  feed,
  settings;

  static HomeSection parse(String? s) {
    switch (s) {
      case 'feed':
        return HomeSection.feed;
      case 'settings':
        return HomeSection.settings;
      default:
        return HomeSection.chat;
    }
  }
}
