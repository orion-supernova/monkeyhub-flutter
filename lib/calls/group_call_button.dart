import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/liquid_glass.dart';
import 'call_models.dart';
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
    this.kind,
  });

  final String roomId;

  /// Matches the room header style: plain icon (classic header) vs a
  /// LiquidGlass circle (liquid header).
  final bool liquid;

  /// Which kind this button is for: it wears that icon and opens the sheet
  /// with that chip preselected. Null is the generic "call" button, which
  /// leaves the sheet on its own default.
  final CallMediaKind? kind;

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
      initialKind: kind ?? CallMediaKind.audio,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final service = GroupCallService.maybeInstance;
    final busy = (service?.inCall ?? false) ||
        (CallService.maybeInstance?.inCall ?? false);
    final icon = kind == CallMediaKind.video ? Icons.videocam : Icons.call;
    final tooltip = switch (kind) {
      CallMediaKind.audio => l10n.callButtonVoiceCallTooltip,
      CallMediaKind.video => l10n.callButtonVideoCallTooltip,
      null => l10n.callButtonTooltip,
    };
    if (liquid) {
      return Tooltip(
        message: tooltip,
        child: LiquidGlass(
          shape: LiquidGlassShape.circle,
          size: const Size(44, 44),
          onTap: busy ? null : () => _open(context),
          child: Icon(
            icon,
            size: 18,
            color: busy ? theme.inkMuted : theme.accent,
          ),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: busy ? null : () => _open(context),
      icon: Icon(
        icon,
        color: busy ? theme.inkMuted : theme.inkSoft,
        size: 18,
      ),
    );
  }
}
