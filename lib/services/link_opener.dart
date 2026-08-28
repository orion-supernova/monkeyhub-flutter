import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';

/// Opens tapped links in the platform's own browser surface —
/// `SFSafariViewController` on iOS, Chrome Custom Tabs on Android.
///
/// This replaced a hand-rolled `InAppWebView` screen with ~400 lines of custom
/// chrome. The native surfaces bring their own share / copy / reload /
/// open-in-browser actions, their own reader mode, and — the part no custom
/// webview can offer — the user's real cookie jar and saved passwords, so a
/// tapped link lands already signed in.
///
/// The bar is tinted to the active theme where the OS still honours it: Android
/// Custom Tabs always, iOS up to 25. iOS 26 renders the browser chrome with
/// Liquid Glass and ignores both tint properties, so there it reads as stock
/// Safari regardless of the selected theme.
class LinkOpener {
  /// Entry point used from message bubbles & link preview cards.
  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // Resolve everything that needs `context` up front — the awaits below are
    // async gaps, after which touching `context` is unsafe.
    final theme = ThemeScope.of(context);
    final toast = AppToast.of(context);
    final couldNotOpenLinkMessage =
        AppLocalizations.of(context).linkOpenerCouldNotOpenLink;

    try {
      await launchUrl(
        uri,
        customTabsOptions: CustomTabsOptions(
          colorSchemes: CustomTabsColorSchemes.defaults(
            toolbarColor: theme.surface,
          ),
          shareState: CustomTabsShareState.on,
          urlBarHidingEnabled: true,
          showTitle: true,
        ),
        safariVCOptions: SafariViewControllerOptions(
          preferredBarTintColor: theme.surface,
          preferredControlTintColor: theme.accent,
          barCollapsingEnabled: true,
          dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        ),
      );
    } catch (_) {
      // Thrown when there's no Custom Tabs provider / no browser at all, and
      // for schemes the tab surface won't take. Hand it to the OS instead —
      // same fallback shape `openUpdateDestination` uses for store schemes.
      final opened = await _launchExternally(uri);
      if (!opened) {
        toast.show(couldNotOpenLinkMessage);
      }
    }
  }

  static Future<bool> _launchExternally(Uri uri) async {
    try {
      return await launcher.launchUrl(
        uri,
        mode: launcher.LaunchMode.externalApplication,
      );
    } catch (_) {
      // A scheme with no handler throws on some platforms and returns false on
      // others. Both mean the same thing here.
      return false;
    }
  }
}
