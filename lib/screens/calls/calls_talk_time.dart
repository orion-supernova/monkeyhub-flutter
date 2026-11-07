import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../backend/chat_api.dart';
import '../../calls/widgets/call_chrome.dart' show kCallAcceptGreen;
import '../../l10n/generated/app_localizations.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/ios_kit.dart' show groupedFill, groupedRadius;
import '../../widgets/progress_ring.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/sheet_kit.dart';
import '../../widgets/spring_press.dart';
import '../../widgets/user_avatar.dart';
import 'call_log_models.dart';
import 'call_log_store.dart';
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
    this.store,
  });

  /// Where the sheet reads the 30-day and all-time figures from (and asks for
  /// the latter). Without it the sheet shows the week only.
  final CallLogStore? store;

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
        store: widget.store,
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

enum _Period { week, month, all }

class _TalkTimeSheet extends StatefulWidget {
  const _TalkTimeSheet({
    required this.summary,
    required this.weekStart,
    required this.directory,
    this.api,
    this.store,
  });

  final CallLogSummary summary;
  final DateTime weekStart;
  final CallsDirectory directory;
  final ChatApi? api;
  final CallLogStore? store;

  @override
  State<_TalkTimeSheet> createState() => _TalkTimeSheetState();
}

class _TalkTimeSheetState extends State<_TalkTimeSheet> {
  _Period _period = _Period.week;

  CallLogSummary? _current() {
    final st = widget.store;
    return switch (_period) {
      _Period.week => st?.week ?? widget.summary,
      _Period.month => st?.month,
      _Period.all => st?.allTime,
    };
  }

  void _pick(_Period p) {
    setState(() => _period = p);
    if (p == _Period.all) widget.store?.loadAllTime();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = widget.store;
    return SheetFrame(
      title: l10n.callsTabTalkTimeSheetTitle,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Material(
        type: MaterialType.transparency,
        child: ListenableBuilder(
          listenable: store ?? const AlwaysStoppedAnimation<double>(0),
          builder: (context, _) {
            final s = _current();
            final start = switch (_period) {
              _Period.week => widget.weekStart,
              _Period.month =>
                callsClock().subtract(const Duration(days: 30)),
              _Period.all => null,
            };
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (store != null) ...[
                    IosSegmentedControl<_Period>(
                      value: _period,
                      onChanged: _pick,
                      segments: [
                        IosSegment(
                          value: _Period.week,
                          label: l10n.callsTabTalkTimeSheetTitle,
                        ),
                        IosSegment(
                          value: _Period.month,
                          label: l10n.callsStatsPeriodMonth,
                        ),
                        IosSegment(
                          value: _Period.all,
                          label: l10n.callsStatsPeriodAll,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (s == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    )
                  else
                    _StatsBody(
                      summary: s,
                      directory: widget.directory,
                      api: widget.api,
                      footnote: start == null
                          ? l10n.callsStatsAllTimeNote(s.calls)
                          : l10n.callsTabTalkTimeFootnote(
                              MaterialLocalizations.of(context)
                                  .formatFullDate(start),
                            ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.summary,
    required this.directory,
    required this.footnote,
    this.api,
  });

  final CallLogSummary summary;
  final CallsDirectory directory;
  final ChatApi? api;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final s = summary;
    final locale = Localizations.localeOf(context).toString();
    final ml = MaterialLocalizations.of(context);
    final peakHour = CallLogSummary.peak(s.byHour);
    final peakDay = CallLogSummary.peak(s.byWeekday);
    String hourLabel(int h) => ml.formatTimeOfDay(TimeOfDay(hour: h, minute: 0));
    // 2024-01-07 was a Sunday: weekday index 0 is Sunday on the wire.
    String dayLabel(int d) =>
        DateFormat.EEEE(locale).format(DateTime(2024, 1, 7 + d));
    final tiles = <Widget>[];
    if (s.hasDetail && s.calls > 0) {
      tiles
        ..add(_StatTile(value: '${s.answered}', label: l10n.callsStatsAnswered))
        ..add(_StatTile(
          value: '${s.missed}',
          label: l10n.callsStatsMissed,
          danger: s.missed > 0,
        ))
        ..add(_StatTile(
          value: talkDuration(l10n, s.longestMs),
          label: l10n.callsStatsLongest,
        ))
        ..add(_StatTile(
          value: talkDuration(l10n, s.averageMs),
          label: l10n.callsStatsAverage,
        ));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            talkDuration(l10n, s.totalMs),
            style: theme.displayLarge.copyWith(color: theme.ink),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            l10n.callsTabCallCount(s.calls),
            style: theme.bodySoft.copyWith(color: theme.inkMuted),
          ),
        ),
        if (tiles.isNotEmpty) ...[
          const SizedBox(height: 18),
          _Grid(children: tiles),
          const SizedBox(height: 10),
          _SplitCard(
            leftLabel: l10n.callsStatsVoice,
            rightLabel: l10n.callsStatsVideo,
            left: s.audioMs > 0 || s.videoMs > 0 ? s.audioMs : s.audioCalls,
            right: s.audioMs > 0 || s.videoMs > 0 ? s.videoMs : s.videoCalls,
            leftText: '${talkDuration(l10n, s.audioMs)} · ${s.audioCalls}',
            rightText: '${talkDuration(l10n, s.videoMs)} · ${s.videoCalls}',
            leftColor: kCallAcceptGreen,
            rightColor: theme.accent,
          ),
          const SizedBox(height: 10),
          _SplitCard(
            leftLabel: l10n.callsStatsOutgoing,
            rightLabel: l10n.callsStatsIncoming,
            left: s.outgoing,
            right: s.incoming,
            leftText: '${s.outgoing}',
            rightText: '${s.incoming}',
            leftColor: theme.accent,
            rightColor: theme.inkMuted,
          ),
          if (peakHour >= 0) ...[
            const SizedBox(height: 10),
            _HourCard(
              title: l10n.callsStatsBusiestHour,
              value: hourLabel(peakHour),
              hours: s.byHour,
              peak: peakHour,
            ),
          ],
          const SizedBox(height: 10),
          _Grid(children: [
            if (peakDay >= 0)
              _StatTile(value: dayLabel(peakDay), label: l10n.callsStatsBusiestDay),
            _StatTile(
              value: l10n.callsStatsDays(s.currentStreak),
              label: l10n.callsStatsStreak,
              sub: l10n.callsStatsBestStreak(l10n.callsStatsDays(s.bestStreak)),
            ),
          ]),
        ],
        if (s.top.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            l10n.callsTabTopPeople,
            style: theme.bodyEmph.copyWith(fontSize: 15, color: theme.inkSoft),
          ),
          const SizedBox(height: 8),
          for (final t in s.top)
            _PersonRow(peer: t, directory: directory, api: api),
        ],
        const SizedBox(height: 18),
        Text(
          footnote,
          style: theme.bodySoft.copyWith(fontSize: 12.5, color: theme.inkMuted),
        ),
      ],
    );
  }
}

/// Tiles two to a row, however many there are.
class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.sub,
    this.danger = false,
  });
  final String value;
  final String label;
  final String? sub;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodyEmph.copyWith(
              fontSize: 20,
              color: danger ? theme.danger : theme.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySoft.copyWith(fontSize: 12.5, color: theme.inkMuted),
            ),
        ],
      ),
    );
  }
}

