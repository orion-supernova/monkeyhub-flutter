import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../calls/widgets/call_chrome.dart' show kCallAcceptGreen;
import '../../l10n/generated/app_localizations.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/ios_kit.dart' show groupedFill, groupedRadius;
import '../../widgets/progress_ring.dart';
import '../../widgets/sheet_kit.dart';
import '../../widgets/spring_press.dart';
import '../../widgets/user_avatar.dart';
import 'call_log_models.dart';
import 'calls_directory.dart';
import 'calls_format.dart';

/// "This week: 3h 20m on calls", with a ring that closes once on first view.
///
/// What it counts: the time the user was CONNECTED on calls since the week
/// started in their locale (`callLog.durationMs`, which is 0 for anything
/// never answered). The ring is a flourish, not a gauge: it sweeps closed once
/// per app run when there was any talk time, and stays a thin track when there
/// was none. The footnote in the sheet spells the rule out.
class CallsTalkTime extends StatefulWidget {
  const CallsTalkTime({
    super.key,
    required this.summary,
    required this.weekStart,
    required this.directory,
    this.api,
  });

  /// Null until the first summary lands; the header is hidden meanwhile.
  final CallLogSummary? summary;
  final DateTime weekStart;
  final CallsDirectory directory;
  final ChatApi? api;

  /// The sweep plays once per run, not on every visit to the tab.
  static bool played = false;

  @override
  State<CallsTalkTime> createState() => _CallsTalkTimeState();
}

class _CallsTalkTimeState extends State<CallsTalkTime>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _fill =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybePlay();
  }

  @override
  void didUpdateWidget(CallsTalkTime old) {
    super.didUpdateWidget(old);
    _maybePlay();
  }

  void _maybePlay() {
    final s = widget.summary;
    if (s == null || _started) return;
    _started = true;
    if (s.totalMs <= 0) return;
    if (CallsTalkTime.played || MotionScope.of(context).calm) {
      _c.value = 1;
      return;
    }
    CallsTalkTime.played = true;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _openSheet() {
    final s = widget.summary;
    if (s == null) return;
    showAdaptiveSheet<void>(
      context,
      builder: (_) => _TalkTimeSheet(
        summary: s,
        weekStart: widget.weekStart,
        directory: widget.directory,
        api: widget.api,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    if (s == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final text = s.totalMs <= 0
        ? l10n.callsTabTalkTimeNone
        : l10n.callsTabTalkTimeThisWeek(talkDuration(l10n, s.totalMs));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SpringPress(
        onTap: _openSheet,
        scale: 0.98,
        haptic: true,
        semanticLabel: text,
        focusRadius: groupedRadius(theme),
        hoverRadius: groupedRadius(theme),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: groupedFill(theme),
            borderRadius: BorderRadius.circular(groupedRadius(theme)),
          ),
          child: Row(
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, child) {
                    // The jelly: the whole ring swells past its size and
                    // settles as it closes.
                    final pop = MotionScope.of(context).calm
                        ? 1.0
                        : 0.84 + 0.16 * const ElasticOutCurve(0.55).transform(_c.value);
                    return Transform.scale(scale: pop, child: child);
                  },
                  child: SizedBox.square(
                    dimension: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: ProgressRing.animated(
                            animation: _fill,
                            color: kCallAcceptGreen,
                            trackColor: theme.ink.withValues(alpha: 0.10),
                            strokeWidth: 4,
                            inset: 2,
                          ),
                        ),
                        Icon(
                          CupertinoIcons.phone_fill,
                          size: 16,
                          color: s.totalMs > 0 ? kCallAcceptGreen : theme.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(fontSize: 16, color: theme.ink),
                ),
              ),
              Icon(CupertinoIcons.chevron_right, size: 14, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalkTimeSheet extends StatelessWidget {
  const _TalkTimeSheet({
    required this.summary,
    required this.weekStart,
    required this.directory,
    this.api,
  });

  final CallLogSummary summary;
  final DateTime weekStart;
  final CallsDirectory directory;
  final ChatApi? api;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final start = MaterialLocalizations.of(context).formatFullDate(weekStart);
    return SheetFrame(
      title: l10n.callsTabTalkTimeSheetTitle,
      maxHeightFraction: 0.8,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              talkDuration(l10n, summary.totalMs),
              style: theme.displayLarge.copyWith(color: theme.ink),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              l10n.callsTabCallCount(summary.calls),
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
          ),
          if (summary.top.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              l10n.callsTabTopPeople,
              style: theme.bodyEmph.copyWith(fontSize: 15, color: theme.inkSoft),
            ),
            const SizedBox(height: 8),
            for (final t in summary.top)
              _PersonRow(peer: t, directory: directory, api: api),
          ],
          const SizedBox(height: 18),
          Text(
            l10n.callsTabTalkTimeFootnote(start),
            style: theme.bodySoft.copyWith(fontSize: 12.5, color: theme.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.peer, required this.directory, this.api});
  final CallTopPeer peer;
  final CallsDirectory directory;
  final ChatApi? api;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final user = directory.user(peer.peerId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (user != null)
            UserAvatar(user: user, size: 38, api: api, showStatus: false)
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.ink.withValues(alpha: 0.08),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user?.displayName ?? l10n.callsTabUnknown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyEmph.copyWith(fontSize: 16, color: theme.ink),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                talkDuration(l10n, peer.ms),
                style: theme.bodyEmph.copyWith(fontSize: 15, color: theme.ink),
              ),
              Text(
                l10n.callsTabCallCount(peer.calls),
                style: theme.bodySoft.copyWith(fontSize: 12.5, color: theme.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
