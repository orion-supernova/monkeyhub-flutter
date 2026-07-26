import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/link_preview_service.dart';

/// Renders [text] with bare http/https URLs underlined and tap-routable
/// via [onLinkTap]. Falls back to plain Text when no URLs are present so
/// we avoid the RichText overhead in the common case.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
    required this.onLinkTap,
    this.trailing,
  });

  final String text;
  final TextStyle style;
  final TextStyle linkStyle;
  final void Function(String url) onLinkTap;

  /// Appended as the paragraph's last span. Used to reserve the room the
  /// bubble's timestamp needs at the end of the text, so a full last line wraps
  /// rather than running underneath it. Forces the rich path even when there
  /// are no URLs to linkify.
  final InlineSpan? trailing;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final matches = UrlDetector.matches(widget.text);
    if (matches.isEmpty) {
      final trailing = widget.trailing;
      if (trailing == null) return Text(widget.text, style: widget.style);
      return Text.rich(TextSpan(
        text: widget.text,
        children: [trailing],
        style: widget.style,
      ));
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onLinkTap(m.url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: widget.text.substring(m.start, m.end),
        style: widget.linkStyle,
        recognizer: recognizer,
      ));
      cursor = m.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    if (widget.trailing != null) spans.add(widget.trailing!);

    return Text.rich(
      TextSpan(children: spans, style: widget.style),
    );
  }
}
