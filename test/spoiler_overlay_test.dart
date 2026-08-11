import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/spoiler_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/spoiler_overlay.dart';

/// The veil's contract: spoiler text is covered until touched, a swipe reveals
/// only what it touched, a tap opens the lot — and nothing stays open. Both
/// kinds of exposure heal back to dust on their own.
///
/// Never reach for `pumpAndSettle` in a `calm: false` test here — the drift
/// controller repeats forever, so it will spin to the timeout rather than
/// fail. Every wait below is an explicit duration for that reason.
void main() {
  const messageId = 'm1';
  const text = 'the secret is hidden in here somewhere';

  /// The spoiler is 26 characters, so the hold floors at 5s. These wait past
  /// it rather than encoding the formula.
  const pastHold = Duration(seconds: 6);
  const pastAnimation = Duration(milliseconds: 900);

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
                spoilerDust: Colors.white,
              ),
            ),
          ),
        ),
      );

  /// Pump the two frames the overlay needs to measure and mount its geometry.
  Future<void> settleVeil(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  setUp(SpoilerStore.instance.clear);

  testWidgets('spoiler text mounts under a veil', (tester) async {
    await tester.pumpWidget(host(calm: true));
    await settleVeil(tester);
    expect(find.byType(SpoilerOverlay), findsOneWidget);
    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
    // The paragraph still renders the real text — the veil, not a rewrite,
    // is the concealment, so layout and copy stay truthful.
    expect(find.textContaining('secret', findRichText: true), findsOneWidget);
  });

  testWidgets('calm motion: a tap on the veil reveals the whole spoiler',
      (tester) async {
    await tester.pumpWidget(host(calm: true));
    await settleVeil(tester);

    await tester.tap(find.byType(SpoilerOverlay), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
  });

  testWidgets('full motion: a tap on the veil reveals the whole spoiler',
      (tester) async {
    // The wipe recognizer claims the pointer on down, so a tap has to be
    // recognised inside the pan rather than by a recognizer beside it.
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    await tester.tap(find.byType(SpoilerOverlay), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
  });

  testWidgets('a reveal does not last — the dust closes back over it',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    await tester.tap(find.byType(SpoilerOverlay), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);

    await tester.pump(pastHold);
    await tester.pump(pastAnimation);
    expect(
      SpoilerStore.instance.isRevealed(messageId),
      isFalse,
      reason: 'the hold expired; the wavefront should have run backwards',
    );
    // And it is still there to be revealed again.
    expect(find.byType(SpoilerOverlay), findsOneWidget);
  });

  testWidgets('a message that mounts already open heals on its own',
      (tester) async {
    // A row recycled while its text was showing, or a rebuild in place. The
    // overlay picks the state up and starts a fresh hold, so an entry in the
    // store can never strand a spoiler permanently readable.
    SpoilerStore.instance.reveal(messageId);
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);
    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);

    await tester.pump(pastHold);
    await tester.pump(pastAnimation);
    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
  });

  testWidgets('one small stroke wipes without revealing everything',
      (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    // A short smudge from the veil's middle — a stroke has to START on dust
    // to claim the gesture at all, which is also the real-thumb behaviour.
    final rect = tester.getRect(find.byType(SpoilerOverlay));
    await tester.dragFrom(rect.center, const Offset(30, 0));
    await tester.pump();

    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
    expect(find.byType(SpoilerOverlay), findsOneWidget);
  });

  testWidgets('even a tiny swipe stays a partial reveal, not a tap',
      (tester) async {
    // 10px is under the platform's tap slop but is unmistakably a swipe over
    // a word or two. Treating it as a tap would open the whole spoiler, which
    // is the opposite of what the gesture asked for.
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    final rect = tester.getRect(find.byType(SpoilerOverlay));
    await tester.dragFrom(rect.center, const Offset(10, 0));
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isFalse);
  });

  testWidgets('a partial wipe heals back to dust', (tester) async {
    await tester.pumpWidget(host(calm: false));
    await settleVeil(tester);

    final rect = tester.getRect(find.byType(SpoilerOverlay));
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
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
  });

  testWidgets('calm motion runs no ticker', (tester) async {
    // The MotionScope contract is "calm is a code path, not a shorter
    // duration" — no looping controller, and no particle buffers behind it.
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
    await tester.tap(find.byType(SpoilerOverlay), warnIfMissed: false);
    await tester.pump();
    await tester.pump(pastAnimation);

    expect(SpoilerStore.instance.isRevealed(messageId), isTrue);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
