import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../calls/call_models.dart' show VideoQualityTier, VideoQualityTierWire;
import '../services/launcher_icon_service.dart';
import '../theme/bubble_shape.dart';
import '../theme/speaker_colors.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'glass_config.dart';
import 'room_filter.dart';
import 'settings_keychain.dart';

/// User-selectable preferences persisted across launches.
///
/// All values live in the platform secure store so they survive reinstall —
/// matches v02's habit of keeping the theme alive across uninstall.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const _kTheme = 'mh.theme';
  // The device-following pair, and which of the two ways the theme is chosen.
  // See [appearanceMode].
  static const _kThemeMode = 'mh.theme.mode';
  static const _kThemeLight = 'mh.theme.light';
  static const _kThemeDark = 'mh.theme.dark';
  static const _kThemeOnboarded = 'mh.theme.onboarded';
  static const _kLayout = 'mh.roomLayout';
  static const _kMonogram = 'mh.roomMonogram';
  static const _kNav = 'mh.nav';
  static const _kSection = 'mh.section';
  static const _kPushEnabled = 'mh.pushEnabled';
  static const _kGameReminders = 'mh.gameReminders';
  static const _kFriendActivity = 'mh.friendActivity';
  static const _kCaptureProtection = 'mh.captureProtection';
  static const _kChatStyle = 'mh.chatStyle';
  static const _kReplyStyle = 'mh.replyStyle';
  static const _kBubbleStyle = 'mh.bubbleStyle';
  static const _kSpeakerTint = 'mh.speakerTint';
  static const _kViewReadReceipts = 'mh.viewReadReceipts';
  static const _kLogoMode = 'mh.logoMode';
  static const _kManualLogoThemeId = 'mh.manualLogoThemeId';
  static const _kShowLinkUrls = 'mh.showLinkUrls';
  static const _kAutoplayExpressions = 'mh.autoplayExpressions';
  static const _kStickerSuggestions = 'mh.stickerSuggestions';
  static const _kShowNetworkStats = 'mh.showNetworkStats';
  static const _kPhotoHd = 'mh.photoHd';
  static const _kVideoQualityTier = 'mh.videoQualityTier';
  // NOTE: 'mh.fullScreenIntentPrompted', 'mh.batteryOptPrompted' and
  // 'mh.micPermissionPrompted' were retired with the Android onboarding
  // prompts they gated. Their values are left on disk rather than migrated
  // away — they cost three unread booleans, and reusing either name later
  // would silently inherit a "yes, already asked" from an install that was
  // asked by the old flow. Pick new keys if a prompt ever comes back.
  static const _kRecoveryPromptDismissed = 'mh.recoveryPromptDismissedFor';
  static const _kComposerModeHintSeenRoomIds = 'mh.composerModeHintSeenRoomIds';
  static const _kFilterStyle = 'mh.filterStyle';
  static const _kRoomFilter = 'mh.roomFilter';
  static const _kGlassProfile = 'mh.glass.profile';
  static const _kGlassSlots = 'mh.glass.slots';
  static const _kGlassPreset = 'mh.glass.preset';
  static const _kGlassEngine = 'mh.glass.engine';
  static const _kLocale = 'mh.locale';
  static const _kMotionLevel = 'mh.motionLevel';
  static const _kScheduledIndicator = 'mh.schedule.indicator';
  static const _kDiagHidden = 'mh.diag.hidden';

  // ── Companions (lib/companions/) ───────────────────────────────────────
  // Namespaced under `mh.companion.` so a future resident needs no new
  // convention, and so the whole subsystem is greppable in one go.
  static const _kSebastianEnabled = 'mh.companion.sebastian.enabled';
  static const _kTranslationTarget = 'mh.companion.sebastian.target';
  static const _kTranslatedRoomIds = 'mh.companion.sebastian.rooms';
  static const _kMarloweBrainId = 'mh.companion.marlowe.brain';
  static const _kCompanionForceCpu = 'mh.companion.forceCpu';

  /// Every key above — what [SettingsKeychain] may take from the legacy class,
  /// which the other stores share. A key added later can be left out safely:
  /// nothing has written under the legacy class since 1.3.105.
  @visibleForTesting
  static const keys = {
    _kTheme, _kThemeMode, _kThemeLight, _kThemeDark, _kThemeOnboarded,
    _kLayout, _kMonogram, _kNav, _kSection, _kPushEnabled, _kGameReminders,
    _kFriendActivity, _kCaptureProtection, _kChatStyle, _kReplyStyle,
    _kBubbleStyle, _kSpeakerTint, _kViewReadReceipts, _kLogoMode,
    _kManualLogoThemeId, _kShowLinkUrls, _kShowNetworkStats, _kPhotoHd,
    _kVideoQualityTier, _kRecoveryPromptDismissed,
    _kComposerModeHintSeenRoomIds, _kFilterStyle, _kRoomFilter,
    _kGlassProfile, _kGlassSlots, _kGlassPreset, _kLocale, _kMotionLevel,
    _kScheduledIndicator, _kSebastianEnabled, _kTranslationTarget,
    _kTranslatedRoomIds, _kMarloweBrainId, _kCompanionForceCpu,
  };

  final SettingsKeychain _storage = SettingsKeychain(keys: keys);

  String? _themeId;
  AppearanceMode _appearanceMode = AppearanceMode.system;
  String _lightThemeId = kDefaultLightThemeId;
  String _darkThemeId = kDefaultDarkThemeId;
  bool _themeOnboarded = false;
  RoomLayout _roomLayout = RoomLayout.list;
  // Off by default: the letter is a backdrop for a room with nothing to
  // show, and whether it reads as texture or as clutter is a matter of
  // taste rather than of layout.
  bool _roomMonogram = false;
  NavStyle _navStyle = NavStyle.pill;
  HomeSection _section = HomeSection.chat;
  bool _pushEnabled = true;
  // The once-a-day "you haven't played today" nudge, on by default — a daily
  // game nobody is reminded about is a daily game nobody plays. Mirrored on
  // this device's backend row (userDevices.gameRemindersEnabled), which is
  // where the sender actually reads it; this copy exists so the switch renders
  // instantly and correctly with no round trip, exactly like [_pushEnabled].
  bool _gameReminders = true;
  // Highlights, points and shared game results from friends. On by default for
  // the same reason the nudge is: a board nobody is told about is a board
  // nobody opens. Mirrored on this device's backend row
  // (userDevices.friendActivityEnabled), which is where the sender reads it.
  bool _friendActivity = true;
  bool _captureProtection = false;
  ChatStyle _chatStyle = ChatStyle.compact;
  ReplyStyle _replyStyle = ReplyStyle.quote;
  BubbleStyle _bubbleStyle = BubbleStyle.tailed;
  // On, and on all the way, by default. A group room where five people's
  // messages are all drawn in the same ink is the problem this setting is the
  // answer to — shipping the answer switched off would mean nobody who never
  // opens Settings ever sees it.
  SpeakerTint _speakerTint = SpeakerTint.bubble;
  bool _viewReadReceipts = false;
  LogoMode _logoMode = LogoMode.auto;
  String? _manualLogoThemeId;
  bool _showLinkUrls = false;
  bool _autoplayExpressions = true;
  bool _stickerSuggestions = true;
  bool _photoHd = false;
  bool _showNetworkStats = false;
  VideoQualityTier _videoQualityTier = VideoQualityTier.auto;
  String? _recoveryPromptDismissedFor;
  Set<String> _composerModeHintSeenRoomIds = {};
  Set<String>? _diagHiddenCategories;
  FilterStyle _filterStyle = FilterStyle.chips;
  GlassEngine _glassEngine = GlassEngine.native;
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

  // Off until asked for. Sebastian costs a 328 MB download, and a default-on
  // feature that large would be spending someone's storage and data plan on a
  // decision they never made. See [sebastianEnabled].
  bool _sebastianEnabled = false;
  // Null means "follow the app's display language" — see
  // `Sebastian.targetLanguage`, which owns the whole fallback chain. Storing
  // null rather than resolving it here matters: someone who switches the app
  // to Turkish should get Turkish translations without visiting this setting.
  String? _translationTarget;
  Set<String> _translatedRoomIds = {};
  String? _marloweBrainId;
  // Set once, by discovery rather than by the user: see
  // `BrainGateway.demoteToCpu`. A device whose GPU path returns nonsense will
  // do so on every launch, and rediscovering that costs a wasted translation
  // each time.
  bool _companionForceCpu = false;

  /// The theme picked in [AppearanceMode.fixed]. Null for somebody who has
  /// never picked one — the device-following pair is what they see.
  String? get themeId => _themeId;

  /// Whether the theme follows the device's light and dark mode, or stays put.
  ///
  /// A fresh install follows the device, with Midnight and Daylight as the
  /// pair. An install that already had a theme picked keeps it: the choice was
  /// made, and quietly swapping it for a pair at dusk would read as the app
  /// forgetting it.
  AppearanceMode get appearanceMode => _appearanceMode;

  /// The theme worn while the device is in light mode, under
  /// [AppearanceMode.system].
  String get lightThemeId => _lightThemeId;

  /// The theme worn while the device is in dark mode, under
  /// [AppearanceMode.system].
  String get darkThemeId => _darkThemeId;

  /// Whether the first-launch appearance picker has been answered — or never
  /// needs to be, for an install that already had a theme, or a session.
  bool get themeOnboarded => _themeOnboarded;

  /// The theme id to wear right now, with the device in [platform] brightness.
  String themeIdFor(Brightness platform) => resolveThemeId(
        mode: _appearanceMode,
        platform: platform,
        fixedId: _themeId ?? _darkThemeId,
        lightId: _lightThemeId,
        darkId: _darkThemeId,
      );
  RoomLayout get roomLayout => _roomLayout;
  bool get roomMonogram => _roomMonogram;
  NavStyle get navStyle => _navStyle;
  HomeSection get section => _section;
  bool get pushEnabled => _pushEnabled;
  bool get gameReminders => _gameReminders;
  bool get friendActivity => _friendActivity;
  bool get captureProtection => _captureProtection;
  ChatStyle get chatStyle => _chatStyle;
  ReplyStyle get replyStyle => _replyStyle;

  /// The shape family every message bubble is drawn with. Defaults to
  /// [BubbleStyle.tailed] — a run of messages closes with a curved tail.
  BubbleStyle get bubbleStyle => _bubbleStyle;

  /// How far each speaker's own colour reaches inside a group room. Defaults
  /// to [SpeakerTint.bubble]. Has no effect in a DM, where there is exactly
  /// one other person and the margin already says who is talking.
  SpeakerTint get speakerTint => _speakerTint;
  LogoMode get logoMode => _logoMode;
  String? get manualLogoThemeId => _manualLogoThemeId;

  /// When `true`, raw URL text remains visible inline alongside the link
  /// preview card. Default `false` — the preview alone communicates the
  /// link, and keeping the URL text out makes mixed messages read clean.
  bool get showLinkUrls => _showLinkUrls;

  /// Whether GIFs and animated stickers play by themselves in the transcript
  /// and the picker. Off shows each one still, with a tap to play it — for
  /// people who find a moving transcript distracting, or who are on a metered
  /// connection (a KLIPY GIF is a few hundred KB). The system reduce-motion
  /// setting pauses them regardless; see `ExpressionPlayback`.
  bool get autoplayExpressions => _autoplayExpressions;

  /// Whether typing a lone emoji offers matching stickers above the composer,
  /// the way Telegram and Signal do.
  bool get stickerSuggestions => _stickerSuggestions;

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

  /// When `true`, an outgoing photo is sent at its source resolution and JPEG
  /// q90 — what the editor exported unconditionally before this switch existed.
  ///
  /// Default `false`, and that default is the point. A phone camera photo is
  /// ~5 MB at full size, and a chat room multiplies it: every member fetches
  /// the blob separately from Convex storage with no CDN in front, so one
  /// photo into a room of four is ~25 MB moved. Capped, the same photo is
  /// ~150 KB. See `kSendPhotoMaxEdge` in media/image_raster.dart.
  ///
  /// Sticky rather than per-send: someone who turns HD on is usually sending a
  /// screenshot of text or a photo they want kept, and asking them to re-arm it
  /// on every picture would be the wrong kind of careful. The editor still
  /// shows the state on every send, so it is never silently on.
  bool get photoHd => _photoHd;

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

  /// Whether room [roomId]'s composer should still show its mode-switch
  /// tooltip the next time it opens. The entrance bump plays regardless —
  /// only the tooltip is gated by this.
  ///
  /// Per room, not global: a room already teaches nothing the second time it
  /// is opened, but a room the user has never opened before has taught them
  /// nothing yet either, hint or no hint elsewhere.
  bool shouldShowComposerModeHint(String roomId) => !_composerModeHintSeenRoomIds.contains(roomId);

  /// The diagnostics categories left out of the viewer's **All**, by name.
  /// Null until somebody first changes them, so the viewer can tell "never
  /// chosen" (its default applies) from "chose to hide nothing".
  Set<String>? get diagHiddenCategories => _diagHiddenCategories;

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

  /// Who draws the glass chrome. [GlassEngine.native] — the default — hands
  /// the bottom bar to iOS itself wherever the OS has Liquid Glass (iOS 26+);
  /// anywhere it doesn't, the app's own glass is drawn whatever this says, so
  /// the setting only ever means something on a phone that can honour it.
  /// See `NativeChrome.supported`.
  GlassEngine get glassEngine => _glassEngine;

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

  /// Whether Sebastian is switched on.
  ///
  /// Distinct from "installed": a user can switch him off without deleting his
  /// brain, which is the state you want when you are on a plane and low on
  /// battery but not ready to re-download 328 MB tomorrow.
  bool get sebastianEnabled => _sebastianEnabled;

  /// Explicit translation target, or null to follow the app's language.
  String? get translationTarget => _translationTarget;

  /// Rooms the user has switched room-wide translation on for.
  ///
  /// Persisted rather than per-session on purpose: a room you needed
  /// translated yesterday is a room you need translated today — it is a fact
  /// about who you talk to there, not about one visit.
  Set<String> get translatedRoomIds => Set.unmodifiable(_translatedRoomIds);

  /// Whether companion inference has been pinned to the CPU.
  ///
  /// Not a preference anybody sets. It is a conclusion the app reached about
  /// this device's accelerator after the fast path produced something that
  /// was not language.
  bool get companionForceCpu => _companionForceCpu;

  /// Which brain Marlowe is set to think with, or null if there is none yet.
  String? get marloweBrainId => _marloweBrainId;

  Future<void> load() async {
    if (_loaded) return;
    await _readStored();
    _loaded = true;
    notifyListeners();
  }

  /// Whether the last attempt to read the stored preferences failed, so every
  /// getter is answering with a default rather than the user's choice.
  ///
  /// Not a test-harness curiosity. On iOS the next launch after an update is
  /// often a background one on a locked phone, where the keychain can refuse —
  /// and the process that launch starts is the one the person later opens.
  /// See [SettingsKeychain].
  bool _unread = false;
  bool _retrying = false;

  final Completer<void> _ready = Completer<void>();

  /// Completes once the stored preferences have actually been read — which on
  /// a locked cold start can be well after [load] returned.
  ///
  /// Anything that copies a preference somewhere else (the device row's push
  /// switches, the launcher icon) waits on this, so it can never copy a
  /// default that stood in for a value the keychain would not hand over yet.
  Future<void> get ready => _ready.future;

  Future<bool> _readStored() async {
    final Map<String, String> s;
    try {
      s = await _storage.readAll();
    } catch (e) {
      _unread = true;
      debugPrint('SettingsStore: preferences unreadable for now: $e');
      return false;
    }
    _apply(s);
    _unread = false;
    if (!_ready.isCompleted) _ready.complete();
    unawaited(_storage.migrate());
    return true;
  }

  /// Reads the stored preferences again if the launch could not.
  ///
  /// Called on every resume, where it is free unless a read is outstanding.
  /// On success the whole app re-renders under the real choices, the launcher
  /// icon is reconciled against them, and any toggle flipped in the meantime is
  /// persisted — it already won over the disk copy in [SettingsKeychain.readAll].
  ///
  /// True when this call is the one that finally read them, so a caller that
  /// seeded something from the defaults at launch knows to seed it again.
  Future<bool> retryIfUnread() async {
    if (!_unread || _retrying) return false;
    _retrying = true;
    try {
      if (!await _readStored()) return false;
      notifyListeners();
      _applyLauncherIcon();
      unawaited(_storage.flush());
      return true;
    } finally {
      _retrying = false;
    }
  }

  void _apply(Map<String, String> s) {
    final look = StoredAppearance.parse(
      theme: s[_kTheme],
      mode: s[_kThemeMode],
      light: s[_kThemeLight],
      dark: s[_kThemeDark],
      onboarded: s[_kThemeOnboarded],
    );
    _themeId = look.fixedId;
    _appearanceMode = look.mode;
    _lightThemeId = look.lightId;
    _darkThemeId = look.darkId;
    _themeOnboarded = look.onboarded;
    final lay = s[_kLayout];
    _roomLayout = RoomLayout.values.firstWhere(
      (l) => l.name == lay,
      orElse: () => RoomLayout.list,
    );
    final mono = s[_kMonogram];
    _roomMonogram = mono == 'true'; // default false
    final nav = s[_kNav];
    // First-launch default is pill; honor an explicit 'radial' selection.
    _navStyle = nav == 'radial' ? NavStyle.radial : NavStyle.pill;
    final sec = s[_kSection];
    _section = HomeSection.parse(sec);
    final push = s[_kPushEnabled];
    _pushEnabled = push != 'false'; // default true
    final nudge = s[_kGameReminders];
    _gameReminders = nudge != 'false'; // default true
    final social = s[_kFriendActivity];
    _friendActivity = social != 'false'; // default true
    final cap = s[_kCaptureProtection];
    _captureProtection = cap == 'true'; // default false
    final cs = s[_kChatStyle];
    // 'liquid' was the legacy name for compact — preserve the choice for
    // anyone who had selected it before the rename.
    _chatStyle = cs == 'classic' ? ChatStyle.classic : ChatStyle.compact;
    final rs = s[_kReplyStyle];
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
      // Stored only when somebody picked it: an install on the default never
      // wrote this key, so it moves to the new default with everyone else.
      case 'phantomEcho':
        _replyStyle = ReplyStyle.phantomEcho;
        break;
      default:
        _replyStyle = ReplyStyle.quote;
    }
    final bs = s[_kBubbleStyle];
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
    final st = s[_kSpeakerTint];
    switch (st) {
      case 'off':
        _speakerTint = SpeakerTint.off;
        break;
      case 'name':
        _speakerTint = SpeakerTint.name;
        break;
      default:
        _speakerTint = SpeakerTint.bubble;
    }
    final vrr = s[_kViewReadReceipts];
    _viewReadReceipts = vrr == 'true'; // default false
    final lm = s[_kLogoMode];
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
    _manualLogoThemeId = s[_kManualLogoThemeId];
    final slu = s[_kShowLinkUrls];
    _showLinkUrls = slu == 'true'; // default false
    _autoplayExpressions = s[_kAutoplayExpressions] != 'false'; // default true
    _stickerSuggestions = s[_kStickerSuggestions] != 'false'; // default true
    final sns = s[_kShowNetworkStats];
    _showNetworkStats = sns == 'true'; // default false
    final phd = s[_kPhotoHd];
    _photoHd = phd == 'true'; // default false — compressed
    _videoQualityTier = VideoQualityTierWire.parse(s[_kVideoQualityTier]);
    _recoveryPromptDismissedFor = s[_kRecoveryPromptDismissed];
    _composerModeHintSeenRoomIds = _decodeStringSet(
      s[_kComposerModeHintSeenRoomIds],
    );
    // Absent stays null — "never chosen", which the viewer reads as its own
    // default — rather than decoding to an empty set, which is a choice.
    final dh = s[_kDiagHidden];
    _diagHiddenCategories = dh == null ? null : _decodeStringSet(dh);
    final fs = s[_kFilterStyle];
    // First-launch default is chips; honour an explicit 'drawer' selection.
    _filterStyle = fs == 'drawer' ? FilterStyle.drawer : FilterStyle.chips;
    _roomFilter = RoomFilter.decode(s[_kRoomFilter]);
    _glassEngine = s[_kGlassEngine] == 'flutter'
        ? GlassEngine.flutter
        : GlassEngine.native;
    _glassSlots = _decodeSlots(s[_kGlassSlots]);
    final rawGlass = s[_kGlassProfile];
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
    final stored = _decodeGlass(rawGlass);
    if (stored != null) {
      _glass = stored;
      // Legitimately null once the slot you were wearing is deleted.
      _glassPresetId = s[_kGlassPreset];
    } else {
      _glassPresetId = kDefaultGlassPresetId;
      _glass = _resolvePreset(_glassPresetId).profile;
    }
    _localeCode = s[_kLocale];
    // Absent (and unrecognised) reads back as null = "follow the OS", which
    // is the default every fresh install wants.
    _motionLevel = MotionLevel.parse(s[_kMotionLevel]);
    _scheduledIndicator = ScheduledIndicator.parse(s[_kScheduledIndicator]);
    _sebastianEnabled = s[_kSebastianEnabled] == 'true';
    _translationTarget = s[_kTranslationTarget];
    _translatedRoomIds = _decodeStringSet(s[_kTranslatedRoomIds]);
    _marloweBrainId = s[_kMarloweBrainId];
    _companionForceCpu = s[_kCompanionForceCpu] == 'true';
  }

  /// Wears [id] all day: [AppearanceMode.fixed].
  Future<void> setThemeId(String id) async {
    if (_themeId == id && _appearanceMode == AppearanceMode.fixed) return;
    final modeMoved = _appearanceMode != AppearanceMode.fixed;
    _themeId = id;
    _appearanceMode = AppearanceMode.fixed;
    notifyListeners();
    await _storage.write(key: _kTheme, value: id);
    if (modeMoved) await _storage.write(key: _kThemeMode, value: 'fixed');
    _applyLauncherIcon();
  }

  /// Switches between following the device and one fixed theme.
  ///
  /// Going to [AppearanceMode.fixed] fixes [current] — whatever the reader is
  /// looking at — so the switch changes nothing on screen, only what happens
  /// at dusk.
  Future<void> setAppearanceMode(AppearanceMode mode, {String? current}) async {
    if (_appearanceMode == mode) return;
    _appearanceMode = mode;
    if (mode == AppearanceMode.fixed && current != null) _themeId = current;
    notifyListeners();
    await _storage.write(key: _kThemeMode, value: mode.name);
    if (mode == AppearanceMode.fixed && current != null) {
      await _storage.write(key: _kTheme, value: current);
    }
    _applyLauncherIcon();
  }

  /// Sets the theme worn in light ([Brightness.light]) or dark mode.
  Future<void> setSlotTheme(Brightness slot, String id) async {
    final light = slot == Brightness.light;
    if ((light ? _lightThemeId : _darkThemeId) == id) return;
    if (light) {
      _lightThemeId = id;
    } else {
      _darkThemeId = id;
    }
    notifyListeners();
    await _storage.write(key: light ? _kThemeLight : _kThemeDark, value: id);
    if (!light) _applyLauncherIcon();
  }

  /// Records that the first-launch appearance picker has been answered.
  Future<void> markThemeOnboarded() async {
    if (_themeOnboarded) return;
    _themeOnboarded = true;
    notifyListeners();
    await _storage.write(key: _kThemeOnboarded, value: 'true');
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

  Future<void> setGlassEngine(GlassEngine e) async {
    if (_glassEngine == e) return;
    _glassEngine = e;
    notifyListeners();
    await _storage.write(key: _kGlassEngine, value: e.name);
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

  Future<void> setGameReminders(bool v) async {
    if (_gameReminders == v) return;
    _gameReminders = v;
    notifyListeners();
    await _storage.write(key: _kGameReminders, value: v ? 'true' : 'false');
  }

  Future<void> setFriendActivity(bool v) async {
    if (_friendActivity == v) return;
    _friendActivity = v;
    notifyListeners();
    await _storage.write(key: _kFriendActivity, value: v ? 'true' : 'false');
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

  Future<void> setSpeakerTint(SpeakerTint t) async {
    if (_speakerTint == t) return;
    _speakerTint = t;
    notifyListeners();
    await _storage.write(key: _kSpeakerTint, value: t.name);
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

  Future<void> setAutoplayExpressions(bool v) async {
    if (_autoplayExpressions == v) return;
    _autoplayExpressions = v;
    notifyListeners();
    await _storage.write(
        key: _kAutoplayExpressions, value: v ? 'true' : 'false');
  }

  Future<void> setStickerSuggestions(bool v) async {
    if (_stickerSuggestions == v) return;
    _stickerSuggestions = v;
    notifyListeners();
    await _storage.write(
        key: _kStickerSuggestions, value: v ? 'true' : 'false');
  }

  Future<void> setSebastianEnabled(bool v) async {
    if (_sebastianEnabled == v) return;
    _sebastianEnabled = v;
    notifyListeners();
    await _storage.write(key: _kSebastianEnabled, value: v ? 'true' : 'false');
  }

  /// Sets the translation target, or clears it back to "follow the app".
  Future<void> setTranslationTarget(String? code) async {
    if (_translationTarget == code) return;
    _translationTarget = code;
    notifyListeners();
    if (code == null) {
      await _storage.delete(key: _kTranslationTarget);
    } else {
      await _storage.write(key: _kTranslationTarget, value: code);
    }
  }

  Future<void> setRoomTranslated(String roomId, bool on) async {
    final changed =
        on ? _translatedRoomIds.add(roomId) : _translatedRoomIds.remove(roomId);
    if (!changed) return;
    notifyListeners();
    await _storage.write(
      key: _kTranslatedRoomIds,
      value: jsonEncode(_translatedRoomIds.toList()),
    );
  }

  Future<void> setCompanionForceCpu(bool v) async {
    if (_companionForceCpu == v) return;
    _companionForceCpu = v;
    notifyListeners();
    await _storage.write(key: _kCompanionForceCpu, value: v ? 'true' : 'false');
  }

  Future<void> setMarloweBrainId(String? id) async {
    if (_marloweBrainId == id) return;
    _marloweBrainId = id;
    notifyListeners();
    if (id == null) {
      await _storage.delete(key: _kMarloweBrainId);
    } else {
      await _storage.write(key: _kMarloweBrainId, value: id);
    }
  }

  Future<void> setPhotoHd(bool v) async {
    if (_photoHd == v) return;
    _photoHd = v;
    notifyListeners();
    await _storage.write(key: _kPhotoHd, value: v ? 'true' : 'false');
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

  /// Records that [roomId]'s composer just played the mode-switch hint, so
  /// [shouldShowComposerModeHint] stays false for that room from now on.
  Future<void> markComposerModeHintShown(String roomId) async {
    if (!_composerModeHintSeenRoomIds.add(roomId)) return;
    await _storage.write(
      key: _kComposerModeHintSeenRoomIds,
      value: jsonEncode(_composerModeHintSeenRoomIds.toList()),
    );
  }

  Future<void> setDiagHiddenCategories(Set<String> names) async {
    final prev = _diagHiddenCategories;
    if (prev != null && setEquals(prev, names)) return;
    _diagHiddenCategories = {...names};
    notifyListeners();
    await _storage.write(
      key: _kDiagHidden,
      value: jsonEncode(names.toList()..sort()),
    );
  }

  static Set<String> _decodeStringSet(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return {};
      return {for (final entry in list) if (entry is String) entry};
    } catch (_) {
      return {};
    }
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

  /// The stored live tuning, or null when there is none — or none that still
  /// parses, which is treated the same: fall back to the default look rather
  /// than let one bad blob abort the rest of the preferences.
  static GlassProfile? _decodeGlass(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return GlassProfile.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

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

  /// The theme the home-screen icon follows in `LogoMode.auto`.
  ///
  /// Under [AppearanceMode.system] that is the DARK half of the pair, always,
  /// never "whichever is showing". The shown theme changes at dusk and dawn,
  /// and on iOS every icon change raises a system alert — an icon that tracked
  /// the device would announce itself twice a day, and on whatever launch
  /// happened to reconcile it.
  String get _iconThemeId => _appearanceMode == AppearanceMode.fixed
      ? (_themeId ?? _darkThemeId)
      : _darkThemeId;

  /// Fire-and-forget native launcher-icon swap. Reads the resolved icon name
  /// from the current store state; safe to call from any setter. Awaiting
  /// would block the UI on a non-essential side effect.
  void _applyLauncherIcon() {
    // Never from defaults: with the real choice still unread, "auto" and
    // Midnight would swap the home-screen icon — and on iOS raise the system's
    // icon-changed alert — for a selection the person never made.
    if (_unread) return;
    // Nor during first-run onboarding: picking a theme there must not swap
    // the home-screen icon (and raise iOS's alert) before the icon step has
    // asked whether the icon should follow it. [markThemeOnboarded] applies
    // whatever was chosen.
    if (!_themeOnboarded) return;
    LauncherIconService.applyFromSettings(ThemeController.byId(_iconThemeId));
  }
}

/// How the home list draws a room.
///
/// * `list` (default) — iOS-style rows: avatar, name, time, two lines of
///   preview, separated by an inset hairline. See `ChatListRow`.
/// * `cards` — the original bordered card per room, every fact about the room
///   spelled out as a pill. Kept for anyone who preferred it.
/// * `grid` — two (or three) columns of tiles.
enum RoomLayout { list, cards, grid }

enum NavStyle { radial, pill }

/// Who draws the app's glass chrome on a phone that offers a choice.
///
/// * `native` (default) — iOS's own Liquid Glass: the bottom bar is a real
///   `UITabBar` laid over the Flutter view (`ios/Runner/NativeChrome.swift`).
/// * `flutter` — the app's own frosted glass, the same on every platform and
///   tunable in Settings › Glass.
enum GlassEngine { native, flutter }

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
/// * `phantomEcho` — ghost-bubble above with a curved connector
///   and a branch icon at the join point.
/// * `stickyNote` — rotated polaroid clipped to the bubble corner.
/// * `comicTail` — mini parent bubble with a downward-pointing comic-book
///   triangle tail.
/// * `classic` — accent-tinted inset row with tether bar, avatar, mono-caps
///   header, and content snippet. The original quote-pill look.
///
/// * `quote` (default) — Telegram/WhatsApp: a compact quote block (accent
///   rail, name, one line) at the top INSIDE the reply's own bubble.
enum ReplyStyle { quote, phantomEcho, stickyNote, comicTail, classic }

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
  static ScheduledIndicator parse(String? s) =>
      _byName[s] ?? ScheduledIndicator.pill;
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
