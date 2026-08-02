import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../theme/theme_scope.dart';
import '../widgets/media_grid_tile.dart' show roomMediaHeroTag;
import '../widgets/remote_image.dart';
import '../widgets/steady_hero.dart';
import '../widgets/video_message.dart';

/// Fullscreen media, swipeable across everything in the MEDIA tab.
///
/// `FullscreenImageViewer` opens exactly one picture and is the right thing
/// from a bubble, where "the next photo" has no meaning. From a grid it does:
/// the set is on screen, and a viewer that made you back out and tap again to
/// see the next one would be the only gallery that works that way.
///
/// Only the current page mounts a [VideoMessage]. `PageView` keeps neighbours
/// alive, and each of those would otherwise build and `initialize()` its own
/// `VideoPlayerController` — three concurrent pipelines while swiping, and
/// three `<video>` elements on web.
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
                itemBuilder: (_, i) => _Page(
                  message: widget.items[i],
                  api: widget.api,
                  // Neighbours stay built; only the visible one may own a
                  // player. See the class comment.
                  active: i == _index,
                ),
              ),
            ),
            _Chrome(
              message: current,
              position: '${_index + 1} / ${widget.items.length}',
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
        child: Text('this file is gone', style: theme.bodySoft),
      );
    }

    if (message.type == MessageType.video) {
      if (!active) {
        // Poster if there is one, dark plate if not. Never a player.
        final poster = message.posterStorageId;
        return Center(
          child: _flight(
            poster == null
                ? const Icon(CupertinoIcons.film, size: 34, color: Colors.white24)
                : RemoteImage(storageId: poster, api: api, fit: BoxFit.contain),
          ),
        );
      }
      // No hero on the page that owns a player: a `VideoPlayer` texture cannot
      // be flown between routes, and asking it to produces a black rectangle
      // where the poster used to be. The poster on the inactive page above
      // carries the flight, which is the one that is on screen when a flight
      // actually starts.
      return Center(
        child: VideoMessage(api: api, storageId: id, isMine: false),
      );
    }

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: _flight(
          RemoteImage(storageId: id, api: api, fit: BoxFit.contain),
        ),
      ),
    );
  }

  /// Pairs this page with its grid tile for the open/close flight.
  ///
  /// `SteadyHero` rather than `Hero` for the reason its own doc gives: a plain
  /// one tears the child out of the tree at both ends of a flight, so the
  /// picture arrives as a hole and fills in a frame later.
  Widget _flight(Widget child) =>
      SteadyHero(tag: roomMediaHeroTag(message.id), child: child);
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
              semanticLabel: 'Close',
              onTap: onClose,
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  message.senderName.isEmpty ? 'you' : message.senderName,
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
                semanticLabel: 'Show in chat',
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
