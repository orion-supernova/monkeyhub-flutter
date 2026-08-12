import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../calls/call_models.dart' show VideoQualityTier, VideoQualityTierWire;
import '../services/launcher_icon_service.dart';
import '../theme/bubble_shape.dart';
import '../theme/theme_scope.dart';
import 'glass_config.dart';
import 'room_filter.dart';

/// User-selectable preferences persisted across launches.
///
/// All values live in the platform secure store so they survive reinstall —
/// matches v02's habit of keeping the theme alive across uninstall.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kTheme = 'mh.theme';
  static const _kLayout = 'mh.roomLayout';
  static const _kMonogram = 'mh.roomMonogram';
  static const _kNav = 'mh.nav';
  static const _kSection = 'mh.section';
  static const _kPushEnabled = 'mh.pushEnabled';
  static const _kCaptureProtection = 'mh.captureProtection';
  static const _kChatStyle = 'mh.chatStyle';
  static const _kReplyStyle = 'mh.replyStyle';
  static const _kBubbleStyle = 'mh.bubbleStyle';
  static const _kViewReadReceipts = 'mh.viewReadReceipts';
  static const _kLogoMode = 'mh.logoMode';
  static const _kManualLogoThemeId = 'mh.manualLogoThemeId';
  static const _kShowLinkUrls = 'mh.showLinkUrls';
  static const _kShowNetworkStats = 'mh.showNetworkStats';
  static const _kVideoQualityTier = 'mh.videoQualityTier';
  // NOTE: 'mh.fullScreenIntentPrompted', 'mh.batteryOptPrompted' and
  // 'mh.micPermissionPrompted' were retired with the Android onboarding
  // prompts they gated. Their values are left on disk rather than migrated
  // away — they cost three unread booleans, and reusing either name later
  // would silently inherit a "yes, already asked" from an install that was
  // asked by the old flow. Pick new keys if a prompt ever comes back.
  static const _kRecoveryPromptDismissed = 'mh.recoveryPromptDismissedFor';
  static const _kFilterStyle = 'mh.filterStyle';
  static const _kRoomFilter = 'mh.roomFilter';
  static const _kGlassProfile = 'mh.glass.profile';
  static const _kGlassSlots = 'mh.glass.slots';
  static const _kGlassPreset = 'mh.glass.preset';
  static const _kLocale = 'mh.locale';
  static const _kMotionLevel = 'mh.motionLevel';
  static const _kScheduledIndicator = 'mh.schedule.indicator';

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
  );

  String? _themeId;
  RoomLayout _roomLayout = RoomLayout.list;
  // Off by default: the letter is a backdrop for a room with nothing to
  // show, and whether it reads as texture or as clutter is a matter of
  // taste rather than of layout.
  bool _roomMonogram = false;
  NavStyle _navStyle = NavStyle.pill;
  HomeSection _section = HomeSection.chat;
  bool _pushEnabled = true;
  bool _captureProtection = false;
  ChatStyle _chatStyle = ChatStyle.compact;
  ReplyStyle _replyStyle = ReplyStyle.phantomEcho;
  BubbleStyle _bubbleStyle = BubbleStyle.tailed;
  bool _viewReadReceipts = false;
  LogoMode _logoMode = LogoMode.auto;
  String? _manualLogoThemeId;
  bool _showLinkUrls = false;
  bool _showNetworkStats = false;
  VideoQualityTier _videoQualityTier = VideoQualityTier.auto;
  String? _recoveryPromptDismissedFor;
  FilterStyle _filterStyle = FilterStyle.chips;
  RoomFilter _roomFilter = RoomFilter.empty;
  GlassProfile _glass = _presetById(kDefaultGlassPresetId).profile;
  List<GlassPreset> _glassSlots = const [];
  String? _glassPresetId = kDefaultGlassPresetId;
  // Null means "follow the system language" (constrained to a supported
  // locale by app.dart's localeListResolutionCallback). A saved 'en'/'tr'
  // overrides the system, letting a user run the app in a language other
  // than their device's — e.g. practicing Turkish, or a shared family
  // handset where members prefer different languages.
  String? _localeCode;

  // Null means "follow the OS accessibility setting" — see [motionLevel].
  MotionLevel? _motionLevel;
  ScheduledIndicator _scheduledIndicator = ScheduledIndicator.pill;

  String? get themeId => _themeId;
  RoomLayout get roomLayout => _roomLayout;
  bool get roomMonogram => _roomMonogram;
  NavStyle get navStyle => _navStyle;
  HomeSection get section => _section;
  bool get pushEnabled => _pushEnabled;
  bool get captureProtection => _captureProtection;
  ChatStyle get chatStyle => _chatStyle;
  ReplyStyle get replyStyle => _replyStyle;

  /// The shape family every message bubble is drawn with. Defaults to
  /// [BubbleStyle.tailed] — a run of messages closes with a curved tail.
  BubbleStyle get bubbleStyle => _bubbleStyle;
  LogoMode get logoMode => _logoMode;
  String? get manualLogoThemeId => _manualLogoThemeId;

  /// When `true`, raw URL text remains visible inline alongside the link
  /// preview card. Default `false` — the preview alone communicates the
  /// link, and keeping the URL text out makes mixed messages read clean.
  bool get showLinkUrls => _showLinkUrls;

  /// When `true`, the in-call warning chip expands into a live numeric
  /// stats panel (bitrate, RTT, loss, jitter, resolution/fps) instead of
  /// just a "poor/weak connection" label — and shows even when the
  /// connection is good, not only when degraded. Default `false`. Also
  /// toggleable from an icon inside the call view itself — same setting,
  /// reachable from both places.
  bool get showNetworkStats => _showNetworkStats;

  /// Resolution ceiling for outgoing video on both the 1:1 and group call
  /// paths. Default `auto` — today's long-standing 720p/adaptive behavior,
  /// unchanged unless the user opts into a higher tier. Also switchable from
  /// inside the call view; both write here.
  VideoQualityTier get videoQualityTier => _videoQualityTier;

  /// When false (default), the "SEEN" indicator on the user's own messages is
  /// suppressed even if read-state data flows in. Off by default — opt-in.
  /// Even when on, only contributors whose `seen` visibility allows it will
  /// surface; see [profile_visibility_screen] for the inbound warning.
  bool get viewReadReceipts => _viewReadReceipts;

  /// The userId that declined the "set up a recovery phrase" prompt.
  ///
  /// Stores an ID rather than a bool because two accounts can share a handset,
  /// and one of them declining must not silence the prompt for the other.
  ///
  /// Deliberately lives here and NOT in SessionStore: `clearSession()` wipes
  /// its keys on every sign-out, so a dismissal stored there would evaporate
  /// and the user would be re-prompted on every single sign-in. SettingsStore
  /// is never cleared. That difference is the whole reason for the split.
  String? get recoveryPromptDismissedFor => _recoveryPromptDismissedFor;

  /// How much decorative motion the app renders.
  ///
  /// `null` (the default) means "follow the OS" — iOS Reduce Motion / Android
  /// Remove Animations, read through `MediaQuery.disableAnimations`. An
  /// explicit value overrides the OS **in both directions**, so someone who
  /// turned the system flag on for a different app can still opt this one back
  /// into full motion, and someone who just finds the board busy can calm it
  /// without touching a system setting.
  ///
  /// Tri-state rather than a bool for exactly that reason: a bare bool cannot
  /// express "I have not chosen" separately from "I chose the same thing the OS
  /// happens to say today", so the first time the OS flag flipped the user's
  /// choice would be silently overwritten.
  ///
  /// Resolve it with [MotionScope.of] — never read this getter directly in a
  /// widget, or the OS half of the contract is lost.
  MotionLevel? get motionLevel => _motionLevel;

  /// How a room announces that it is holding messages you have not sent yet.
  ///
  /// Non-nullable, unlike [motionLevel]: there is no OS preference to defer to,
  /// so "not chosen" is simply the default rather than a third state.
  ScheduledIndicator get scheduledIndicator => _scheduledIndicator;

  /// Which control the chat list uses to filter rooms. Defaults to
  /// [FilterStyle.chips] — the filters are worth a permanent row, and a control
  /// you have to open first is a control most people never find.
  FilterStyle get filterStyle => _filterStyle;

  /// Active chat-list filter. Persisted, so a cold start can open onto a
  /// filtered — possibly empty — list. The chat screen therefore always renders
  /// an active-filter cue and a one-tap "show all" escape when this is set.
  RoomFilter get roomFilter => _roomFilter;

  /// Live glass tuning — what every [LiquidGlass] and the bottom bar actually
  /// render with right now. Not necessarily equal to any saved preset: moving
  /// a slider edits this and clears [glassPresetId].
  GlassProfile get glass => _glass;

  /// The user's saved looks, newest last. Built-ins are not in here — see
  /// [glassPresets] for the full list as the panel shows it.
  List<GlassPreset> get glassSlots => List.unmodifiable(_glassSlots);

  /// Built-ins first, then saved slots.
  List<GlassPreset> get glassPresets => [
    ...kBuiltInGlassPresets,
    ..._glassSlots,
  ];

  /// Which preset [glass] came from, or null once a dial has been moved away
  /// from it — the panel shows that as "Custom", and it is the state the "save
  /// current as…" action exists to name.
  String? get glassPresetId => _glassPresetId;

  bool get glassSlotsFull => _glassSlots.length >= kMaxGlassSlots;

  /// 'en', 'tr', or null to follow the system language.
  String? get localeCode => _localeCode;

  static GlassPreset _presetById(String? id) => kBuiltInGlassPresets.firstWhere(
    (p) => p.id == id,
    orElse: () => kBuiltInGlassPresets.first,
  );

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      _themeId = await _storage.read(key: _kTheme);
      final lay = await _storage.read(key: _kLayout);
      _roomLayout = lay == 'grid' ? RoomLayout.grid : RoomLayout.list;
      final mono = await _storage.read(key: _kMonogram);
      _roomMonogram = mono == 'true'; // default false
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
      final bs = await _storage.read(key: _kBubbleStyle);
      switch (bs) {
        case 'soft':
          _bubbleStyle = BubbleStyle.soft;
          break;
        case 'pill':
          _bubbleStyle = BubbleStyle.pill;
          break;
        case 'slab':
          _bubbleStyle = BubbleStyle.slab;
          break;
        default:
          _bubbleStyle = BubbleStyle.tailed;
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
      final sns = await _storage.read(key: _kShowNetworkStats);
      _showNetworkStats = sns == 'true'; // default false
      _videoQualityTier = VideoQualityTierWire.parse(
        await _storage.read(key: _kVideoQualityTier),
      );
      _recoveryPromptDismissedFor = await _storage.read(
        key: _kRecoveryPromptDismissed,
      );
      final fs = await _storage.read(key: _kFilterStyle);
      // First-launch default is chips; honour an explicit 'drawer' selection.
      _filterStyle = fs == 'drawer' ? FilterStyle.drawer : FilterStyle.chips;
      _roomFilter = RoomFilter.decode(await _storage.read(key: _kRoomFilter));
      _glassSlots = _decodeSlots(await _storage.read(key: _kGlassSlots));
      final rawGlass = await _storage.read(key: _kGlassProfile);
      // The stored profile wins, because a look can be selected and then
      // nudged. Only fall back to the preset's own profile when there is no
      // stored one at all — a fresh install, or a keychain wipe.
      //
      // The two are read together, and the preset pointer is only trusted when
      // there IS a stored profile. Reading the pointer on its own overwrote the
      // field's default with the null a fresh install returns, so a first
      // launch came up wearing Frosted's values while labelled "Custom" — a
      // state the UI otherwise cannot reach, and one that made the shipped
      // default look like an unsaved edit.
      if (rawGlass != null && rawGlass.isNotEmpty) {
        _glass = GlassProfile.fromJson(jsonDecode(rawGlass));
        // Legitimately null once the slot you were wearing is deleted.
        _glassPresetId = await _storage.read(key: _kGlassPreset);
      } else {
        _glassPresetId = kDefaultGlassPresetId;
        _glass = _resolvePreset(_glassPresetId).profile;
      }
      _localeCode = await _storage.read(key: _kLocale);
      // Absent (and unrecognised) reads back as null = "follow the OS", which
      // is the default every fresh install wants. Parsing cannot throw, so its
      // position at the tail of this try block costs nothing.
      _motionLevel = MotionLevel.parse(await _storage.read(key: _kMotionLevel));
      _scheduledIndicator = ScheduledIndicator.parse(
        await _storage.read(key: _kScheduledIndicator),
      );
    } catch (_) {
      /* secure storage unavailable in test harness */
    }
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

  Future<void> setRoomMonogram(bool on) async {
    if (_roomMonogram == on) return;
    _roomMonogram = on;
    notifyListeners();
    await _storage.write(key: _kMonogram, value: '$on');
  }

  Future<void> setNavStyle(NavStyle s) async {
    if (_navStyle == s) return;
    _navStyle = s;
    notifyListeners();
    await _storage.write(key: _kNav, value: s.name);
  }

  /// Switches the active shell section.
  ///
  /// [persist] exists for pushes: a notification tap should steer the shell for
  /// *this* run without making the destination sticky across restarts. Every
  /// in-app caller wants the default.
  Future<void> setSection(HomeSection s, {bool persist = true}) async {
    if (_section == s) return;
    _section = s;
    notifyListeners();
    if (persist) await _storage.write(key: _kSection, value: s.name);
  }

  /// Sets (or clears) the motion override. Passing null returns to "follow the
  /// OS", and deletes the key rather than writing a sentinel — the same shape
  /// [setLocaleCode] uses for its nullable preference.
  Future<void> setScheduledIndicator(ScheduledIndicator v) async {
    if (_scheduledIndicator == v) return;
    _scheduledIndicator = v;
    notifyListeners();
    await _storage.write(key: _kScheduledIndicator, value: v.name);
  }

  Future<void> setMotionLevel(MotionLevel? m) async {
    if (_motionLevel == m) return;
    _motionLevel = m;
    notifyListeners();
    if (m == null) {
      await _storage.delete(key: _kMotionLevel);
    } else {
      await _storage.write(key: _kMotionLevel, value: m.name);
    }
  }

  Future<void> setFilterStyle(FilterStyle s) async {
    if (_filterStyle == s) return;
    _filterStyle = s;
    notifyListeners();
    await _storage.write(key: _kFilterStyle, value: s.name);
  }

  /// Serialises writes to the filter key.
  ///
  /// Filter chips are tapped rapidly and repeatedly, and every tap fires a
  /// write. Concurrent `FlutterSecureStorage.write` calls on one key have no
  /// completion ordering, so an unlucky interleaving persists a filter the user
  /// passed through rather than the one they stopped on — and because the
  /// filter survives relaunch, that wrong value is what they come back to.
  Future<void> _filterWrite = Future<void>.value();

  Future<void> setRoomFilter(RoomFilter f) async {
    if (_roomFilter == f) return;
    _roomFilter = f;
    notifyListeners();
    final encoded = f.encode();
    _filterWrite = _filterWrite
        .then((_) => _storage.write(key: _kRoomFilter, value: encoded))
        .catchError((_) {
          /* storage unavailable; in-memory state still right */
        });
    await _filterWrite;
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

  /// Pass null to go back to following the system language.
  Future<void> setLocaleCode(String? code) async {
    if (_localeCode == code) return;
    _localeCode = code;
    notifyListeners();
    if (code == null) {
      await _storage.delete(key: _kLocale);
    } else {
      await _storage.write(key: _kLocale, value: code);
    }
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

  Future<void> setBubbleStyle(BubbleStyle s) async {
    if (_bubbleStyle == s) return;
    _bubbleStyle = s;
    notifyListeners();
    await _storage.write(key: _kBubbleStyle, value: s.name);
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

  Future<void> setShowNetworkStats(bool v) async {
    if (_showNetworkStats == v) return;
    _showNetworkStats = v;
    notifyListeners();
    await _storage.write(key: _kShowNetworkStats, value: v ? 'true' : 'false');
  }

  Future<void> setVideoQualityTier(VideoQualityTier v) async {
    if (_videoQualityTier == v) return;
    _videoQualityTier = v;
    notifyListeners();
    await _storage.write(key: _kVideoQualityTier, value: v.wire);
  }

  /// Records that [userId] declined the recovery-phrase prompt once. The
  /// settings and profile banners carry it from there — this is a prompt, not
  /// a nag.
  Future<void> markRecoveryPromptDismissed(String userId) async {
    if (_recoveryPromptDismissedFor == userId) return;
    _recoveryPromptDismissedFor = userId;
    await _storage.write(key: _kRecoveryPromptDismissed, value: userId);
  }

  Future<void> setManualLogoThemeId(String id) async {
    if (_manualLogoThemeId == id) return;
    _manualLogoThemeId = id;
    notifyListeners();
    await _storage.write(key: _kManualLogoThemeId, value: id);
    _applyLauncherIcon();
  }

  // --------------------------------------------------------------- glass

  GlassPreset _resolvePreset(String? id) => glassPresets.firstWhere(
    (p) => p.id == id,
    orElse: () => kBuiltInGlassPresets.first,
  );

  static List<GlassPreset> _decodeSlots(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final entry in list.take(kMaxGlassSlots))
          ?GlassPreset.fromJson(entry),
      ];
    } catch (_) {
      // A slot list that no longer parses costs the user their saved looks,
      // which is bad; wedging every cold start on it would be worse.
      return const [];
    }
  }

  /// Debounces the live profile's write.
  ///
  /// A slider reports on every drag frame. The filter-chip guard below
  /// serialises writes but still performs one per event, which at 60fps means
  /// ~60 keychain writes per second of dragging — enough to visibly stutter
  /// the drag on a real device. Only the value the user lets go on matters, so
  /// coalesce and write once the drag stops.
  Timer? _glassWriteTimer;
  Future<void> _glassWrite = Future<void>.value();

  void _writeGlassSoon() {
    _glassWriteTimer?.cancel();
    _glassWriteTimer = Timer(const Duration(milliseconds: 350), _writeGlassNow);
  }

  void _writeGlassNow() {
    _glassWriteTimer?.cancel();
    _glassWriteTimer = null;
    final profile = jsonEncode(_glass.toJson());
    final preset = _glassPresetId;
    _glassWrite = _glassWrite
        .then((_) async {
          await _storage.write(key: _kGlassProfile, value: profile);
          if (preset == null) {
            await _storage.delete(key: _kGlassPreset);
          } else {
            await _storage.write(key: _kGlassPreset, value: preset);
          }
        })
        .catchError((_) {
          /* storage unavailable; in-memory state still right */
        });
  }

  /// Starts any pending debounced glass write immediately.
  ///
  /// Call when leaving the tuning screen, which is exactly when a drag that
  /// ended a moment ago has not been persisted yet. Also what keeps widget
  /// tests honest: a test that moves a slider and ends otherwise leaves a live
  /// [Timer] behind, which the test binding reports as a failure.
  ///
  /// Deliberately not awaitable. Every glass write is fire-and-forget for the
  /// same reason [_applyLauncherIcon] is — the in-memory state is already
  /// correct and already notified, so a caller gains nothing by waiting on the
  /// keychain. Returning a future here would also hang any `testWidgets` that
  /// awaited it: the body runs in a fake-async zone where the platform
  /// channel's reply never arrives, so the write never completes.
  void flushGlassWrites() {
    if (_glassWriteTimer?.isActive ?? false) _writeGlassNow();
  }

  /// Replaces the live tuning. [presetId] is the preset it came from, or null
  /// when a dial has been dragged and it now matches nothing saved.
  Future<void> setGlassProfile(GlassProfile p, {String? presetId}) async {
    if (_glass == p && _glassPresetId == presetId) return;
    _glass = p;
    _glassPresetId = presetId;
    notifyListeners();
    _writeGlassSoon();
  }

  /// Selects a built-in or saved look.
  void selectGlassPreset(String id) {
    final preset = _resolvePreset(id);
    _glass = preset.profile;
    _glassPresetId = preset.id;
    notifyListeners();
    // Discrete choice rather than a drag, so no reason to make it wait out the
    // debounce before it would survive a kill.
    _writeGlassNow();
  }

  /// Saves the live tuning as a new named slot and makes it the active one.
  ///
  /// Returns false when the cap is reached or the name is blank, so the caller
  /// can say why rather than appearing to succeed.
  bool saveGlassSlot(String rawName) {
    final name = sanitizeSlotName(rawName);
    if (name.isEmpty || glassSlotsFull) return false;
    // Millisecond stamp rather than a counter: a counter reset by a keychain
    // wipe would re-issue an id that a stale persisted selection still points
    // at, silently activating the wrong slot.
    final id = 'slot-${DateTime.now().microsecondsSinceEpoch}';
    _glassSlots = [
      ..._glassSlots,
      GlassPreset(id: id, name: name, profile: _glass),
    ];
    _glassPresetId = id;
    notifyListeners();
    _writeSlots();
    _writeGlassNow();
    return true;
  }

  /// Renames a saved slot. Built-ins are not renameable.
  void renameGlassSlot(String id, String rawName) {
    final name = sanitizeSlotName(rawName);
    if (name.isEmpty) return;
    final i = _glassSlots.indexWhere((s) => s.id == id);
    if (i < 0 || _glassSlots[i].name == name) return;
    final next = [..._glassSlots];
    next[i] = GlassPreset(id: id, name: name, profile: _glassSlots[i].profile);
    _glassSlots = next;
    notifyListeners();
    _writeSlots();
  }

  /// Overwrites a saved slot with the live tuning.
  void updateGlassSlot(String id) {
    final i = _glassSlots.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final next = [..._glassSlots];
    next[i] = GlassPreset(id: id, name: _glassSlots[i].name, profile: _glass);
    _glassSlots = next;
    _glassPresetId = id;
    notifyListeners();
    _writeSlots();
    _writeGlassNow();
  }

  void deleteGlassSlot(String id) {
    if (!_glassSlots.any((s) => s.id == id)) return;
    _glassSlots = [
      for (final s in _glassSlots)
        if (s.id != id) s,
    ];
    // Deleting the look you are wearing leaves the look on screen and just
    // stops calling it by name — reverting to a default here would throw away
    // tuning the user never asked to lose.
    if (_glassPresetId == id) _glassPresetId = null;
    notifyListeners();
    _writeSlots();
    _writeGlassNow();
  }

  void _writeSlots() {
    final encoded = jsonEncode([for (final s in _glassSlots) s.toJson()]);
    _glassWrite = _glassWrite
        .then((_) => _storage.write(key: _kGlassSlots, value: encoded))
        .catchError((_) {
          /* storage unavailable; in-memory state still right */
        });
  }

  /// Re-apply the launcher icon from current state, once per launch.
  ///
  /// [load] deliberately does NOT do this: it runs before the engine has
  /// attached its method channels, where `supportsAlternateIcons` resolves to
  /// null and the whole call silently no-ops. Call this from the app shell,
  /// after the first frame.
  ///
  /// Free when the icon is already correct — the service compares against the
  /// live name and returns without touching PackageManager. It exists so an
  /// install left holding an `<activity-alias>` icon by an earlier build gets
  /// the primary adaptive icon back on the next launch, without the user
  /// having to visit the logo screen.
  void reconcileLauncherIcon() => _applyLauncherIcon();

  /// Fire-and-forget native launcher-icon swap. Reads the resolved icon name
  /// from the current store state; safe to call from any setter. Awaiting
  /// would block the UI on a non-essential side effect.
  void _applyLauncherIcon() {
    final active = ThemeController.byId(
      _themeId ?? ThemeController.all.first.id,
    );
    LauncherIconService.applyFromSettings(active);
  }
}

