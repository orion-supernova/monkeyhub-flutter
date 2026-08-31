import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'call_models.dart';
import 'call_service.dart';
import 'group_call_service.dart';
import 'widgets/call_chrome.dart';

/// The way back into a call that was put away.
///
/// A call screen can now be hidden while the call goes on — to read a
/// message, to find the thing you meant to share, to draw over the app you
/// are sharing. This pill sits at the top of every screen while a call runs
/// behind it and its screen is not up: a timer, "Return", and — while this
/// device is sharing its screen — the pen that arms drawing over the app
/// and a stop for the share. Rendered nothing while the call screen is on
/// top, or when there is no call.
///
/// Sibling of [ActiveCallPill], which is about a call on ANOTHER device.
class InCallPill extends StatefulWidget {
  const InCallPill({
    super.key,
    required this.call,
    required this.group,
    required this.callScreenUp,
  });

  final CallService call;
  final GroupCallService? group;

  /// Whether a call screen is the top route right now — the overlays that
  /// push them know.
  final ValueListenable<bool> callScreenUp;

  @override
  State<InCallPill> createState() => _InCallPillState();
}

class _InCallPillState extends State<InCallPill> {
  @override
  void initState() {
    super.initState();
    widget.call.addListener(_changed);
    widget.group?.addListener(_changed);
    widget.callScreenUp.addListener(_changed);
    widget.call.drawArmed.addListener(_changed);
    widget.group?.drawArmed.addListener(_changed);
  }

  @override
  void dispose() {
    widget.call.removeListener(_changed);
    widget.group?.removeListener(_changed);
    widget.callScreenUp.removeListener(_changed);
    widget.call.drawArmed.removeListener(_changed);
    widget.group?.drawArmed.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final call = widget.call;
    final group = widget.group;
    final session = call.session;
    // A ringing call has its own screens (native or in-app); the pill is
    // for a call that is genuinely under way behind whatever is on top.
    final oneToOne = call.inCall &&
        session != null &&
        session.status != CallStatus.incomingRinging &&
        session.status != CallStatus.ended &&
        session.status != CallStatus.failed &&
        session.status != CallStatus.handedOff;
    final inGroup = group?.inCall ?? false;
    final visible = (oneToOne || inGroup) && !widget.callScreenUp.value;
    final sharing = oneToOne ? call.localScreenSharing : (group?.localScreenSharing ?? false);
    final armed = oneToOne ? call.drawArmed : group?.drawArmed;
    final start = oneToOne
        ? (call.session!.connectedAt ?? call.session!.startedAt)
        : group?.joinedAt;
    final title = oneToOne
        ? l10n.activeCallPillCallWith(call.session!.peerName)
        : (group?.roomName ?? l10n.inCallPillOngoingCall);

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !visible
          ? const SizedBox(width: double.infinity, height: 0)
          : Material(
              color: Colors.transparent,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(theme.radiusLg),
                      gradient: LinearGradient(
                        colors: [theme.accent, theme.accentSoft],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.32),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sharing
                                ? Icons.screen_share_outlined
                                : Icons.call_rounded,
                            size: 18,
                            color: theme.accentInk,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: theme.body.copyWith(
                                    color: theme.accentInk,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    if (start != null)
                                      ElapsedLabel(
                                        start: start,
                                        style: theme.monoTiny.copyWith(
                                          color: theme.accentInk.withValues(
                                            alpha: 0.82,
                                          ),
                                        ),
                                      ),
                                    if (sharing) ...[
                                      if (start != null)
                                        Text(
                                          '  ·  ',
                                          style: theme.monoTiny.copyWith(
                                            color: theme.accentInk.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      Flexible(
                                        child: Text(
                                          l10n.inCallPillSharing,
                                          style: theme.monoTiny.copyWith(
                                            color: theme.accentInk.withValues(
                                              alpha: 0.82,
                                            ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (sharing && armed != null) ...[
                            const SizedBox(width: 6),
                            _RoundAction(
                              icon: Icons.draw_outlined,
                              active: armed.value,
                              semanticLabel: l10n.inCallPillDrawSemanticLabel,
                              onTap: () => armed.value = !armed.value,
                            ),
                            const SizedBox(width: 6),
                            _RoundAction(
                              icon: Icons.stop_rounded,
                              semanticLabel:
                                  l10n.inCallPillStopSharingSemanticLabel,
                              onTap: () => unawaited(
                                oneToOne
                                    ? call.stopScreenShare()
                                    : group!.stopScreenShare(),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          FocusableTap(
                            onTap: () => _reopen(oneToOne),
                            shape: FocusRingShape.capsule,
                            semanticLabel: l10n.inCallPillReturn,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _reopen(oneToOne),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.accentInk.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      l10n.inCallPillReturn,
                                      style: theme.monoTiny.copyWith(
                                        color: theme.accentInk,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      size: 14,
                                      color: theme.accentInk,
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
              ),
            ),
    );
  }

  void _reopen(bool oneToOne) {
    if (oneToOne) {
      widget.call.reopenTick.value++;
    } else {
      widget.group?.reopenTick.value++;
    }
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.circle,
      semanticLabel: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? theme.accentInk
                : theme.accentInk.withValues(alpha: 0.20),
          ),
          child: Icon(
            icon,
            size: 16,
            color: active ? theme.accent : theme.accentInk,
          ),
        ),
      ),
    );
  }
}
