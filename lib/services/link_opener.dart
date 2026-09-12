import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../invites/deep_link_service.dart';
import '../invites/invite_link.dart';
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

    // One of our own invite links, shared into a room. The browser is the
    // wrong destination for it: that page exists to bounce a stranger back
    // into the app, and we ARE the app — so the tap became a flash of Safari
    // and a round trip to reach a screen already one push away.
    //
    // Routed through the same seam the OS uses for a link tapped outside the
    // app, so an invite lands identically however it was reached, and the
    // "already signed in / wrong server / dead code" handling lives in one
    // place. [parseOwnInviteUrl], not [parseInviteLink]: in a room full of
    // prose, only a URL we minted may take a tap away from the browser.
    if (parseOwnInviteUrl(url) != null) {
      DeepLinkService.instance.handleExternal(url);
      return;
    }

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

  /// Dismiss the browser surface, if one is up.
  ///
  /// For the "open in app" button a web page shows: following it hands control
  /// back to us, but the tab it was tapped in is a platform surface, not a
  /// Flutter route — no amount of popping the navigator touches it, so without
  /// this the app opened UNDERNEATH a browser the user then had to close by
  /// hand, having already told it where they wanted to be.
  ///
  /// Safe to call blind: closing nothing is not an error on either platform,
  /// and the surface does not exist on web or desktop.
  static Future<void> dismiss() async {
    if (kIsWeb) return;
    try {
      await closeCustomTabs();
    } catch (_) {
      // No tab open, no Custom Tabs provider, or a platform with no such
      // surface at all. Nothing to close is the outcome we wanted anyway.
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
