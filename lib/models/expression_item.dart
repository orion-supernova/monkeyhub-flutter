/// One GIF or sticker — the unit the expression panel shows, a message carries,
/// and recents/favourites remember.
///
/// The same shape in all three places on purpose. The panel builds one from a
/// KLIPY result or a pack sticker, sending turns it into `messages:send`
/// arguments, and the RECENT row stores it verbatim through
/// `expressions:recordUse` — so a tile in RECENT can be sent again without any
/// lookup, and a sticker in a message can be starred straight from its bubble.
///
/// Mirrors `expressionRef` in `backend/convex/schema.ts`.
library;

final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The emoji a sticker's alt text stands for, or null when it is not one.
///
/// A pack sticker's alt text IS its emoji; a KLIPY sticker's is a title
/// ("Whatever Nevermind"). Surfaces that name a sticker in a line of text show
/// the emoji and nothing otherwise — a title there reads as typed text. The
/// same rule as `roomPreviewFor` in messages.ts.
String? stickerEmojiOf(String alt) {
  final t = alt.trim();
  if (t.isEmpty || t.length > 16 || _letterOrDigit.hasMatch(t)) return null;
  return t;
}

/// What an item sends as: the message type.
enum ExpressionKind { gif, sticker }

/// Where the art lives.
///
/// [klipy] is KLIPY's catalogue — loaded from its CDN, never copied (its API
/// terms forbid it). [pack] is one of our official sticker packs; [personal]
/// is a sticker somebody made from their own photo. The distinction between
/// the last two is a permission: the child guard treats an official sticker
/// like an emoji and a personal one like a photo.
enum ExpressionSource { klipy, pack, personal }

/// How a sticker's file is drawn.
enum StickerFormat { lottie, image }

class ExpressionItem {
  const ExpressionItem({
    required this.kind,
    required this.source,
    this.stickerId,
    this.storageId,
    this.format = StickerFormat.image,
    this.url,
    this.previewUrl,
    this.ref,
    this.width,
    this.height,
    this.title,
  });

  final ExpressionKind kind;
  final ExpressionSource source;

  /// Pack and personal stickers: the `stickers` row and its blob.
  final String? stickerId;
  final String? storageId;
  final StickerFormat format;

  /// KLIPY items: the animated rendition to show in a message, a small one for
  /// thumbnails, and the slug KLIPY's share and report endpoints key on.
  ///
  /// Used exactly as KLIPY returned them — its terms forbid rewriting the URL
  /// or its parameters.
  final String? url;
  final String? previewUrl;
  final String? ref;

  final double? width;
  final double? height;

  /// The alt text: a GIF's title, or the emoji a sticker stands for.
  final String? title;

  bool get isSticker => kind == ExpressionKind.sticker;
  bool get isLottie => format == StickerFormat.lottie;

  /// Width÷height, or 1 when unknown — stickers are nearly always square and a
  /// square placeholder is the least wrong guess for a GIF too.
  double get aspectRatio {
    final w = width, h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return 1;
    return w / h;
  }

  /// Whether two items are the same picture — the backend's `sameRef`.
  bool sameAs(ExpressionItem other) {
    if (other.kind != kind || other.source != source) return false;
    if (stickerId != null || other.stickerId != null) {
      return stickerId == other.stickerId;
    }
    return url == other.url;
  }

  static ExpressionKind? _kind(Object? raw) => switch (raw) {
        'gif' => ExpressionKind.gif,
        'sticker' => ExpressionKind.sticker,
        _ => null,
      };

  static ExpressionSource? parseSource(Object? raw) => switch (raw) {
        'klipy' => ExpressionSource.klipy,
        'pack' => ExpressionSource.pack,
        'personal' => ExpressionSource.personal,
        _ => null,
      };

  static StickerFormat parseFormat(Object? raw) =>
      raw == 'lottie' ? StickerFormat.lottie : StickerFormat.image;

  /// Reads one of `expressions:state`'s entries. Null for anything this build
  /// does not understand, so a newer client's additions are skipped rather
  /// than drawn wrong.
  static ExpressionItem? fromRefJson(Map<String, dynamic> j) {
    final kind = _kind(j['kind']);
    final source = parseSource(j['source']);
    if (kind == null || source == null) return null;
    return ExpressionItem(
      kind: kind,
      source: source,
      stickerId: j['stickerId'] as String?,
      storageId: j['storageId'] as String?,
      format: parseFormat(j['format']),
      url: j['url'] as String?,
      previewUrl: j['previewUrl'] as String?,
      ref: j['ref'] as String?,
      width: (j['width'] as num?)?.toDouble(),
      height: (j['height'] as num?)?.toDouble(),
      title: j['title'] as String?,
    );
  }

  /// The `expressionRef` shape, for `recordUse` and `toggleFavorite`.
  Map<String, dynamic> toRefJson() => {
        'kind': kind.name,
        'source': source.name,
        if (stickerId != null) 'stickerId': stickerId,
        if (storageId != null) 'storageId': storageId,
        if (isSticker) 'format': format.name,
        if (url != null) 'url': url,
        if (previewUrl != null) 'previewUrl': previewUrl,
        if (ref != null) 'ref': ref,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (title != null) 'title': title,
      };

  /// The picture-naming part of a `messages:send` call. The server resolves a
  /// pack sticker from its id alone and ignores anything else it is told.
  Map<String, dynamic> toSendArgs() => {
        'type': kind.name,
        if (stickerId != null)
          'stickerId': stickerId
        else ...{
          'mediaSource': 'klipy',
          if (url != null) 'mediaUrl': url,
          if (previewUrl != null) 'mediaPreviewUrl': previewUrl,
          if (ref != null) 'mediaRef': ref,
        },
        if (width != null) 'mediaWidth': width,
        if (height != null) 'mediaHeight': height,
      };
}
