/// The two system lines a huddle can leave in a room.
///
/// `huddle:ended:<durationMs>:<peopleCount>` is written by the backend, once,
/// and only if somebody besides the starter joined (so an empty huddle leaves
/// no trace for anyone else). `huddle:alone` NEVER exists on the server: it is
/// the starter's own device noting, locally, that nobody came ("You wanted to
/// talk · Nobody joined"), which costs zero writes and tells nobody else.
///
/// Pure Dart on purpose: the chat list's preview line and the transcript both
/// read it, and neither should need a widget tree to do so.
class HuddleHistory {
  const HuddleHistory({required this.duration, required this.people});

  final Duration duration;

  /// Everyone who was in it at some point, the starter included.
  final int people;

  static const String _prefix = 'huddle:ended:';

  /// The content of the local-only "nobody joined" row.
  static const String aloneContent = 'huddle:alone';

  /// [content] as a finished huddle, or null when it is any other message.
  static HuddleHistory? parse(String content) {
    if (!content.startsWith(_prefix)) return null;
    final parts = content.substring(_prefix.length).split(':');
    if (parts.length != 2) return null;
    final ms = int.tryParse(parts[0]);
    final n = int.tryParse(parts[1]);
    if (ms == null || n == null || ms < 0 || n < 1) return null;
    return HuddleHistory(duration: Duration(milliseconds: ms), people: n);
  }

  /// The wire form, for tests and for anything that has to write one.
  String get content =>
      '$_prefix${duration.inMilliseconds}:$people';

  static bool isAlone(String content) => content == aloneContent;

  /// Either line, for surfaces that cannot localize (a one-line preview).
  static bool isHuddleLine(String content) =>
      isAlone(content) || content.startsWith(_prefix);
}
