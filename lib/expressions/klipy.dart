import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../backend/hashing.dart';
import '../models/expression_item.dart';

/// The KLIPY API — GIF and sticker search, trending, categories, per-user
/// recents, and the share/report calls its terms ask for.
///
/// ## The rules this file exists to follow
///
/// KLIPY's integration requirements (docs.klipy.com/integration-requirements)
/// shape everything here, so they are worth stating once:
///
///  * **Calls come from the app.** API requests and media loads must originate
///    from the user's device, never from our servers. So this is plain HTTP
///    from the client, with the app key the server hands out through
///    `expressions:config` (KLIPY designs for it to ship in clients).
///  * **Media URLs are used as given.** No rewriting, no stripping
///    parameters, no re-hosting. [KlipyMedia] keeps them verbatim and
///    messages store them verbatim.
///  * **Results are shown in the order and composition returned.** Nothing
///    here filters, dedupes or reorders a page, ads included.
///  * **Content filtering is configured in the Partner Panel,** not here. The
///    one exception is a child account, which asks for `content_filter=high`
///    on every call.
///
/// ## Ads
///
/// A trending, search or recents page can contain `{type: "ad", content: html,`
/// `width, height}` items. They are only served to mobile devices,
/// only when the request carries a browser-like User-Agent (an app's own
/// `CFNetwork/…` string gets nothing), and only when the `ad-*` sizing
/// parameters are present. [KlipyClient.adsEnabled] gates all three.
class KlipyClient {
  KlipyClient({
    required this.appKey,
    required this.customerId,
    this.adsEnabled = false,
    this.childSafe = false,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String appKey;

  /// A stable, opaque per-user id. KLIPY keys recents and personalisation on
  /// it; see [klipyCustomerId].
  final String customerId;

  /// Ads requested at all. False for child accounts regardless of the server
  /// switch — see `ExpressionStore`.
  final bool adsEnabled;

  /// Child account: the strictest content filter on every call.
  final bool childSafe;

  final http.Client _http;

  /// A browser-like User-Agent from the platform web view, which KLIPY needs
  /// before it will serve an ad. Set once by the ad tile when a web view first
  /// exists; until then requests go out with the default agent and simply
  /// receive no ads.
  static String? browserUserAgent;

  /// The width the grid lays ads into, in logical pixels. Updated by the panel
  /// as it lays out so an ad is never wider than the space it will get.
  double adMaxWidth = 360;

  static const _base = 'https://api.klipy.com/api/v1';

  /// Ads are a mobile-only product on KLIPY's side.
  static bool get _adPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get _wantsAds => adsEnabled && !childSafe && _adPlatform;

  /// ISO 3166-1 country for trending/search — what KLIPY localises on.
  static String get _country =>
      (PlatformDispatcher.instance.locale.countryCode ?? 'US').toLowerCase();

  /// `en_US` style, which the categories endpoint wants instead.
  static String get _languageLocale {
    final l = PlatformDispatcher.instance.locale;
    return '${l.languageCode}_${l.countryCode ?? 'US'}';
  }

  Map<String, String> get _headers => {
        if (!kIsWeb && browserUserAgent != null)
          'User-Agent': browserUserAgent!,
      };

  Map<String, String> _adParams() {
    if (!_wantsAds) return const {};
    final view = PlatformDispatcher.instance.implicitView;
    final size = view == null
        ? null
        : view.physicalSize / view.devicePixelRatio;
    return {
      'ad-min-width': '50',
      'ad-max-width': adMaxWidth.floor().toString(),
      'ad-min-height': '50',
      'ad-max-height': '250',
      'ad-os': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'ad-language': PlatformDispatcher.instance.locale.languageCode,
      if (size != null) 'ad-device-w': size.width.round().toString(),
      if (size != null) 'ad-device-h': size.height.round().toString(),
      if (view != null) 'ad-pxratio': view.devicePixelRatio.toString(),
    };
  }

  Map<String, String> _common({bool ads = false}) => {
        'customer_id': customerId,
        if (childSafe) 'content_filter': 'high',
        if (ads) ..._adParams(),
      };

  Uri _uri(String path, Map<String, String> query) =>
      Uri.parse('$_base/$appKey/$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final res = await _http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw KlipyException(res.statusCode);
    }
    final body = jsonDecode(res.body);
    if (body is! Map || body['result'] != true) throw const KlipyException(0);
    return body.cast<String, dynamic>();
  }

  static String _segment(ExpressionKind kind) =>
      kind == ExpressionKind.gif ? 'gifs' : 'stickers';

  /// One page of trending GIFs or stickers. Pages start at 1.
  Future<KlipyPage> trending(ExpressionKind kind, {int page = 1}) async {
    final uri = _uri('${_segment(kind)}/trending', {
      'page': '$page',
      'per_page': '24',
      'locale': _country,
      ..._common(ads: true),
    });
    return KlipyPage.parse(await _get(uri), kind);
  }

  Future<KlipyPage> search(ExpressionKind kind, String query,
      {int page = 1}) async {
    final uri = _uri('${_segment(kind)}/search', {
      'q': query,
      'page': '$page',
      'per_page': '24',
      'locale': _country,
      ..._common(ads: true),
    });
    return KlipyPage.parse(await _get(uri), kind);
  }

  /// What this user sent recently through KLIPY, tracked by KLIPY itself off
  /// the share calls below.
  Future<KlipyPage> recent(ExpressionKind kind, {int page = 1}) async {
    final uri = _uri('${_segment(kind)}/recent/$customerId', {
      'page': '$page',
      'per_page': '24',
      if (childSafe) 'content_filter': 'high',
      ..._adParams(),
    });
    return KlipyPage.parse(await _get(uri), kind);
  }

  Future<List<KlipyCategory>> categories(ExpressionKind kind) async {
    final uri = _uri('${_segment(kind)}/categories', {
      'locale': _languageLocale,
    });
    final data = (await _get(uri))['data'];
    final list = data is Map ? data['categories'] : null;
    return [
      for (final c in (list as List? ?? const []))
        if (c is Map && c['query'] is String)
          KlipyCategory(
            name: (c['category'] ?? c['query']) as String,
            query: c['query'] as String,
            previewUrl: c['preview_url'] as String?,
          ),
    ];
  }

  /// Completions for a partial query, most likely first.
  Future<List<String>> autocomplete(String partial) async {
    final q = partial.trim();
    if (q.isEmpty) return const [];
    final uri = _uri('autocomplete/${Uri.encodeComponent(q)}', {'limit': '8'});
    final data = (await _get(uri))['data'];
    return [for (final s in (data as List? ?? const [])) if (s is String) s];
  }

  /// Related searches for a finished query — the chips under the search box.
  Future<List<String>> suggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri =
        _uri('search-suggestions/${Uri.encodeComponent(q)}', {'limit': '8'});
    final data = (await _get(uri))['data'];
    return [for (final s in (data as List? ?? const [])) if (s is String) s];
  }

