import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/media_aspect_cache.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../theme/theme_scope.dart';
import '../widgets/media_filmstrip.dart';
import '../widgets/media_grid_tile.dart' show roomMediaHeroTag;
import '../widgets/photo_backdrop.dart';
import '../widgets/photo_chrome.dart' show MediaPlayDisc;
import '../widgets/photo_dismiss_area.dart';
import '../widgets/remote_image.dart';
import '../widgets/route_landing.dart';
import '../widgets/spring_press.dart';
import '../widgets/steady_hero.dart';
import 'fullscreen_video_viewer.dart';
import '../widgets/glass_buttons.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/viewer_chrome.dart';

/// Fullscreen media, swipeable across a set — the MEDIA tab's grid, or every
/// picture in one conversation.
///
/// This is now what a photo in the transcript opens too. It used to be
/// `FullscreenImageViewer`, which shows exactly one picture: the right thing
/// from a bubble in 2010 and wrong ever since, because "the next photo" plainly
/// does have a meaning in a chat, and every messenger anyone has used since
/// then answers it by swiping. Backing out and hunting up the transcript for
/// the next photograph was the only gallery in the app that worked that way.
/// `FullscreenImageViewer` is still the right screen for a lone picture with no
/// set behind it — an avatar, a lifted bubble preview.
///
/// **No page here ever owns a video player.** A video is a poster with a play
/// disc on it, and playing hands off to [FullscreenVideoViewer] — which is to
/// say, to `AVPlayerViewController` or ExoPlayer, exactly as a tap on a video
/// in the transcript does. That is not a shortcut. The OS player is where
/// scrubbing, skip, speed, AirPlay/Cast, Picture-in-Picture, the lock-screen
/// transport controls and the system volume HUD already live, in the user's own
/// language; a Flutter texture with a progress bar drawn under it is a worse
/// copy of a player everyone already knows from Photos. The gallery used to
/// mount that copy inline, so the one place in the app that shows nothing but
/// media was the one place a video played worst.
///
/// Only the current page takes part in a hero flight. `Hero` collects every
/// hero in both routes' trees, visible or not, and a `PageView`'s neighbours
/// are built (they sit inside the viewport's cache extent) with the same tags
/// their grid tiles carry — so opening one photo used to launch three flights,
/// two of them dragging thumbnails off the side of the screen to pages nobody
/// had asked to see. [HeroMode] on the inactive pages is what limits the
/// flight to the one picture that was actually tapped.
class MediaPagerScreen extends StatefulWidget {
  const MediaPagerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.api,
    this.onShowInChat,
    this.onPageChanged,
    this.heroTagFor,
    this.sourceDecodeWidth,
  });

  final List<ChatMessage> items;
  final int initialIndex;
  final ChatApi api;

  /// Pops the pager and asks the room to travel to this message. Null when
  /// there is nothing to travel back to.
  final void Function(ChatMessage message)? onShowInChat;

  /// Reports the picture the reader has settled on, every time that changes.
  ///
  /// The route underneath uses it to keep the thumbnail for the current
  /// photograph laid out, so the flight home has somewhere to land. Swiping is
  /// how a reader ends up looking at a picture whose thumbnail is nowhere near
  /// the screen any more, and a Hero whose destination is not in the tree does
  /// not fail — it silently degrades to a cross-fade, which is the one thing
  /// this whole screen is built not to do.
  final void Function(ChatMessage message)? onPageChanged;

  /// The decode width, in device pixels, of the thumbnail this was opened from.
  ///
  /// A photograph is decoded at the size of the box it is painted into, so the
  /// fullscreen copy is a DIFFERENT `ImageCache` entry from the thumbnail that
  /// was just tapped — and the flight lands before that entry exists. Pinned to
  /// the thumbnail's the opening page paints from a decode that is already
  /// resident, and the sharp one is fetched once the picture has come to rest.
  /// See [RemoteImage.placeholderDecodeWidth].
  final int? sourceDecodeWidth;

  /// The [Hero] tag the picture for a message flies from and back to.
  ///
  /// Defaults to the grid's, because the grid was the only caller for as long
  /// as there was only one. The transcript's bubbles carry their own tags and
  /// have to hand theirs in, or a photo opened from a chat would fly from
  /// nowhere and land back nowhere — which is the state that reads as the app
  /// cutting to a picture rather than moving it.
  final Object Function(ChatMessage message)? heroTagFor;

  /// Returns the index the pager was left on, so the grid can put that tile
  /// back under the reader's eyes. Null if it was dismissed without settling.
  ///
  /// Swiping four photos deep and closing should not land you looking at the
  /// one you opened — and the hero has nowhere to fly home to if the tile it
  /// belongs to has been scrolled out of the grid's build range.
  static Future<int?> open(
    BuildContext context, {
    required List<ChatMessage> items,
    required int initialIndex,
    required ChatApi api,
    void Function(ChatMessage message)? onShowInChat,
    void Function(ChatMessage message)? onPageChanged,
    Object Function(ChatMessage message)? heroTagFor,
    int? sourceDecodeWidth,
  }) {
    return Navigator.of(context, rootNavigator: true).push<int>(
      PageRouteBuilder<int>(
        opaque: false,
        barrierColor: Colors.transparent,
        // Matches `FullscreenImageViewer`: the flight is a direct response to
        // a tap on the thing that flies, so it should feel like the picture
        // moved rather than like an animation played.
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, _, _) => MediaPagerScreen(
          items: items,
          initialIndex: initialIndex,
          api: api,
          onShowInChat: onShowInChat,
          onPageChanged: onPageChanged,
          heroTagFor: heroTagFor,
          sourceDecodeWidth: sourceDecodeWidth,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<MediaPagerScreen> createState() => _MediaPagerScreenState();
}

class _MediaPagerScreenState extends State<MediaPagerScreen>
    with RouteLanding {
  late final PageController _pager;
  late int _index;

  /// Live dismiss-drag offset, written by whichever page is under a finger and
  /// painted here. Shared across the pages on purpose — only one of them can be
  /// dragged at a time, and the thing that moves is the whole gallery.
  final ValueNotifier<Offset> _drag = ValueNotifier(Offset.zero);

  /// Whether the chrome is showing. A tap on the picture toggles it: this is
  /// the one screen in the app whose entire content is a photograph, and the
  /// furniture over it should get out of the way for the same reason a
  /// gallery's does everywhere else.
  bool _chrome = true;

  /// True while the current page is pinch- or double-tap-zoomed. The
  /// `PageView` stops scrolling for the duration, or a sideways drag meant to
  /// move around inside one photograph would flick to the next one instead —
  /// the single most annoying thing a zoomable pager can do.
  bool _zoomed = false;

  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pager = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pager.dispose();
    _drag.dispose();
    super.dispose();
  }

  /// Pops with the index the reader settled on. Guarded because a committed
  /// dismiss drag and a tap on the close button can land in the same frame.
  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(_index);
  }

  Object _heroTag(ChatMessage m) =>
      widget.heroTagFor?.call(m) ?? roomMediaHeroTag(m.id);

  void _jumpTo(int i) {
    if (i == _index) return;
    // Jumped, not animated. The rail can be dragged a long way from where the
    // pager is, and sliding forty photographs past the reader to answer a tap
    // on a thumbnail is a long wait for something they can already see.
    _pager.jumpToPage(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context);
    final current = widget.items[_index];
    // A rail under a set of one is a rail with one tile on it, saying nothing
    // the position counter above has not already said.
    final strip = widget.items.length > 1;

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: Colors.white),
        child: ValueListenableBuilder<Offset>(
          valueListenable: _drag,
          builder: (context, drag, pages) {
            final t = photoDismissProgress(drag, screen);
            // The chrome leaves twice as fast as the picture does, so it is
            // gone before the photograph is halfway home rather than riding
            // out over the transcript behind it.
            final chromeOpacity = _chrome ? (1 - t * 2).clamp(0.0, 1.0) : 0.0;

            return Stack(
              children: [
                // Painted inside the route rather than left to the barrier, so
                // it can fade to nothing as the drag commits — that is what
                // makes the Hero return read as the picture going back where it
                // came from rather than as a cut.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.95 * (1 - t)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: drag,
                    child: Transform.scale(
                      scale: 1 - t * kPhotoDismissShrink,
                      child: pages,
                    ),
                  ),
                ),
                _FadingChrome(
                  opacity: chromeOpacity,
                  child: _TopBar(
                    message: current,
                    position: AppLocalizations.of(context)
                        .photoChromeMediaPositionLabel(
                      _index + 1,
                      widget.items.length,
                    ),
                    onClose: _close,
                    onShowInChat: widget.onShowInChat == null
                        ? null
                        : () => widget.onShowInChat!(current),
                  ),
                ),
                if (strip)
                  _FadingChrome(
                    opacity: chromeOpacity,
                    alignBottom: true,
                    child: _Strip(
                      items: widget.items,
                      index: _index,
                      api: widget.api,
                      onTap: _jumpTo,
                    ),
                  ),
              ],
            );
          },
          // Built once and passed through the builder: the pages are the
          // expensive part and none of them depend on the drag offset.
          child: PageView.builder(
            controller: _pager,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.items.length,
            onPageChanged: (i) {
              setState(() {
                _index = i;
                // Belt and braces. A zoomed page cannot be swiped away, so this
                // should already be false — but a stuck `true` would leave the
                // gallery unswipeable with nothing on screen to explain why.
                _zoomed = false;
              });
              widget.onPageChanged?.call(widget.items[i]);
            },
            itemBuilder: (_, i) => HeroMode(
              // Neighbours stay built; only the visible one may fly. See the
              // class comment.
              enabled: i == _index,
              child: _Page(
                message: widget.items[i],
                api: widget.api,
                heroTag: _heroTag(widget.items[i]),
                // Only the page the flight actually opened on. The rest were
                // never a thumbnail on the route below, so there is no warm
                // decode of theirs to defer to, and offering one would only
                // pin them to a resolution they never had.
                sourceDecodeWidth:
                    i == widget.initialIndex ? widget.sourceDecodeWidth : null,
                landed: landed,
                drag: _drag,
                onDismiss: _close,
                onToggleChrome: () => setState(() => _chrome = !_chrome),
                onZoomChanged: (z) {
                  if (i == _index && z != _zoomed) {
                    setState(() => _zoomed = z);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds a piece of chrome against an edge of the screen and fades it.
///
/// [AnimatedOpacity] rather than a plain [Opacity] so the tap-to-hide toggle
/// is a fade and not a cut. It is driven by the dismiss drag as well, and at
/// 90ms that follows a finger closely enough to still read as continuous.
class _FadingChrome extends StatelessWidget {
  const _FadingChrome({
    required this.opacity,
    required this.child,
    this.alignBottom = false,
  });

  final double opacity;
  final Widget child;
  final bool alignBottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: alignBottom ? null : 0,
      bottom: alignBottom ? 0 : null,
      child: IgnorePointer(
        // Not merely invisible: hidden chrome that still swallowed taps would
        // make the gesture that hid it impossible to undo.
        ignoring: opacity < 0.05,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 90),
          child: child,
        ),
      ),
    );
  }
}

/// The thumbnail rail, plus the scrim that keeps it legible over a bright
/// photograph.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.items,
    required this.index,
    required this.api,
    required this.onTap,
  });

  final List<ChatMessage> items;
  final int index;
  final ChatApi api;
  final void Function(int i) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        MediaScrim(height: MediaFilmstrip.height + bottom + 24),
        Padding(
          padding: EdgeInsets.only(bottom: bottom + 6),
          child: MediaFilmstrip(
            count: items.length,
            index: index,
            onTap: onTap,
            tileSemanticLabel: (i, total) =>
                l10n.photoChromeThumbnailSemanticLabel(i, total),
            thumbnailBuilder: (_, i) => _Thumb(message: items[i], api: api),
          ),
        ),
      ],
    );
  }
}

