import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../call_models.dart';
import '../video_quality_governor.dart';
import 'call_chrome.dart';

/// The display name of a camera tier in a sentence: Auto runs at 720p, and
/// "lowered to Auto" would say nothing.
String videoTierLabel(AppLocalizations l10n, VideoQualityTier t) =>
    switch (t) {
      VideoQualityTier.auto => '720p',
      VideoQualityTier.hd1080 => l10n.settingsScreenValueVideoQuality1080p,
      VideoQualityTier.uhd4k => l10n.settingsScreenValueVideoQuality4k,
    };

/// A call's [VideoQualityNoticeSource.qualityNotice] as a [CallNoticeChip],
/// on the 1:1 and the group call screen alike. A drop the call already made
/// is news and leaves by itself after a few seconds; an offer (auto-lowering
/// off) stays until it is taken or closed.
class VideoQualityNoticeLayer extends StatefulWidget {
  const VideoQualityNoticeLayer({super.key, required this.source});
  final VideoQualityNoticeSource source;

  /// How long a "video lowered" notice stays.
  static const Duration appliedHold = Duration(seconds: 6);

  @override
  State<VideoQualityNoticeLayer> createState() =>
      _VideoQualityNoticeLayerState();
}

class _VideoQualityNoticeLayerState extends State<VideoQualityNoticeLayer> {
  Timer? _hide;

  ValueListenable<VideoQualityNotice?> get _notice =>
      widget.source.qualityNotice;

  @override
  void initState() {
    super.initState();
    _notice.addListener(_changed);
  }

  @override
  void didUpdateWidget(VideoQualityNoticeLayer old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      old.source.qualityNotice.removeListener(_changed);
      _notice.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    _notice.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    _hide?.cancel();
    final n = _notice.value;
    if (n != null && n.applied) {
      _hide = Timer(VideoQualityNoticeLayer.appliedHold, () {
        if (identical(_notice.value, n)) widget.source.dismissQualityNotice();
      });
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final n = _notice.value;
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: n == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Center(
                key: ValueKey(n),
                child: CallNoticeChip(
                  label: n.applied
                      ? l10n.callQualityLoweredBanner(videoTierLabel(l10n, n.to))
                      : l10n.callQualityOfferBanner(videoTierLabel(l10n, n.from)),
                  closeSemanticLabel: l10n.interactionClose,
                  onClose: widget.source.dismissQualityNotice,
                  actionLabel: n.applied
                      ? null
                      : l10n.callQualityOfferAction(videoTierLabel(l10n, n.to)),
                  onAction: n.applied
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          widget.source.lowerVideoQualityForCall(n.to);
                        },
                ),
              ),
      ),
    );
  }
}
