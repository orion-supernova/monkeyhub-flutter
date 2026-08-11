/// The one place a message body's decorations — auto-detected URLs, mentions,
/// and stored formatting spans — are reconciled into a flat list of styled
/// runs that `LinkifiedText` can paint.
///
/// ── Why a fold, and why an offset map ──────────────────────────────────────
///
/// Two coordinate systems collide here. Mentions and URLs are re-detected
/// from whatever string is on screen, but formatting entities are STORED
/// offsets into the ORIGINAL `content` (they have no literal token to
/// re-find). The bubble, meanwhile, rewrites the string it renders when the
/// user keeps link URLs hidden — the old `_stripUrls` — which would shift
/// every stored offset out from under its span.
///
/// So the rewrite lives here now, as [DisplayTransform]: the same strip +
/// whitespace-collapse the bubble always did, performed while recording,
/// for every surviving character, which original character it was. Every
/// decoration is located against the ORIGINAL text and mapped through that
/// record into display coordinates — one coordinate space at the end, and no
/// span ever applied to a string it wasn't measured against.
///
/// The old `_merge` dropped any overlapping decoration, which was right for
/// URL-vs-mention and wrong for formatting: bold-inside-italic is legitimate
/// nesting. [foldRuns] instead splits the text at every decoration boundary
/// and gives each atomic run the UNION of the styles covering it, plus at
/// most one interactive owner.
library;

import '../models/mention.dart';
import '../models/message_formatting.dart';
import '../services/link_preview_service.dart';

/// The display string a message body renders, plus the record of where each
/// surviving character came from.
class DisplayTransform {
  const DisplayTransform._(this.text, this._originOf);

  /// What the paragraph actually shows.
  final String text;

  /// `_originOf[i]` = index in the original string of display character `i`;
  /// null when [text] IS the original (identity — the common case, kept as
  /// null so it costs nothing).
  final List<int>? _originOf;

  /// Replicates the bubble's historical rewrite exactly, mapping included:
  ///
  ///  * nothing hidden → the original text untouched, except an optional
  ///    [trimRight] (what the bubble always applied before handing the text
  ///    to the paragraph);
  ///  * with [hidden] ranges (the auto-URL matches, when the user keeps URLs
  ///    hidden) → drop those ranges, collapse `[ \t]+` runs to one space,
  ///    drop spaces touching a newline, then trim — the exact `_stripUrls`
  ///    pipeline, step for step, because every text bubble ever sent renders
  ///    through this and "almost the same string" is a visible regression.
  factory DisplayTransform.of(
    String original, {
    List<UrlMatch> hidden = const [],
    bool trimRight = false,
  }) {
    if (hidden.isEmpty) {
      if (!trimRight) return DisplayTransform._(original, null);
      final trimmed = original.trimRight();
      // Still an identity map for every index that survives; the map is only
      // needed when characters in the MIDDLE can vanish.
      return DisplayTransform._(trimmed, null);
    }

    // 1. Drop the hidden ranges, carrying each survivor's original index.
    //    Ranges come from UrlDetector in document order and never overlap.
    final chars = <int>[]; // code units
    final origin = <int>[];
    var h = 0;
    for (var i = 0; i < original.length; i++) {
      while (h < hidden.length && hidden[h].end <= i) {
        h++;
      }
      if (h < hidden.length && i >= hidden[h].start && i < hidden[h].end) {
        continue;
      }
      chars.add(original.codeUnitAt(i));
      origin.add(i);
    }

    bool isSpaceOrTab(int u) => u == 0x20 || u == 0x09;
    const nl = 0x0A;

    // 2. Collapse `[ \t]+` to a single space. The survivor keeps the run's
    //    first original index — any index inside the run maps to the same
    //    display position either way.
    final c2 = <int>[];
    final o2 = <int>[];
    for (var i = 0; i < chars.length; i++) {
      if (isSpaceOrTab(chars[i])) {
        if (c2.isNotEmpty && isSpaceOrTab(c2.last)) continue;
        c2.add(0x20); // a lone tab becomes a space, exactly as the regex did
        o2.add(origin[i]);
      } else {
        c2.add(chars[i]);
        o2.add(origin[i]);
      }
    }

    // 3. ` *\n *` → `\n`: after step 2 a whitespace run is a single space, so
    //    this is "drop any space that touches a newline".
    final c3 = <int>[];
    final o3 = <int>[];
    for (var i = 0; i < c2.length; i++) {
      if (isSpaceOrTab(c2[i])) {
        final prevIsNl = c3.isNotEmpty && c3.last == nl;
        final nextIsNl = i + 1 < c2.length && c2[i + 1] == nl;
        if (prevIsNl || nextIsNl) continue;
      }
      c3.add(c2[i]);
      o3.add(o2[i]);
    }

    // 4. Trim, with Dart's own definition of trimmable — computed by asking
    //    Dart, so this can never disagree with what `.trim()` used to do.
    var s = String.fromCharCodes(c3);
    var lead = s.length - s.trimLeft().length;
    var keep = s.trimRight().length - lead;
    if (keep < 0) keep = 0;
    final text = s.substring(lead, lead + keep);
    final map = o3.sublist(lead, lead + keep);
    return DisplayTransform._(text, map);
  }

