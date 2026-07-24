import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_sheet.dart';

/// In-app browser presented from any tapped link.
///
/// The chrome is intentionally restrained — a custom header that uses the
/// active theme's typography (display title, mono-caps host with a lock
/// glyph and theme-accent ping), a hairline progress bar tinted by the
/// theme accent, and a footer with paired navigation arrows, a prominent
/// "Open in browser" pill, and overflow actions for copy / share / reload.
class InAppBrowserScreen extends StatefulWidget {
  const InAppBrowserScreen({super.key, required this.url});

  final String url;

  /// Convenience entry point used from message bubbles & link cards.
  static Future<void> open(BuildContext context, String url) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, _, _) => InAppBrowserScreen(url: url),
        transitionsBuilder: (context, animation, _, child) {
          // Subtle slide-up + fade for the entry — feels lighter than the
          // default fullscreen-dialog slide which whacks down from the top
          // edge and never animates back out cleanly on iOS.
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  InAppWebViewController? _controller;
  double _progress = 0;
  String? _title;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  Future<void> _refreshNavState() async {
    final controller = _controller;
    if (controller == null) return;
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open in system browser')),
      );
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _currentUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  Future<void> _share() async {
    await Share.share(_currentUrl, subject: _title);
  }

  bool get _isSecure {
    try {
      return Uri.parse(_currentUrl).scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  String _hostOf(String url) {
    try {
      final host = Uri.parse(url).host;
      return host.startsWith('www.') ? host.substring(4) : host;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: Column(
        children: [
          _BrowserHeader(
            theme: theme,
            title: _title,
            host: _hostOf(_currentUrl),
            isSecure: _isSecure,
            progress: _progress,
            onClose: () => Navigator.of(context).pop(),
            onReload: () => _controller?.reload(),
            onMenu: () => _showMenu(context, theme),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                transparentBackground: true,
                useShouldOverrideUrlLoading: false,
                mediaPlaybackRequiresUserGesture: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStart: (controller, url) {
                if (!mounted) return;
                setState(() {
                  _currentUrl = url?.toString() ?? _currentUrl;
                  _progress = 0.05;
                });
              },
              onLoadStop: (controller, url) async {
                if (!mounted) return;
                setState(() {
                  _currentUrl = url?.toString() ?? _currentUrl;
                  _progress = 1;
                });
                _refreshNavState();
              },
              onProgressChanged: (controller, p) {
                if (!mounted) return;
                setState(() => _progress = p / 100.0);
              },
              onTitleChanged: (controller, t) {
                if (!mounted || t == null) return;
                setState(() => _title = t);
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                if (!mounted) return;
                setState(() => _currentUrl = url?.toString() ?? _currentUrl);
                _refreshNavState();
              },
            ),
          ),
          _BrowserFooter(
            theme: theme,
            canGoBack: _canGoBack,
            canGoForward: _canGoForward,
            onBack: () => _controller?.goBack(),
            onForward: () => _controller?.goForward(),
            onOpenExternal: _openExternal,
            onShare: _share,
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, AppTheme theme) async {
    final action = await showAdaptiveSheet<_BrowserAction>(
      context,
      builder: (_) => _BrowserMenuSheet(theme: theme),
    );
    switch (action) {
      case _BrowserAction.copy:
        await _copy();
        break;
      case _BrowserAction.share:
        await _share();
        break;
      case _BrowserAction.openExternal:
        await _openExternal();
        break;
      case _BrowserAction.reload:
        _controller?.reload();
        break;
      case null:
        break;
    }
  }
}

class _BrowserHeader extends StatelessWidget {
  const _BrowserHeader({
    required this.theme,
    required this.title,
    required this.host,
    required this.isSecure,
    required this.progress,
    required this.onClose,
    required this.onReload,
    required this.onMenu,
  });

  final AppTheme theme;
  final String? title;
  final String host;
  final bool isSecure;
  final double progress;
  final VoidCallback onClose;
  final VoidCallback onReload;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final showProgress = progress > 0 && progress < 1;

    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(bottom: BorderSide(color: theme.divider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 10),
              child: Row(
                children: [
                  _HeaderIconButton(
                    theme: theme,
                    icon: Icons.close_rounded,
                    onTap: onClose,
                    tooltip: 'Close',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (title?.isNotEmpty ?? false) ? title! : host,
                          style: theme.bodyEmph.copyWith(
                            color: theme.ink,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              isSecure
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 10,
                              color: isSecure ? theme.success : theme.danger,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                host,
                                style: theme.monoTiny.copyWith(
                                  color: theme.inkMuted,
                                  letterSpacing: 0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _HeaderIconButton(
                    theme: theme,
                    icon: Icons.refresh_rounded,
                    onTap: onReload,
                    tooltip: 'Reload',
                  ),
                  _HeaderIconButton(
                    theme: theme,
                    icon: Icons.more_horiz_rounded,
                    onTap: onMenu,
                    tooltip: 'More',
                  ),
                ],
              ),
            ),
            // Hairline progress / divider in one slot.
            SizedBox(
              height: 2,
              child: showProgress
                  ? LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: theme.surface,
                      valueColor: AlwaysStoppedAnimation(theme.accent),
                    )
                  : Container(color: theme.divider.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserFooter extends StatelessWidget {
  const _BrowserFooter({
    required this.theme,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onOpenExternal,
    required this.onShare,
  });

  final AppTheme theme;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onOpenExternal;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          border: Border(top: BorderSide(color: theme.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            _FooterIconButton(
              theme: theme,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: canGoBack ? onBack : null,
            ),
            const SizedBox(width: 4),
            _FooterIconButton(
              theme: theme,
              icon: Icons.arrow_forward_ios_rounded,
              onTap: canGoForward ? onForward : null,
            ),
            const Spacer(),
            // The "leave to system browser" affordance gets the prominent
            // accent pill — it's the primary intent users come here for.
            _AccentPill(
              theme: theme,
              icon: Icons.arrow_outward_rounded,
              label: 'OPEN IN BROWSER',
              onTap: onOpenExternal,
            ),
            const SizedBox(width: 8),
            _FooterIconButton(
              theme: theme,
              icon: Icons.ios_share_rounded,
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.theme,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final AppTheme theme;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: theme.ink),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({
    required this.theme,
    required this.icon,
    required this.onTap,
  });

  final AppTheme theme;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 18,
            color: disabled ? theme.inkMuted.withValues(alpha: 0.4) : theme.ink,
          ),
        ),
      ),
    );
  }
}

class _AccentPill extends StatelessWidget {
  const _AccentPill({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: theme.accentInk),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.label.copyWith(
                  color: theme.accentInk,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserMenuSheet extends StatelessWidget {
  const _BrowserMenuSheet({required this.theme});
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.surfaceRaised,
            borderRadius: BorderRadius.circular(theme.radiusLg),
            border: Border.all(color: theme.divider),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuRow(
                theme: theme,
                icon: Icons.copy_rounded,
                label: 'Copy link',
                onTap: () => Navigator.of(context).pop(_BrowserAction.copy),
              ),
              _MenuRow(
                theme: theme,
                icon: Icons.ios_share_rounded,
                label: 'Share',
                onTap: () => Navigator.of(context).pop(_BrowserAction.share),
              ),
              _MenuRow(
                theme: theme,
                icon: Icons.arrow_outward_rounded,
                label: 'Open in system browser',
                onTap: () =>
                    Navigator.of(context).pop(_BrowserAction.openExternal),
              ),
              _MenuRow(
                theme: theme,
                icon: Icons.refresh_rounded,
                label: 'Reload',
                onTap: () => Navigator.of(context).pop(_BrowserAction.reload),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.ink),
              const SizedBox(width: 14),
              Text(label, style: theme.body.copyWith(color: theme.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BrowserAction { copy, share, openExternal, reload }
