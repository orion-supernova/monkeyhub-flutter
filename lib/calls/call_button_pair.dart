import 'package:flutter/widgets.dart';

import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/foundation/ui_kit.dart' show FlutterSkinsOnly;
import '../ui/native/native_control.dart';
import 'call_button.dart';
import 'call_models.dart';
import 'call_service.dart';
import 'group_call_button.dart';
import 'group_call_service.dart';

/// The header's video + voice call buttons as one unit.
///
/// In the liquid kit on iOS 26 the two are separate glass discs in one native
/// `GlassEffectContainer`, 6 pt apart and blending into a single shape like
/// the discs of a system toolbar. Everywhere else (and while a call is up,
/// when each button dims and explains itself on tap) it is the two ordinary
/// [CallButton] / [GroupCallButton] buttons in a row, exactly as before.
class CallButtonPair extends StatelessWidget {
  /// Calls the one person in a DM.
  const CallButtonPair.direct({
    super.key,
    required String this.peerUserId,
    required String this.peerName,
    required this.roomId,
    this.peerAvatarStorageId,
    this.gap = 6,
  });

  /// Calls a group room.
  const CallButtonPair.group({super.key, required this.roomId, this.gap = 6})
    : peerUserId = null,
      peerName = null,
      peerAvatarStorageId = null;

  final String? peerUserId;
  final String? peerName;
  final String? peerAvatarStorageId;
  final String roomId;
  final double gap;

  bool get _direct => peerUserId != null;

  Widget _button(CallMediaKind kind) => _direct
      ? CallButton(
          peerUserId: peerUserId!,
          peerName: peerName!,
          peerAvatarStorageId: peerAvatarStorageId,
          roomId: roomId,
          variant: CallButtonVariant.liquid,
          kind: kind,
        )
      : GroupCallButton(roomId: roomId, liquid: true, kind: kind);

  void _activate(BuildContext context, CallMediaKind kind) {
    final button = _button(kind);
    if (button is CallButton) {
      button.activate(context);
    } else if (button is GroupCallButton) {
      button.activate(context);
    }
  }

  bool get _busy =>
      CallService.instance.inCall ||
      CallService.instance.busyElsewhere ||
      (!_direct && (GroupCallService.maybeInstance?.inCall ?? false));

  @override
  Widget build(BuildContext context) {
    if (FamilyService.maybeInstance?.canCall == false) {
      return const SizedBox.shrink();
    }
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(CallMediaKind.video),
        SizedBox(width: gap),
        _button(CallMediaKind.audio),
      ],
    );
    if (!NativeControl.readyIn(context)) return row;
    final service = CallService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        service,
        ?GroupCallService.maybeInstance,
      ]),
      builder: (context, _) {
        if (_busy) return row;
        final l10n = AppLocalizations.of(context);
        return NativeControl(
          standIn: FlutterSkinsOnly(child: Builder(builder: build)),
          size: Size(44 * 2 + gap, 44),
          spec: NativeSpec.toolbar(
            options: [
              NativeOptionSpec(
                value: 'video',
                label: l10n.callButtonVideoCallTooltip,
                symbol: 'video',
              ),
              NativeOptionSpec(
                value: 'audio',
                label: l10n.callButtonVoiceCallTooltip,
                symbol: 'phone',
              ),
            ],
            spacing: gap,
            // Two discs apart at rest (the user found them "touching"); the
            // glass still flows between them while one is pressed.
            blend: 0,
          ),
          onEvent: (event, value) {
            if (event != 'select') return;
            _activate(
              context,
              value == 'video' ? CallMediaKind.video : CallMediaKind.audio,
            );
          },
        );
      },
    );
  }
}
