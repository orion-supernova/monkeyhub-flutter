import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;

import '../backend/connection_health.dart';
import '../backend/convex_client.dart';
import '../backend/server_directory.dart';
import '../backend/server_endpoint.dart';
import '../backend/server_probe.dart';
import '../backend/server_store.dart';
import '../backend/server_switch.dart';
import '../keyboard/dismiss_keyboard_on_tap.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape;
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart' show SoftNote;
import '../widgets/labeled_field.dart';
import '../widgets/server_role_sheet.dart';
import '../widgets/ios_kit.dart';

/// Where this install connects: the deployment it shipped with, or one the user
/// runs themselves.
///
/// ───────── the shape of the screen ─────────
///
/// Top to bottom it answers four questions in the order someone actually asks
/// them: where am I now, what are my choices, does the address I typed work,
/// and what will change if I switch. The order is why the test step sits
/// BETWEEN the address field and the CONNECT button rather than behind it —
/// switching is destructive (see [ServerSwitch]) and a typo should be caught by
/// an HTTP round trip, not by signing someone out and finding the socket never
/// opens.
///
/// ───────── the two things it will not do ─────────
///
///  * **It will not refuse an address the probe disliked.** A probe can be wrong
///    — a captive portal, a corporate proxy, CORS on web, a backend mid-deploy —
///    and a check that can be wrong must never be the only door. Failing the
///    test changes the button's wording, not its existence.
///  * **It will not pretend the switch is reversible.** The warning says what
///    is actually lost, and [ServerSwitch] does exactly that and no more.
///
/// [onboarding] is the boot state where there is no server at all: `env.local`
/// carried no `CONVEX_URL` and nothing has been chosen. The screen then has no
/// back button, because there is nothing behind it.
class ServerScreen extends StatefulWidget {
  const ServerScreen({super.key, this.health, this.onboarding = false});

  /// The live connection state. Defaults to the app's monitor; the parameter
  /// exists so a widget test can hand in its own without booting the app.
  final ConnectionHealth? health;

  ConnectionHealth? get _health => health ?? ConnectionHealth.maybeInstance;

  final bool onboarding;

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

/// Which side of the choice the form is showing. Not derived from
/// `ServerStore.isCustom`, because someone on the bundled deployment has to be
/// able to open the self-host form before they have committed to anything —
/// and someone on a self-hosted one has to be able to look at the default
/// without losing what they typed.
enum _Choice { bundled, own }

class _ServerScreenState extends State<ServerScreen> {
  final _address = TextEditingController();
  final _siteAddress = TextEditingController();

  // isSelfHosted, NOT isCustom. Following a directive onto the home server
  // writes a custom URL, and reading isCustom here opened this screen with the
  // self-host form selected and the operator's address sitting in the edit
  // field — presenting a temporary move as a choice the user had made.
  late _Choice _choice = ServerStore.instance.isSelfHosted || !_hasBundled
      ? _Choice.own
      : _Choice.bundled;

  /// Open when the user wants to override where HTTP actions answer. Closed for
  /// everyone else, which is almost everyone — see [ServerEndpoint.siteUrl].
  bool _advancedOpen = false;

  final _probe = ServerProbe();

  /// The finding for the address currently in the field, or null once the text
  /// changes under it. Dropping it on edit is the point: a green tick next to
  /// an address that is no longer the one that was tested is a lie.
  ServerProbeResult? _result;
  bool _testing = false;

  /// Set when the last [ServerSwitch.apply] came back on the old server.
  /// Cleared by any subsequent edit.
  String? _switchError;

  bool get _hasBundled => ServerStore.instance.hasBundled;

  @override
  void initState() {
    super.initState();
    // Only a server the user typed in is theirs to see, let alone to edit.
    final custom = ServerStore.instance.isSelfHosted
        ? ServerStore.instance.custom
        : null;
    if (custom != null) {
      _address.text = custom.deploymentUrl;
      final site = custom.siteUrlOverride;
      if (site != null) {
        _siteAddress.text = site;
        _advancedOpen = true;
      }
    }
    ServerStore.instance.addListener(_onStores);
    ServerSwitch.instance.addListener(_onStores);
    widget._health?.addListener(_onStores);
  }

