import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/media_aspect_cache.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/remote_image.dart';
import 'package:monkeyhub/widgets/steady_hero.dart';

/// What this pins: **the gallery gives a flight somewhere to land, and
/// something already-decoded to fly.**
///
/// A page here used to be a bare `contain` image filling the route. That is two
/// separate ways for an opening flight to look wrong, and neither of them
/// throws:
///
///  * A `contain` image that has not decoded yet has no intrinsic size, so it
///    measures the whole screen — and the Hero's destination rect is the whole
///    screen. The thumbnail blows up to the full frame and the photograph then
///    drops into its letterbox a frame later, which reads as the picture
///    arriving twice.
///  * The fullscreen decode is a different `ImageCache` entry from the
///    thumbnail's, and it does not exist when the flight starts. So the thing
///    animating across the screen is a shimmer, and the picture appears at the
///    end of it — which is indistinguishable from having no flight at all.
class _FakeApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

void main() {
  final api = _FakeApi();

  ChatMessage photo(String id, {double? w = 1600, double? h = 900}) =>
      ChatMessage(
        id: id,
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.image,
        mediaStorageId: 'stor_$id',
        mediaWidth: w,
        mediaHeight: h,
      );

  Widget host(Widget home) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  Future<BuildContext> stage(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox.expand();
    })));
    return ctx;
  }

  Future<void> openPager(
    WidgetTester tester, {
    required List<ChatMessage> items,
    int initialIndex = 0,
    int? sourceDecodeWidth,
    void Function(ChatMessage m)? onPageChanged,
  }) async {
    final ctx = await stage(tester);
    MediaPagerScreen.open(
      ctx,
      items: items,
      initialIndex: initialIndex,
      api: api,
      sourceDecodeWidth: sourceDecodeWidth,
      onPageChanged: onPageChanged,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  /// The page's own image, not the filmstrip's thumbnails.
  final pageImage = find.descendant(
    of: find.byType(SteadyHero),
    matching: find.byType(RemoteImage),
  );

  /// Shapes the viewport like a phone in portrait.
  ///
  /// The default 800×600 test surface is a LANDSCAPE window, on which
  /// `photoFillsScreen` correctly decides that a 16:9 photograph should fill —
  /// so the letterbox path these tests are about never runs there. Every
  /// assertion about a shape-pinned hero has to say which shape of screen it
  /// means.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('the destination a flight aims at', () {
    testWidgets('is the picture\'s own shape when the sender said what it is', (
      tester,
    ) async {
      phone(tester);
      await openPager(tester, items: [photo('m1')]);

      final box = find.ancestor(
        of: pageImage,
        matching: find.byType(AspectRatio),
      );
      expect(
        box,
        findsOneWidget,
        reason: 'without it the hero flies to the whole screen and the '
            'photograph drops into its letterbox afterwards',
      );
      expect(tester.widget<AspectRatio>(box).aspectRatio, 1600 / 900);

      // And it is the HERO's box that ends up that shape, which is the whole
      // point — an AspectRatio the hero merely contains would leave the flight
      // aiming at the full frame exactly as before.
      final hero = tester.getSize(find.byType(SteadyHero).first);
      final screen = tester.getSize(find.byType(MediaPagerScreen));
      expect(hero.width, screen.width);
      expect(hero.height, closeTo(screen.width * 900 / 1600, 0.01));
    });

    testWidgets('is remembered from the last time this device drew it', (
      tester,
    ) async {
      // A sender who told us nothing is the common case for anything that came
      // in before the field existed. The thumbnail measured it once and the
      // cache has held it since.
      //
      // A LANDSCAPE ratio, because that is the one that still letterboxes on a
      // phone — a portrait shot fills the screen and has no box to pin. Which
      // half of the rule runs is `photoFillsScreen`'s business and is pinned in
      // `photo_fill_rule_test.dart`; this test is only about where the ratio
      // came from.
      phone(tester);
      MediaAspectCache.instance.debugPersist = false;
      MediaAspectCache.instance.remember('stor_m2', 4 / 3);
      addTearDown(() {
        MediaAspectCache.instance.clear();
        MediaAspectCache.instance.debugPersist = true;
      });

      await openPager(tester, items: [photo('m2', w: null, h: null)]);

      expect(
        tester
            .widget<AspectRatio>(
              find.ancestor(of: pageImage, matching: find.byType(AspectRatio)),
            )
            .aspectRatio,
        4 / 3,
      );
    });

    testWidgets('is the whole screen when the picture fills it', (
      tester,
    ) async {
      // A portrait shot on a tall phone fills rather than letterboxing — see
      // `photoFillsScreen`. That is still a destination the flight can aim at
      // on its first frame, which is all these tests are really about: it is
      // the whole route, known before anything has decoded, and it is the same
      // crop the thumbnail was already showing.
      phone(tester);
      await openPager(tester, items: [photo('m4', w: 900, h: 1600)]);

      expect(
        find.ancestor(of: pageImage, matching: find.byType(AspectRatio)),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(SteadyHero).first),
        tester.getSize(find.byType(MediaPagerScreen)),
      );
    });

    testWidgets('is the whole frame when nobody knows the shape', (
      tester,
    ) async {
      // The honest answer rather than a guess: there is nothing to pin it to,
      // and a wrong box is worse than a big one.
      await openPager(tester, items: [photo('m3', w: null, h: null)]);
      expect(
        find.ancestor(of: pageImage, matching: find.byType(AspectRatio)),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(SteadyHero).first),
        tester.getSize(find.byType(MediaPagerScreen)),
      );
    });
  });

  group('the decode a flight paints from', () {
    testWidgets('is the thumbnail\'s until the picture has landed', (
      tester,
    ) async {
      await openPager(tester, items: [photo('m1')], sourceDecodeWidth: 750);

      final flying = tester.widget<RemoteImage>(pageImage);
      expect(
        flying.decodeWidth,
        750,
        reason: 'the full-resolution decode is megabytes to allocate, and the '
            'one moment it must not compete for is the one the picture is '
            'moving',
      );
      expect(flying.placeholderDecodeWidth, 750);

      // Landed: the sharp one is fetched now and fades in over the warm one.
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<RemoteImage>(pageImage).decodeWidth, isNull);
      expect(tester.widget<RemoteImage>(pageImage).placeholderDecodeWidth, 750);
    });

    testWidgets('is offered only to the page the gallery opened on', (
      tester,
    ) async {
      // Nothing else was ever a thumbnail on the route below, so there is no
      // warm decode of theirs to defer to — and pinning them to a resolution
      // they never had would be a decode nobody asked for.
      await openPager(
        tester,
        items: [photo('m1'), photo('m2')],
        initialIndex: 1,
        sourceDecodeWidth: 750,
      );
      await tester.pump(const Duration(milliseconds: 400));

      final widths = tester
          .widgetList<RemoteImage>(pageImage)
          .map((i) => i.placeholderDecodeWidth)
          .toList();
      expect(widths.where((w) => w == 750), hasLength(1));
    });
  });

  testWidgets('the route below is told which picture the reader settled on', (
    tester,
  ) async {
    // This is what keeps the thumbnail for the CURRENT photograph laid out. A
    // reader who swipes eight deep and closes is flying home to a thumbnail
    // that may be a thousand rows away, and a Hero with no destination in the
    // tree cross-fades rather than complaining.
    final settled = <String>[];
    await openPager(
      tester,
      items: [photo('m1'), photo('m2'), photo('m3')],
      onPageChanged: (m) => settled.add(m.id),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(settled, isEmpty, reason: 'opening is not a page change');

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(settled, ['m2']);
  });
}
