import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../auth/social_sign_in.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

/// "Continue with Apple / Google", plus the two rules about the pair.
///
/// RULE 1 — THE APPLE BUTTON IS NOT OURS TO DESIGN. Apple publishes strict
/// Human Interface Guidelines for it: the mark, the wording, the minimum size
/// and the permitted colour treatments are all fixed, and a restyled one is a
/// real review rejection. So it is rendered by [SignInWithAppleButton] from the
/// SDK — Apple's own compliant widget — and NOT by the themed button below.
/// Resist the urge to make it match the rest of the app; that urge is the bug.
/// (It uses CupertinoButton internally, so it brings no ink or ripple with it.)
///
/// The permitted wording is "Sign in with Apple", "Sign up with Apple" or
/// "Continue with Apple". This flow can be either a sign-in or a sign-up and
/// does not know which until the backend answers, so "Continue" is the only one
/// that is honest in both cases.
///
/// RULE 2 — APPLE AND GOOGLE ARE NOT INDEPENDENT ON iOS. Guideline 4.8 lets an
/// app that uses only its own account system skip third-party login entirely,
/// which is where this app has been. Adding Google alone forfeits that exemption
/// and requires an equivalent service offering a private-email option — and Sign
/// in with Apple is the only mainstream one that qualifies. On Apple platforms
/// it is both buttons or neither, never Google on its own.
///
/// Android is outside guideline 4.8 and gets Google alone, because Sign in with
/// Apple there would need the web redirect flow (a Services ID and an HTTPS
/// return URL) — the one piece of this feature that would tie us to a domain.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.onProvider,
    this.busyProvider,
    this.enabled = true,
    this.dividerLabel = 'or',
  });

  final ValueChanged<SocialProvider> onProvider;

  /// Which provider is mid-flight. Null means none.
  final SocialProvider? busyProvider;
  final bool enabled;

  /// Null drops the divider — the Profile screen wants the buttons bare.
  final String? dividerLabel;

  /// Apple's minimum. The Google button matches it so the pair lines up.
  static const double _buttonHeight = 44;

  static List<SocialProvider> get available => [
        if (SocialSignIn.appleAvailable) SocialProvider.apple,
        if (SocialSignIn.googleAvailable) SocialProvider.google,
      ];

  @override
  Widget build(BuildContext context) {
    final providers = available;
    if (providers.isEmpty) return const SizedBox.shrink();

    final theme = ThemeScope.of(context);
    // One at a time — a second tap while a native sheet is up would stack two.
    final live = enabled && busyProvider == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dividerLabel != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: theme.divider, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(dividerLabel!, style: theme.caption),
              ),
              Expanded(child: Divider(color: theme.divider, height: 1)),
            ],
          ),
          const SizedBox(height: 16),
        ],
        for (final provider in providers) ...[
          if (provider == SocialProvider.apple)
            _AppleButton(
              enabled: live,
              onTap: () => onProvider(SocialProvider.apple),
            )
          else
            _GoogleButton(
              busy: busyProvider == SocialProvider.google,
              enabled: live,
              height: _buttonHeight,
              onTap: () => onProvider(SocialProvider.google),
            ),
          if (provider != providers.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Apple's own widget, deliberately unstyled by us. See RULE 1 above.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Apple's rule is black on light backgrounds, white on dark. Derived from
    // the theme's own background rather than a hardcoded choice, because this
    // app ships many themes and several are dark.
    final onDark =
        ThemeData.estimateBrightnessForColor(theme.background) == Brightness.dark;

    return SignInWithAppleButton(
      // Null rather than a no-op closure: the underlying CupertinoButton then
      // renders a real disabled state. A button that visibly accepts a tap and
      // does nothing reads as broken.
      onPressed: enabled ? onTap : null,
      text: 'Continue with Apple',
      style: onDark
          ? SignInWithAppleButtonStyle.white
          : SignInWithAppleButtonStyle.black,
      // Height and border radius left at Apple's defaults (44 / 8) on purpose.
      // Both are constrained by the HIG and there is nothing to gain by nudging
      // them toward the app's own radius scale.
    );
  }
}

/// Google has branding guidance too, but it is far less prescriptive than
/// Apple's — and this button carries no Google mark, only the wording — so it
/// is free to wear the app's own styling.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({
    required this.busy,
    required this.enabled,
    required this.height,
    required this.onTap,
  });

  final bool busy;
  final bool enabled;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    const label = 'Continue with Google';
    return FocusableTap(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      semanticLabel: label,
      radius: theme.radiusMd,
      // Never InkWell anywhere in this app — no ink, no ripple.
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: theme.motionFast,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.surfaceRaised,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(color: theme.divider),
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
                  style: theme.bodyEmph.copyWith(
                    color: enabled ? theme.ink : theme.inkMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
