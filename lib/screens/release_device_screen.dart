import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/ios_kit.dart';
import '../widgets/code_field.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';

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
  String _childName(BuildContext context) =>
      widget.auth.session?.name ??
      AppLocalizations.of(context).releaseDeviceScreenFallbackChildName;

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
    final l10n = AppLocalizations.of(context);
    if (s.contains('PAIRING_CODE_EXPIRED')) {
      return l10n.releaseDeviceScreenErrorCodeExpired;
    }
    if (s.contains('PAIRING_CODE_INVALID')) {
      return l10n.releaseDeviceScreenErrorCodeInvalid;
    }
    // The backend answers every password failure identically on purpose — a
    // child holding this phone must not be able to learn which usernames are
    // their grown-ups, so don't invent a more specific message here.
    if (s.contains('NOT_A_GUARDIAN')) {
      return l10n.releaseDeviceScreenErrorNotAGuardian;
    }
    return l10n.releaseDeviceScreenErrorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final childName = _childName(context);
    return IosPage(
      title: l10n.acctHandPhoneBack,
      slivers: readableSlivers(context, [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.releaseDeviceScreenIntro(childName),
                style: theme.bodySoft,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.releaseDeviceScreenAccountKeptNote,
                style: theme.caption.copyWith(color: theme.inkMuted),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.releaseDeviceScreenAskGrownUp(childName),
                style: theme.bodySoft,
              ),
              const SizedBox(height: 20),
              CodeField(
                controller: _code,
                enabled: !_busy,
                onCompleted: _submitCode,
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(child: Container(height: 0.5, color: theme.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      l10n.releaseDeviceScreenOrDivider,
                      style: theme.caption.copyWith(color: theme.inkMuted),
                    ),
                  ),
                  Expanded(child: Container(height: 0.5, color: theme.divider)),
                ],
              ),
              const SizedBox(height: 26),
              Text(l10n.releaseDeviceScreenOnePhoneNote, style: theme.bodySoft),
              const SizedBox(height: 14),
              ThemedInput(
                controller: _username,
                hint: l10n.releaseDeviceScreenUsernameHint,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 10),
              PasswordField(
                controller: _password,
                hint: l10n.releaseDeviceScreenPasswordHint,
                onSubmitted: (_) => _submitPassword(),
              ),
              const SizedBox(height: 18),
              SheetButton(
                label: _busy
                    ? l10n.linkedAccountsScreenStatusChecking
                    : l10n.rdSignOut(childName),
                filled: true,
                onTap: _busy ? null : _submitPassword,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: theme.bodySoft.copyWith(color: theme.danger),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}
