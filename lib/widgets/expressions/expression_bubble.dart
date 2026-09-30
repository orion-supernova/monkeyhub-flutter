import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/expression_item.dart';
import '../../theme/theme_scope.dart';
import '../message_stamp.dart';
import 'expression_media.dart';

/// How big a sticker sits in the transcript. Telegram and WhatsApp both land
/// around here — big enough to read as the message, small enough that a run of
/// three does not fill the screen.
const double kStickerMessageSize = 150;

/// The widest a GIF grows in a bubble, whatever the pane allows. A GIF is a
/// reaction, not a photograph; blown up to a photo's width it is mostly
/// compression artefacts.
const double kGifMessageMaxWidth = 280;

/// A GIF message: a bare rounded tile that loops, stamp in the corner like a
/// photo.
///
/// When autoplay is off (the setting, or reduce motion) it rests on its first
/// frame with a GIF badge, and a tap plays it — the same affordance every
/// messenger with a data-saver mode uses.
class GifMessageTile extends StatefulWidget {
  const GifMessageTile({
    super.key,
    required this.item,
    required this.maxWidth,
    required this.radius,
    this.stamp,
    this.onTap,
  });

  final ExpressionItem item;
  final double maxWidth;
  final BorderRadius radius;
  final MessageStamp? stamp;

  /// Opens the GIF's sheet (star it, report it). With autoplay off the first
  /// tap plays it instead, and this is one tap further on.
  final VoidCallback? onTap;

  @override
  State<GifMessageTile> createState() => _GifMessageTileState();
}

class _GifMessageTileState extends State<GifMessageTile> {
  /// A tap-to-play override for this one tile, when autoplay is off.
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final width = widget.maxWidth.clamp(120.0, kGifMessageMaxWidth);
    // Clamped so a panorama or a sliver cannot produce a tile that is a line
    // or a tower.
    final height = width / item.aspectRatio.clamp(0.6, 2.2);
    final autoplay = expressionsAutoplay(context);
    final play = autoplay || _playing;
    final url = item.url;

    Widget tile = url == null
        ? ExpressionPlaceholder(width: width, height: height)
        : KlipyImage(
            url: url,
            width: width,
            height: height,
            play: play,
            radius: widget.radius.topLeft.x,
          );

    if (!play) {
      tile = Stack(
        children: [
          tile,
          Positioned(
            left: 8,
            top: 8,
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'GIF',
                  style: theme.monoTiny.copyWith(
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    tile = Semantics(
      image: true,
      label: l10n.expressionGifSemantics(item.title ?? ''),
      onTapHint: autoplay ? null : l10n.expressionPlayGifHint,
      child: ExcludeSemantics(child: tile),
    );

    if (!autoplay || widget.onTap != null) {
      tile = GestureDetector(
        onTap: () {
          if (!autoplay && !_playing) {
            setState(() => _playing = true);
            return;
          }
          widget.onTap?.call();
        },
        child: tile,
      );
    }

    return StampedMedia(tile: tile, stamp: widget.stamp);
  }
}

/// A sticker message: the art alone, floating on the transcript.
class StickerMessage extends StatefulWidget {
  const StickerMessage({
    super.key,
    required this.item,
    required this.api,
    this.onTap,
  });

  final ExpressionItem item;
  final ChatApi api;

  /// Opens the sticker's sheet (star it, see its pack). Null leaves it inert.
  final VoidCallback? onTap;

  @override
  State<StickerMessage> createState() => _StickerMessageState();
}

class _StickerMessageState extends State<StickerMessage> {
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final autoplay = expressionsAutoplay(context);
    final art = StickerArt(
      item: widget.item,
      size: kStickerMessageSize,
      api: widget.api,
      play: autoplay || _playing,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // With autoplay off the first tap plays it, like a GIF; the sheet is
        // one more tap away.
        if (!autoplay && !_playing) {
          setState(() => _playing = true);
          return;
        }
        widget.onTap?.call();
      },
      child: art,
    );
  }
}
