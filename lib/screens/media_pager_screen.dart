import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../theme/theme_scope.dart';
import '../widgets/media_grid_tile.dart' show roomMediaHeroTag;
import '../widgets/remote_image.dart';
import '../widgets/route_landing.dart';
import '../widgets/steady_hero.dart';
import 'fullscreen_video_viewer.dart';

/// Fullscreen media, swipeable across everything in the MEDIA tab.
///
/// `FullscreenImageViewer` opens exactly one picture and is the right thing
/// from a bubble, where "the next photo" has no meaning. From a grid it does:
/// the set is on screen, and a viewer that made you back out and tap again to
/// see the next one would be the only gallery that works that way.
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
  });

  final List<ChatMessage> items;
  final int initialIndex;
  final ChatApi api;

  /// Pops the pager and asks the room to travel to this message. Null when
  /// there is nothing to travel back to.
  final void Function(ChatMessage message)? onShowInChat;

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
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<MediaPagerScreen> createState() => _MediaPagerScreenState();
}

class _MediaPagerScreenState extends State<MediaPagerScreen> {
  late final PageController _pager;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pager = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final current = widget.items[_index];

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: Colors.white),
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xF2000000))),
            Positioned.fill(
              child: PageView.builder(
                controller: _pager,
                itemCount: widget.items.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => HeroMode(
                  // Neighbours stay built; only the visible one may fly. See
                  // the class comment.
                  enabled: i == _index,
                  child: _Page(message: widget.items[i], api: widget.api),
                ),
              ),
            ),
            _Chrome(
              message: current,
              position: AppLocalizations.of(context).photoChromeMediaPositionLabel(
                _index + 1,
                widget.items.length,
              ),
              onClose: () => Navigator.of(context).pop(_index),
              onShowInChat: widget.onShowInChat == null
                  ? null
                  : () => widget.onShowInChat!(current),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.message, required this.api});

  final ChatMessage message;
  final ChatApi api;

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

    if (message.type == MessageType.video) {
      return _VideoPage(message: message, api: api);
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: mediaFlight(
          message,
          RemoteImage(storageId: id, api: api, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Pairs a page with its grid tile for the open/close flight.
///
/// `SteadyHero` rather than `Hero` for the reason its own doc gives: a plain
/// one tears the child out of the tree at both ends of a flight, so the
/// picture arrives as a hole and fills in a frame later.
Widget mediaFlight(ChatMessage message, Widget child) =>
    SteadyHero(tag: roomMediaHeroTag(message.id), child: child);

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
  const _VideoPage({required this.message, required this.api});

  final ChatMessage message;
  final ChatApi api;

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
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: playable ? _play : null,
            behavior: HitTestBehavior.opaque,
            // The disc below carries the label and the focus ring; this is the
            // same action with a bigger target, and announcing it twice would
            // put two identical buttons on one screen.
            excludeFromSemantics: true,
            child: Center(
              child: mediaFlight(
                widget.message,
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
            ),
          ),
        ),
        if (playable)
          // Held back until the picture has arrived. A disc fading in over a
          // photograph that has come to rest reads as the page finishing; the
          // same disc riding the flight in reads as a second thing moving.
          IgnorePointer(
            ignoring: !landed,
            child: AnimatedOpacity(
              opacity: landed ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: _PlayDisc(
                onTap: _play,
                semanticLabel: l10n.bubbleStyleScreenMediaTileVideoSemanticLabel,
              ),
            ),
          ),
      ],
    );
  }
}

/// The play affordance, at the same weight `VideoMessage` gives a video bubble
/// and `VideoPlayerSurface` gives a paused one — one glyph for "this is a video
/// and it is not playing" wherever the app draws it.
class _PlayDisc extends StatelessWidget {
  const _PlayDisc({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what actually receives the pointer. Both
    // carry the handler. Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      shape: FocusRingShape.circle,
      radius: 999,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

class _Chrome extends StatelessWidget {
  const _Chrome({
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
    final theme = ThemeScope.of(context);
    final pad = MediaQuery.paddingOf(context);

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, pad.top + 6, 8, 0),
        child: Row(
          children: [
            _GlassButton(
              icon: CupertinoIcons.xmark,
              semanticLabel: AppLocalizations.of(context).photoChromeCloseSemanticLabel,
              onTap: onClose,
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  message.senderName.isEmpty
                      ? AppLocalizations.of(context).photoChromeMediaYouLabel
                      : message.senderName,
                  style: theme.bodyEmph.copyWith(color: Colors.white),
                ),
                Text(
                  position,
                  style: theme.monoTiny.copyWith(color: Colors.white70),
                ),
              ],
            ),
            const Spacer(),
            if (onShowInChat != null)
              _GlassButton(
                icon: CupertinoIcons.chat_bubble,
                semanticLabel:
                    AppLocalizations.of(context).photoChromeShowInChatSemanticLabel,
                onTap: onShowInChat!,
              )
            else
              const SizedBox(width: 38),
          ],
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what actually receives the pointer. Both
    // carry the handler. Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: semanticLabel,
      shape: FocusRingShape.circle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x33FFFFFF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: Colors.white),
        ),
      ),
    );
  }
}
