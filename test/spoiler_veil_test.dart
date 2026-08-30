import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/spoiler_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/spoiler_veil.dart';

/// The veil's contract: spoiler text is cut out of the paragraph until
/// touched, a rub reveals only what it touched, a tap opens the lot — and
/// nothing stays open. Both kinds of exposure close back over on their own,
/// and none of it gets in the way of the transcript around it.
///
/// Never reach for `pumpAndSettle` in a `calm: false` test here — the dust
/// ticker runs for as long as the veil is up, so it will spin to the timeout
/// rather than fail. Every wait below is an explicit duration for that reason.
void main() {
  const messageId = 'm1';
  const text = 'the secret is hidden in here somewhere';
  const spoiler = FormattingEntity(
    start: 4,
    end: 30,
    type: FormattingType.spoiler,
  );

  /// Past the longest hold (`kSpoilerHoldMaxMs`). Waits past the ceiling
  /// rather than encoding the per-character formula.
  const pastHold = Duration(milliseconds: kSpoilerHoldMaxMs + 500);

  /// Past the longest of the animations — the gather, at 800ms.
  const pastAnimation = Duration(milliseconds: 1000);

  // `builder` rather than an outer MediaQuery: MaterialApp installs its own
  // MediaQuery from the view, which would silently discard an ancestor's
  // `disableAnimations` — the exact flag MotionScope reads.
  Widget host({
    required bool calm,
    List<FormattingEntity> formatting = const [spoiler],
    void Function(String url)? onLinkEntityTap,
    Key? boundaryKey,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: calm),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 300,
                child: LinkifiedText(
                  text: text,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  linkStyle: const TextStyle(color: Colors.blue),
                  onLinkTap: (_) {},
                  onLinkEntityTap: onLinkEntityTap,
                  formatting: formatting,
                  spoilerContextId: messageId,
                  // White, so the dust never reads as "dark pixels" in the
                  // probe below — only glyphs do.
                  spoilerDust: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> settleVeil(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  RenderVeiledText veiledText(WidgetTester tester) =>
      tester.renderObject<RenderVeiledText>(find.byType(VeiledText));

  /// Opaque dark pixels inside the veil rects, from a real raster of the
  /// boundary. The test font draws every glyph as a solid box, so
  /// "concealed" is literally zero and "revealed" is a lot. Opaque, because
  /// the boundary rasterises without the Scaffold behind it and a
  /// transparent pixel reads as black.
  Future<int> darkPixelsUnderVeil(WidgetTester tester, Key boundaryKey) async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final veil = veiledText(tester);
    final image = boundary.toImageSync();
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(bytes, isNotNull);
    final width = image.width;
    var dark = 0;
    for (final r in veil.debugVeilRects) {
      final tl = veil.localToGlobal(r.topLeft, ancestor: boundary);
      final br = veil.localToGlobal(r.bottomRight, ancestor: boundary);
      for (var y = tl.dy.ceil() + 1; y < br.dy.floor() - 1; y++) {
        for (var x = tl.dx.ceil() + 1; x < br.dx.floor() - 1; x++) {
          if (x < 0 || y < 0 || x >= width || y >= image.height) continue;
          final i = (y * width + x) * 4;
          final sum = bytes!.getUint8(i) +
              bytes.getUint8(i + 1) +
              bytes.getUint8(i + 2);
          if (bytes.getUint8(i + 3) > 128 && sum < 300) dark++;
        }
      }
    }
    image.dispose();
    return dark;
  }

  setUp(SpoilerStore.instance.clear);

  testWidgets('spoiler text mounts under a veil', (tester) async {
    await tester.pumpWidget(host(calm: true));
    await settleVeil(tester);
    expect(find.byType(SpoilerVeil), findsOneWidget);
    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
    // The paragraph still carries the real text — the veil, not a rewrite,
    // is the concealment, so layout and copy stay truthful.
    expect(find.textContaining('secret', findRichText: true), findsOneWidget);
  });

  testWidgets('the words are cut out on the very first frame', (tester) async {
    // No settleVeil, deliberately: geometry is measured in layout, so the
    // first paint is already cut to the glyphs — no post-frame measurement,
    // no frame of bare text on room entry or on the long-press lifted copy.
    await tester.pumpWidget(host(calm: true));
    final veil = veiledText(tester);
    expect(veil.debugVeilRects, isNotEmpty);
    expect(veil.debugConcealing, isTrue);
    expect(
      veil,
      paints..clipPath(),
      reason: 'concealed and still, the text is painted under an even-odd '
          'clip — no layers',
    );
  });

  testWidgets('concealed means no glyph pixels; revealed means glyphs',
      (tester) async {
    const key = Key('boundary');
    await tester.pumpWidget(host(calm: true, boundaryKey: key));
    await settleVeil(tester);
    expect(await darkPixelsUnderVeil(tester, key), 0);

    await tester.tap(find.byType(SpoilerVeil), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
    expect(await darkPixelsUnderVeil(tester, key), greaterThan(100));
  });

  testWidgets('calm motion: a tap on the veil reveals the whole spoiler',
      (tester) async {
    await tester.pumpWidget(host(calm: true));
    await settleVeil(tester);

    await tester.tap(find.byType(SpoilerVeil), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
  });

  testWidgets('full motion: a tap on the veil reveals the whole spoiler',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    await tester.tap(find.byType(SpoilerVeil), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
  });

  testWidgets('a reveal does not last — the dust closes back over it',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    await tester.tap(find.byType(SpoilerVeil), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);

    await tester.pump(pastHold);
    await tester.pump(pastAnimation);
    expect(
      SpoilerStore.instance.isRevealed(messageId),
      isFalse,
      reason: 'the hold expired; the dust should have blown back in',
    );
    expect(veiledText(tester).debugConcealing, isTrue);
    // And it is still there to be revealed again.
    expect(find.byType(SpoilerVeil), findsOneWidget);
  });

  testWidgets('the spot you tapped is covered again after it heals',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);
    final spot = tester.getRect(find.byType(SpoilerVeil)).center;

    await tester.tapAt(spot);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);

    await tester.pump(pastHold);
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);

    // If anything about the tap survived on the wipe mask, this point would
    // count as an open window and the recognizer would refuse the pointer.
    await tester.tapAt(spot);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(
      SpoilerStore.instance.isRevealed(messageId),
      isTrue,
      reason: 'the tapped spot never re-veiled',
    );
  });

  testWidgets('a message that mounts already open heals on its own',
      (tester) async {
    // A row recycled while its text was showing, or a rebuild in place. The
    // veil picks the state up and starts a fresh hold, so an entry in the
    // store can never strand a spoiler permanently readable.
    SpoilerStore.instance.reveal(messageId);
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);
    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
    expect(veiledText(tester).debugConcealing, isFalse);

    await tester.pump(pastHold);
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
  });

  testWidgets('one small stroke wipes without revealing everything',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    final rect = tester.getRect(find.byType(SpoilerVeil));
    await tester.dragFrom(rect.center, const Offset(30, 0));
    await tester.pump();

    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
    expect(find.byType(SpoilerVeil), findsOneWidget);
  });

  testWidgets('even a tiny swipe stays a partial reveal, not a tap',
      (tester) async {
    // 10px is under the platform's tap slop but is unmistakably a swipe over
    // a word or two. Treating it as a tap would open the whole spoiler, which
    // is the opposite of what the gesture asked for.
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    final rect = tester.getRect(find.byType(SpoilerVeil));
    await tester.dragFrom(rect.center, const Offset(10, 0));
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
  });

  testWidgets('a partial wipe heals back to dust', (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    final rect = tester.getRect(find.byType(SpoilerVeil));
    await tester.dragFrom(rect.center, const Offset(30, 0));
    await tester.pump();

    // A wiped-open cell is a window, not veil: the recognizer refuses a
    // pointer that lands there, so this tap belongs to the transcript and
    // reveals nothing.
    await tester.tapAt(rect.center);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);

    await tester.pump(pastHold);
    await tester.pump(pastAnimation);

    // Dust again, so the same tap now takes.
    await tester.tapAt(rect.center);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(
      SpoilerStore.instance.isRevealed(messageId),
      isTrue,
      reason: 'the wiped cells never healed — the tap was still refused',
    );
  });

  testWidgets('wiping the whole veil reveals it and records the reveal',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    final rect = tester.getRect(find.byType(SpoilerVeil));
    // ONE continuous serpentine scrub, the way a thumb actually clears a
    // spoiler: touch down on dust once, then sweep every band without
    // lifting.
    final gesture = await tester.startGesture(rect.center);
    for (var y = rect.top + 4; y < rect.bottom + 8; y += 8) {
      await gesture.moveTo(Offset(rect.left + 2, y));
      await tester.pump();
      await gesture.moveTo(Offset(rect.right - 2, y));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
  });

  testWidgets('a vertical drag on the veil scrolls the transcript',
      (tester) async {
    // The old wipe claimed the pointer on down, so a scroll that happened to
    // start on a veil went to the veil. Now only sideways motion is a wipe;
    // a vertical drag is the list's, exactly as it is anywhere else.
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 40),
            LinkifiedText(
              text: text,
              style: const TextStyle(fontSize: 16, color: Colors.black),
              linkStyle: const TextStyle(color: Colors.blue),
              onLinkTap: (_) {},
              formatting: const [spoiler],
              spoilerContextId: messageId,
              spoilerDust: Colors.white,
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    ));
    await settleVeil(tester);

    await tester.drag(find.byType(SpoilerVeil), const Offset(0, -120));
    await tester.pump();

    expect(controller.offset, greaterThan(0));
    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
  });

  testWidgets('a tap on a veiled link reveals; on a revealed one it opens',
      (tester) async {
    final opened = <String>[];
    // "secret" is both the start of the spoiler and a link entity.
    await tester.pumpWidget(host(
      calm: false,
      formatting: const [
        spoiler,
        FormattingEntity(
          start: 4,
          end: 10,
          type: FormattingType.link,
          url: 'https://example.com',
        ),
      ],
      onLinkEntityTap: opened.add,
    ));
    await settleVeil(tester);

    final veil = veiledText(tester);
    final onLink = veil.localToGlobal(
      veil.debugVeilRects.first.centerLeft + const Offset(8, 0),
    );

    await tester.tapAt(onLink);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
    expect(opened, isEmpty, reason: 'a veiled link must reveal, not open');

    await tester.tapAt(onLink);
    await tester.pump();
    expect(opened, ['https://example.com']);
  });

  testWidgets('calm motion runs no ticker', (tester) async {
    // The MotionScope contract is "calm is a code path, not a shorter
    // duration" — no looping ticker, and no particle buffers behind it.
    await tester.pumpWidget(host(calm: true));
    await settleVeil(tester);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('full motion runs exactly one ticker', (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);
    expect(tester.binding.transientCallbackCount, 1);
  });

  testWidgets('an open spoiler runs no ticker while it is just text',
      (tester) async {
    // Nothing to animate while the words are simply readable, and a
    // transcript of revealed spoilers should not each hold a ticker open.
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);
    await tester.tap(find.byType(SpoilerVeil), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
