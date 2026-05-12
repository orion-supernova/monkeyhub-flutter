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
        setState(() => _visible = false);
      } else {
        // Disconnected: hold for 800ms before showing.
        _showTimer = Timer(const Duration(milliseconds: 800), () {
          if (!mounted || _connected) return;
          setState(() => _visible = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _showTimer?.cancel();
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
