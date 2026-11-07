import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../family/family_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/density.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/chrome_motion.dart';
import '../ui/foundation/ui_kit.dart' show FlutterSkinsOnly;
import '../ui/native/native_control.dart';
import '../widgets/liquid_glass.dart';
import 'call_models.dart';
import 'call_service.dart';
import '../backend/server_limits.dart';

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
    this.peerAvatarStorageId,
  });

  final String peerUserId;
  final String peerName;

  /// The peer's picture, so the call screen opens on their face.
  final String? peerAvatarStorageId;
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
        peerAvatarStorageId: peerAvatarStorageId,
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = _friendlyError(context, e);
      showAppToast(context, msg, duration: const Duration(seconds: 3));
    }
  }

  /// What a tap on this button does, for a caller with no button to tap: the
  /// room's ⌥⌘A / ⌥⌘V. Busy answers with the reason, exactly as the
  /// disabled button does.
  void activate(BuildContext context) {
    if (FamilyService.maybeInstance?.canCall == false) return;
    final reason = _busyReason(context, CallService.instance);
    if (reason != null) {
      _showBusy(context, reason);
    } else {
      _start(context);
    }
  }

  String _friendlyError(BuildContext context, Object e) {
    final l10n = AppLocalizations.of(context);
    final s = e.toString();
    final limit = serverLimitMessage(e, l10n);
    if (limit != null) return limit;
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
        icon: CupertinoIcons.phone,
        tooltip: l10n.callButtonVoiceCallTooltip
      ),
    CallMediaKind.video => (
        icon: CupertinoIcons.video_camera,
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
  Widget build(BuildContext context) => CallGlyphButton(
        kind: kind,
        enabled: enabled,
        onTap: onTap,
        size: Density.of(context).iconButton,
      );
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
  Widget build(BuildContext context) =>
      CallGlyphButton(kind: kind, enabled: enabled, onTap: onTap, size: 44);
}

/// THE header call button — voice or video, one-to-one or group. A glass disc
/// with an ink glyph: no accent, because a header that wore two blue handsets
/// next to the title was the loudest thing on the screen while doing nothing.
///
/// The glyph says what it does when tapped: the handset rocks like a phone
/// ringing on a table, the camera swells like a shutter. [enabled] false
/// (already in a call) dims the glyph but keeps the tap, which explains why.
class CallGlyphButton extends StatefulWidget {
  const CallGlyphButton({
    super.key,
    required this.kind,
    required this.enabled,
    required this.onTap,
    required this.size,
  });

  final CallMediaKind kind;
  final bool enabled;
  final VoidCallback? onTap;
  final double size;

  @override
  State<CallGlyphButton> createState() => _CallGlyphButtonState();
}

class _CallGlyphButtonState extends State<CallGlyphButton> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final face = _face(context, widget.kind);
    final color = widget.enabled ? theme.ink : theme.inkMuted;
    final onTap = widget.onTap;
    // The liquid kit's native glass disc. Busy (not enabled) keeps the Flutter
    // disc, which dims and still answers a tap; the native one loses the
    // handset's rock and the camera's pop, so it is the idle-state skin only.
    if (widget.enabled && onTap != null && NativeControl.readyIn(context)) {
      return NativeControl(
        standIn: FlutterSkinsOnly(child: Builder(builder: build)),
        size: Size.square(widget.size),
        spec: NativeSpec.symbolButton(
          symbol: widget.kind == CallMediaKind.audio ? 'phone' : 'video',
          label: face.tooltip,
          size: widget.size,
          symbolSize: widget.size * 17 / 44,
        ),
        onEvent: (event, _) {
          if (event == 'tap') onTap();
        },
      );
    }
    return Tooltip(
      message: face.tooltip,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: face.tooltip,
        child: LiquidGlass(
          shape: LiquidGlassShape.circle,
          size: Size(widget.size, widget.size),
          onTap: onTap == null
              ? null
              : () {
                  if (widget.enabled) setState(() => _taps++);
                  onTap();
                },
          child: KickGlyph(
            kick: widget.kind == CallMediaKind.audio
                ? GlyphKick.rock
                : GlyphKick.pop,
            trigger: _taps,
            child: Icon(face.icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
