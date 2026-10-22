import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/recovery_phrase.dart';
import '../auth/session_guard.dart';
import '../auth/session_store.dart';
import '../auth/social_sign_in.dart';
import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../keyboard/dismiss_keyboard_on_tap.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../legal_links.dart';
import '../platform.dart';
import '../services/link_opener.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../data/settings_store.dart';
import '../data/username_availability_controller.dart';
import '../widgets/app_icon_picker.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/device_login_panel.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import '../widgets/self_host_badge.dart' show shortHost;
import '../widgets/social_sign_in_buttons.dart';
import '../widgets/terms_consent.dart';
import '../widgets/username_status_label.dart';
import '../widgets/ios_kit.dart';
import 'child_pair_screen.dart';
import 'device_login_screen.dart';
import 'recovery_phrase_screen.dart';
import 'server_screen.dart';
import 'social_username_screen.dart';

/// Minimum window width at which the phone sign-in panel sits beside the
/// password form (see `LoginScreen._formColumn`/`build`) instead of behind
/// the footer link that pushes the full-screen `DeviceLoginScreen`. Set with
/// headroom above the fixed layout it enables (`ContentWidth.auth` +
/// `_phonePanelGap` + `_phonePanelWidth` = 828), so the row never ends up
/// flush against the window edge.
const double _phonePanelBreakpoint = 840;

/// Fixed width of the phone sign-in panel in the side-by-side layout — wide
/// enough for the 200px QR (plus its card padding) and the six-digit code
/// row, no wider.
const double _phonePanelWidth = 320;

/// Gap between the password form and the phone panel.
const double _phonePanelGap = 48;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// The three states of this screen. All per-mode copy lives here so adding or
/// rewording a mode is a single-place edit.
enum _AuthMode {
  signIn,
  signUp,
  reset;

