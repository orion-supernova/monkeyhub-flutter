/// A stopwatch reading: `m:ss` under an hour, `h:mm:ss` from an hour up.
///
/// Negative durations clamp to zero. Deliberately not localized: digits and
/// colons are what a clock looks like in every locale this app ships in.
String formatClock(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}
