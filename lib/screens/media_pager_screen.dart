import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/media_aspect_cache.dart';
import '../media/storage/media_ledger.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/forward_target_sheet.dart';
import '../widgets/media_filmstrip.dart';
import '../widgets/media_grid_tile.dart' show roomMediaHeroTag;
import '../widgets/photo_chrome.dart' show MediaDurationBadge, MediaPlayDisc;
import '../widgets/photo_dismiss_area.dart';
import '../widgets/remote_image.dart';
import '../widgets/route_landing.dart';
import '../widgets/spring_press.dart';
import '../widgets/steady_hero.dart';
import '../widgets/video_message.dart' show VideoPlayerSurface;
import 'room_content_actions.dart';
import '../widgets/viewer_chrome.dart';

/// What the gallery's bottom toolbar can do with the picture on screen.
///
/// The pager draws the toolbar, asks before deleting and says what happened;
/// these do the work. Each is optional, and a null one hides its button — a
/// pager opened somewhere with no room to forward from simply has no Forward.
///
/// [MediaPagerActions.room] is the whole set for a conversation, so the
/// transcript and the room's shared-content grid hand the gallery one value
/// rather than four closures each.
class MediaPagerActions {
  const MediaPagerActions({
    this.currentUserId,
    this.onShare,
    this.onSave,
    this.onForward,
    this.onDelete,
  });

  /// Whose pictures may be deleted: Delete shows only on [currentUserId]'s.
  final String? currentUserId;

  /// The OS share sheet. False when nothing could be handed to it.
  final Future<bool> Function(ChatMessage m)? onShare;

  /// Save to the photo library. False when it did not save.
  final Future<bool> Function(ChatMessage m)? onSave;

  /// Picks chats and forwards into them, from [context] (the sheet needs one).
  /// The number of chats it reached; null when the reader backed out.
  final Future<int?> Function(BuildContext context, ChatMessage m)? onForward;

  /// Delete for everyone, AFTER the pager has asked. False when the server
  /// refused it.
  final Future<bool> Function(ChatMessage m)? onDelete;

