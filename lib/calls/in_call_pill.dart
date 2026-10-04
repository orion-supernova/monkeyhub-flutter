import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../widgets/fit_label.dart';
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
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: CallStatusBanner(
                  icon: sharing ? CallGlyphs.share : CallGlyphs.voice,
                  title: title,
                  meta: Row(
                    // Top-aligned so a wrapped sharing label hangs under its
                    // own first line, with the timer level with that line.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (start != null)
                        ElapsedLabel(
                          start: start,
                          style: CallStatusBanner.metaStyle(
                            context,
                            CallBannerTone.accent,
                          ),
                        ),
                      if (sharing) ...[
                        if (start != null) const Text('  ·  '),
                        // Wraps, then shrinks — never "Ekranını
                        // paylaşıyor…". The pill is narrowest exactly while
                        // sharing (draw + stop sit beside Return), so this is
                        // the line that runs out of room first.
                        Flexible(
                          child: FitLabel(
                            l10n.inCallPillSharing,
                            style: CallStatusBanner.metaStyle(
                              context,
                              CallBannerTone.accent,
                            ),
                            minFontSize: 11,
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    if (sharing && armed != null) ...[
                      CallBannerAction(
                        icon: CallGlyphs.draw,
                        active: armed.value,
                        semanticLabel: l10n.inCallPillDrawSemanticLabel,
                        onTap: () => armed.value = !armed.value,
                      ),
                      CallBannerAction(
                        icon: CallGlyphs.stopShare,
                        semanticLabel: l10n.inCallPillStopSharingSemanticLabel,
                        onTap: () => unawaited(
                          oneToOne
                              ? call.stopScreenShare()
                              : group!.stopScreenShare(),
                        ),
                      ),
                    ],
                    // With the pen and the stop beside it, Return drops its
                    // word for the glyph: three labelled controls left the
                    // title and the timer two letters each in Turkish.
                    CallBannerAction(
                      icon: CallGlyphs.back,
                      label: sharing ? null : l10n.inCallPillReturn,
                      semanticLabel: l10n.inCallPillReturn,
                      onTap: () => _reopen(oneToOne),
                    ),
                  ],
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
