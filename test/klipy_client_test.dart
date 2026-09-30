import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monkeyhub/expressions/klipy.dart';
import 'package:monkeyhub/models/expression_item.dart';

/// The KLIPY client: parsing its real response shape (captured from the live
/// API on 2026-09-30), choosing renditions, and the request rules its terms
/// impose — customer id on every call, ads only where they can be served,
/// the strict filter for children.
void main() {
  Map<String, dynamic> file(String name, int w, int h, int size) =>
      {'url': 'https://static.klipy.com/ii/x/$name', 'width': w, 'height': h, 'size': size};

  final page = {
    'result': true,
    'data': {
      'data': [
        {
          'id': 4267701481317971,
          'slug': 'nighty-night-tom-and-jerry-4',
          'title': 'Nighty Night Tom And Jerry',
          'type': 'gif',
          'blur_preview': 'data:image/jpeg;base64,AAAA',
          'file': {
            // KLIPY's tiers are NOT ordered by weight: md is bigger than hd.
            'hd': {'webp': file('hd.webp', 498, 374, 281856), 'jpg': file('hd.jpg', 498, 373, 16850)},
            'md': {'webp': file('md.webp', 640, 480, 1047800), 'jpg': file('md.jpg', 640, 480, 24873)},
            'sm': {'webp': file('sm.webp', 220, 165, 246732), 'jpg': file('sm.jpg', 220, 165, 6649)},
            'xs': {'webp': file('xs.webp', 90, 68, 67812), 'jpg': file('xs.jpg', 90, 68, 2230)},
          },
        },
        {
          'type': 'ad',
          'width': '300',
          'height': '50',
          'content': '<html class="klipy-ad"></html>',
        },
        {'type': 'gif', 'slug': 'broken'}, // no files — dropped
      ],
      'current_page': 1,
      'per_page': 24,
      'has_next': true,
      'meta': {'item_min_width': 80, 'ad_max_resize_percent': 10},
    },
  };

  group('parsing', () {
    test('media and ads, in KLIPY\'s order', () {
      final p = KlipyPage.parse(page, ExpressionKind.gif);
      expect(p.items.length, 2);
      expect(p.items[0], isA<KlipyMedia>());
      expect(p.items[1], isA<KlipyAd>());
      expect(p.hasNext, isTrue);
      expect(p.itemMinWidth, 80);
      final ad = p.items[1] as KlipyAd;
      expect(ad.width, 300);
      expect(ad.height, 50);
    });

    test('a message carries the lightest rendition that is big enough', () {
      final m = KlipyPage.parse(page, ExpressionKind.gif).items.first as KlipyMedia;
      // hd (498px, 280 KB) beats md (640px, 1 MB): both clear the bar.
      expect(m.messageFile!.url, endsWith('hd.webp'));
      expect(m.gridFile!.url, endsWith('sm.webp'));
      expect(m.stillFile!.url, endsWith('xs.jpg'));
      final item = m.toItem();
      expect(item.source, ExpressionSource.klipy);
      expect(item.ref, 'nighty-night-tom-and-jerry-4');
      expect(item.width, 498);
      expect(item.previewUrl, endsWith('xs.jpg'));
    });
  });

  test('the customer id is stable, opaque and not the user id', () {
    final a = klipyCustomerId('k57abc');
    expect(a, klipyCustomerId('k57abc'));
    expect(a, isNot(contains('k57abc')));
    expect(a.length, 32);
    expect(klipyCustomerId('other'), isNot(a));
  });

  group('requests', () {
    late List<http.Request> seen;
    MockClient client() => MockClient((req) async {
          seen.add(req);
          return http.Response(jsonEncode(page), 200);
        });
    setUp(() => seen = []);

    test('every search names the customer and carries no filter for adults',
        () async {
      final k = KlipyClient(
          appKey: 'KEY', customerId: 'cust', httpClient: client());
      await k.search(ExpressionKind.gif, 'hello');
      final q = seen.single.url.queryParameters;
      expect(seen.single.url.path, '/api/v1/KEY/gifs/search');
      expect(q['q'], 'hello');
      expect(q['customer_id'], 'cust');
      expect(q.containsKey('content_filter'), isFalse,
          reason: 'filtering is configured in the Partner Panel');
    });

    test('a child account asks for the strictest filter and never for ads',
        () async {
      final k = KlipyClient(
        appKey: 'KEY',
        customerId: 'cust',
        adsEnabled: true,
        childSafe: true,
        httpClient: client(),
      );
      await k.trending(ExpressionKind.sticker);
      final q = seen.single.url.queryParameters;
      expect(seen.single.url.path, '/api/v1/KEY/stickers/trending');
      expect(q['content_filter'], 'high');
      expect(q.keys.where((k) => k.startsWith('ad-')), isEmpty);
    });

    test('ads are requested on mobile only, with sizing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final k = KlipyClient(
        appKey: 'KEY',
        customerId: 'cust',
        adsEnabled: true,
        httpClient: client(),
      )..adMaxWidth = 342;
      await k.trending(ExpressionKind.gif);
      final q = seen.single.url.queryParameters;
      expect(q['ad-max-width'], '342');
      expect(q['ad-min-width'], '50');
      expect(q['ad-max-height'], '250');
      expect(q['ad-os'], 'android');

      seen.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await k.trending(ExpressionKind.gif);
      expect(seen.single.url.queryParameters.keys.where((k) => k.startsWith('ad-')),
          isEmpty);
    });

    test('a share ping carries the query that found the item', () async {
      final k = KlipyClient(
          appKey: 'KEY', customerId: 'cust', httpClient: client());
      await k.registerShare(ExpressionKind.gif, 'hello-hi', query: 'hello');
      final req = seen.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/KEY/gifs/share/hello-hi');
      expect(jsonDecode(req.body), {'customer_id': 'cust', 'q': 'hello'});
    });

    test('a failed call surfaces as an error, not an empty page', () async {
      final k = KlipyClient(
        appKey: 'KEY',
        customerId: 'cust',
        httpClient: MockClient((_) async => http.Response('nope', 500)),
      );
      expect(() => k.trending(ExpressionKind.gif), throwsA(isA<KlipyException>()));
    });
  });
}
