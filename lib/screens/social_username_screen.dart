import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/social_sign_in.dart';
import '../data/username_availability_controller.dart';
import '../keyboard/dismiss_keyboard_on_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../platform.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/labeled_field.dart';
import '../widgets/password_field.dart';
import '../widgets/username_status_label.dart';
import '../widgets/ios_kit.dart';

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

  /// Live "is this free?", for [_Mode.create] only.
  ///
  /// [_Mode.link] types the handle of an account that already exists, so the
  /// verdict there would be inverted — "already taken" is precisely what the
  /// user is hoping for, and saying it in red would read as a rejection.
  late final _availability =
      UsernameAvailabilityController(api: widget.auth.api);

  /// Set when a create attempt failed specifically because the username exists,
  /// so the error can offer the fix rather than just stating the problem.
  bool _offerLink = false;

  @override
  void dispose() {
    _availability.dispose();
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
        // Both modes share the username field, and "already taken" means
        // opposite things in them. Re-feed rather than blank, so switching back
        // re-checks whatever is still in the box.
        _availability.onChanged(mode == _Mode.create ? _username.text : '');
      });

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim();
    if (username.isEmpty) {
      setState(() => _error =
          AppLocalizations.of(context).audioMessageUsernameRequiredError);
      return;
    }
    if (_mode == _Mode.link && _password.text.isEmpty) {
      setState(() => _error =
          AppLocalizations.of(context).audioMessagePasswordRequiredError);
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
      // Same reasoning as login_screen: the copy is intentionally vague, so the
      // raw code has to reach the console or it reaches nobody.
      debugPrint('[social] completeSignUp/link failed: $e');
      if (!mounted) return;
      final taken = e.toString().contains('USERNAME_TAKEN');
      setState(() {
        _error = humanizeAuthError(
          e,
          AppLocalizations.of(context),
          fallback: null,
        );
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
      body: DismissKeyboardOnTap(
        child: Stack(
          children: [
            theme.backgroundLayer(context),
            SafeArea(
              child: Column(
                children: [
                  // The way out. This screen is pushed as a fullscreenDialog,
                  // which on iOS also disables swipe-back — without this there is
                  // no gesture and no button that leaves, and a failed attempt
                  // traps the user on it. Top-leading, like every ×, in the same
                  // 52pt bar `IosPage` draws, so the form starts where every
                  // other page's content does.
                  SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IgnorePointer(
                          ignoring: _busy,
                          child: GlassCloseButton(
                            semanticLabel: AppLocalizations.of(context)
                                .audioMessageCancelSemanticLabel,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Top-aligned, not centred: centring a short form under a
                  // bar left ~350pt of nothing above the title on a phone.
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: ContentWidth.auth),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                creating
                                    ? AppLocalizations.of(context)
                                        .socialHeroCreateIos
                                    : AppLocalizations.of(context)
                                        .socialHeroLinkIos,
                                style: theme.displayLarge
                                    .copyWith(letterSpacing: 0.37),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                creating
                                    ? AppLocalizations.of(context)
                                        .audioMessageCreateSubtitle
                                    : AppLocalizations.of(context)
                                        .audioMessageLinkSubtitle(_provider),
                                style: theme.bodySoft.copyWith(fontSize: 17),
                              ),
                              const SizedBox(height: 28),
                              // Labelled fields, not placeholder-only: the
                              // name arrives prefilled from the provider, and
                              // with its placeholder gone nothing said which
                              // box was the username and which the name. The
                              // label carries the field's name, so the box
                              // itself stays empty rather than repeat it.
                              LabeledField(
                                label: AppLocalizations.of(context)
                                    .audioMessageUsernameHint,
                                controller: _username,
                                hint: '',
                                autocorrect: false,
                                enableSuggestions: false,
                                autofocus: isPhysicalKeyboardPlatform,
                                textInputAction: TextInputAction.next,
                                onChanged:
                                    creating ? _availability.onChanged : null,
                                onSubmitted: (_) =>
                                    FocusScope.of(context).nextFocus(),
                              ),
                              // The status label reserves its own 18pt line,
                              // which is the gap on create — stacking 12 on top
                              // of it left this pair visibly wider apart.
                              if (creating)
                                UsernameStatusLabel(controller: _availability)
                              else
                                const SizedBox(height: 12),
                              if (creating)
                                LabeledField(
                                  label: AppLocalizations.of(context)
                                      .audioMessageDisplayNameHint,
                                  controller: _name,
                                  hint: '',
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                )
                              else
                                PasswordField(
                                  controller: _password,
                                  label: AppLocalizations.of(context)
                                      .audioMessagePasswordHint,
                                  hint: '',
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                FormErrorBanner(
                                  _error!,
                                  // The whole point of the second mode, offered
                                  // right where "taken" is said.
                                  actionLabel: _offerLink
                                      ? AppLocalizations.of(context)
                                          .audioMessageSwitchToLinkPrompt
                                      : null,
                                  onAction: _offerLink
                                      ? () => _switchTo(_Mode.link)
                                      : null,
                                ),
                              ],
                              const SizedBox(height: 20),
                              _Cta(
                                busy: _busy,
                                label: creating
                                    ? AppLocalizations.of(context)
                                        .audioMessageCreateAccountButton
                                    : AppLocalizations.of(context)
                                        .socialSignInLinkIos(_provider),
                                onTap: _submit,
                              ),
                              const SizedBox(height: 12),
                              _SecondaryCta(
                                label: creating
                                    ? AppLocalizations.of(context)
                                        .audioMessageSwitchToLinkModeLink
                                    : AppLocalizations.of(context)
                                        .audioMessageSwitchToCreateModeLink,
                                onTap: _busy
                                    ? null
                                    : () => _switchTo(
                                        creating ? _Mode.link : _Mode.create,
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
      ),
    );
  }
}

/// The primary action: the app's filled capsule.
class _Cta extends StatelessWidget {
  const _Cta({required this.busy, required this.label, required this.onTap});
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SheetActionButton(
        label: label,
        busy: busy,
        // The one big commit on the screen: the heavier haptic, played here
        // instead of the default selection tick.
        haptic: false,
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
      );
}

/// The OTHER mode, as a button rather than a footnote.
///
/// This was a small underlined line at the very bottom of the screen, and it
/// was missed. The class doc above already says the most common first tap of a
/// provider button is by someone who ALREADY has an account of months'
/// standing — and what that person met was a hero reading "almost there." over
/// a CREATE ACCOUNT button, with the door they actually wanted set in caption
/// type below the fold. Three consecutive attempts on one real account ended
/// with the person backing out of this screen rather than finding it, and then
/// reporting that sign-in was broken. It was not; the way through was
/// invisible.
///
/// So it sits directly under the primary action, at the same width and weight,
/// where the two modes read as the pair they are.
///
/// OUTLINED, not filled, and that is the whole point of the widget: it has to
/// be impossible to miss without becoming impossible to tell apart from the
/// primary action. Someone who genuinely IS new must still see at a glance
/// which of the two is theirs, so only ever one of them is solid.
class _SecondaryCta extends StatelessWidget {
  const _SecondaryCta({required this.label, required this.onTap});

  final String label;

  /// Null while a request is in flight: the switch rebuilds the whole form,
  /// and doing that under a submit already on the wire is how the answer comes
  /// back to a screen that has moved on.
  final VoidCallback? onTap;

  // TINTED, not filled: impossible to miss, and still never mistaken for the
  // primary action — only one of the pair is ever solid.
  @override
  Widget build(BuildContext context) =>
      SheetActionButton(label: label, onTap: onTap, tonal: true);
}
