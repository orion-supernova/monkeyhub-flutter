import 'package:flutter/foundation.dart';

/// Rich-text runs over a message's `content` — the sidecar the server stores
/// beside the plain string, never markup inside it.
///
/// The design copies [MessageMention]'s reasoning wholesale: `content` is
/// reused verbatim as the push body, as `rooms.lastMessage` and as
/// `replyToPreview.contentPreview`, so a marker syntax would leak into all
/// three, and a client that predates the feature would render the markers as
/// prose. A sidecar span costs nothing anywhere the text is sliced — the
/// slices just render plain.
///
/// Unlike mentions, these spans CANNOT be re-derived from the text (there is
/// no literal token to find), so [start]/[end] are stored offsets — UTF-16
/// code units into the ORIGINAL `content`, half-open `[start, end)`. Nothing
/// may apply them to a rewritten string: `foldRuns` in `text_runs.dart` maps
/// them through its display transform instead, which is the entire reason
/// that transform records an offset map.

/// The closed set of span kinds, mirroring `FORMATTING_TYPES` in
/// `backend/convex/messages.ts`. Wire format is [name]; parsing an unknown
/// name drops the span (see [FormattingEntity.fromJson]) rather than throwing
/// — a message from a future client renders plain, never breaks.
enum FormattingType {
  bold,
  italic,
  strikethrough,
  underline,
  spoiler,
  link,
  code;

  /// What goes on the wire and into the disk cache.
  String get wire => name;

  /// Null for a name this build doesn't know — the caller drops the span.
  static FormattingType? parse(String? wire) {
    for (final t in FormattingType.values) {
      if (t.name == wire) return t;
    }
    return null;
  }
}

/// What stands in for spoiler text on any surface the reader has not touched
/// — a pin banner, a reply card, a quote in the action menu.
///
/// Mirrors `SPOILER_MASK` in `backend/convex/messages.ts`, which does the same
/// job for the push body and the room card, so a spoiler looks the same
/// whichever side rendered the line. A fixed run rather than one block per
/// character: the length of a spoiler is part of what it hides.
const String spoilerMask = '\u2592\u2592\u2592\u2592\u2592';

/// [content] with every spoiler span replaced by [spoilerMask].
///
/// For surfaces that show a message they are NOT rendering as a bubble — the
/// bubble itself veils the words in place and never needs this. Touching and
/// overlapping spans collapse into one mask, and offsets are clamped rather
/// than thrown on, because a preview line must never take a screen down.
String maskSpoilers(String content, List<FormattingEntity> formatting) {
  if (formatting.isEmpty) return content;
  final spans = <({int start, int end})>[];
  for (final f in formatting) {
    if (f.type != FormattingType.spoiler) continue;
    final start = f.start.clamp(0, content.length);
    final end = f.end.clamp(0, content.length);
    if (start < end) spans.add((start: start, end: end));
  }
  if (spans.isEmpty) return content;
  spans.sort((a, b) => a.start.compareTo(b.start));

  final out = StringBuffer();
  var cursor = 0;
  var openStart = spans.first.start;
  var openEnd = spans.first.end;
  void flush() {
    out
      ..write(content.substring(cursor, openStart))
      ..write(spoilerMask);
    cursor = openEnd;
  }

  for (final s in spans.skip(1)) {
    if (s.start <= openEnd) {
      if (s.end > openEnd) openEnd = s.end;
      continue;
    }
    flush();
    openStart = s.start;
    openEnd = s.end;
  }
  flush();
  out.write(content.substring(cursor));
  return out.toString();
}

/// One styled run of a message body. Immutable — an edit replaces the list.
@immutable
class FormattingEntity {
  const FormattingEntity({
    required this.start,
    required this.end,
    required this.type,
    this.url,
  });

  /// UTF-16 code-unit offsets into the message's original `content`,
  /// half-open: `content.substring(start, end)` is the styled text.
  final int start;
  final int end;
  final FormattingType type;

  /// The destination, present iff [type] is [FormattingType.link]. The
  /// visible text says whatever the sender typed; this is where a tap goes —
  /// which is exactly why the renderer confirms before opening it.
  final String? url;

  /// Null when the span names a type this build doesn't know, or is
  /// malformed — the caller filters those out and the text renders plain.
  /// Tolerant rather than throwing for the same reason `MessageTypeWire.parse`
  /// falls back to text: one bad span from a newer client must not take the
  /// whole transcript down with it.
  static FormattingEntity? fromJson(Map<String, dynamic> j) {
    final type = FormattingType.parse(j['type'] as String?);
    if (type == null) return null;
    final start = (j['start'] as num?)?.toInt();
    final end = (j['end'] as num?)?.toInt();
    if (start == null || end == null || start < 0 || end <= start) return null;
    return FormattingEntity(
      start: start,
      end: end,
      type: type,
      url: type == FormattingType.link ? j['url'] as String? : null,
    );
  }

  /// Parse a wire/cache list, dropping anything [fromJson] refuses. Returns
  /// `const []` for absent input so callers never branch on null.
  static List<FormattingEntity> parseList(Object? raw) {
    if (raw is! List) return const [];
    final out = <FormattingEntity>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final parsed = fromJson(e.cast<String, dynamic>());
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'type': type.wire,
        if (url != null) 'url': url,
      };

  @override
  bool operator ==(Object other) =>
      other is FormattingEntity &&
      other.start == start &&
      other.end == end &&
      other.type == type &&
      other.url == url;

  @override
  int get hashCode => Object.hash(start, end, type, url);

  @override
  String toString() =>
      'FormattingEntity(${type.name} [$start,$end)${url == null ? '' : ' $url'})';
}
