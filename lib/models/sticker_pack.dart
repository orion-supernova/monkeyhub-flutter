import 'expression_item.dart';

/// One sticker pack as `expressions:packs` returns it — official packs in
/// order, then the viewer's own personal pack.
class StickerPack {
  const StickerPack({
    required this.id,
    required this.slug,
    required this.title,
    required this.personal,
    required this.stickers,
    int? count,
    this.cover,
    this.stickersLoaded = true,
    this.author,
    this.license,
    this.sourceUrl,
  }) : _count = count;

  final String id;
  final String slug;
  final String title;

  /// The viewer's own pack of stickers made from their photos.
  final bool personal;
  final List<PackSticker> stickers;

  /// How many stickers the pack holds. Known from the pack list before
  /// [stickers] is fetched (`expressions:packStickers`, on first open).
  int get count => _count ?? stickers.length;
  final int? _count;

  /// The pack's first sticker, for its tab and store row before it is loaded.
  final PackSticker? cover;

  /// Whether [stickers] holds the pack's stickers yet.
  final bool stickersLoaded;

  /// What draws the pack's tab: the cover before load, else its first sticker.
  PackSticker? get previewSticker =>
      cover ?? (stickers.isEmpty ? null : stickers.first);

  StickerPack withStickers(List<PackSticker> list) => StickerPack(
        id: id,
        slug: slug,
        title: title,
        personal: personal,
        stickers: list,
        count: list.length,
        cover: cover,
        author: author,
        license: license,
        sourceUrl: sourceUrl,
      );

  /// Credit for the art. The Noto packs are CC BY 4.0, whose one condition is
  /// exactly this line being shown.
  final String? author;
  final String? license;
  final String? sourceUrl;

  factory StickerPack.fromJson(Map<String, dynamic> j) {
    final personal = j['kind'] == 'personal';
    // `expressions:packList` rows carry no `stickers`: a count and a cover.
    final listed = j['stickers'] == null;
    final coverUrl = j['coverUrl'] as String?;
    return StickerPack(
      count: listed ? ((j['count'] as num?) ?? 0).toInt() : null,
      stickersLoaded: !listed,
      cover: listed && coverUrl != null && j['coverStorageId'] != null
          ? PackSticker(
              id: 'cover-${j['_id']}',
              storageId: j['coverStorageId'].toString(),
              url: coverUrl,
              format: ExpressionItem.parseFormat(j['coverFormat']),
              emoji: '',
              width: 512,
              height: 512,
              personal: false,
            )
          : null,
      id: j['_id'].toString(),
      slug: (j['slug'] ?? '') as String,
      title: (j['title'] ?? '') as String,
      personal: personal,
      author: j['author'] as String?,
      license: j['license'] as String?,
      sourceUrl: j['sourceUrl'] as String?,
      stickers: [
        for (final s in (j['stickers'] as List? ?? const []))
          PackSticker.fromJson((s as Map).cast<String, dynamic>(),
              personal: personal),
      ],
    );
  }
}

class PackSticker {
  const PackSticker({
    required this.id,
    required this.storageId,
    required this.url,
    required this.format,
    required this.emoji,
    required this.width,
    required this.height,
    required this.personal,
  });

  final String id;
  final String storageId;

  /// The serving URL, resolved by the server with the pack so a whole pack
  /// draws from one subscription.
  final String url;
  final StickerFormat format;
  final String emoji;
  final double width;
  final double height;
  final bool personal;

  factory PackSticker.fromJson(Map<String, dynamic> j,
          {required bool personal}) =>
      PackSticker(
        id: j['_id'].toString(),
        storageId: j['storageId'].toString(),
        url: (j['url'] ?? '') as String,
        format: ExpressionItem.parseFormat(j['format']),
        emoji: (j['emoji'] ?? '') as String,
        width: ((j['width'] as num?) ?? 512).toDouble(),
        height: ((j['height'] as num?) ?? 512).toDouble(),
        personal: personal,
      );

  ExpressionItem toItem() => ExpressionItem(
        kind: ExpressionKind.sticker,
        source: personal ? ExpressionSource.personal : ExpressionSource.pack,
        stickerId: id,
        storageId: storageId,
        format: format,
        width: width,
        height: height,
        title: emoji,
      );
}
