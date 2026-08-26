import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_message.dart';
import '../models/pending_upload.dart';
import '../screens/fullscreen_image_viewer.dart' show thumbnailDecodeWidth;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'reaction_bubble.dart';
import 'remote_image.dart';
import 'steady_hero.dart';

/// The hairline between two tiles of an album.
///
/// The chat's own ground shows through it rather than a painted line: the block
/// is clipped as one shape, so a gap is simply where no tile was drawn. Two
/// logical pixels is the width at which the pictures read as separate frames of
/// one thing — wider and they are back to being separate pictures, narrower and
/// two photographs of a beach become one long smear of sand.
const double kMosaicGap = 2;

/// How a run of [count] photographs packs into rows of square tiles.
///
/// Rows of two and three only, and a row's tiles are square, so a row of two is
/// taller than a row of three and the block gets its rhythm from the counts
/// rather than from a table of heights. The plans put the row holding FEWEST
/// tiles first, which is the row whose tiles are largest: an album should open
/// on its biggest pictures and taper, not build up to them.
///
/// Three is the exception, and gets [mosaicFeatured] instead. Three across is
/// three thumbnails, and three is exactly the count at which an album most
/// needs to still look like photographs.
List<int> mosaicRows(int count) => switch (count) {
      <= 2 => const [2],
      3 => const [3],
      4 => const [2, 2],
      5 => const [2, 3],
      6 => const [3, 3],
      7 => const [2, 2, 3],
      8 => const [2, 3, 3],
      9 => const [3, 3, 3],
      _ => const [2, 2, 3, 3],
    };

/// Whether [count] photographs get the featured layout — one large tile with a
/// stack of two beside it — rather than the rows of [mosaicRows].
bool mosaicFeatured(int count) => count == 3;

/// How much of the width the large tile takes in the featured layout. The rest,
/// less one gap, is the column of two beside it. Tuned so the pair reads as a
/// deliberate stack rather than as two off-cuts: much past this and they are
/// slivers, much under it and the featured picture stops being featured.
const double _featuredFraction = 0.66;

/// A run of photographs drawn as one block instead of a column of bubbles.
///
/// Every tile is still its own message — its own timestamp on the server, its
/// own reactions, its own entry in the action menu — and that is the whole
/// difficulty of the shape. What the reader sees is one thing that arrived at
/// one moment, so the block carries one stamp and one delivery state (the
/// newest photo's, laid on from outside); what they can *act on* is still the
/// individual picture under their finger, which is why every tile takes its own
/// tap, long-press and reaction chips.
///
/// Tiles are cropped square rather than laid out from their real ratios. That
/// is a deliberate trade against the mosaic Telegram draws: an aspect-driven
/// layout has to reflow the moment a ratio arrives, and a photograph that is
/// still downloading has no ratio at all — so a block of ten would rearrange
/// itself under the reader several times on a slow connection. A square grid is
/// the same grid before and after the pictures land.
class PhotoMosaic extends StatefulWidget {
  const PhotoMosaic({
    super.key,
    required this.photos,
    required this.api,
    required this.width,
    required this.radius,
    required this.currentUserId,
    required this.onOpen,
    this.onTileLongPress,
    this.onReactionTap,
    this.onReactionLongPress,
  });

  /// Oldest first — reading order, which is also the order they were sent in.
  final List<ChatMessage> photos;
  final ChatApi api;

  /// The block's full width. Every tile size is derived from it, so this is the
  /// only measurement the caller has to get right.
  final double width;

  /// Rounds the block's four outer corners. Inner corners stay square: the
  /// whole thing is clipped once, as one shape, which is what makes a mosaic
  /// read as a single object rather than as tiles that happen to be adjacent.
  final BorderRadius radius;

  final String currentUserId;

  /// Opens this photograph fullscreen.
  final void Function(ChatMessage m) onOpen;

  /// The message under the finger, and the key of the tile it was on — the
  /// action menu anchors its lifted preview to that rect, and a mosaic has no
  /// single rect to give it.
  final void Function(ChatMessage m, GlobalKey anchor)? onTileLongPress;

