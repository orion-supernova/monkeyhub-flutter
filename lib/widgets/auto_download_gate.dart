import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../media/storage/auto_download.dart';
import '../media/storage/network_kind.dart';
import '../theme/theme_scope.dart';
import 'glass_buttons.dart';

/// Holds an incoming photo behind a tap when auto-download says not now.
///
/// The rule is the user's: a photo in a kind of chat they turned off for this
/// network (Data and Storage → Using Cellular → Photos) draws as a quiet plate
/// with a download button instead of fetching. One tap releases it for the
/// session. Anything already on disk, anything you sent, and every photo once
/// the network or the rule allows it, draws straight through: [child] is built
/// exactly as it would have been without the gate.
class AutoDownloadGate extends StatefulWidget {
  const AutoDownloadGate({
    super.key,
    required this.storageId,
    required this.roomId,
    required this.incoming,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final String storageId;
  final String roomId;
  final bool incoming;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<AutoDownloadGate> createState() => _AutoDownloadGateState();
}

class _AutoDownloadGateState extends State<AutoDownloadGate> {
  late bool _ready = _decide();

  bool _decide() => AutoDownload.instance
      .photoReady(widget.storageId, widget.roomId, incoming: widget.incoming);

  @override
  void initState() {
    super.initState();
    if (!_ready) NetworkKindMonitor.instance.addListener(_recheck);
  }

  @override
  void didUpdateWidget(AutoDownloadGate old) {
    super.didUpdateWidget(old);
    // The bubble rebuilds when settings change, which is when a rule that
    // held this photo may have been relaxed.
    if (!_ready) _recheck();
  }

  @override
  void dispose() {
    NetworkKindMonitor.instance.removeListener(_recheck);
    super.dispose();
  }

  void _recheck() {
    if (_ready || !_decide()) return;
    NetworkKindMonitor.instance.removeListener(_recheck);
    if (mounted) setState(() => _ready = true);
  }

  void _release() {
    HapticFeedback.selectionClick();
    AutoDownload.instance.releasePhoto(widget.storageId);
    NetworkKindMonitor.instance.removeListener(_recheck);
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final theme = ThemeScope.of(context);
    // The shimmer's resting base, so a held photo and a loading one sit on
    // the same plate and releasing it reads as the load simply starting.
    final base = Color.alphaBlend(
      theme.surfaceSunken.withValues(alpha: 0.55),
      theme.surfaceRaised,
    );
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: base,
        child: Center(
          child: GlassIconButton(
            icon: CupertinoIcons.arrow_down,
            size: 44,
            iconSize: 20,
            still: true,
            semanticLabel: AppLocalizations.of(context).autoDownloadGateLoad,
            onTap: _release,
          ),
        ),
      ),
    );
  }
}
