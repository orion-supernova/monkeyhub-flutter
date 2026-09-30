import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../expressions/klipy.dart';

/// Whether this platform can show KLIPY's ads at all. KLIPY serves them to
/// mobile only, and they are HTML that needs a platform web view.
bool get klipyAdsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Learns the platform web view's own User-Agent, once, for [KlipyClient].
///
/// KLIPY only fills ads for requests that look like a mobile browser; an app's
/// default agent (`Dart/3.x`, `CFNetwork/…`) gets none. KLIPY's own demos read
/// the agent off a `WKWebView` / Android `WebView` for exactly this reason.
/// Called when the expression panel first opens, so the first trending page
/// already carries it.
Future<void> primeKlipyUserAgent() async {
  if (!klipyAdsSupported || KlipyClient.browserUserAgent != null) return;
  try {
    final ua = await WebViewController().getUserAgent();
    if (ua != null && ua.isNotEmpty) KlipyClient.browserUserAgent = ua;
  } catch (e) {
    debugPrint('[klipy] user agent unavailable: $e');
  }
}

/// One KLIPY ad, at the size KLIPY returned it.
///
/// Taps inside the ad leave the app for the system browser rather than
/// navigating the tile — a GIF grid that turned into a landing page would be
/// the worst possible outcome of a mis-tap. The first page load (the ad's own
/// HTML) is the only navigation the web view performs itself.
class KlipyAdTile extends StatefulWidget {
  const KlipyAdTile({super.key, required this.ad});

  final KlipyAd ad;

  @override
  State<KlipyAdTile> createState() => _KlipyAdTileState();
}

class _KlipyAdTileState extends State<KlipyAdTile> {
  WebViewController? _controller;

  /// When the user last touched this tile. A main-frame navigation only leaves
  /// the app if it follows a real tap: an ad that redirects on its own (an
  /// auto-redirect is a known ad-fraud pattern) is simply refused, rather than
  /// allowed to throw the user into a browser while they scroll.
  DateTime? _lastTouch;

  bool get _recentlyTouched {
    final t = _lastTouch;
    return t != null &&
        DateTime.now().difference(t) < const Duration(seconds: 2);
  }

  @override
  void initState() {
    super.initState();
    if (!klipyAdsSupported) return;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          // `about:blank` and data URLs are the ad's own document loading.
          final uri = Uri.tryParse(req.url);
          if (uri == null ||
              uri.scheme == 'about' ||
              uri.scheme == 'data' ||
              !req.isMainFrame) {
            return NavigationDecision.navigate;
          }
          if (_recentlyTouched && (uri.scheme == 'https' || uri.scheme == 'http')) {
            _lastTouch = null;
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return NavigationDecision.prevent;
        },
      ));
    final ua = KlipyClient.browserUserAgent;
    if (ua != null) c.setUserAgent(ua);
    c.loadHtmlString(widget.ad.html, baseUrl: 'https://klipy.com');
    _controller = c;
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return Listener(
      onPointerDown: (_) => _lastTouch = DateTime.now(),
      child: SizedBox(
      width: widget.ad.width,
      height: widget.ad.height,
      child: WebViewWidget(
        controller: c,
        // Let a tap reach the ad, but leave vertical drags to the grid so the
        // tile never traps the scroll.
        gestureRecognizers: {
          Factory<TapGestureRecognizer>(TapGestureRecognizer.new),
        },
      ),
      ),
    );
  }
}