  /// Maps a half-open original-coordinate range into display coordinates, or
  /// null when nothing of it survived the rewrite (a span living entirely
  /// inside a stripped URL, say).
  ({int start, int end})? mapRange(int start, int end) {
    final map = _originOf;
    if (map == null) {
      final s = start.clamp(0, text.length);
      final e = end.clamp(0, text.length);
      return s < e ? (start: s, end: e) : null;
    }
    final s = _lowerBound(map, start);
    final e = _lowerBound(map, end);
    return s < e ? (start: s, end: e) : null;
  }

  /// First index in ascending [sorted] whose value is >= [value].
  static int _lowerBound(List<int> sorted, int value) {
    var lo = 0, hi = sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (sorted[mid] < value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

/// One tappable decoration — exactly one of the three fields is set. A run
/// points at its owner by index so a link split in half by a bold boundary
/// still gets ONE gesture recognizer.
class RunOwner {
  const RunOwner.autoUrl(String this.autoUrl)
      : linkUrl = null,
        mention = null;
  const RunOwner.link(String this.linkUrl)
      : autoUrl = null,
        mention = null;
  const RunOwner.of(MentionMatch this.mention)
      : autoUrl = null,
        linkUrl = null;

  /// A bare URL the text itself spells out — tap opens directly, because the
  /// visible text IS the destination.
  final String? autoUrl;

  /// A formatting link entity: arbitrary visible text carrying a URL — tap
  /// confirms before opening, because the visible text says nothing about
  /// where it goes.
  final String? linkUrl;
  final MentionMatch? mention;
}

/// One atomic slice of the display text: every character in it carries the
/// same styles, the same spoiler-ness, and the same (or no) tap owner.
class StyledRun {
  const StyledRun({
    required this.start,
    required this.end,
    required this.styles,
    required this.spoiler,
    required this.ownerIndex,
  });

  /// Display coordinates, half-open. Runs tile `[0, displayText.length)`.
  final int start;
  final int end;

  /// The pure-TextStyle layers: bold / italic / strikethrough / underline /
  /// code. Never contains `spoiler` or `link` — those change behaviour, not
  /// just paint, and have their own fields.
  final Set<FormattingType> styles;
  final bool spoiler;

  /// Index into [FoldedText.owners], or null for plain text.
  final int? ownerIndex;

  bool get isPlain => styles.isEmpty && !spoiler && ownerIndex == null;
}

/// Everything `LinkifiedText` needs to paint a message body.
class FoldedText {
  const FoldedText({
    required this.displayText,
    required this.runs,
    required this.owners,
    required this.spoilerRanges,
  });

  final String displayText;
  final List<StyledRun> runs;
  final List<RunOwner> owners;

  /// Maximal contiguous spoiler stretches in display coordinates — what the
  /// dust overlay covers, one entry per visually continuous veil.
  final List<({int start, int end})> spoilerRanges;

  /// Nothing to enrich: one plain run and no owners. The fast path that keeps
  /// the overwhelmingly common unformatted message on `Text` instead of
  /// `Text.rich`.
  bool get plain =>
      owners.isEmpty && runs.every((r) => r.styles.isEmpty && !r.spoiler);
}

/// Reconciles every decoration on a message body into [FoldedText].
///
/// [urls] and [mentions] must have been detected against [text] — the
/// ORIGINAL content — not against any rewritten form; the fold does the
/// rewriting itself. Interactive conflicts resolve in a fixed order:
///
///  * an explicit link entity beats an overlapping auto-URL — the sender said
///    what this text is, and two tap targets on one word is a coin toss;
///  * an auto-URL beats a mention inside it (the old `_merge` rule:
///    `https://x.com/@bob` is a link that happens to contain an at-sign);
///  * a mention inside a link entity is dropped, same tap-target argument.
///
/// Style spans (bold/italic/…/code) and spoilers overlap everything freely.
FoldedText foldRuns({
  required String text,
  required List<UrlMatch> urls,
  required List<MentionMatch> mentions,
  required List<FormattingEntity> entities,
  required bool hideAutoUrls,
  bool trimRight = false,
}) {
  final transform = DisplayTransform.of(
    text,
    hidden: hideAutoUrls ? urls : const [],
    trimRight: trimRight,
  );
  final display = transform.text;

  bool overlaps(int aS, int aE, int bS, int bE) => aS < bE && bS < aE;

  final linkEntities = [
    for (final e in entities)
      if (e.type == FormattingType.link && e.url != null) e,
  ];

  // Hidden auto-URLs have no display presence at all; visible ones lose any
  // stretch an explicit link entity claims.
  final liveUrls = hideAutoUrls
      ? const <UrlMatch>[]
      : [
          for (final u in urls)
            if (!linkEntities.any((e) => overlaps(u.start, u.end, e.start, e.end))) u,
        ];
  final liveMentions = [
    for (final m in mentions)
      if (!urls.any((u) => !hideAutoUrls && overlaps(m.start, m.end, u.start, u.end)) &&
          !linkEntities.any((e) => overlaps(m.start, m.end, e.start, e.end)))
        m,
  ];

  // Owners with their display ranges; anything the rewrite erased is dropped.
  final owners = <RunOwner>[];
  final ownerRanges = <({int start, int end})>[];
  void addOwner(RunOwner owner, int start, int end) {
    final r = transform.mapRange(start, end);
    if (r == null) return;
    owners.add(owner);
    ownerRanges.add(r);
  }

  for (final e in linkEntities) {
    addOwner(RunOwner.link(e.url!), e.start, e.end);
  }
  for (final u in liveUrls) {
    addOwner(RunOwner.autoUrl(u.url), u.start, u.end);
  }
  for (final m in liveMentions) {
    addOwner(RunOwner.of(m), m.start, m.end);
  }

  // Style and spoiler spans, mapped the same way.
  final styleRanges = <({int start, int end, FormattingType type})>[];
  final spoilerSpans = <({int start, int end})>[];
  for (final e in entities) {
    switch (e.type) {
      case FormattingType.bold:
      case FormattingType.italic:
      case FormattingType.strikethrough:
      case FormattingType.underline:
      case FormattingType.code:
        final r = transform.mapRange(e.start, e.end);
        if (r != null) {
          styleRanges.add((start: r.start, end: r.end, type: e.type));
        }
      case FormattingType.spoiler:
        final r = transform.mapRange(e.start, e.end);
        if (r != null) spoilerSpans.add(r);
      case FormattingType.link:
        break; // already an owner
    }
  }

  // Boundary split: every start/end of everything, deduplicated and sorted.
  final boundaries = <int>{0, display.length};
  for (final r in ownerRanges) {
    boundaries
      ..add(r.start)
      ..add(r.end);
  }
  for (final r in styleRanges) {
    boundaries
      ..add(r.start)
      ..add(r.end);
  }
  for (final r in spoilerSpans) {
    boundaries
      ..add(r.start)
      ..add(r.end);
  }
  final cuts = boundaries.where((b) => b >= 0 && b <= display.length).toList()
    ..sort();

  final runs = <StyledRun>[];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final a = cuts[i], b = cuts[i + 1];
    if (a >= b) continue;
    final styles = <FormattingType>{
      for (final r in styleRanges)
        if (r.start <= a && b <= r.end) r.type,
    };
    final spoiler = spoilerSpans.any((r) => r.start <= a && b <= r.end);
    int? ownerIndex;
    for (var o = 0; o < ownerRanges.length; o++) {
      if (ownerRanges[o].start <= a && b <= ownerRanges[o].end) {
        ownerIndex = o;
        break; // first covering owner wins — see the conflict order above
      }
    }
    runs.add(StyledRun(
      start: a,
      end: b,
      styles: styles,
      spoiler: spoiler,
      ownerIndex: ownerIndex,
    ));
  }
  if (runs.isEmpty && display.isNotEmpty) {
    runs.add(StyledRun(
      start: 0,
      end: display.length,
      styles: const {},
      spoiler: false,
      ownerIndex: null,
    ));
  }

  // Merge touching spoiler runs into the veils the overlay will draw.
  final veils = <({int start, int end})>[];
  for (final r in runs) {
    if (!r.spoiler) continue;
    if (veils.isNotEmpty && veils.last.end == r.start) {
      veils[veils.length - 1] = (start: veils.last.start, end: r.end);
    } else {
      veils.add((start: r.start, end: r.end));
    }
  }

  return FoldedText(
    displayText: display,
    runs: runs,
    owners: owners,
    spoilerRanges: veils,
  );
}
