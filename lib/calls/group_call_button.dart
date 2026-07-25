import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../theme/theme_scope.dart';
import '../widgets/liquid_glass.dart';
import 'call_service.dart';
import 'group_call_service.dart';
import 'group_call_sheets.dart';

/// Header entry point for group-room calls. Opens the start-call sheet
/// (voice/video × everyone/choose-people). Disabled while this device is
/// already in any call.
class GroupCallButton extends StatelessWidget {
  const GroupCallButton({
    super.key,
    required this.roomId,
    this.liquid = false,
  });

  final String roomId;

  /// Matches the room header style: plain icon (classic header) vs a
  /// LiquidGlass circle (liquid header).
  final bool liquid;

  void _open(BuildContext context) {
    final service = GroupCallService.maybeInstance;
    final me = service?.userId;
    if (service == null || me == null) return;
    showStartGroupCallSheet(
      context,
      service: service,
      api: ChatApi(ConvexBackend.instance),
      roomId: roomId,
      myUserId: me,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final service = GroupCallService.maybeInstance;
    final busy = (service?.inCall ?? false) ||
        (CallService.maybeInstance?.inCall ?? false);
    if (liquid) {
      return LiquidGlass(
        shape: LiquidGlassShape.circle,
        size: const Size(44, 44),
        onTap: busy ? null : () => _open(context),
        child: Icon(
          Icons.call,
          size: 18,
          color: busy ? theme.inkMuted : theme.accent,
        ),
      );
    }
    return IconButton(
      onPressed: busy ? null : () => _open(context),
      icon: Icon(
        Icons.call,
        color: busy ? theme.inkMuted : theme.inkSoft,
        size: 18,
      ),
    );
  }
}
