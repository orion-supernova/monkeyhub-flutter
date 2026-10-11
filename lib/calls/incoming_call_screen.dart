import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import 'call_models.dart';
import 'widgets/call_chrome.dart'
    show
        CallGlyphs,
        RingActionButton,
        RingerLayout,
        callStatusStyle,
        kCallAcceptGreen,
        kCallStatusBarStyle;
import 'call_screen.dart';
import 'call_service.dart';
import '../l10n/text_case.dart';

/// Full-screen UI shown when an incoming call arrives. Tap accept → spins up
/// media + answer, replaces self with [CallScreen]. Tap reject → tears down.
///
/// Phones ring via the NATIVE UI (CallKit / ConnectionService) instead —
/// this screen only shows on platforms without one (iOS simulator,
/// desktop). See `_CallOverlay._nativeRinger`.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.service,
    this.api,
    this.screenUp,
    this.routeName,
  });
  final CallService service;
  final ChatApi? api;

  /// Raised while the [CallScreen] this hands over to is up, as the
  /// overlay does for the screens it pushes itself: the in-call pill hides
  /// behind it rather than floating over the call.
  final ValueNotifier<bool>? screenUp;

  /// The [CallScreen] route's name, so it is as protected as this one.
  final String? routeName;

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
      dismissCallRoute(context);
      return;
    }
    if (!_movedToCall &&
        (s.status == CallStatus.connecting || s.status == CallStatus.active)) {
      // We've accepted — swap to the active call screen. Guarded so the
      // repeated notifies in this window can't stack CallScreen routes
      // (each of which would allocate its own pair of video renderers).
      _movedToCall = true;
      final screenUp = widget.screenUp;
      screenUp?.value = true;
      Navigator.of(context)
          .pushReplacement(
            MaterialPageRoute<void>(
              settings: RouteSettings(name: widget.routeName),
              builder: (_) =>
                  CallScreen(service: widget.service, api: widget.api),
            ),
          )
          .whenComplete(() => screenUp?.value = false);
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
    final isVideo = s?.mediaKind == CallMediaKind.video;
    // Sentence case at the source (the ARB value); sentenceCaseOf below
    // only guards a translation that still shouts.
    final kindLabel = isVideo
        ? l10n.typingIndicatorIncomingVideoCallLabel
        : l10n.typingIndicatorIncomingVoiceCallLabel;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kCallStatusBarStyle,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: RingerLayout(
            // The Phone app's incoming screen: who, large, and what kind of
            // call in a quiet line under it. The voice/video distinction
            // stays unmissable through the glyph beside it and the accept
            // button's own icon.
            title: name,
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVideo ? CallGlyphs.camera : CallGlyphs.voice,
                  size: 17,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    sentenceCaseOf(context, kindLabel),
                    style: callStatusStyle(theme),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            pulse: _pulse,
            // Real avatar photo when known; per-user gradient + initial
            // otherwise.
            avatar: UserAvatar(
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
            actions: [
              RingActionButton(
                icon: CallGlyphs.end,
                background: theme.danger,
                label: _pending == _RingAction.reject
                    ? l10n.typingIndicatorDeclineButtonDeclining
                    : l10n.typingIndicatorDeclineButtonLabel,
                enabled: _pending == _RingAction.none,
                onTap: _reject,
              ),
              RingActionButton(
                // Video calls accept with the camera glyph so the user knows
                // what they're walking into.
                icon: isVideo ? CallGlyphs.camera : CallGlyphs.voice,
                background: kCallAcceptGreen,
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
    );
  }
}
