import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_message.dart';
import '../models/mention.dart';
import '../models/message_formatting.dart';
import 'text_runs.dart';

/// The composer's text controller, extended to know which `@handles` in the
/// field are real mentions and which stretches of it carry formatting.
///
/// It owns three things a plain [TextEditingController] can't:
///
///  * **The committed set.** A handle only counts once it has been picked from
///    the list. That set is what gets sent, and what the field tints.
///  * **Token-atomic backspace.** Deleting one character out of `@murat` would
///    otherwise leave `@mura` sitting in the message looking like a mention and
///    behaving like prose. One backspace takes the whole token, the way every
///    other chat app does it.
///  * **Formatting ranges.** Bold/italic/spoiler/link/… spans applied from the
///    selection toolbar. Unlike mentions these have no literal token to
///    re-derive from, so their offsets are REMAPPED through every text change
///    (see [_remapFormats]) — the one genuinely new bookkeeping obligation the
///    formatting feature brings, and the reason it lives here at the single
///    choke point every change flows through.
///
/// Mention correctness does not depend on the atomic delete: [prune]
/// re-derives the set from the text after every change, so any edit that
/// breaks a handle drops the mention it broke. Formatting has no such
/// re-derivation to fall back on; the remap must simply be right.
class MentionTextController extends TextEditingController {
  MentionTextController({super.text});

  final Map<String, String> _handles = {};
  bool _everyone = false;
  final List<_FormatRange> _formats = [];

  /// Painted behind completed handles in the field. Null disables tinting
  /// entirely, which is what keeps this usable from a test with no theme.
  Color? tint;

  Map<String, String> get handles => Map.unmodifiable(_handles);
  bool get everyone => _everyone;

  /// What [ChatRepository.sendText] wants.
  List<MessageMention> get mentions => [
        for (final e in _handles.entries)
          MessageMention(userId: e.key, username: e.value),
      ];

  bool get hasMentions => _handles.isNotEmpty || _everyone;

  void commit(String userId, String username) {
    _handles[userId] = username;
  }

  void commitEveryone() => _everyone = true;

  void clearMentions() {
    _handles.clear();
    _everyone = false;
  }

  /// Puts back a set that was taken away — the child-guard refusal path in
  /// `room_screen._send` restores the text it just cleared, and the mentions
  /// have to come back with it or the retry would deliver "@bob" to a Bob who
  /// is never told.
  void restoreMentions(List<MessageMention> ms, {bool everyone = false}) {
    _handles
      ..clear()
      ..addEntries(ms.map((m) => MapEntry(m.userId, m.username)));
    _everyone = everyone;
  }

  /// Drops every mention whose handle no longer appears in the text.
  void prune() {
    if (_handles.isNotEmpty) {
      final alive = MentionDetector.survivingIds(text, usernameById: _handles);
      _handles.removeWhere((id, _) => !alive.contains(id));
    }
    if (_everyone && !MentionDetector.everyoneSurvives(text)) _everyone = false;
  }

  // ───────────────────────── formatting ─────────────────────────

  /// The spans as the wire wants them, sorted by start. Empty ranges never
  /// exist (the remap drops them), so this needs no filtering.
  List<FormattingEntity> get formatting {
    final sorted = [..._formats]..sort((a, b) => a.start.compareTo(b.start));
    return [
      for (final f in sorted)
        FormattingEntity(start: f.start, end: f.end, type: f.type, url: f.url),
    ];
  }

  bool get hasFormatting => _formats.isNotEmpty;

  void clearFormatting() {
    if (_formats.isEmpty) return;
    _formats.clear();
    notifyListeners();
  }

  /// Puts back a set that was taken away — the same contract, and the same
  /// callers, as [restoreMentions]: the refusal path restores the text, and
  /// the bold has to come back with it or the retry sends the words plain.
  /// Also how edit mode loads a message's existing spans.
  void restoreFormatting(List<FormattingEntity> entities) {
    _formats
      ..clear()
      ..addAll([
        for (final e in entities)
          if (e.start < e.end)
            _FormatRange(e.start, e.end, e.type, url: e.url),
      ]);
    _clampAndCoalesce();
    notifyListeners();
  }

