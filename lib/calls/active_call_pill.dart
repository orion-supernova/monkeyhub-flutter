import 'package:flutter/material.dart';

import '../backend/call_api.dart';
import '../backend/convex_client.dart';
import '../theme/theme_scope.dart';
import 'call_service.dart';

/// Global premium-feel pill rendered at the top of every screen when there
/// is an active call on ANOTHER of my devices. Tap to transfer the call to
/// this device. See `lib/calls/call_service.dart#handoffToHere`.
class ActiveCallPill extends StatefulWidget {
  const ActiveCallPill({
    super.key,
    required this.api,
    required this.service,
  });
  final CallApi api;
  final CallService service;

  @override
  State<ActiveCallPill> createState() => _ActiveCallPillState();
}

class _ActiveCallPillState extends State<ActiveCallPill> {
  Subscription? _sub;
  String? _subscribedUserId;
  Map<String, dynamic>? _activeCall;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
    // Initial bind — CallService may already have a userId attached.
    _resubscribeIfNeeded();
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _sub?.cancel();
    super.dispose();
  }

  void _onServiceChanged() {
    // Either userId changed (login/logout) or local session changed
    // (started/ended a call here). Both can affect visibility.
    _resubscribeIfNeeded();
    if (mounted) setState(() {});
  }

  void _resubscribeIfNeeded() {
    final uid = widget.service.userId;
    if (uid == _subscribedUserId) return;
    _sub?.cancel();
    _sub = null;
    _subscribedUserId = uid;
    _activeCall = null;
    if (uid == null) return;
    // Fire-and-forget; the callback handles state updates.
    widget.api
        .subscribeActiveCall(
      userId: uid,
      onCall: (call) {
        if (!mounted) return;
        setState(() => _activeCall = call);
      },
      onError: (e) => debugPrint('ActiveCallPill subscribe error: $e'),
    )
        .then((s) {
      if (!mounted) {
        s.cancel();
        return;
      }
      _sub = s;
    });
  }

  bool get _shouldShow {
    final call = _activeCall;
    if (call == null) return false;
    final status = call['status'] as String?;
    if (status != 'active') return false;
    final accDev = call['acceptingDeviceId'] as String?;
    final me = widget.service.deviceId;
    if (accDev == null || me == null) return false;
    if (accDev == me) return false;
    // If THIS device already has a session for this call (e.g., we're
    // mid-handoff onto ourselves), don't show.
    final sess = widget.service.session;
    final callId = call['_id']?.toString() ?? '';
    if (sess != null && sess.callId == callId) return false;
    return true;
  }

  Future<void> _moveHere() async {
    if (_busy) return;
    final call = _activeCall;
    if (call == null) return;
    _busy = true;
    // Mark accepted-natively so _CallOverlay routes to CallScreen (not
    // IncomingCallScreen) when the new session appears.
    widget.service.markAcceptedNatively();
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
    final visible = _shouldShow;
    final call = _activeCall;
    final peerName = (call?['peerName'] as String?) ?? 'Unknown';
    final deviceName = (call?['acceptingDeviceName'] as String?);
    final platform = (call?['acceptingPlatform'] as String?);
    final label = (deviceName != null && deviceName.isNotEmpty)
        ? deviceName
        : _platformFallback(platform);
    final type = (call?['type'] as String?) ?? 'audio';
    final isVideo = type == 'video';

    // Reserve no space when hidden — AnimatedSlide animates the offset but
    // we wrap in an IgnorePointer so taps don't fall on an invisible widget.
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, -1.6),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(theme.radiusLg),
                  onTap: _moveHere,
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(theme.radiusLg),
                      gradient: LinearGradient(
                        colors: [
                          theme.accent,
                          theme.accentSoft,
                        ],
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
                                  'Call with $peerName',
                                  style: theme.body.copyWith(
                                    color: theme.accentInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'On $label',
                                  style: theme.monoTiny.copyWith(
                                    color: theme.accentInk
                                        .withValues(alpha: 0.82),
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
                              color:
                                  theme.accentInk.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Move here',
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
      ),
    );
  }

  String _platformFallback(String? platform) {
    switch (platform) {
      case 'ios':
        return 'iPhone';
      case 'ios-simulator':
        return 'iOS Simulator';
      case 'android':
        return 'Android device';
      case 'macos':
        return 'Mac';
      case 'windows':
        return 'Windows PC';
      case 'linux':
        return 'Linux device';
      case 'web':
        return 'Browser';
      default:
        return 'another device';
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