  /// [returning] is whether this handset has ever completed a sign-in. Only
  /// [signIn] cares: greeting a device that has never been signed into with
  /// "welcome back" is a claim we have no basis for. Sign-up and reset read the
  /// same either way — one is addressed to a new account by definition, the
  /// other to someone who already has one.
  String title(BuildContext context, {required bool returning}) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      _AuthMode.signIn =>
        returning ? l10n.loginTitleReturning : l10n.loginTitleFirst,
      _AuthMode.signUp => l10n.loginTitleSignUp,
      _AuthMode.reset => l10n.loginTitleReset,
    };
  }

  String subtitle(BuildContext context, {required bool returning}) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      _AuthMode.signIn =>
        returning ? l10n.loginSubtitleSignIn : l10n.loginSubtitleFirst,
      _AuthMode.signUp => l10n.loginSubtitleSignUp,
      _AuthMode.reset => l10n.loginSubtitleReset,
    };
  }

  String cta(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      _AuthMode.signIn => l10n.loginCtaSignIn,
      _AuthMode.signUp => l10n.loginCtaSignUp,
      _AuthMode.reset => l10n.loginCtaReset,
    };
  }
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  String? _error;

  /// Landed here by a ban, with the banned session's token still held for one
  /// account deletion (`SessionGuard.suspensionPending`). Drives the banner's
  /// "Delete my account" action.
  bool _suspended = false;

  /// Whether the pairing screen is showing instead of the sign-in form.
  ///
  /// Seeded from the sticky child-device marker so a paired handset opens
  /// straight into pairing on every launch and never flashes the adult form.
  /// An adult can also reach it deliberately via the footer link, in which
  /// case they get a way back.
  late bool _pairing = SessionStore.instance.isChildDevice;

  /// Whether the QR/short-code device-login screen is showing instead of the
  /// sign-in form. Desktop/web only — see `isWebOrDesktop` where the footer
  /// link that sets this is offered. Unlike [_pairing] there is no sticky
  /// marker to seed from: every desktop/web launch starts on the password
  /// form, and this is purely a deliberate, reversible detour off it.
  bool _deviceLogin = false;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();
  final _newPassword = TextEditingController();

  /// The recovery phrase, on the reset screen only. Never typed at sign-up any
  /// more — it is generated there, and only ever entered here.
  final _phrase = TextEditingController();

  /// Minted once per sign-up attempt and deliberately KEPT across a failed
  /// submit, so that retrying with a corrected username reuses the phrase the
  /// user has already written down. Without this, a USERNAME_TAKEN would
  /// invalidate a phrase that is now on paper somewhere.
  RecoveryPhrase? _pendingPhrase;
  bool _phraseConfirmed = false;

  /// Live "is this free?" for the SIGN-UP mode only.
  ///
  /// Fed exclusively from [_AuthMode.signUp]'s field, because the other two
  /// modes type a handle that is supposed to already exist — telling someone
  /// signing in that their own username is "already taken" would be true and
  /// useless, and on the reset form it would be an invitation to go fishing.
  late final _availability = UsernameAvailabilityController(
    api: widget.auth.api,
  );

  /// The EULA box on the sign-up form. Sign-up will not run without it.
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    // Landed here because a moderator banned the account: say so, rather
    // than looking like an ordinary sign-out. See `SessionGuard`.
    if (SessionGuard.instance.takeSuspendedNotice()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _suspended = true;
          _error = AppLocalizations.of(context).authErrorAccountSuspended;
        });
      });
    }
  }

  @override
  void dispose() {
    // Leaving the screen (signed in, or gone) ends the offer to delete a
    // banned account with the old token.
    SessionGuard.instance.dismissSuspension();
    _availability.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    _phrase.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  /// The suspended notice's action: delete the banned account with the same
  /// confirm the profile screen uses. A refusal (for example a session revoked
  /// before the ban) points them at support instead.
  Future<void> _deleteSuspendedAccount() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmSheet(
      context,
      headline: l10n.profileScreenDeleteAccountConfirmTitle,
      body: l10n.profileScreenDeleteAccountConfirmBody,
      confirmLabel: l10n.acctDeleteAccount,
    );
    if (!ok || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.deleteSuspendedAccount();
      if (!mounted) return;
      setState(() {
        _suspended = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('[login] deleting the suspended account failed: $e');
      if (!mounted) return;
      setState(() {
        _suspended = false;
        _error = l10n.authSuspendedDeleteFailed;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchTo(_AuthMode mode) => setState(() {
    _mode = mode;
    _error = null;
    _suspended = false;
    // Switching away from sign-up abandons the attempt; a later one should
    // mint a fresh phrase rather than resurrect an abandoned one.
    _pendingPhrase = null;
    _phraseConfirmed = false;
    // The three modes share one username field, so a verdict earned in
    // sign-up would still be sitting there on the way back — describing a
    // name the user typed under different rules, minutes ago. Re-fed rather
    // than blanked, so returning to sign-up with text still in the box
    // re-checks it instead of showing nothing.
    _availability.onChanged(mode == _AuthMode.signUp ? _username.text : '');
  });

  /// Which provider button is mid-flight, so only one native sheet can be open.
  SocialProvider? _socialBusy;

  /// Apple/Google sign-in.
  ///
  /// Two outcomes: either the identity already had an account and we are simply
  /// signed in, or it is new and we push the username step. Nothing is created
  /// on the server in the second case — the account appears only once
  /// [SocialUsernameScreen] succeeds.
  Future<void> _socialSignIn(SocialProvider provider) async {
    if (_busy || _socialBusy != null) return;
    setState(() {
      _socialBusy = provider;
      _error = null;
    });
    try {
      final credential = await SocialSignIn.forProvider(provider);
      final outcome = await widget.auth.signInWithProvider(credential);
      if (!mounted || outcome == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SocialUsernameScreen(
            auth: widget.auth,
            credential: credential,
            suggestedName: outcome.suggestedName,
          ),
        ),
      );
    } on SocialSignInCancelled {
      // They backed out of the native sheet. Say nothing at all — an error
      // banner for "changed my mind" reads as a failure that wasn't one.
    } catch (e, stack) {
      // The banner copy is deliberately vague ("didn't go through") because the
      // backend's codes are opaque by design. That leaves the console as the
      // ONLY place the real cause can appear, so it has to appear there.
      debugPrint('[social] ${provider.wire} sign-in failed: $e');
      debugPrintStack(stackTrace: stack, maxFrames: 8);
      if (mounted) setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_mode == _AuthMode.signUp && !_termsAccepted) {
      setState(() {
        _error = AppLocalizations.of(context).termsMustAccept;
      });
      return;
    }
    if (_mode == _AuthMode.signUp && _password.text != _confirmPassword.text) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        ).loginScreenErrorPasswordsDontMatch;
      });
      return;
    }
    // Sign-up runs the save-your-phrase gate BEFORE creating the account.
    //
    // `_busy` is raised FIRST, covering the gate as well as the request that
    // follows it. Without that, `_submit` is re-entrant for as long as the
    // gate is open — a double-tap on OPEN ACCOUNT would push two gate routes,
    // and dismissing one would leave the user staring at the other.
    if (_mode == _AuthMode.signUp) {
      setState(() {
        _busy = true;
        _error = null;
      });
      final saved = await _ensurePhraseSaved();
      if (!mounted) return;
      if (!saved) {
        setState(() => _busy = false);
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final username = _username.text.trim();
      switch (_mode) {
        case _AuthMode.signUp:
          final name = _name.text.trim();
          await widget.auth.signUp(
            username: username,
            name: name.isEmpty ? username : name,
            password: _password.text,
            recoveryKeyHash: recoveryPhraseHash(_pendingPhrase!.canonical),
          );
        case _AuthMode.signIn:
          await widget.auth.signIn(
            username: username,
            password: _password.text,
          );
        case _AuthMode.reset:
          await widget.auth.resetPasswordWithRecoveryKey(
            username: username,
            recoveryKey: _phrase.text,
            newPassword: _newPassword.text,
          );
      }
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows the generated phrase and makes the user confirm they saved it.
  /// Returns false if they backed out, in which case no account is created.
  ///
  /// This runs BEFORE `auth.signUp` on purpose, and the ordering is the whole
  /// reason the gate is un-skippable:
  ///
  ///  * `_AppHome` swaps LoginScreen out for HomeShell the instant
  ///    `auth.isSignedIn` flips. Showing the gate afterwards would race that
  ///    swap; showing it first makes the flip the LAST thing that happens, so
  ///    there is simply no app to slip into yet.
  ///  * Killing the app mid-gate leaves no account at all — the cleanest
  ///    possible state, with nothing half-provisioned to reconcile later.
  ///
  /// The risk it trades for — signup failing after the user already wrote the
  /// phrase down — is handled by keeping `_pendingPhrase` and
  /// `_phraseConfirmed` across the failure, so a retry reuses the same words
  /// and does not show the gate twice.
  ///
  Future<bool> _ensurePhraseSaved() async {
    if (_password.text.isEmpty) {
      setState(() {
        _error = AppLocalizations.of(
          context,
        ).loginScreenErrorChoosePasswordFirst;
      });
      return false;
    }
    if (_phraseConfirmed) return true;
    _pendingPhrase ??= RecoveryPhrase.generate();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecoveryPhraseScreen(
          phrase: _pendingPhrase!,
          mode: RecoveryGateMode.setup,
        ),
      ),
    );
    if (saved != true) return false;
    _phraseConfirmed = true;
    return true;
  }

  String _humanize(Object e) =>
      humanizeAuthError(e, AppLocalizations.of(context));

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (_deviceLogin) {
      return DeviceLoginScreen(
        auth: widget.auth,
        onCancel: () => setState(() => _deviceLogin = false),
      );
    }
    if (_pairing) {
      return ChildPairScreen(
        auth: widget.auth,
        // A device that belongs to a child has nowhere to go back to.
        onCancel: SessionStore.instance.isChildDevice
            ? null
            : () => setState(() => _pairing = false),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DismissKeyboardOnTap(
        child: Stack(
          children: [
            theme.backgroundLayer(context),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, outer) {
                  // Desktop/web only, and sign-in only — scanning a QR needs a
                  // phone on the other end, and sign-up/reset have no use for
                  // it. Below the breakpoint the row would either overflow or
                  // squeeze the form uncomfortably narrow, so `_footer` offers
                  // the link to the full-screen fallback instead.
                  final showPhonePanel = isWebOrDesktop &&
                      _mode == _AuthMode.signIn &&
                      outer.maxWidth >= _phonePanelBreakpoint;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: showPhonePanel
                            ? ContentWidth.auth + _phonePanelGap + _phonePanelWidth
                            : ContentWidth.auth,
                        maxHeight: outer.maxHeight,
                      ),
                      child: showPhonePanel
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _formColumn(showPhoneLink: false),
                                ),
                                const SizedBox(width: _phonePanelGap),
                                SizedBox(
                                  width: _phonePanelWidth,
                                  child: Center(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(vertical: 36),
                                      child: DeviceLoginPanel(auth: widget.auth),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _formColumn(showPhoneLink: true),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The password form plus its footer. Shared by the single-column layout
  /// and the left side of the desktop side-by-side layout — see `build`.
  ///
  /// One scroll view holds BOTH. The footer used to be pinned under an
  /// `Expanded` scroll area, which on a short screen (sign-up's five fields,
  /// or 1.3× text) sliced the CTA in half against it with no keyboard in
  /// sight. `SliverFillRemaining(hasScrollBody: false)` keeps the old look
  /// when everything fits — form centred, footer on the floor — and lets the
  /// footer scroll away under the form when it doesn't.
  Widget _formColumn({required bool showPhoneLink}) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(mode: _mode),
                      const SizedBox(height: 30),
                      ..._fields(),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        FormErrorBanner(
                          _error!,
                          actionLabel: _suspended
                              ? AppLocalizations.of(context).authSuspendedDeleteAction
                              : null,
                          onAction: _suspended ? _deleteSuspendedAccount : null,
                        ),
                      ],
                      const SizedBox(height: 20),
                      // The one big commit on the screen, so it plays the
                      // heavier haptic itself (see ProminentButton, which this
                      // replaced) instead of the default selection tick.
                      SheetActionButton(
                        busy: _busy,
                        haptic: false,
                        label: _mode.cta(context),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _submit();
                        },
                      ),
                      // Not on `reset`: a recovery phrase resets a
                      // password, and these accounts may not have one.
                      if (_mode != _AuthMode.reset)
                        SocialSignInButtons(
                          onProvider: _socialSignIn,
                          busyProvider: _socialBusy,
                          enabled: !_busy,
                        ),
                    ],
                  ),
                ),
              ),
              _footer(showPhoneLink: showPhoneLink),
            ],
          ),
        ),
      ],
    );
  }

  /// The field stack for the active mode. Username is always first; the rest
  /// depend on what the mode actually needs. Fields carry no separate label —
  /// the placeholder names them.
  /// Move to the next field. Used instead of explicit [FocusNode]s because
  /// `_fields()` is rebuilt unkeyed whenever `_mode` or `_showOptional`
  /// changes — owned nodes would need disposal and focus would still land
  /// arbitrarily after a mode switch. `nextFocus()` needs no node at all.
  void _next() => FocusScope.of(context).nextFocus();

  List<Widget> _fields() {
    // The last field of each mode submits on Enter; every other field advances.
    final passwordIsLast = _mode == _AuthMode.signIn;
    final l10n = AppLocalizations.of(context);

    return [
      ThemedInput(
        controller: _username,
        hint: l10n.loginUsernameField,
        autocorrect: false,
        enableSuggestions: false,
        autofocus: isPhysicalKeyboardPlatform,
        textInputAction: TextInputAction.next,
        onChanged: _mode == _AuthMode.signUp ? _availability.onChanged : null,
        onSubmitted: (_) => _next(),
      ),
      // The status label always reserves its own 18pt line (so the field
      // below never hops when a verdict arrives) — that line IS the gap on
      // sign-up, rather than stacking the usual 12 on top of it and leaving
      // username→password visibly wider than every other pair.
      if (_mode == _AuthMode.signUp)
        UsernameStatusLabel(controller: _availability),
      if (_mode != _AuthMode.reset) ...[
        if (_mode != _AuthMode.signUp) const SizedBox(height: 12),
        PasswordField(
          controller: _password,
          hint: l10n.loginPasswordField,
          textInputAction: passwordIsLast
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: (_) => passwordIsLast ? _submit() : _next(),
        ),
      ],
      if (_mode == _AuthMode.signUp) ...[
        // 18 on sign-up, matching the status label's reserved line above, so
        // the four fields keep one rhythm instead of one wide gap and two
        // narrow ones.
        const SizedBox(height: 18),
        PasswordField(
          controller: _confirmPassword,
          hint: l10n.loginConfirmPasswordField,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _next(),
        ),
        // `name` used to hide behind a "show optional fields" toggle, along
        // with email (now gone — nothing ever sent any) and a freehand
        // recovery phrase (now generated, not typed). With one optional field
        // left, a disclosure toggle is theatre.
        const SizedBox(height: 18),
        ThemedInput(
          controller: _name,
          hint: l10n.loginNameField,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        // The EULA, agreed to explicitly, just above OPEN ACCOUNT. See
        // `TermsConsentRow` for why it is a box and why the words are shared.
        const SizedBox(height: 14),
        TermsConsentRow(
          value: _termsAccepted,
          onChanged: (v) => setState(() {
            _termsAccepted = v;
            if (v && _error == l10n.termsMustAccept) _error = null;
          }),
        ),
      ],
      if (_mode == _AuthMode.reset) ...[
        const SizedBox(height: 12),
        // Multi-line on purpose. Twelve words is ~70 characters; in a
        // single-line field the text scrolls out of sight and the user cannot
        // see what they pasted, which is the single biggest cause of "I typed
        // it right and it says wrong".
        ThemedInput(
          controller: _phrase,
          hint: l10n.loginRecoveryPhraseField,
          minLines: 2,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.multiline,
          // Drives the counter below. textInputAction is deliberately unset:
          // with maxLines > 1 the return key inserts a newline, which
          // normalization absorbs anyway.
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _WordCounter(count: recoveryWordCount(_phrase.text)),
        const SizedBox(height: 12),
        PasswordField(
          controller: _newPassword,
          hint: l10n.loginNewPasswordField,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ],
    ];
  }

  /// Mode-switching links, pinned to the bottom of the screen in every mode.
  ///
  /// [showPhoneLink] is false when the phone panel is already visible beside
  /// the form (see `build`) — the link would just be a second way to reach
  /// something already on screen.
  Widget _footer({required bool showPhoneLink}) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mode == _AuthMode.reset)
            TextLinkButton(
              label: l10n.loginBackToSignIn,
              onTap: () => _switchTo(_AuthMode.signIn),
            )
          else ...[
            _ModeToggle(
              mode: _mode,
              onTap: () => _switchTo(
                _mode == _AuthMode.signUp ? _AuthMode.signIn : _AuthMode.signUp,
              ),
            ),
            // No spacers between the links: each is a 44pt touch target
            // already, which is the rhythm.
            if (_mode == _AuthMode.signIn) ...[
              TextLinkButton(
                label: l10n.loginForgotPassword,
                onTap: () => _switchTo(_AuthMode.reset),
              ),
              TextLinkButton(
                label: l10n.loginChildAccount,
                onTap: () => setState(() => _pairing = true),
              ),
              // Desktop/web only — scanning a QR needs a phone on the other
              // end, so this is offered ALONGSIDE the password form rather
              // than replacing it: not every self-hosted deployment's users
              // will have a paired phone to scan with. Suppressed when the
              // panel itself is already showing beside the form (`build`).
              if (isWebOrDesktop && showPhoneLink) ...[
                TextLinkButton(
                  label: l10n.loginWithPhone,
                  onTap: () => setState(() => _deviceLogin = true),
                ),
              ],
            ],
          ],
          // Sign-up only. The Profile screen carries the permanent link that
          // Guideline 5.1.1(i) requires; this one is here because sign-up is
          // the moment the agreement is actually formed — and because a
          // guardian creating a child account is consenting on someone else's
          // behalf, which is only meaningful if the document was reachable
          // before they tapped.
          if (_mode == _AuthMode.signUp) ...[
            const SizedBox(height: 14),
            _LegalNote(theme: ThemeScope.of(context)),
          ],
          // Which server the credentials above are about to be sent to.
          //
          // On this screen rather than only in Settings, because this is where
          // the answer is actionable: signing in is the moment an account gets
          // bound to a deployment, and Settings sits behind having one. It is
          // also what makes self-hosting reachable at all on a handset that has
          // never signed in — otherwise the feature would need an account on
          // the very server you were trying not to use.
          const SizedBox(height: 12),
          const _ServerChip(),
        ],
      ),
    );
  }
}

