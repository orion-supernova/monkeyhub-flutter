import 'chat_message.dart';
import 'enums.dart';
import 'expression_item.dart';
import 'message_formatting.dart';

/// The most this ever renders as. A pinned banner is one line on a phone; a
/// message can be thousands of characters, and carrying them around to throw
/// them away in the text layout is wasted work on every subscription fire.
const int _kPreviewChars = 120;

/// Collapses runs of whitespace, including newlines.
final RegExp _whitespace = RegExp(r'\s+');

/// One line describing [m], for a surface that shows a message it isn't
/// rendering — the pin banner, the pin list, the composer's reply card.
///
/// Always exactly one line. `maxLines: 1` alone is not enough: it keeps the
/// first *line*, so a message that opens with a blank line renders as an empty
/// row. This flattens instead, so the reader sees the text either way.
///
/// [hasThumbnail] is the one real difference between callers. A surface drawing
/// the picture beside the text wants the caption alone — a "photo" label next
/// to a photo is noise. A surface with no room for a thumbnail needs the word,
/// or an uncaptioned image is a blank line.
///
/// Takes a live [ChatMessage], so the `__DELETED__` / `__VIEW_ONCE__` sentinels
/// never come up: those live in `replyToPreview.contentPreview`, which is a
/// snapshot of a parent taken at send time. A live document says the same
/// things with real fields, and a pinned message is always live — its pin row
/// is deleted with it in `removeMessageAndFanout`.
String messagePreviewLine(ChatMessage m, {bool hasThumbnail = false}) {
  final raw = _rawPreview(m, hasThumbnail: hasThumbnail);
  final flat = raw.replaceAll(_whitespace, ' ').trim();
  if (flat.length <= _kPreviewChars) return flat;
  return '${flat.substring(0, _kPreviewChars).trimRight()}…';
}

String _rawPreview(ChatMessage m, {required bool hasThumbnail}) {
  // Checked before content, and before the media branch. A burn-after-reading
  // photo has no thumbnail to show at any callsite — the server withholds the
  // storage id — so it can never fall through to the caption-only case.
  if (m.viewOnce) return 'photo · view once';

  switch (m.type) {
    case MessageType.text:
    case MessageType.url:
      // A genuinely empty message is possible (a media send whose upload
      // failed). An ellipsis keeps the row from collapsing to nothing.
      //
      // Spoilers masked, here and on the captions below: every caller is a
      // surface showing a message it is not rendering as a bubble, so there
      // is no veil to touch and the words would simply sit in the open.
      return m.content.isEmpty ? '…' : maskSpoilers(m.content, m.formatting);
    case MessageType.image:
      if (m.content.isNotEmpty) return maskSpoilers(m.content, m.formatting);
      return hasThumbnail ? '' : 'photo';
    case MessageType.video:
      if (m.content.isNotEmpty) return maskSpoilers(m.content, m.formatting);
      return hasThumbnail ? '' : 'video';
    case MessageType.videoNote:
      // Named apart from a plain video on purpose: the two are different
      // things to receive, and a row that said "video" for both would make a
      // four-second face indistinguishable from a 40 MB clip.
      return 'video note';
    case MessageType.audio:
      return 'voice message';
    case MessageType.file:
      // The name, not the word "file". A document is the one attachment whose
      // identity is text, so a preview that said "document" would throw away
      // the only thing distinguishing two of them. [hasThumbnail] buys nothing
      // here — a document tile draws a type badge, not a picture of itself.
      final name = m.fileName ?? '';
      return name.isEmpty ? 'document' : name;
    case MessageType.location:
    case MessageType.liveLocation:
      // The word, never the coordinates — and this is the reason it is spelled
      // out rather than folded into the text case. Every caller of this line is
      // a surface that shows a message it is NOT rendering: a pin banner at the
      // top of a room, a reply card in the composer, a row in a list. Putting a
      // position in any of those puts it somewhere it stays after the bubble has
      // scrolled away, and a live share's coordinates change under it besides,
      // so the banner would be quietly wrong within a minute.
      //
      // Static and live share one label deliberately. This line is one row tall
      // and is read at a glance; "live location" in a pin banner would raise
      // exactly the question the banner cannot answer — live until when?
      return 'location';
    case MessageType.system:
      return m.content;
    case MessageType.poll:
    case MessageType.checklist:
    case MessageType.event:
      // The prompt itself, which is exactly what `content` holds on these — the
      // server puts the question on the message row precisely so every surface
      // that shows a message it isn't rendering gets a readable sentence for
      // free. See `backend/convex/schema.ts:messageInteractions`.
      //
      // Deliberately WITHOUT the kind's own word in front of it. Every caller
      // here is one line tall and already short of room, and "poll · which
      // night suits everyone?" spends a fifth of it saying something the
      // reader learns the moment they tap through. The chat list, which has no
      // such tap, does prefix — see `roomPreviewFor`.
      //
      // Falls back rather than returning empty: the prompt is required
      // server-side, so an empty one means a row that predates the feature or
      // a failed parse, and a blank pin banner is worse than a generic word.
      return m.content.isEmpty ? 'poll' : m.content;
    case MessageType.gif:
      // The word, not the title. `content` is the GIF's alt text ("Hello"),
      // and a pin banner reading "Hello" would say the sender typed it.
      return hasThumbnail ? '' : 'GIF';
    case MessageType.sticker:
      // The emoji the sticker stands for, which is what it says — but never a
      // KLIPY sticker's title; see [stickerEmojiOf].
      final emoji = stickerEmojiOf(m.content);
      return emoji == null ? 'sticker' : '$emoji sticker';
  }
}
