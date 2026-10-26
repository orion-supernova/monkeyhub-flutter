import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/pending_upload.dart';
import '../screens/fullscreen_image_viewer.dart' show thumbnailDecodeWidth;
import '../platform.dart';
import '../theme/app_theme.dart';
import '../theme/interaction.dart';
import '../theme/theme_scope.dart';
import 'auto_download_gate.dart';
import 'secondary_click_recognizer.dart';
import 'highlight_pulse.dart';
import 'media_flight.dart';
import 'reaction_bubble.dart';
import 'media_spoiler.dart';
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

/// The row plan [count] photographs are ACTUALLY drawn with — [mosaicRows]
/// with its last row trimmed to what is left.
///
/// The plans cover every count up to the album cap exactly, so the trim only
/// fires for a run the cap split; a short final row is a better answer than a
/// row of two drawn as a row of three. Pulled out of the layout because a
/// tile's corners are a function of the same plan, and a block whose corners
/// are rounded off a different plan from the one it was laid out with rounds
/// the wrong tiles.
List<int> mosaicRowPlan(int count) {
  final plan = mosaicRows(count);
  var total = 0;
  for (final perRow in plan) {
    total += perRow;
  }
  // The common path, and the one every real album takes: the plans cover every
  // count up to the cap exactly, so the const list goes back untouched. This is
  // called per tile per build on a list that rebuilds with the transcript, and
  // a block of ten allocating twenty throwaway lists a frame is a cost with
  // nothing to show for it.
  if (total == count) return plan;

  final out = <int>[];
  var next = 0;
  for (final perRow in plan) {
    if (next >= count) break;
    final take = perRow.clamp(1, count - next);
    out.add(take);
    next += take;
  }
  return out;
}

/// The width the [index]th tile of a [count]-photograph block is laid out at,
/// for a block [width] wide.
///
/// Only ever used to pick a decode size — the rows hand tiles exact
/// constraints. But it has to be the width the tile REALLY decoded at, because
/// that is the `ImageCache` key the fullscreen view reuses both as the picture
/// it flies and as its arrival backdrop; a value that merely approximates it
/// misses the cache, and then the flight animates a shimmer.
///
/// Width, not side, in the one place where those differ. Every tile of a row
/// layout is square, but the featured layout's pair are a hair wider than they
/// are tall — the column beside the big tile takes the arithmetic remainder so
/// the row cannot overflow by a rounding error. Decoding those two to their
/// height would leave them upscaled across their whole width, and — worse —
/// would be a decode the flight then could not find.
double mosaicTileSide(int count, double width, int index) {
  if (mosaicFeatured(count)) {
    final big = (width - kMosaicGap) * _featuredFraction;
    return index == 0 ? big : width - big - kMosaicGap;
  }
  var next = 0;
  for (final take in mosaicRowPlan(count)) {
    if (index < next + take) {
      return (width - (take - 1) * kMosaicGap) / take;
    }
    next += take;
  }
  return width;
}

