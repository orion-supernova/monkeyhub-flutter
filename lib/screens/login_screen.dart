import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../auth/session_store.dart';
import '../keyboard/focusable_tap.dart';
import '../platform.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import 'child_pair_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// The three states of this screen. All per-mode copy lives here so adding or
/// rewording a mode is a single-place edit.
enum _AuthMode {
  signIn(heroMuted: 'welcome\n', heroInk: 'back.', cta: 'SIGN IN'),
  signUp(heroMuted: 'new\n', heroInk: 'face.', cta: 'OPEN ACCOUNT'),
  reset(heroMuted: 'reset\n', heroInk: 'password.', cta: 'RESET PASSWORD');

  const _AuthMode({
    required this.heroMuted,
    required this.heroInk,
    required this.cta,
  });

  final String heroMuted;
  final String heroInk;
  final String cta;
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

  /// Whether sign-up's optional name/email/recovery fields are revealed.
  bool _showOptional = false;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _recovery = TextEditingController();
  final _newPassword = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _name.dispose();
    _email.dispose();
    _recovery.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  void _switchTo(_AuthMode mode) => setState(() {
        _mode = mode;
        _error = null;
        _showOptional = false;
      });

  Future<void> _submit() async {
    if (_busy) return;
    if (_mode == _AuthMode.signUp && _password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords don\'t match.');
      return;
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
          final email = _email.text.trim();
          final recovery = _recovery.text.trim();
          await widget.auth.signUp(
            username: username,
            name: name.isEmpty ? username : name,
            password: _password.text,
            email: email.isEmpty ? null : email,
            recoveryKey: recovery.isEmpty ? null : recovery,
          );
        case _AuthMode.signIn:
          await widget.auth.signIn(username: username, password: _password.text);
        case _AuthMode.reset:
          await widget.auth.resetPasswordWithRecoveryKey(
            username: username,
            recoveryKey: _recovery.text.trim(),
            newPassword: _newPassword.text,
          );
      }
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const Map<String, String> _errorMessages = {
    'USERNAME_TAKEN': 'That username is already taken.',
    'USER_NOT_FOUND': 'No account with that username.',
    'WRONG_PASSWORD': 'Wrong password.',
    'WRONG_RECOVERY_KEY': 'Recovery phrase doesn\'t match.',
    'NO_RECOVERY_KEY': 'This account has no recovery phrase set.',
    'CHILD_MUST_PAIR':
        'That\'s a kid\'s account — ask a grown-up for a pairing code.',
  };

  String _humanize(Object e) {
    final s = e.toString();
    for (final entry in _errorMessages.entries) {
      if (s.contains(entry.key)) return entry.value;
    }
    return s.length > 140 ? '${s.substring(0, 140)}…' : s;
  }

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
                                  label: _mode.cta,
                                  onTap: _submit,
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
    final confirmIsLast = _mode == _AuthMode.signUp && !_showOptional;

    return [
      ThemedInput(
        controller: _username,
        hint: 'username',
        autocorrect: false,
        enableSuggestions: false,
        autofocus: isPhysicalKeyboardPlatform,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _next(),
      ),
      if (_mode != _AuthMode.reset) ...[
        const SizedBox(height: 12),
        PasswordField(
          controller: _password,
          hint: 'password',
          textInputAction:
              passwordIsLast ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) => passwordIsLast ? _submit() : _next(),
        ),
      ],
      if (_mode == _AuthMode.signUp) ...[
        const SizedBox(height: 12),
        PasswordField(
          controller: _confirmPassword,
          hint: 'confirm password',
          textInputAction:
              confirmIsLast ? TextInputAction.done : TextInputAction.next,
          onSubmitted: (_) => confirmIsLast ? _submit() : _next(),
        ),
        const SizedBox(height: 14),
        _DisclosureLink(
          label: _showOptional
              ? 'hide optional fields'
              : 'show optional fields',
          onTap: () => setState(() => _showOptional = !_showOptional),
        ),
        if (_showOptional) ...[
          const SizedBox(height: 14),
          ThemedInput(
            controller: _name,
            hint: 'name',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 12),
          ThemedInput(
            controller: _email,
            hint: 'email',
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _next(),
          ),
          const SizedBox(height: 12),
          ThemedInput(
            controller: _recovery,
            hint: 'recovery phrase',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ],
      if (_mode == _AuthMode.reset) ...[
        const SizedBox(height: 12),
        ThemedInput(
          controller: _recovery,
          hint: 'recovery phrase',
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: 12),
        PasswordField(
          controller: _newPassword,
          hint: 'new password',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ],
    ];
  }

  /// Mode-switching links, pinned to the bottom of the screen in every mode.
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_mode == _AuthMode.reset)
            _TextLink(
              label: '← back to sign in',
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
                label: 'forgot password?',
                onTap: () => _switchTo(_AuthMode.reset),
              ),
              const SizedBox(height: 10),
              _TextLink(
                label: 'setting up a kid\'s phone?',
                onTap: () => setState(() => _pairing = true),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.mode});
  final _AuthMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return RichText(
      text: TextSpan(
        style: theme.displayHero,
        children: [
          TextSpan(
            text: mode.heroMuted,
            style: theme.displayHero.copyWith(color: theme.inkMuted),
          ),
          TextSpan(text: mode.heroInk),
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
    final isSignUp = mode == _AuthMode.signUp;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText(
          text: TextSpan(style: theme.bodySoft, children: [
            TextSpan(text: isSignUp ? 'already here? ' : 'no account? '),
            TextSpan(
              text: isSignUp ? 'sign in' : 'open one',
              style: theme.body.copyWith(color: theme.accent),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Left-aligned toggle that reveals sign-up's optional fields.
class _DisclosureLink extends StatelessWidget {
  const _DisclosureLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: theme.monoTiny.copyWith(color: theme.accent),
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
