import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../theme/density.dart';
import 'call_button.dart' show CallGlyphButton;
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
    required this.kind,
  });

  final String roomId;

  /// Matches the room header style: plain icon (classic header) vs a
  /// LiquidGlass circle (liquid header).
  final bool liquid;

  /// Which kind this button is for: it wears that icon and opens the sheet
  /// with that chip preselected. Both headers mount one of each, video then
  /// voice.
  final CallMediaKind kind;

  void _open(BuildContext context) {
    final service = GroupCallService.maybeInstance;
    final me = service?.userId;
    if (service == null || me == null) return;
    HapticFeedback.lightImpact();
    showStartGroupCallSheet(
      context,
      service: service,
      api: ChatApi(ConvexBackend.instance),
      roomId: roomId,
      myUserId: me,
      initialKind: kind,
    );
  }

  /// What a tap on this button does, for a caller with no button to tap: the
  /// room's ⌥⌘A / ⌥⌘V. Inert while a call is already up, like the button.
  void activate(BuildContext context) {
    final busy = (GroupCallService.maybeInstance?.inCall ?? false) ||
        (CallService.maybeInstance?.inCall ?? false);
    if (!busy) _open(context);
  }

  @override
  Widget build(BuildContext context) {
    final service = GroupCallService.maybeInstance;
    final busy = (service?.inCall ?? false) ||
        (CallService.maybeInstance?.inCall ?? false);
    // The same button the one-to-one header wears — see [CallGlyphButton].
    // 44pt to match the liquid header's own back button and capsule
    // (room_screen `_controlSize`); classic follows Density.
    return CallGlyphButton(
      kind: kind,
      enabled: !busy,
      onTap: busy ? null : () => _open(context),
      size: liquid ? 44 : Density.of(context).iconButton,
    );
  }
}
