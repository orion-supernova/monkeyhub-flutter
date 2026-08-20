import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../calls/call_models.dart' show VideoQualityTier;
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
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
import '../theme/bubble_shape.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../update/update_availability.dart';
import '../update/update_checker.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_brand_mark.dart' show canonicalLogoId;
import '../widgets/count_badge.dart';
import '../widgets/detail_link_row.dart';
import '../widgets/monkey_collection.dart';
import '../widgets/self_host_badge.dart' show shortHost;
import '../widgets/recovery_banner.dart';
import '../widgets/user_avatar.dart';
import 'bubble_style_screen.dart';
import 'chat_style_screen.dart';
import 'diagnostics_screen.dart';
import 'glass_screen.dart';
import 'language_screen.dart';
import 'reply_style_screen.dart';
import 'logo_screen.dart';
import 'motion_screen.dart';
import 'navigation_screen.dart';
import 'navigation/destinations.dart';
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
    ScrollMemory.restore('settings', _scroll);
    SettingsStore.instance.addListener(_onSettings);
    widget.family.addListener(_onSettings);
    widget.auth.addListener(_onAuth);
    // Rebuild when the desktop settings pane's selection changes so the active
    // row highlights.
    UiSelectionStore.instance.addListener(_onSettings);
    // The approvals badge should be right whenever this screen is opened.
    widget.family.refresh();
    _loadMe();
  }

  @override
  void dispose() {
    ScrollMemory.save('settings', _scroll);
    SettingsStore.instance.removeListener(_onSettings);
    widget.family.removeListener(_onSettings);
    widget.auth.removeListener(_onAuth);
    UiSelectionStore.instance.removeListener(_onSettings);
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
      if (!mounted || fresh == null) return;
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
        ? l10n.settingsScreenAccountHintChild
        : l10n.settingsScreenAccountHintAdult;
  }

  String get _layoutLabel {
    final l10n = AppLocalizations.of(context);
    return SettingsStore.instance.roomLayout == RoomLayout.list
        ? l10n.settingsScreenValueScrollList
        : l10n.settingsScreenValueGridSheet;
  }

  String get _navLabel {
    final l10n = AppLocalizations.of(context);
    return SettingsStore.instance.navStyle == NavStyle.radial
        ? l10n.settingsScreenValueRadialOrb
        : l10n.settingsScreenValueBottomPill;
  }

  /// The active look's name, marked when it has been tuned away from what it
  /// saved. 'Custom' only when nothing is selected at all.
  String get _glassLabel {
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.instance;
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

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final activeTheme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = widget.auth.session;
    return Stack(
      children: [
        theme.backgroundLayer(context),
        SafeArea(
          // See home_screen: the bottom inset leaves a dead strip of background
          // under the scroller. The list's own bottom padding clears the
          // floating pill and the home indicator.
          bottom: false,
          // On a tablet-width standalone window (before the two-pane shell
          // kicks in at WindowClass.expanded) this keeps rows from
          // stretching edge to edge; a no-op in the desktop shell's fixed
          // 360px master pane, since that's already narrower than the cap.
          child: AdaptivePageBody(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                20,
                28,
                20,
                sectionBottomPadding(context),
              ),
              children: [
                Text(
                  l10n.settingsScreenTitle,
                  style: theme.label.copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 28),
                Text(l10n.settingsScreenTagline, style: theme.displayLarge),
                const SizedBox(height: 28),
                if (s != null) ...[
                  // An account with no recovery phrase is one forgotten password
                  // away from being gone. Shown here because Settings is the
                  // screen people actually open — profile carries the same
                  // banner. `_loadMe()` already fetches with viewerUserId ==
                  // userId, so hasRecoveryKey arrives with no extra query.
                  //
                  // Explicitly `== false`: null means "unknown" (older backend,
                  // or not a self-fetch) and must not be read as "none set".
                  // The isChild check is belt-and-braces — the server already
                  // returns null for children, who have no reset path at all.
                  if (_me?.hasRecoveryKey == false && !widget.auth.isChild) ...[
                    RecoveryPhraseBanner(
                      onTap: () => openSettingsDetail(
                        context,
                        key: 'profile',
                        builder: (_) => ProfileScreen(
                          user: _me!,
                          repo: widget.repo,
                          api: widget.api,
                          auth: widget.auth,
                          family: widget.family,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  () {
                    final me =
                        _me ??
                        ChatUser(
                          id: s.userId,
                          username: s.username,
                          name: s.name,
                        );
                    return GestureDetector(
                      onTap: () => openSettingsDetail(
                        context,
                        key: 'profile',
                        builder: (_) => ProfileScreen(
                          user: me,
                          repo: widget.repo,
                          api: widget.api,
                          auth: widget.auth,
                          family: widget.family,
                        ),
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: theme.roomCardDecoration(
                          ephemeral: false,
                          active: _isOpen('profile'),
                        ),
                        child: Row(
                          children: [
                            UserAvatar(user: me, size: 48, api: widget.api),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    me.displayName,
                                    style: theme.displaySmall,
                                  ),
                                  Text(
                                    '@${me.username}',
                                    style: theme.mono.copyWith(
                                      color: theme.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // Says where the account settings went, now
                                  // that family is one of them.
                                  Text(
                                    _accountHint,
                                    style: theme.monoTiny.copyWith(
                                      color: theme.inkMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Approvals used to badge their own top-level row.
                            // That row now lives inside the account screen, so
                            // the count rides the way in — otherwise a guardian
                            // would have to go looking to find out anything was
                            // waiting.
                            if (widget.family.pendingCount > 0) ...[
                              CountBadge(count: widget.family.pendingCount),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: theme.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    );
                  }(),
                ],
                const SizedBox(height: 24),

                // Sections run in descending order of how often anyone opens
                // them, not in the order they were built. The nine appearance
                // and chat-styling rows used to sit up here, which meant that
                // changing your language or silencing push started with a scroll
                // past six flavours of message bubble. The customisation is the
                // part people browse; the rest is the part they came for.
                _SectionHeader(label: l10n.settingsScreenSectionGeneral),
                const SizedBox(height: 12),
                _DisclosureRow(
                  label: l10n.settingsLanguageRowLabel,
                  value: _languageLabel,
                  selected: _isOpen('language'),
                  leading: Icon(
                    Icons.language_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'language',
                    builder: (_) => const LanguageScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                const _CheckForUpdatesRow(),
                const SizedBox(height: 10),
                // Absorbed from a LINKS section that existed to hold this one
                // toggle. A heading, a gap and a scroll for a single switch is a
                // worse deal than the switch is worth, and how a link renders is
                // a reading preference like any other on this list.
                _ShowLinkUrlsToggle(),

                const SizedBox(height: 28),
                _SectionHeader(label: l10n.settingsScreenSectionNotifications),
                const SizedBox(height: 12),
                _PushToggle(),
                // Android's two call-delivery settings. Renders nothing at all
                // when there is nothing to fix — see _CallDeliveryRows.
                const _CallDeliveryRows(),

                const SizedBox(height: 28),
                _SectionHeader(label: l10n.settingsScreenSectionCalls),
                const SizedBox(height: 12),
                _DisclosureRow(
                  label: l10n.settingsScreenRowVideoQuality,
                  value: _videoQualityLabel,
                  selected: _isOpen('videoQuality'),
                  leading: Icon(
                    Icons.high_quality_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'videoQuality',
                    builder: (_) => const VideoQualityScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _ShowNetworkStatsToggle(),

                // Appearance is everything that dresses the app as a whole —
                // Navigation and Motion moved in from LAYOUT because a switcher
                // animation is app chrome, not a property of a conversation.
                const SizedBox(height: 28),
                _SectionHeader(label: l10n.settingsScreenSectionAppearance),
                const SizedBox(height: 12),
                _DisclosureRow(
                  label: l10n.settingsScreenRowTheme,
                  value: activeTheme.name,
                  selected: _isOpen('theme'),
                  leading: _SwatchDot(color: activeTheme.accent),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'theme',
                    builder: (_) => const ThemeScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _DisclosureRow(
                  label: l10n.settingsScreenRowAppLogo,
                  value: _logoLabel,
                  selected: _isOpen('logo'),
                  leading: Icon(
                    Icons.workspaces_outline,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'logo',
                    builder: (_) => const LogoScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _DisclosureRow(
                  label: l10n.settingsScreenRowGlass,
                  value: _glassLabel,
                  selected: _isOpen('glass'),
                  leading: Icon(
                    Icons.blur_on_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'glass',
                    builder: (_) => const GlassScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _DisclosureRow(
                  label: l10n.settingsScreenRowNavigation,
                  value: _navLabel,
                  selected: _isOpen('navigation'),
                  leading: Icon(
                    Icons.swap_horiz,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'navigation',
                    builder: (_) => const NavigationScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _DisclosureRow(
                  label: l10n.settingsScreenRowMotion,
                  value: _motionLabel,
                  selected: _isOpen('motion'),
                  leading: Icon(
                    Icons.animation_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'motion',
                    builder: (_) => const MotionScreen(),
                  ),
                ),

                // What used to be LAYOUT, minus the two rows that were never
                // about layout. Everything left answers one question — how a
                // conversation renders — so the header says so.
                const SizedBox(height: 28),
                _SectionHeader(label: l10n.settingsScreenSectionChat),
                const SizedBox(height: 12),
                _DisclosureRow(
                  label: l10n.settingsScreenRowChatList,
                  value: _layoutLabel,
                  selected: _isOpen('roomLayout'),
                  leading: Icon(
                    Icons.dashboard_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'roomLayout',
                    builder: (_) => const RoomLayoutScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _DisclosureRow(
                  label: l10n.settingsScreenRowChatStyle,
                  value: _chatStyleLabel,
                  selected: _isOpen('chatStyle'),
                  leading: Icon(
                    Icons.bubble_chart_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'chatStyle',
                    builder: (_) => const ChatStyleScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _DisclosureRow(
                  label: l10n.settingsScreenRowBubbleStyle,
                  value: _bubbleStyleLabel,
                  selected: _isOpen('bubbleStyle'),
                  leading: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'bubbleStyle',
                    builder: (_) => const BubbleStyleScreen(),
                  ),
                ),
                const SizedBox(height: 10),
                _DisclosureRow(
                  label: l10n.settingsScreenRowReplyStyle,
                  value: _replyStyleLabel,
                  selected: _isOpen('replyStyle'),
                  leading: Icon(
                    Icons.reply_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'replyStyle',
                    builder: (_) => ReplyStyleScreen(api: widget.api),
                  ),
                ),

                // Report a Problem used to float here without a header of its
                // own, in the middle of the screen. It belongs with the legal
                // links by the same argument that brought those up from Profile:
                // none of the four says anything about the account you are
                // looking at — they are facts about the app.
                //
                // The privacy policy stays unconditional, and it has to:
                // Guideline 5.1.1(i) and Google's User Data policy both want one
                // reachable from inside the app for EVERY account, children
                // included, and Settings is the one screen all of them can open.
                const SizedBox(height: 28),
                _SectionHeader(label: l10n.settingsScreenSectionHelpAndLegal),
                const SizedBox(height: 12),
                _DisclosureRow(
                  label: l10n.reportProblemRowLabel,
                  value: l10n.reportProblemRowValue,
                  selected: _isOpen('report'),
                  leading: Icon(
                    Icons.bug_report_outlined,
                    size: 16,
                    color: theme.inkSoft,
                  ),
                  onTap: () => openSettingsDetail(
                    context,
                    key: 'report',
                    builder: (_) =>
                        ReportProblemScreen(auth: widget.auth, api: widget.api),
                  ),
                ),
                const SizedBox(height: 10),
                // The same row Profile stacks — these three came from there, and
                // arriving looking like something else would read as three new
                // rows rather than three moved ones.
                DetailLinkRow(
                  label: l10n.settingsScreenPrivacyPolicy,
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => LinkOpener.open(context, kPrivacyPolicyUrl),
                ),
                const SizedBox(height: 10),
                DetailLinkRow(
                  label: l10n.settingsScreenTermsOfService,
                  icon: Icons.gavel_outlined,
                  onTap: () => LinkOpener.open(context, kTermsOfServiceUrl),
                ),
                const SizedBox(height: 10),
                DetailLinkRow(
                  label: l10n.settingsScreenLicence,
                  icon: Icons.description_outlined,
                  onTap: () => LinkOpener.open(context, kEulaUrl),
                ),

                // Last, and in a section of its own. Which server holds the
                // account is not a preference — changing it signs this device out
                // and starts over — so it sits below everything that is one,
                // where nobody arrives at it by scrolling.
                //
                // Hidden from children entirely: a supervised device is pinned to
                // a family that exists on ONE deployment, and it cannot sign
                // itself out to leave (see `ServerSwitch`). A row that would
                // refuse is worse than no row.
                if (!widget.auth.isChild) ...[
                  const SizedBox(height: 28),
                  _SectionHeader(label: l10n.settingsScreenSectionAdvanced),
                  const SizedBox(height: 12),
                  _ServerRow(selected: _isOpen('server')),
                ],

                const SizedBox(height: 36),
                _VersionStamp(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.label.copyWith(letterSpacing: 2.8, color: theme.accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: theme.divider)),
      ],
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.leading,
    this.selected = false,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? leading;

  /// Whether this row's sub-screen is currently open in the desktop detail
  /// pane. Renders an accent-tinted surface so the two-pane selection is clear.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: 0.14)
              : theme.surface,
          border: Border.all(
            color: selected
                ? theme.accent.withValues(alpha: 0.4)
                : theme.divider,
          ),
          borderRadius: BorderRadius.circular(theme.radiusMd),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            SizedBox(width: 110, child: Text(label, style: theme.label)),
            Expanded(
              child: Text(
                value,
                style: theme.body.copyWith(color: theme.inkSoft),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// The way into [ServerScreen], showing which deployment is live.
///
/// Its own widget rather than a [_DisclosureRow] for one reason: it has to
/// rebuild when [ServerStore] changes, and everything else on this screen is
/// driven off [SettingsStore]. It borrows the disclosure row's exact geometry
/// so it still reads as one of the list.
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
        // isSelfHosted, NOT isCustom. Following a directive onto the home
        // server writes a custom URL, so isCustom is true there too — and
        // reading it is what made this row present a temporary move as a
        // self-hosting choice the user had made.
        final own = store.isSelfHosted;
        final marked = store.announcesRole;
        return GestureDetector(
          onTap: () => openSettingsDetail(
            context,
            key: 'server',
            builder: (_) => const ServerScreen(),
          ),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: selected
                  ? theme.accent.withValues(alpha: 0.14)
                  : theme.surface,
              border: Border.all(
                color: selected || marked
                    ? theme.accent.withValues(alpha: 0.4)
                    : theme.divider,
              ),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.dns_outlined,
                  size: 16,
                  color: marked ? theme.accent : theme.inkSoft,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: Text(l10n.settingsScreenRowServer, style: theme.label),
                ),
                Expanded(
                  child: Text(
                    // The address only ever appears for a server the user
                    // typed in. The operator's deployment URLs are
                    // infrastructure, not something to publish on every user's
                    // settings screen.
                    own
                        ? shortHost(store.host)
                        : (store.role == ServerRole.homeserver
                              ? l10n.serverValueHomeserver
                              : l10n.serverValueDefault),
                    style: theme.body.copyWith(
                      color: marked ? theme.accent : theme.inkSoft,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider, width: 0.5),
      ),
    );
  }
}

class _PushToggle extends StatefulWidget {
  @override
  State<_PushToggle> createState() => _PushToggleState();
}

class _PushToggleState extends State<_PushToggle> {
  Future<void> _toggle(bool v) async {
    await SettingsStore.instance.setPushEnabled(v);
    if (v) {
      await PushManager.instance.optIn();
    } else {
      await PushManager.instance.optOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final on = SettingsStore.instance.pushEnabled;
        return GestureDetector(
          onTap: () => _toggle(!on),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  on
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 16,
                  color: on ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsScreenPushNotificationsLabel,
                        style: theme.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        on
                            ? l10n.settingsScreenPushOnBody
                            : l10n.settingsScreenPushOffBody,
                        style: theme.bodySoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: on,
                  onChanged: _toggle,
                  activeThumbColor: theme.accent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The Android-only OS settings that decide whether a call reaches the user:
/// full-screen-intent access and the battery-optimization exemption.
///
/// These used to be asked for during onboarding, from a post-frame callback in
/// `_bootstrap` — two explain-dialogs that each ejected a brand-new user into a
/// system settings page before they had sent a message, with nothing equivalent
/// on iOS. This is where they live now instead: reachable when a user goes
/// looking because their calls are not ringing, and silent otherwise.
///
/// "Silent otherwise" is literal — a row that is already granted renders
/// NOTHING, so a healthy install shows an empty slot here rather than two
/// reassurance rows nobody needs. That also means the section can only ever say
/// something actionable, which is what makes "Tap to allow" sufficient as its
/// own explanation.
class _CallDeliveryRows extends StatefulWidget {
  const _CallDeliveryRows();

  @override
  State<_CallDeliveryRows> createState() => _CallDeliveryRowsState();
}

class _CallDeliveryRowsState extends State<_CallDeliveryRows>
    with WidgetsBindingObserver {
  bool? _fullScreen;
  bool? _battery;

  @override
  void initState() {
    super.initState();
    // Both fixes happen in a system settings page we don't control, so the
    // only signal that one landed is coming back to the app. Re-read on every
    // resume rather than trusting the answer from mount.
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (!AndroidCallReliability.supported) return;
    final fullScreen = await AndroidCallReliability.instance
        .fullScreenIntentAllowed();
    final battery = await AndroidCallReliability.instance.batteryExempt();
    if (!mounted) return;
    setState(() {
      _fullScreen = fullScreen;
      _battery = battery;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AndroidCallReliability.supported) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    // Null = not read yet. Treated as granted so the section never flashes a
    // scary row on the way to discovering there was nothing wrong.
    final rows = <Widget>[
      if (_fullScreen == false)
        _CallDeliveryRow(
          icon: Icons.lock_clock_outlined,
          label: l10n.settingsCallDeliveryLockScreenLabel,
          // Reuses the copy the retired pre-prompt dialog already carried in
          // all 12 locales, which says exactly what this row needs to say.
          body: l10n.bulkActionBarFullScreenIntentDialogBody,
          onTap: AndroidCallReliability.instance.openFullScreenIntentSettings,
        ),
      if (_battery == false)
        _CallDeliveryRow(
          icon: Icons.battery_saver_outlined,
          label: l10n.settingsCallDeliveryBackgroundLabel,
          body: l10n.bulkActionBarBatteryExemptionDialogBody,
          onTap: AndroidCallReliability.instance.openBatterySettings,
        ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final row in rows) ...[const SizedBox(height: 10), row],
      ],
    );
  }
}

class _CallDeliveryRow extends StatelessWidget {
  const _CallDeliveryRow({
    required this.icon,
    required this.label,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    // BOTH wrappers, per FocusableTap's doc comment: it binds Enter/Space and
    // the semantics but registers no gesture recognizer, so the bare detector
    // is what makes the row answer a touch at all.
    return FocusableTap(
      onTap: onTap,
      radius: theme.radiusMd,
      semanticLabel: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border.all(color: theme.divider),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.inkMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.label),
                    const SizedBox(height: 2),
                    Text(body, style: theme.bodySoft),
                    const SizedBox(height: 6),
                    Text(
                      l10n.settingsCallDeliveryStatusOff,
                      style: theme.monoTiny.copyWith(color: theme.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowLinkUrlsToggle extends StatelessWidget {
  Future<void> _toggle(bool v) => SettingsStore.instance.setShowLinkUrls(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final on = SettingsStore.instance.showLinkUrls;
        return GestureDetector(
          onTap: () => _toggle(!on),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  on ? Icons.link_rounded : Icons.link_off_rounded,
                  size: 16,
                  color: on ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsScreenShowLinkUrlsLabel,
                        style: theme.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        on
                            ? l10n.settingsScreenLinksUrlsOnBody
                            : l10n.settingsScreenLinksUrlsOffBody,
                        style: theme.bodySoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: on,
                  onChanged: _toggle,
                  activeThumbColor: theme.accent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShowNetworkStatsToggle extends StatelessWidget {
  Future<void> _toggle(bool v) => SettingsStore.instance.setShowNetworkStats(v);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final on = SettingsStore.instance.showNetworkStats;
        return GestureDetector(
          onTap: () => _toggle(!on),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(color: theme.divider),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.speed_outlined,
                  size: 16,
                  color: on ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsScreenShowNetworkStatsLabel,
                        style: theme.label,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.settingsScreenShowNetworkStatsBody,
                        style: theme.bodySoft,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: on,
                  onChanged: _toggle,
                  activeThumbColor: theme.accent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Manual counterpart to `UpdateChecker.ensure`'s launch-time check — every
/// tap is a real round trip to the backend, unlike `ensure`'s once-per-launch
/// guard. Reflects `UpdateAvailability` so the row itself stays lit after a
/// launch check the user dismissed with LATER, not just right after a tap.
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
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: UpdateAvailability.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final available = UpdateAvailability.instance.available;
        return GestureDetector(
          onTap: _check,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: theme.surface,
              border: Border.all(
                color: available
                    ? theme.accent.withValues(alpha: 0.4)
                    : theme.divider,
              ),
              borderRadius: BorderRadius.circular(theme.radiusMd),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.system_update_alt_rounded,
                  size: 16,
                  color: available ? theme.accent : theme.inkSoft,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsScreenCheckForUpdatesLabel,
                    style: theme.label,
                  ),
                ),
                if (_checking)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.inkMuted,
                    ),
                  )
                else ...[
                  if (available) ...[
                    Text(
                      l10n.settingsScreenUpdateAvailableValue,
                      style: theme.monoTiny.copyWith(color: theme.accent),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
                ],
              ],
            ),
          ),
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

  /// Opens the diagnostics viewer.
  ///
  /// Reachable on every device. This used to be gated on a backend allowlist,
  /// and the gate cost more than it bought: a lookup, a copy-pasted device id,
  /// a deploy and a cold start standing between a bug report and any evidence
  /// about it — while what it protected turned out not to need protecting.
  /// [Redactor] withholds message content, credentials and capability URLs at
  /// capture time, so the log holds a trace of the reader's own app timings and
  /// their own device id and nothing else. Somebody who finds this by accident
  /// learns nothing they did not already have.
  ///
  /// The obscurity that remains — five taps, or a long press, on an unlabelled
  /// version string — is there to keep it out of the way, not to keep anyone
  /// out.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 600),
          content: Text('Diagnostics in ${_tapsNeeded - _taps}…'),
        ),
      );
    }
  }

  static const int _tapsNeeded = 5;
  static const Duration _tapWindow = Duration(seconds: 3);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Two triggers on purpose. The bug this exists to diagnose includes taps
    // that do not land, so a tap burst may be untriggerable on the very device
    // we are targeting — the long-press is the one that will actually work
    // there.
    //
    // Deliberately NOT wrapped in FocusableTap, the one considered exception to
    // the both-wrappers rule used everywhere else in this file: FocusableTap
    // attaches a semantics label and keyboard activation, which would announce
    // a hidden developer affordance to every screen-reader user in the shipped
    // app. A bare detector stays invisible to everything except a finger.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onLongPress: _openDiagnostics,
      child: Text(_stamp ?? 'MonkeyHub', style: theme.monoTiny),
    );
  }
}
