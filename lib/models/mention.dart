/// @-mentions: locating them in sent text, and driving the composer's picker.
///
/// ## Why the text keeps a literal `@username`
///
/// A sent message stores the handle the user actually typed and carries the
/// resolved ids alongside it, rather than substituting markup like `<@id>` the
/// way Slack does. Two things make that the better trade here:
///
///  * The anchor in the text cannot go stale, which is the one thing markup
///    buys you. Not because handles never change — `users.applyUsernameChange`
///    exists — but because the handle array and the text are written in the
///    same breath and read against each other, never against the live roster.
///    A rename moves neither, so an old message keeps highlighting and keeps
///    routing on its ids; it simply goes on showing the handle that was
///    actually typed, which is the honest rendering of what was said.
///  * `content` is reused verbatim as the push body, as `rooms.lastMessage`,
///    and as `replyToPreview.contentPreview`. Markup would leak raw ids into
///    all three, and each would need its own resolver to read like a sentence
///    again.
///
/// A client that predates the feature therefore renders a mention as ordinary
/// readable text rather than as a broken token.
///
/// ## Why this scans for known handles instead of matching a pattern
///
/// Usernames are not charset-constrained: signup and rename both only trim the
/// string, cap it at 32 characters and check that it's unique, so one can
/// legitimately contain spaces or non-Latin characters. A `@[\w]+` pattern
/// would quietly clip those in half.
///
/// So [MentionDetector] never guesses at the shape of a handle. It walks to
/// each `@` and tries the handles this message actually claims, longest first.
/// That is exact whatever the handle contains, and it makes the id array the
/// single source of truth: typing `@bob` by hand highlights nothing, because
/// nothing resolved it.
library;

import 'chat_user.dart';
import '../services/link_preview_service.dart';

/// One mention occurrence located in a run of text.
///
/// Mirrors [UrlMatch]'s `(start, end, payload)` shape so both can be merged
/// into one ordered pass when the bubble builds its spans.
class MentionMatch {
  const MentionMatch({
    required this.start,
    required this.end,
    required this.userId,
  });

  final int start;
  final int end;

  /// The mentioned user, or null for `@everyone` — which names no single
  /// account and so has no id to carry.
  final String? userId;

  bool get isEveryone => userId == null;
}

/// The literal that `@everyone` is written as, without its `@`.
///
/// Anyone whose handle happens to be this would be shadowed by the broadcast
/// token, so [MentionDetector] resolves real members first.
const String kEveryoneHandle = 'everyone';

/// Letters, digits and underscore — used only to test whether a mention sits
/// on a word boundary. Unicode-aware so a Cyrillic or CJK handle is treated as
/// a word rather than as punctuation.
final RegExp _wordChar = RegExp(r'[\p{L}\p{N}_]', unicode: true);

bool _isWordChar(String ch) => _wordChar.hasMatch(ch);

class MentionDetector {
  const MentionDetector._();

  /// Every mention in [text], in document order and never overlapping.
  ///
  /// [usernameById] is the handle of each account this message mentions;
  /// [everyone] arms the broadcast token. Handles absent from the map are not
  /// matched at all, which is what stops a hand-typed `@bob` from claiming a
  /// mention nobody sent.
  static List<MentionMatch> matches(
    String text, {
    required Map<String, String> usernameById,
    bool everyone = false,
  }) {
    if (text.isEmpty || (usernameById.isEmpty && !everyone)) return const [];

    final candidates = <_Candidate>[
      for (final e in usernameById.entries)
        if (e.value.isNotEmpty) _Candidate(e.value, e.key),
      if (everyone) const _Candidate(kEveryoneHandle, null),
    ]..sort((a, b) {
        // Longest first, so a room holding both `@bob` and `@bobby` resolves
        // "@bobby" to the person actually named that.
        final byLength = b.handle.length.compareTo(a.handle.length);
        if (byLength != 0) return byLength;
        // Real members outrank the broadcast token at equal length, so someone
        // who registered the handle "everyone" still owns it. Spelled out
        // rather than left to insertion order because List.sort is not stable.
        return _Candidate.rank(a).compareTo(_Candidate.rank(b));
      });

    final out = <MentionMatch>[];
    var i = 0;
    while (i < text.length) {
      final at = text.indexOf('@', i);
      if (at < 0) break;

      // `foo@bar` is an address, not a mention. Only an `@` that opens a word
      // can start one.
      if (at > 0 && _isWordChar(text[at - 1])) {
        i = at + 1;
        continue;
      }

      final hit = _matchAt(text, at, candidates);
      if (hit == null) {
        i = at + 1;
        continue;
      }
      out.add(hit);
      i = hit.end;
    }
    return out;
  }

  static MentionMatch? _matchAt(
    String text,
    int at,
    List<_Candidate> candidates,
  ) {
    for (final c in candidates) {
      final end = at + 1 + c.handle.length;
      if (end > text.length) continue;
      if (text.substring(at + 1, end) != c.handle) continue;
      // The handle has to end where the word ends. Without this, `@bob` would
      // match inside "@bobby" whenever only Bob is mentioned, highlighting
      // four characters of someone else's name.
      if (end < text.length && _isWordChar(text[end])) continue;
      return MentionMatch(start: at, end: end, userId: c.userId);
    }
    return null;
  }

