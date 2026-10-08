import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/file_url_cache.dart';
import '../media/native_gallery.dart';
import '../media/native_video_player.dart';
import '../media/video_file_cache.dart';
import '../privacy/capture_protection.dart';
import '../theme/theme_scope.dart';
import '../widgets/remote_image.dart';
import '../widgets/route_landing.dart';
import '../widgets/steady_hero.dart';
import '../widgets/video_message.dart' show VideoPlayerSurface;
import '../widgets/viewer_chrome.dart';

/// Fullscreen player for a single video stored in Convex — the route a tap on
/// a chat video message opens, mirroring [FullscreenImageViewer] for photos.
///
/// Its first move is to get out of the way: it resolves the storage URL and
/// hands it to the OS player (see [NativeVideoPlayer]), then pops itself. What
/// remains here is the fallback for every case that handoff can't serve — web,
/// a platform that declined, a URL that wouldn't resolve — plus the poster
/// backdrop that covers the resolve so a tap has something to land on rather
/// than a frozen transcript.
///
/// Capture protection does NOT send the video back here, though it used to.
/// The reasoning was that iOS has no FLAG_SECURE and the Dart `CaptureShield`
/// cannot cover a UIKit controller presented above the engine — true, but the
/// conclusion was wrong twice over. A user who leaves the protection toggle on
/// never sees the OS player at all, which is most of what this route exists
/// for; and the cache never filled either, because the download lives in
/// `_source` behind a handoff that was being skipped, so every open re-streamed
/// from scratch. The native player now carries its own shield instead, off the
/// same `UIScreen.isCaptured` signal the Dart one uses.
///
/// Opened from a video bubble in the transcript, and from `MediaPagerScreen` —
/// the shared-content gallery keeps its poster on screen and pushes this over
/// it, so a handoff that succeeds pops straight back to the gallery, ready to
/// swipe on. Everything a second call site would otherwise have had to
/// reimplement lives here: the cached-file lookup, the download and its
/// progress ring, the capture shield's translated copy, and the Flutter player
/// that covers web, desktop, and any build where the handoff declines.
///
/// With a [heroTag] the poster flies in from whatever was tapped, the same way
/// a photo does — and then the OS player rises over it. What flies is the
/// poster and never the player: a `VideoPlayer` texture cannot be carried
/// between routes, it arrives as a black rectangle where the picture was. So
/// the route shows the flying still on its way in and swaps to the real thing
/// on touchdown, which is invisible, because the real thing draws that same
/// poster letterboxed into the same box.
///
/// No pinch-zoom on the fallback path — a video has no reason to support one.
/// Swipe down or tap the X to dismiss, the same gesture vocabulary
/// [FullscreenImageViewer] uses.
class FullscreenVideoViewer extends StatefulWidget {
  const FullscreenVideoViewer({
    super.key,
    required this.storageId,
    required this.api,
    this.posterStorageId,
    this.heroTag,
    this.gallery,
  });

  final String storageId;
  final ChatApi api;

  /// The still frame captured on send, shown as an instant backdrop while the
  /// real video resolves and initializes. Null renders black instead.
  final String? posterStorageId;

  /// Tag of the [SteadyHero] around the poster this was opened from. Null
  /// leaves the route's own fade to carry the arrival.
  final Object? heroTag;

  /// The media around this video. With it, the OS player opens as a native
  /// gallery the user can swipe through; without it, on this one video.
  final VideoGallery? gallery;

