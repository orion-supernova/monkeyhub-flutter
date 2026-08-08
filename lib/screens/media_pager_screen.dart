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
import '../widgets/video_message.dart' show VideoPlayerSurface;

/// Fullscreen media, swipeable across everything in the MEDIA tab.
///
/// `FullscreenImageViewer` opens exactly one picture and is the right thing
/// from a bubble, where "the next photo" has no meaning. From a grid it does:
/// the set is on screen, and a viewer that made you back out and tap again to
/// see the next one would be the only gallery that works that way.
///
/// Only the current page mounts a [VideoPlayerSurface]. `PageView` keeps
/// neighbours alive, and each of those would otherwise build and
/// `initialize()` its own `VideoPlayerController` — three concurrent
/// pipelines while swiping, and three `<video>` elements on web.
///
/// Only the current page takes part in a hero flight either, for a related
/// reason. `Hero` collects every hero in both routes' trees, visible or not,
/// and a `PageView`'s neighbours are built (they sit inside the viewport's
/// cache extent) with the same tags their grid tiles carry — so opening one
/// photo used to launch three flights, two of them dragging thumbnails off the
/// side of the screen to pages nobody had asked to see. [HeroMode] on the
/// inactive pages is what limits the flight to the one picture that was
/// actually tapped.
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
                  // Neighbours stay built; only the visible one may own a
                  // player, and only the visible one may fly. See the class
                  // comment for both.
                  enabled: i == _index,
                  child: _Page(
                    message: widget.items[i],
                    api: widget.api,
                    active: i == _index,
                  ),
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
  const _Page({
    required this.message,
    required this.api,
    required this.active,
  });

  final ChatMessage message;
  final ChatApi api;
  final bool active;

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
      return _VideoPage(message: message, api: api, active: active);
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

/// A video page: the poster while the route is moving, the real player once it
/// has stopped.
///
/// A video used to be the one thing in this grid that opened with no flight at
/// all — you tapped a tile and the pager cross-faded in over it, while every
/// photo beside it flew. The cause was the obvious fix for a real problem: a
/// `VideoPlayer` texture cannot be flown between routes (it arrives as a black
/// rectangle where the poster was), so the active page carried no hero, and
/// the active page is precisely the one a flight needs a destination on. The
/// poster left on the *inactive* pages could never stand in for it, because
/// the page being opened is by definition the active one.
///
/// So the player is not what flies — it is not even mounted yet. The poster is,
/// and it hands over to [VideoPlayerSurface] the moment the route settles,
/// which is invisible: the surface draws that same poster as its own backdrop,
/// letterboxed by the same [BoxFit.contain] into the same box, so the picture
/// does not move on the swap.
///
/// [RouteLanding.unlandsOnExit] is what gives the pop a hero to fly home: the
/// player is torn down and the poster is back in the tree a frame before
/// Flutter goes looking for flight candidates. Tearing the player down is
/// wanted anyway — a video that keeps playing over a closing route is a video
/// you can still hear.
class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.message,
    required this.api,
    required this.active,
  });

  final ChatMessage message;
  final ChatApi api;
  final bool active;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with RouteLanding {
  /// A closing route has to get its poster back before the flight is measured.
  @override
  bool get unlandsOnExit => true;

  @override
  Widget build(BuildContext context) {
    if (widget.active && landed) {
      return Center(
        child: VideoPlayerSurface(
          api: widget.api,
          storageId: widget.message.mediaStorageId,
          posterStorageId: widget.message.posterStorageId,
        ),
      );
    }

    // Poster if there is one, film glyph if not. Never a player — that is the
    // whole point of this branch, and of the grid tile's identical rule.
    //
    // The glyph flies too, so a posterless video still travels rather than
    // snapping into place; the tile it leaves behind draws the same one.
    final poster = widget.message.posterStorageId;
    return Center(
      child: mediaFlight(
        widget.message,
        poster == null
            ? const Icon(CupertinoIcons.film, size: 34, color: Colors.white24)
            : RemoteImage(storageId: poster, api: widget.api, fit: BoxFit.contain),
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
