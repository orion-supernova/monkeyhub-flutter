import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/mention.dart';
import '../models/message_formatting.dart';
import '../services/link_preview_service.dart';
import 'code_chip_underlay.dart';
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
    this.mentionTint,
    this.onMentionTap,
    this.formatting = const [],
    this.codeStyle,
    this.codeBackground,
    this.codeBorder,
    this.onLinkEntityTap,
    this.spoilerContextId,
    this.spoilerCover,
    this.spoilerDust,
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

  /// Per-mentioned-user ink, layered over [mentionStyle] — the colour that
  /// person speaks in, in a group room that hands colours out. Null, or a null
  /// return for a given id, leaves the mention in [mentionStyle] exactly as
  /// before.
  ///
  /// Colour only. Weight, background and the deliberate absence of an
  /// underline stay with [mentionStyle], so a tinted mention is still visibly
  /// a mention and still tellable apart from a link.
  ///
  /// Never consulted for a mention of the reader: [selfMentionStyle] already
  /// draws that one the loudest, and repainting it in a speaker colour would
  /// quietly demote the one distinction the feature exists for.
  final Color? Function(String userId)? mentionTint;
  final void Function(String userId)? onMentionTap;

  /// The message's stored formatting spans, offsets into [text].
  final List<FormattingEntity> formatting;

  /// Full style for inline-code runs, merged over [style] — themes derive it
  /// via `FormattingSurface.codeStyle`. Null renders code runs as plain text
  /// (a caller that has no theme in reach, like a bare test).
  final TextStyle? codeStyle;

  /// Fill of the chip behind an inline-code run (see
  /// `FormattingSurface.codeBackground`). Null paints no chip at all — a
  /// caller with no theme in reach, like a bare test.
  ///
  /// Painted by `InlineCodeUnderlay`, a sibling BENEATH the paragraph, rather
  /// than by a WidgetSpan pill. The bubble's standing rule that the paragraph
  /// carries exactly one placeholder — the stamp spacer, whose sizing is
  /// load-bearing — is intact and is the reason for the underlay: nothing is
  /// added to the paragraph at all. It used to be a `TextStyle.background`
  /// paint, which honoured the same rule but could not do padding, a corner
  /// radius or an edge, and so painted a flush smear the height of the line
  /// box.
  final Color? codeBackground;

  /// Hairline around the inline-code chip (see
  /// `FormattingSurface.codeBorder`). Null draws fill only. On dark themes
  /// this edge, not the fill, is what makes the chip readable.
  final Color? codeBorder;

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

  /// The opaque plate under the spoiler's dust (see
  /// `FormattingSurface.spoilerCover`). Falls back to the body style's own
  /// colour, so a spoiler is never accidentally legible just because a caller
  /// forgot the theme plumbing.
  final Color? spoilerCover;

  /// Ink of the spoiler's dust motes (see `FormattingSurface.spoilerDust`).
  /// Falls back to [spoilerCover]'s own resolution, which yields a plate with
  /// invisible dust — concealment intact, effect absent.
  final Color? spoilerDust;

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

    // The overlay mounts whenever spoiler runs exist, revealed or not, and
    // owns the whole veiled/open cycle itself — because a revealed spoiler
    // heals back to dust after a hold, and a widget that had been unmounted
    // on reveal would have nothing left to do the healing. It paints nothing
    // and runs no ticker while the words are simply readable.
    //
    // The paragraph renders the real text underneath either way: layout must
    // be true so the bubble is the right size and the reveal uncovers words
    // that were always exactly there.
    final contextId = widget.spoilerContextId;
    final veiled = fold.spoilerRanges.isNotEmpty;
    final chipped =
        widget.codeBackground != null && fold.codeRanges.isNotEmpty;

    // The key is what both overlays measure against, so it goes on only when
    // one of them is mounted. Kept conditional rather than always-on because
    // flipping it null↔non-null remounts the Text element: acceptable once, at
    // reveal, and pure waste on every plain paragraph in a long transcript.
    final paragraph = Text.rich(
      TextSpan(children: spans, style: widget.style),
      key: veiled || chipped ? _paragraphKey : null,
    );
    if (!veiled && !chipped) return paragraph;

    // The paragraph stays the only non-positioned child, so the Stack keeps
    // hugging the text exactly as it did before either overlay existed.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (chipped)
          Positioned.fill(
            child: InlineCodeUnderlay(
              paragraphKey: _paragraphKey,
              ranges: fold.codeRanges,
              fill: widget.codeBackground!,
              border: widget.codeBorder,
            ),
          ),
        paragraph,
        if (veiled)
          Positioned.fill(
            child: SpoilerOverlay(
              paragraphKey: _paragraphKey,
              ranges: fold.spoilerRanges,
              contextId: contextId ?? '',
              cover: widget.spoilerCover ?? widget.style.color ?? Colors.black,
              dust: widget.spoilerDust ??
                  widget.spoilerCover ??
                  widget.style.color ??
                  Colors.black,
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
        final id = m.userId;
        if (!isSelf && id != null) {
          final tint = widget.mentionTint?.call(id);
          if (tint != null) {
            style = (style ?? const TextStyle()).copyWith(color: tint);
          }
        }
      }
    }

    if (run.styles.contains(FormattingType.code)) {
      final code = widget.codeStyle;
      if (code != null) style = style?.merge(code) ?? code;
      // No `background:` here. The chip is drawn by InlineCodeUnderlay, and a
      // paint drawn as well would put square corners out past the rounded
      // ones.
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
