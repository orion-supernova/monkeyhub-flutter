import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../auth/apple_button_titles.dart';
import '../auth/google_web_button.dart';
import '../auth/social_sign_in.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show OrDivider;

/// "Continue with Apple / Google", plus the three rules about the pair.
///
/// RULE 1 — NEITHER BUTTON IS OURS TO DESIGN. Both vendors publish binding
/// guidelines covering the mark, the wording, the colours, the typeface and the
/// minimum size, and a restyled button is a real review rejection rather than a
/// nitpick. Everything below that looks like a hardcoded magic number is a
/// value from one of those two documents. Resist the urge to make either button
/// match the rest of the app; that urge is the bug.
///
/// The one thing both vendors explicitly leave to us is the corner radius —
/// Apple's HIG permits matching "the other buttons in your UI", and Google
/// ships both a rectangular and a pill variant. So both take the theme's
/// `radiusMd` and stay a matched pair with the CTA above them on every theme.
///
/// Apple's permitted wording is "Sign in with Apple", "Sign up with Apple" or
/// "Continue with Apple", and Google's is the same three verbs. This flow can be
/// either a sign-in or a sign-up and does not know which until the backend
/// answers, so "Continue" is the only one that is honest in both cases.
///
/// RULE 2 — THE TWO BUTTONS LOCALIZE DIFFERENTLY, AND THAT IS NOT AN
/// INCONSISTENCY TO TIDY UP. Apple's title is Apple's copy: it comes from the
/// const table in [appleContinueTitle] and deliberately has no ARB key, because
/// a translation pass is not entitled to rewrite it (it did, and three locales
/// drifted). Google, by contrast, states that localizing their button text is
/// "permitted and encouraged", so their label is a normal ARB string.
///
/// RULE 3 — APPLE AND GOOGLE ARE NOT INDEPENDENT ON iOS. Guideline 4.8 lets an
/// app that uses only its own account system skip third-party login entirely,
/// which is where this app has been. Adding Google alone forfeits that exemption
/// and requires an equivalent service offering a private-email option — and Sign
/// in with Apple is the only mainstream one that qualifies. On Apple platforms
/// it is both buttons or neither, never Google on its own. The Apple button also
/// has to be no smaller than the Google one, which is why they share
/// [_buttonHeight] rather than each taking its own vendor minimum.
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
    this.dividerLabel = _autoDividerLabel,
    this.only,
  });

  final ValueChanged<SocialProvider> onProvider;

  /// Which provider is mid-flight. Null means none.
  final SocialProvider? busyProvider;
  final bool enabled;

  /// Null drops the divider — the Profile screen wants the buttons bare.
  /// Left unset (the default), the divider shows the localized "or". This
  /// sentinel exists only because a const constructor's default value must be
  /// a compile-time constant, so the localized fallback is resolved in
  /// [build] instead — see [_autoDividerLabel].
  final String? dividerLabel;

  /// Private marker meaning "no explicit [dividerLabel] was provided" —
  /// distinct from an explicit `null`, which hides the divider entirely.
  static const String _autoDividerLabel = '__social_sign_in_auto_divider__';

  /// Narrows the set to specific providers. Null renders every [available] one,
  /// which is what sign-in wants. Linked Accounts renders them one per card and
  /// passes a single provider — the button still has to be the compliant one
  /// there, so it asks for a subset rather than hand-rolling the mark.
  ///
  /// Still intersected with [available]: a provider this platform can't do is
  /// dropped however loudly it was asked for.
  final List<SocialProvider>? only;

  /// Apple's minimum, and above Google's 40. Both buttons take it — see RULE 3
  /// on why the Apple one may never end up the smaller of the two.
  static const double _buttonHeight = 44;

  static List<SocialProvider> get available => [
    if (SocialSignIn.appleAvailable) SocialProvider.apple,
    if (SocialSignIn.googleAvailable) SocialProvider.google,
  ];

  @override
  Widget build(BuildContext context) {
    final providers = only == null
        ? available
        : available.where(only!.contains).toList();
    if (providers.isEmpty) return const SizedBox.shrink();

    // One at a time — a second tap while a native sheet is up would stack two.
    final live = enabled && busyProvider == null;
    final resolvedDividerLabel = dividerLabel == _autoDividerLabel
        ? AppLocalizations.of(context).socialButtonDividerOr
        : dividerLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (resolvedDividerLabel != null) ...[
          const SizedBox(height: 6),
          // The shared "or" rule — meta on the body face; it was the theme's
          // caption, monospace on character themes.
          OrDivider(label: resolvedDividerLabel),
          const SizedBox(height: 2),
        ],
        for (final provider in providers) ...[
          if (provider == SocialProvider.apple)
            _AppleButton(
              enabled: live,
              onTap: () => onProvider(SocialProvider.apple),
            )
          else if (SocialSignIn.googleUsesRenderedButton)
            _GoogleWebButton(
              busy: busyProvider == SocialProvider.google,
              enabled: live,
              height: _buttonHeight,
              onDelivered: () => onProvider(SocialProvider.google),
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

/// Whether this theme's background is dark enough to want each vendor's dark
/// button variant. Both vendors define exactly two treatments — one for light
/// backgrounds, one for dark — and both buttons must answer this the same way
/// or the pair ends up in opposite polarities on the same screen.
bool _onDarkBackground(BuildContext context) =>
    ThemeData.estimateBrightnessForColor(ThemeScope.of(context).background) ==
    Brightness.dark;

/// Apple's own widget, deliberately unstyled by us. See RULE 1 above.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    return SignInWithAppleButton(
      // Null rather than a no-op closure: the underlying CupertinoButton then
      // renders a real disabled state. A button that visibly accepts a tap and
      // does nothing reads as broken.
      onPressed: enabled ? onTap : null,
      // Apple's copy, not ours, and not an ARB key. See apple_button_titles.dart.
      text: appleContinueTitle(Localizations.localeOf(context)),
      style: _onDarkBackground(context)
          ? SignInWithAppleButtonStyle.white
          : SignInWithAppleButtonStyle.black,
      // Radius is the one dimension the HIG hands back to us; height stays at
      // Apple's default 44, which is also SocialSignInButtons._buttonHeight.
      borderRadius: BorderRadius.circular(theme.radiusMd),
    );
  }
}