/// The quiet line at the foot of the login screen naming the deployment.
///
/// Deliberately understated on the default server and accented on a
/// self-hosted one — a stock install should not be nagged about a setting it
/// has never touched, while a repointed one should say so on the screen where
/// a password is about to be typed.
class _ServerChip extends StatelessWidget {
  const _ServerChip();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerStore.instance,
      builder: (context, _) {
        final theme = ThemeScope.of(context);
        final l10n = AppLocalizations.of(context);
        final store = ServerStore.instance;
        // Hidden on a store build's default server; see
        // `ServerStore.showsServerTools`.
        if (!store.showsServerTools) return const SizedBox.shrink();
        // Marked for anything that is not the ordinary deployment; named only
        // when the user chose it. A homeserver follow is temporary and not
        // theirs — it says so, and does not publish the address.
        final marked = store.announcesRole;
        final tone = marked ? theme.accent : theme.inkMuted;
        final label = switch (store.role) {
          ServerRole.selfHosted =>
            store.host.isEmpty
                ? l10n.serverNoneConfigured
                : shortHost(store.host, max: 28),
          ServerRole.homeserver => l10n.serverValueHomeserver,
          ServerRole.primary => l10n.serverValueDefault,
        };
        void open() => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ServerScreen(),
          ),
        );
        return Center(
          child: SpringPress(
            onTap: open,
            scale: PressSpec.scaleSmall,
            focusShape: FocusRingShape.capsule,
            focusRadius: 999,
            semanticLabel: l10n.serverChipSemantics(label),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              decoration: BoxDecoration(
                color: marked
                    ? quietFill(theme)
                    : Colors.transparent,
                border: Border.all(
                  color: marked
                      ? theme.accent.withValues(alpha: 0.45)
                      : theme.divider,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.globe, size: 13, color: tone),
                  const SizedBox(width: 6),
                  // Meta on the body face, never the theme's caption: on a
                  // character theme that is tracked monospace, and this is a
                  // sentence about where your password goes, not a payload.
                  Flexible(
                    child: Text(
                      label,
                      style: groupedMetaStyle(theme).copyWith(color: tone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "By opening an account you agree to …", with the two documents tappable.
///
/// Deliberately quiet — this is a disclosure, not a call to action, and styling
/// it to compete with OPEN ACCOUNT would be dishonest about which one the user
/// came here to press.
class _LegalNote extends StatelessWidget {
  const _LegalNote({required this.theme});
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = groupedMetaStyle(theme).copyWith(height: 1.4);
    final link = base.copyWith(
      color: theme.inkSoft,
      decoration: TextDecoration.underline,
      decorationColor: theme.inkSoft,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: l10n.loginScreenLegalPrefix),
          TextSpan(
            text: l10n.loginScreenLegalTermsLink,
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => LinkOpener.open(context, kTermsOfServiceUrl),
          ),
          TextSpan(text: l10n.loginScreenLegalMiddle),
          TextSpan(
            text: l10n.loginScreenLegalPrivacyLink,
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => LinkOpener.open(context, kPrivacyPolicyUrl),
          ),
          TextSpan(text: l10n.loginScreenLegalSuffix),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// The brand, then what this screen is for: the app's mark arriving on a
/// spring, a large title and one line under it. The title cross-fades when
/// the mode changes, so switching to sign-up reads as the same screen
/// changing its mind rather than a new one.
class _Hero extends StatelessWidget {
  const _Hero({required this.mode});
  final _AuthMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    // Read straight off the in-memory marker rather than awaiting the keychain:
    // it was populated by `loadSession()` during boot, which is the same
    // guarantee `_pairing` relies on, and a future here would flash the wrong
    // greeting for a frame.
    final returning = SessionStore.instance.hasSignedInBefore;
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: motion.d(const Duration(milliseconds: 1100)),
          curve: Curves.elasticOut,
          builder: (context, v, child) => Transform.scale(
            scale: 0.5 + 0.5 * v,
            child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
          ),
          child: const _BrandTile(),
        ),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: motion.d(const Duration(milliseconds: 260)),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Column(
            key: ValueKey(mode),
            children: [
              Text(
                mode.title(context, returning: returning),
                textAlign: TextAlign.center,
                style: theme.displayLarge.copyWith(letterSpacing: 0.37),
              ),
              const SizedBox(height: 8),
              Text(
                mode.subtitle(context, returning: returning),
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The app's current mark on an icon-shaped tile, as it sits on the home
/// screen — the same face the person tapped to get here.
class _BrandTile extends StatelessWidget {
  const _BrandTile();

  @override
  Widget build(BuildContext context) {
    const size = 84.0;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.45),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: SettingsStore.instance,
        builder: (context, _) => appIconArt(
          SettingsStore.instance,
          currentIconChoice(SettingsStore.instance),
          size,
        ),
      ),
    );
  }
}

/// The two-tone "no account? open one" / "already here? sign in" switch.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onTap});
  final _AuthMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isSignUp = mode == _AuthMode.signUp;
    final prompt = isSignUp
        ? l10n.loginHaveAccountPrompt
        : l10n.loginNoAccountPrompt;
    final link = isSignUp ? l10n.loginSignInLink : l10n.loginCreateAccountLink;
    // `Text.rich`, not `RichText`: the latter ignores the text scale, so at
    // 1.3× this line stayed small while every sibling grew.
    return Center(
      child: SpringPress(
        onTap: onTap,
        scale: PressSpec.scaleSmall,
        semanticLabel: '$prompt$link',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Text.rich(
              TextSpan(
                // 17, the step the text links under it use, so the footer
                // reads as one column rather than two sizes.
                style: groupedValueStyle(theme),
                children: [
                  TextSpan(text: prompt),
                  TextSpan(
                    text: link,
                    style: groupedValueStyle(theme).copyWith(
                      color: theme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Live `n/12 words` readout under the reset screen's phrase field.
///
/// Reports the COUNT only, never which word is wrong. The count is cheap and
/// removes most of the "I typed it right" confusion on its own; naming the bad
/// word would turn a help affordance into a wordlist oracle.
class _WordCounter extends StatelessWidget {
  const _WordCounter({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final complete = count == 12;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        AppLocalizations.of(context).loginScreenWordCounter(count),
        style: groupedMetaStyle(theme).copyWith(
          color: complete ? theme.accent : theme.inkMuted,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