/// One tile in the rail.
///
/// A video shows its poster with a play glyph on it rather than a still and
/// nothing else — the rail is how you find the clip you remember among forty
/// photographs, and "which of these is the video" is the one question it has to
/// answer that a photo's own thumbnail cannot.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.message, required this.api});

  final ChatMessage message;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final video = _isMovie(message);
    final id = video ? message.posterStorageId : message.mediaStorageId;
    if (id == null) {
      return ColoredBox(
        color: theme.surfaceSunken,
        child: Icon(
          video ? CupertinoIcons.film : CupertinoIcons.photo,
          size: 18,
          color: Colors.white24,
        ),
      );
    }
    final thumb = RemoteImage(
      storageId: id,
      api: api,
      // The box is already tight from the rail, so this only steers the
      // DECODE — 54pt of thumbnail has no business decoding at the screen cap,
      // which is what `decodeSizeFor` falls back to when neither axis is given.
      width: MediaFilmstrip.tileSize,
      height: MediaFilmstrip.tileSize,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
    );
    if (!video) return thumb;
    return Stack(
      fit: StackFit.expand,
      children: [
        thumb,
        const Center(
          child: Icon(
            CupertinoIcons.play_fill,
            size: 16,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}

/// Whether [m] is a movie rather than a photograph, for the two places on this
/// screen that have to draw a poster and a play glyph instead of a picture.
///
/// [MessageType.videoNote] belongs here and used to be missing, which was a
/// real bug rather than a nicety: the shared-content MEDIA tab puts circular
/// video notes in the same grid as everything else, so swiping onto one handed
/// its `.mp4` storage id to a `RemoteImage` and drew a broken-image glyph on a
/// clip that plays perfectly well.
bool _isMovie(ChatMessage m) =>
    m.type == MessageType.video || m.type == MessageType.videoNote;

class _Page extends StatelessWidget {
  const _Page({
    required this.message,
    required this.api,
    required this.heroTag,
    required this.sourceDecodeWidth,
    required this.landed,
    required this.drag,
    required this.onDismiss,
    required this.onToggleChrome,
    required this.onZoomChanged,
  });

  final ChatMessage message;
  final ChatApi api;
  final Object heroTag;

  /// See [MediaPagerScreen.sourceDecodeWidth]. Null on every page but the one
  /// the gallery opened on.
  final int? sourceDecodeWidth;

  /// Whether the opening flight has finished — see [RouteLanding]. The
  /// full-resolution decode is held back until it has, so the megabytes it
  /// costs are not spent in competition with the one moment the picture is
  /// moving.
  final bool landed;

  final ValueNotifier<Offset> drag;
  final VoidCallback onDismiss;
  final VoidCallback onToggleChrome;
  final void Function(bool zoomed) onZoomChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final id = message.mediaStorageId;
    if (id == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).photoChromeMediaGoneLabel,
          style: theme.bodySoft,
        ),
      );
    }

    if (_isMovie(message)) {
      return _VideoPage(
        message: message,
        api: api,
        heroTag: heroTag,
        drag: drag,
        onDismiss: onDismiss,
      );
    }

    // Always the whole picture, never a `cover` crop. A chat photo is
    // something somebody sent you to look at, and filling a tall phone with a
    // 3:4 shot cut about 38% of it off the sides — the edges of the frame were
    // simply not reachable without pinching. The blurred backdrop fills the
    // space around it instead, so the chrome still floats over the picture's
    // own colour rather than dead black.
    final image = RemoteImage(
      storageId: id,
      api: api,
      fit: BoxFit.contain,
      borderRadius: BorderRadius.zero,
      placeholderDecodeWidth: sourceDecodeWidth,
      decodeWidth: landed ? null : sourceDecodeWidth,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // The chrome above and the rail below sit on the picture's own blurred
        // colour rather than on dead black. Reuses the thumbnail decode where
        // the flight already warmed one, so it costs nothing on the page you
        // opened.
        PhotoBackdrop(
          image: RemoteImage(
            storageId: id,
            api: api,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.zero,
            decodeWidth: sourceDecodeWidth ?? kPhotoBackdropDecodeWidth,
          ),
        ),
        PhotoDismissArea(
          drag: drag,
          onDismiss: onDismiss,
          onTap: onToggleChrome,
          onZoomChanged: onZoomChanged,
          maxScale: 4,
          child: mediaFlight(heroTag, _shaped(image)),
        ),
      ],
    );
  }

  /// The picture's width÷height, when anybody knows it.
  ///
  /// The sender usually tells us, and [MediaAspectCache] remembers the ones who
  /// did not from the last time this device drew the thumbnail. Null when
  /// neither does, which [_shaped] reads as "show the whole thing" — the answer
  /// that is never wrong.
  double? get _aspect {
    final aspect =
        message.mediaAspectRatio ??
        MediaAspectCache.instance.peek(message.mediaStorageId ?? '');
    if (aspect == null || !aspect.isFinite || aspect <= 0) return null;
    return aspect;
  }

  /// Pins the picture's box to its own shape, when the shape is known.
  ///
  /// Without it the hero's destination is the whole screen, because that is
  /// what a `contain` image with no intrinsic size yet measures — so a flight
  /// blows the thumbnail up to the full frame and the photograph then drops
  /// into its letterbox a frame later. [PhotoDismissArea] centres what it is
  /// given under loose constraints, so this settles at the largest rect of
  /// that ratio which fits: exactly where the decoded picture would have
  /// landed anyway, one frame earlier and without the jump.
  ///
  /// The sender usually tells us the shape, and [MediaAspectCache] remembers
  /// the ones who did not from the last time this device drew the thumbnail.
  /// When neither knows, the old full-screen destination is still the honest
  /// answer — there is nothing to pin it to.
  Widget _shaped(Widget image) {
    final aspect = _aspect;
    if (aspect == null) return image;
    return AspectRatio(aspectRatio: aspect, child: image);
  }
}

