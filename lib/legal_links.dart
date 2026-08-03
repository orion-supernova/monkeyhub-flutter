/// The published legal documents, and the one place their addresses live.
///
/// THESE LINKS ARE A STORE REQUIREMENT, not a nicety. App Store Review
/// Guideline 5.1.1(i) requires a privacy policy link *inside the app*, and
/// Google's User Data policy requires one both in the Play listing and in the
/// app itself. Until these existed, `lib/` contained no link to any legal page
/// at all — the only walhallaa.com URL in the whole client was the download
/// page — which is a rejection on both stores rather than a nice-to-have.
///
/// They point at walhallaa.com rather than monkeyhub.walhallaa.com because that
/// is the domain both store listings already reference, and a second copy of a
/// legal document is a second thing that has to stay true.
///
/// [deleteAccount] is separately mandated by Google Play: an account-deletion
/// route has to work for someone who has already uninstalled the app, which by
/// definition cannot be the in-app flow.
library;

const String kPrivacyPolicyUrl =
    'https://walhallaa.com/monkeyhub-privacy-terms.html#privacy';

const String kTermsOfServiceUrl =
    'https://walhallaa.com/monkeyhub-privacy-terms.html#terms';

const String kEulaUrl = 'https://walhallaa.com/monkeyhub-eula.html';

const String kDeleteAccountUrl =
    'https://walhallaa.com/monkeyhub-delete-account.html';
