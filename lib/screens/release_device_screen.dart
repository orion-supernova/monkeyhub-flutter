import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/code_field.dart';
import '../widgets/labeled_field.dart';

/// Hands a child's phone back to a grown-up.
///
/// A child cannot sign themselves out — that is the point of a supervised
/// device — so this screen is a lock, not a door: it does nothing at all
/// without an adult's credential. Two ways to give one, because they fail in
/// different circumstances:
///
///   • **A six-digit code**, minted by a guardian on their own phone. The
///     normal case, and the safer one — single-use and short-lived, so a
///     child who watches it being typed gains nothing.
///   • **A guardian's username and password.** Needed when there is only one
///     handset: pairing a child signs the adult out, so there is no adult
///     session left anywhere to mint a code from. The trade-off is real —
///     a grown-up types their own password in front of the child — so it sits
///     below the code as the fallback, not the headline.
///
/// On success the sticky child-device marker is cleared too, so the phone
/// returns to the ordinary adult login form rather than bouncing straight
/// back to the pairing screen.
class ReleaseDeviceScreen extends StatefulWidget {
  const ReleaseDeviceScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ReleaseDeviceScreen> createState() => _ReleaseDeviceScreenState();
}

class _ReleaseDeviceScreenState extends State<ReleaseDeviceScreen> {
  final _code = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;

  /// Whose phone this is. Naming them makes "sign out" unambiguous — a parent
  /// reading a bare "unlock" can't tell whether it wipes the account.
  String get _childName => widget.auth.session?.name ?? 'them';

  @override
  void dispose() {
    _code.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submitCode(String code) async {
    await _run(() => widget.auth.releaseChildDeviceWithCode(code));
  }

  Future<void> _submitPassword() async {
    final user = _username.text.trim();
    final pass = _password.text;
    if (user.isEmpty || pass.isEmpty) return;
    await _run(() => widget.auth.releaseChildDeviceWithPassword(
          guardianUsername: user,
          password: pass,
        ));
  }

  /// Clearing the session makes `_AppHome` swap the login screen in — but that
  /// happens in the Navigator's *initial route*, underneath this pushed one.
  /// Without popping, the release succeeds invisibly and the user is left
  /// staring at a dead "checking…" button. Same reason
  /// `profile_screen._deleteAccount` pops after deleting.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      await action();
      if (!mounted) return;
      nav.popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _humanize(e);
        _busy = false;
        _code.clear();
        _password.clear();
      });
    }
  }

  String _humanize(Object e) {
    final s = e.toString();
    if (s.contains('PAIRING_CODE_EXPIRED')) {
      return 'That code has run out. Ask for a new one.';
    }
    if (s.contains('PAIRING_CODE_INVALID')) {
      return 'That code didn\'t work. It may have been used already.';
    }
    // The backend answers every password failure identically on purpose — a
    // child holding this phone must not be able to learn which usernames are
    // their grown-ups, so don't invent a more specific message here.
    if (s.contains('NOT_A_GUARDIAN')) {
      return 'That didn\'t work. Check the username and password.';
    }
    return 'Something went wrong. Try again.';
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
            child: AdaptivePageBody(
              child: Column(
              children: [
                _Header(onClose: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'This signs $_childName out of this phone and hands '
                          'it back — the phone returns to the normal sign-in '
                          'screen, and anyone can use it.',
                          style: theme.bodySoft,
                        ),
                        const SizedBox(height: 10),
                        // A grown-up standing here needs to know this is not
                        // the delete button. Nothing about the account changes.
                        Text(
                          'Their account, messages and friends are all kept. '
                          'They can be signed back in any time.',
                          style: theme.monoTiny.copyWith(color: theme.inkMuted),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Ask a grown-up to open MonkeyHub, find $_childName '
                          'under family, and tap “release”.',
                          style: theme.bodySoft,
                        ),
                        const SizedBox(height: 24),
                        CodeField(
                          controller: _code,
                          enabled: !_busy,
                          onCompleted: _submitCode,
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: Container(height: 1, color: theme.divider),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: theme.monoTiny),
                            ),
                            Expanded(
                              child: Container(height: 1, color: theme.divider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text(
                          'If there\'s only this one phone, a grown-up can sign '
                          'in here instead.',
                          style: theme.bodySoft,
                        ),
                        const SizedBox(height: 14),
                        ThemedInput(
                          controller: _username,
                          hint: 'a grown-up\'s username',
                          autocorrect: false,
                          enableSuggestions: false,
                        ),
                        const SizedBox(height: 10),
                        ThemedInput(
                          controller: _password,
                          hint: 'their password',
                          obscure: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          onSubmitted: (_) => _submitPassword(),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _busy ? null : _submitPassword,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _busy ? theme.surfaceSunken : theme.accent,
                              borderRadius:
                                  BorderRadius.circular(theme.radiusMd),
                            ),
                            child: Text(
                              _busy
                                  ? 'CHECKING…'
                                  : 'SIGN ${_childName.toUpperCase()} OUT',
                              style: theme.label.copyWith(
                                color:
                                    _busy ? theme.inkMuted : theme.accentInk,
                                letterSpacing: 2.4,
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          Text(
                            _error!,
                            style: theme.bodySoft.copyWith(color: theme.danger),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.arrow_back, size: 20, color: theme.inkSoft),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'HAND THIS PHONE BACK',
              style: theme.label.copyWith(letterSpacing: 2.8),
            ),
          ),
        ],
      ),
    );
  }
}
