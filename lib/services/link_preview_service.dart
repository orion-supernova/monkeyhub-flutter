import 'dart:async';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Parsed metadata for a single URL, used to render a preview card.
///
/// Any field may be null when the source page omits it. A preview with
/// nothing but [url] is still rendered as a minimal domain pill so the
/// user knows the link is at least reachable.
class LinkPreview {
  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;

  String get domain {
    try {
      final host = Uri.parse(url).host;
      return host.startsWith('www.') ? host.substring(4) : host;
    } catch (_) {
      return url;
    }
  }

  bool get hasContent =>
      (title?.isNotEmpty ?? false) ||
      (description?.isNotEmpty ?? false) ||
      (imageUrl?.isNotEmpty ?? false);
}

/// In-memory cache + deduper for [LinkPreview] fetches. Singleton via
/// [LinkPreviewService.instance] — each message bubble re-mounts on rebuild
/// and would otherwise re-fetch the same OG metadata on every scroll.
class LinkPreviewService {
  LinkPreviewService._();
  static final LinkPreviewService instance = LinkPreviewService._();

  final Map<String, Future<LinkPreview?>> _inflight = {};
  final Map<String, LinkPreview?> _cache = {};

  /// Returns a cached preview synchronously if one exists, otherwise null.
  /// Callers should fall back to [fetch] when this is null.
  LinkPreview? cached(String url) => _cache[url];

  Future<LinkPreview?> fetch(String url) {
    final existing = _inflight[url];
    if (existing != null) return existing;
    if (_cache.containsKey(url)) return Future.value(_cache[url]);

    final future = _fetch(url).then((preview) {
      _cache[url] = preview;
      _inflight.remove(url);
      return preview;
    }).catchError((_) {
      _cache[url] = null;
      _inflight.remove(url);
      return null;
    });

    _inflight[url] = future;
    return future;
  }