  /// Toggle [type] over [selection]: fully covered → remove it there,
  /// anything less → apply it there. The reading every editor's Cmd+B has
  /// taught people, so anything cleverer would just be wrong somewhere.
  ///
  /// Only for the pure style layers — [FormattingType.link] carries a URL and
  /// goes through [applyLink]/[removeLink] instead.
  void toggleFormat(FormattingType type, TextSelection selection) {
    assert(type != FormattingType.link, 'links go through applyLink');
    final range = _normalized(selection);
    if (range == null) return;
    final (s, e) = range;
    if (_isCovered(type, s, e)) {
      _removeType(type, s, e);
    } else {
      _formats.add(_FormatRange(s, e, type));
      _clampAndCoalesce();
    }
    notifyListeners();
  }

  /// Whether every character of [selection] already carries [type] — what the
  /// toolbar uses to draw a chip as active, and what [toggleFormat] branches
  /// on.
  bool selectionHas(FormattingType type, TextSelection selection) {
    final range = _normalized(selection);
    if (range == null) return false;
    return _isCovered(type, range.$1, range.$2);
  }

  /// The URL under [selection], when it sits inside exactly one link span —
  /// pre-fills the link sheet so "edit the link" and "add a link" are the
  /// same gesture.
  String? linkAt(TextSelection selection) {
    final s = math.min(selection.baseOffset, selection.extentOffset);
    if (s < 0) return null;
    for (final f in _formats) {
      if (f.type == FormattingType.link && f.start <= s && s < f.end) {
        return f.url;
      }
    }
    return null;
  }

  void applyLink(TextSelection selection, String url) {
    final range = _normalized(selection);
    if (range == null) return;
    final (s, e) = range;
    // One link per stretch: anything the new span overlaps gives way, because
    // two destinations under one word is a coin toss the reader loses.
    _removeType(FormattingType.link, s, e);
    _formats.add(_FormatRange(s, e, FormattingType.link, url: url));
    _clampAndCoalesce();
    notifyListeners();
  }

  void removeLink(TextSelection selection) {
    final range = _normalized(selection);
    if (range == null) return;
    _removeType(FormattingType.link, range.$1, range.$2);
    notifyListeners();
  }

  (int, int)? _normalized(TextSelection selection) {
    if (!selection.isValid || selection.isCollapsed) return null;
    final s = math.min(selection.baseOffset, selection.extentOffset)
        .clamp(0, text.length);
    final e = math.max(selection.baseOffset, selection.extentOffset)
        .clamp(0, text.length);
    return s < e ? (s, e) : null;
  }

