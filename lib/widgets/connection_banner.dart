import 'dart:async';

import 'package:flutter/material.dart';

import '../backend/convex_client.dart';
import '../theme/theme_scope.dart';

/// Thin top-of-screen banner that appears only while the Convex socket is
/// disconnected. Lives in the safe-area inset so it never collides with
/// status bar or notch.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key, required this.cv});
  final ConvexBackend cv;

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  StreamSubscription<bool>? _sub;
  bool _connected = true;
  // Wait a beat before showing — momentary blips shouldn't flash a banner.
  Timer? _showTimer;
  bool _visible = false;

  // Self-heal watchdog. While the client reports disconnected, actively probe
  // real connectivity: the native connectionState stream can wedge on
  // `connecting` after a long OS suspension and never re-emit `connected`,
  // leaving this banner stuck forever even though the socket works (or can be
  // revived by the probe itself). A successful probe hides the banner.
  Timer? _watchdog;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _connected = widget.cv.isConnected;
    _sub = widget.cv.connectionState.listen((c) {
      if (!mounted) return;
      _connected = c;
      _showTimer?.cancel();
      if (c) {
        // Reconnected: hide immediately.
        _stopWatchdog();
        setState(() => _visible = false);
      } else {
        // Disconnected: start probing now (so a wedged stream can still
        // self-heal), and hold 800ms before showing the banner.
        _startWatchdog();
        _showTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted || _connected) return;
          setState(() => _visible = true);
        });
      }
    });
  }

  void _startWatchdog() {
    _watchdog ??=
        Timer.periodic(const Duration(seconds: 6), (_) => _probe());
    // Probe once up front rather than waiting a full interval.
    _probe();
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<void> _probe() async {
    if (_probing || _connected) return;
    _probing = true;
    final ok = await widget.cv.probeConnection();
    _probing = false;
    if (!mounted || !ok) return;
    // The socket actually works — reconcile the stuck state and hide.
    _connected = true;
    _stopWatchdog();
    _showTimer?.cancel();
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _showTimer?.cancel();
    _stopWatchdog();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, -1),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.surfaceRaised,
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(color: theme.divider),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'reconnecting…',
                  style: theme.monoTiny.copyWith(color: theme.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
