import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
import 'group_call_service.dart';

/// Full-screen UI for an active mesh group call: a tile per participant
/// (video when available, avatar otherwise), glass control tray, and a
/// reconnecting chip when any link is recovering. Pops itself when the
/// service leaves the call.
class GroupCallScreen extends StatefulWidget {
  const GroupCallScreen({super.key, required this.service, this.api});
  final GroupCallService service;
  final ChatApi? api;

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final Map<String, RTCVideoRenderer> _renderers = {};
  final Map<String, int> _boundTicks = {};
  RTCVideoRenderer? _localRenderer;
  bool _popScheduled = false;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onChanged);
    if (widget.service.mediaKind == CallMediaKind.video) {
      _ensureLocalRenderer();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _ensureLocalRenderer() async {
    if (_localRenderer != null) return;
    final r = RTCVideoRenderer();
    _localRenderer = r;
    await r.initialize();
    if (!mounted) return;
    r.srcObject = widget.service.localStream;
    setState(() {});
  }

  Future<void> _ensureRenderer(
    String userId,
    MediaStream stream,
    int tick,
  ) async {
    var r = _renderers[userId];
    if (r == null) {
      r = RTCVideoRenderer();
      _renderers[userId] = r;
      await r.initialize();
      if (!mounted) return;
    }
    if (_boundTicks[userId] != tick || r.srcObject != stream) {
      r.srcObject = stream;
      _boundTicks[userId] = tick;
    }
  }

  void _onChanged() {
    if (!mounted) return;
    final svc = widget.service;
    if (!svc.inCall) {
      if (!_popScheduled) {
        _popScheduled = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
      setState(() {});
      return;
    }
    // Bind/refresh renderers for peers with live streams.
    for (final peer in svc.peers.values) {
      final stream = peer.remoteStream;
      if (stream != null) {
        unawaited(_ensureRenderer(peer.userId, stream, peer.remoteStreamTick));
      }
    }
    final localR = _localRenderer;
    if (localR != null && localR.srcObject != svc.localStream) {
      localR.srcObject = svc.localStream;
    }
    // Drop renderers for peers that left.
    final gone = _renderers.keys
        .where((k) => !svc.peers.containsKey(k))
        .toList(growable: false);
    for (final k in gone) {
      final r = _renderers.remove(k);
      _boundTicks.remove(k);
      if (r != null) {
        r.srcObject = null;
        r.dispose();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    for (final r in _renderers.values) {
      r.srcObject = null;
      r.dispose();
    }
    _localRenderer?.srcObject = null;
    _localRenderer?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  ChatUser _asUser(String id, String name, String? avatarStorageId) => ChatUser(
    id: id,
    username: '',
    name: name,
    avatarStorageId: avatarStorageId,
  );

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final svc = widget.service;
    final peers = svc.peers.values.toList(growable: false);
    final anyReconnecting = peers.any((p) => p.reconnecting);
    final isVideo = svc.mediaKind == CallMediaKind.video;
    final tileCount = peers.length + 1; // + me
    final columns = tileCount <= 1
        ? 1
        : tileCount <= 4
        ? 2
        : 3;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isVideo
                                ? AppLocalizations.of(context)
                                      .groupCallScreenTitleVideo
                                : AppLocalizations.of(context)
                                      .groupCallScreenTitleVoice,
                            style: theme.displaySmall.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            AppLocalizations.of(
                              context,
                            ).groupCallScreenParticipantCount(tileCount),
                            style: theme.monoTiny.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (anyReconnecting)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: _chip(
                        theme,
                        AppLocalizations.of(context).groupCallScreenReconnecting,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: GridView.count(
                        crossAxisCount: columns,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3 / 4,
                        children: [
                          _localTile(theme),
                          for (final peer in peers) _peerTile(theme, peer),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _control(
                              icon: svc.localMuted ? Icons.mic_off : Icons.mic,
                              active: svc.localMuted,
                              label: svc.localMuted
                                  ? AppLocalizations.of(
                                      context,
                                    ).groupCallScreenUnmuteLabel
                                  : AppLocalizations.of(
                                      context,
                                    ).groupCallScreenMuteLabel,
                              onTap: svc.toggleMute,
                            ),
                            if (isVideo)
                              _control(
                                icon: svc.localVideoOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                active: svc.localVideoOff,
                                label: svc.localVideoOff
                                    ? AppLocalizations.of(
                                        context,
                                      ).groupCallScreenCamOnLabel
                                    : AppLocalizations.of(
                                        context,
                                      ).groupCallScreenCamOffLabel,
                                onTap: svc.toggleVideo,
                              ),
                            if (isVideo)
                              _control(
                                icon: Icons.cameraswitch_outlined,
                                label: AppLocalizations.of(
                                  context,
                                ).groupCallScreenFlipLabel,
                                onTap: svc.switchCamera,
                              ),
                            _control(
                              icon: svc.speakerOn
                                  ? Icons.volume_up
                                  : Icons.phone_in_talk,
                              active: svc.speakerOn,
                              label: AppLocalizations.of(
                                context,
                              ).groupCallScreenSpeakerLabel,
                              onTap: svc.toggleSpeaker,
                            ),
                            _control(
                              icon: Icons.call_end,
                              label: AppLocalizations.of(
                                context,
                              ).groupCallScreenLeaveLabel,
                              background: theme.danger,
                              iconColor: Colors.white,
                              large: true,
                              onTap: () => unawaited(svc.leaveCall()),
                            ),
                          ],
                        ),
                      ),
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

  Widget _chip(dynamic theme, String label) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.monoTiny.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _localTile(dynamic theme) {
    final svc = widget.service;
    final showVideo =
        svc.mediaKind == CallMediaKind.video &&
        !svc.localVideoOff &&
        _localRenderer != null &&
        svc.localStream != null;
    return _TileFrame(
      label: AppLocalizations.of(context).groupCallScreenYouLabel,
      muted: svc.localMuted,
      child: showVideo
          ? RTCVideoView(
              _localRenderer!,
              mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          : null,
    );
  }

  Widget _peerTile(dynamic theme, GroupPeer peer) {
    final renderer = _renderers[peer.userId];
    final showVideo =
        widget.service.mediaKind == CallMediaKind.video &&
        peer.remoteStream != null &&
        renderer != null &&
        !peer.mediaState.videoOff;
    return _TileFrame(
      label: peer.name,
      muted: peer.mediaState.audioMuted,
      dimmed: !peer.connected || peer.reconnecting,
      child: showVideo
          ? RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          : Center(
              child: UserAvatar(
                user: _asUser(peer.userId, peer.name, peer.avatarStorageId),
                api: widget.api,
                size: 72,
                showStatus: false,
              ),
            ),
    );
  }

  Widget _control({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Color? background,
    Color? iconColor,
    bool large = false,
  }) {
    final size = large ? 64.0 : 52.0;
    final bg =
        background ??
        (active
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.18));
    final fg = iconColor ?? (active ? Colors.black : Colors.white);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusableTap(
          onTap: onTap,
          semanticLabel: label,
          shape: FocusRingShape.circle,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: large ? 30 : 22),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}

class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.label,
    this.child,
    this.muted = false,
    this.dimmed = false,
  });
  final String label;
  final Widget? child;
  final bool muted;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF17181C)),
          ?child,
          if (dimmed) Container(color: Colors.black.withValues(alpha: 0.45)),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                if (muted) ...[
                  const Icon(Icons.mic_off, size: 12, color: Colors.white70),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