  /// The full set for one conversation, built on the same helpers the
  /// shared-content grid's action bar uses, so "share a photo" is one
  /// implementation whether one or forty are picked.
  ///
  /// [onDeleted] lets the opener drop the row from its own list straight
  /// away rather than waiting on a subscription.
  factory MediaPagerActions.room({
    required ChatRepository repo,
    required ChatApi api,
    required String roomId,
    void Function(ChatMessage m)? onDeleted,
  }) {
    return MediaPagerActions(
      currentUserId: repo.userId,
      onShare: (m) => shareMessages(api: api, messages: [m]),
      // `gal` has no web implementation — see [saveMessagesToDevice].
      onSave: kIsWeb
          ? null
          : (m) async =>
              (await saveMessagesToDevice(api: api, messages: [m])).ok > 0,
      onForward: (context, m) async {
        final targets = await showForwardTargetSheet(
          context,
          repo: repo,
          messageCount: 1,
          excludeRoomId: roomId,
        );
        if (targets == null || targets.isEmpty) return null;
        final result = await forwardMessages(
          api: api,
          repo: repo,
          sourceRoomId: roomId,
          targets: [for (final t in targets) t.id],
          messages: [m],
        );
        return result.ok;
      },
      onDelete: (m) async {
        final result =
            await deleteMessages(api: api, repo: repo, messageIds: [m.id]);
        if (result.ok > 0) onDeleted?.call(m);
        return result.ok > 0;
      },
    );
  }
}

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
/// **A video plays in place, inside this chrome.** It used to hand off to the
/// OS player (see `FullscreenVideoViewer`), and a video tapped in a grid went
/// straight there without passing through here, so the same clip was two
/// different screens depending on whether it was tapped or swiped onto: a
/// different close, different controls, a different way back. A gallery is
/// one screen. Only the current page ever holds a player; see [_VideoPage].
/// A video in the transcript still opens the OS player, where it is the only
/// thing being looked at.
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
    this.actions,
    this.fileAsSeen = true,
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

  /// The bottom toolbar's actions. Null draws no toolbar at all.
  final MediaPagerActions? actions;

  /// Whether each page reached is filed under its chat in [MediaLedger]. Off
  /// for a set that was rebuilt FROM the ledger (Storage Usage), whose
  /// messages may be stand-ins that know less than the ledger already does.
  final bool fileAsSeen;

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
    MediaPagerActions? actions,
    bool fileAsSeen = true,
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
          actions: actions,
          fileAsSeen: fileAsSeen,
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

  /// The set as it stands now. A copy of [MediaPagerScreen.items] that only
  /// ever shrinks — Delete takes the picture out from under the reader and
  /// the gallery carries on with its neighbour, as Photos does.
  late final List<ChatMessage> _items = [...widget.items];

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

  /// An action is in flight. A second tap on Share while the first is still
  /// fetching the file would open two share sheets.
  bool _busy = false;

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

  /// Pops with the index the reader settled on — in the set the opener HANDED
  /// in, which is the list it knows, even after a delete has shortened ours.
  /// Guarded because a committed dismiss drag and a tap on the close button can
  /// land in the same frame.
  void _close() {
    if (_closing) return;
    _closing = true;
    final at = _items.isEmpty
        ? -1
        : widget.items.indexWhere((m) => m.id == _items[_index].id);
    Navigator.of(context).pop(at < 0 ? null : at);
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

  // ───────────────────────── toolbar ─────────────────────────

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }

  Future<void> _share(ChatMessage m) => _run(() async {
        final l10n = AppLocalizations.of(context);
        final toast = AppToast.of(context);
        final ok = await widget.actions!.onShare!(m);
        if (!ok) toast.show(l10n.photoChromeShareFailed, tone: ToastTone.danger);
      });

  Future<void> _save(ChatMessage m) => _run(() async {
        final l10n = AppLocalizations.of(context);
        final toast = AppToast.of(context);
        final ok = await widget.actions!.onSave!(m);
        toast.show(
          ok ? l10n.photoChromeSaved : l10n.photoChromeSaveFailed,
          tone: ok ? ToastTone.success : ToastTone.danger,
        );
      });

  Future<void> _forward(ChatMessage m) => _run(() async {
        final l10n = AppLocalizations.of(context);
        final toast = AppToast.of(context);
        final reached = await widget.actions!.onForward!(context, m);
        if (reached == null) return;
        if (reached > 0) {
          toast.show(l10n.photoChromeForwarded(reached), tone: ToastTone.success);
        } else {
          toast.show(l10n.photoChromeForwardFailed, tone: ToastTone.danger);
        }
      });

  Future<void> _delete(ChatMessage m) => _run(() async {
        final l10n = AppLocalizations.of(context);
        final toast = AppToast.of(context);
        final confirmed = await showConfirmSheet(
          context,
          headline: l10n.roomContentScreenDeleteHeadline(1),
          body: l10n.photoChromeDeleteBody,
          confirmLabel: l10n.roomContentScreenDeleteForEveryone,
        );
        if (!confirmed || !mounted) return;
        final ok = await widget.actions!.onDelete!(m);
        if (!mounted) return;
        if (!ok) {
          toast.show(l10n.photoChromeDeleteFailed, tone: ToastTone.danger);
          return;
        }
        final at = _items.indexWhere((x) => x.id == m.id);
        if (at < 0) return;
        if (_items.length == 1) {
          // Nothing left to look at. No flight home either — the tile it
          // would land on is the thing that was just deleted.
          _items.removeAt(at);
          _closing = true;
          Navigator.of(context).pop();
          return;
        }
        setState(() {
          _items.removeAt(at);
          // The page under the reader is now the one after it — or, at the
          // end of the set, the one before.
          if (_index >= _items.length) _index = _items.length - 1;
          _zoomed = false;
        });
        if (_pager.hasClients && _pager.page?.round() != _index) {
          _pager.jumpToPage(_index);
        }
        widget.onPageChanged?.call(_items[_index]);
      });

  /// How tall the filmstrip-and-toolbar band is, home indicator included.
  double _bottomChromeHeight(BuildContext context) {
    final strip = _items.length > 1;
    final tools = _toolbar(_items[_index]).isNotEmpty;
    if (!strip && !tools) return 0;
    return MediaQuery.paddingOf(context).bottom +
        (strip ? MediaFilmstrip.viewerHeight : 0) +
        (tools ? ViewerToolbar.height + (strip ? 8 : 0) : 0) +
        8;
  }

  List<ViewerToolbarAction> _toolbar(ChatMessage m) {
    final a = widget.actions;
    if (a == null) return const [];
    final l10n = AppLocalizations.of(context);
    // Nothing to share, save or forward once the blob has gone.
    final hasFile = m.mediaStorageId != null;
    return [
      if (a.onShare != null && hasFile)
        ViewerToolbarAction(
          icon: CupertinoIcons.square_arrow_up,
          semanticLabel: l10n.roomContentScreenShareAction,
          onTap: () => _share(m),
        ),
      if (a.onSave != null && hasFile)
        ViewerToolbarAction(
          icon: CupertinoIcons.arrow_down_to_line,
          semanticLabel: l10n.roomContentScreenSaveAction,
          onTap: () => _save(m),
        ),
      if (a.onForward != null)
        ViewerToolbarAction(
          icon: CupertinoIcons.arrowshape_turn_up_right,
          semanticLabel: l10n.roomContentScreenForwardAction,
          onTap: () => _forward(m),
        ),
      if (a.onDelete != null &&
          a.currentUserId != null &&
          m.senderId == a.currentUserId)
        ViewerToolbarAction(
          icon: CupertinoIcons.trash,
          semanticLabel: l10n.roomContentScreenDeleteAction,
          danger: true,
          onTap: () => _delete(m),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (_items.isEmpty) return const SizedBox.shrink();
    final screen = MediaQuery.sizeOf(context);
    final current = _items[_index];
    final l10n = AppLocalizations.of(context);
    // A rail under a set of one is a rail with one tile on it, saying nothing.
    final strip = _items.length > 1;
    final tools = _toolbar(current);

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
                // came from rather than as a cut. Fully black at rest: at 95%
                // the transcript bled through as a dirty grey.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 1 - t),
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
                  builder: (still) => _TopBar(
                    message: current,
                    position: l10n.photoChromeThumbnailSemanticLabel(
                      _index + 1,
                      _items.length,
                    ),
                    still: still,
                    onClose: _close,
                    onShowInChat: widget.onShowInChat == null
                        ? null
                        : () => widget.onShowInChat!(current),
                  ),
                ),
                if (strip || tools.isNotEmpty)
                  _FadingChrome(
                    opacity: chromeOpacity,
                    alignBottom: true,
                    builder: (_) => _BottomChrome(
                      items: _items,
                      index: _index,
                      api: widget.api,
                      strip: strip,
                      tools: tools,
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
            itemCount: _items.length,
            // Keyed by message, so a delete that slides every later page one
            // slot left hands each its own state rather than its neighbour's.
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String>) return null;
              final i = _items.indexWhere((m) => m.id == key.value);
              return i < 0 ? null : i;
            },
            onPageChanged: (i) {
              setState(() {
                _index = i;
                // A video's tap plays and pauses rather than toggling the
                // chrome, so landing on one with the chrome hidden would leave
                // no way to bring it back short of swiping away again.
                if (_isMovie(_items[i])) _chrome = true;
                // Belt and braces. A zoomed page cannot be swiped away, so this
                // should already be false — but a stuck `true` would leave the
                // gallery unswipeable with nothing on screen to explain why.
                _zoomed = false;
              });
              widget.onPageChanged?.call(_items[i]);
            },
            itemBuilder: (_, i) {
              // Every page reached by a swipe is filed under its chat, the
              // same as a bubble would file it. See `MediaLedger`.
              if (widget.fileAsSeen) MediaLedger.instance.noteSeen(_items[i]);
              return HeroMode(
                key: ValueKey<String>(_items[i].id),
                // Neighbours stay built; only the visible one may fly. See the
                // class comment.
                enabled: i == _index,
                child: _Page(
                  message: _items[i],
                  api: widget.api,
                  active: i == _index,
                  heroTag: _heroTag(_items[i]),
                  // Only the page the flight actually opened on. The rest were
                  // never a thumbnail on the route below, so there is no warm
                  // decode of theirs to defer to, and offering one would only
                  // pin them to a resolution they never had.
                  sourceDecodeWidth: _items[i].id ==
                          widget.items[widget.initialIndex
                                  .clamp(0, widget.items.length - 1)]
                              .id
                      ? widget.sourceDecodeWidth
                      : null,
                  landed: landed,
                  drag: _drag,
                  chromeClearance: _bottomChromeHeight(context),
                  onDismiss: _close,
                  onToggleChrome: () => setState(() => _chrome = !_chrome),
                  onZoomChanged: (z) {
                    if (i == _index && z != _zoomed) {
                      setState(() => _zoomed = z);
                    }
                  },
                ),
              );
            },
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
///
/// [builder] is told whether the chrome is anything but fully shown and at
/// rest, so the glass in it can step down to its blur-free twin for exactly
/// the frames it is fading — a `BackdropFilter` is never animated.
class _FadingChrome extends StatefulWidget {
  const _FadingChrome({
    required this.opacity,
    required this.builder,
    this.alignBottom = false,
  });

  final double opacity;
  final Widget Function(bool still) builder;
  final bool alignBottom;

  @override
  State<_FadingChrome> createState() => _FadingChromeState();
}

class _FadingChromeState extends State<_FadingChrome> {
  bool _fading = false;

  @override
  void didUpdateWidget(_FadingChrome old) {
    super.didUpdateWidget(old);
    if (old.opacity != widget.opacity) _fading = true;
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.opacity;
    return Positioned(
      left: 0,
      right: 0,
      top: widget.alignBottom ? null : 0,
      bottom: widget.alignBottom ? 0 : null,
      child: IgnorePointer(
        // Not merely invisible: hidden chrome that still swallowed taps would
        // make the gesture that hid it impossible to undo.
        ignoring: opacity < 0.05,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 90),
          onEnd: () {
            if (mounted && _fading) setState(() => _fading = false);
          },
          child: widget.builder(_fading || opacity < 1),
        ),
      ),
    );
  }
}