  @override
  void dispose() {
    ServerStore.instance.removeListener(_onStores);
    ServerSwitch.instance.removeListener(_onStores);
    widget._health?.removeListener(_onStores);
    _address.dispose();
    _siteAddress.dispose();
    _probe.dispose();
    super.dispose();
  }

  void _onStores() {
    if (mounted) setState(() {});
  }

  /// What the field currently resolves to, and why not if it doesn't.
  ServerUrlCheck get _check => normalizeServerUrl(_address.text);

  /// The endpoint CONNECT would apply, or null while the address is unusable.
  ServerEndpoint? get _candidate {
    final url = _check.url;
    if (url == null) return null;
    final site = normalizeServerUrl(_siteAddress.text).url;
    // An address this app already knows keeps what it knows about it, even
    // when it arrives by being typed rather than by a directive. Both operator
    // deployments serve HTTP actions under `/http` and [deriveSiteUrl] cannot
    // know that, so building this one as an ordinary self-hosted endpoint
    // would connect the socket fine and leave every upload and every action
    // pointed at an origin that answers nothing.
    //
    // Skipped the moment an override is typed: an explicit answer outranks
    // anything inferred from the host.
    if (site == null && KnownHosts.isManaged(url)) {
      return KnownHosts.endpointFor(KnownHosts.roleOf(url), url: url);
    }
    return ServerEndpoint(
      deploymentUrl: url,
      // An override equal to the derived value is not an override. Dropping it
      // here keeps `siteUrlOverride` meaning "the two are genuinely split",
      // which is what [ServerEndpoint.siteUrl] and the recents list read it as.
      siteUrlOverride: site == null || site == deriveSiteUrl(url) ? null : site,
    );
  }

