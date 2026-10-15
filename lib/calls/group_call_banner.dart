import 'dart:async';

import 'package:flutter/material.dart';

import '../backend/convex_client.dart';
import '../backend/group_call_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../widgets/app_toast.dart';
import 'group_call_service.dart';
import 'widgets/call_chrome.dart';
import '../backend/server_limits.dart';

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
      final l10n = AppLocalizations.of(context);
      final msg = e.toString().contains('CALL_FULL')
          ? l10n.groupCallBannerCallFullError
          : friendlyServerError(e, l10n, l10n.groupCallBannerJoinFailedError);
      showAppToast(context, msg);
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

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      // The shared call banner, neutral: a call you are not in yet. Green
      // stays on the pulsing glyph and the Join action only.
      child: CallStatusBanner(
        tone: CallBannerTone.neutral,
        icon: isVideo ? CallGlyphs.camera : CallGlyphs.voice,
        iconOpacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
        title: isVideo
            ? l10n.groupCallBannerOngoingVideoCall
            : l10n.groupCallBannerOngoingVoiceCall,
        meta: Text(l10n.groupCallBannerParticipantsInCall(extra, names)),
        actions: [
          CallBannerAction(
            icon: isVideo ? CallGlyphs.camera : CallGlyphs.voice,
            label: l10n.groupCallBannerJoinButtonLabel,
            semanticLabel: l10n.groupCallBannerJoinCallSemanticLabel,
            prominent: true,
            onTap: svc.inCall ? null : _join,
          ),
        ],
      ),
    );
  }
}
