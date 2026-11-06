import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../calls/call_models.dart';
import '../../calls/widgets/call_chrome.dart' show kCallAcceptGreen;
import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/sheet_kit.dart';
import 'call_log_models.dart';
import 'call_row_tile.dart' show resolveSubject;
import 'calls_directory.dart';
import 'calls_format.dart';

/// One line of the details timeline.
class TimelineEvent {
  const TimelineEvent(this.label, this.at);
  final String label;
  final int at;
}

/// Builds the timeline from a row: Started, Rang, Answered (on a device), each
/// handoff, Ended. Pure, for tests.
List<TimelineEvent> buildTimeline(AppLocalizations l10n, CallLogEntry e) {
  final out = <TimelineEvent>[TimelineEvent(l10n.callsTabDetailsStarted, e.startedAt)];
  final rang = e.ringingAt;
  if (rang != null) out.add(TimelineEvent(l10n.callsTabDetailsRang, rang));
  final answered = e.answeredAt;
  if (answered != null) {
    final on = e.answeredOn;
    out.add(
      TimelineEvent(
        on == null || on.isEmpty
            ? l10n.callsTabDetailsAnswered
            : l10n.callsTabDetailsAnsweredOn(platformName(l10n, on)),
        answered,
      ),
    );
  }
  for (final h in e.handoffs) {
    out.add(
      TimelineEvent(l10n.callsTabDetailsMovedTo(platformName(l10n, h.platform)), h.at),
    );
  }
  out.add(TimelineEvent(l10n.callsTabDetailsEnded, e.endedAt));
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// The call details sheet: who, what, the timeline and (when the call
/// reported one) its connection quality, with the three ways back to the
/// person.
Future<void> showCallDetails(
  BuildContext context, {
  required CallLogEntry entry,
  required CallsDirectory directory,
  ChatApi? api,
  required void Function(CallMediaKind kind) onCall,
  required VoidCallback onMessage,
  bool? Function()? isFavourite,
  VoidCallback? onToggleFavourite,
  Listenable? refresh,
}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => CallDetailsSheet(
      entry: entry,
      directory: directory,
      api: api,
      onCall: onCall,
      onMessage: onMessage,
      isFavourite: isFavourite,
      onToggleFavourite: onToggleFavourite,
      refresh: refresh,
    ),
  );
}

class CallDetailsSheet extends StatelessWidget {
  const CallDetailsSheet({
    super.key,
    required this.entry,
    required this.directory,
    required this.onCall,
    required this.onMessage,
    this.api,
    this.isFavourite,
    this.onToggleFavourite,
    this.refresh,
  });

  /// Whether this call's person is pinned (null: nothing to pin, so no button),
  /// the toggle, and what to listen to so the label follows the change.
  final bool? Function()? isFavourite;
  final VoidCallback? onToggleFavourite;
  final Listenable? refresh;

