import 'dart:async';

import 'package:flutter/material.dart';

import '../backend/convex_client.dart';
import '../backend/group_call_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'group_call_service.dart';

/// "Ongoing call" banner for a room: green pulse + who's in + a Join pill.
/// Renders nothing when no call is active in the room, or when this device
/// is already in it. Collapses to zero height, so it can sit permanently
/// in the room layout.
class GroupCallBanner extends StatefulWidget {
  const GroupCallBanner({
    super.key,
    required this.api,
    required this.service,
    required this.roomId,
    required this.userId,
  });

  final GroupCallApi api;
  final GroupCallService service;
  final String roomId;
  final String userId;

  @override
  State<GroupCallBanner> createState() => _GroupCallBannerState();
}

class _GroupCallBannerState extends State<GroupCallBanner>
    with SingleTickerProviderStateMixin {
  Subscription? _sub;
  Map<String, dynamic>? _call;
  // Created on first paint, not on mount: this banner sits in every room's
  // layout permanently and collapses to nothing whenever there's no call, so
  // an eager controller would run a repeating ticker in every open room for a
  // call that isn't happening.
  //
  // Nullable and not `late final … = AnimationController(…)`. With a lazy
  // initializer, a banner that never showed reaches dispose having never been
  // touched — making `_pulse.dispose()` the *first* access, which builds an
  // AnimationController during unmount. `createTicker` looks up its TickerMode
  // ancestor, and that lookup is illegal on a deactivated element: closing any
  // room with no active call in it threw.
  AnimationController? _pulseCtrl;

  AnimationController get _pulse => _pulseCtrl ??= AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onService);
    _subscribe();
  }

  void _onService() {
    if (mounted) setState(() {});
  }

  void _subscribe() {
    unawaited(
      widget.api
          .subscribeActiveForRoom(
            roomId: widget.roomId,
            userId: widget.userId,
            onCall: (call) {
              if (!mounted) return;
              setState(() => _call = call);
            },
            onError: (e) => debugPrint('GroupCallBanner: $e'),
          )
          .then((s) {
            if (!mounted) {
              s.cancel();
              return;
            }
            _sub = s;
          }),
    );
  }

  @override
  void dispose() {
    widget.service.removeListener(_onService);
    _sub?.cancel();
    // Deliberately not `_pulse` — see the field. Nothing to dispose when the
    // banner never had a call to show.
    _pulseCtrl?.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final call = _call;
    if (call == null) return;
    try {
      await widget.service.joinCall(call['groupCallId'].toString());
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('CALL_FULL')
          ? AppLocalizations.of(context).groupCallBannerCallFullError
          : AppLocalizations.of(context).groupCallBannerJoinFailedError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = _call;
    final svc = widget.service;
    // Hidden: no call, or we're already in this room's call.
    if (call == null ||
        (svc.inCall && svc.groupCallId == call['groupCallId'].toString())) {
      return const SizedBox.shrink();
    }
    final theme = ThemeScope.of(context);
    final parts = ((call['participants'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        // Only heartbeating participants count — a joined row whose app
        // died must not advertise a call nobody is in. Missing `live`
        // (older backend) is treated as live.
        .where((p) => p['status'] == 'joined' && (p['live'] ?? true) == true)
        .toList(growable: false);
    if (parts.isEmpty) return const SizedBox.shrink();
    final someone = AppLocalizations.of(
      context,
    ).groupCallBannerUnknownParticipant;
    final names = parts
        .map((p) => p['name']?.toString() ?? someone)
        .take(2)
        .join(', ');
    final extra = parts.length > 2 ? ' +${parts.length - 2}' : '';
    final isVideo = call['type'] == 'video';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        // Opaque themed card — a translucent green wash reads as a glitch on
        // dark themes. Green stays on the pulse icon and the JOIN pill only.
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.divider),
        ),
        child: Row(
          children: [
            FadeTransition(
              opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
              child: Icon(
                isVideo ? Icons.videocam : Icons.call,
                size: 18,
                color: const Color(0xFF17C964),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVideo
                        ? AppLocalizations.of(
                            context,
                          ).groupCallBannerOngoingVideoCall
                        : AppLocalizations.of(
                            context,
                          ).groupCallBannerOngoingVoiceCall,
                    style: theme.body.copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).groupCallBannerParticipantsInCall(extra, names),
                    style: theme.monoTiny.copyWith(color: theme.inkMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FocusableTap(
              onTap: svc.inCall ? null : _join,
              enabled: !svc.inCall,
              semanticLabel: AppLocalizations.of(
                context,
              ).groupCallBannerJoinCallSemanticLabel,
              shape: FocusRingShape.capsule,
              child: GestureDetector(
                onTap: svc.inCall ? null : _join,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17C964),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    AppLocalizations.of(context).groupCallBannerJoinButtonLabel,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
