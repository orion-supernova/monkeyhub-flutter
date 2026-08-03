import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/social_sign_in.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/password_prompt_sheet.dart';
import '../widgets/social_sign_in_buttons.dart';

/// Every way back into this account, one card per provider.
///
/// This used to be two bare LINK/UNLINK rows buried at the bottom of the
/// ACCOUNT section, where the label was the only thing telling you the current
/// state — you had to read "UNLINK APPLE" and work backwards to "so Apple is
/// linked". Here the state is the headline and the action is secondary.
///
/// Linking a provider is offered through [SocialSignInButtons], not a themed
/// button of our own: on Apple's side the mark, wording and colour treatment
/// are fixed by the HIG whatever screen the flow starts from.
class SignInMethodsScreen extends StatefulWidget {
  const SignInMethodsScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SignInMethodsScreen> createState() => _SignInMethodsScreenState();
}

class _SignInMethodsScreenState extends State<SignInMethodsScreen> {
  /// Providers attached to this account. Null while unknown — the cards render
  /// a neutral "checking" state rather than claiming "not linked" and inviting
  /// a duplicate link the backend would only reject.
  List<SocialProvider>? _linked;
  SocialProvider? _busy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final auth = widget.auth;
    if (auth.isChild || !auth.isSignedIn) return;
    try {
      final linked = await auth.linkedProviders();
      if (mounted) setState(() => _linked = linked);
    } catch (_) {
      // Offline or an older backend. Null keeps the cards honest about not
      // knowing.
    }
  }

  /// Attaches or detaches a provider, password-gated in both directions.
  ///
  /// Linking runs the native provider sheet FIRST and asks for the password
  /// second: the provider flow is the one that can be cancelled casually, and
  /// making someone type their password before finding that out would be rude.
  Future<void> _toggle(SocialProvider provider) async {
    final auth = widget.auth;
    if (auth.isChild || _busy != null) return;
    final linked = _linked?.contains(provider) ?? false;

    setState(() => _error = null);
    try {
      if (linked) {
        final password = await _askPassword(
          title: 'UNLINK ${provider.label.toUpperCase()}',
          actionLabel: 'UNLINK',
          subtitle:
              'Enter your password to stop signing in with ${provider.label}.',
        );
        if (password == null) return;
        setState(() => _busy = provider);
        await auth.unlinkSocialIdentity(password: password, provider: provider);
      } else {
        final credential = await SocialSignIn.forProvider(provider);
        if (!mounted) return;
        final password = await _askPassword(
          title: 'LINK ${provider.label.toUpperCase()}',
          actionLabel: 'LINK',
          subtitle:
              'Enter your password to add ${provider.label} as a way to sign in.',
        );
        if (password == null) return;
        setState(() => _busy = provider);
        await auth.linkSocialIdentity(
          password: password,
          credential: credential,
        );
      }
      await _refresh();
    } on SocialSignInCancelled {
      // Backed out of the native sheet — not a failure, say nothing.
    } catch (e) {
      if (mounted) setState(() => _error = humanizeAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<String?> _askPassword({
    required String title,
    required String actionLabel,
    required String subtitle,
  }) => askPassword(
    context,
    title: title,
    actionLabel: actionLabel,
    subtitle: subtitle,
  );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final providers = SocialSignInButtons.available;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.inkSoft,
                          size: 18,
                        ),
                      ),
                      Text(
                        'SIGN-IN METHODS',
                        style: theme.label.copyWith(letterSpacing: 2.4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How you get back into this account. Your password always '
                    'works — these are shortcuts on top of it.',
                    style: theme.bodySoft,
                  ),
                  const SizedBox(height: 24),
                  if (providers.isEmpty)
                    Text(
                      'No sign-in shortcuts are available on this device.',
                      style: theme.body.copyWith(color: theme.inkMuted),
                    )
                  else
                    for (final provider in providers) ...[
                      _ProviderCard(
                        provider: provider,
                        // Null propagates as "unknown" — see [_linked].
                        linked: _linked?.contains(provider),
                        busy: _busy == provider,
                        anyBusy: _busy != null,
                        onToggle: () => _toggle(provider),
                      ),
                      const SizedBox(height: 12),
                    ],
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: theme.body.copyWith(color: theme.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.linked,
    required this.busy,
    required this.anyBusy,
    required this.onToggle,
  });

  final SocialProvider provider;

  /// True linked, false not, null not yet known.
  final bool? linked;
  final bool busy;

  /// Some provider is mid-flight — possibly a different one. Both cards go
  /// inert, because two native sheets stacked on top of each other is a mess
  /// only one of them can back out of.
  final bool anyBusy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isLinked = linked == true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(
          color: isLinked ? theme.accent.withValues(alpha: 0.4) : theme.divider,
        ),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // No vendor glyph here on purpose. Apple's mark and Google's
              // both come with usage rules, and neither is needed — the name
              // is right there, and the only thing that must carry their
              // branding is the button below, which is Apple's own widget.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLinked ? theme.accent : theme.divider,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(provider.label, style: theme.displaySmall)),
              _StatusPill(linked: linked),
            ],
          ),
          const SizedBox(height: 8),
          Text(switch (linked) {
            null => 'Checking…',
            true =>
              'You can sign in with ${provider.label} on any of your devices.',
            false =>
              'Add ${provider.label} so you don\'t have to type your password.',
          }, style: theme.bodySoft),
          const SizedBox(height: 14),
          if (linked == null)
            const SizedBox.shrink()
          else if (isLinked)
            _UnlinkButton(
              label: 'UNLINK ${provider.label.toUpperCase()}',
              busy: busy,
              enabled: !anyBusy,
              onTap: onToggle,
              theme: theme,
            )
          else
            // Apple's own widget, never restyled. See SocialSignInButtons.
            SocialSignInButtons(
              only: [provider],
              dividerLabel: null,
              enabled: !anyBusy,
              busyProvider: busy ? provider : null,
              onProvider: (_) => onToggle(),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.linked});

  /// True linked, false not, null not yet known.
  final bool? linked;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final (label, color) = switch (linked) {
      null => ('CHECKING', theme.inkMuted),
      true => ('LINKED', theme.accent),
      false => ('NOT LINKED', theme.inkMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: theme.monoTiny.copyWith(color: color, letterSpacing: 1.2),
      ),
    );
  }
}

/// Unlinking carries no vendor branding — it's our own destructive-ish action,
/// so it wears the app's styling. Matched to the 44pt provider buttons above so
/// the two cards line up whichever state they're in.
class _UnlinkButton extends StatelessWidget {
  const _UnlinkButton({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      semanticLabel: label,
      radius: theme.radiusMd,
      // Never InkWell anywhere in this app — no ink, no ripple.
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.surfaceRaised,
            border: Border.all(color: theme.divider),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.inkSoft,
                  ),
                )
              : Text(
                  label,
                  style: theme.label.copyWith(
                    color: enabled ? theme.ink : theme.inkMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