  /// The ids in [text] that still carry a visible token, given what was
  /// committed.
  ///
  /// The composer calls this on every keystroke instead of tracking edits:
  /// backspacing `@murat` down to `@mura` stops it matching, so the mention
  /// drops itself. That makes deletion, selection-replace and paste all
  /// correct without any of them being handled specially.
  static Set<String> survivingIds(
    String text, {
    required Map<String, String> usernameById,
  }) {
    final out = <String>{};
    for (final m in matches(text, usernameById: usernameById)) {
      final id = m.userId;
      if (id != null) out.add(id);
    }
    return out;
  }

  /// Whether an armed `@everyone` still has a token in [text].
  static bool everyoneSurvives(String text) => matches(
        text,
        usernameById: const {},
        everyone: true,
      ).isNotEmpty;
}

class _Candidate {
  const _Candidate(this.handle, this.userId);
  final String handle;
  final String? userId;

  static int rank(_Candidate c) => c.userId == null ? 1 : 0;
}

/// The in-progress `@…` the caret currently sits in.
class MentionQuery {
  const MentionQuery({required this.atIndex, required this.query});

  /// Offset of the `@` that opened it.
  final int atIndex;

  /// Everything between that `@` and the caret. May contain spaces — see
  /// [activeAt].
  final String query;

  /// How far back from the caret an unresolved `@` is still considered open.
  ///
  /// Without a bound, every keystroke in a long paragraph would rescan to the
  /// first `@` in it, and a stray one near the top would keep a picker alive
  /// for the rest of the message.
  static const int maxQueryLength = 32;

  /// The mention query the caret is inside, or null if it isn't in one.
  ///
  /// The `@` must open a word — at the start of the text or after whitespace —
  /// and must not be part of a URL, so neither `foo@bar.com` nor a query string
  /// pops the picker open.
  ///
  /// The query deliberately may contain spaces: a room member displayed as
  /// "John Smith" should still be reachable by typing `@john sm`, the way it is
  /// in Slack. The caller closes the picker when a query stops matching anyone,
  /// which is what keeps ordinary prose from holding it open.
  static MentionQuery? activeAt(String text, int caret) {
    if (caret < 0 || caret > text.length) return null;

    final floor = caret - maxQueryLength - 1;
    var at = -1;
    for (var i = caret - 1; i >= 0 && i >= floor; i--) {
      final ch = text[i];
      if (ch == '@') {
        at = i;
        break;
      }
      // A mention never spans lines: an `@` on an earlier line belongs to a
      // sentence the user has already finished.
      if (ch == '\n') return null;
    }
    if (at < 0) return null;
    // Same boundary rule the detector uses, so what opens the picker is
    // exactly what will render as a mention afterwards. `(@bo` counts;
    // `foo@bo` does not.
    if (at > 0 && _isWordChar(text[at - 1])) return null;
    if (_insideUrl(text, at)) return null;

    return MentionQuery(atIndex: at, query: text.substring(at + 1, caret));
  }

  static bool _insideUrl(String text, int index) {
    for (final u in UrlDetector.matches(text)) {
      if (index >= u.start && index < u.end) return true;
    }
    return false;
  }
}

/// Room members that match [query], best match first.
///
/// Scoring is deliberately coarse — a handle that starts with what you typed
/// beats one that merely contains it, and a handle beats a display name — then
/// ties fall back to the same order an empty query produces. That order puts
/// the room's owner first and online people above offline ones, so the list is
/// useful the instant `@` is pressed and before anything has been typed.
///
/// Runs against the roster already held in memory, so there is no network call
/// and nothing to debounce.
List<ChatUser> rankMembers(
  Iterable<ChatUser> members,
  String query, {
  String? excludeUserId,
}) {
  final needle = query.trim().toLowerCase();
  final scored = <_Scored>[];

  for (final u in members) {
    // Tagging yourself is noise — you already know you said it.
    if (excludeUserId != null && u.id == excludeUserId) continue;
    final score = needle.isEmpty ? 0 : _score(u, needle);
    if (score == null) continue;
    scored.add(_Scored(u, score));
  }

  scored.sort((a, b) {
    if (a.score != b.score) return a.score.compareTo(b.score);
    final owner = _ownerRank(a.user).compareTo(_ownerRank(b.user));
    if (owner != 0) return owner;
    final online = _presenceRank(a.user).compareTo(_presenceRank(b.user));
    if (online != 0) return online;
    return a.user.displayName.toLowerCase().compareTo(
          b.user.displayName.toLowerCase(),
        );
  });

  return [for (final s in scored) s.user];
}

/// Lower is better. Null means "no match at all".
int? _score(ChatUser u, String needle) {
  final handle = u.username.toLowerCase();
  final name = u.displayName.toLowerCase();

  if (handle.startsWith(needle)) return 0;
  if (name.startsWith(needle)) return 1;
  // A match at any word boundary of the display name — "@smi" should find
  // "John Smith", which neither prefix test above catches.
  for (final word in name.split(RegExp(r'\s+'))) {
    if (word.startsWith(needle)) return 2;
  }
  if (handle.contains(needle)) return 3;
  if (name.contains(needle)) return 4;
  return null;
}

int _ownerRank(ChatUser u) => u.role == 'owner' ? 0 : 1;

int _presenceRank(ChatUser u) {
  switch (u.status) {
    case 'online':
      return 0;
    case 'away':
      return 1;
    default:
      return 2;
  }
}

class _Scored {
  const _Scored(this.user, this.score);
  final ChatUser user;
  final int score;
}
