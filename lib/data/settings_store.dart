import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/launcher_icon_service.dart';
import '../theme/theme_scope.dart';

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
  static const _kChatStyle = 'mh.chatStyle';
  static const _kReplyStyle = 'mh.replyStyle';
  static const _kViewReadReceipts = 'mh.viewReadReceipts';
  static const _kLogoMode = 'mh.logoMode';
  static const _kManualLogoThemeId = 'mh.manualLogoThemeId';
  static const _kShowLinkUrls = 'mh.showLinkUrls';
  static const _kFullScreenIntentPrompted = 'mh.fullScreenIntentPrompted';
  static const _kBatteryOptPrompted = 'mh.batteryOptPrompted';

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
  );

  String? _themeId;
  RoomLayout _roomLayout = RoomLayout.list;
  NavStyle _navStyle = NavStyle.pill;
  HomeSection _section = HomeSection.chat;
  bool _pushEnabled = true;
  bool _captureProtection = false;
  ChatStyle _chatStyle = ChatStyle.compact;
  ReplyStyle _replyStyle = ReplyStyle.phantomEcho;
  bool _viewReadReceipts = false;
  LogoMode _logoMode = LogoMode.auto;
  String? _manualLogoThemeId;
  bool _showLinkUrls = false;
  bool _fullScreenIntentPrompted = false;
  bool _batteryOptPrompted = false;

  String? get themeId => _themeId;
  RoomLayout get roomLayout => _roomLayout;
  NavStyle get navStyle => _navStyle;
  HomeSection get section => _section;
  bool get pushEnabled => _pushEnabled;
  bool get captureProtection => _captureProtection;
  ChatStyle get chatStyle => _chatStyle;
  ReplyStyle get replyStyle => _replyStyle;
  LogoMode get logoMode => _logoMode;
  String? get manualLogoThemeId => _manualLogoThemeId;

  /// When `true`, raw URL text remains visible inline alongside the link
  /// preview card. Default `false` — the preview alone communicates the
  /// link, and keeping the URL text out makes mixed messages read clean.
  bool get showLinkUrls => _showLinkUrls;

  /// When false (default), the "SEEN" indicator on the user's own messages is
  /// suppressed even if read-state data flows in. Off by default — opt-in.
  /// Even when on, only contributors whose `seen` visibility allows it will
  /// surface; see [profile_visibility_screen] for the inbound warning.
  bool get viewReadReceipts => _viewReadReceipts;

  /// One-time Android call-reliability prompts (full-screen-intent access and
  /// battery-optimization exemption). Tracked so the user is asked exactly
  /// once — both remain reachable from system settings if declined.
  bool get fullScreenIntentPrompted => _fullScreenIntentPrompted;
  bool get batteryOptPrompted => _batteryOptPrompted;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _themeId = await _storage.read(key: _kTheme);
      final lay = await _storage.read(key: _kLayout);
      _roomLayout = lay == 'grid' ? RoomLayout.grid : RoomLayout.list;
      final nav = await _storage.read(key: _kNav);
      // First-launch default is pill; honor an explicit 'radial' selection.
      _navStyle = nav == 'radial' ? NavStyle.radial : NavStyle.pill;
      final sec = await _storage.read(key: _kSection);
      _section = HomeSection.parse(sec);
      final push = await _storage.read(key: _kPushEnabled);
      _pushEnabled = push != 'false'; // default true
      final cap = await _storage.read(key: _kCaptureProtection);
      _captureProtection = cap == 'true'; // default false
      final cs = await _storage.read(key: _kChatStyle);
      // 'liquid' was the legacy name for compact — preserve the choice for
      // anyone who had selected it before the rename.
      _chatStyle = cs == 'classic' ? ChatStyle.classic : ChatStyle.compact;
      final rs = await _storage.read(key: _kReplyStyle);
      switch (rs) {
        case 'stickyNote':
          _replyStyle = ReplyStyle.stickyNote;
          break;
        case 'comicTail':
          _replyStyle = ReplyStyle.comicTail;
          break;
        case 'classic':
          _replyStyle = ReplyStyle.classic;
          break;
        default:
          _replyStyle = ReplyStyle.phantomEcho;
      }
      final vrr = await _storage.read(key: _kViewReadReceipts);
      _viewReadReceipts = vrr == 'true'; // default false
      final lm = await _storage.read(key: _kLogoMode);
      switch (lm) {
        case 'manual':
          _logoMode = LogoMode.manual;
          break;
        case 'alwaysDefault':
          _logoMode = LogoMode.alwaysDefault;
          break;
        default:
          _logoMode = LogoMode.auto;
      }
      _manualLogoThemeId = await _storage.read(key: _kManualLogoThemeId);
      final slu = await _storage.read(key: _kShowLinkUrls);
      _showLinkUrls = slu == 'true'; // default false
      _fullScreenIntentPrompted =
          await _storage.read(key: _kFullScreenIntentPrompted) == 'true';
      _batteryOptPrompted =
          await _storage.read(key: _kBatteryOptPrompted) == 'true';
    } catch (_) {/* secure storage unavailable in test harness */}
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeId(String id) async {
    if (_themeId == id) return;
    _themeId = id;
    notifyListeners();
    await _storage.write(key: _kTheme, value: id);
    _applyLauncherIcon();
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

  Future<void> setChatStyle(ChatStyle s) async {
    if (_chatStyle == s) return;
    _chatStyle = s;
    notifyListeners();
    await _storage.write(key: _kChatStyle, value: s.name);
  }

  Future<void> setReplyStyle(ReplyStyle s) async {
    if (_replyStyle == s) return;
    _replyStyle = s;
    notifyListeners();
    await _storage.write(key: _kReplyStyle, value: s.name);
  }

  Future<void> setViewReadReceipts(bool v) async {
    if (_viewReadReceipts == v) return;
    _viewReadReceipts = v;
    notifyListeners();
    await _storage.write(key: _kViewReadReceipts, value: v ? 'true' : 'false');
  }

  Future<void> setLogoMode(LogoMode m) async {
    if (_logoMode == m) return;
    _logoMode = m;
    notifyListeners();
    await _storage.write(key: _kLogoMode, value: m.name);
    _applyLauncherIcon();
  }

  Future<void> setShowLinkUrls(bool v) async {
    if (_showLinkUrls == v) return;
    _showLinkUrls = v;
    notifyListeners();
    await _storage.write(key: _kShowLinkUrls, value: v ? 'true' : 'false');
  }

  Future<void> markFullScreenIntentPrompted() async {
    if (_fullScreenIntentPrompted) return;
    _fullScreenIntentPrompted = true;
    await _storage.write(key: _kFullScreenIntentPrompted, value: 'true');
  }

  Future<void> markBatteryOptPrompted() async {
    if (_batteryOptPrompted) return;
    _batteryOptPrompted = true;
    await _storage.write(key: _kBatteryOptPrompted, value: 'true');
  }

  Future<void> setManualLogoThemeId(String id) async {
    if (_manualLogoThemeId == id) return;
    _manualLogoThemeId = id;
    notifyListeners();
    await _storage.write(key: _kManualLogoThemeId, value: id);
    _applyLauncherIcon();
  }

  /// Fire-and-forget native launcher-icon swap. Reads the resolved icon name
  /// from the current store state; safe to call from any setter. Awaiting
  /// would block the UI on a non-essential side effect.
  void _applyLauncherIcon() {
    final active = ThemeController.byId(_themeId ?? ThemeController.all.first.id);
    LauncherIconService.applyFromSettings(active);
  }
}

enum RoomLayout { list, grid }

enum NavStyle { radial, pill }

enum ChatStyle { classic, compact }

/// Visual style for the inline reply indicator. User-selectable via settings.
///
/// * `phantomEcho` (default) — ghost-bubble above with a curved connector
///   and a branch icon at the join point.
/// * `stickyNote` — rotated polaroid clipped to the bubble corner.
/// * `comicTail` — mini parent bubble with a downward-pointing comic-book
///   triangle tail.
/// * `classic` — accent-tinted inset row with tether bar, avatar, mono-caps
///   header, and content snippet. The original quote-pill look.
enum ReplyStyle { phantomEcho, stickyNote, comicTail, classic }

enum LogoMode { auto, manual, alwaysDefault }

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
