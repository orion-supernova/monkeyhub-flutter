import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/app_shortcuts.dart';
import '../keyboard/focusable_tap.dart';
import '../keyboard/viewer_keys.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/media_aspect_cache.dart';
import '../media/native_gallery.dart';
import '../media/storage/media_ledger.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/room_content_item.dart' show RoomContentPage;
import '../platform.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/forward_target_sheet.dart';
import '../widgets/media_filmstrip.dart';
import '../widgets/media_grid_tile.dart' show roomMediaHeroTag;
import '../widgets/photo_chrome.dart' show MediaDurationBadge, MediaPlayDisc;
import '../widgets/photo_dismiss_area.dart';
import '../widgets/dust/spoiler_dust.dart';
import '../widgets/media_spoiler.dart';
import '../widgets/remote_image.dart';
import '../widgets/route_landing.dart';
import '../widgets/spring_press.dart';
import '../widgets/steady_hero.dart';
import 'fullscreen_video_viewer.dart';
import 'room_content_actions.dart';
import 'viewer_disk.dart';
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

  /// Save to the photo library. False when it did not save. On a desk and
  /// on the web its presence only says "this set may be saved": the pager
  /// writes to Downloads there, see [ViewerDisk].
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
      // The phone's save, into the photo library. On a desk and on the web
      // the pager saves to Downloads itself instead (see [ViewerDisk]), so
      // `gal`, which has no web implementation, is never reached there.
      onSave: (m) async =>
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
    this.actions,
    this.fileAsSeen = true,
    this.loadOlder,
    this.newestFirst = false,
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

  /// Fetches the media older than the oldest item the pager holds, OLDEST
  /// FIRST, and whether anything older still exists.
  ///
  /// [items] is a snapshot of whatever the opener had loaded — the
  /// transcript's live window, the grid's pages so far — and a reader swiping
  /// back through a long conversation used to run off the end of it a few
  /// dozen photographs in, with years of pictures still behind them. Asked
  /// when the reader is within [_MediaPagerScreenState._olderLead] pages of
  /// the oldest item, one request at a time, until it says there is no more.
  /// Null means the set is complete as handed in.
  final Future<RoomContentPage> Function(ChatMessage oldest)? loadOlder;

  /// Whether [items] runs newest to oldest (the shared-content grid's order)
  /// rather than oldest to newest (the transcript's). Decides which end older
  /// media from [loadOlder] joins: appended past the end, or slid in before
  /// the start without moving the page on screen.
  final bool newestFirst;

  /// Returns the message the pager was left on, so the opener can put that
  /// tile back under the reader's eyes. Null if it was dismissed without
  /// settling.
  ///
  /// Swiping four photos deep and closing should not land you looking at the
  /// one you opened — and the hero has nowhere to fly home to if the tile it
  /// belongs to has been scrolled out of the grid's build range. A message
  /// rather than an index, because the set grows while it is open: a picture
  /// fetched by [loadOlder] has no index in the list the opener handed in.
  static Future<ChatMessage?> open(
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
    Future<RoomContentPage> Function(ChatMessage oldest)? loadOlder,
    bool newestFirst = false,
  }) {
    return Navigator.of(context, rootNavigator: true).push<ChatMessage>(
      PageRouteBuilder<ChatMessage>(
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
          loadOlder: loadOlder,
          newestFirst: newestFirst,
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

  /// The native gallery a video page opened. It swipes through this same
  /// set, so it REPLACES this pager rather than stacking on it: once it is on
  /// screen the pager closes, unseen beneath it, and closing the OS player is
  /// one close back to the grid or the chat, not two. Where the user ends up
  /// still reaches the screen underneath, through [onPageChanged], the same
  /// way swiping here does.
  VideoGallery _nativeGallery() => VideoGallery(
        items: _items,
        onPresented: _stepAside,
        onLanded: widget.onPageChanged,
      );

  /// Removes THIS pager's route, wherever it sits in the stack.
  ///
  /// Not [_close]: that pops, and a pop takes whatever route is on top. The
  /// video viewer that opened the native gallery is popping itself in the
  /// same moment, so a pop here could take the viewer a second time and
  /// leave the pager standing, which was the "close twice" bug. Removed by
  /// identity, the order cannot matter. Unanimated, because the OS player
  /// covers it.
  void _stepAside() {
    if (!mounted || _closing) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    _closing = true;
    Navigator.of(context).removeRoute(route);
  }

  /// The set as it stands now. A copy of [MediaPagerScreen.items] that
  /// shrinks when Delete takes the picture out from under the reader (the
  /// gallery carries on with its neighbour, as Photos does) and grows at its
  /// oldest end as [MediaPagerScreen.loadOlder] brings in more.
  late final List<ChatMessage> _items = [...widget.items];

  // ── Older media ──

  /// How close to the oldest item, in pages, the reader gets before the next
  /// batch is asked for. Far enough ahead that a page of thirty normally
  /// lands before they reach the end; near enough that opening on today's
  /// photo does not fetch last year's.
  static const _olderLead = 3;

  /// A [MediaPagerScreen.loadOlder] request is out. One at a time: every
  /// page change near the edge asks, and two requests from the same cursor
  /// would fetch the same batch twice.
  bool _loadingOlder = false;

  /// The loader said there is nothing older. Never asked again.
  bool _olderExhausted = false;

  /// A batch that arrived while the pages were moving, held until they come
  /// to rest. See [_applyOlder].
  List<ChatMessage>? _pendingOlder;

  /// Pages between the current one and the oldest item.
  int get _fromOldest =>
      widget.newestFirst ? _items.length - 1 - _index : _index;

  /// Asks for the next batch of older media if the reader is near enough to
  /// the oldest end, nothing is in flight and the loader has more to give.
  void _maybeLoadOlder() {
    final load = widget.loadOlder;
    if (load == null || _loadingOlder || _olderExhausted || _closing) return;
    if (_items.isEmpty || _pendingOlder != null) return;
    if (_fromOldest > _olderLead) return;
    _loadingOlder = true;
    final oldest = widget.newestFirst ? _items.last : _items.first;
    load(oldest).then((page) {
      if (!mounted) return;
      _loadingOlder = false;
      if (!page.hasMore) _olderExhausted = true;
      // By id, not by trusting the cursor: two messages can share a
      // millisecond, and the transcript and the index can both hold one.
      final known = {for (final m in _items) m.id};
      final fresh = [
        for (final m in page.items)
          if (known.add(m.id)) m,
      ];
      // Nothing new and not exhausted (a failed or empty page): no retry
      // here, or a bad network would spin. The next page change asks again.
      if (fresh.isEmpty) return;
      _pendingOlder = fresh;
      _applyOlder();
    }, onError: (Object e) {
      debugPrint('media pager: older media failed: $e');
      if (mounted) _loadingOlder = false;
    });
  }

  /// Puts the held batch into the set without moving the picture on screen.
  ///
  /// Appended, for a newest-first set, that is all there is to it. Slid in
  /// before the start of an oldest-first one, every page index shifts by the
  /// batch's length, so the current index and the scroll offset are moved by
  /// exactly that much in the same frame — the reader sees the same
  /// photograph, now with more of them behind it.
  ///
  /// Only at rest. A settling swipe or an arrow-key step is a simulation
  /// aimed at an absolute offset, and correcting the offset under it would
  /// carry the reader to the wrong page; the batch waits for the scroll to
  /// end (see the [ScrollEndNotification] listener in [build]).
  void _applyOlder() {
    final fresh = _pendingOlder;
    if (fresh == null || !mounted || _closing) return;
    if (!widget.newestFirst) {
      if (!_pager.hasClients) {
        // Not laid out yet: the controller would attach on the old index.
        WidgetsBinding.instance.addPostFrameCallback((_) => _applyOlder());
        return;
      }
      if (_pager.position.isScrollingNotifier.value) return;
    }
    _pendingOlder = null;
    if (widget.newestFirst) {
      setState(() => _items.addAll(fresh.reversed));
    } else {
      setState(() {
        _items.insertAll(0, fresh);
        _index += fresh.length;
      });
      // `correctPixels`, not `jumpToPage`: the jump runs before the new
      // pages are laid out, lands past the old end, and springs back. The
      // correction is read by the layout this setState schedules.
      final p = _pager.position;
      p.correctPixels(p.pixels + fresh.length * p.viewportDimension);
    }
    // A small batch can leave the reader still near the edge.
    _maybeLoadOlder();
  }

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

  // ── Desktop and web ──

  /// A desk's gallery: chrome that stays while zoomed and leaves on its own
  /// when the mouse is still, a click outside the picture to close, the
  /// wheel and the edge chevrons to page, ⌘= ⌘− ⌘0 to zoom.
  final bool _desktop = isWebOrDesktop;

  /// Hands ⌘= ⌘− ⌘0 to the page on screen.
  final PhotoZoomController _zoom = PhotoZoomController();

  /// A mouse has moved over the gallery since the last touch. The chevrons
  /// and the idle fade are a mouse's furniture; a touchscreen laptop, or a
  /// phone's browser, never sees them.
  bool _mouse = false;

  /// The mouse has been still for [_idleAfter]: the chrome and the pointer
  /// get out of the picture's way, as in Photos and QuickTime.
  bool _idle = false;
  Timer? _idleTimer;
  static const _idleAfter = Duration(milliseconds: 2500);

  /// The pointer is over a piece of chrome, which never fades out from under
  /// a hand reaching for a button.
  bool _overChrome = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pager = PageController(initialPage: _index);
    // Opened on one of the oldest few: ask now rather than on the first swipe.
    _maybeLoadOlder();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _pager.dispose();
    _drag.dispose();
    super.dispose();
  }

  /// Pops with the message the reader settled on. Guarded because a committed
  /// dismiss drag and a tap on the close button can land in the same frame.
  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(_items.isEmpty ? null : _items[_index]);
  }

  Object _heroTag(ChatMessage m) =>
      widget.heroTagFor?.call(m) ?? roomMediaHeroTag(m.id);

  /// An arrow key: one photograph along, animated like a swipe would be.
  /// Ignored while zoomed, where a swipe is ignored too.
  void _step(int by) {
    if (_zoomed || _closing) return;
    final to = _index + by;
    if (to < 0 || to >= _items.length) return;
    _pager.animateToPage(
      to,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// The mouse moved: chrome and pointer back, and the idle clock restarts.
  /// A setState only when something visible changes, not per hover event.
  void _wake() {
    if (!_mouse || _idle) {
      setState(() {
        _mouse = true;
        _idle = false;
      });
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleAfter, () {
      if (!mounted || _overChrome || _closing) return;
      setState(() => _idle = true);
    });
  }

  void _onHover(PointerEvent e) {
    if (e.kind == PointerDeviceKind.mouse) _wake();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.mouse) {
      _wake();
    } else if (_mouse) {
      // Touch: the mouse's furniture goes until the mouse comes back.
      _idleTimer?.cancel();
      setState(() {
        _mouse = false;
        _idle = false;
      });
    }
  }

  void _setOverChrome(bool over) {
    _overChrome = over;
    if (!over && _mouse) _wake();
  }

  void _playCurrent() {
    final m = _items[_index];
    final id = m.mediaStorageId;
    if (id == null || !_isMovie(m)) return;
    FullscreenVideoViewer.open(
      context,
      storageId: id,
      api: widget.api,
      posterStorageId: m.posterStorageId,
      gallery: _nativeGallery(),
    );
  }

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

  /// A desk's Save: into Downloads, saying where, with the way to it.
  Future<void> _saveToDisk(ChatMessage m) => _run(() async {
        final l10n = AppLocalizations.of(context);
        final toast = AppToast.of(context);
        final saved = await ViewerDisk.save(api: widget.api, m: m);
        if (saved == null) {
          toast.show(l10n.photoChromeSaveFailed, tone: ToastTone.danger);
          return;
        }
        final path = saved.path;
        if (path == null) {
          toast.show(l10n.viewerDownloaded, tone: ToastTone.success);
          return;
        }
        final mac = defaultTargetPlatform == TargetPlatform.macOS;
        toast.show(
          l10n.viewerSavedToDownloads,
          tone: ToastTone.success,
          actionLabel: ViewerDisk.canReveal
              ? (mac ? l10n.viewerShowInFinder : l10n.viewerShowInFolder)
              : null,
          onAction: ViewerDisk.canReveal ? () => ViewerDisk.reveal(path) : null,
        );
      });

  Future<void> _copy(ChatMessage m) => _run(() async {
        final l10n = AppLocalizations.of(context);
        final toast = AppToast.of(context);
        final ok = await ViewerDisk.copyImage(api: widget.api, m: m);
        toast.show(
          ok ? l10n.viewerCopied : l10n.viewerCopyFailed,
          tone: ok ? ToastTone.success : ToastTone.danger,
        );
      });

  /// Save is offered for this picture, wherever it would go.
  bool _canSave(ChatMessage m) =>
      widget.actions?.onSave != null && m.mediaStorageId != null;

  bool _canCopy(ChatMessage m) =>
      _desktop &&
      widget.actions != null &&
      ViewerDisk.canCopyImage &&
      m.type == MessageType.image &&
      m.mediaStorageId != null;

  /// The keys this page answers right now: only what it can do.
  Map<ShortcutDef, VoidCallback> _bindings(ChatMessage m) {
    final photo = !_isMovie(m) && m.mediaStorageId != null;
    return {
      if (photo) AppShortcuts.zoomIn: _zoom.zoomIn,
      if (photo) AppShortcuts.zoomOut: _zoom.zoomOut,
      if (photo) AppShortcuts.zoomFit: _zoom.fit,
      if (_isMovie(m) && m.mediaStorageId != null)
        AppShortcuts.playPause: _playCurrent,
      if (_canCopy(m)) AppShortcuts.copyMedia: () => _copy(m),
      if (_desktop && _canSave(m)) AppShortcuts.saveMedia: () => _saveToDisk(m),
    };
  }

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
      // On a desk Save sits top right with Copy, by its shortcut.
      if (a.onSave != null && hasFile && !_desktop)
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
    // A wide desk window keeps its filmstrip: there is room for it under the
    // picture, and it is how a mouse finds the photo three along.
    final wide = _desktop && screen.width >= 700;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Left and right as the reader sees them, like the arrow keys.
    final canBack = _index > 0;
    final canOn = _index < _items.length - 1;

    Widget gallery = ViewerKeys(
      onClose: _close,
      onPrevious: () => _step(-1),
      onNext: () => _step(1),
      child: Material(
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
              final away = (1 - t * 2).clamp(0.0, 1.0);
              final chromeOpacity = _chrome && !_idle ? away : 0.0;
              // The chevrons are a mouse's, and step aside while zoomed,
              // where paging is locked for a drag inside the photograph.
              final chevrons = _desktop && _mouse && !_zoomed && strip
                  ? chromeOpacity
                  : 0.0;

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
                    onHover: _desktop ? _setOverChrome : null,
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
                      onCopy: _canCopy(current) ? () => _copy(current) : null,
                      onSave: _desktop && _canSave(current)
                          ? () => _saveToDisk(current)
                          : null,
                    ),
                  ),
                  if (strip || tools.isNotEmpty)
                    _FadingChrome(
                      opacity: wide ? away : chromeOpacity,
                      alignBottom: true,
                      onHover: _desktop ? _setOverChrome : null,
                      builder: (_) => _BottomChrome(
                        items: _items,
                        index: _index,
                        api: widget.api,
                        strip: strip,
                        tools: tools,
                        onTap: _jumpTo,
                      ),
                    ),
                  if (_desktop && strip) ...[
                    ViewerEdgeChevron(
                      start: true,
                      visible: chevrons > 0 && (rtl ? canOn : canBack),
                      opacity: chevrons,
                      tooltip: viewerShortcutTip(
                        rtl ? l10n.kbdViewerNext : l10n.kbdViewerPrevious,
                        rtl ? AppShortcuts.viewerNext : AppShortcuts.viewerPrevious,
                      ),
                      onTap: () => _step(rtl ? 1 : -1),
                      onHover: _setOverChrome,
                    ),
                    ViewerEdgeChevron(
                      start: false,
                      visible: chevrons > 0 && (rtl ? canBack : canOn),
                      opacity: chevrons,
                      tooltip: viewerShortcutTip(
                        rtl ? l10n.kbdViewerPrevious : l10n.kbdViewerNext,
                        rtl ? AppShortcuts.viewerPrevious : AppShortcuts.viewerNext,
                      ),
                      onTap: () => _step(rtl ? -1 : 1),
                      onHover: _setOverChrome,
                    ),
                  ],
                ],
              );
            },
            // Built once and passed through the builder: the pages are the
            // expensive part and none of them depend on the drag offset.
            child: NotificationListener<ScrollEndNotification>(
              // A batch of older media that arrived mid-swipe goes in once the
              // pages are still. A microtask, because the position reports
              // itself idle only after this notification has been sent.
              onNotification: (n) {
                if (n.depth == 0 && _pendingOlder != null) {
                  scheduleMicrotask(_applyOlder);
                }
                return false;
              },
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
                    // Belt and braces. A zoomed page cannot be swiped away, so this
                    // should already be false — but a stuck `true` would leave the
                    // gallery unswipeable with nothing on screen to explain why.
                    _zoomed = false;
                  });
                  widget.onPageChanged?.call(_items[i]);
                  _maybeLoadOlder();
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
                      gallery: _nativeGallery(),
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
                      chromeClearance: _chrome || wide
                          ? _bottomChromeHeight(context)
                          : 0,
                      onDismiss: _close,
                      onToggleChrome: () => setState(() => _chrome = !_chrome),
                      // Only the page on screen takes ⌘= and friends.
                      zoom: i == _index ? _zoom : null,
                      onBackdropClick: _desktop ? _close : null,
                      onWheelStep: _desktop ? _step : null,
                      cursorHidden: _desktop && _idle,
                      onZoomChanged: (z) {
                        if (i == _index && z != _zoomed) {
                          setState(() {
                            _zoomed = z;
                            // Like Photos: zooming in gives the picture the
                            // whole screen. A tap brings the chrome back. Not
                            // on a desk, where the chrome is how a mouse gets
                            // back out, and leaves on its own when still.
                            if (z && !_desktop) _chrome = false;
                          });
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    if (!_desktop) return gallery;
    gallery = ShortcutBindings(bindings: _bindings(current), child: gallery);
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerHover: _onHover,
      onPointerMove: _onHover,
      child: MouseRegion(
        // The pointer leaves with the chrome. Inner regions that set their
        // own cursor (a zoomed photo's hand) are told too: theirs would win.
        cursor: _idle ? SystemMouseCursors.none : MouseCursor.defer,
        child: gallery,
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
    this.onHover,
  });

  final double opacity;
  final Widget Function(bool still) builder;
  final bool alignBottom;

  /// The mouse came onto (true) or left (false) this chrome. The gallery
  /// keeps its chrome up while a hand is on it.
  final ValueChanged<bool>? onHover;

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
          child: widget.onHover == null
              ? widget.builder(_fading || opacity < 1)
              : MouseRegion(
                  opaque: false,
                  onEnter: (_) => widget.onHover!(true),
                  onExit: (_) => widget.onHover!(false),
                  child: widget.builder(_fading || opacity < 1),
                ),
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
    final picture = RemoteImage(
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
    // A spoiler must not show its face in the rail while the page above it is
    // still under dust. Same key as the page, so the two open and close
    // together.
    final thumb = message.mediaSpoiler
        ? MediaSpoilerCover(
            interactive: false,
            sigma: 6,
            dustDensity: SpoilerDust.defaultDensity / 3,
            revealKey: message.id,
            child: picture,
          )
        : picture;
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
    this.gallery,
    this.chromeClearance = 0,
    this.zoom,
    this.onBackdropClick,
    this.onWheelStep,
    this.cursorHidden = false,
  });

  final ChatMessage message;
  final ChatApi api;
  final Object heroTag;

  /// Desktop and web: see the parameters of the same names on
  /// [PhotoDismissArea].
  final PhotoZoomController? zoom;
  final VoidCallback? onBackdropClick;
  final ValueChanged<int>? onWheelStep;
  final bool cursorHidden;

  /// The pager's whole set, for a video page's OS player to swipe through.
  final VideoGallery? gallery;

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
        gallery: gallery,
        heroTag: heroTag,
        drag: drag,
        onDismiss: onDismiss,
        chromeClearance: chromeClearance,
        onBackdropClick: onBackdropClick,
        onWheelStep: onWheelStep,
        cursorHidden: cursorHidden,
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
          zoom: zoom,
          onBackdropClick: onBackdropClick,
          onWheelStep: onWheelStep,
          cursorHidden: cursorHidden,
          pixelSize: () => ViewerDisk.pixelSize(message),
          child: mediaFlight(
            heroTag,
            _shaped(
              _spoilered(
                PhotoSharpOnZoom(
                  // The same file at a bigger decode, from the disk copy the
                  // screen-sized one was decoded from. Quiet: while it decodes
                  // the picture underneath simply stays.
                  sharp: (w) => RemoteImage(
                    storageId: id,
                    api: api,
                    fit: BoxFit.contain,
                    borderRadius: BorderRadius.zero,
                    decodeWidth: w,
                    onDark: true,
                    quiet: true,
                  ),
                  child: image,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// [child] under the chat's own spoiler cover when the sender sent it as
  /// one. Keyed by the message id, so it shares [SpoilerStore] with the bubble
  /// and the shared-media tile: open in one is open in all, and when the dust
  /// closes back over it, it closes here too.
  Widget _spoilered(Widget child) => message.mediaSpoiler
      ? MediaSpoilerCover(revealKey: message.id, child: child)
      : child;

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
    this.gallery,
    required this.heroTag,
    required this.drag,
    required this.onDismiss,
    this.chromeClearance = 0,
    this.onBackdropClick,
    this.onWheelStep,
    this.cursorHidden = false,
  });

  final VoidCallback? onBackdropClick;
  final ValueChanged<int>? onWheelStep;
  final bool cursorHidden;

  /// The bottom band the filmstrip and toolbar sit in. The duration badge
  /// stays above it: under the chrome's scrim it was a grey smudge.
  final double chromeClearance;

  final ChatMessage message;
  final ChatApi api;

  /// The pager's set, handed to the OS player so it swipes on through it.
  final VideoGallery? gallery;
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
      gallery: widget.gallery,
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
          // Black void around a photo that doesn't fill the screen, like
          // Photos — the blurred copy of the picture read as a smudge.
          const ColoredBox(color: Colors.black),
        PhotoDismissArea(
          drag: widget.drag,
          onDismiss: widget.onDismiss,
          // A tap on a video means play, not "hide the chrome". The disc below
          // is the same action with a smaller target and a focus ring on it.
          onTap: playable ? _play : null,
          onBackdropClick: widget.onBackdropClick,
          onWheelStep: widget.onWheelStep,
          cursorHidden: widget.cursorHidden,
          // A poster is not a photograph to examine: zooming one would enlarge
          // a still of something the OS player is one tap away from showing
          // properly.
          maxScale: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              mediaFlight(
                widget.heroTag,
                // The film glyph only when there is nothing to play: under the
                // play disc's scrim it showed through as a second mark. A
                // playable posterless video flies an empty box — the disc
                // below is the whole picture.
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
        ?_durationBadge(),
      ],
    );
  }

  /// The clip's length in the bottom-right corner of the PICTURE, where every
  /// grid tile and bubble already puts it — not the screen's corner, which on
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
        child: LayoutBuilder(
          builder: (context, box) {
            var w = box.maxWidth;
            var h = w / aspect;
            if (h > box.maxHeight) {
              h = box.maxHeight;
              w = h * aspect;
            }
            // Lifted clear of the chrome when the picture runs down into it.
            final pictureBottom = (box.maxHeight + h) / 2;
            final lift = (pictureBottom - (box.maxHeight - widget.chromeClearance))
                .clamp(0.0, h / 2);
            return Center(
              child: SizedBox(
                width: w,
                height: h,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, 10, 10, 10 + lift),
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
            );
          },
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
    this.onCopy,
    this.onSave,
  });

  final ChatMessage message;
  final String position;
  final bool still;
  final VoidCallback onClose;
  final VoidCallback? onShowInChat;

  /// A desk's Copy and Save, top right beside Show in chat, where a Mac app
  /// keeps a window's actions and where the hover hint can name their keys.
  final VoidCallback? onCopy;
  final VoidCallback? onSave;

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
        if (onCopy != null)
          ViewerChromeButton(
            icon: CupertinoIcons.doc_on_doc,
            semanticLabel: l10n.kbdCopyMedia,
            tooltip: viewerShortcutTip(l10n.kbdCopyMedia, AppShortcuts.copyMedia),
            onTap: onCopy,
          ),
        if (onSave != null)
          ViewerChromeButton(
            icon: CupertinoIcons.arrow_down_to_line,
            semanticLabel: l10n.roomContentScreenSaveAction,
            tooltip: viewerShortcutTip(
              l10n.roomContentScreenSaveAction,
              AppShortcuts.saveMedia,
            ),
            onTap: onSave,
          ),
        if (onShowInChat != null)
          ViewerChromeButton(
            icon: CupertinoIcons.chat_bubble,
            semanticLabel: l10n.photoChromeShowInChatSemanticLabel,
            tooltip: isWebOrDesktop
                ? l10n.photoChromeShowInChatSemanticLabel
                : null,
            onTap: onShowInChat,
          ),
      ],
    );
  }
}