  static Future<void> open(
    BuildContext context, {
    required String storageId,
    required ChatApi api,
    String? posterStorageId,
    Object? heroTag,
    VideoGallery? gallery,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        // Matches FullscreenImageViewer: a direct response to a tap on the
        // thing that opened it, not an animation playing for its own sake.
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        pageBuilder: (_, _, _) => FullscreenVideoViewer(
          storageId: storageId,
          api: api,
          posterStorageId: posterStorageId,
          heroTag: heroTag,
          gallery: gallery,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<FullscreenVideoViewer> createState() => _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends State<FullscreenVideoViewer>
    with RouteLanding {
  /// Fraction of screen height that commits a drag to a dismiss. Same figure
  /// as [FullscreenImageViewer] — one gesture vocabulary across the app's
  /// fullscreen overlays rather than a subtly different feel per media type.
  static const _dismissFraction = 0.18;

  /// A flick faster than this dismisses regardless of distance.
  static const _dismissVelocity = 700.0;

  /// Live drag offset. A notifier rather than `setState` so a drag repaints
  /// the barrier and chrome without rebuilding the video subtree every frame.
  final ValueNotifier<double> _dragDy = ValueNotifier(0);

  /// Ceiling on the URL resolve before the handoff gives up and lets the
  /// Flutter player take over (which applies its own, longer one). Short
  /// because everything this covers is a single cached Convex lookup, and a
  /// tap that sits on a spinner for ten seconds has already failed the user
  /// whatever eventually comes back.
  static const _resolveTimeout = Duration(seconds: 8);

  /// Download progress, 0…1, or null while there is no figure to show (the
  /// URL resolve, or a response that declared no length). A notifier so the
  /// ring repaints on every chunk without rebuilding the route.
  final ValueNotifier<double?> _progress = ValueNotifier(null);

  bool _dismissing = false;

  /// True once the OS player is off the table and this route has to play the
  /// video itself.
  bool _fallback = false;

  @override
  void initState() {
    super.initState();
    // A fact already known here, so it is settled as initial state rather than
    // behind the async handoff. Routed through `_handoff` it would still be
    // correct, but the route would mount showing a handoff plate for a handoff
    // that was never going to happen — a spinner for one frame in front of a
    // player that could have been rendering already.
    _fallback = !NativeVideoPlayer.supported;
    if (_fallback) {
      // Every route to the Flutter player says so, because from the outside
      // they are one indistinguishable symptom: "the OS player didn't open".
      // Naming which gate closed is the difference between a setting to turn
      // off and a build to redo.
      debugPrint(
        'FullscreenVideoViewer: Flutter player — platform has no OS player',
      );
      return;
    }
    _handoff();
  }

  @override
  void dispose() {
    _dragDy.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Resolve, hand to the OS player, and step aside. Any failure along the
  /// way lands on [_fallback] rather than an error state — the Flutter surface
  /// below re-resolves (off the same caches) and draws the real diagnosis,
  /// including the retry and the "this file is gone" case.
  Future<void> _handoff() async {
    final source = await _source();
    if (!mounted) return;

    // Read after the await, not before: `_handoff` is called from `initState`,
    // where a State may not yet depend on an inherited widget, and
    // `AppLocalizations.of` does exactly that. By here the first await has
    // landed and `mounted` has just been checked, so the lookup is legal.
    //
    // Protection is read this late for a different reason — `_source` can sit
    // on a multi-megabyte download, and the answer that matters is the one at
    // the moment the player appears, not the one from before the wait.
    final l = AppLocalizations.of(context);
    final secure = CaptureProtection.instance.active;

    // The swipeable native gallery, when there is media around this video.
    // Not under capture protection: the protected single player is the one
    // that carries the recording shield, and a protected room's media is
    // better seen one at a time than unshielded.
    final gallery = widget.gallery;
    if (source != null && gallery != null && !secure) {
      final built = await buildNativeGallery(
        gallery: gallery,
        currentStorageId: widget.storageId,
        currentUrl: source,
        api: widget.api,
      );
      if (!mounted) return;
      if (built.pages.length > 1 &&
          await NativeVideoPlayer.presentGallery(
            items: built.pages,
            index: built.index,
            onClosed: (i) {
              if (i >= 0 && i < built.messages.length) {
                gallery.onLanded?.call(built.messages[i]);
              }
            },
            closeLabel: l.photoChromeCloseSemanticLabel,
          )) {
        if (mounted) Navigator.of(context).maybePop();
        gallery.onPresented?.call();
        return;
      }
    }

    if (source != null &&
        await NativeVideoPlayer.present(
          url: source,
          secure: secure,
          shieldTitle: l.countBadgeProtectedLabel,
          shieldBody: l.countBadgeCaptureShieldActiveBody,
        )) {
      // The OS player owns the screen now, and it outlives this route — so
      // closing it returns to the transcript directly instead of to a poster
      // nobody asked for a second look at.
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    if (!mounted) return;
    debugPrint(
      'FullscreenVideoViewer: Flutter player — '
      '${source == null ? "no playable URL resolved" : "the OS player declined to present"}',
    );
    setState(() => _fallback = true);
  }

  /// What to hand the OS player: a `file://` URL for a local copy, the remote
  /// URL when there can't be one, or null when neither is reachable.
  ///
  /// Local wins whenever it is available, and that is the whole point of this
  /// method. Nothing sits in front of `AVPlayer`/`ExoPlayer` caching an HTTP
  /// response, so a streamed video re-downloads in full on every play and
  /// rebuffers on every seek. A cached file starts on the first frame and
  /// scrubs instantly, this time and every time after.
  Future<String?> _source() async {
    Future<String?> remote() => FileUrlCache.instance
        .resolve(widget.storageId, () => widget.api.getFileUrl(widget.storageId))
        .timeout(_resolveTimeout);

    if (!kIsWeb) {
      // Separate from the download below so a hit costs no HTTP client, no
      // progress plumbing, and — because `lookup` never reaches the network —
      // no URL resolve either.
      final hit = await VideoFileCache.instance.lookup(widget.storageId);
      if (hit != null) return Uri.file(hit).toString();

      // A download deliberately outlives a dismissal: backing out mid-fetch
      // and tapping again is the most common thing anyone does here, and
      // abandoning the bytes would make the second tap start over. The size
      // ceiling and the concurrency cap are what keep that bounded.
      try {
        final path = await VideoFileCache.instance.resolve(
          widget.storageId,
          remote,
          onProgress: (received, total) {
            if (!mounted || total == null || total <= 0) return;
            _progress.value = (received / total).clamp(0.0, 1.0);
          },
        );
        return Uri.file(path).toString();
      } on MediaTooLarge {
        // By design: too big to keep, so stream it exactly as before. Not a
        // failure and not worth a log line.
      } catch (e) {
        // A download that failed still leaves streaming as a real option —
        // a truncated write, a full disk, a sandbox that purged the directory
        // mid-fetch. None of those say anything about the network.
        debugPrint('VideoFileCache miss fell through to streaming: $e');
      }
      if (!mounted) return null;
      _progress.value = null;
    }

    try {
      return await remote();
    } catch (e) {
      debugPrint('FullscreenVideoViewer could not resolve a URL: $e');
      return null;
    }
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    _dragDy.value += d.delta.dy;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final dy = _dragDy.value;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final threshold = MediaQuery.sizeOf(context).height * _dismissFraction;
    // Velocity has to agree with the direction of travel, or a fast upward
    // correction at the end of a downward drag would read as a dismiss.
    final flung = velocity.abs() > _dismissVelocity && velocity.sign == dy.sign;
    if (dy != 0 && (flung || dy.abs() > threshold)) {
      _dismissing = true;
      Navigator.of(context).maybePop();
      return;
    }
    _dragDy.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ValueListenableBuilder<double>(
        valueListenable: _dragDy,
        builder: (context, dy, child) {
          final t = (dy.abs() / (screen.height * 0.65)).clamp(0.0, 1.0);
          return Stack(
            children: [
              // Barrier inside the route so it can fade to fully transparent
              // as the drag commits, reading as the video leaving rather than
              // the page cutting away.
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Colors.black.withValues(alpha: 1 - t)),
                ),
              ),
              Transform.translate(offset: Offset(0, dy), child: child),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  // The chrome gets out of the way as the video leaves.
                  opacity: (1 - t * 2).clamp(0.0, 1.0),
                  child: ViewerTopBar(
                    // Fading with the drag, so no blur under the × for it.
                    still: t > 0,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          );
        },
        // Built once and passed through the builder: the player is the
        // expensive part and none of it depends on the drag offset.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          child: Center(child: _body()),
        ),
      ),
    );
  }

  /// The still while the route is arriving, the real thing once it has.
  ///
  /// [SteadyHero] rather than [Hero]: a plain one tears its child out of the
  /// tree at both ends of a flight, so the picture arrives as a hole and fills
  /// in a frame later. The swap on touchdown moves nothing — both this poster
  /// and the plate's are the same file drawn [BoxFit.contain] into the same
  /// screen, so they land on the same rectangle.
  ///
  /// The resolve does not wait for any of this: [_handoff] starts in
  /// `initState`, so the download is already in flight while the picture is.
  Widget _body() {
    final tag = widget.heroTag;
    if (tag != null && !landed) {
      final poster = widget.posterStorageId;
      return SteadyHero(
        tag: tag,
        child: poster == null
            ? const SizedBox.expand()
            : RemoteImage(
                storageId: poster,
                onDark: true,
                api: widget.api,
                fit: BoxFit.contain,
              ),
      );
    }
    return _fallback
        ? VideoPlayerSurface(
            api: widget.api,
            storageId: widget.storageId,
            posterStorageId: widget.posterStorageId,
          )
        : _HandoffPlate(
            api: widget.api,
            posterStorageId: widget.posterStorageId,
            progress: _progress,
          );
  }
}

/// What the tap lands on between opening this route and the OS player covering
/// it: the poster full-bleed and dimmed, with a progress ring over it.
/// Deliberately identical in geometry to [VideoPlayerSurface]'s own loading
/// state, so a handoff that falls back doesn't visibly change its mind — and
/// full-bleed for the reason spelled out there, that a poster boxed at a
/// guessed ratio is a stamp floating in the middle of a black screen.
class _HandoffPlate extends StatelessWidget {
  const _HandoffPlate({
    required this.api,
    required this.posterStorageId,
    required this.progress,
  });

  final ChatApi api;
  final String? posterStorageId;

  /// 0…1 once the download reports a total, null before that. A determinate
  /// ring rather than an endless one wherever the figure exists: this wait is
  /// a download of a known size, and saying so is the difference between "it's
  /// working" and "it's stuck".
  final ValueListenable<double?> progress;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final poster = posterStorageId;
    return Stack(
      fit: StackFit.expand,
      children: [
        poster == null
            ? const ColoredBox(color: Colors.black)
            : ColoredBox(
                color: Colors.black,
                child: RemoteImage(
                  storageId: poster,
                  onDark: true,
                  api: api,
                  fit: BoxFit.contain,
                ),
              ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
        // Centred inside the expanded child, not laid out as one: under
        // `StackFit.expand` a bare SizedBox gets tight stack-sized
        // constraints and the ring inflates to fill the screen.
        Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: ValueListenableBuilder<double?>(
              valueListenable: progress,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 2.5,
                color: theme.accent,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