  Future<LinkPreview?> _fetch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }

    // Many sites only emit rich OG/Twitter meta to known crawler UAs.
    // facebookexternalhit is the most widely-served-against bot signature.
    final response = await http.get(
      uri,
      headers: const {
        'User-Agent':
            'facebookexternalhit/1.1 (+https://www.facebook.com/externalhit_uatext.php)',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    ).timeout(const Duration(seconds: 6));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return LinkPreview(url: url);
    }

    final body = _decodeBody(response);
    final document = html_parser.parse(body);

    String? meta(String selectorAttr, String selectorValue) {
      for (final element
          in document.querySelectorAll('meta[$selectorAttr]')) {
        if (element.attributes[selectorAttr]?.toLowerCase() == selectorValue) {
          final content = element.attributes['content']?.trim();
          if (content != null && content.isNotEmpty) return content;
        }
      }
      return null;
    }

    final title = meta('property', 'og:title') ??
        meta('name', 'twitter:title') ??
        document.querySelector('title')?.text.trim();

    final description = meta('property', 'og:description') ??
        meta('name', 'twitter:description') ??
        meta('name', 'description');

    final rawImage = meta('property', 'og:image') ??
        meta('property', 'og:image:url') ??
        meta('property', 'og:image:secure_url') ??
        meta('name', 'twitter:image') ??
        meta('name', 'twitter:image:src') ??
        meta('itemprop', 'image') ??
        _linkHref(document, 'image_src') ??
        _firstSizableImage(document) ??
        _linkHref(document, 'apple-touch-icon') ??
        _linkHref(document, 'apple-touch-icon-precomposed') ??
        _linkHref(document, 'icon');

    final siteName = meta('property', 'og:site_name');

    return LinkPreview(
      url: url,
      title: _decodeEntities(title),
      description: _decodeEntities(description),
      imageUrl: rawImage == null ? null : _resolveUrl(uri, rawImage),
      siteName: _decodeEntities(siteName),
    );
  }

  /// Pulls `href` from `<link rel="$rel">` — used to mine alternate image
  /// sources (image_src, apple-touch-icon, favicon) when og:image is missing.
  String? _linkHref(dynamic document, String rel) {
    for (final el in document.querySelectorAll('link[rel]')) {
      final attr = el.attributes['rel']?.toLowerCase() ?? '';
      // rel can be space-separated ("icon mask-icon"); match any token.
      if (attr.split(RegExp(r'\s+')).contains(rel.toLowerCase())) {
        final href = el.attributes['href']?.trim();
        if (href != null && href.isNotEmpty) return href;
      }
    }
    return null;
  }

  /// Best-effort fallback when no metadata image is present: scan the
  /// document for the first reasonably large `<img>` (declared width/height
  /// ≥ 200, or src that looks like a hero/banner). Avoids picking up tiny
  /// tracking pixels, sprite sheets, and icon thumbnails.
  String? _firstSizableImage(dynamic document) {
    for (final el in document.querySelectorAll('img')) {
      final src = el.attributes['src']?.trim();
      if (src == null || src.isEmpty) continue;
      // Skip data URIs and likely-tracking 1x1 GIFs.
      if (src.startsWith('data:')) continue;
      final w = int.tryParse(el.attributes['width'] ?? '');
      final h = int.tryParse(el.attributes['height'] ?? '');
      if (w != null && w < 80) continue;
      if (h != null && h < 80) continue;
      // If dimensions aren't declared, accept any non-icon-looking path.
      final lower = src.toLowerCase();
      if (lower.contains('spacer') ||
          lower.contains('pixel') ||
          lower.endsWith('.svg')) {
        continue;
      }
      return src;
    }
    return null;
  }

  String _decodeBody(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final charsetMatch =
        RegExp(r'charset=([\w\-]+)', caseSensitive: false).firstMatch(contentType);
    final charset = charsetMatch?.group(1)?.toLowerCase();
    try {
      if (charset == null || charset == 'utf-8' || charset == 'utf8') {
        return utf8.decode(response.bodyBytes, allowMalformed: true);
      }
      if (charset == 'iso-8859-1' || charset == 'latin-1') {
        return latin1.decode(response.bodyBytes, allowInvalid: true);
      }
    } catch (_) {}
    return response.body;
  }

  String? _resolveUrl(Uri base, String maybeRelative) {
    try {
      return base.resolve(maybeRelative).toString();
    } catch (_) {
      return maybeRelative;
    }
  }

  String? _decodeEntities(String? value) {
    if (value == null) return null;
    // Cheap unescape for the handful of entities that crop up in OG meta;
    // pulling in a full HTML entity decoder for these isn't worth the dep.
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}

/// Detects bare http/https URLs in a string. Trailing punctuation that's
/// almost never part of a URL (`.,;:!?)]}>`) is stripped so "see https://x.com."
/// yields the URL without the period.
class UrlDetector {
  static final RegExp _pattern = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  static const _trailingTrim = '.,;:!?)]}>\'"';

  /// Returns all URL matches as (start, end, url) tuples in document order.
  static List<UrlMatch> matches(String text) {
    final out = <UrlMatch>[];
    for (final m in _pattern.allMatches(text)) {
      var url = m.group(0)!;
      var end = m.end;
      while (url.isNotEmpty && _trailingTrim.contains(url[url.length - 1])) {
        url = url.substring(0, url.length - 1);
        end -= 1;
      }
      if (url.isEmpty) continue;
      out.add(UrlMatch(start: m.start, end: end, url: url));
    }
    return out;
  }

  /// Returns the unique URLs (first-occurrence order) found in [text].
  static List<String> extract(String text) {
    final seen = <String>{};
    final out = <String>[];
    for (final m in matches(text)) {
      if (seen.add(m.url)) out.add(m.url);
    }
    return out;
  }

}

class UrlMatch {
  const UrlMatch({required this.start, required this.end, required this.url});
  final int start;
  final int end;
  final String url;
}
