import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';

import '../../backend/chat_api.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/file_url_cache.dart';
import '../../media/storage/data_usage_store.dart';
import '../../media/storage/media_image_cache.dart';
import '../../models/enums.dart';
import '../../models/expression_item.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';

/// Whether GIFs and animated stickers should move in this build.
///
/// Two switches, both of which win: the app's own "autoplay GIFs & stickers"
/// setting, and the resolved motion budget ([MotionScope] — the OS reduce-motion
/// flag unless the user overrode it in the app). A reader who asked for calm
/// gets stills everywhere and can still tap one to play it.
bool expressionsAutoplay(BuildContext context) =>
    SettingsStore.instance.autoplayExpressions &&
    !MotionScope.of(context).calm;

/// A small square picture of a GIF or sticker, for surfaces that quote one — a
/// reply tether, the composer's reply card. Null for any other type, or when
/// the quote carries nothing to draw.
///
/// Always still: a thumbnail the size of a word has no business moving.
Widget? expressionThumbnail({
  required MessageType type,
  required String? url,
  required String? stickerStorageId,
  required StickerFormat? stickerFormat,
  required String? alt,
  required ChatApi api,
  required double size,
}) {
  if (type == MessageType.gif && url != null) {
    return KlipyImage(url: url, width: size, height: size, radius: 4, play: false);
  }
  if (type == MessageType.sticker && (stickerStorageId != null || url != null)) {
    final isPack = stickerStorageId != null;
    return StickerArt(
      item: ExpressionItem(
        kind: ExpressionKind.sticker,
        source: isPack ? ExpressionSource.pack : ExpressionSource.klipy,
        storageId: stickerStorageId,
        url: url,
        format: stickerFormat ?? StickerFormat.image,
        title: alt,
      ),
      size: size,
      api: api,
      play: false,
    );
  }
  return null;
}

/// Puts a search field's keyboard away without clearing the search — shown at
/// the end of the field while it has the keyboard.
///
/// iOS's keyboard has no dismiss key, and a search keyboard over a half-height
/// panel leaves room for barely a row of results; this and scrolling the
/// results are the two ways out. The panel opens up when the keyboard goes
/// (see `ExpressionPanelController.setSearching`).
class HideKeyboardButton extends StatelessWidget {
  const HideKeyboardButton({super.key, required this.focus});

  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = AppLocalizations.of(context).expressionHideKeyboard;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focus.unfocus,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: Icon(CupertinoIcons.keyboard_chevron_compact_down,
              size: 18, color: theme.inkMuted),
        ),
      ),
    );
  }
}

/// A translucent placeholder the size of the tile it stands in for.
///
/// Deliberately static. A picker grid shows two dozen of these at once, and a
/// shimmer controller per tile is two dozen tickers for a state that lasts a
/// few hundred milliseconds; the grid-level skeleton (see the panel) is the
/// one that sweeps.
class ExpressionPlaceholder extends StatelessWidget {
  const ExpressionPlaceholder({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.blurPreview,
  });

  final double? width;
  final double? height;
  final double radius;

  /// KLIPY's inline base64 JPEG — a blurry version of the real frame, which is
  /// a far better stand-in than a grey box.
  final String? blurPreview;

  static Uint8List? _decode(String? dataUri) {
    if (dataUri == null) return null;
    final comma = dataUri.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64Decode(dataUri.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final bytes = _decode(blurPreview);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            : ColoredBox(color: theme.inkMuted.withValues(alpha: 0.12)),
      ),
    );
  }
}

/// The on-device cache for KLIPY media, kept apart from our own files.
///
/// KLIPY's "do not store, mirror or retain copies" rule is about partners
/// re-serving its media from their own servers — a device cache is what its
/// own reference apps do (Coil on Android, SDWebImage on iOS, both caching to
/// disk by default), and its CDN sends `cache-control: public, max-age=86400`
/// with an ETag precisely so clients will. What this store adds over the
/// default one is honesty about freshness: entries are revalidated against the
/// ETag once the CDN's max-age lapses, and dropped after [_stale] whatever
/// happens, so an item KLIPY takes down stops appearing within days rather
/// than living on a phone for a month.
class KlipyCacheManager extends CacheManager {
  KlipyCacheManager._()
      : super(Config(
          'klipyMedia',
          // SDWebImage's default disk age, which is what KLIPY's iOS demo ships.
          stalePeriod: _stale,
          maxNrOfCacheObjects: 400,
          // Counted as stickers in Data Usage.
          fileService: CountingFileService(kindFor: (_) => UsageKind.stickers),
        ));
  static final KlipyCacheManager instance = KlipyCacheManager._();
  static const _stale = Duration(days: 7);
}