/// Two quantities as one proportional bar, each side labelled underneath.
class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.leftLabel,
    required this.rightLabel,
    required this.left,
    required this.right,
    required this.leftText,
    required this.rightText,
    required this.leftColor,
    required this.rightColor,
  });
  final String leftLabel;
  final String rightLabel;
  final int left;
  final int right;
  final String leftText;
  final String rightText;
  final Color leftColor;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final total = left + right;
    final lf = total == 0 ? 1 : left;
    final rf = total == 0 ? 1 : right;
    Widget side(String label, String text, Color c, CrossAxisAlignment al) =>
        Expanded(
          child: Column(
            crossAxisAlignment: al,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyEmph.copyWith(fontSize: 14, color: theme.ink),
                    ),
                  ),
                ],
              ),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (left > 0 || total == 0)
                    Expanded(flex: lf, child: ColoredBox(color: leftColor)),
                  if (left > 0 && right > 0) const SizedBox(width: 2),
                  if (right > 0 || total == 0)
                    Expanded(flex: rf, child: ColoredBox(color: rightColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              side(leftLabel, leftText, leftColor, CrossAxisAlignment.start),
              const SizedBox(width: 12),
              side(rightLabel, rightText, rightColor, CrossAxisAlignment.start),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourCard extends StatelessWidget {
  const _HourCard({
    required this.title,
    required this.value,
    required this.hours,
    required this.peak,
  });
  final String title;
  final String value;
  final List<int> hours;
  final int peak;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.bodyEmph.copyWith(fontSize: 20, color: theme.ink),
          ),
          Text(
            title,
            style: theme.bodySoft.copyWith(fontSize: 13, color: theme.inkMuted),
          ),
          const SizedBox(height: 10),
          RepaintBoundary(
            child: CustomPaint(
              size: const Size(double.infinity, 44),
              painter: _HourPainter(
                hours,
                peak: peak,
                base: theme.ink.withValues(alpha: 0.16),
                hot: theme.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HourPainter extends CustomPainter {
  _HourPainter(this.v, {required this.peak, required this.base, required this.hot});
  final List<int> v;
  final int peak;
  final Color base;
  final Color hot;

  @override
  void paint(Canvas canvas, Size size) {
    final max = v.fold<int>(1, math.max);
    const gap = 3.0;
    final w = (size.width - gap * 23) / 24;
    for (var i = 0; i < 24; i++) {
      final h = math.max(3.0, size.height * v[i] / max);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w + gap), size.height - h, w, h),
          const Radius.circular(2),
        ),
        Paint()..color = i == peak ? hot : base,
      );
    }
  }

  @override
  bool shouldRepaint(_HourPainter old) =>
      old.peak != peak || old.base != base || old.hot != hot || !_same(old.v, v);

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
