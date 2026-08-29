import 'package:flutter/material.dart';

import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/liquid_glass.dart';
import 'call_models.dart';
import 'call_picker.dart';
import 'call_service.dart';

enum CallButtonVariant { classic, liquid }

/// Header width from which both call kinds are shown side by side instead of
/// behind a picker. Measured against the CHAT PANE, not the window: in the
/// two-pane desktop shell the header only owns the detail pane, and a 1024px
/// window leaves it about 580.
const double _kSideBySideCallsFrom = 520;

/// Header entry-point for starting a 1:1 call. DM-only — callers gate
/// visibility on `room.isDm`.
///
/// On a narrow header this is one icon that opens a frosted popover with
/// "Voice call" / "Video call". Where there is room for them, both kinds get
/// their own button instead: the popover exists to buy horizontal space, and
/// when space isn't scarce it is just an extra tap in front of the two things
/// it was hiding.
///
/// Reflects call state live: while a call is active on THIS device
/// ([CallService.inCall]) or ANOTHER of the user's devices
/// ([CallService.busyElsewhere]) the button is visibly disabled and a tap
/// explains why instead of starting a second call. Listens to [CallService]
/// (a [ChangeNotifier]) so the state is always current.
class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.peerUserId,
    required this.peerName,
    required this.roomId,
    required this.variant,
    this.kind,
  });

  final String peerUserId;
  final String peerName;
  final String roomId;
  final CallButtonVariant variant;

  /// Starts this kind directly, as a single button, whatever the pane width.
  /// Null keeps the width-adaptive layout described above: a picker on a
  /// narrow header, both kinds side by side on a wide one.
  final CallMediaKind? kind;

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
      final msg = _friendlyError(context, e);
      showAppToast(context, msg, duration: const Duration(seconds: 3));
    }
  }

  String _friendlyError(BuildContext context, Object e) {
    final l10n = AppLocalizations.of(context);
    final s = e.toString();
    if (s.contains('BUSY')) return l10n.callButtonErrorBusy;
    if (s.contains('CALL_FAILED')) return l10n.callButtonErrorCallFailed;
    if (s.contains('NOT_A_MEMBER')) return l10n.callButtonErrorNotMember;
    return l10n.callButtonErrorGeneric;
  }

  /// Why the button is disabled right now (null when it's tappable).
  String? _busyReason(BuildContext context, CallService service) {
    final l10n = AppLocalizations.of(context);
    if (service.inCall) return l10n.callButtonAlreadyOnCall;
    if (service.busyElsewhere) return l10n.callButtonBusyElsewhere;
    return null;
  }

  void _showBusy(BuildContext context, String reason) {
    showAppToast(context, reason, duration: const Duration(seconds: 3));
  }

  @override
  Widget build(BuildContext context) {
    // Calls can be switched off for a child. Hide rather than disable — the
    // backend refuses either way, and a dead button just invites tapping.
    // Null (not yet resolved) reads as unrestricted, which is right for the
    // adult case and harmless for a child since `calls.initiate` still gates.
    if (FamilyService.maybeInstance?.canCall == false) {
      return const SizedBox.shrink();
    }
    final service = CallService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final busyReason = _busyReason(context, service);
        final enabled = busyReason == null;
        void onDisabledTap() => _showBusy(context, busyReason!);

        Widget button(CallMediaKind? kind) {
          switch (variant) {
            case CallButtonVariant.classic:
              return _ClassicCallButton(
                kind: kind,
                enabled: enabled,
                onPick: (k) => _start(context, k),
                onDisabledTap: onDisabledTap,
              );
            case CallButtonVariant.liquid:
              return _LiquidCallButton(
                kind: kind,
                enabled: enabled,
                onPick: (k) => _start(context, k),
                onDisabledTap: onDisabledTap,
              );
          }
        }

        final kind = this.kind;
        if (kind != null) return button(kind);
        final roomy = ChatMetricsScope.of(context).paneWidth >=
            _kSideBySideCallsFrom;
        if (!roomy) return button(null);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(CallMediaKind.audio),
            // The classic variant's IconButtons carry their own 48px hit box,
            // so they space themselves; the liquid circles need the same 12
            // the header uses between its other controls.
            if (variant == CallButtonVariant.liquid) const SizedBox(width: 12),
            button(CallMediaKind.video),
          ],
        );
      },
    );
  }
}

/// Icon + tooltip for a direct button; null [kind] is the picker button.
({IconData icon, String tooltip}) _face(BuildContext context, CallMediaKind? kind) {
  final l10n = AppLocalizations.of(context);
  return switch (kind) {
    CallMediaKind.audio => (
        icon: Icons.call_outlined,
        tooltip: l10n.callButtonVoiceCallTooltip
      ),
    CallMediaKind.video => (
        icon: Icons.videocam_outlined,
        tooltip: l10n.callButtonVideoCallTooltip
      ),
    null => (icon: Icons.call_outlined, tooltip: l10n.callButtonTooltip),
  };
}

class _ClassicCallButton extends StatefulWidget {
  const _ClassicCallButton({
    required this.kind,
    required this.onPick,
    required this.enabled,
    required this.onDisabledTap,
  });

  /// Starts this kind directly. Null opens the picker instead.
  final CallMediaKind? kind;
  final ValueChanged<CallMediaKind> onPick;
  final bool enabled;
  final VoidCallback onDisabledTap;

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
    if (!widget.enabled) {
      widget.onDisabledTap();
      return;
    }
    final kind = widget.kind;
    if (kind != null) {
      widget.onPick(kind);
      return;
    }
    final picked = await showCallPicker(context: context, anchorKey: _anchorKey);
    if (picked != null) widget.onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = widget.enabled
        ? theme.inkSoft
        : theme.inkSoft.withValues(alpha: 0.35);
    final face = _face(context, widget.kind);
    return IconButton(
      key: _anchorKey,
      tooltip: face.tooltip,
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: Icon(face.icon, color: color, size: 18),
      onPressed: _handleTap,
    );
  }
}

class _LiquidCallButton extends StatefulWidget {
  const _LiquidCallButton({
    required this.kind,
    required this.onPick,
    required this.enabled,
    required this.onDisabledTap,
  });

  /// Starts this kind directly. Null opens the picker instead.
  final CallMediaKind? kind;
  final ValueChanged<CallMediaKind> onPick;
  final bool enabled;
  final VoidCallback onDisabledTap;

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
    if (!widget.enabled) {
      widget.onDisabledTap();
      return;
    }
    final kind = widget.kind;
    if (kind != null) {
      widget.onPick(kind);
      return;
    }
    final picked = await showCallPicker(context: context, anchorKey: _anchorKey);
    if (picked != null) widget.onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = widget.enabled
        ? theme.accent
        : theme.accent.withValues(alpha: 0.35);
    final face = _face(context, widget.kind);
    return Tooltip(
      message: face.tooltip,
      child: LiquidGlass(
        key: _anchorKey,
        shape: LiquidGlassShape.circle,
        size: const Size(44, 44),
        onTap: _handleTap,
        child: Icon(face.icon, size: 18, color: color),
      ),
    );
  }
}
