import 'package:flutter/widgets.dart' show Locale;

/// Apple's own localized titles for the Sign in with Apple button.
///
/// THESE STRINGS ARE APPLE'S COPY, NOT OURS, AND MUST NOT MOVE INTO AN ARB
/// FILE. Apple's system-provided button translates its own title; a custom
/// button — which [SignInWithAppleButton] is, being a Flutter reimplementation
/// rather than a wrapped `ASAuthorizationAppleIDButton` — has to supply the same
/// wording itself. Translating it ourselves is a Human Interface Guidelines
/// violation even when the result happens to read correctly.
///
/// It did not read correctly. These lived in the ARB files until 2026-08-08,
/// where a routine translation-review pass is free to "improve" them, and three
/// of the twelve had drifted from Apple's wording by the time anyone checked.
/// A const table is the point: there is nothing here for a translator to edit.
///
/// Extracted verbatim from the installed iOS 26.5 simulator runtime:
///
/// ```
/// AuthenticationServices.framework/<lang>.lproj/Localizable.strings
/// key: "Continue with Apple"
/// ```
///
/// Re-extract them (rather than hand-editing) if a locale is ever added:
///
/// ```sh
/// FW="$(ls -d /Library/Developer/CoreSimulator/Volumes/*/Library/Developer/\
/// CoreSimulator/Profiles/Runtimes/*.simruntime | head -1)/Contents/Resources/\
/// RuntimeRoot/System/Cryptexes/OS/System/Library/Frameworks/\
/// AuthenticationServices.framework"
/// plutil -p "$FW/<lang>.lproj/Localizable.strings" | grep '"Continue with Apple"'
/// ```
///
/// "Continue with" is the right one of Apple's three permitted titles here
/// ("Sign in with" / "Sign up with" / "Continue with"): this flow does not know
/// whether it is a sign-in or a sign-up until the backend answers, so it is the
/// only one that is honest in both cases.
const Map<String, String> kAppleContinueTitles = {
  'ar': 'الاستمرار باستخدام Apple',
  'en': 'Continue with Apple',
  'es': 'Continuar con Apple',
  'fr': 'Continuer avec Apple',
  'hi': 'Apple से जारी रखें',
  'ja': 'Appleで続ける',
  'ko': 'Apple로 계속하기',
  // European and Brazilian Portuguese share this one. Apple's pt.lproj (which
  // is pt-BR) and pt_PT.lproj give the same string for this key, so there is no
  // pt_BR entry to add.
  'pt': 'Continuar com a Apple',
  'sv': 'Fortsätt med Apple',
  'tr': 'Apple ile Devam Et',
  // No spaces around "Apple" — that is Apple's own typesetting for zh-Hans, and
  // the spaced variant we used to ship was our invention.
  'zh': '通过Apple继续',
};

/// Apple's title for [locale], falling back to English.
///
/// Matched on language code alone: Apple's string is identical across every
/// regional variant we ship (see the `pt` note above), and a locale we have no
/// entry for is a locale the app itself does not support, so English is the
/// same answer `AppLocalizations` would give.
String appleContinueTitle(Locale locale) =>
    kAppleContinueTitles[locale.languageCode] ?? kAppleContinueTitles['en']!;
