import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'call_service.dart';
import 'widgets/call_chrome.dart';

/// Global premium-feel pill rendered at the top of every screen when there
/// is an active call on ANOTHER of my devices. Tap to transfer the call to
/// this device. See `lib/calls/call_service.dart#handoffToHere`.
///
/// Reads the cross-device active call from [CallService.activeCallElsewhere]
/// (the single source of truth) rather than holding its own subscription, so
/// it can never show a call this device just ended.
class ActiveCallPill extends StatefulWidget {
  const ActiveCallPill({super.key, required this.service});
  final CallService service;

  @override
  State<ActiveCallPill> createState() => _ActiveCallPillState();
}

class _ActiveCallPillState extends State<ActiveCallPill> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    // CallService owns the cross-device active-call subscription now
    // (activeCallElsewhere / busyElsewhere), so any change to it — or to the
    // local session — arrives through this listener. Just rebuild.
    if (mounted) setState(() {});
  }

  Future<void> _moveHere() async {
    if (_busy) return;
    final call = widget.service.activeCallElsewhere;
    if (call == null) return;
    _busy = true;
    // Mark accepted-natively so _CallOverlay routes to CallScreen (not
    // IncomingCallScreen) when the new session appears.
    widget.service.markAcceptedNatively(callId: call['_id']?.toString());
    try {
      await widget.service.handoffToHere(call);
    } catch (e) {
      debugPrint('ActiveCallPill._moveHere failed: $e');
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final call = widget.service.activeCallElsewhere;
    final visible = call != null;
    final peerName =
        (call?['peerName'] as String?) ?? l10n.activeCallPillUnknownCaller;
    final deviceName = (call?['acceptingDeviceName'] as String?);
    final platform = (call?['acceptingPlatform'] as String?);
    final label = (deviceName != null && deviceName.isNotEmpty)
        ? deviceName
        : _platformFallback(context, platform);
    final type = (call?['type'] as String?) ?? 'audio';
    final isVideo = type == 'video';

    // Genuinely occupy no space when hidden: this pill shares a Column with
    // ConnectionBanner, so a translated-but-still-laid-out pill (the previous
    // AnimatedSlide) would offset whatever sits above it.
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity, height: 0)
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                // The whole banner is the target; "Move here" is its label.
                child: CallStatusBanner(
                  onTap: _moveHere,
                  semanticLabel: l10n.activeCallPillMoveHereSemanticLabel,
                  leading: _LiveDot(color: theme.accentInk),
                  icon: isVideo ? CallGlyphs.camera : CallGlyphs.voice,
                  title: l10n.activeCallPillCallWith(peerName),
                  meta: Text(l10n.activeCallPillOnDevice(label)),
                  actions: [
                    CallBannerAction(
                      icon: CallGlyphs.moveHere,
                      label: l10n.activeCallPillMoveHereLabel,
                      semanticLabel: l10n.activeCallPillMoveHereSemanticLabel,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _platformFallback(BuildContext context, String? platform) {
    final l10n = AppLocalizations.of(context);
    switch (platform) {
      case 'ios':
        return l10n.activeCallPillPlatformIphone;
      case 'ios-simulator':
        return l10n.activeCallPillPlatformIosSimulator;
      case 'android':
        return l10n.activeCallPillPlatformAndroid;
      case 'macos':
        return l10n.activeCallPillPlatformMac;
      case 'windows':
        return l10n.activeCallPillPlatformWindows;
      case 'linux':
        return l10n.activeCallPillPlatformLinux;
      case 'web':
        return l10n.activeCallPillPlatformBrowser;
      default:
        return l10n.activeCallPillPlatformOther;
    }
  }
}

/// Tiny pulsing dot that signals "live" — purely decorative.
class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});
  final Color color;
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.55 + 0.45 * t),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * (1 - t)),
                blurRadius: 6 + 4 * t,
                spreadRadius: 1 + t,
              ),
            ],
          ),
        );
      },
    );
  }
}