  /// Tells KLIPY an item was sent. Its terms ask for this on every share; it
  /// is also what feeds [recent]. Fire-and-forget — a lost share ping costs
  /// the user nothing.
  Future<void> registerShare(ExpressionKind kind, String slug,
      {String? query}) async {
    try {
      await _http
          .post(
            Uri.parse('$_base/$appKey/${_segment(kind)}/share/$slug'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'customer_id': customerId,
              if (query != null && query.isNotEmpty) 'q': query,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  /// Reports an item to KLIPY's moderation.
  Future<void> report(ExpressionKind kind, String slug, String reason) async {
    await _http
        .post(
          Uri.parse('$_base/$appKey/${_segment(kind)}/report/$slug'),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'customer_id': customerId, 'reason': reason}),
        )
        .timeout(const Duration(seconds: 12));
  }

  /// Removes an item from this user's KLIPY recents.
  Future<void> hideFromRecent(ExpressionKind kind, String slug) async {
    await _http
        .delete(
          _uri('${_segment(kind)}/recent/$customerId', {'slug': slug}),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 12));
  }

  void close() => _http.close();
}

/// A stable id for [userId] that is not [userId].
///
/// KLIPY needs the same value for a user on every device and every call — it
/// keys recents on it — but has no business holding our internal ids. A
/// salted hash is both: deterministic, and meaningless outside this app.
String klipyCustomerId(String userId) =>
    sha256Hash('monkeyhub-klipy:$userId').substring(0, 32);

class KlipyException implements Exception {
  const KlipyException(this.status);
  final int status;
  @override
  String toString() => 'KlipyException($status)';
}

class KlipyCategory {
  const KlipyCategory({
    required this.name,
    required this.query,
    this.previewUrl,
  });
  final String name;
  final String query;
  final String? previewUrl;
}

/// One page of results: media and ads, in KLIPY's order.
class KlipyPage {
  const KlipyPage({
    required this.items,
    required this.page,
    required this.hasNext,
    this.itemMinWidth,
  });

  final List<KlipyResult> items;
  final int page;
  final bool hasNext;

  /// KLIPY's hint for the grid's narrowest tile, from `meta.item_min_width`.
  final double? itemMinWidth;