  void _onAddressChanged(String _) {
    setState(() {
      _result = null;
      _switchError = null;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    _address.text = text.trim();
    _onAddressChanged(text);
  }

  Future<void> _test() async {
    final url = _check.url;
    if (url == null || _testing) return;
    setState(() {
      _testing = true;
      _result = null;
      _switchError = null;
    });
    final result = await _probe.probe(url);
    if (!mounted) return;
    // The address may have been edited while the probe was in flight — a result
    // about a URL nobody is looking at any more must not be shown as if it were
    // about this one.
    if (_check.url != url) {
      setState(() => _testing = false);
      return;
    }
    setState(() {
      _testing = false;
      _result = result;
    });
  }

  Future<void> _connect(ServerEndpoint? target) async {
    final l10n = AppLocalizations.of(context);
    final outcome = await ServerSwitch.instance.apply(target);
    if (!mounted) return;
    switch (outcome) {
      case ServerSwitchOutcome.switched:
        setState(() {
          _switchError = null;
          _result = null;
          _choice = target == null ? _Choice.bundled : _Choice.own;
        });
        // Onboarding has nothing behind it; the app swaps this screen out for
        // the login screen on its own once a client exists.
        if (!widget.onboarding && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      case ServerSwitchOutcome.rolledBack:
        setState(
          () => _switchError = l10n.serverSwitchRolledBackBody(
            target?.host ?? '',
          ),
        );
      case ServerSwitchOutcome.stranded:
        setState(() => _switchError = l10n.serverSwitchStrandedBody);
      case ServerSwitchOutcome.refused:
        setState(() => _switchError = l10n.serverSwitchRefusedBody);
      case ServerSwitchOutcome.unchanged:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final switching = ServerSwitch.instance.busy;
    // Pushed from Settings it wears the back chevron; opened as a
    // full-screen modal (the login screen's server chip) it wears the ×
    // instead; during onboarding there is nothing behind it at all.
    final modal = ModalRoute.of(context)?.fullscreenDialog ?? false;
    final Widget? leading = widget.onboarding
        ? null
        : IgnorePointer(
            ignoring: switching,
            child: modal ? const GlassCloseButton() : const GlassBackButton(),
          );
    return DismissKeyboardOnTap(
      child: Stack(
        children: [
          IosPage(
            title: widget.onboarding
                ? l10n.serverOnboardingTitleIos
                : l10n.serverTitleIos,
            subtitle: widget.onboarding
                ? l10n.serverOnboardingSubtitle
                : l10n.serverScreenSubtitle,
            leading: leading,
            showBack: !widget.onboarding,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 48),
            children: [
              // Where things stand right now. Skipped during onboarding —
              // there is no "now" yet, and a card reading "Not connected"
              // above an empty form describes a problem rather than the task.
              if (!widget.onboarding) ...[
                _ActiveServerCard(health: widget._health),
                const SizedBox(height: 24),
              ],

              if (_hasBundled)
                GroupedSection(
                  margin: const EdgeInsets.only(bottom: 20),
                  children: [
                    _choiceRow(
                      label: l10n.serverChoiceCloud,
                      // Says "temporarily on the homeserver" rather than naming
                      // an address: a follow is still THIS choice, just being
                      // served from somewhere else for a while.
                      sub: ServerStore.instance.role == ServerRole.homeserver
                          ? l10n.serverChoiceCloudSubHomeserver
                          : l10n.serverChoiceCloudSub,
                      selected: _choice == _Choice.bundled,
                      inUse: !ServerStore.instance.isSelfHosted,
                      inUseLabel: l10n.serverActiveNowLabel,
                      onTap: switching
                          ? null
                          : () => setState(() => _choice = _Choice.bundled),
                    ),
                    _choiceRow(
                      label: l10n.serverChoiceOwn,
                      sub: ServerStore.instance.isSelfHosted
                          ? ServerStore.instance.host
                          : l10n.serverChoiceOwnSub,
                      selected: _choice == _Choice.own,
                      inUse: ServerStore.instance.isSelfHosted,
                      inUseLabel: l10n.serverActiveNowLabel,
                      onTap: switching
                          ? null
                          : () => setState(() => _choice = _Choice.own),
                    ),
                  ],
                ),

              if (_choice == _Choice.own)
                ..._ownServerForm(theme, l10n, switching)
              else
                ..._bundledForm(l10n, switching),

              if (_switchError != null) ...[
                const SizedBox(height: 18),
                SoftNote(
                  icon: CupertinoIcons.exclamationmark_circle,
                  tone: theme.danger,
                  title: l10n.serverSwitchRolledBackTitle,
                  text: _switchError!,
                ),
              ],

              ..._recentSection(l10n, switching),

              const SizedBox(height: 24),
              SoftNote(
                icon: CupertinoIcons.arrow_right_arrow_left,
                tone: theme.inkMuted,
                title: l10n.serverSwitchWarningTitle,
                text: l10n.serverSwitchWarningBody,
              ),
            ],
          ),
          // A half-applied switch is the one state with no sensible UI: the
          // session is gone, the socket is mid-rebuild, and every screen
          // underneath is describing a server that is no longer there. So the
          // whole screen is taken until it settles.
          if (switching) const _SwitchScrim(),
        ],
      ),
    );
  }

  /// One side of the bundled / own choice: a pick-one row with what it is
  /// underneath, "In use" on the side that is live, and the checkmark on the
  /// side the form below is showing.
  Widget _choiceRow({
    required String label,
    required String sub,
    required bool selected,
    required bool inUse,
    required String inUseLabel,
    required VoidCallback? onTap,
  }) {
    final theme = ThemeScope.of(context);
    return GroupedRow(
      title: label,
      subtitle: sub,
      value: inUse ? inUseLabel : null,
      chevron: false,
      onTap: onTap,
      trailing: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 380),
        curve: selected ? Curves.elasticOut : Curves.easeIn,
        child: Icon(CupertinoIcons.checkmark_alt, size: 20, color: theme.accent),
      ),
    );
  }

  // ───────── the bundled side ─────────

  List<Widget> _bundledForm(AppLocalizations l10n, bool switching) {
    // Nothing to go back TO unless the user actually left. A homeserver follow
    // is already this choice, so offering "use the default" there would be a
    // button that undoes something nobody did.
    if (!ServerStore.instance.isSelfHosted) return const [];
    return [
      SheetActionButton(
        label: l10n.serverUseDefaultCta,
        onTap: switching ? null : () => _connect(null),
      ),
    ];
  }

  // ───────── the self-hosted side ─────────

  List<Widget> _ownServerForm(
    AppTheme theme,
    AppLocalizations l10n,
    bool switching,
  ) {
    final check = _check;
    final candidate = _candidate;
    final result = _result;
    final unchanged =
        candidate != null &&
        ServerStore.instance.isSelfHosted &&
        candidate == ServerStore.instance.custom;
    return [
      ThemedInput(
        controller: _address,
        hint: l10n.serverAddressHint,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onChanged: _onAddressChanged,
        onSubmitted: (_) => _test(),
        trailing: SpringPress(
          onTap: switching ? null : _paste,
          semanticLabel: l10n.serverAddressPaste,
          focusShape: FocusRingShape.capsule,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              l10n.serverAddressPaste,
              style: groupedSubtitleStyle(theme).copyWith(
                fontWeight: FontWeight.w600,
                color: theme.accent,
              ),
            ),
          ),
        ),
      ),

      // What the address will actually be saved as. Shown because
      // normalization is invisible otherwise, and someone who typed
      // `example.com` deserves to see the `https://` they are about to get
      // rather than discover it later in a log.
      if (check.url != null && check.url != _address.text.trim()) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              CupertinoIcons.arrow_turn_down_right,
              size: 13,
              color: theme.inkMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                check.url!,
                style: groupedMetaStyle(theme).copyWith(color: theme.inkSoft),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
      if (check.problem != null && check.problem != ServerUrlProblem.empty) ...[
        const SizedBox(height: 8),
        Text(
          _problemText(l10n, check.problem!),
          style: groupedFooterStyle(theme).copyWith(color: theme.danger),
        ),
      ],
      // Not a refusal. Desktop and web builds can reach a plain-http server
      // perfectly well, and iOS exempts localhost from ATS — but on a phone
      // pointed at a LAN box this is the single most likely reason a correct
      // address never connects, and it is invisible without being said.
      if (check.url != null && !Uri.parse(check.url!).isScheme('https')) ...[
        const SizedBox(height: 10),
        SoftNote(
          icon: CupertinoIcons.lock_open,
          tone: theme.danger,
          title: l10n.serverInsecureTitle,
          text: l10n.serverInsecureBody,
        ),
      ],

      const SizedBox(height: 14),
      // The secondary action: tonal, so the filled Connect below stays the
      // one obvious primary — and the same capsule as it, not a rounded
      // rectangle stacked over a pill.
      SheetActionButton(
        label: l10n.serverTestCta,
        semanticLabel: _testing ? l10n.serverTestingLabel : null,
        tonal: true,
        busy: _testing,
        onTap: !switching && check.url != null ? _test : null,
      ),
      if (result != null) ...[
        const SizedBox(height: 14),
        _ProbeReport(result: result),
      ],

      const SizedBox(height: 14),
      _AdvancedDisclosure(
        open: _advancedOpen,
        label: l10n.serverAdvancedLabel,
        onToggle: () => setState(() => _advancedOpen = !_advancedOpen),
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.serverSiteUrlExplain, style: groupedFooterStyle(theme)),
              const SizedBox(height: 10),
              ThemedInput(
                controller: _siteAddress,
                hint: check.url == null
                    ? l10n.serverSiteUrlHint
                    : deriveSiteUrl(check.url!),
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                onChanged: _onAddressChanged,
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 18),
      SheetActionButton(
        label: unchanged
            ? l10n.serverAlreadyConnectedCta
            : (result != null && !result.ok
                  ? l10n.serverConnectAnywayCta
                  : l10n.serverConnectCta),
        // `unchanged` disables rather than hides: a CONNECT that silently does
        // nothing is worse than one that says it has nothing to do.
        onTap: switching || candidate == null || unchanged
            ? null
            : () => _connect(candidate),
      ),
    ];
  }

