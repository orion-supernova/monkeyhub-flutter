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
