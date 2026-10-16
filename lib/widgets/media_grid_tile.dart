import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/storage/media_ledger.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'media_flight.dart';
import 'video_length_badge.dart';
import 'dust/spoiler_dust.dart' show SpoilerDust;
import 'media_spoiler.dart';
import 'remote_image.dart';
import 'selection_check.dart';
import 'steady_hero.dart';

/// Hero tag tying a grid tile to its page in the fullscreen pager.
///
/// Deliberately not the bubble's `msg-image-<id>`. A transcript bubble for the
/// same message can be alive on the room screen further down the stack, and two
/// heroes sharing a tag on routes that both take part in a flight is an
/// assertion, not a graceful degrade.
String roomMediaHeroTag(String messageId) => 'room-media-$messageId';

/// One square in the shared-content grid.
///
/// **Never mounts `VideoMessage`.** That widget builds a
/// `VideoPlayerController` per instance and calls `initialize()` on it, so a
/// screenful of forty videos would be forty concurrent media pipelines — forty
/// `<video>` elements on web. A video shows its poster if it has one and a play
/// glyph if it does not; actual playback belongs to the fullscreen pager, where
/// there is exactly one.
///
/// A poster is absent on every video sent from web or desktop and on all
/// history, because extraction is Android/iOS only. That is permanent rather
/// than a migration state, so the glyph tile is designed to look like a
/// deliberate representation of a video rather than a failed image load.
class MediaGridTile extends StatelessWidget {
  const MediaGridTile({
    super.key,
    required this.message,
    required this.api,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    this.longPressInRegion = false,
    this.decodeWidth,
  });

  final ChatMessage message;
  final ChatApi api;

  /// Picked, in selection mode.
  final bool selected;

  /// Selection mode is on — every tile shows its checkbox, picked or not, so
  /// the affordance is discoverable without a second long-press.
  final bool selecting;

  final VoidCallback onTap;

  /// Starts selecting with this tile. Right-click always reaches it (the
  /// desktop long-press); a held finger reaches it only when
  /// [longPressInRegion] is false.
  final VoidCallback onLongPress;

  /// The grid is a `DragSelectRegion`, which owns the long press so the
  /// same finger can go on to drag a range. The tile then leaves it alone.
  final bool longPressInRegion;

  /// Device-pixel width to decode at. A grid tile is a fraction of the screen,
  /// so decoding at full size is the difference between a smooth scroll and a
  /// stuttering one — the same argument `RemoteImage` makes at length.
  final int? decodeWidth;

  /// A circular video note is a video here too: the grid shows it as one
  /// clip among the rest, and its `.mp4` id handed to an image decoder is a
  /// broken tile. See `MediaPagerScreen`'s `_isMovie`, which fixed the same
  /// thing on the other end of the flight.
  bool get _isVideo =>
      message.type == MessageType.video ||
      message.type == MessageType.videoNote;

  Widget _picture(String imageId) => RemoteImage(
        storageId: imageId,
        api: api,
        fit: BoxFit.cover,
        // Square, as Photos draws it: the 2pt gaps are the grid's only lines.
        borderRadius: BorderRadius.zero,
        decodeWidth: decodeWidth,
      );