  static String _problemText(AppLocalizations l10n, ServerUrlProblem p) =>
      switch (p) {
        ServerUrlProblem.empty => '',
        ServerUrlProblem.malformed => l10n.serverProblemMalformed,
        ServerUrlProblem.badScheme => l10n.serverProblemBadScheme,
        ServerUrlProblem.noHost => l10n.serverProblemNoHost,
        ServerUrlProblem.hasCredentials => l10n.serverProblemCredentials,
      };

  // ───────── recents ─────────

  List<Widget> _recentSection(AppLocalizations l10n, bool switching) {
    final recent = ServerStore.instance.recent;
    if (recent.isEmpty) return const [];
    return [
      const SizedBox(height: 28),
      GroupedSection(
        header: l10n.serverSectionRecent,
        margin: EdgeInsets.zero,
        children: [
          for (final e in recent)
            _recentRow(
              endpoint: e,
              forgetLabel: l10n.serverRecentForget,
              onTap: switching
              ? null
              : () {
                  // Fills the form rather than connecting. One tap away from a
                  // sign-out is not a place to put a list you scroll past.
                  _address.text = e.deploymentUrl;
                  _siteAddress.text = e.siteUrlOverride ?? '';
                  setState(() {
                    _choice = _Choice.own;
                    _advancedOpen = e.siteUrlOverride != null;
                    _result = null;
                    _switchError = null;
                  });
                },
          onForget: switching ? null : () => ServerStore.instance.forget(e),
        ),
        ],
      ),
    ];
  }

