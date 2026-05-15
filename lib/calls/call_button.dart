import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import '../widgets/liquid_glass.dart';
import 'call_models.dart';
import 'call_service.dart';

enum CallButtonVariant { classic, liquid }

/// Header entry-point for starting a 1:1 call. Renders as a small icon next
/// to the room-info button; tapping reveals a popup with "Voice call" /
/// "Video call". DM-only — callers gate visibility on `room.isDm`.
class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.peerUserId,
    required this.peerName,
    required this.roomId,
    required this.variant,
  });

  final String peerUserId;
  final String peerName;
  final String roomId;
  final CallButtonVariant variant;

  Future<void> _start(BuildContext context, CallMediaKind kind) async {
    final service = CallService.instance;
    if (service.inCall) return;
    try {
      await service.initiate(
        peerUserId: peerUserId,
        peerName: peerName,
        roomId: roomId,
        kind: kind,
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = _friendlyError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('BUSY')) return 'busy on another call';
    if (s.contains('CALL_FAILED')) return 'could not start call';
    if (s.contains('NOT_A_MEMBER')) return 'not a member of this room';
    return 'could not start call';
  }

  void _showMenuAt(
    BuildContext context,
    RelativeRect position,
  ) async {
    final theme = ThemeScope.of(context);
    final selected = await showMenu<CallMediaKind>(
      context: context,
      position: position,
      color: theme.surfaceRaised,
      items: [
        PopupMenuItem(
          value: CallMediaKind.audio,
          child: Row(
            children: [
              Icon(Icons.call, size: 16, color: theme.ink),
              const SizedBox(width: 10),
              Text('voice call', style: theme.body),
            ],
          ),
        ),
        PopupMenuItem(
          value: CallMediaKind.video,
          child: Row(
            children: [
              Icon(Icons.videocam, size: 16, color: theme.ink),
              const SizedBox(width: 10),
              Text('video call', style: theme.body),
            ],
          ),
        ),
      ],
    );
    if (selected != null && context.mounted) {
      await _start(context, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case CallButtonVariant.classic:
        return _ClassicCallButton(onPick: (k) => _start(context, k));
      case CallButtonVariant.liquid:
        return _LiquidCallButton(onTrigger: (pos) => _showMenuAt(context, pos));
    }
  }
}

class _ClassicCallButton extends StatelessWidget {
  const _ClassicCallButton({required this.onPick});
  final ValueChanged<CallMediaKind> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return PopupMenuButton<CallMediaKind>(
      tooltip: 'call',
      padding: EdgeInsets.zero,
      iconSize: 18,
      color: theme.surfaceRaised,
      icon: Icon(Icons.call_outlined, color: theme.inkSoft, size: 18),
      onSelected: onPick,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: CallMediaKind.audio,
          child: Row(
            children: [
              Icon(Icons.call, size: 16, color: theme.ink),
              const SizedBox(width: 10),
              Text('voice call', style: theme.body),
            ],
          ),
        ),
        PopupMenuItem(
          value: CallMediaKind.video,
          child: Row(
            children: [
              Icon(Icons.videocam, size: 16, color: theme.ink),
              const SizedBox(width: 10),
              Text('video call', style: theme.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiquidCallButton extends StatelessWidget {
  const _LiquidCallButton({required this.onTrigger});
  final ValueChanged<RelativeRect> onTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final key = GlobalKey();
    return LiquidGlass(
      key: key,
      shape: LiquidGlassShape.circle,
      size: const Size(44, 44),
      onTap: () {
        final ctx = key.currentContext;
        if (ctx == null) return;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null) return;
        final overlay =
            Overlay.of(ctx).context.findRenderObject() as RenderBox?;
        if (overlay == null) return;
        final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
        final size = box.size;
        final pos = RelativeRect.fromLTRB(
          origin.dx,
          origin.dy + size.height + 4,
          overlay.size.width - origin.dx - size.width,
          0,
        );
        onTrigger(pos);
      },
      child: Icon(Icons.call_outlined, size: 18, color: theme.accent),
    );
  }
}