enum RoomLayout { list, grid }

enum NavStyle { radial, pill }

/// Shape of the chat list's filter control.
///
/// * `chips` (default) — an always-visible scrolling row of multi-select chips.
///   Zero taps to filter, at the cost of a permanent row.
/// * `drawer` — one button in the header that expands an inline panel with
///   per-facet counts. Calmer at rest, but costs a tap and is easier to miss.
enum FilterStyle { drawer, chips }

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

/// How much decorative motion to render. See [SettingsStore.motionLevel] for
/// why the stored preference is nullable, and [MotionScope] for how it resolves
/// against the OS flag.
///
/// * `full` — every parallax layer, loop and particle runs.
/// * `calm` — decorative motion is not shortened, it is **not built**. Looping
///   tickers never start, the parallax field paints statically, and transitions
///   collapse to zero duration. Merely shortening durations still costs the
///   frames and still moves the screen, which is the thing being asked for.
enum MotionLevel {
  full,
  calm;

  static final Map<String, MotionLevel> _byName = values.asNameMap();

  /// Resolves a persisted name. Unknown and absent both mean "no override" —
  /// the caller falls back to the OS.
  ///
  /// Derived from [values] rather than a `switch` with a `default:`, matching
  /// [HomeSection.parse]: the switch form compiles cleanly when a member is
  /// added and silently dumps everyone onto the fallback.
  static MotionLevel? parse(String? s) => s == null ? null : _byName[s];
}

