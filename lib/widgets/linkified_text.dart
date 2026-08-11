import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/spoiler_store.dart';
import '../models/mention.dart';
import '../models/message_formatting.dart';
import '../services/link_preview_service.dart';
import 'spoiler_overlay.dart';
import 'text_runs.dart';

/// Renders a message body: bare URLs underlined and tap-routable via
/// [onLinkTap], @-mentions highlighted and tap-routable via [onMentionTap],
/// and the message's stored [formatting] spans — bold, italic, strikethrough,
/// underline, inline code, spoilers, and link entities — folded over the
/// same text. Falls back to plain [Text] when there is nothing to enrich, so
/// the overwhelmingly common unformatted message never pays for RichText.
///
/// All reconciliation lives in [foldRuns] (see `text_runs.dart`): decorations
/// are located against the ORIGINAL text, the URL-hiding rewrite happens
/// inside the fold with an offset map, and this widget only turns the
/// resulting runs into spans. That replaces the old two-list `_merge`, whose
/// drop-any-overlap rule was right for URL-vs-mention and wrong for
/// formatting — bold-inside-italic is nesting, not a conflict.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
    required this.onLinkTap,
    this.trailing,
    this.linkifyUrls = true,
    this.hideAutoUrls = false,
    this.trimRight = false,
    this.mentionHandles = const {},
    this.mentionsEveryone = false,
    this.selfUserId,
    this.mentionStyle,
    this.selfMentionStyle,
    this.onMentionTap,
    this.formatting = const [],
    this.codeStyle,
    this.codeBackground,
    this.onLinkEntityTap,
    this.spoilerContextId,
    this.spoilerCover,
  });

  /// The ORIGINAL message content. Never pre-stripped or pre-trimmed by the
  /// caller: [formatting] offsets index into this exact string, and the fold
  /// owns every rewrite ([hideAutoUrls], [trimRight]) precisely so those
  /// offsets are mapped rather than broken.
  final String text;
  final TextStyle style;
  final TextStyle linkStyle;
  final void Function(String url) onLinkTap;

  /// Appended as the paragraph's last span. Used to reserve the room the
  /// bubble's timestamp needs at the end of the text, so a full last line wraps
  /// rather than running underneath it. Forces the rich path even when there
  /// is nothing else to enrich.
  final InlineSpan? trailing;

  /// Pass false for text that has never been linkified — media captions and
  /// system notices — so this widget can serve them without silently giving
  /// them URL detection they didn't have before.
  final bool linkifyUrls;

  /// When true, detected URLs are removed from the rendered text (the
  /// user's "hide link URLs" preference) — the rewrite the bubble used to do
  /// itself with `_stripUrls`, now performed inside the fold so stored
  /// formatting offsets survive it.
  final bool hideAutoUrls;

  /// Drop trailing whitespace from the rendered text — what the bubble always
  /// did before handing text to the paragraph, so a trailing newline can't
  /// push the stamp onto a line of its own.
  final bool trimRight;

  /// The handles to look for, keyed by the user each belongs to. Comes from the
  /// message's own resolved mention list, so an `@bob` nobody actually sent is
  /// left as plain text.
  final Map<String, String> mentionHandles;
  final bool mentionsEveryone;

  /// The reader. Their own mention is drawn differently from everyone else's —
  /// separating "someone was named" from "you were named" is the entire point
  /// of the feature.
  final String? selfUserId;

  final TextStyle? mentionStyle;
  final TextStyle? selfMentionStyle;
  final void Function(String userId)? onMentionTap;

  /// The message's stored formatting spans, offsets into [text].
  final List<FormattingEntity> formatting;

  /// Full style for inline-code runs, merged over [style] — themes derive it
  /// via `FormattingSurface.codeStyle`. Null renders code runs as plain text
  /// (a caller that has no theme in reach, like a bare test).
  final TextStyle? codeStyle;

  /// The chip wash behind an inline-code run, painted with
  /// `TextStyle.background` — a paint, not a WidgetSpan, per the bubble's
  /// standing rule that the paragraph carries exactly one placeholder (the
  /// stamp spacer) whose sizing is load-bearing.
  final Color? codeBackground;

  /// Tap handler for link ENTITIES — text whose visible words differ from
  /// their destination. Separate from [onLinkTap] so the bubble can route
  /// these through a confirmation (the visible text says nothing about where
  /// they go) while bare URLs keep their direct open. Falls back to
  /// [onLinkTap] when null.
  final void Function(String url)? onLinkEntityTap;

  /// What keys this message's spoiler reveal in the session store — the
  /// message id. Spoiler text always renders veiled; without a stable id the
  /// reveal just doesn't outlive the next rebuild, so callers should pass it
  /// wherever a message id exists.
  final String? spoilerContextId;

  /// Veil ink (see `FormattingSurface.spoilerCover`). Falls back to the body
  /// style's own colour, so a spoiler is never accidentally legible just
  /// because a caller forgot the theme plumbing.
  final Color? spoilerCover;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  /// On the paragraph only while a veil is up — the overlay resolves it to
  /// the RenderParagraph to measure real glyph boxes.
  final GlobalKey _paragraphKey = GlobalKey();

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

    final fold = foldRuns(
      text: widget.text,
      urls: urls,
      mentions: mentions,
      entities: widget.formatting,
      hideAutoUrls: widget.hideAutoUrls && widget.linkifyUrls,
      trimRight: widget.trimRight,
    );

    if (fold.plain) {
      final trailing = widget.trailing;
      if (trailing == null) return Text(fold.displayText, style: widget.style);
      return Text.rich(TextSpan(
        text: fold.displayText,
        children: [trailing],
        style: widget.style,
      ));
    }

    // One recognizer per OWNER, not per run — a link split in half by a bold
    // boundary is still one tap target. Built lazily so an owner whose runs
    // were all consumed by a higher-priority neighbour allocates nothing.
    final recognizers = List<TapGestureRecognizer?>.filled(
      fold.owners.length,
      null,
    );
    TapGestureRecognizer? recognizerFor(int index) {
      final existing = recognizers[index];
      if (existing != null) return existing;
      final owner = fold.owners[index];
      VoidCallback? onTap;
      final autoUrl = owner.autoUrl;
      final linkUrl = owner.linkUrl;
      final mention = owner.mention;
      if (autoUrl != null) {
        onTap = () => widget.onLinkTap(autoUrl);
      } else if (linkUrl != null) {
        final handler = widget.onLinkEntityTap ?? widget.onLinkTap;
        onTap = () => handler(linkUrl);
      } else if (mention != null) {
        // `@everyone` names nobody, so there is no profile to open. A tap
        // that can only be refused is worse than no tap at all.
        final id = mention.userId;
        final tap = widget.onMentionTap;
        if (id != null && tap != null) onTap = () => tap(id);
      }
      if (onTap == null) return null;
      final r = TapGestureRecognizer()..onTap = onTap;
      _recognizers.add(r);
      recognizers[index] = r;
      return r;
    }

    final spans = <InlineSpan>[];
    for (final run in fold.runs) {
      final slice = fold.displayText.substring(run.start, run.end);
      if (run.isPlain) {
        spans.add(TextSpan(text: slice));
        continue;
      }
      spans.add(TextSpan(
        text: slice,
        style: _styleFor(run, fold),
        recognizer:
            run.ownerIndex == null ? null : recognizerFor(run.ownerIndex!),
      ));
    }
    if (widget.trailing != null) spans.add(widget.trailing!);

    // A veil goes up whenever unrevealed spoiler runs exist. The paragraph
    // still renders the real text underneath — layout must be true so the
    // bubble is the right size and the wipe uncovers words that were always
    // exactly there; the overlay's near-opaque fill is the concealment.
    final contextId = widget.spoilerContextId;
    final veiled = fold.spoilerRanges.isNotEmpty &&
        !(contextId != null && SpoilerStore.instance.isRevealed(contextId));

    final paragraph = Text.rich(
      TextSpan(children: spans, style: widget.style),
      key: veiled ? _paragraphKey : null,
    );
    if (!veiled) return paragraph;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        paragraph,
        Positioned.fill(
          child: SpoilerOverlay(
            paragraphKey: _paragraphKey,
            ranges: fold.spoilerRanges,
            contextId: contextId ?? '',
            cover: widget.spoilerCover ?? widget.style.color ?? Colors.black,
            onRevealed: () {
              if (mounted) setState(() {});
            },
          ),
        ),
      ],
    );
  }

  /// The one style a run paints with: owner ink first, then the formatting
  /// layers folded over it, so bold-inside-a-link stays a bold link.
  TextStyle? _styleFor(StyledRun run, FoldedText fold) {
    TextStyle? style;

    final ownerIndex = run.ownerIndex;
    if (ownerIndex != null) {
      final owner = fold.owners[ownerIndex];
      if (owner.autoUrl != null || owner.linkUrl != null) {
        style = widget.linkStyle;
      } else if (owner.mention != null) {
        final m = owner.mention!;
        final isSelf = m.isEveryone ||
            (m.userId != null && m.userId == widget.selfUserId);
        style = isSelf ? widget.selfMentionStyle : widget.mentionStyle;
      }
    }

    if (run.styles.contains(FormattingType.code)) {
      final code = widget.codeStyle;
      if (code != null) style = style?.merge(code) ?? code;
      final wash = widget.codeBackground;
      if (wash != null) {
        style = (style ?? const TextStyle())
            .copyWith(background: Paint()..color = wash);
      }
    }
    if (run.styles.contains(FormattingType.bold)) {
      style = (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700);
    }
    if (run.styles.contains(FormattingType.italic)) {
      style = (style ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);
    }

    // Decorations COMBINE rather than overwrite: a struck link keeps its
    // underline, underline+strikethrough draws both lines.
    final decorations = <TextDecoration>[
      if (style?.decoration != null) style!.decoration!,
      if (run.styles.contains(FormattingType.strikethrough))
        TextDecoration.lineThrough,
      if (run.styles.contains(FormattingType.underline))
        TextDecoration.underline,
    ];
    if (decorations.isNotEmpty) {
      style = (style ?? const TextStyle())
          .copyWith(decoration: TextDecoration.combine(decorations));
    }
    return style;
  }
}