  final CallLogEntry entry;
  final CallsDirectory directory;
  final ChatApi? api;
  final void Function(CallMediaKind kind) onCall;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final e = entry;
    final subject = resolveSubject(l10n, directory, api, e);
    final events = buildTimeline(l10n, e);
    final quality = qualityLine(l10n, e.qualitySamples);
    final detail = callDetail(l10n, e);
    return SheetFrame(
      showClose: true,
      maxHeightFraction: 0.92,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: subject.avatar(72)),
            const SizedBox(height: 12),
            Text(
              subject.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.displaySmall.copyWith(color: theme.ink),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(
                fontSize: 15,
                color: e.isMissed ? theme.danger : theme.inkMuted,
              ),
            ),
            if (e.wasAnswered && e.durationMs > 0) ...[
              const SizedBox(height: 2),
              Text(
                l10n.callsTabDetailsTalked(clockDuration(e.durationMs)),
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(fontSize: 14, color: theme.inkMuted),
              ),
            ],
            const SizedBox(height: 22),
            _Timeline(events: events, startedAt: e.startedAt),
            if (quality != null) ...[
              const SizedBox(height: 20),
              Text(
                l10n.callsTabQualityTitle,
                style: theme.bodyEmph.copyWith(fontSize: 15, color: theme.inkSoft),
              ),
              const SizedBox(height: 8),
              QualityStrip(samples: e.qualitySamples),
              const SizedBox(height: 8),
              Text(
                quality.text,
                style: theme.bodySoft.copyWith(fontSize: 14, color: theme.inkMuted),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SheetActionButton(
                    label: l10n.callsTabVoiceCall,
                    icon: CupertinoIcons.phone_fill,
                    tonal: true,
                    onTap: () => onCall(CallMediaKind.audio),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SheetActionButton(
                    label: l10n.callsTabVideoCall,
                    icon: CupertinoIcons.videocam_fill,
                    tonal: true,
                    onTap: () => onCall(CallMediaKind.video),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SheetActionButton(
              label: l10n.callsTabDetailsMessage,
              icon: CupertinoIcons.bubble_left_fill,
              onTap: onMessage,
            ),
            if (isFavourite != null && onToggleFavourite != null) ...[
              const SizedBox(height: 10),
              ListenableBuilder(
                listenable: refresh ?? const AlwaysStoppedAnimation<double>(0),
                builder: (context, _) {
                  final fav = isFavourite!();
                  if (fav == null) return const SizedBox.shrink();
                  return SheetActionButton(
                    label: fav ? l10n.callsTabFavRemove : l10n.callsTabFavAdd,
                    icon: fav ? CupertinoIcons.star_slash : CupertinoIcons.star,
                    tonal: true,
                    onTap: onToggleFavourite!,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events, required this.startedAt});
  final List<TimelineEvent> events;
  final int startedAt;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = theme.bodyEmph.copyWith(fontSize: 15.5, color: theme.ink);
    final time = theme.bodySoft.copyWith(
      fontSize: 14,
      color: theme.inkMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: CustomPaint(
                    painter: _RailPainter(
                      first: i == 0,
                      last: i == events.length - 1,
                      color: theme.ink.withValues(alpha: 0.18),
                      dot: i == events.length - 1 ? theme.inkMuted : theme.accent,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(events[i].label, style: label),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    i == 0
                        ? clockTime(context, events[i].at)
                        : '${clockTime(context, events[i].at)}  +${clockDuration(events[i].at - startedAt)}',
                    style: time,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.first,
    required this.last,
    required this.color,
    required this.dot,
  });
  final bool first;
  final bool last;
  final Color color;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final x = 8.0;
    final mid = size.height / 2;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!first) canvas.drawLine(Offset(x, 0), Offset(x, mid), line);
    if (!last) canvas.drawLine(Offset(x, mid), Offset(x, size.height), line);
    canvas.drawCircle(Offset(x, mid), 5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.first != first ||
      old.last != last ||
      old.color != color ||
      old.dot != dot;
}

/// The connection strip: one segment per 10 s bucket (folded to at most 60
/// segments), green / amber / red for 0 / 1 / 2.
class QualityStrip extends StatelessWidget {
  const QualityStrip({super.key, required this.samples});
  final List<int> samples;

  /// At most [max] values, each the worst of the buckets it covers.
  static List<int> fold(List<int> samples, {int max = 60}) {
    if (samples.length <= max) return samples;
    final out = <int>[];
    for (var i = 0; i < max; i++) {
      final from = (i * samples.length / max).floor();
      final to = math.max(from + 1, ((i + 1) * samples.length / max).floor());
      var worst = 0;
      for (var j = from; j < to && j < samples.length; j++) {
        worst = math.max(worst, samples[j]);
      }
      out.add(worst);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(double.infinity, 10),
        painter: _StripPainter(
          fold(samples),
          good: kCallAcceptGreen,
          fair: const Color(0xFFFFB020),
          poor: theme.danger,
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.values, {required this.good, required this.fair, required this.poor});
  final List<int> values;
  final Color good;
  final Color fair;
  final Color poor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const gap = 2.0;
    final w = (size.width - gap * (values.length - 1)) / values.length;
    final r = Radius.circular(math.min(w / 2, 3));
    for (var i = 0; i < values.length; i++) {
      final c = switch (values[i]) { 0 => good, 1 => fair, _ => poor };
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (w + gap), 0, math.max(w, 1), size.height),
          r,
        ),
        Paint()..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      !listEquals(old.values, values) || old.good != good || old.fair != fair || old.poor != poor;
}