/// Pairs a page with the thumbnail it was opened from, for the open/close
/// flight.
///
/// `SteadyHero` rather than `Hero` for the reason its own doc gives: a plain
/// one tears the child out of the tree at both ends of a flight, so the
/// picture arrives as a hole and fills in a frame later.
Widget mediaFlight(Object tag, Widget child) =>
    SteadyHero(tag: tag, child: child);

/// A video page: a poster with a play disc on it, and nothing else.
///
/// Reached by *swiping* — a video tapped in the grid goes straight to the
/// player and never comes through here, so nothing on this page plays by
/// itself. That is deliberate twice over: a fullscreen OS player shoved up
/// every time a video scrolled past would make the gallery unswipeable, and
/// the page you actually asked for should not cost a second tap.
///
/// Playing means [FullscreenVideoViewer], which resolves the file (from the
/// cache when it is already there), hands it to the OS player and steps out of
/// the way — leaving this pager underneath, so closing the player puts the
/// gallery back exactly where it was. The reason it goes through a route
/// rather than calling the platform channel from here is that the viewer
/// already owns the parts nobody should write twice: the download with its
/// progress ring, the capture shield's translated copy, and the Flutter player
/// that covers web, desktop, and any build where the handoff declines.
///
/// A video was also the one thing in this gallery that arrived with no flight
/// at all: you tapped a tile and the pager cross-faded in over it while every
/// photo beside it flew. The cause was the obvious fix for a real problem — a
/// `VideoPlayer` texture cannot be flown between routes, it arrives as a black
/// rectangle where the poster was, so the active page carried no hero. But the
/// active page is precisely the one a flight needs a destination on. With no
/// player in the tree at all there is nothing left to work around: the poster
/// is simply always there, and it flies both ways.
class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.message,
    required this.api,
    required this.heroTag,
    required this.drag,
    required this.onDismiss,
  });

  final ChatMessage message;
  final ChatApi api;
  final Object heroTag;
  final ValueNotifier<Offset> drag;
  final VoidCallback onDismiss;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with RouteLanding {
  /// So the play disc gets out of the way on the way out, rather than hanging
  /// over the hole the poster just flew out of.
  @override
  bool get unlandsOnExit => true;

  void _play() {
    final id = widget.message.mediaStorageId;
    if (id == null || !mounted) return;
    // No hero tag: this poster and the viewer's are the same picture at the
    // same size, so a flight between them would animate nothing.
    FullscreenVideoViewer.open(
      context,
      storageId: id,
      api: widget.api,
      posterStorageId: widget.message.posterStorageId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Poster if there is one, film glyph if not. The glyph flies too, so a
    // posterless video still travels rather than snapping into place — the tile
    // it left behind draws the same one.
    final poster = widget.message.posterStorageId;
    final playable = widget.message.mediaStorageId != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null)
          PhotoBackdrop(
            image: RemoteImage(
              storageId: poster,
              api: widget.api,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
              decodeWidth: kPhotoBackdropDecodeWidth,
            ),
          ),
        PhotoDismissArea(
          drag: widget.drag,
          onDismiss: widget.onDismiss,
          // A tap on a video means play, not "hide the chrome". The disc below
          // is the same action with a smaller target and a focus ring on it.
          onTap: playable ? _play : null,
          // A poster is not a photograph to examine: zooming one would enlarge
          // a still of something the OS player is one tap away from showing
          // properly.
          maxScale: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              mediaFlight(
                widget.heroTag,
                poster == null
                    ? const Icon(
                        CupertinoIcons.film,
                        size: 34,
                        color: Colors.white24,
                      )
                    : RemoteImage(
                        storageId: poster,
                        api: widget.api,
                        fit: BoxFit.contain,
                      ),
              ),
              if (playable)
                // Held back until the picture has arrived. A disc fading in
                // over a photograph that has come to rest reads as the page
                // finishing; the same disc riding the flight in reads as a
                // second thing moving.
                IgnorePointer(
                  ignoring: !landed,
                  child: AnimatedOpacity(
                    opacity: landed ? 1 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: _PlayDisc(
                      onTap: _play,
                      semanticLabel:
                          l10n.bubbleStyleScreenMediaTileVideoSemanticLabel,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The play affordance: the shared [MediaPlayDisc] at viewer size — one mark
/// for "this is a video and it is not playing" wherever the app draws it —
/// made pressable here with a spring and a focus stop.
class _PlayDisc extends StatelessWidget {
  const _PlayDisc({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => SpringPress(
        onTap: onTap,
        semanticLabel: semanticLabel,
        focusShape: FocusRingShape.circle,
        focusRadius: 32,
        child: const MediaPlayDisc(size: 64),
      );
}

/// The pager's top bar: the shared viewer chrome, with who sent it and where
/// in the album this is.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.message,
    required this.position,
    required this.onClose,
    required this.onShowInChat,
  });

  final ChatMessage message;
  final String position;
  final VoidCallback onClose;
  final VoidCallback? onShowInChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ViewerTopBar(
      onClose: onClose,
      closeLabel: l10n.photoChromeCloseSemanticLabel,
      title: message.senderName.isEmpty
          ? l10n.photoChromeMediaYouLabel
          : message.senderName,
      subtitle: position,
      actions: [
        if (onShowInChat != null)
          GlassIconButton(
            tone: GlassTone.media,
            icon: CupertinoIcons.chat_bubble,
            semanticLabel: l10n.photoChromeShowInChatSemanticLabel,
            onTap: onShowInChat,
          ),
      ],
    );
  }
}
