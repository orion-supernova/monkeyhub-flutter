import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Minimal JSON colouring for the detail pane.
///
/// One regex pass, no parsing: the body may be pretty-printed JSON, a redaction
/// summary, or a stack trace, and a highlighter that only works on the first of
/// those would fail exactly when it is needed. Anything unmatched falls through
/// as plain text.
///
/// Colours come from the active [AppTheme] rather than a fixed editor palette,
/// so this stays legible on the light themes as well as the dark ones.
List<TextSpan> highlightJson(String source, AppTheme theme) {
  if (source.isEmpty) return const [];

  final pattern = RegExp(
    // "key":            → identifier
    r'("(?:[^"\\]|\\.)*")\s*:'
    // "value"           → string
    r'|("(?:[^"\\]|\\.)*")'
    // <redacted …>      → the redactor's own markers, worth standing out
    r'|(<[a-z]+[^>]*>)'
    // true/false/null   → keyword
    r'|\b(true|false|null)\b'
    // numbers
    r'|(-?\d+\.?\d*)',
  );

  final spans = <TextSpan>[];
  var last = 0;

  for (final m in pattern.allMatches(source)) {
    if (m.start > last) {
      spans.add(TextSpan(text: source.substring(last, m.start)));
    }
    if (m.group(1) != null) {
      spans.add(
        TextSpan(
          text: m.group(1),
          style: TextStyle(color: theme.accent),
        ),
      );
      spans.add(const TextSpan(text: ':'));
    } else if (m.group(2) != null) {
      spans.add(
        TextSpan(
          text: m.group(2),
          style: TextStyle(color: theme.ink),
        ),
      );
    } else if (m.group(3) != null) {
      // Redaction markers are deliberately loud. Someone reading a log needs to
      // see instantly that a value was withheld rather than absent.
      spans.add(
        TextSpan(
          text: m.group(3),
          style: TextStyle(color: theme.inkMuted, fontStyle: FontStyle.italic),
        ),
      );
    } else if (m.group(4) != null) {
      spans.add(
        TextSpan(
          text: m.group(4),
          style: TextStyle(color: theme.danger),
        ),
      );
    } else if (m.group(5) != null) {
      spans.add(
        TextSpan(
          text: m.group(5),
          style: TextStyle(color: theme.success),
        ),
      );
    }
    last = m.end;
  }

  if (last < source.length) {
    spans.add(TextSpan(text: source.substring(last)));
  }
  return spans;
}
