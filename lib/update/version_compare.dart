/// Compares two MonkeyHub version strings numerically, segment by segment.
///
/// Returns <0 when [a] is older than [b], 0 when they're equivalent, >0 when
/// [a] is newer.
///
/// Numeric, not lexicographic — the whole point. This project's release cadence
/// runs the patch number well past 9 (`1.3.9` → `1.3.10` → … → `1.3.29`), where
/// a string compare would decide 1.3.9 is *newer* than 1.3.10 and quietly stop
/// prompting anyone.
///
/// Everything from the first `+` or `-` is discarded, so `1.3.29+1` and
/// `1.3.29` are equal. Deliberate: the build suffix is pinned at `+1` forever
/// by convention (see deploy.sh's version bump), and Android's versionCode is
/// derived from the three-part version, so the display version is the only
/// signal that ever moves.
///
/// Missing segments read as 0 (`1.3` == `1.3.0`), and so does anything
/// non-numeric — a malformed version sorts as old rather than throwing, since
/// the caller's failure mode for an exception would be an unprompted user.
int compareVersions(String a, String b) {
  final pa = _segments(a);
  final pb = _segments(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

List<int> _segments(String version) {
  var core = version.trim();
  for (final sep in const ['+', '-']) {
    final at = core.indexOf(sep);
    if (at >= 0) core = core.substring(0, at);
  }
  return core
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList(growable: false);
}
