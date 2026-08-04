import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'call_service.dart';

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
          : Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  // Bare GestureDetector, never InkWell — this app's tappables
                  // register no ink and no ripple (see FocusableTap's doc).
                  child: FocusableTap(
                    onTap: _moveHere,
                    radius: theme.radiusLg,
                    semanticLabel: l10n.activeCallPillMoveHereSemanticLabel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _moveHere,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(theme.radiusLg),
                          gradient: LinearGradient(
                            colors: [theme.accent, theme.accentSoft],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accent.withValues(alpha: 0.32),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              _LiveDot(color: theme.accentInk),
                              const SizedBox(width: 10),
                              Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                size: 18,
                                color: theme.accentInk,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.activeCallPillCallWith(peerName),
                                      style: theme.body.copyWith(
                                        color: theme.accentInk,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      l10n.activeCallPillOnDevice(label),
                                      style: theme.monoTiny.copyWith(
                                        color: theme.accentInk.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.accentInk.withValues(
                                    alpha: 0.20,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.activeCallPillMoveHereLabel,
                                      style: theme.monoTiny.copyWith(
                                        color: theme.accentInk,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 14,
                                      color: theme.accentInk,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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
