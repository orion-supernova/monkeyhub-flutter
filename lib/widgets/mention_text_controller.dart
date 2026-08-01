import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/mention.dart';

/// The composer's text controller, extended to know which `@handles` in the
/// field are real mentions.
///
/// It owns two things a plain [TextEditingController] can't:
///
///  * **The committed set.** A handle only counts once it has been picked from
///    the list. That set is what gets sent, and what the field tints.
///  * **Token-atomic backspace.** Deleting one character out of `@murat` would
///    otherwise leave `@mura` sitting in the message looking like a mention and
///    behaving like prose. One backspace takes the whole token, the way every
///    other chat app does it.
///
/// Correctness does not depend on that second behaviour: [prune] re-derives the
/// set from the text after every change, so any edit that breaks a handle —
/// backspace, paste over a selection, select-all-delete — drops the mention it
/// broke. The atomic delete is polish on top of a model that is already safe.
class MentionTextController extends TextEditingController {
  MentionTextController({super.text});

  final Map<String, String> _handles = {};
  bool _everyone = false;

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

  @override
  set value(TextEditingValue newValue) {
    super.value = _absorbTokenBackspace(super.value, newValue);
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
    if (tint == null || (withComposing && value.composing.isValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final matches = MentionDetector.matches(
      text,
      usernameById: _handles,
      everyone: _everyone,
    );
    if (matches.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    // Colour and weight only — no `background` here, unlike the sent bubble. A
    // filled rect in an editable fights the selection highlight and clips
    // untidily around the caret.
    final tinted = (style ?? const TextStyle())
        .copyWith(color: tint, fontWeight: FontWeight.w600);

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(TextSpan(text: text.substring(m.start, m.end), style: tinted));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: spans);
  }
}