/// Which affordance tells you a room is holding scheduled messages.
///
/// The two are not equivalent, which is why this exists rather than a bool.
///
/// * `pill` — a tappable pill above the composer. The only one that stands
///   alone: it is visible whenever the room has something queued, and it is the
///   sole route into the list.
/// * `badge` — a count on the send button. Quieter, but the send button only
///   exists while the composer has text, so an idle room shows nothing at all,
///   and tapping it sends rather than opening anything.
/// * `both` — the pill, plus the count while you are composing.
enum ScheduledIndicator {
  pill,
  badge,
  both;

  /// Whether the pill above the composer should be built.
  bool get showsPill => this != ScheduledIndicator.badge;

  /// Whether the send button should carry a count.
  bool get showsBadge => this != ScheduledIndicator.pill;

  static final Map<String, ScheduledIndicator> _byName = values.asNameMap();

  /// Resolves a persisted name, falling back to [pill].
  ///
  /// Derived from [values] rather than a `switch` with a `default:`, matching
  /// [MotionLevel.parse] and [HomeSection.parse] — the switch form compiles
  /// cleanly when a member is added and silently dumps everyone onto the
  /// fallback.
  static ScheduledIndicator parse(String? s) => _byName[s] ?? ScheduledIndicator.pill;
}

/// Top-level shell destinations, in nav order.
enum HomeSection {
  chat,
  feed,
  discover,
  settings;

  static final Map<String, HomeSection> _byName = values.asNameMap();

  /// Resolves a persisted section name, falling back to [chat].
  ///
  /// Derived from [values] rather than a hand-written switch: the previous
  /// version listed each case explicitly with a `default:` catch-all, so adding
  /// a member and forgetting its case compiled cleanly while silently dumping
  /// everyone on that section back to Chat at each cold start. Nothing to
  /// forget now.
  static HomeSection parse(String? s) => _byName[s] ?? HomeSection.chat;
}
