import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../calls/call_models.dart' show VideoQualityTier;
import '../data/chat_repository.dart';
import '../companions/brain_manager.dart';
import '../companions/companion.dart';
import '../data/settings_store.dart';
import '../widgets/app_toast.dart';
import 'navigation/scroll_memory.dart';
import '../data/ui_selection_store.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../legal_links.dart';
import '../models/chat_user.dart';
import '../push/android_call_reliability.dart';
import '../push/push_manager.dart';
import '../services/link_opener.dart';
import '../services/mac_app_chrome.dart';
import '../theme/app_theme.dart';
import '../theme/speaker_colors.dart';
import '../theme/layout.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../update/update_availability.dart';
import '../update/update_checker.dart';
import '../widgets/app_brand_mark.dart' show canonicalLogoId;
import '../widgets/monkey_collection.dart';
import '../widgets/self_host_badge.dart' show shortHost;
import '../widgets/recovery_banner.dart';
import '../widgets/ios_kit.dart';
import '../widgets/settings_pickers.dart';
import '../widgets/user_avatar.dart';
import 'bubble_style_screen.dart';
import 'chat_style_screen.dart';
import 'companions/companion_page.dart'
    show CompanionStorageLine, companionStatusLine;
import 'companions/marlowe_screen.dart';
import 'companions/sebastian_screen.dart';
import 'diagnostics_screen.dart';
import 'glass_screen.dart';
import 'language_screen.dart';
import 'reply_style_screen.dart';
import 'speaker_color_screen.dart';
import 'logo_screen.dart';
import 'motion_screen.dart';
import 'navigation_screen.dart';
import 'navigation/destinations.dart';
import 'navigation/native_tab_bar.dart' show NativeChrome;
import 'navigation/open_room.dart';
import 'navigation/tab_reselect.dart';
import 'profile_screen.dart';
import 'report_problem_screen.dart';
import 'room_layout_screen.dart';
import 'server_screen.dart';
import 'theme_screen.dart';
import 'video_quality_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repo,
    required this.api,
    required this.auth,
    required this.family,
  });
  final ChatRepository repo;
  final ChatApi api;
  final AuthService auth;
  final FamilyService family;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TabReselectScroll<SettingsScreen> {
  ChatUser? _me;

  // Not a plain ScrollController: this section's State is destroyed on
  // every tab switch, and the framework's own PageStorage restore is what
  // produced the settle-bounce on return. See [ScrollMemory].
  final _scroll = ScrollMemory.controller();

  @override
  HomeSection get reselectSection => HomeSection.settings;
  @override
  ScrollController get reselectScroll => _scroll;

  void _onSettings() {
    if (mounted) setState(() {});
  }

  /// The account card is built from `_me`, which is fetched ONCE in initState,
  /// and falls back to the session while that is in flight. Both go stale the
  /// moment the profile screen pushed on top of this one changes something —
  /// and a handle change is the case where stale is not merely untidy, since
  /// the card would go on showing a name the account no longer answers to.
  ///
  /// Re-fetching rather than just rebuilding: the session carries the handle
  /// but not the avatar, display name or approvals state, so a rebuild alone
  /// would fix one field and leave the rest of the card behind.
  void _onAuth() {
    if (mounted) _loadMe();
  }

  @override
  void initState() {
    super.initState();
    ScrollMemory.attach('settings', _scroll);
    SettingsStore.instance.addListener(_onSettings);
    widget.family.addListener(_onSettings);
    widget.auth.addListener(_onAuth);
    // Rebuild when the desktop settings pane's selection changes so the active
    // row highlights.
    UiSelectionStore.instance.addListener(_onSettings);
    // The Companions row shows live download progress, and this is what makes
    // the percentage move. Without it the row renders whatever the figure was
    // when the screen opened and then sits there, which reads as a stalled
    // download rather than a stale label.
    BrainManager.instance.addListener(_onSettings);
    _callDelivery.addListener(_onSettings);
    if (MacAppChrome.isSupported) {
      MacAppChrome.instance.addListener(_onSettings);
      // Re-read on every visit: the item can also be removed by ⌘-dragging it
      // out of the menu bar, and the switch has to show what happened.
      MacAppChrome.instance.load();
    }
    // The approvals badge should be right whenever this screen is opened.
    widget.family.refresh();
    _loadMe();
  }

  @override
  void dispose() {
    SettingsStore.instance.removeListener(_onSettings);
    widget.family.removeListener(_onSettings);
    widget.auth.removeListener(_onAuth);
    UiSelectionStore.instance.removeListener(_onSettings);
    BrainManager.instance.removeListener(_onSettings);
    _callDelivery
      ..removeListener(_onSettings)
      ..dispose();
    if (MacAppChrome.isSupported) {
      MacAppChrome.instance.removeListener(_onSettings);
    }
    _scroll.dispose();
    super.dispose();
  }

  /// True when [key]'s sub-screen is the one shown in the desktop detail pane.
  bool _isOpen(String key) =>
      context.isExpanded && UiSelectionStore.instance.settingsDetailKey == key;

  Future<void> _loadMe() async {
    final s = widget.auth.session;
    if (s == null) return;
    try {
      final fresh = await widget.api.getProfile(
        s.userId,
        viewerUserId: s.userId,
      );
      if (!mounted) return;
      // See the note in `home_screen._loadMe`: a null profile for ourselves
      // means the account is gone, not that the fetch was uninteresting.
      if (fresh == null) {
        widget.auth.onSelfProfileMissing();
        return;
      }
      setState(() => _me = fresh);
    } catch (_) {
      /* keep the bootstrap ChatUser; avatar stays generic */
    }
  }

  /// The breadcrumb under the avatar card. A child's account has no family
  /// controls to offer and nothing to link, so it gets the things that are
  /// actually behind the card for them.
  String get _accountHint {
    final l10n = AppLocalizations.of(context);
    return widget.auth.isChild
        ? l10n.settingsHubAccountHintChild
        : l10n.settingsHubAccountHintAdult;
  }

  String get _layoutLabel {
    final l10n = AppLocalizations.of(context);
    return switch (SettingsStore.instance.roomLayout) {
      RoomLayout.list => l10n.settingsHubLayoutRows,
      RoomLayout.cards => l10n.settingsHubLayoutCards,
      RoomLayout.grid => l10n.settingsHubLayoutGrid,
    };
  }

  String get _navLabel {
    final l10n = AppLocalizations.of(context);
    return SettingsStore.instance.navStyle == NavStyle.radial
        ? l10n.settingsScreenValueRadialOrb
        : l10n.settingsHubNavTabBar;
  }

  /// The active look's name, marked when it has been tuned away from what it
  /// saved. 'Custom' only when nothing is selected at all.
  String get _glassLabel {
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.instance;
    // Under iOS's own glass the dials do not apply, so naming a preset here
    // would describe something that is not on screen.
    if (_nativeGlass) return l10n.glassStyleLiquidTitle;
    final id = store.glassPresetId;
    if (id == null) return l10n.settingsScreenValueCustom;
    for (final p in store.glassPresets) {
      if (p.id == id) {
        return store.glass == p.profile
            ? p.name
            : l10n.settingsScreenValueEdited(p.name);
      }
    }
    return l10n.settingsScreenValueCustom;
  }

  bool get _nativeGlass =>
      NativeChrome.supported &&
      SettingsStore.instance.glassEngine == GlassEngine.native;

  String get _videoQualityLabel {
    final l10n = AppLocalizations.of(context);
    switch (SettingsStore.instance.videoQualityTier) {
      case VideoQualityTier.auto:
        return l10n.settingsScreenValueVideoQualityAuto;
      case VideoQualityTier.hd1080:
        return l10n.settingsScreenValueVideoQuality1080p;
      case VideoQualityTier.uhd4k:
        return l10n.settingsScreenValueVideoQuality4k;
    }
  }

  String get _chatStyleLabel {
    final l10n = AppLocalizations.of(context);
    return SettingsStore.instance.chatStyle == ChatStyle.classic
        ? l10n.settingsScreenValueClassic
        : l10n.settingsScreenValueCompact;
  }

  String get _languageLabel {
    final l10n = AppLocalizations.of(context);
    switch (SettingsStore.instance.localeCode) {
      case 'en':
        return l10n.languageValueEnglish;
      case 'tr':
        return l10n.languageValueTurkish;
      case 'es':
        return l10n.languageValueSpanish;
      case 'fr':
        return l10n.languageValueFrench;
      case 'pt':
        return l10n.languageValuePortuguese;
      case 'pt_BR':
        return l10n.languageValuePortugueseBrazil;
      case 'sv':
        return l10n.languageValueSwedish;
      case 'ar':
        return l10n.languageValueArabic;
      case 'zh':
        return l10n.languageValueChinese;
      case 'hi':
        return l10n.languageValueHindi;
      case 'ko':
        return l10n.languageValueKorean;
      case 'ja':
        return l10n.languageValueJapanese;
      default:
        return l10n.languageValueSystem;
    }
  }

  String get _bubbleStyleLabel {
    final l10n = AppLocalizations.of(context);
    switch (SettingsStore.instance.bubbleStyle) {
      case BubbleStyle.tailed:
        return l10n.settingsScreenValueBubbleTailed;
      case BubbleStyle.soft:
        return l10n.settingsScreenValueBubbleSoft;
      case BubbleStyle.pill:
        return l10n.settingsScreenValueBubblePill;
      case BubbleStyle.slab:
        return l10n.settingsScreenValueBubbleSlab;
    }
  }

  String get _replyStyleLabel {
    final l10n = AppLocalizations.of(context);
    switch (SettingsStore.instance.replyStyle) {
      case ReplyStyle.quote:
        return l10n.settingsScreenValueReplyQuote;
      case ReplyStyle.phantomEcho:
        return l10n.settingsScreenValueReplyPhantomEcho;
      case ReplyStyle.stickyNote:
        return l10n.settingsScreenValueReplyStickyNote;
      case ReplyStyle.comicTail:
        return l10n.settingsScreenValueReplyComicTail;
      case ReplyStyle.classic:
        return l10n.settingsScreenValueClassic;
    }
  }

  String get _speakerTintLabel {
    final l10n = AppLocalizations.of(context);
    switch (SettingsStore.instance.speakerTint) {
      case SpeakerTint.off:
        return l10n.settingsScreenValueSpeakerOff;
      case SpeakerTint.name:
        return l10n.settingsScreenValueSpeakerName;
      case SpeakerTint.bubble:
        return l10n.settingsScreenValueSpeakerBubble;
    }
  }

  /// Null resolves against the OS flag rather than showing a third label, so
  /// the row states what the user will actually get rather than "system".
  String get _motionLabel {
    final l10n = AppLocalizations.of(context);
    switch (SettingsStore.instance.motionLevel) {
      case MotionLevel.full:
        return l10n.settingsScreenValueMotionFull;
      case MotionLevel.calm:
        return l10n.settingsScreenValueMotionCalm;
      case null:
        return MediaQuery.disableAnimationsOf(context)
            ? l10n.settingsScreenValueMotionSystemCalm
            : l10n.settingsScreenValueMotionSystemFull;
    }
  }

  String get _logoLabel {
    final l10n = AppLocalizations.of(context);
    final s = SettingsStore.instance;
    switch (s.logoMode) {
      case LogoMode.auto:
        return l10n.settingsScreenValueLogoAuto;
      case LogoMode.alwaysDefault:
        return 'MonkeyHub';
      case LogoMode.manual:
        final id = s.manualLogoThemeId;
        if (id == null) return l10n.settingsScreenValueLogoManual;
        if (id == canonicalLogoId) return 'MonkeyHub';
        final monkey = monkeyVariantById(id);
        if (monkey != null) return monkey.displayName;
        return ThemeController.byId(id).name;
    }
  }


  void _openProfile(ChatUser me) => openSettingsDetail(
        context,
        key: 'profile',
        builder: (_) => ProfileScreen(
          user: me,
          repo: widget.repo,
          api: widget.api,
          auth: widget.auth,
          family: widget.family,
        ),
      );

  void _open(String key, WidgetBuilder builder) =>
      openSettingsDetail(context, key: key, builder: builder);

  @override
  Widget build(BuildContext context) {
    final activeTheme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = widget.auth.session;
    final store = SettingsStore.instance;
    final me = s == null
        ? null
        : (_me ?? ChatUser(id: s.userId, username: s.username, name: s.name));

    // Sections run in descending order of how often anyone opens them, not in
    // the order they were built: the part people came for first, the part
    // they browse after it, the facts about the app last.
    return SettingsPage(
      title: l10n.settingsHubTitle,
      controller: _scroll,
      showBack: false,
      bottomPadding: sectionBottomPadding(context),
      children: [
        if (me != null) ...[
          // An account with no recovery phrase is one forgotten password away
          // from being gone. Explicitly `== false`: null means "unknown" and
          // must not be read as "none set"; children have no reset path.
          if (_me?.hasRecoveryKey == false && !widget.auth.isChild) ...[
            RecoveryPhraseBanner(onTap: () => _openProfile(_me!)),
            const SizedBox(height: 16),
          ],
          GroupedSection(
            children: [
              _ProfileCard(
                user: me,
                api: widget.api,
                hint: _accountHint,
                // Approvals live inside the account screen, so the count
                // rides the way in.
                pending: widget.family.pendingCount,
                selected: _isOpen('profile'),
                onTap: () => _openProfile(me),
              ),
            ],
          ),
        ],

        GroupedSection(
          header: l10n.settingsHubSectionGeneral,
          children: [
            _HubRow(
              icon: CupertinoIcons.globe,
              tone: TileTone.blue,
              title: l10n.settingsHubLanguage,
              value: _languageLabel,
              selected: _isOpen('language'),
              onTap: () => _open('language', (_) => const LanguageScreen()),
            ),
            const _CheckForUpdatesRow(),
            _StoreToggle(
              icon: CupertinoIcons.link,
              tone: TileTone.teal,
              title: l10n.settingsHubShowLinkUrls,
              subtitle: l10n.settingsHubShowLinkUrlsSubtitle,
              value: () => store.showLinkUrls,
              onChanged: store.setShowLinkUrls,
            ),
            _StoreToggle(
              icon: CupertinoIcons.play_rectangle_fill,
              tone: TileTone.pink,
              title: l10n.settingsAutoplayExpressionsLabel,
              subtitle: store.autoplayExpressions
                  ? l10n.settingsAutoplayExpressionsOnBody
                  : l10n.settingsAutoplayExpressionsOffBody,
              value: () => store.autoplayExpressions,
              onChanged: store.setAutoplayExpressions,
            ),
            _StoreToggle(
              icon: CupertinoIcons.smiley_fill,
              tone: TileTone.orange,
              title: l10n.settingsStickerSuggestionsLabel,
              subtitle: l10n.settingsStickerSuggestionsBody,
              value: () => store.stickerSuggestions,
              onChanged: store.setStickerSuggestions,
            ),
          ],
        ),

        GroupedSection(
          header: l10n.settingsHubSectionNotifications,
          children: [
            _StoreToggle(
              icon: CupertinoIcons.bell_fill,
              tone: TileTone.red,
              title: l10n.settingsHubPush,
              subtitle: l10n.settingsHubPushSubtitle,
              value: () => store.pushEnabled,
              onChanged: (v) async {
                await store.setPushEnabled(v);
                if (v) {
                  await PushManager.instance.optIn();
                } else {
                  await PushManager.instance.optOut();
                }
              },
            ),
            // Nested under push, and only while it is on: a reminder toggle
            // offered to somebody who turned notifications off has nothing to
            // control.
            if (store.pushEnabled) ...[
              _StoreToggle(
                icon: CupertinoIcons.game_controller_solid,
                tone: TileTone.purple,
                title: l10n.settingsHubGameReminders,
                subtitle: l10n.settingsHubGameRemindersSubtitle,
                value: () => store.gameReminders,
                onChanged: (v) async {
                  await store.setGameReminders(v);
                  await PushManager.instance.setGameReminders(v);
                },
              ),
              _StoreToggle(
                icon: CupertinoIcons.person_2_fill,
                tone: TileTone.green,
                title: l10n.settingsHubFriendActivity,
                subtitle: l10n.settingsHubFriendActivitySubtitle,
                value: () => store.friendActivity,
                onChanged: (v) async {
                  await store.setFriendActivity(v);
                  await PushManager.instance.setFriendActivity(v);
                },
              ),
            ],
            // Android's two call-delivery settings and macOS's menu-bar item.
            // Each renders as no rows at all when there is nothing to show.
            ..._CallDeliveryRows.rows(context, _callDelivery),
            if (_menuBarVisible != null)
              _HubToggle(
                icon: CupertinoIcons.device_laptop,
                tone: TileTone.gray,
                title: l10n.settingsHubMenuBar,
                subtitle: l10n.settingsHubMenuBarSubtitle,
                value: _menuBarVisible!,
                onChanged: MacAppChrome.instance.setVisible,
              ),
          ],
        ),

        GroupedSection(
          header: l10n.settingsHubSectionCalls,
          children: [
            _HubRow(
              icon: CupertinoIcons.videocam_fill,
              tone: TileTone.green,
              title: l10n.settingsScreenRowVideoQuality,
              value: _videoQualityLabel,
              selected: _isOpen('videoQuality'),
              onTap: () =>
                  _open('videoQuality', (_) => const VideoQualityScreen()),
            ),
            _StoreToggle(
              icon: CupertinoIcons.speedometer,
              tone: TileTone.gray,
              title: l10n.settingsHubCallStats,
              subtitle: l10n.settingsHubCallStatsSubtitle,
              value: () => store.showNetworkStats,
              onChanged: store.setShowNetworkStats,
            ),
          ],
        ),

        GroupedSection(
          header: l10n.settingsHubSectionAppearance,
          children: [
            _HubRow(
              icon: CupertinoIcons.paintbrush_fill,
              tone: TileTone.indigo,
              title: l10n.settingsHubTheme,
              // "Auto · Midnight" while it follows the device, so the row says
              // the theme will change by itself before it does.
              value: store.appearanceMode == AppearanceMode.system
                  ? l10n.settingsHubThemeAuto(activeTheme.name)
                  : activeTheme.name,
              selected: _isOpen('theme'),
              onTap: () => _open('theme', (_) => const ThemeScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.app_fill,
              tone: TileTone.blue,
              title: l10n.settingsHubAppIcon,
              value: _logoLabel,
              selected: _isOpen('logo'),
              onTap: () => _open('logo', (_) => const LogoScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.drop_fill,
              tone: TileTone.teal,
              title: l10n.settingsHubGlass,
              value: _glassLabel,
              selected: _isOpen('glass'),
              onTap: () => _open('glass', (_) => const GlassScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.square_grid_2x2_fill,
              tone: TileTone.orange,
              title: l10n.settingsHubNavigation,
              value: _navLabel,
              selected: _isOpen('navigation'),
              onTap: () =>
                  _open('navigation', (_) => const NavigationScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.wand_stars,
              tone: TileTone.pink,
              title: l10n.settingsHubMotion,
              value: _motionLabel,
              selected: _isOpen('motion'),
              onTap: () => _open('motion', (_) => const MotionScreen()),
            ),
          ],
        ),

        // A companion is not a rendering preference: it is a resident that
        // costs hundreds of megabytes and runs a model on the handset, so it
        // gets its own section. One row per resident, so the value can say
        // something specific — "Translating into Türkçe" beats "On".
        GroupedSection(
          header: l10n.settingsHubSectionCompanions,
          margin: const EdgeInsets.only(bottom: 8),
          children: [
            _CompanionRow(
              companion: Companion.sebastian,
              selected: _isOpen('sebastian'),
              onTap: () => _open('sebastian', (_) => const SebastianScreen()),
            ),
            _CompanionRow(
              companion: Companion.marlowe,
              selected: _isOpen('marlowe'),
              onTap: () => _open('marlowe', (_) => const MarloweScreen()),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: CompanionStorageLine(),
        ),

        GroupedSection(
          header: l10n.settingsHubSectionChats,
          children: [
            _HubRow(
              icon: CupertinoIcons.list_bullet,
              tone: TileTone.blue,
              title: l10n.settingsHubChatList,
              value: _layoutLabel,
              selected: _isOpen('roomLayout'),
              onTap: () =>
                  _open('roomLayout', (_) => const RoomLayoutScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.chat_bubble_2_fill,
              tone: TileTone.green,
              title: l10n.settingsHubChatStyle,
              value: _chatStyleLabel,
              selected: _isOpen('chatStyle'),
              onTap: () => _open('chatStyle', (_) => const ChatStyleScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.bubble_left_fill,
              tone: TileTone.teal,
              title: l10n.settingsHubBubbleStyle,
              value: _bubbleStyleLabel,
              selected: _isOpen('bubbleStyle'),
              onTap: () =>
                  _open('bubbleStyle', (_) => const BubbleStyleScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.paintbrush,
              tone: TileTone.orange,
              title: l10n.settingsHubSpeakerColors,
              value: _speakerTintLabel,
              selected: _isOpen('speakerColors'),
              onTap: () =>
                  _open('speakerColors', (_) => const SpeakerColorScreen()),
            ),
            _HubRow(
              icon: CupertinoIcons.reply,
              tone: TileTone.indigo,
              title: l10n.settingsHubReplyStyle,
              value: _replyStyleLabel,
              selected: _isOpen('replyStyle'),
              onTap: () => _open(
                'replyStyle',
                (_) => ReplyStyleScreen(api: widget.api),
              ),
            ),
          ],
        ),

        // The privacy policy stays unconditional: Guideline 5.1.1(i) and
        // Google's User Data policy want one reachable for EVERY account,
        // children included, and Settings is the one screen all of them open.
        GroupedSection(
          header: l10n.settingsHubSectionHelp,
          children: [
            _HubRow(
              icon: CupertinoIcons.ant_fill,
              tone: TileTone.red,
              title: l10n.reportProblemRowLabel,
              selected: _isOpen('report'),
              onTap: () => _open(
                'report',
                (_) => ReportProblemScreen(auth: widget.auth, api: widget.api),
              ),
            ),
            _HubRow(
              icon: CupertinoIcons.hand_raised_fill,
              tone: TileTone.blue,
              title: l10n.settingsHubPrivacyPolicy,
              onTap: () => LinkOpener.open(context, kPrivacyPolicyUrl),
            ),
            _HubRow(
              icon: CupertinoIcons.doc_text_fill,
              tone: TileTone.gray,
              title: l10n.settingsHubTerms,
              onTap: () => LinkOpener.open(context, kTermsOfServiceUrl),
            ),
            _HubRow(
              icon: CupertinoIcons.doc_fill,
              tone: TileTone.gray,
              title: l10n.settingsHubLicence,
              onTap: () => LinkOpener.open(context, kEulaUrl),
            ),
          ],
        ),

        // Last. Which server holds the account is not a preference — changing
        // it signs this device out — so it sits below everything that is one.
        // Hidden from children: a supervised device is pinned to a family on
        // ONE deployment and cannot sign itself out to leave.
        if (!widget.auth.isChild)
          GroupedSection(
            header: l10n.settingsHubSectionAdvanced,
            children: [_ServerRow(selected: _isOpen('server'))],
          ),

        const SizedBox(height: 4),
        Center(child: _VersionStamp()),
      ],
    );
  }

  // ── Platform rows whose state lives outside SettingsStore ──────────────

  /// Android call-delivery permissions: null = not read yet (treated as fine
  /// so nothing scary flashes in).
  final _callDelivery = _CallDeliveryState();

  bool? get _menuBarVisible =>
      MacAppChrome.isSupported ? MacAppChrome.instance.visible : null;
}

/// The account at the top of the list, the way iOS Settings puts your Apple
/// Account there: a large face, the name, the handle and what is inside.
class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.user,
    required this.api,
    required this.hint,
    required this.pending,
    required this.selected,
    required this.onTap,
  });

  final ChatUser user;
  final ChatApi api;
  final String hint;
  final int pending;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final u = widget.user;
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: u.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration:
              _pressed ? Duration.zero : const Duration(milliseconds: 260),
          color: _rowFill(theme, pressed: _pressed, selected: widget.selected),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              UserAvatar(user: u, size: 60, api: widget.api, showStatus: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.displayName,
                      style: theme.displaySmall.copyWith(
                        fontSize: 20,
                        color: theme.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${u.username}',
                      style: theme.bodySoft.copyWith(
                        fontSize: 15,
                        color: theme.inkSoft,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.hint,
                      style: theme.bodySoft.copyWith(
                        fontSize: 13,
                        color: theme.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.pending > 0) ...[
                const SizedBox(width: 8),
                _RedBadge(count: widget.pending),
              ],
              const SizedBox(width: 8),
              _Chevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The fill a hub row takes when pressed, or when it is the page open in the
/// desktop detail pane — the selected cell of a split view.
Color _rowFill(AppTheme theme, {required bool pressed, required bool selected}) {
  if (pressed) return theme.ink.withValues(alpha: 0.08);
  if (selected) return theme.accent.withValues(alpha: 0.14);
  return Colors.transparent;
}

class _Chevron extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Icon(
      CupertinoIcons.chevron_forward,
      size: 15,
      color: theme.inkMuted.withValues(alpha: 0.7),
    );
  }
}

class _RedBadge extends StatelessWidget {
  const _RedBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.danger,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: theme.caption.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// A [GroupedRow] that can also show itself as the page open in the desktop
/// detail pane. A subclass rather than a wrapper so [GroupedSection] still
/// recognises it and insets the hairline under it to the text.
class _HubRow extends GroupedRow {
  const _HubRow({
    required super.title,
    required IconData super.icon,
    super.tone,
    super.value,
    super.onTap,
    super.trailing,
    super.chevron,
    super.badge,
    this.selected = false,
    this.leading,
  });

  final bool selected;

  /// Replaces the coloured tile with any 30×30 widget (a companion's mark).
  final Widget? leading;

  @override
  State<GroupedRow> createState() => _HubRowState();
}

class _HubRowState extends State<GroupedRow> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget as _HubRow;
    final theme = ThemeScope.of(context);
    if (w.leading == null) {
      // The plain row draws its own press highlight; the selected fill sits
      // under it.
      return ColoredBox(
        color: _rowFill(theme, pressed: false, selected: w.selected),
        child: GroupedRow(
          title: w.title,
          icon: w.icon,
          tone: w.tone,
          value: w.value,
          onTap: w.onTap,
          trailing: w.trailing,
          chevron: w.chevron,
          badge: w.badge,
        ),
      );
    }
    return FocusableTap(
      onTap: w.onTap,
      semanticLabel: w.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: w.onTap,
        child: AnimatedContainer(
          duration:
              _pressed ? Duration.zero : const Duration(milliseconds: 260),
          color: _rowFill(theme, pressed: _pressed, selected: w.selected),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
          child: Row(
            children: [
              SizedBox(width: 30, height: 30, child: w.leading),
              const SizedBox(width: 16),
              // The name is a proper noun and never breaks; the status beside
              // it is what gives way.
              Text(
                w.title,
                maxLines: 1,
                style: theme.body.copyWith(
                  fontSize: 17,
                  height: 1.25,
                  color: theme.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  w.value ?? '',
                  style: theme.body.copyWith(
                    fontSize: 17,
                    color: theme.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 8),
              _Chevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A switch row with its tap haptic. `Switch.adaptive` is silent even on iOS,
/// where the real UISwitch always ticks.
class _HubToggle extends StatelessWidget {
  const _HubToggle({
    required this.icon,
    required this.tone,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final TileTone tone;
  final String title;
  final String? subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) => GroupedRow.toggle(
        icon: icon,
        tone: tone,
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: (v) {
          HapticFeedback.lightImpact();
          onChanged(v);
        },
      );
}

/// A [_HubToggle] over a [SettingsStore] value. The hub rebuilds on every
/// store change, so this reads the value fresh each build.
class _StoreToggle extends StatelessWidget {
  const _StoreToggle({
    required this.icon,
    required this.tone,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final TileTone tone;
  final String title;
  final String? subtitle;
  final bool Function() value;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) => _HubToggle(
        icon: icon,
        tone: tone,
        title: title,
        subtitle: subtitle,
        value: value(),
        onChanged: onChanged,
      );
}

/// One resident, its monogram on a coloured tile where the other rows have a
/// glyph. Never a sparkle or a brain: every icon that reads as "AI" says the
/// opposite of what a companion is for (see [CompanionMark]).
///
/// The label is the companion's name, the same in every locale, and the value
/// comes from [companionStatusLine] so this row and the screen it opens can
/// never disagree.
class _CompanionRow extends StatelessWidget {
  const _CompanionRow({
    required this.companion,
    required this.onTap,
    this.selected = false,
  });

  final Companion companion;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return _HubRow(
      icon: CupertinoIcons.person_fill,
      title: companion.displayName,
      value: companionStatusLine(companion, AppLocalizations.of(context)),
      selected: selected,
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CompanionMark(
          companion: companion,
          size: 30,
          foreground: Colors.white,
          background: tileColor(
            theme,
            companion == Companion.sebastian ? TileTone.indigo : TileTone.teal,
          ),
        ),
      ),
    );
  }
}

/// The way into [ServerScreen], showing which deployment is live. Rebuilds on
/// [ServerStore], which nothing else on this screen listens to.
class _ServerRow extends StatelessWidget {
  const _ServerRow({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerStore.instance,
      builder: (context, _) {
        final theme = ThemeScope.of(context);
        final l10n = AppLocalizations.of(context);
        final store = ServerStore.instance;
        // isSelfHosted, NOT isCustom: following a directive onto the home
        // server writes a custom URL too, and reading isCustom presented a
        // temporary move as a self-hosting choice the user had made.
        final own = store.isSelfHosted;
        return _HubRow(
          icon: CupertinoIcons.cloud_fill,
          tone: TileTone.gray,
          title: l10n.settingsHubServer,
          // The address only ever appears for a server the user typed in; the
          // operator's deployment URLs are infrastructure.
          value: own
              ? shortHost(store.host)
              : (store.role == ServerRole.homeserver
                    ? l10n.serverValueHomeserver
                    : l10n.serverValueDefault),
          trailing: store.announcesRole
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          chevron: true,
          selected: selected,
          onTap: () => openSettingsDetail(
            context,
            key: 'server',
            builder: (_) => const ServerScreen(),
          ),
        );
      },
    );
  }
}

/// Android's two call-delivery permissions — full-screen intents and the
/// battery exemption — as rows that exist only while something is wrong.
///
/// These used to be asked for during onboarding, ejecting a brand-new user
/// into system settings before they had sent a message. Here they are
/// reachable when someone goes looking because calls are not ringing, and
/// silent otherwise: a granted permission renders no row at all.
class _CallDeliveryState extends ChangeNotifier with WidgetsBindingObserver {
  _CallDeliveryState() {
    if (!AndroidCallReliability.supported) return;
    // Both fixes happen in a system page we don't control, so coming back to
    // the app is the only signal one landed. Re-read on every resume.
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  bool? fullScreen;
  bool? battery;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    fullScreen =
        await AndroidCallReliability.instance.fullScreenIntentAllowed();
    battery = await AndroidCallReliability.instance.batteryExempt();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

abstract final class _CallDeliveryRows {
  static List<Widget> rows(BuildContext context, _CallDeliveryState state) {
    if (!AndroidCallReliability.supported) return const [];
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    Widget row(IconData icon, String title, VoidCallback onTap) => _HubRow(
          icon: icon,
          tone: TileTone.red,
          title: title,
          trailing: Text(
            l10n.settingsCallDeliveryStatusOff,
            style: theme.body.copyWith(fontSize: 15, color: theme.danger),
          ),
          chevron: true,
          onTap: onTap,
        );
    return [
      if (state.fullScreen == false)
        row(
          CupertinoIcons.lock_fill,
          l10n.settingsCallDeliveryLockScreenLabel,
          AndroidCallReliability.instance.openFullScreenIntentSettings,
        ),
      if (state.battery == false)
        row(
          CupertinoIcons.battery_25,
          l10n.settingsCallDeliveryBackgroundLabel,
          AndroidCallReliability.instance.openBatterySettings,
        ),
    ];
  }
}

/// Manual counterpart to `UpdateChecker.ensure`'s launch-time check — every
/// tap is a real round trip. Reflects `UpdateAvailability` so the row stays lit
/// after a launch check the user dismissed with LATER.
class _CheckForUpdatesRow extends StatefulWidget {
  const _CheckForUpdatesRow();

  @override
  State<_CheckForUpdatesRow> createState() => _CheckForUpdatesRowState();
}

class _CheckForUpdatesRowState extends State<_CheckForUpdatesRow> {
  bool _checking = false;

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final outcome = await UpdateChecker.instance.checkNow();
    if (!mounted) return;
    setState(() => _checking = false);
    final l10n = AppLocalizations.of(context);
    // `available` already showed the update sheet — nothing left to say here.
    final message = switch (outcome) {
      UpdateCheckOutcome.available => null,
      UpdateCheckOutcome.upToDate => l10n.settingsScreenUpdateUpToDateSnackbar,
      UpdateCheckOutcome.unsupported =>
        l10n.settingsScreenUpdateUnsupportedSnackbar,
      UpdateCheckOutcome.error => l10n.settingsScreenUpdateErrorSnackbar,
    };
    if (message != null) showAppToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UpdateAvailability.instance,
      builder: (context, _) {
        final theme = ThemeScope.of(context);
        final l10n = AppLocalizations.of(context);
        final available = UpdateAvailability.instance.available;
        return _HubRow(
          icon: CupertinoIcons.arrow_down_circle_fill,
          tone: TileTone.gray,
          title: l10n.settingsHubCheckForUpdates,
          badge: available && !_checking ? 1 : 0,
          trailing: _checking
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(theme.inkMuted),
                  ),
                )
              : (available
                    ? Text(
                        l10n.settingsHubUpdateAvailable,
                        style: theme.body.copyWith(
                          fontSize: 15,
                          color: theme.accent,
                        ),
                      )
                    : null),
          chevron: true,
          onTap: _check,
        );
      },
    );
  }
}

class _VersionStamp extends StatefulWidget {
  @override
  State<_VersionStamp> createState() => _VersionStampState();
}

class _VersionStampState extends State<_VersionStamp> {
  String? _stamp;

  /// Taps inside the current window, for the tap-count route into diagnostics.
  int _taps = 0;
  DateTime? _firstTap;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _stamp = 'MonkeyHub · v${info.version}');
  }

  /// Opens the diagnostics viewer. Reachable on every device: [Redactor]
  /// withholds message content, credentials and capability URLs at capture
  /// time, so the log holds nothing a stranger could use. The five taps — or
  /// a long press — on an unlabelled version string keep it out of the way,
  /// not out of reach.
  void _openDiagnostics() {
    openSettingsDetail(
      context,
      key: 'diagnostics',
      builder: (_) => const DiagnosticsScreen(),
    );
  }

  void _onTap() {
    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > _tapWindow) {
      _firstTap = now;
      _taps = 0;
    }
    _taps++;
    if (_taps >= _tapsNeeded) {
      _taps = 0;
      _firstTap = null;
      _openDiagnostics();
      return;
    }
    if (_taps >= 3 && mounted) {
      showAppToast(
        context,
        'Diagnostics in ${_tapsNeeded - _taps}…',
        duration: const Duration(milliseconds: 600),
      );
    }
  }

  static const int _tapsNeeded = 5;
  static const Duration _tapWindow = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Two triggers on purpose: the bug this exists to diagnose includes taps
    // that do not land, so the long press is the one that works there.
    //
    // Deliberately NOT wrapped in FocusableTap: its semantics label would
    // announce a hidden developer affordance to every screen-reader user.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onLongPress: _openDiagnostics,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Text(
          _stamp ?? 'MonkeyHub',
          style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
        ),
      ),
    );
  }
}