  final void Function(ChatMessage m, String emoji)? onReactionTap;
  final void Function(ChatMessage m, String emoji)? onReactionLongPress;

  @override
  State<PhotoMosaic> createState() => _PhotoMosaicState();
}

class _PhotoMosaicState extends State<PhotoMosaic> {
  /// One stable key per photograph, so a rebuild — an arriving reaction, a
  /// finished upload — hands the action menu a key whose element has not
  /// moved. Owned by the state and pruned with the album rather than kept in a
  /// static map, which on a long-lived transcript would be an entry per
  /// photograph ever scrolled past.
  final Map<String, GlobalKey> _anchors = {};

  GlobalKey _anchorFor(String id) =>
      _anchors.putIfAbsent(id, () => GlobalKey(debugLabel: 'mosaic-$id'));

  @override
  void didUpdateWidget(PhotoMosaic old) {
    super.didUpdateWidget(old);
    final live = {for (final m in widget.photos) m.id};
    _anchors.removeWhere((id, _) => !live.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return ClipRRect(
      borderRadius: widget.radius,
      child: SizedBox(
        width: widget.width,
        child: mosaicFeatured(widget.photos.length)
            ? _featured(theme)
            : _rows(theme),
      ),
    );
  }

  /// [side] is what the tile will actually be laid out at — the row hands it
  /// exact constraints, so this is only used to pick a decode size.
  Widget _tile(AppTheme theme, ChatMessage m, double side) => _MosaicTile(
        anchor: _anchorFor(m.id),
        message: m,
        api: widget.api,
        theme: theme,
        side: side,
        currentUserId: widget.currentUserId,
        onOpen: () => widget.onOpen(m),
        onLongPress: widget.onTileLongPress == null
            ? null
            : () => widget.onTileLongPress!(m, _anchorFor(m.id)),
        onReactionTap: widget.onReactionTap == null
            ? null
            : (emoji) => widget.onReactionTap!(m, emoji),
        onReactionLongPress: widget.onReactionLongPress == null
            ? null
            : (emoji) => widget.onReactionLongPress!(m, emoji),
      );

  /// One large tile, two stacked beside it. The large one leads on both sides
  /// of the conversation: mirroring it would put the album's first photograph
  /// at the reader's right on their own messages and at their left on everyone
  /// else's, and reading order is not a property of who sent it.
  Widget _featured(AppTheme theme) {
    final photos = widget.photos;
    final big = (widget.width - kMosaicGap) * _featuredFraction;
    final small = (big - kMosaicGap) / 2;
    return SizedBox(
      height: big,
      child: Row(
        children: [
          SizedBox(width: big, child: _tile(theme, photos[0], big)),
          const SizedBox(width: kMosaicGap),
          // Expanded rather than the arithmetic remainder: the two must add up
          // to the block's width to the last subpixel, and a Row that overflows
          // by a rounding error is a yellow-and-black stripe across a
          // photograph.
          Expanded(
            child: Column(
              children: [
                Expanded(child: _tile(theme, photos[1], small)),
                const SizedBox(height: kMosaicGap),
                Expanded(child: _tile(theme, photos[2], small)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rows(AppTheme theme) {
    final photos = widget.photos;
    final plan = mosaicRows(photos.length);
    final rows = <Widget>[];
    var next = 0;
    for (final perRow in plan) {
      if (next >= photos.length) break;
      // The last row takes what is left rather than what the plan asked for.
      // The plans cover every count up to the album cap exactly, so this only
      // fires for a run the cap split — and a short final row is a better
      // answer than a row of two drawn as a row of three.
      final take = perRow.clamp(1, photos.length - next);
      final side = (widget.width - (take - 1) * kMosaicGap) / take;
      rows.add(SizedBox(
        height: side,
        child: Row(
          children: [
            for (var k = 0; k < take; k++) ...[
              if (k > 0) const SizedBox(width: kMosaicGap),
              Expanded(child: _tile(theme, photos[next + k], side)),
            ],
          ],
        ),
      ));
      next += take;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: kMosaicGap),
          rows[i],
        ],
      ],
    );
  }
}

/// The [Hero] tag a mosaic tile flies under.
///
/// Deliberately its own prefix. A tile and the transcript bubble for the same
/// message are never both mounted — the album replaces the bubbles it draws —
/// but the shared-content grid and the fullscreen viewer build their own tags
/// for the same messages, and two heroes sharing a tag across routes that both
/// join one flight is an assertion rather than a graceful degrade.
Object mosaicHeroTag(ChatMessage m) => 'album-${m.id}';

/// One photograph in the block.
///
/// Square-cropped, un-rounded (the block owns the corners) and carrying only
/// what fits: the picture, its own reaction chips, and — while it is still on
/// its way up — the sender's own bytes under a progress arc.
class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.anchor,
    required this.message,
    required this.api,
    required this.theme,
    required this.side,
    required this.currentUserId,
    required this.onOpen,
    this.onLongPress,
    this.onReactionTap,
    this.onReactionLongPress,
  });

  final GlobalKey anchor;
  final ChatMessage message;
  final ChatApi api;
  final AppTheme theme;

  /// What the tile will be laid out at. Used to size the decode, not to size
  /// the box — the row hands down tight constraints for that.
  final double side;

  final String currentUserId;
  final VoidCallback onOpen;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;
  final void Function(String emoji)? onReactionLongPress;

  @override
  Widget build(BuildContext context) {
    final upload = message.upload;
    final storageId = message.mediaStorageId;
    final Widget picture;
    if (upload != null) {
      // Ahead of the storage id for the reason the single-photo bubble puts it
      // there: for a moment after the upload lands the message has both, and
      // the bytes already in memory beat fetching back a picture we have only
      // just finished sending.
      picture = _UploadingTile(upload: upload);
    } else if (storageId != null) {
      picture = SteadyHero(
        tag: mosaicHeroTag(message),
        child: RemoteImage(
          storageId: storageId,
          api: api,
          // The block is clipped as one shape, so a tile that rounded itself
          // would cut four notches out of the middle of it.
          borderRadius: BorderRadius.zero,
          decodeWidth: thumbnailDecodeWidth(context, side),
        ),
      );
    } else {
      picture = ColoredBox(
        color: theme.surfaceSunken,
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              size: 20, color: theme.inkMuted),
        ),
      );
    }

    final reactions = message.reactions;
    return KeyedSubtree(
      key: anchor,
      child: GestureDetector(
        onTap: onOpen,
        onLongPress: onLongPress,
        // Right-click reaches the same menu, matching how the bubble already
        // treats a secondary tap.
        onSecondaryTap: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            picture,
            if (reactions.isNotEmpty && onReactionTap != null)
              Positioned(
                left: 4,
                bottom: 4,
                // On the picture rather than under the block: a row of chips
                // beneath a mosaic cannot say WHICH of ten photographs it is
                // about, and the one place that is never ambiguous is the
                // corner of the photograph itself.
                child: ReactionRow(
                  reactions: reactions,
                  currentUserId: currentUserId,
                  onToggle: onReactionTap!,
                  onShowReactors: onReactionLongPress,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The sender's own photograph, painted from the bytes in hand while they go
/// up, with the upload's arc over it.
class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.upload});

  final PendingUpload upload;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(upload.bytes, fit: BoxFit.cover, gaplessPlayback: true),
        // Dimmed until it lands, so a block of ten says at a glance which of
        // them are still on their way.
        ValueListenableBuilder<double?>(
          valueListenable: upload.progress,
          builder: (context, progress, _) => DecoratedBox(
            decoration:
                BoxDecoration(color: Colors.black.withValues(alpha: 0.28)),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  // Null where the transport cannot honestly measure it — see
                  // [PendingUpload.progress] — which spins rather than lying.
                  value: progress,
                  strokeWidth: 2,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
