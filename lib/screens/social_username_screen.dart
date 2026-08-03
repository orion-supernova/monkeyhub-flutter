import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/social_sign_in.dart';
import '../keyboard/focusable_tap.dart';
import '../platform.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';

/// Where a first-time Apple/Google sign-in lands, with two ways out.
///
/// Apple and Google give us a stable subject and sometimes an email, but this
/// app's public identity is a chosen username — it is how people find each
/// other — so a provider identity we have never seen has to stop here.
///
/// TWO MODES, and the second is not optional. The single most common real-world
/// first tap of a provider button is by someone who ALREADY has an account of
/// months' standing. Offering only "pick a username" strands them: they type the
/// username they already own, are told it is taken, and there is nowhere to go.
/// [_Mode.link] is that missing door — prove the existing account with its
/// password and the provider is attached to it instead.
///
/// The account does NOT exist yet in [_Mode.create]. Nothing is written until
/// this screen succeeds, so backing out leaves no orphan — the same ordering
/// property the signup recovery-phrase gate relies on. Which is also why this
/// screen must always be closable; it briefly was not, and that was a trap.
///
/// This screen is PUSHED as a route, which is the fact behind both bugs it has
/// had: it needs its own close control (no AppBar, and `fullscreenDialog`
/// disables iOS swipe-back), and it must pop itself on success or it goes on
/// covering the HomeShell that signing in just built underneath it.
class SocialUsernameScreen extends StatefulWidget {
  const SocialUsernameScreen({
    super.key,
    required this.auth,
    required this.credential,
    this.suggestedName,
  });

  final AuthService auth;

  /// Re-sent verbatim so the backend can re-verify it. Apple tokens live 24h
  /// and Google's an hour, so there is no realistic way to sit here long enough
  /// for one to expire.
  final SocialCredential credential;
  final String? suggestedName;

  @override
  State<SocialUsernameScreen> createState() => _SocialUsernameScreenState();
}

enum _Mode { create, link }

class _SocialUsernameScreenState extends State<SocialUsernameScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _name =
      TextEditingController(text: widget.suggestedName ?? '');

  _Mode _mode = _Mode.create;
  bool _busy = false;
  String? _error;

  /// Set when a create attempt failed specifically because the username exists,
  /// so the error can offer the fix rather than just stating the problem.
  bool _offerLink = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _provider => widget.credential.provider.label;

  void _switchTo(_Mode mode) => setState(() {
        _mode = mode;
        _error = null;
        _offerLink = false;
      });

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Enter your username.');
      return;
    }
    if (_mode == _Mode.link && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _offerLink = false;
    });
    try {
      if (_mode == _Mode.create) {
        final name = _name.text.trim();
        await widget.auth.completeSocialSignUp(
          credential: widget.credential,
          username: username,
          name: name.isEmpty ? null : name,
        );
      } else {
        await widget.auth.linkSocialToExistingAccount(
          credential: widget.credential,
          username: username,
          password: _password.text,
        );
      }
      // POP ON SUCCESS — and this is load-bearing, not tidiness.
      //
      // Either call flips `isSignedIn`, which makes `_AppHome` swap its child
      // from LoginScreen to HomeShell. But that child is `MaterialApp.home`,
      // and this screen was PUSHED on top of it. So the swap happens underneath
      // a route that is still covering the whole window: the app is signed in,
      // HomeShell is built and rendering, and the user sees this form forever.
      // That is exactly what shipped, and it looked like a hang.
      //
      // Popping is safe here: `notifyListeners()` runs synchronously inside the
      // await above, so the swap is already scheduled by the time we get here.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final taken = e.toString().contains('USERNAME_TAKEN');
      setState(() {
        _error = humanizeAuthError(e, fallback: null);
        // The whole point of the second mode — surface it exactly when it is
        // the answer, rather than making them find it.
        _offerLink = taken && _mode == _Mode.create;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final creating = _mode == _Mode.create;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                // The way out. This screen is pushed as a fullscreenDialog,
                // which on iOS also disables swipe-back — without this there is
                // no gesture and no button that leaves, and a failed attempt
                // traps the user on it.
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                    child: FocusableTap(
                      onTap: _busy ? null : () => Navigator.of(context).pop(),
                      enabled: !_busy,
                      semanticLabel: 'Cancel',
                      radius: theme.radiusSm,
                      child: GestureDetector(
                        onTap: _busy ? null : () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(Icons.close,
                              size: 20, color: theme.inkMuted),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: ContentWidth.auth),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: creating ? 'almost\n' : 'welcome\n',
                                    style: theme.displayHero
                                        .copyWith(color: theme.inkMuted),
                                  ),
                                  TextSpan(
                                    text: creating ? 'there.' : 'back.',
                                    style: theme.displayHero,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              creating
                                  ? 'Pick a username so your family and friends can find you.'
                                  : 'Sign in once and $_provider is attached to your account.',
                              style: theme.bodySoft,
                            ),
                            const SizedBox(height: 28),
                            ThemedInput(
                              controller: _username,
                              hint: 'username',
                              autocorrect: false,
                              enableSuggestions: false,
                              autofocus: isPhysicalKeyboardPlatform,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 12),
                            if (creating)
                              ThemedInput(
                                controller: _name,
                                hint: 'display name (optional)',
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              )
                            else
                              PasswordField(
                                controller: _password,
                                hint: 'password',
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(),
                              ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: theme.danger.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(theme.radiusSm),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _error!,
                                      style: theme.body
                                          .copyWith(color: theme.danger),
                                    ),
                                    if (_offerLink) ...[
                                      const SizedBox(height: 8),
                                      _TextLink(
                                        label: 'That one\'s mine — sign in',
                                        onTap: () => _switchTo(_Mode.link),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            _Cta(
                              busy: _busy,
                              label: creating
                                  ? 'CREATE ACCOUNT'
                                  : 'SIGN IN & LINK $_provider'.toUpperCase(),
                              onTap: _submit,
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: _TextLink(
                                label: creating
                                    ? 'Already have an account?'
                                    : 'New here? Create an account',
                                onTap: () => _switchTo(
                                  creating ? _Mode.link : _Mode.create,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.busy, required this.label, required this.onTap});
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
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: busy ? theme.accentSoft : theme.accent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
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
                  style: theme.label.copyWith(
                    color: theme.accentInk,
                    letterSpacing: 2,
                  ),
                ),
        ),
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
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusSm,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: theme.body.copyWith(
              color: theme.accent,
              decoration: TextDecoration.underline,
              decorationColor: theme.accent,
            ),
          ),
        ),
      ),
    );
  }
}