  static KlipyPage parse(Map<String, dynamic> body, ExpressionKind kind) {
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final items = <KlipyResult>[];
    for (final raw in (data['data'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final r = KlipyResult.parse(raw.cast<String, dynamic>(), kind);
      if (r != null) items.add(r);
    }
    final meta = data['meta'];
    return KlipyPage(
      items: items,
      page: (data['current_page'] as num?)?.toInt() ?? 1,
      hasNext: data['has_next'] == true,
      itemMinWidth: meta is Map
          ? (meta['item_min_width'] as num?)?.toDouble()
          : null,
    );
  }
}

sealed class KlipyResult {
  const KlipyResult();

  static KlipyResult? parse(Map<String, dynamic> j, ExpressionKind kind) {
    if (j['type'] == 'ad') {
      final content = j['content'];
      final w = double.tryParse('${j['width']}');
      final h = double.tryParse('${j['height']}');
      if (content is! String || w == null || h == null || w <= 0 || h <= 0) {
        return null;
      }
      return KlipyAd(html: content, width: w, height: h);
    }
    return KlipyMedia.parse(j, kind);
  }
}

class KlipyAd extends KlipyResult {
  const KlipyAd({required this.html, required this.width, required this.height});
  final String html;
  final double width;
  final double height;
}

/// One rendition of a KLIPY item.
class KlipyFile {
  const KlipyFile(this.url, this.width, this.height, this.size);
  final String url;
  final double width;
  final double height;
  final int size;
}

class KlipyMedia extends KlipyResult {
  const KlipyMedia({
    required this.kind,
    required this.slug,
    required this.title,
    required this.files,
    this.blurPreview,
  });

  final ExpressionKind kind;
  final String slug;
  final String title;

  /// tier ("hd", "md", "sm", "xs") → format ("webp", "gif", "jpg", "png", …).
  final Map<String, Map<String, KlipyFile>> files;

  /// A tiny base64 JPEG to paint while the real tile loads.
  final String? blurPreview;

  static KlipyMedia? parse(Map<String, dynamic> j, ExpressionKind kind) {
    final slug = j['slug'];
    final file = j['file'];
    if (slug is! String || file is! Map) return null;
    final files = <String, Map<String, KlipyFile>>{};
    for (final tier in file.entries) {
      if (tier.value is! Map) continue;
      final formats = <String, KlipyFile>{};
      for (final f in (tier.value as Map).entries) {
        final v = f.value;
        if (v is! Map || v['url'] is! String) continue;
        formats[f.key as String] = KlipyFile(
          v['url'] as String,
          ((v['width'] as num?) ?? 0).toDouble(),
          ((v['height'] as num?) ?? 0).toDouble(),
          ((v['size'] as num?) ?? 0).toInt(),
        );
      }
      if (formats.isNotEmpty) files[tier.key as String] = formats;
    }
    if (files.isEmpty) return null;
    return KlipyMedia(
      kind: kind,
      slug: slug,
      title: (j['title'] ?? '') as String,
      files: files,
      blurPreview: j['blur_preview'] as String?,
    );
  }

  /// Animated formats, best first. WebP is a fraction of a GIF's size and
  /// Flutter decodes both natively everywhere.
  static const _animated = ['webp', 'gif'];

  KlipyFile? _pick(String tier, List<String> formats) {
    final t = files[tier];
    if (t == null) return null;
    for (final f in formats) {
      final file = t[f];
      if (file != null) return file;
    }
    return null;
  }

  /// What a grid tile draws: the small animated rendition.
  KlipyFile? get gridFile =>
      _pick('sm', _animated) ?? _pick('xs', _animated) ?? _pick('md', _animated);

  /// What a message carries: the lightest animated rendition that is still
  /// big enough for a bubble.
  ///
  /// By SIZE rather than by tier name, because KLIPY's tiers are not ordered by
  /// weight — in the wild its `md` WebP is 640px and 1 MB while its `hd` is
  /// 498px and 280 KB. Every recipient downloads this, so the difference is
  /// real data on real phones.
  KlipyFile? get messageFile {
    final minWidth = kind == ExpressionKind.sticker ? 180.0 : 300.0;
    KlipyFile? best;
    KlipyFile? widest;
    for (final tier in files.values) {
      for (final f in _animated) {
        final file = tier[f];
        if (file == null) continue;
        if (widest == null || file.width > widest.width) widest = file;
        if (file.width >= minWidth &&
            (best == null || file.size < best.size)) {
          best = file;
        }
      }
    }
    return best ?? widest;
  }

  /// A small still for reply thumbnails and the no-autoplay state.
  KlipyFile? get stillFile =>
      _pick('xs', const ['jpg', 'png']) ??
      _pick('sm', const ['jpg', 'png']) ??
      _pick('xs', _animated);

  ExpressionItem toItem() {
    final msg = messageFile;
    return ExpressionItem(
      kind: kind,
      source: ExpressionSource.klipy,
      url: msg?.url,
      previewUrl: stillFile?.url,
      ref: slug,
      width: msg?.width,
      height: msg?.height,
      title: title.isEmpty ? null : title,
    );
  }
}