/// Which of the [index]th tile's corners are rounded, given the block's own
/// [outer] radius.
///
/// At rest this is redundant: the block is clipped once as one shape, so a tile
/// drawn square under a rounded clip already looks rounded. It stops being
/// redundant the moment the tile leaves. A picture flying to fullscreen is
/// lifted out of that clip, so with no corners of its own it snaps square on
/// the frame it takes off and square again where it lands — which is the tell
/// that turns a movement back into a cut. See [mediaFlightShuttle].
BorderRadius mosaicTileRadius(int count, BorderRadius outer, int index) {
  var tl = false, tr = false, bl = false, br = false;
  if (mosaicFeatured(count)) {
    // One large tile, two stacked beside it: the big one owns the whole
    // leading edge, and the pair take one trailing corner each.
    tl = bl = index == 0;
    tr = index == 1;
    br = index == 2;
  } else {
    final plan = mosaicRowPlan(count);
    var next = 0;
    for (var row = 0; row < plan.length; row++) {
      final take = plan[row];
      if (index < next + take) {
        final first = index == next;
        final last = index == next + take - 1;
        tl = first && row == 0;
        tr = last && row == 0;
        bl = first && row == plan.length - 1;
        br = last && row == plan.length - 1;
        break;
      }
      next += take;
    }
  }
  return BorderRadius.only(
    topLeft: tl ? outer.topLeft : Radius.zero,
    topRight: tr ? outer.topRight : Radius.zero,
    bottomLeft: bl ? outer.bottomLeft : Radius.zero,
    bottomRight: br ? outer.bottomRight : Radius.zero,
  );
}

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
    this.onTileContextMenu,
    this.onReactionTap,
    this.onReactionLongPress,
    this.highlightedPhotoId,
    this.highlightT = 0,
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
  ///
  /// [sourceDecodeWidth] is the width, in device pixels, the tile under the
  /// finger has its picture decoded at. The fullscreen view needs it twice
  /// over — as the picture it flies, and as the backdrop it lands on — and the
  /// tile is the only thing that knows it: an album's tiles are three
  /// different sizes depending on how many photographs came with them. See
  /// [mosaicTileSide].
  final void Function(ChatMessage m, {required int sourceDecodeWidth})
      onOpen;

  /// The message under the finger, and the key of the tile it was on — the
  /// action menu anchors its lifted preview to that rect, and a mosaic has no
  /// single rect to give it.
  final void Function(ChatMessage m, GlobalKey anchor)? onTileLongPress;

  /// A right-click on one photograph, with where it landed.
  final void Function(ChatMessage m, Offset globalPosition)? onTileContextMenu;

  final void Function(ChatMessage m, String emoji)? onReactionTap;
  final void Function(ChatMessage m, String emoji)? onReactionLongPress;

  /// The one photograph a jump has landed on, pulsing under [highlightT].
  ///
  /// One tile, not the block. A reply tether or a gallery's SHOW IN CHAT names
  /// a message, and in a run of ten pictures "one of these" is not an answer —
  /// the whole point of the trip was to be shown WHICH. Null on every row that
  /// nothing is currently pointing at, which is nearly all of them.
  final String? highlightedPhotoId;

  /// 0..1 progress of that pulse. See [highlightPulseCurve].
  final double highlightT;

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

  /// [index] is the photograph's place in the block, which is what its size
  /// and its corners are both derived from — see [mosaicTileSide] and
  /// [mosaicTileRadius].
  Widget _tile(AppTheme theme, int index) {
    final m = widget.photos[index];
    final count = widget.photos.length;
    return MosaicTile(
        anchor: _anchorFor(m.id),
        message: m,
        api: widget.api,
        theme: theme,
        side: mosaicTileSide(count, widget.width, index),
        radius: mosaicTileRadius(count, widget.radius, index),
        highlightT:
            m.id == widget.highlightedPhotoId ? widget.highlightT : 0.0,
        currentUserId: widget.currentUserId,
        onOpen: (w) => widget.onOpen(m, sourceDecodeWidth: w),
        onLongPress: widget.onTileLongPress == null
            ? null
            : () => widget.onTileLongPress!(m, _anchorFor(m.id)),
        onContextMenu: widget.onTileContextMenu == null
            ? null
            : (at) => widget.onTileContextMenu!(m, at),
        onReactionTap: widget.onReactionTap == null
            ? null
            : (emoji) => widget.onReactionTap!(m, emoji),
        onReactionLongPress: widget.onReactionLongPress == null
            ? null
            : (emoji) => widget.onReactionLongPress!(m, emoji),
      );
  }

  /// One large tile, two stacked beside it. The large one leads on both sides
  /// of the conversation: mirroring it would put the album's first photograph
  /// at the reader's right on their own messages and at their left on everyone
  /// else's, and reading order is not a property of who sent it.
  Widget _featured(AppTheme theme) {
    final big = mosaicTileSide(widget.photos.length, widget.width, 0);
    return SizedBox(
      height: big,
      child: Row(
        children: [
          SizedBox(width: big, child: _tile(theme, 0)),
          const SizedBox(width: kMosaicGap),
          // Expanded rather than the arithmetic remainder: the two must add up
          // to the block's width to the last subpixel, and a Row that overflows
          // by a rounding error is a yellow-and-black stripe across a
          // photograph.
          Expanded(
            child: Column(
              children: [
                Expanded(child: _tile(theme, 1)),
                const SizedBox(height: kMosaicGap),
                Expanded(child: _tile(theme, 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rows(AppTheme theme) {
    final count = widget.photos.length;
    final rows = <Widget>[];
    var next = 0;
    for (final take in mosaicRowPlan(count)) {
      final side = mosaicTileSide(count, widget.width, next);
      rows.add(SizedBox(
        height: side,
        child: Row(
          children: [
            for (var k = 0; k < take; k++) ...[
              if (k > 0) const SizedBox(width: kMosaicGap),
              Expanded(child: _tile(theme, next + k)),
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

/// Every pointer but a mouse, for the card's long-press on web and desktop.
final Set<PointerDeviceKind> _notMouse = {
  for (final k in PointerDeviceKind.values)
    if (k != PointerDeviceKind.mouse) k,
};

/// One photograph in the block. Public because [PhotoDeck] deals the same
/// tiles as cards: a photograph's tap, menu, reactions and flight are the same
/// whichever shape the album takes.
///
/// Square-cropped, un-rounded (the block owns the corners) and carrying only
/// what fits: the picture, its own reaction chips, and — while it is still on
/// its way up — the sender's own bytes under a progress arc.
class MosaicTile extends StatelessWidget {
  const MosaicTile({
    super.key,
    required this.anchor,
    required this.message,
    required this.api,
    required this.theme,
    required this.side,
    required this.radius,
    required this.highlightT,
    required this.currentUserId,
    required this.onOpen,
    this.onLongPress,
    this.onContextMenu,
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

  /// This tile's own share of the block's corners. Nothing to do with how it is
  /// drawn at rest — see [mosaicTileRadius].
  final BorderRadius radius;

  /// 0..1 progress of the jump pulse, 0 on every tile a jump did not land on.
  final double highlightT;

  final String currentUserId;

  /// Takes the decode width the picture is resident at — see
  /// [PhotoMosaic.onOpen].
  final void Function(int sourceDecodeWidth) onOpen;

  /// The menu for this photograph. Recognized with the row's own timing
  /// ([kActionMenuLongPress]) rather than the platform default: the row
  /// around an album listens for a long-press too, and the slower of two
  /// equal recognizers loses. Losing is how a long-press on a card used to
  /// open the menu for the album's LAST item, which the row is drawn as.
  final VoidCallback? onLongPress;

  /// A right-click, with where it landed; falls back to [onLongPress].
  final void Function(Offset globalPosition)? onContextMenu;
  final void Function(String emoji)? onReactionTap;
  final void Function(String emoji)? onReactionLongPress;

  @override
  Widget build(BuildContext context) {
    final upload = message.upload;
    final video = message.type == MessageType.video;
    // A video's card is its poster: the still the sender's device took, never
    // the video itself, which is not a picture to decode.
    final storageId = video ? message.posterStorageId : message.mediaStorageId;
    final decodeWidth = thumbnailDecodeWidth(context, side);
    final Widget picture;
    if (upload != null) {
      // Ahead of the storage id for the reason the single-photo bubble puts it
      // there: for a moment after the upload lands the message has both, and
      // the bytes already in memory beat fetching back a picture we have only
      // just finished sending.
      picture = _UploadingTile(
        upload: upload,
        still: video ? upload.posterBytes : upload.bytes,
        theme: theme,
      );
    } else if (video && storageId == null) {
      // A video with no poster (web and desktop cannot take one): a dark
      // card, still a hero so the player has something to fly from.
      picture = SteadyHero(
        tag: mosaicHeroTag(message),
        child: ColoredBox(color: theme.surfaceSunken),
      );
    } else if (storageId != null) {
      Widget image({required BorderRadius borderRadius}) => RemoteImage(
            storageId: storageId,
            api: api,
            borderRadius: borderRadius,
            decodeWidth: decodeWidth,
          );
      picture = SteadyHero(
        tag: mosaicHeroTag(message),
        // The tile owns the flight's appearance rather than leaving it to the
        // fullscreen view, because everything a flight needs to look right is
        // known HERE and nowhere else: this crop, this corner, and above all
        // this decode, which is the one already on screen and therefore the
        // one that can be painted without waiting. Handing it over also settles
        // it for both directions at once — Flutter resolves the destination's
        // shuttle first, and the destination is this tile on the way home.
        flightShuttleBuilder: mediaFlightShuttle(
          spoilerId: message.mediaSpoiler ? message.id : null,
          image: image(borderRadius: BorderRadius.zero),
          radius: radius,
        ),
        child: AutoDownloadGate(
          storageId: storageId,
          roomId: message.roomId,
          incoming: message.senderId != currentUserId,
          child: image(
            // The block is clipped as one shape, so a tile that rounded itself
            // would cut four notches out of the middle of it.
            borderRadius: BorderRadius.zero,
          ),
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

    // This photo's own reactions. Ones to the whole album ride on its first
    // message too, flagged, and are drawn under the stack instead.
    final reactions = [for (final r in message.reactions) if (!r.album) r];
    return KeyedSubtree(
      key: anchor,
      child: RawGestureDetector(
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            () => TapGestureRecognizer(),
            (r) => r.onTap = () => onOpen(decodeWidth),
          ),
          if (onLongPress != null)
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: kActionMenuLongPress,
                // As on the row: holding a mouse button is a drag, not a menu.
                supportedDevices: isWebOrDesktop ? _notMouse : null,
              ),
              (r) => r.onLongPress = onLongPress,
            ),
          // Right-click reaches the same menu, claimed on the way down so it
          // wins over the row's own (see [SecondaryClickRecognizer]).
          if (onContextMenu != null || onLongPress != null)
            SecondaryClickRecognizer:
                GestureRecognizerFactoryWithHandlers<SecondaryClickRecognizer>(
              () => SecondaryClickRecognizer(),
              (r) => r.onClick = onContextMenu ?? (_) => onLongPress?.call(),
            ),
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A spoiler is per item, as it is on the wire: each card of an
            // album sent hidden opens on its own tap, and the first tap on
            // one opens it rather than the viewer.
            if (message.mediaSpoiler)
              MediaSpoilerCover(
                revealKey: message.id,
                sigma: 16,
                child: picture,
              )
            else
              picture,
            // Not while it is still going up: the upload's arc owns the
            // middle of the card until there is something to play.
            if (video && upload == null) const _PlayDisc(),
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
            if (highlightT > 0) _TilePulse(theme: theme, t: highlightT),
          ],
        ),
      ),
    );
  }
}

/// The jump pulse, over one photograph of a block.
///
/// A wash and an inset stroke rather than the halo a bubble gets. A bubble
/// pulses by glowing into the margin beside it; a tile has no margin — its
/// neighbours are other photographs, drawn by sibling widgets that paint after
/// it, so a glow would spill under half of them and over the other half. Ink on
/// the picture itself is the only mark a tile can make that reads the same
/// wherever in the block it happens to sit.
class _TilePulse extends StatelessWidget {
  const _TilePulse({required this.theme, required this.t});

  final AppTheme theme;
  final double t;

  @override
  Widget build(BuildContext context) {
    final curve = highlightPulseCurve(t);
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.28 * curve),
            border: Border.all(
              color: theme.accent.withValues(alpha: 0.9 * curve),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// The play button a video's card carries, centred on its poster: the one
/// mark that says "this one moves" in a hand of photographs.
class _PlayDisc extends StatelessWidget {
  const _PlayDisc();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IgnorePointer(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.85), width: 1.5),
          ),
          // Nudged right: a play triangle's visual centre is left of its box.
          padding: const EdgeInsets.only(left: 3),
          child: const Icon(CupertinoIcons.play_fill,
              size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

/// The sender's own photograph (or a video's poster), painted from the bytes
/// in hand while they go up, with the upload's arc over it.
class _UploadingTile extends StatelessWidget {
  const _UploadingTile({
    required this.upload,
    required this.still,
    required this.theme,
  });

  final PendingUpload upload;

  /// What to show: the photo's own bytes, or a video's poster. Null for a
  /// video that has none, which shows a dark card under the arc.
  final Uint8List? still;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final bytes = still;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bytes != null)
          Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
        else
          ColoredBox(color: theme.surfaceSunken),
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
                // Null where the transport cannot honestly measure it — see
                // [PendingUpload.progress] — which spins rather than lying.
                child: progress == null
                    ? const CupertinoActivityIndicator(
                        color: Colors.white,
                        radius: 11,
                      )
                    : CircularProgressIndicator(
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