/// A picture served by KLIPY, animated when [play] is true.
///
/// Loaded straight from the URL the API returned, byte for byte — no rewriting
/// and no proxy, as KLIPY's terms require — through [KlipyCacheManager].
///
/// Paused rather than hidden when [play] is false: [TickerMode] freezes an
/// animated image on its current frame (see `Image`'s own docs), so nothing
/// re-downloads when playback resumes.
class KlipyImage extends StatelessWidget {
  const KlipyImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.play = true,
    this.radius = 12,
    this.blurPreview,
    this.semanticLabel,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool play;
  final double radius;
  final String? blurPreview;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = width;
    // Decoded at the painted size. An animated WebP decodes EVERY frame at the
    // requested size, so an unresized 640px GIF in a 110px grid tile costs
    // thirty times the memory it needs, per frame.
    final cacheWidth = w == null || !w.isFinite ? null : (w * dpr).round();
    final placeholder = ExpressionPlaceholder(
      width: width,
      height: height,
      radius: radius,
      blurPreview: blurPreview,
    );
    final image = Image(
      image: ResizeImage.resizeIfNeeded(
        cacheWidth,
        null,
        CachedNetworkImageProvider(url,
            cacheManager: KlipyCacheManager.instance),
      ),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      frameBuilder: (context, child, frame, sync) =>
          frame == null && !sync ? placeholder : child,
      errorBuilder: (context, _, _) => placeholder,
    );
    return TickerMode(
      enabled: play,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image,
      ),
    );
  }
}

/// Loads and caches Lottie compositions for sticker files in our storage.
///
/// Two layers, the same split `RemoteImage` makes: the file on disk through
/// [MediaImageCache] (our own files, apart from KLIPY's store), and the
/// parsed composition in memory, because parsing a Lottie
/// document is the expensive part and a picker scrolls past the same sticker
/// many times.
class LottieCache {
  LottieCache._();
  static final LottieCache instance = LottieCache._();

  final Map<String, Future<LottieComposition?>> _inFlight = {};
  final Map<String, LottieComposition> _ready = {};

  /// Compositions kept parsed. A pack is ~30; this holds a few packs' worth.
  static const _maxReady = 160;

  LottieComposition? peek(String key) => _ready[key];

  Future<LottieComposition?> load(String key, Future<String?> Function() url) {
    final ready = _ready[key];
    if (ready != null) return SynchronousFuture(ready);
    return _inFlight[key] ??= _fetch(key, url).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<LottieComposition?> _fetch(
      String key, Future<String?> Function() urlFn) async {
    try {
      final url = await urlFn();
      if (url == null) return null;
      final Uint8List bytes;
      if (kIsWeb) {
        // No file system to cache into; the browser's HTTP cache does the job.
        final res = await http.get(Uri.parse(url));
        if (res.statusCode != 200) return null;
        bytes = res.bodyBytes;
      } else {
        MediaImageCache.bind(url, key);
        final file =
            await MediaImageCache.manager.getSingleFile(url, key: key);
        bytes = await file.readAsBytes();
      }
      final comp = await LottieComposition.fromBytes(bytes);
      if (_ready.length >= _maxReady) _ready.remove(_ready.keys.first);
      _ready[key] = comp;
      return comp;
    } catch (e) {
      debugPrint('[lottie] $key failed: $e');
      return null;
    }
  }
}

/// A sticker, drawn bare — no tile, no background.
///
/// Lottie stickers play through [Lottie]; image stickers are KLIPY's (loaded
/// by [KlipyImage] through its own cache) or ours from storage (through
/// `CachedNetworkImage`, which may keep them). When the art cannot be loaded
/// the emoji it stands for is drawn instead, large — a sticker that fails
/// still says what it said.
class StickerArt extends StatefulWidget {
  const StickerArt({
    super.key,
    required this.item,
    required this.size,
    this.api,
    this.url,
    this.play = true,
  });

  final ExpressionItem item;
  final double size;

  /// For resolving a pack sticker's storage id to a URL when [url] is not
  /// already known. Null in pickers, which always have the URL.
  final ChatApi? api;

  /// A pack sticker's serving URL, when the caller already has it.
  final String? url;
  final bool play;