/// Google's button, built to the Sign in with Google branding guidelines.
///
/// Every colour here is fixed by Google and none of them are theme tokens —
/// that is the whole point, and an earlier version of this button that wore the
/// theme's `surfaceRaised` and carried no "G" at all was out of compliance.
/// Google publishes three treatments (light, dark, neutral); this uses light
/// and dark, chosen by [_onDarkBackground] so the pair with Apple stays in the
/// same polarity.
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

  // Google's published values. Do not nudge them toward the theme.
  static const Color _lightFill = Color(0xFFFFFFFF);
  static const Color _lightStroke = Color(0xFF747775);
  static const Color _lightText = Color(0xFF1F1F1F);
  static const Color _darkFill = Color(0xFF131314);
  static const Color _darkStroke = Color(0xFF8E918F);
  static const Color _darkText = Color(0xFFE3E3E3);

  /// Google's iOS spec: 16 before the logo, 12 between logo and text, 16 after.
  static const double _endPadding = 16;
  static const double _logoGap = 12;
  static const double _logoSize = 18;

  /// Must match the `family:` declared in pubspec's `fonts:` section — Flutter
  /// resolves this by string and silently falls back to the platform face if
  /// the two ever drift apart.
  static const String _fontFamily = 'Google Sans';

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final onDark = _onDarkBackground(context);
    final label = AppLocalizations.of(context).socialButtonGoogleContinue;

    // Google Sans Medium 14/20, the face and metrics the guidelines name.
    // Declared in pubspec's `fonts:` rather than resolved through the
    // google_fonts package — see the comment there — and subset to the scripts
    // the twelve labels actually use, so a locale added later may need the
    // subset re-cut (ar/ja/ko/zh already fall through to the platform font,
    // which is fine and is what Google's own Android button does).
    final textStyle = TextStyle(
      fontFamily: _fontFamily,
      fontWeight: FontWeight.w500,
      fontSize: 14,
      height: 20 / 14,
      color: onDark ? _darkText : _lightText,
    );

    // Disabled is a flat opacity over the whole lockup rather than a per-part
    // recolour: Google forbids recolouring the mark, and dimming the label
    // alone would leave a full-strength "G" on a dead button.
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: FocusableTap(
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
            padding: const EdgeInsets.symmetric(horizontal: _endPadding),
            decoration: BoxDecoration(
              color: onDark ? _darkFill : _lightFill,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(
                color: onDark ? _darkStroke : _lightStroke,
                width: 1,
              ),
            ),
            child: busy
                ? SizedBox(
                    width: _logoSize,
                    height: _logoSize,
                    child: CupertinoActivityIndicator(color: onDark ? _darkText : _lightText),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'branding/google_g.svg',
                        width: _logoSize,
                        height: _logoSize,
                      ),
                      const SizedBox(width: _logoGap),
                      Flexible(
                        child: Text(
                          label,
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Google's own button, on the web — see
/// [SocialSignIn.googleUsesRenderedButton] for why [_GoogleButton] cannot work
/// there.
///
/// Google draws it, in an iframe, and the click never reaches Flutter. The
/// result arrives on [SocialSignIn.webGoogleDeliveries], and only then does
/// this call [onDelivered] — the same `onProvider` a tap on [_GoogleButton]
/// makes, so every caller's `forProvider` handling works unchanged.
///
/// [_GoogleButton] stands in whenever the iframe must not take a click: while
/// the plugin initialises, while a sign-in is in flight (it owns the spinner),
/// and while the set is disabled. An iframe ignores `IgnorePointer`, so taking
/// it out is the only way to make it inert.
class _GoogleWebButton extends StatefulWidget {
  const _GoogleWebButton({
    required this.busy,
    required this.enabled,
    required this.height,
    required this.onDelivered,
  });

  final bool busy;
  final bool enabled;
  final double height;
  final VoidCallback onDelivered;

  @override
  State<_GoogleWebButton> createState() => _GoogleWebButtonState();
}

class _GoogleWebButtonState extends State<_GoogleWebButton> {
  StreamSubscription<void>? _deliveries;
  bool _ready = false;

  /// The rendered button, reused until what it was drawn for changes.
  ///
  /// Load-bearing: the plugin keys its view on the configuration's hashCode,
  /// which is identity. A fresh configuration per build would tear the iframe
  /// down and reload it on every keystroke in the form around it.
  Widget? _rendered;
  (bool, double, String)? _renderedFor;

  @override
  void initState() {
    super.initState();
    _deliveries = SocialSignIn.webGoogleDeliveries.listen((_) => _delivered());
    SocialSignIn.prepareGoogle().then(
      (_) {
        if (mounted) setState(() => _ready = true);
      },
      // Stays on the disabled stand-in. Nearly always the Google script was
      // blocked (an extension, a network filter), and a retry would not help.
      onError: (Object e) =>
          debugPrint('[social] google web button unavailable: $e'),
    );
  }

  @override
  void dispose() {
    _deliveries?.cancel();
    super.dispose();
  }

  void _delivered() {
    if (!mounted || !widget.enabled || widget.busy) return;
    // Google's callback is page-wide, so a button on a covered route hears the
    // click made on the sheet above it. Only the one on top answers.
    if (ModalRoute.of(context)?.isCurrent == false) return;
    widget.onDelivered();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || widget.busy || !widget.enabled) {
      return _GoogleButton(
        busy: widget.busy,
        enabled: false,
        height: widget.height,
        onTap: () {},
      );
    }
    final onDark = _onDarkBackground(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Google caps its button at 400 px wide.
          final width = constraints.maxWidth.clamp(200.0, 400.0).floorToDouble();
          final key = (onDark, width, locale);
          if (_renderedFor != key) {
            _renderedFor = key;
            _rendered = renderGoogleWebButton(
              onDark: onDark,
              width: width,
              locale: locale,
            );
          }
          return Center(child: _rendered);
        },
      ),
    );
  }
}
