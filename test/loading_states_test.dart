import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/pending_placeholder.dart';
import 'package:monkeyhub/widgets/skeleton_rows.dart';

/// Telling "we have not been told yet" apart from "there is nothing".
///
/// Both are an empty list, and every screen that had to distinguish them used
/// to guess. On a fast connection the guess is invisible; on a slow one the
/// chat list told people with a hundred rooms that they had none, and opening
/// a years-long conversation said "no messages yet" until the backlog landed.
///
/// The fix has two halves and both are pinned here: a real answered/unanswered
/// signal, and a bound on how long the loading state is allowed to claim the
/// answer is coming.
void main() {
  Widget host(Widget child) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(body: child),
    ),
  );

  Widget subject({required bool pending, Duration? timeout}) =>
      PendingPlaceholder(
        pending: pending,
        timeout: timeout ?? const Duration(seconds: 8),
        loading: (_) => const SkeletonRows(count: 3),
        empty: (_) => const Text('nothing here'),
      );

  testWidgets('an unanswered list shimmers instead of claiming to be empty', (
    tester,
  ) async {
    await tester.pumpWidget(host(subject(pending: true)));
    await tester.pump();

    expect(find.byType(SkeletonRows), findsOneWidget);
    expect(find.text('nothing here'), findsNothing);

    // The shimmer is a real animation, not a static block.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SkeletonRows), findsOneWidget);
  });

  testWidgets('an answer of "nothing" reaches the empty state at once', (
    tester,
  ) async {
    // A brand-new account genuinely has no rooms, and must not be made to
    // watch a skeleton for the timeout before being told so.
    await tester.pumpWidget(host(subject(pending: false)));
    await tester.pump();

    expect(find.text('nothing here'), findsOneWidget);
    expect(find.byType(SkeletonRows), findsNothing);
  });

  testWidgets('the answer landing swaps the skeleton for the real thing', (
    tester,
  ) async {
    await tester.pumpWidget(host(subject(pending: true)));
    await tester.pump();
    expect(find.byType(SkeletonRows), findsOneWidget);

    await tester.pumpWidget(host(subject(pending: false)));
    await tester.pump();
    expect(find.byType(SkeletonRows), findsNothing);
    expect(find.text('nothing here'), findsOneWidget);
  });

  testWidgets('it gives up rather than shimmering forever', (tester) async {
    // Offline, or pointed at a backend that is down: no answer is ever coming.
    // A skeleton that says "any moment now" indefinitely is a worse lie than
    // an empty list, and it hides the actions that would fix the situation.
    await tester.pumpWidget(
      host(subject(pending: true, timeout: const Duration(seconds: 2))),
    );
    await tester.pump();
    expect(find.byType(SkeletonRows), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SkeletonRows), findsOneWidget, reason: 'still waiting');

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('nothing here'), findsOneWidget);
    expect(find.byType(SkeletonRows), findsNothing);
  });

  testWidgets('a fresh wait gets a fresh timeout, not the last one\'s verdict', (
    tester,
  ) async {
    // A reconnect, or another account signing in. Having given up once must
    // not mean the next wait is written off before it starts.
    const short = Duration(seconds: 2);
    await tester.pumpWidget(host(subject(pending: true, timeout: short)));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('nothing here'), findsOneWidget);

    await tester.pumpWidget(host(subject(pending: false, timeout: short)));
    await tester.pump();
    await tester.pumpWidget(host(subject(pending: true, timeout: short)));
    await tester.pump();

    expect(find.byType(SkeletonRows), findsOneWidget,
        reason: 'the new wait starts over');

    // And it is still bounded.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('nothing here'), findsOneWidget);
  });

  testWidgets('the transcript skeleton is bubble-shaped and bottom-anchored', (
    tester,
  ) async {
    // A roster skeleton in a transcript reads as some other screen loading,
    // and a centred one puts its rows where no message will be.
    await tester.pumpWidget(
      host(const SizedBox(width: 390, height: 600, child: SkeletonBubbles())),
    );
    await tester.pump();

    final column = tester.widget<Column>(
      find.descendant(
        of: find.byType(SkeletonBubbles),
        matching: find.byType(Column),
      ).first,
    );
    expect(column.mainAxisAlignment, MainAxisAlignment.end);

    // Alternating sides — a conversation, not a monologue.
    final aligns = tester
        .widgetList<Align>(find.descendant(
          of: find.byType(SkeletonBubbles),
          matching: find.byType(Align),
        ))
        .map((a) => a.alignment)
        .toList();
    expect(aligns.length, greaterThan(1));
    expect(aligns[0], Alignment.centerLeft);
    expect(aligns[1], Alignment.centerRight);
  });
}
