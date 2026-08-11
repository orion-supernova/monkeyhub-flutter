import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/spoiler_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/spoiler_overlay.dart';

/// The veil's contract: spoiler text is covered until interacted with, a
/// partial wipe reveals only what was wiped, a full wipe (or calm-mode tap)
/// reveals everything and records it for the session.
void main() {
  const messageId = 'm1';
  const text = 'the secret is hidden in here somewhere';

  // `builder` rather than an outer MediaQuery: MaterialApp installs its own
  // MediaQuery from the view, which would silently discard an ancestor's
  // `disableAnimations` — the exact flag MotionScope reads.
  Widget host({required bool calm}) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: calm),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: LinkifiedText(
                text: text,
                style: const TextStyle(fontSize: 16, color: Colors.black),
                linkStyle: const TextStyle(color: Colors.blue),
                onLinkTap: (_) {},
                formatting: const [
                  FormattingEntity(
                    start: 4,
                    end: 30,
                    type: FormattingType.spoiler,
                  ),
                ],
                spoilerContextId: messageId,
                spoilerCover: Colors.black,
              ),
            ),
          ),
        ),
      );

  setUp(SpoilerStore.instance.clear);

  testWidgets('spoiler text mounts under a veil', (tester) async {
    await tester.pumpWidget(host(calm: true));
    await tester.pump(); // post-frame measurement pass
    expect(find.byType(SpoilerOverlay), findsOneWidget);
    // The paragraph still renders the real text — the veil, not a rewrite,
    // is the concealment, so layout and copy stay truthful.
    expect(find.textContaining('secret', findRichText: true), findsOneWidget);
  });

  testWidgets('an already-revealed message never re-veils', (tester) async {
    SpoilerStore.instance.reveal(messageId);
    await tester.pumpWidget(host(calm: true));
    await tester.pump();
    expect(find.byType(SpoilerOverlay), findsNothing);
  });

  testWidgets('calm motion: a tap on the veil reveals the whole spoiler',
      (tester) async {
    await tester.pumpWidget(host(calm: true));
    await tester.pump(); // measure rects
    await tester.pump(); // rebuild with rects

    // Tap the middle of the overlay — inside the veiled stretch.
    await tester.tap(find.byType(SpoilerOverlay), warnIfMissed: false);
    await tester.pump(); // first tick establishes the dissolve's baseline
    await tester.pump(const Duration(milliseconds: 300)); // dissolve completes
    await tester.pump(); // host rebuilds without the overlay

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
    expect(find.byType(SpoilerOverlay), findsNothing);
  });

  testWidgets('one small stroke wipes without revealing everything',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await tester.pump();
    await tester.pump();

    // A short smudge from the veil's middle — a stroke has to START on dust
    // to claim the gesture at all, which is also the real-thumb behaviour.
    final rect = tester.getRect(find.byType(SpoilerOverlay));
    await tester.dragFrom(rect.center, const Offset(30, 0));
    await tester.pump();

    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
    expect(find.byType(SpoilerOverlay), findsOneWidget);
  });

  testWidgets('wiping the whole veil dissolves it and records the reveal',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await tester.pump();
    await tester.pump();

    final rect = tester.getRect(find.byType(SpoilerOverlay));
    // ONE continuous serpentine scrub, the way a thumb actually clears a
    // spoiler: touch down on dust once, then sweep every band without
    // lifting. (Separate pointers per stroke would be refused wherever a
    // re-touch lands on an already-cleared cell — that hand-back is a
    // feature, but it isn't how anyone wipes.)
    final gesture = await tester.startGesture(rect.center);
    for (var y = rect.top + 4; y < rect.bottom + 8; y += 8) {
      await gesture.moveTo(Offset(rect.left + 2, y));
      await tester.pump();
      await gesture.moveTo(Offset(rect.right - 2, y));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(); // dissolve baseline tick
    await tester.pump(const Duration(milliseconds: 300)); // dissolve completes
    await tester.pump();

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
    expect(find.byType(SpoilerOverlay), findsNothing);
  });
}
