/// A guess at what language a voice note is in, from what its sender writes.
///
/// ── Why this exists ────────────────────────────────────────────────────────
///
/// The built-in recognizer has to be TOLD the language, and holds to it: hand
/// it Turkish speech with an English locale and it returns fluent English
/// nonsense rather than failing. The phone's own language is the wrong default
/// for exactly the people this app is for: a Turkish speaker with an English
/// phone, or a Swede in a Turkish group. What someone types in a chat is far
/// better evidence of what they speak in it, and the app already has a cheap,
/// conservative text detector (see [LanguageDetector]).
///
/// The sender's own messages first, then the room's, then nothing. A null is
/// fine: the caller falls back to the reader's languages.
library;

import '../companions/translation/language_detector.dart';

abstract final class VoiceLanguageHints {
  /// The text of recent messages in [roomId], newest last, optionally only
  /// [senderId]'s. Registered by the repository that holds them; null in
  /// tests and before sign-in.
  static Iterable<String> Function(String roomId, {String? senderId})? textIn;

  /// How much text to look at. Enough for the detector's word tables to
  /// separate close languages (Swedish from Norwegian), little enough that a
  /// long chat costs nothing.
  static const int _maxChars = 1200;

  /// The base language code ("tr", "sv") the note is probably in, or null.
  static String? guess({String? roomId, String? senderId}) {
    final source = textIn;
    if (source == null || roomId == null) return null;
    if (senderId != null) {
      final theirs = _detect(source(roomId, senderId: senderId));
      if (theirs != null) return theirs;
    }
    return _detect(source(roomId));
  }

  static String? _detect(Iterable<String> texts) {
    final sample = _sample(texts);
    return sample.isEmpty ? null : LanguageDetector.detect(sample);
  }

  static String _sample(Iterable<String> texts) {
    final parts = <String>[];
    var n = 0;
    for (final t in texts.toList().reversed) {
      final s = t.trim();
      if (s.isEmpty) continue;
      parts.add(s);
      n += s.length;
      if (n >= _maxChars) break;
    }
    return parts.join('\n');
  }
}