  bool _isCovered(FormattingType type, int s, int e) {
    // Union the type's ranges, then ask whether [s,e) fits inside one merged
    // stretch — overlap bookkeeping happens once, here, instead of at every
    // toggle call site.
    final merged = <(int, int)>[];
    final ofType = [
      for (final f in _formats)
        if (f.type == type) (f.start, f.end),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final r in ofType) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
        merged[merged.length - 1] =
            (merged.last.$1, math.max(merged.last.$2, r.$2));
      } else {
        merged.add(r);
      }
    }
    return merged.any((r) => r.$1 <= s && e <= r.$2);
  }

  void _removeType(FormattingType type, int s, int e) {
    final next = <_FormatRange>[];
    for (final f in _formats) {
      if (f.type != type || f.end <= s || f.start >= e) {
        next.add(f);
        continue;
      }
      // Keep whatever sticks out either side of the removal window.
      if (f.start < s) next.add(_FormatRange(f.start, s, f.type, url: f.url));
      if (f.end > e) next.add(_FormatRange(e, f.end, f.type, url: f.url));
    }
    _formats
      ..clear()
      ..addAll(next);
  }

  void _clampAndCoalesce() {
    final len = text.length;
    _formats.removeWhere((f) {
      f.start = f.start.clamp(0, len);
      f.end = f.end.clamp(0, len);
      return f.start >= f.end;
    });
    _formats.sort((a, b) {
      final byType = a.type.index.compareTo(b.type.index);
      return byType != 0 ? byType : a.start.compareTo(b.start);
    });
    // Merge touching same-type ranges — links only onto the same destination.
    final out = <_FormatRange>[];
    for (final f in _formats) {
      final last = out.isEmpty ? null : out.last;
      if (last != null &&
          last.type == f.type &&
          last.url == f.url &&
          f.start <= last.end) {
        last.end = math.max(last.end, f.end);
      } else {
        out.add(f);
      }
    }
    _formats
      ..clear()
      ..addAll(out);
  }

  /// Shifts every format range across one text change, located by
  /// common-prefix/common-suffix diff. String comparison rather than
  /// selection deltas, because it is the only signal that stays truthful
  /// through IME composition, autocorrect replacing a word, and paste — all
  /// of which arrive here as ordinary value assignments.
  ///
  /// The rules, stated once:
  ///  * an edit inside a range grows/shrinks it (typing inside bold stays
  ///    bold; so does autocorrect replacing a bold word);
  ///  * a PURE insertion at a range's edge falls OUTSIDE it — coherent
  ///    because formatting is selection-applied only, so there is no "bold
  ///    typing mode" whose caret state could say otherwise;
  ///  * a deletion eats whatever of a range it covers, and a range it covers
  ///    entirely dies with it.
  void _remapFormats(String oldText, String newText) {
    if (_formats.isEmpty) return;
    var p = 0;
    final maxP = math.min(oldText.length, newText.length);
    while (p < maxP && oldText.codeUnitAt(p) == newText.codeUnitAt(p)) {
      p++;
    }
    var oldEnd = oldText.length, newEnd = newText.length;
    while (oldEnd > p &&
        newEnd > p &&
        oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    final rs = p, re = oldEnd; // replaced range in the OLD text
    final ins = newEnd - p; // how much replaced it
    final delta = ins - (re - rs);
    if (delta == 0 && rs == re) return; // no structural change

    final pureInsert = rs == re;
    final next = <_FormatRange>[];
    for (final f in _formats) {
      var s = f.start, e = f.end;
      if (e <= rs) {
        // Entirely before — but a pure insert exactly AT the end boundary
        // stays outside (no growth), which this already gives: e == rs keeps.
        next.add(f);
        continue;
      }
      if (s >= re) {
        // Entirely after; a pure insert exactly at the start boundary pushes
        // the range right rather than growing it (s == rs == re → s >= re).
        f.start = s + delta;
        f.end = e + delta;
        next.add(f);
        continue;
      }
      if (rs >= s && re <= e) {
        // Edit contained by the range. A pure insert strictly inside grows
        // it; a replacement (even one touching the edges) keeps the range —
        // typing over a bold selection leaves bold text.
        if (pureInsert && (rs == s || rs == e)) {
          // Handled by the two branches above; unreachable, kept for the
          // reader tracing the case split.
          next.add(f);
        } else {
          f.end = e + delta;
          next.add(f);
        }
        continue;
      }
      if (rs <= s && re >= e) {
        // Edit swallows the range entirely: it dies with the text it styled.
        continue;
      }
      if (s < rs) {
        // Tail overlaps the edit: keep the head, the inserted text (sitting
        // at the range's new end boundary) stays outside.
        f.start = s;
        f.end = rs;
        next.add(f);
      } else {
        // Head overlaps the edit: keep the tail, shifted to after the
        // insertion.
        f.start = rs + ins;
        f.end = e + delta;
        next.add(f);
      }
    }
    _formats
      ..clear()
      ..addAll(next);
    _clampAndCoalesceAgainst(newText.length);
  }

  /// [_clampAndCoalesce] against an explicit length — during [_remapFormats]
  /// `text` still holds the OLD value (the remap runs before the assignment).
  void _clampAndCoalesceAgainst(int len) {
    _formats.removeWhere((f) {
      f.start = f.start.clamp(0, len);
      f.end = f.end.clamp(0, len);
      return f.start >= f.end;
    });
    _formats.sort((a, b) {
      final byType = a.type.index.compareTo(b.type.index);
      return byType != 0 ? byType : a.start.compareTo(b.start);
    });
    final out = <_FormatRange>[];
    for (final f in _formats) {
      final last = out.isEmpty ? null : out.last;
      if (last != null &&
          last.type == f.type &&
          last.url == f.url &&
          f.start <= last.end) {
        last.end = math.max(last.end, f.end);
      } else {
        out.add(f);
      }
    }
    _formats
      ..clear()
      ..addAll(out);
  }

  @override
  set value(TextEditingValue newValue) {
    final old = super.value;
    final applied = _absorbTokenBackspace(old, newValue);
    // The remap runs on every text change, IME composition included —
    // offsets that sat out a composition would be wrong the moment it
    // committed. The DIFF makes that safe: it only compares strings, so a
    // framework rewrite that changes nothing moves nothing.
    if (applied.text != old.text) _remapFormats(old.text, applied.text);
    super.value = applied;
  }

  /// Turns a single-character delete that landed inside a completed handle into
  /// a delete of the whole handle.
  ///
  /// Guarded on both values being composition-free: while an IME candidate
  /// window is open the framework rewrites the text in ways that look like
  /// edits and aren't, and rewriting it back underneath would strand the
  /// candidate.
  TextEditingValue _absorbTokenBackspace(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    if (!hasMentions) return next;
    if (old.composing.isValid || next.composing.isValid) return next;
    if (old.text.length - next.text.length != 1) return next;
    if (!next.selection.isValid || !next.selection.isCollapsed) return next;

    final at = next.selection.baseOffset;
    if (at < 0 || at > old.text.length) return next;

    for (final m in MentionDetector.matches(
      old.text,
      usernameById: _handles,
      everyone: _everyone,
    )) {
      if (at < m.start || at >= m.end) continue;
      return TextEditingValue(
        text: old.text.substring(0, m.start) + old.text.substring(m.end),
        selection: TextSelection.collapsed(offset: m.start),
      );
    }
    return next;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final tint = this.tint;
    // Hand the paint back to the framework while an IME candidate window is
    // open so its underline is drawn exactly as it expects. This is also the
    // field `SubmitOnEnter` reads as its own IME guard — the two must never
    // disagree about whether a composition is in progress.
    if (withComposing && value.composing.isValid) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final matches = tint == null
        ? const <MentionMatch>[]
        : MentionDetector.matches(
            text,
            usernameById: _handles,
            everyone: _everyone,
          );
    if (matches.isEmpty && _formats.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    // The same fold the bubble renders with, minus URLs and rewrites — the
    // composer shows exactly what was typed. Sharing `foldRuns` is what keeps
    // the preview and the sent bubble from ever disagreeing about which
    // characters a span covers.
    final fold = foldRuns(
      text: text,
      urls: const [],
      mentions: matches,
      entities: formatting,
      hideAutoUrls: false,
    );

    final spans = <InlineSpan>[];
    for (final run in fold.runs) {
      final slice = fold.displayText.substring(run.start, run.end);
      spans.add(TextSpan(text: slice, style: _previewStyle(run, fold, tint)));
    }
    return TextSpan(style: style, children: spans);
  }

  /// Colour and weight only for mentions — no `background`, unlike the sent
  /// bubble: a filled rect in an editable fights the selection highlight and
  /// clips untidily around the caret. Formatting previews follow the same
  /// restraint: real bold/italic/strike/underline, a mono face for code, and
  /// a DOTTED underline for spoilers — the one span that must stay readable
  /// while its final form exists to be unreadable.
  TextStyle? _previewStyle(StyledRun run, FoldedText fold, Color? tint) {
    TextStyle? s;
    final ownerIndex = run.ownerIndex;
    if (ownerIndex != null && fold.owners[ownerIndex].mention != null) {
      if (tint != null) {
        s = TextStyle(color: tint, fontWeight: FontWeight.w600);
      }
    }
    if (run.styles.contains(FormattingType.code)) {
      final code = GoogleFonts.jetBrainsMono();
      s = s?.merge(code) ?? code;
    }
    if (run.styles.contains(FormattingType.bold)) {
      s = (s ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700);
    }
    if (run.styles.contains(FormattingType.italic)) {
      s = (s ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);
    }
    final decorations = <TextDecoration>[
      if (run.styles.contains(FormattingType.strikethrough))
        TextDecoration.lineThrough,
      if (run.styles.contains(FormattingType.underline))
        TextDecoration.underline,
      if (run.spoiler) TextDecoration.underline,
      if (ownerIndex != null && fold.owners[ownerIndex].linkUrl != null)
        TextDecoration.underline,
    ];
    if (decorations.isNotEmpty) {
      s = (s ?? const TextStyle()).copyWith(
        decoration: TextDecoration.combine(decorations),
        decorationStyle:
            run.spoiler ? TextDecorationStyle.dotted : TextDecorationStyle.solid,
      );
    }
    if (ownerIndex != null &&
        fold.owners[ownerIndex].linkUrl != null &&
        tint != null) {
      s = (s ?? const TextStyle()).copyWith(color: tint);
    }
    return s;
  }
}

/// Mutable on purpose — the remap adjusts these in place on every keystroke,
/// and an immutable copy-per-key would be allocation for its own sake.
class _FormatRange {
  _FormatRange(this.start, this.end, this.type, {this.url});
  int start;
  int end;
  final FormattingType type;
  final String? url;
}