/// Everything under the picture: the thumbnail rail, the toolbar 8pt below
/// it, and the one scrim both sit on so they stay legible over a bright
/// photograph.
class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.items,
    required this.index,
    required this.api,
    required this.strip,
    required this.tools,
    required this.onTap,
  });

  final List<ChatMessage> items;
  final int index;
  final ChatApi api;
  final bool strip;
  final List<ViewerToolbarAction> tools;
  final void Function(int i) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasTools = tools.isNotEmpty;
    final height = (strip ? MediaFilmstrip.viewerHeight : 0) +
        (hasTools ? ViewerToolbar.height + (strip ? 8 : 0) : 0);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        MediaScrim(height: height + bottom + 40),
        Padding(
          padding: EdgeInsets.only(bottom: bottom + (hasTools ? 4 : 6)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (strip)
                MediaFilmstrip.viewer(
                  count: items.length,
                  index: index,
                  onTap: onTap,
                  tileSemanticLabel: (i, total) =>
                      l10n.photoChromeThumbnailSemanticLabel(i, total),
                  thumbnailBuilder: (_, i) => _Thumb(message: items[i], api: api),
                ),
              if (strip && hasTools) const SizedBox(height: 8),
              if (hasTools) ViewerToolbar(actions: tools),
            ],
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
    final video = _isMovie(message);
    final id = video ? message.posterStorageId : message.mediaStorageId;
    if (id == null) {
      // Fixed dark, not the theme's sunken surface: this rail sits on the
      // viewer's black on every theme, and a cream tile on Risograph read as
      // a hole punched in it.
      return ColoredBox(
        color: Colors.white.withValues(alpha: 0.06),
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
      // DECODE — 40pt of thumbnail has no business decoding at the screen cap,
      // which is what `decodeSizeFor` falls back to when neither axis is given.
      width: MediaFilmstrip.viewerTileSize,
      height: MediaFilmstrip.viewerTileSize,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
      onDark: true,
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
    required this.active,
    this.chromeClearance = 0,
  });

  final ChatMessage message;
  final ChatApi api;
  final Object heroTag;

  /// Whether this is the page on screen. See [_VideoPage.active].
  final bool active;

  /// How much of the screen's bottom the gallery's chrome covers — see
  /// [_VideoPage.chromeClearance].
  final double chromeClearance;

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
        active: active,
        heroTag: heroTag,
        drag: drag,
        onDismiss: onDismiss,
        chromeClearance: chromeClearance,
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
      onDark: true,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // The chrome above and the rail below sit on the picture's own blurred
        // colour rather than on dead black. Reuses the thumbnail decode where
        // the flight already warmed one, so it costs nothing on the page you
        // opened.
        // Black void around a photo that doesn't fill the screen, like
          // Photos — the blurred copy of the picture read as a smudge.
          const ColoredBox(color: Colors.black),
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

/// A video page: the poster with a play disc on it while the page is passing
/// by, and the video itself, playing in place, once the reader has settled
/// on it.
///
/// In place, inside this gallery's own chrome: the same top bar, the same
/// filmstrip, the same toolbar as the photograph beside it. It used to hand
/// off to [FullscreenVideoViewer] (the OS player, or the native gallery) on a
/// tap, and a video tapped in a grid went straight there without passing
/// through the pager at all. So one clip looked like two different screens
/// depending on whether you tapped it or swiped onto it, with a different
/// close, different controls and a different way back. Photos and Telegram
/// both answer it the same way: a video in a gallery is a page of the
/// gallery, and it plays where it is.
///
/// It starts by itself once the page has been the current one for a moment
/// ([_settle]), so a quick swipe past it costs nothing, and stops the instant
/// the reader moves on: only the current page ever holds a player.
///
/// The poster and the player share one box, the screen minus the top bar
/// and the bottom chrome, so the player's scrub rail is never under the
/// filmstrip and the poster it replaces sits at exactly the same rect. The
/// poster is what flies, both ways; a `VideoPlayer` texture cannot be carried
/// between routes.
class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.message,
    required this.api,
    required this.heroTag,
    required this.drag,
    required this.onDismiss,
    required this.active,
    this.chromeClearance = 0,
  });

  /// The bottom band the filmstrip and toolbar sit in, kept clear of the
  /// video whether or not the chrome is showing, so toggling it never moves
  /// the picture.
  final double chromeClearance;

  final ChatMessage message;
  final ChatApi api;
  final Object heroTag;
  final ValueNotifier<Offset> drag;
  final VoidCallback onDismiss;

  /// Whether this is the page on screen. Only that one may play.
  final bool active;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with RouteLanding {
  /// How long a page has to stay current before it starts playing. Long
  /// enough that flicking through ten pages never opens ten streams, short
  /// enough that the one you stopped on starts before you reach for it.
  static const _settle = Duration(milliseconds: 260);

  /// So the play disc gets out of the way on the way out, rather than hanging
  /// over the hole the poster just flew out of.
  @override
  bool get unlandsOnExit => true;

  bool _playing = false;
  Timer? _arm;

  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    if (old.active == widget.active) return;
    if (widget.active) {
      _schedule();
    } else {
      _arm?.cancel();
      _arm = null;
      // Dropping the surface disposes its controller: a page swiped away
      // stops making sound and stops downloading.
      if (_playing) setState(() => _playing = false);
    }
  }

  @override
  void onRouteLandingChanged() => _schedule();

  @override
  void dispose() {
    _arm?.cancel();
    super.dispose();
  }

  void _schedule() {
    if (!mounted || _playing || !widget.active || !landed) return;
    if (widget.message.mediaStorageId == null) return;
    _arm?.cancel();
    _arm = Timer(_settle, _play);
  }

  void _play() {
    _arm?.cancel();
    _arm = null;
    if (!mounted || _playing || widget.message.mediaStorageId == null) return;
    setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Poster if there is one, film glyph if not. The glyph flies too, so a
    // posterless video still travels rather than snapping into place; the
    // tile it left behind draws the same one.
    final poster = widget.message.posterStorageId;
    final playable = widget.message.mediaStorageId != null;
    final top = ViewerTopBar.extentOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        PhotoDismissArea(
          drag: widget.drag,
          onDismiss: widget.onDismiss,
          // A tap on a resting video means play. Once it plays, the player's
          // own tap (play/pause) is the one that answers.
          onTap: playable && !_playing ? _play : null,
          // A video is not a photograph to examine.
          maxScale: 1,
          child: Padding(
            padding:
                EdgeInsets.only(top: top, bottom: widget.chromeClearance),
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                Center(
                  child: mediaFlight(
                    widget.heroTag,
                    // The film glyph only when there is nothing to play: under
                    // the play disc's scrim it showed through as a second
                    // mark. A playable posterless video flies an empty box.
                    poster != null
                        ? RemoteImage(
                            storageId: poster,
                            api: widget.api,
                            fit: BoxFit.contain,
                            onDark: true,
                          )
                        : playable
                            ? const SizedBox(width: 34, height: 34)
                            : const Icon(
                                CupertinoIcons.film,
                                size: 34,
                                color: Colors.white24,
                              ),
                  ),
                ),
                if (_playing)
                  Center(
                    child: VideoPlayerSurface(
                      api: widget.api,
                      storageId: widget.message.mediaStorageId,
                      posterStorageId: poster,
                    ),
                  )
                else if (playable)
                  // Held back until the picture has arrived. A disc fading in
                  // over a photograph that has come to rest reads as the page
                  // finishing; the same disc riding the flight in reads as a
                  // second thing moving.
                  Center(
                    child: IgnorePointer(
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
                  ),
                if (!_playing) ?_durationBadge(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The clip's length in the bottom-right corner of the PICTURE, where every
  /// grid tile and bubble already puts it, not the screen's corner, which on
  /// a landscape clip is a long way from anything to do with the video.
  ///
  /// Only when the poster's shape is known, because that is what says where
  /// the picture's corner is; and held back until the flight lands, like the
  /// play disc, so it is not a third thing moving.
  Widget? _durationBadge() {
    final ms = widget.message.mediaDurationMs;
    if (ms == null || ms <= 0) return null;
    final aspect = widget.message.mediaAspectRatio ??
        MediaAspectCache.instance.peek(widget.message.posterStorageId ?? '');
    if (aspect == null || !aspect.isFinite || aspect <= 0) return null;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AnimatedOpacity(
                  opacity: landed ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: MediaDurationBadge(
                    duration: Duration(milliseconds: ms),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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

/// The pager's top bar: the shared viewer chrome, with who sent it and when.
///
/// When, not "3 / 8": the filmstrip under the picture already says where in
/// the set this is, and the question a photograph raises that nothing else on
/// screen answers is when it was taken. The position stays for screen
/// readers, which have no filmstrip to glance at.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.message,
    required this.position,
    required this.still,
    required this.onClose,
    required this.onShowInChat,
  });

  final ChatMessage message;
  final String position;
  final bool still;
  final VoidCallback onClose;
  final VoidCallback? onShowInChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ViewerTopBar(
      onClose: onClose,
      still: still,
      closeLabel: l10n.photoChromeCloseSemanticLabel,
      title: message.senderName.isEmpty
          ? l10n.photoChromeMediaYouLabel
          : message.senderName,
      subtitle: viewerWhenLabel(context, message.createdAt),
      subtitleSemanticLabel:
          '${viewerWhenLabel(context, message.createdAt)}, $position',
      actions: [
        if (onShowInChat != null)
          ViewerChromeButton(
            icon: CupertinoIcons.chat_bubble,
            semanticLabel: l10n.photoChromeShowInChatSemanticLabel,
            onTap: onShowInChat,
          ),
      ],
    );
  }
}
