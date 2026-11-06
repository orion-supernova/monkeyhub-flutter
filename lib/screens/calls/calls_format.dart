import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../format/duration_format.dart';
import 'call_log_models.dart';

/// The Calls tab's "now": what Today, Yesterday and "this week" are measured
/// from. A test pins it, so a fixture written on one day still reads the same
/// after midnight.
DateTime Function() callsClock = DateTime.now;

/// `m:ss`, or `h:mm:ss` from an hour up: the clock a call is read off.
String clockDuration(int ms) {
  return formatClock(Duration(seconds: (ms / 1000).round()));
}

/// Talk time for a header: "3h 20m", "12m", "40s".
String talkDuration(AppLocalizations l10n, int ms) {
  final minutes = ms ~/ 60000;
  if (minutes >= 60) return l10n.callsTabDurationHM(minutes ~/ 60, minutes % 60);
  if (minutes >= 1) return l10n.callsTabDurationM(minutes);
  return l10n.callsTabDurationS((ms ~/ 1000).clamp(0, 59));
}

/// The clock time of [ms], 12 or 24 hour as the phone is set.
String clockTime(BuildContext context, int ms) {
  final t = TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ms));
  return MaterialLocalizations.of(context).formatTimeOfDay(
    t,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// A day header: Today, Yesterday, then the date.
String dayLabel(BuildContext context, DateTime day, {DateTime? now}) {
  final l10n = AppLocalizations.of(context);
  final n = now ?? callsClock();
  final today = DateTime(n.year, n.month, n.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.callsTabToday;
  if (diff == 1) return l10n.callsTabYesterday;
  return MaterialLocalizations.of(context).formatFullDate(day);
}

/// Device name for a `userDevices.platform` value.
String platformName(AppLocalizations l10n, String platform) =>
    switch (platform) {
      'ios' => l10n.callsTabPlatformIos,
      'macos' => l10n.callsTabPlatformMacos,
      'android' => l10n.callsTabPlatformAndroid,
      'windows' => l10n.callsTabPlatformWindows,
      'linux' => l10n.callsTabPlatformLinux,
      'web' => l10n.callsTabPlatformWeb,
      _ => platform,
    };

/// The row's second line: type and how it went.
String callDetail(AppLocalizations l10n, CallLogEntry e) {
  final String base;
  if (e.kind == CallLogKind.huddle) {
    base = l10n.callsTabHuddle;
  } else if (e.kind == CallLogKind.group &&
      e.outcome == CallOutcome.answered) {
    // "Incoming" says nothing about a group call (several people rang it, or
    // nobody did); the people count beside it is the useful part, and the
    // shorter line keeps the duration from being cut off.
    base = e.video ? l10n.callsTabVideoCall : l10n.callsTabVoiceCall;
  } else {
    base = switch (e.outcome) {
      CallOutcome.answered => e.incoming
          ? (e.video ? l10n.callsTabInVideo : l10n.callsTabInAudio)
          : (e.video ? l10n.callsTabOutVideo : l10n.callsTabOutAudio),
      CallOutcome.missed =>
        e.video ? l10n.callsTabMissedVideo : l10n.callsTabMissedAudio,
      CallOutcome.unanswered => l10n.callsTabNoAnswer,
      CallOutcome.declined => l10n.callsTabDeclined,
      CallOutcome.cancelled => l10n.callsTabCancelled,
    };
  }
  final people = e.people;
  if (e.kind != CallLogKind.direct && people != null && people > 1) {
    return '$base · ${l10n.callsTabPeople(people)}';
  }
  return base;
}

/// How much of a call was rough, and the sentence for it. Null for a call with
/// no report, so the details sheet hides the strip.
({String text, int roughPercent})? qualityLine(
  AppLocalizations l10n,
  List<int> samples,
) {
  if (samples.isEmpty) return null;
  var fair = 0, poor = 0;
  for (final s in samples) {
    if (s == 1) fair++;
    if (s >= 2) poor++;
  }
  final rough = ((fair + poor) * 100 / samples.length).round();
  if (fair + poor == 0) return (text: l10n.callsTabQualityGood, roughPercent: 0);
  if (poor > 0 && poor >= fair) {
    return (
      text: l10n.callsTabQualityPoor((poor * 100 / samples.length).round().clamp(1, 100)),
      roughPercent: rough,
    );
  }
  return (text: l10n.callsTabQualityFair(rough.clamp(1, 100)), roughPercent: rough);
}

/// Midnight of the first day of this week in the locale, for the talk-time
/// header. Flutter's index is 0 = Sunday ... 6 = Saturday.
DateTime weekStart(BuildContext context, {DateTime? now}) {
  final n = now ?? callsClock();
  final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  final today = DateTime(n.year, n.month, n.day);
  final dartWeekday = n.weekday % 7; // 0 = Sunday
  final back = (dartWeekday - first + 7) % 7;
  return DateTime(today.year, today.month, today.day - back);
}
