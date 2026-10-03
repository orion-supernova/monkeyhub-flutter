import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
import 'widgets/call_chrome.dart' show callStatusStyle;
import 'call_screen.dart';
import 'call_service.dart';
import '../widgets/spring_press.dart';

/// Full-screen UI shown when an incoming call arrives. Tap accept → spins up
/// media + answer, replaces self with [CallScreen]. Tap reject → tears down.
///
/// Phones ring via the NATIVE UI (CallKit / ConnectionService) instead —
/// this screen only shows on platforms without one (iOS simulator,
/// desktop). See `_CallOverlay._nativeRinger`.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key, required this.service, this.api});
  final CallService service;
  final ChatApi? api;

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

enum _RingAction { none, accept, reject }

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  // Once the user has tapped accept/reject we lock both buttons until the
  // screen disposes. The session transitions through `connecting` (accept)
  // or terminal (reject) within a few hundred ms — locking is enough.
  _RingAction _pending = _RingAction.none;
  // CallService._teardown notifies twice (status → ended, then session →
  // null 400ms later). Without this guard both notifies would call pop()
  // and the second pop would dismiss the chatroom underneath.
  bool _popScheduled = false;
  // pushReplacement to CallScreen must run exactly once; connecting/active
  // notifies repeatedly while this route is still on top.
  bool _movedToCall = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    // The ringtone is driven by _CallOverlay from the call-state change (not
    // here), because on a backgrounded web tab this screen never mounts — see
    // _CallOverlayState._syncRingtone.
    widget.service.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    final s = widget.service.session;
    if (s == null ||
        s.status == CallStatus.ended ||
        s.status == CallStatus.failed) {
      if (_popScheduled) return;
      _popScheduled = true;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }
    if (!_movedToCall &&
        (s.status == CallStatus.connecting || s.status == CallStatus.active)) {
      // We've accepted — swap to the active call screen. Guarded so the
      // repeated notifies in this window can't stack CallScreen routes
      // (each of which would allocate its own pair of video renderers).
      _movedToCall = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CallScreen(service: widget.service, api: widget.api),
        ),
      );
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.service.removeListener(_onChanged);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_pending != _RingAction.none) return;
    HapticFeedback.mediumImpact();
    setState(() => _pending = _RingAction.accept);
    await widget.service.acceptIncoming();
  }

  Future<void> _reject() async {
    if (_pending != _RingAction.none) return;
    HapticFeedback.heavyImpact();
    setState(() => _pending = _RingAction.reject);
    await widget.service.reject();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final s = widget.service.session;
    final name = s?.peerName ?? l10n.typingIndicatorUnknownCallerFallbackName;
    // Already upper-cased in both languages — Dart's String.toUpperCase()
    // isn't locale-aware and mangles the Turkish dotted İ, so the ARB value
    // carries the final casing instead of a runtime .toUpperCase() call.
    final kindLabel = s?.mediaKind == CallMediaKind.video
        ? l10n.typingIndicatorIncomingVideoCallLabel
        : l10n.typingIndicatorIncomingVoiceCallLabel;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.accent.withValues(alpha: 0.55), Colors.black],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 56),
                // The Phone app's incoming screen: who, large, and what kind
                // of call in a quiet line under it. The voice/video
                // distinction stays unmissable through the glyph beside it
                // and the accept button's own icon.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: theme.displayLarge.copyWith(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s?.mediaKind == CallMediaKind.video
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                    const SizedBox(width: 6),
                    Text(kindLabel, style: callStatusStyle(theme)),
                  ],
                ),
                const SizedBox(height: 56),
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final scale = 1.0 + _pulse.value * 0.05;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.38),
                          blurRadius: 56,
                        ),
                      ],
                    ),
                    // Real avatar photo when known; per-user gradient +
                    // initial otherwise.
                    child: UserAvatar(
                      user: ChatUser(
                        id: s?.peerUserId ?? '',
                        username: '',
                        name: name,
                        avatarStorageId: s?.peerAvatarStorageId,
                      ),
                      api: widget.api,
                      size: 150,
                      showStatus: false,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  // Capped and centered so the two buttons stay a matched
                  // pair on a wide desktop window instead of spaceEvenly
                  // pushing them out to the far edges — on a phone this
                  // ceiling is never reached, so nothing changes there.
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RingButton(
                            icon: Icons.call_end,
                            background: theme.danger,
                            label: _pending == _RingAction.reject
                                ? l10n.typingIndicatorDeclineButtonDeclining
                                : l10n.typingIndicatorDeclineButtonLabel,
                            enabled: _pending == _RingAction.none,
                            onTap: _reject,
                          ),
                          _RingButton(
                            // Video calls accept with the camera glyph so the
                            // user knows what they're walking into.
                            icon: s?.mediaKind == CallMediaKind.video
                                ? Icons.videocam
                                : Icons.call,
                            background: theme.success,
                            label: _pending == _RingAction.accept
                                ? l10n.typingIndicatorAcceptButtonConnecting
                                : l10n.typingIndicatorAcceptButtonLabel,
                            enabled: _pending == _RingAction.none,
                            onTap: _accept,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingButton extends StatelessWidget {
  const _RingButton({
    required this.icon,
    required this.background,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final Color background;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? background : background.withValues(alpha: 0.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FocusableTap(
          onTap: enabled ? onTap : null,
          semanticLabel: label,
          shape: FocusRingShape.circle,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            child: SpringPress.passive(
              scale: 0.9,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(
                  icon,
                  color: Colors.white.withValues(alpha: enabled ? 1.0 : 0.6),
                  size: 34,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'CupertinoSystemText',
            color: Color(0xD9FFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
