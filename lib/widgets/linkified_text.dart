import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/mention.dart';
import '../services/link_preview_service.dart';

/// Renders [text] with bare http/https URLs underlined and tap-routable
/// via [onLinkTap], and any @-mentions it carries highlighted and tap-routable
/// via [onMentionTap]. Falls back to plain Text when there is nothing to
/// enrich so we avoid the RichText overhead in the common case.
///
/// Both kinds of span are produced by ONE ordered pass rather than by two
/// layered ones: they are located independently but share a single coordinate
/// space, and building them separately would mean applying the second set of
/// offsets to a string the first set had already rewritten.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
    required this.onLinkTap,
    this.trailing,
    this.linkifyUrls = true,
    this.mentionHandles = const {},
    this.mentionsEveryone = false,
    this.selfUserId,
    this.mentionStyle,
    this.selfMentionStyle,
    this.onMentionTap,
  });

  final String text;
  final TextStyle style;
  final TextStyle linkStyle;
  final void Function(String url) onLinkTap;

  /// Appended as the paragraph's last span. Used to reserve the room the
  /// bubble's timestamp needs at the end of the text, so a full last line wraps
  /// rather than running underneath it. Forces the rich path even when there
  /// are nothing else to enrich.
  final InlineSpan? trailing;

  /// Pass false for text that has never been linkified — media captions and
  /// system notices — so this widget can serve them without silently giving
  /// them URL detection they didn't have before.
  final bool linkifyUrls;

  /// The handles to look for, keyed by the user each belongs to. Comes from the
  /// message's own resolved mention list, so an `@bob` nobody actually sent is
  /// left as plain text.
  ///
  /// Detection happens in here, against [text], rather than being passed in
  /// pre-computed: the caller renders a string it may have rewritten (the
  /// bubble strips URLs out of it when the user has those hidden), and offsets
  /// found against the original would land in the wrong place.
  final Map<String, String> mentionHandles;
  final bool mentionsEveryone;

  /// The reader. Their own mention is drawn differently from everyone else's —
  /// separating "someone was named" from "you were named" is the entire point
  /// of the feature.
  final String? selfUserId;

  final TextStyle? mentionStyle;
  final TextStyle? selfMentionStyle;
  final void Function(String userId)? onMentionTap;

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

    final urls = widget.linkifyUrls
        ? UrlDetector.matches(widget.text)
        : const <UrlMatch>[];
    final mentions = MentionDetector.matches(
      widget.text,
      usernameById: widget.mentionHandles,
      everyone: widget.mentionsEveryone,
    );

    if (urls.isEmpty && mentions.isEmpty) {
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
    for (final m in _merge(urls, mentions)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      spans.add(m.url != null
          ? _linkSpan(m.start, m.end, m.url!)
          : _mentionSpan(m.start, m.end, m.mention!));
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

  TextSpan _linkSpan(int start, int end, String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => widget.onLinkTap(url);
    _recognizers.add(recognizer);
    return TextSpan(
      text: widget.text.substring(start, end),
      style: widget.linkStyle,
      recognizer: recognizer,
    );
  }

  TextSpan _mentionSpan(int start, int end, MentionMatch m) {
    final isSelf = m.isEveryone || (m.userId != null && m.userId == widget.selfUserId);
    final style = isSelf ? widget.selfMentionStyle : widget.mentionStyle;

    final id = m.userId;
    final onTap = widget.onMentionTap;
    TapGestureRecognizer? recognizer;
    // `@everyone` names nobody, so there is no profile to open. A tap that can
    // only be refused is worse than no tap at all.
    if (id != null && onTap != null) {
      recognizer = TapGestureRecognizer()..onTap = () => onTap(id);
      _recognizers.add(recognizer);
    }

    return TextSpan(
      text: widget.text.substring(start, end),
      style: style,
      recognizer: recognizer,
    );
  }

  /// Interleaves the two match lists into one ordered, non-overlapping run.
  ///
  /// A URL wins any collision: `https://x.com/@bob` is a link that happens to
  /// contain an at-sign, and highlighting half of it as a mention would break
  /// the tap target of the thing it's actually part of.
  static List<_Decorated> _merge(
    List<UrlMatch> urls,
    List<MentionMatch> mentions,
  ) {
    final all = <_Decorated>[
      for (final u in urls) _Decorated(u.start, u.end, url: u.url),
      for (final m in mentions) _Decorated(m.start, m.end, mention: m),
    ]..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        // Same start: the URL is taken and the mention inside it dropped below.
        return a.url != null ? -1 : 1;
      });

    final out = <_Decorated>[];
    for (final d in all) {
      if (out.isNotEmpty && d.start < out.last.end) continue;
      out.add(d);
    }
    return out;
  }
}

class _Decorated {
  const _Decorated(this.start, this.end, {this.url, this.mention});
  final int start;
  final int end;
  final String? url;
  final MentionMatch? mention;
}
