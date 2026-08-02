import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../screens/room_items.dart' show formatClockDuration;
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'remote_image.dart';
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
  final VoidCallback onLongPress;

  /// Device-pixel width to decode at. A grid tile is a fraction of the screen,
  /// so decoding at full size is the difference between a smooth scroll and a
  /// stuttering one — the same argument `RemoteImage` makes at length.
  final int? decodeWidth;

  bool get _isVideo => message.type == MessageType.video;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // A video prefers its poster; the raw video id would resolve to a URL
    // `RemoteImage` cannot decode, which renders as a broken tile rather than
    // as nothing.
    final imageId = _isVideo ? message.posterStorageId : message.mediaStorageId;

    return FocusableTap(
      onTap: onTap,
      semanticLabel: _isVideo ? 'Video' : 'Photo',
      radius: 2,
      inset: 1,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
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
              child: imageId != null
                  ? RemoteImage(
                      storageId: imageId,
                      api: api,
                      fit: BoxFit.cover,
                      decodeWidth: decodeWidth,
                    )
                  : _GlyphTile(theme: theme, isVideo: _isVideo),
            ),

            if (_isVideo)
              _VideoOverlay(theme: theme, durationMs: message.mediaDurationMs),

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

/// The play badge and running time, over whatever is underneath.
///
/// Both sit in a dark lozenge rather than taking a theme colour: they are drawn
/// over a photograph, and no theme knows what colour that is.
class _VideoOverlay extends StatelessWidget {
  const _VideoOverlay({required this.theme, required this.durationMs});

  final AppTheme theme;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final ms = durationMs;
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0x66000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.play_fill,
                  size: 9, color: Colors.white),
            ),
            const Spacer(),
            if (ms != null && ms > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0x66000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  formatClockDuration(Duration(milliseconds: ms)),
                  style: theme.monoTiny.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The selection state drawn over a tile.
///
/// Unpicked tiles get an empty ring rather than nothing, so the whole grid says
/// "you are choosing" at a glance instead of only the tiles already chosen.
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
            ? theme.accent.withValues(alpha: 0.30)
            : Colors.black.withValues(alpha: 0.10),
        alignment: Alignment.topRight,
        padding: const EdgeInsets.all(5),
        child: Container(
          width: 19,
          height: 19,
          decoration: BoxDecoration(
            color: selected ? theme.accent : const Color(0x4D000000),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.4),
          ),
          child: selected
              ? Icon(CupertinoIcons.check_mark,
                  size: 12, color: theme.accentInk)
              : null,
        ),
      ),
    );
  }
}
