import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import '../widgets/liquid_glass.dart';
import 'call_models.dart';
import 'call_picker.dart';
import 'call_service.dart';

enum CallButtonVariant { classic, liquid }

/// Header entry-point for starting a 1:1 call. Renders as a small icon next
/// to the room-info button; tapping reveals a frosted popover with
/// "Voice call" / "Video call". DM-only — callers gate visibility on
/// `room.isDm`.
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

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case CallButtonVariant.classic:
        return _ClassicCallButton(onPick: (k) => _start(context, k));
      case CallButtonVariant.liquid:
        return _LiquidCallButton(onPick: (k) => _start(context, k));
    }
  }
}

class _ClassicCallButton extends StatefulWidget {
  const _ClassicCallButton({required this.onPick});
  final ValueChanged<CallMediaKind> onPick;

  @override
  State<_ClassicCallButton> createState() => _ClassicCallButtonState();
}

class _ClassicCallButtonState extends State<_ClassicCallButton> {
  // Stable across rebuilds — the room screen rebuilds frequently. A
  // GlobalKey constructed inside build() would make Flutter treat the
  // anchor as a new widget every frame, breaking gesture recognition
  // and the picker's RenderBox lookup.
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _handleTap() async {
    final picked = await showCallPicker(context: context, anchorKey: _anchorKey);
    if (picked != null) widget.onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return IconButton(
      key: _anchorKey,
      tooltip: 'call',
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: Icon(Icons.call_outlined, color: theme.inkSoft, size: 18),
      onPressed: _handleTap,
    );
  }
}

class _LiquidCallButton extends StatefulWidget {
  const _LiquidCallButton({required this.onPick});
  final ValueChanged<CallMediaKind> onPick;

  @override
  State<_LiquidCallButton> createState() => _LiquidCallButtonState();
}

class _LiquidCallButtonState extends State<_LiquidCallButton> {
  // Stable across rebuilds — the room screen rebuilds frequently (stream
  // updates, typing, scroll tracking); a GlobalKey constructed inside build()
  // would make Flutter treat the LiquidGlass as a new widget every frame,
  // unmounting it mid-tap and breaking gesture recognition.
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _handleTap() async {
    final picked = await showCallPicker(context: context, anchorKey: _anchorKey);
    if (picked != null) widget.onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return LiquidGlass(
      key: _anchorKey,
      shape: LiquidGlassShape.circle,
      size: const Size(44, 44),
      onTap: _handleTap,
      child: Icon(Icons.call_outlined, size: 18, color: theme.accent),
    );
  }
}
