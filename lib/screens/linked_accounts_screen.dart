import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/social_sign_in.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/account_kit.dart';
import '../widgets/ios_kit.dart';
import '../widgets/password_prompt_sheet.dart';
import '../widgets/social_sign_in_buttons.dart';

/// The Apple/Google accounts attached to this one, a card per provider.
///
/// This used to be two bare LINK/UNLINK rows buried at the bottom of the
/// ACCOUNT section, where the label was the only thing telling you the current
/// state — you had to read "UNLINK APPLE" and work backwards to "so Apple is
/// linked". Here the state is the headline and the action is secondary.
///
/// NOT called "sign-in methods", though it was for one commit: the password
/// and the recovery phrase are also ways into the account, and they live in
/// their own rows outside this screen. A name that claimed to cover them would
/// send people here looking for something that isn't here.
///
/// Linking a provider is offered through [SocialSignInButtons], not a themed
/// button of our own: on Apple's side the mark, wording and colour treatment
/// are fixed by the HIG whatever screen the flow starts from.
class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
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
          title: AppLocalizations.of(
            context,
          ).laUnlinkProvider(provider.label),
          actionLabel: AppLocalizations.of(
            context,
          ).laUnlink,
          subtitle: AppLocalizations.of(
            context,
          ).linkedAccountsScreenUnlinkSubtitle(provider.label),
        );
        if (password == null) return;
        setState(() => _busy = provider);
        await auth.unlinkSocialIdentity(password: password, provider: provider);
      } else {
        final credential = await SocialSignIn.forProvider(provider);
        if (!mounted) return;
        final password = await _askPassword(
          title: AppLocalizations.of(
            context,
          ).laLinkProvider(provider.label),
          actionLabel: AppLocalizations.of(
            context,
          ).laLink,
          subtitle: AppLocalizations.of(
            context,
          ).linkedAccountsScreenLinkSubtitle(provider.label),
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
      if (mounted) {
        setState(
          () => _error = humanizeAuthError(e, AppLocalizations.of(context)),
        );
      }
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
    final l10n = AppLocalizations.of(context);
    final providers = SocialSignInButtons.available;
    return IosPage(
      title: l10n.acctRowLinked,
      subtitle: l10n.linkedAccountsScreenSubtitle,
      slivers: readableSlivers(context, [
        if (providers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.linkedAccountsScreenEmptyState,
              style: theme.body.copyWith(color: theme.inkMuted),
            ),
          )
        else
          for (final provider in providers)
            _ProviderCard(
              provider: provider,
              linked: _linked?.contains(provider),
              busy: _busy == provider,
              anyBusy: _busy != null,
              onToggle: () => _toggle(provider),
            ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: theme.body.copyWith(color: theme.danger),
            ),
          ),
      ]),
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
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
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
              Expanded(
                child: Text(
                  provider.label,
                  style: theme.bodyEmph.copyWith(fontSize: 17, color: theme.ink),
                ),
              ),
              _StatusPill(linked: linked),
            ],
          ),
          const SizedBox(height: 8),
          Text(switch (linked) {
            null => AppLocalizations.of(
              context,
            ).linkedAccountsScreenStatusChecking,
            true => AppLocalizations.of(
              context,
            ).linkedAccountsScreenStatusLinked(provider.label),
            false => AppLocalizations.of(
              context,
            ).linkedAccountsScreenStatusNotLinked(provider.label),
          }, style: theme.caption.copyWith(fontSize: 14, color: theme.inkMuted)),
          const SizedBox(height: 14),
          if (linked == null)
            const SizedBox.shrink()
          else if (isLinked)
            _UnlinkButton(
              label: AppLocalizations.of(
                context,
              ).laUnlinkProvider(provider.label),
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

/// Linked or not, as an iOS status: a glyph and a word, no box.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.linked});

  /// Null while the server's answer is in flight.
  final bool? linked;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    if (linked == null) {
      return SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: theme.inkMuted),
      );
    }
    final on = linked!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          on ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
          size: 16,
          color: on ? theme.success : theme.inkMuted,
        ),
        const SizedBox(width: 5),
        Text(
          on ? l10n.laLinked : l10n.laNotLinked,
          style: theme.caption.copyWith(
            fontSize: 14,
            color: on ? theme.success : theme.inkMuted,
          ),
        ),
      ],
    );
  }
}

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
    if (busy) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.inkSoft),
        ),
      );
    }
    return SheetButton(
      label: label,
      danger: true,
      onTap: enabled ? onTap : null,
    );
  }
}
