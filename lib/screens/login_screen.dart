import 'dart:math' as math;

import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/recovery_phrase.dart';
import '../auth/session_store.dart';
import '../auth/social_sign_in.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../legal_links.dart';
import '../platform.dart';
import '../services/link_opener.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../data/username_availability_controller.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import '../widgets/social_sign_in_buttons.dart';
import '../widgets/username_status_label.dart';
import 'child_pair_screen.dart';
import 'recovery_phrase_screen.dart';
import 'social_username_screen.dart';

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
  String heroMuted(BuildContext context, {required bool returning}) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case _AuthMode.signIn:
        return returning
            ? l10n.loginScreenSignInHeroMuted
            : l10n.loginScreenSignInFirstHeroMuted;
      case _AuthMode.signUp:
        return l10n.loginScreenSignUpHeroMuted;
      case _AuthMode.reset:
        return l10n.loginScreenResetHeroMuted;
    }
  }

  String heroInk(BuildContext context, {required bool returning}) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case _AuthMode.signIn:
        return returning
            ? l10n.loginScreenSignInHeroInk
            : l10n.loginScreenSignInFirstHeroInk;
      case _AuthMode.signUp:
        return l10n.loginScreenSignUpHeroInk;
      case _AuthMode.reset:
        return l10n.loginScreenResetHeroInk;
    }
  }

  String cta(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (this) {
      case _AuthMode.signIn:
        return l10n.loginScreenSignInCta;
      case _AuthMode.signUp:
        return l10n.loginScreenSignUpCta;
      case _AuthMode.reset:
        return l10n.loginScreenResetCta;
    }
  }
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  String? _error;

  /// Whether the pairing screen is showing instead of the sign-in form.
  ///
  /// Seeded from the sticky child-device marker so a paired handset opens
  /// straight into pairing on every launch and never flashes the adult form.
  /// An adult can also reach it deliberately via the footer link, in which
  /// case they get a way back.
  late bool _pairing = SessionStore.instance.isChildDevice;

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
  late final _availability =
      UsernameAvailabilityController(api: widget.auth.api);

  @override
  void dispose() {
    _availability.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    _phrase.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  void _switchTo(_AuthMode mode) => setState(() {
        _mode = mode;
        _error = null;
        // Switching away from sign-up abandons the attempt; a later one should
        // mint a fresh phrase rather than resurrect an abandoned one.
        _pendingPhrase = null;
        _phraseConfirmed = false;
        // The three modes share one username field, so a verdict earned in
        // sign-up would still be sitting there on the way back — describing a
        // name the user typed under different rules, minutes ago. Re-fed rather
        // than blanked, so returning to sign-up with text still in the box
        // re-checks it instead of showing nothing.
        _availability.onChanged(
          mode == _AuthMode.signUp ? _username.text : '',
        );
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
    if (_mode == _AuthMode.signUp && _password.text != _confirmPassword.text) {
      setState(() {
        _error = AppLocalizations.of(context).loginScreenErrorPasswordsDontMatch;
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
          await widget.auth.signIn(username: username, password: _password.text);
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
        _error = AppLocalizations.of(context).loginScreenErrorChoosePasswordFirst;
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
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.auth),
                child: Column(
                  children: [
                    // Form fills the space above the footer and stays
                    // vertically centred in it until it grows tall enough to
                    // need scrolling (sign-up expanded, or keyboard open).
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 36, 28, 12),
                          child: ConstrainedBox(
                            // Never negative: the keyboard can shrink the
                            // viewport below the padding we subtract.
                            constraints: BoxConstraints(
                              minHeight: math.max(0, constraints.maxHeight - 48),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Hero(mode: _mode),
                                const SizedBox(height: 28),
                                ..._fields(),
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  _ErrorBanner(_error!),
                                ],
                                const SizedBox(height: 20),
                                _SubmitButton(
                                  busy: _busy,
                                  label: _mode.cta(context),
                                  onTap: _submit,
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
                      ),
                    ),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
        hint: l10n.loginScreenUsernameHint,
        autocorrect: false,
        enableSuggestions: false,
        autofocus: isPhysicalKeyboardPlatform,
        textInputAction: TextInputAction.next,
        onChanged: _mode == _AuthMode.signUp ? _availability.onChanged : null,
        onSubmitted: (_) => _next(),
      ),
      if (_mode == _AuthMode.signUp)
        UsernameStatusLabel(controller: _availability),
      if (_mode != _AuthMode.reset) ...[
        const SizedBox(height: 12),
        PasswordField(
          controller: _password,
          hint: l10n.loginScreenPasswordHint,
          textInputAction:
              passwordIsLast ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) => passwordIsLast ? _submit() : _next(),
        ),
      ],
      if (_mode == _AuthMode.signUp) ...[
        const SizedBox(height: 12),
        PasswordField(
          controller: _confirmPassword,
          hint: l10n.loginScreenConfirmPasswordHint,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _next(),
        ),
        // `name` used to hide behind a "show optional fields" toggle, along
        // with email (now gone — nothing ever sent any) and a freehand
        // recovery phrase (now generated, not typed). With one optional field
        // left, a disclosure toggle is theatre.
        const SizedBox(height: 12),
        ThemedInput(
          controller: _name,
          hint: l10n.loginScreenNameOptionalHint,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
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
          hint: l10n.loginScreenRecoveryPhraseHint,
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
          hint: l10n.loginScreenNewPasswordHint,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ],
    ];
  }

  /// Mode-switching links, pinned to the bottom of the screen in every mode.
  Widget _footer() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mode == _AuthMode.reset)
            _TextLink(
              label: l10n.loginScreenBackToSignIn,
              onTap: () => _switchTo(_AuthMode.signIn),
            )
          else ...[
            _ModeToggle(
              mode: _mode,
              onTap: () => _switchTo(_mode == _AuthMode.signUp
                  ? _AuthMode.signIn
                  : _AuthMode.signUp),
            ),
            if (_mode == _AuthMode.signIn) ...[
              const SizedBox(height: 10),
              _TextLink(
                label: l10n.loginScreenForgotPassword,
                onTap: () => _switchTo(_AuthMode.reset),
              ),
              const SizedBox(height: 10),
              _TextLink(
                label: l10n.loginScreenSettingUpKidsPhone,
                onTap: () => setState(() => _pairing = true),
              ),
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
        ],
      ),
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
    final base = theme.monoTiny.copyWith(color: theme.inkMuted);
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

class _Hero extends StatelessWidget {
  const _Hero({required this.mode});
  final _AuthMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Read straight off the in-memory marker rather than awaiting the keychain:
    // it was populated by `loadSession()` during boot, which is the same
    // guarantee `_pairing` relies on, and a future here would flash the wrong
    // greeting for a frame.
    final returning = SessionStore.instance.hasSignedInBefore;
    return RichText(
      text: TextSpan(
        style: theme.displayHero,
        children: [
          TextSpan(
            text: mode.heroMuted(context, returning: returning),
            style: theme.displayHero.copyWith(color: theme.inkMuted),
          ),
          TextSpan(text: mode.heroInk(context, returning: returning)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.danger.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: theme.danger, width: 2)),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Text(message, style: theme.body.copyWith(color: theme.danger)),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.busy,
    required this.label,
    required this.onTap,
  });
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: busy ? null : onTap,
      enabled: !busy,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: theme.motionFast,
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: busy ? theme.accentSoft : theme.accent,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          boxShadow: busy
              ? null
              : [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ],
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.accentInk,
                ),
              )
            : Text(
                label,
                style: theme.label
                    .copyWith(color: theme.accentInk, letterSpacing: 2.4),
              ),
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
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText(
          text: TextSpan(style: theme.bodySoft, children: [
            TextSpan(
              text: isSignUp
                  ? l10n.loginScreenAlreadyHerePrompt
                  : l10n.loginScreenNoAccountPrompt,
            ),
            TextSpan(
              text: isSignUp
                  ? l10n.loginScreenSignInLink
                  : l10n.loginScreenOpenOneLink,
              style: theme.body.copyWith(color: theme.accent),
            ),
          ]),
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
        style: theme.monoTiny
            .copyWith(color: complete ? theme.accent : theme.inkMuted),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          label,
          style: theme.monoTiny.copyWith(color: theme.inkMuted),
        ),
      ),
    );
  }
}