  @override
  State<StickerArt> createState() => _StickerArtState();
}

class _StickerArtState extends State<StickerArt>
    with SingleTickerProviderStateMixin {
  LottieComposition? _comp;
  String? _imageUrl;
  bool _failed = false;
  late final AnimationController _ctrl = AnimationController(vsync: this);

  String get _key => widget.item.storageId ?? widget.item.url ?? '';

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(StickerArt old) {
    super.didUpdateWidget(old);
    if (!old.item.sameAs(widget.item) || old.url != widget.url) {
      _comp = null;
      _imageUrl = null;
      _failed = false;
      _bind();
    }
    _syncPlayback();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<String?> _resolveUrl() async {
    if (widget.url != null) return widget.url;
    final item = widget.item;
    if (item.source == ExpressionSource.klipy) return item.url;
    final id = item.storageId;
    final api = widget.api;
    if (id == null) return null;
    final known = FileUrlCache.instance.peek(id);
    if (known != null) return known;
    if (api == null) return null;
    return FileUrlCache.instance.resolve(id, () => api.getFileUrl(id));
  }

  void _bind() {
    final item = widget.item;
    if (item.isLottie) {
      final cached = LottieCache.instance.peek(_key);
      if (cached != null) {
        _setComposition(cached);
        return;
      }
      final key = _key;
      LottieCache.instance.load(key, _resolveUrl).then((comp) {
        if (!mounted || key != _key) return;
        if (comp == null) {
          setState(() => _failed = true);
        } else {
          setState(() => _setComposition(comp));
        }
      });
      return;
    }
    if (widget.url != null || item.source == ExpressionSource.klipy) {
      _imageUrl = widget.url ?? item.url;
      if (_imageUrl == null) _failed = true;
      return;
    }
    final known = item.storageId == null
        ? null
        : FileUrlCache.instance.peek(item.storageId!);
    if (known != null) {
      _imageUrl = known;
      return;
    }
    final key = _key;
    _resolveUrl().then((url) {
      if (!mounted || key != _key) return;
      setState(() {
        _imageUrl = url;
        _failed = url == null;
      });
    }).catchError((Object _) {
      if (mounted && key == _key) setState(() => _failed = true);
    });
  }

  void _setComposition(LottieComposition comp) {
    _comp = comp;
    _ctrl.duration = comp.duration;
    _syncPlayback();
  }

  void _syncPlayback() {
    if (_comp == null) return;
    if (widget.play) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      _ctrl.stop();
      // A paused sticker rests on a frame that shows the character, not on a
      // blank first frame some animations start from.
      _ctrl.value = 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final item = widget.item;
    final label = item.title;
    Widget child;
    if (_failed) {
      child = Center(
        child: Text(
          (label == null || label.isEmpty) ? '🙂' : label,
          style: TextStyle(fontSize: size * 0.62, height: 1),
        ),
      );
    } else if (item.isLottie) {
      final comp = _comp;
      child = comp == null
          ? ExpressionPlaceholder(width: size, height: size, radius: size / 2)
          : Lottie(
              composition: comp,
              controller: _ctrl,
              width: size,
              height: size,
              fit: BoxFit.contain,
              // Thirty is what the Noto animations are drawn at anyway, and it
              // halves the repaints of a grid of thirty playing at once.
              frameRate: const FrameRate(30),
            );
    } else {
      final url = _imageUrl;
      final h = size / item.aspectRatio.clamp(0.5, 2.0);
      if (url == null) {
        child = ExpressionPlaceholder(width: size, height: h);
      } else if (item.source == ExpressionSource.klipy) {
        child = KlipyImage(
          url: url,
          width: size,
          height: h,
          fit: BoxFit.contain,
          play: widget.play,
          radius: 0,
        );
      } else {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        child = TickerMode(
          enabled: widget.play,
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: h,
            fit: BoxFit.contain,
            memCacheWidth: (size * dpr).round(),
            // The fade-in is a ticker animation, and a paused sticker sits
            // under a disabled TickerMode, so the fade never ran and a strip
            // icon loaded for the first time stayed invisible until the
            // memory cache served it again, unfaded. Paused art just appears.
            fadeInDuration: widget.play
                ? const Duration(milliseconds: 120)
                : Duration.zero,
            fadeOutDuration: widget.play
                ? const Duration(milliseconds: 1000)
                : Duration.zero,
            placeholder: (_, _) => ExpressionPlaceholder(width: size, height: h),
            errorWidget: (_, _, _) => Center(
              child: Text(
                (label == null || label.isEmpty) ? '🙂' : label,
                style: TextStyle(fontSize: size * 0.62, height: 1),
              ),
            ),
          ),
        );
      }
    }
    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(width: size, height: item.isLottie ? size : null, child: child),
      ),
    );
  }
}
