import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/liquid_glass.dart';
import 'call_models.dart';
import 'call_service.dart';

enum CallButtonVariant { classic, liquid }

/// Header entry-point for starting a 1:1 call of one [kind]. DM-only —
/// callers gate visibility on `room.isDm`.
///
/// Both headers mount two of these side by side, video then voice, so a tap
/// starts that kind straight away. (There used to be a width-adaptive layout
/// — one picker icon on a narrow header, both kinds only where there was
/// room — but a picker is an extra tap in front of the two things it hides,
/// and the headers found the space by retiring their info buttons.)
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
    required this.kind,
  });

  final String peerUserId;
  final String peerName;
  final String roomId;
  final CallButtonVariant variant;
  final CallMediaKind kind;

  Future<void> _start(BuildContext context) async {
    final service = CallService.instance;
    if (service.inCall) return;
    HapticFeedback.mediumImpact();
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
        // A disabled button still answers a tap — with the reason, instead
        // of a second call.
        final VoidCallback onTap = busyReason == null
            ? () => _start(context)
            : () => _showBusy(context, busyReason);
        final enabled = busyReason == null;
        return switch (variant) {
          CallButtonVariant.classic =>
            _ClassicCallButton(kind: kind, enabled: enabled, onTap: onTap),
          CallButtonVariant.liquid =>
            _LiquidCallButton(kind: kind, enabled: enabled, onTap: onTap),
        };
      },
    );
  }
}

/// Icon + tooltip for a button of [kind].
({IconData icon, String tooltip}) _face(BuildContext context, CallMediaKind kind) {
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
  };
}

class _ClassicCallButton extends StatelessWidget {
  const _ClassicCallButton({
    required this.kind,
    required this.enabled,
    required this.onTap,
  });

  final CallMediaKind kind;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = enabled
        ? theme.inkSoft
        : theme.inkSoft.withValues(alpha: 0.35);
    final face = _face(context, kind);
    return IconButton(
      tooltip: face.tooltip,
      padding: EdgeInsets.zero,
      iconSize: 18,
      // Compact, like the header's back button: two of these sit side by
      // side, and the default 48px hit box left 30px of air between two
      // 18px icons. Compact density trims each box to 40 — still a
      // comfortable target, and the pair reads as one group.
      visualDensity: VisualDensity.compact,
      icon: Icon(face.icon, color: color, size: 18),
      onPressed: onTap,
    );
  }
}

class _LiquidCallButton extends StatelessWidget {
  const _LiquidCallButton({
    required this.kind,
    required this.enabled,
    required this.onTap,
  });

  final CallMediaKind kind;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = enabled
        ? theme.accent
        : theme.accent.withValues(alpha: 0.35);
    final face = _face(context, kind);
    return Tooltip(
      message: face.tooltip,
      child: LiquidGlass(
        shape: LiquidGlassShape.circle,
        size: const Size(44, 44),
        onTap: onTap,
        child: Icon(face.icon, size: 18, color: color),
      ),
    );
  }
}
