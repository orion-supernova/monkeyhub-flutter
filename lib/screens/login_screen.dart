import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/theme_scope.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthService auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _signingUp = false;
  bool _busy = false;
  String? _error;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signingUp) {
        await widget.auth.signUp(
          username: _username.text.trim(),
          name: _name.text.trim().isEmpty ? _username.text.trim() : _name.text.trim(),
          password: _password.text,
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
      } else {
        await widget.auth.signIn(
          username: _username.text.trim(),
          password: _password.text,
        );
      }
    } catch (e) {
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('USERNAME_TAKEN')) return 'That handle is already taken.';
    if (s.contains('USER_NOT_FOUND')) return 'No account with that handle.';
    if (s.contains('WRONG_PASSWORD')) return 'Wrong password.';
    return s.length > 140 ? '${s.substring(0, 140)}…' : s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        theme.brandMark(size: 34),
                        const SizedBox(width: 12),
                        Text('MONKEYHUB', style: theme.label.copyWith(letterSpacing: 3)),
                      ]),
                      const SizedBox(height: 28),
                      RichText(
                        text: TextSpan(
                          style: theme.displayHero,
                          children: [
                            TextSpan(text: _signingUp ? 'new\n' : 'welcome\n', style: theme.displayHero.copyWith(color: theme.inkMuted)),
                            TextSpan(text: _signingUp ? 'face.' : 'back.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _signingUp
                            ? 'pick a handle, set a password. the rest can wait.'
                            : 'sign in to your rooms. nothing here looks at your address book.',
                        style: theme.bodySoft,
                      ),
                      const SizedBox(height: 28),
                      _field(theme, 'HANDLE', _username, hint: 'something you can remember', autofill: false),
                      const SizedBox(height: 14),
                      _field(theme, 'PASSWORD', _password, obscure: true, hint: '…'),
                      if (_signingUp) ...[
                        const SizedBox(height: 14),
                        _field(theme, 'NAME · OPTIONAL', _name, hint: 'how the room will read you'),
                        const SizedBox(height: 14),
                        _field(theme, 'EMAIL · OPTIONAL', _email, hint: 'only for recovery, never shown'),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                            color: theme.danger.withValues(alpha: 0.12),
                            border: Border(left: BorderSide(color: theme.danger, width: 2)),
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                          ),
                          child: Text(_error!, style: theme.body.copyWith(color: theme.danger)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _submit,
                        child: AnimatedContainer(
                          duration: theme.motionFast,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _busy ? theme.accentSoft : theme.accent,
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                            boxShadow: _busy
                                ? null
                                : [BoxShadow(color: theme.accent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
                          ),
                          child: _busy
                              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentInk))
                              : Text(_signingUp ? 'OPEN ACCOUNT' : 'SIGN IN',
                                  style: theme.label.copyWith(color: theme.accentInk, letterSpacing: 2.4)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _signingUp = !_signingUp;
                            _error = null;
                          }),
                          child: RichText(
                            text: TextSpan(style: theme.bodySoft, children: [
                              TextSpan(text: _signingUp ? 'already here? ' : 'no account? '),
                              TextSpan(
                                text: _signingUp ? 'sign in' : 'open one',
                                style: theme.body.copyWith(color: theme.accent),
                              ),
                            ]),
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
    );
  }

  Widget _field(dynamic theme, String label, TextEditingController c,
      {bool obscure = false, String? hint, bool autofill = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.label),
        const SizedBox(height: 6),
        Container(
          decoration: theme.inputDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: c,
            obscureText: obscure,
            autocorrect: autofill,
            enableSuggestions: autofill,
            style: theme.body.copyWith(color: theme.ink),
            cursorColor: theme.accent,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: theme.body.copyWith(color: theme.inkMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