  @override
  Widget build(BuildContext context) {
    // Files this tile's media under its chat for Data and Storage: a video
    // opened from the room's shared media never passed through a bubble.
    MediaLedger.instance.noteSeen(message);
    final theme = ThemeScope.of(context);
    // A video prefers its poster; the raw video id would resolve to a URL
    // `RemoteImage` cannot decode, which renders as a broken tile rather than
    // as nothing.
    final imageId = _isVideo ? message.posterStorageId : message.mediaStorageId;
    final l10n = AppLocalizations.of(context);

    return FocusableTap(
      onTap: onTap,
      semanticLabel: _isVideo
          ? l10n.bubbleStyleScreenMediaTileVideoSemanticLabel
          : l10n.bubbleStyleScreenMediaTilePhotoSemanticLabel,
      radius: 2,
      inset: 1,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: longPressInRegion ? null : onLongPress,
        // Right-click is the desktop long-press, and the only pointer idiom
        // there for "act on this without opening it".
        onSecondaryTap: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // `SteadyHero`, not `Hero`: a plain one tears its child out of the
            // tree for the length of the flight at BOTH ends, so the tile a
            // picture flies home to is destroyed at take-off and rebuilt from
            // nothing on touchdown — with no resolved URL and a decode that
            // spent the flight with no listener holding it in the ImageCache.
            // The landing is a hole in the shape of the photograph. See the
            // class comment on SteadyHero, which exists for exactly this.
            //
            // The glyph tile gets one too, so a posterless video still flies
            // rather than snapping — the destination has the same glyph.
            SteadyHero(
              tag: roomMediaHeroTag(message.id),
              // The tile settles what the flight looks like rather than leaving
              // it to the gallery, because the crop and the warm decode are
              // both known here and nowhere else. A grid tile is a hard square
              // crop of a picture that is almost never square, and Flutter's
              // default shuttle would paint the gallery's `contain` — which
              // letterboxes the photograph inside the small end of the flight
              // and then snaps to this crop on landing.
              flightShuttleBuilder: imageId == null
                  ? null
                  : mediaFlightShuttle(
                      image: RemoteImage(
                        storageId: imageId,
                        api: api,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.zero,
                        decodeWidth: decodeWidth,
                      ),
                    ),
              child: imageId == null
                  ? _GlyphTile(theme: theme, isVideo: _isVideo)
                  : message.mediaSpoiler
                  // Shared media keeps a spoiler hidden too. The tap still
                  // opens it, as a choice to look, and the viewer shows it.
                  ? MediaSpoilerCover(
                      interactive: false,
                      sigma: 10,
                      dustDensity: SpoilerDust.defaultDensity / 3,
                      revealKey: message.id,
                      child: _picture(imageId),
                    )
                  : _picture(imageId),
            ),

            // Not while choosing: the check takes the same corner, and a
            // video's length is not what a selection is deciding.
            if (_isVideo && !selecting)
              _VideoOverlay(
                storageId: message.mediaStorageId,
                durationMs: message.mediaDurationMs,
                api: api,
              ),

            if (selecting)
              _SelectionVeil(theme: theme, selected: selected),
          ],
        ),
      ),
    );
  }
}

/// What a tile draws when there is no picture to draw — a video with no poster,
/// or an attachment whose blob has gone.
class _GlyphTile extends StatelessWidget {
  const _GlyphTile({required this.theme, required this.isVideo});

  final AppTheme theme;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.surfaceSunken,
      alignment: Alignment.center,
      child: Icon(
        isVideo ? CupertinoIcons.film : CupertinoIcons.photo,
        size: 22,
        color: theme.inkMuted.withValues(alpha: 0.5),
      ),
    );
  }
}

/// A video's mark on a tile: its running time on the shared duration badge,
/// a play glyph leading it, in the bottom-right corner — iOS Photos' tile.
///
/// One mark, not two. The tile used to put a play disc bottom-left AND the
/// duration bottom-right, and the pair said "video" twice across a picture
/// three tiles wide. A clip with no known length keeps just the glyph on the
/// same badge, so it still says what it is.
class _VideoOverlay extends StatelessWidget {
  const _VideoOverlay({
    required this.storageId,
    required this.durationMs,
    required this.api,
  });

  final String? storageId;
  final int? durationMs;
  final ChatApi api;

  @override
  Widget build(BuildContext context) => Positioned(
        right: 6,
        bottom: 6,
        // Fills in a length the sender never measured; see VideoLengthBadge.
        child: VideoLengthBadge(
          storageId: storageId,
          durationMs: durationMs,
          api: api,
          withIcon: true,
        ),
      );
}

/// The selection state drawn over a tile, the way iOS Photos draws it: the
/// circle in the bottom-right corner, a picked tile dimmed a fifth under a
/// filled check, an unpicked one left alone with an empty ring.
///
/// Dimmed, not washed in the accent. A blue film over a photograph changes
/// what the picture looks like; a slight darkening only says "this one".
class _SelectionVeil extends StatelessWidget {
  const _SelectionVeil({required this.theme, required this.selected});

  final AppTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: theme.motionFast,
        curve: Curves.easeOutCubic,
        color: selected
            ? Colors.black.withValues(alpha: 0.20)
            : Colors.black.withValues(alpha: 0),
        alignment: Alignment.bottomRight,
        padding: const EdgeInsets.all(6),
        child: SelectionCheck(picked: selected, media: true, size: 24),
      ),
    );
  }
}
