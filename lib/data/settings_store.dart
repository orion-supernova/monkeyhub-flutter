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

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _themeId;
  RoomLayout _roomLayout = RoomLayout.list;
  NavStyle _navStyle = NavStyle.radial;
  HomeSection _section = HomeSection.chat;

  String? get themeId => _themeId;
  RoomLayout get roomLayout => _roomLayout;
  NavStyle get navStyle => _navStyle;
  HomeSection get section => _section;

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
