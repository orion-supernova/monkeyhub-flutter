import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// Google's button, drawn by Google Identity Services into an iframe.
///
/// Every choice here is one of Google's own treatments, so there is nothing to
/// keep in step with their branding guidelines: `outline` and `filledBlack` are
/// the light and dark variants the app-drawn button copies, "Continue with" is
/// the verb that is honest for a flow that may be a sign-up, and `large` is
/// their 40 px size. The text is Google's too, localized by [locale].
///
/// The result is a new iframe every time, so callers must keep the widget and
/// only call this again when an argument changes.
Widget renderGoogleWebButton({
  required bool onDark,
  required double width,
  required String locale,
}) =>
    gsi.renderButton(
      configuration: gsi.GSIButtonConfiguration(
        type: gsi.GSIButtonType.standard,
        theme: onDark ? gsi.GSIButtonTheme.filledBlack : gsi.GSIButtonTheme.outline,
        size: gsi.GSIButtonSize.large,
        text: gsi.GSIButtonText.continueWith,
        shape: gsi.GSIButtonShape.rectangular,
        logoAlignment: gsi.GSIButtonLogoAlignment.center,
        minimumWidth: width,
        locale: locale,
      ),
    );