  /// A server used before: tapping fills the form, the ⓧ forgets it.
  Widget _recentRow({
    required ServerEndpoint endpoint,
    required String forgetLabel,
    required VoidCallback? onTap,
    required VoidCallback? onForget,
  }) {
    final theme = ThemeScope.of(context);
    return GroupedRow(
      title: endpoint.host,
      chevron: false,
      onTap: onTap,
      trailing: SpringPress(
        onTap: onForget,
        semanticLabel: forgetLabel,
        focusShape: FocusRingShape.circle,
        scale: 0.86,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            CupertinoIcons.xmark_circle_fill,
            size: 20,
            color: theme.inkMuted.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ pieces ═════════════════════════

/// Where the app is connected right now, and whether that connection is real.
///
/// Reads [ConnectionHealth] rather than the socket flag: the socket's cached
/// state can sit wedged on `connecting` while queries succeed, and on this
/// screen in particular a false NOT CONNECTED would send someone chasing a
/// server problem that does not exist.
class _ActiveServerCard extends StatelessWidget {
  const _ActiveServerCard({this.health});
  final ConnectionHealth? health;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = ServerStore.instance;
    final online = health == null
        ? ConvexBackend.instance.isConnected
        : health!.phase == ConnectionPhase.online;
    final tone = online ? theme.success : theme.inkMuted;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                online
                    ? l10n.serverStatusConnected
                    : l10n.serverStatusDisconnected,
                style: groupedMetaStyle(theme).copyWith(
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
              const Spacer(),
              Text(
                switch (store.role) {
                  ServerRole.selfHosted => l10n.serverBadgeSelfHosted,
                  ServerRole.homeserver => l10n.serverValueHomeserver,
                  ServerRole.primary => l10n.serverBadgeDefault,
                },
                style: groupedMetaStyle(theme).copyWith(
                  color: store.announcesRole ? theme.accent : theme.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            switch (store.role) {
              // The address, for the one server whose address is the user's.
              ServerRole.selfHosted =>
                store.host.isEmpty ? l10n.serverNoneConfigured : store.host,
              ServerRole.homeserver => l10n.serverValueHomeserver,
              ServerRole.primary => l10n.serverValueDefault,
            },
            style: groupedHeaderStyle(theme),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // The explanation used to hang off the marker itself: a bar across
          // the top of the app that you could tap. The marker is a corner
          // ribbon now — it takes no layout height, which is the whole point
          // of the change, and the same property makes it un-tappable. So the
          // way in lives here, on the screen that already names the role and
          // the host and is where somebody asking "which server am I on?"
          // already goes. Only on the two roles that have anything to explain.
          if (store.announcesRole) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextLinkButton(
                label: l10n.serverRoleExplainAction,
                icon: CupertinoIcons.info_circle,
                onTap: () => showServerRoleInfo(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The probe's finding, as a three-rung ladder plus a sentence.
///
/// The ladder is the useful half. "Couldn't connect" describes four completely
/// different problems with four different fixes; showing which rung the answer
/// stopped at points at the one that actually applies — a dead address, a proxy
/// in the way, or a Convex box running somebody else's app.
class _ProbeReport extends StatelessWidget {
  const _ProbeReport({required this.result});
  final ServerProbeResult result;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = result.status;
    final reachable = s != ServerProbeStatus.unreachable;
    final isConvex =
        s == ServerProbeStatus.notThisApp ||
        s == ServerProbeStatus.serverError ||
        s == ServerProbeStatus.ready;
    final isApp = s == ServerProbeStatus.ready;
    final headline = switch (s) {
      ServerProbeStatus.unreachable => l10n.serverResultUnreachable,
      ServerProbeStatus.notConvex => l10n.serverResultNotConvex,
      ServerProbeStatus.notThisApp => l10n.serverResultNotThisApp,
      ServerProbeStatus.serverError => l10n.serverResultServerError,
      ServerProbeStatus.ready => l10n.serverResultReady,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rung(ok: reachable, label: l10n.serverCheckReachable),
          const SizedBox(height: 6),
          _Rung(ok: isConvex, label: l10n.serverCheckConvex),
          const SizedBox(height: 6),
          _Rung(ok: isApp, label: l10n.serverCheckApp),
          const SizedBox(height: 12),
          Text(
            headline,
            style: theme.body.copyWith(
              color: result.ok ? theme.success : theme.ink,
            ),
          ),
          if (result.detail != null) ...[
            const SizedBox(height: 6),
            Text(
              result.detail!,
              style: groupedFooterStyle(theme),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              // Latency and version are raw, not localized: both are readings,
              // and `38 ms` / `convex 0.1.2` say the same thing in every
              // language the app ships.
              if (reachable)
                Text(
                  '${result.roundTrip.inMilliseconds} ms',
                  style: groupedMetaStyle(theme).copyWith(
                    color: theme.inkSoft,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              if (result.backendVersion != null) ...[
                const SizedBox(width: 12),
                Text(
                  'convex ${result.backendVersion}',
                  style: groupedMetaStyle(theme).copyWith(
                    color: theme.inkSoft,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Rung extends StatelessWidget {
  const _Rung({required this.ok, required this.label});
  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      children: [
        Icon(
          ok
              ? CupertinoIcons.checkmark_circle_fill
              : CupertinoIcons.minus_circle,
          size: 16,
          color: ok ? theme.success : theme.inkMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: groupedSubtitleStyle(theme).copyWith(
            color: ok ? theme.ink : theme.inkMuted,
          ),
        ),
      ],
    );
  }
}

class _AdvancedDisclosure extends StatelessWidget {
  const _AdvancedDisclosure({
    required this.open,
    required this.label,
    required this.onToggle,
    required this.child,
  });
  final bool open;
  final String label;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SpringPress(
            onTap: onToggle,
            semanticLabel: label,
            focusShape: FocusRingShape.capsule,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: groupedTitleStyle(theme).copyWith(color: theme.accent),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 13,
                    color: theme.accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open) child,
      ],
    );
  }
}

/// The blocking cover shown while a switch runs.
///
/// One sentence, not a running commentary. A four-step narration was tried and
/// it was worse: nothing in it was actionable, and it kept naming "the old
/// server" and "the new one" — a distinction that only means anything from
/// inside the code, and that reads as an accusation to the person waiting.
/// The phases still exist for the diagnostics timeline, where they belong.
class _SwitchScrim extends StatelessWidget {
  const _SwitchScrim();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: ServerSwitch.instance,
      builder: (context, _) {
        // One label for every step. Narrating which server is being left and
        // which is being joined told the user nothing they could act on, and
        // named a distinction ("the old one", "the new one") that is only
        // meaningful from inside the code.
        return Positioned.fill(
          // Absorbs every pointer, which is the point of a scrim over a
          // destructive sequence — a stray tap on CONNECT mid-switch would
          // queue a second one behind it.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ColoredBox(
              color: theme.background.withValues(alpha: 0.88),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CupertinoActivityIndicator(
                        radius: 11,
                        color: theme.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(l10n.serverSwitchingLabel, style: theme.bodySoft),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
