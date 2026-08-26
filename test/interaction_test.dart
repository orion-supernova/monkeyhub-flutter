import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/models/message_interaction.dart';
import 'package:monkeyhub/models/message_preview.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/keyboard/focusable_tap.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/widgets/interaction_bubble.dart';
import 'package:monkeyhub/widgets/interaction_respondents_sheet.dart';

/// Polls, checklists and events on the client.
///
/// The server's own guarantees are asserted in `interactions.test.ts`, which
/// runs the real mutations. What is left here is everything that can only be
/// wrong on this side of the wire, and three of those are load-bearing:
///
///   1. **A card renders before its body arrives.** The transcript and the
///      interaction subscription land independently and the message usually
///      lands first, so `interaction: null` is an ordinary state on every first
///      paint. If the card draws nothing there, every poll in the app flickers.
///   2. **Optimism stops at the control.** A tapped option fills immediately;
///      the tally does NOT move until the server agrees. A bar that grew and
///      shrank back would make a dropped vote look like a counted one.
///   3. **`fractionOf` denominates in people, not votes.** On a multiple-answer
///      poll the counts sum past the number of voters, so the obvious
///      denominator draws bars past the end of the card.
void main() {
  // ── Fixtures ────────────────────────────────────────────────────────────

  ChatMessage pollMessage({
    String id = 'm1',
    MessageType type = MessageType.poll,
    String content = 'pizza or curry?',
  }) =>
      ChatMessage(
        id: id,
        roomId: 'r',
        senderId: 'author',
        senderName: 'author',
        content: content,
        createdAt: DateTime(2026, 3, 1, 12, 4),
        type: type,
      );

  InteractionChoice choice(
    String id,
    String label, {
    int count = 0,
    List<String> respondents = const [],
  }) =>
      InteractionChoice(
        id: id,
        label: label,
        count: count,
        respondents: [
          for (final n in respondents)
            InteractionRespondent(userId: n, name: n, at: DateTime(2026, 3, 1)),
        ],
      );

  MessageInteraction poll({
    MessageType kind = MessageType.poll,
    List<InteractionChoice>? choices,
    int respondentCount = 0,
    List<String> myChoiceIds = const [],
    Set<String> pending = const {},
    bool multiple = false,
    bool anonymous = false,
    bool quiz = false,
    String? correctChoiceId,
    DateTime? closedAt,
  }) =>
      MessageInteraction(
        messageId: 'm1',
        kind: kind,
        createdBy: 'author',
        createdAt: DateTime(2026, 3, 1, 12, 4),
        choices: choices ?? [choice('0', 'pizza'), choice('1', 'curry')],
        respondentCount: respondentCount,
        myChoiceIds: myChoiceIds,
        pendingChoiceIds: pending,
        multiple: multiple,
        anonymous: anonymous,
        quiz: quiz,
        correctChoiceId: correctChoiceId,
        closedAt: closedAt,
      );

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: LayoutScope(
              windowClass: WindowClass.compact,
              width: 390,
              // LOOSE constraints inside the 390, which is what the transcript
              // actually hands a bubble (`ConstrainedBox(maxWidth: ...)`). A
              // bare `SizedBox(width: 390, child: card)` would impose a TIGHT
              // 390 and stretch the card past its own `width:` — measuring the
              // harness rather than the widget.
              child: SizedBox(
                width: 390,
                child: Align(alignment: Alignment.topLeft, child: child),
              ),
            ),
          ),
        ),
      );

  Widget card(
    ChatMessage message,
    MessageInteraction? interaction, {
    InteractionActions actions = InteractionActions.none,
    String? me = 'me',
  }) =>
      Builder(
        builder: (context) => InteractionBubble(
          theme: ThemeScope.of(context),
          message: message,
          interaction: interaction,
          isMine: false,
          width: 280,
          radius: BorderRadius.circular(18),
          actions: actions,
          currentUserId: me,
          clock: () => DateTime(2026, 3, 1, 12, 30),
        ),
      );

  // ── The two-source problem ──────────────────────────────────────────────

  group('a card renders before its body arrives', () {
    testWidgets('the prompt is drawn from the MESSAGE, not the interaction',
        (tester) async {
      await tester.pumpWidget(host(card(pollMessage(), null)));
      expect(tester.takeException(), isNull);

      // The whole reason the server puts the question on the message row: a
      // poll whose body has not landed still says what it asked.
      expect(find.text('pizza or curry?'), findsOneWidget);
      // And it says what KIND it is, which is also on the message.
      expect(find.text('POLL'), findsOneWidget);
    });

    testWidgets('the body landing does not change the prompt or the height much',
        (tester) async {
      await tester.pumpWidget(host(card(pollMessage(), null)));
      final skeletonHeight = tester.getSize(find.byType(InteractionBubble)).height;

      await tester.pumpWidget(host(card(pollMessage(), poll())));
      await tester.pumpAndSettle();
      expect(find.text('pizza or curry?'), findsOneWidget);
      expect(find.text('pizza'), findsOneWidget);

      // The skeleton exists to keep the transcript from lurching when the real
      // choices arrive. Three placeholder rows against two real options is
      // close enough that the list does not jump a screen — this pins that it
      // is in the same neighbourhood rather than a zero-height placeholder.
      final realHeight = tester.getSize(find.byType(InteractionBubble)).height;
      expect((realHeight - skeletonHeight).abs(), lessThan(60));
    });
  });

  // ── Optimism ────────────────────────────────────────────────────────────

  group('optimism stops at the control', () {
    testWidgets('a pending tap does not move the tally', (tester) async {
      final confirmed = poll(
        choices: [choice('0', 'pizza', count: 2), choice('1', 'curry')],
        respondentCount: 2,
      );
      await tester.pumpWidget(host(card(pollMessage(), confirmed)));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget);

      // The same poll with this device's vote in flight. The server has not
      // agreed yet, so the percentage must be untouched.
      final pendingVote = confirmed.copyWith(pendingChoiceIds: {'1'});
      await tester.pumpWidget(host(card(pollMessage(), pendingVote)));
      await tester.pumpAndSettle();
      expect(find.text('100%'), findsOneWidget,
          reason: 'the bar must not move until the server says it has');
      expect(find.text('50%'), findsNothing);
    });

    testWidgets('a pending tap on a HELD choice draws as un-selected',
        (tester) async {
      // The subtle half: `chosen != pending`, not `chosen || pending`. Tapping
      // a choice you already hold is a RETRACTION, and drawing it filled while
      // that is in flight shows the opposite of what is about to happen.
      //
      // Asserted through `FocusableTap.selected`, which is also what a screen
      // reader announces — so this pins the state the control reports, not just
      // the pixels it paints.
      bool selectedOf(String label) {
        final tap = tester.widget<FocusableTap>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(FocusableTap),
          ).first,
        );
        return tap.selected ?? false;
      }

      // Held, nothing in flight: filled.
      await tester.pumpWidget(host(card(
        pollMessage(),
        poll(myChoiceIds: const ['0'], respondentCount: 1),
        actions: InteractionActions(onRespond: (_, _) {}),
      )));
      await tester.pumpAndSettle();
      expect(selectedOf('pizza'), isTrue);

      // Held, and a retraction in flight on the same choice: un-filled.
      await tester.pumpWidget(host(card(
        pollMessage(),
        poll(
          myChoiceIds: const ['0'],
          pending: const {'0'},
          respondentCount: 1,
        ),
        actions: InteractionActions(onRespond: (_, _) {}),
      )));
      await tester.pumpAndSettle();
      expect(selectedOf('pizza'), isFalse,
          reason: 'a pending tap on a held choice is taking it back');

      // Not held, and a vote in flight: filled at once, before the server
      // agrees. That is the whole point of the pending set.
      await tester.pumpWidget(host(card(
        pollMessage(),
        poll(pending: const {'1'}),
        actions: InteractionActions(onRespond: (_, _) {}),
      )));
      await tester.pumpAndSettle();
      expect(selectedOf('curry'), isTrue);
    });
  });

  // ── Arithmetic ──────────────────────────────────────────────────────────

  group('the tally maths', () {
    test('fractions denominate in PEOPLE, so a multi poll never exceeds 1', () {
      // One voter who picked all three. The counts sum to 3; the voters are 1.
      final p = poll(
        multiple: true,
        respondentCount: 1,
        choices: [
          choice('0', 'a', count: 1),
          choice('1', 'b', count: 1),
          choice('2', 'c', count: 1),
        ],
      );
      for (final c in p.choices) {
        expect(p.fractionOf(c), 1.0,
            reason: 'each option was picked by the one voter there is');
      }
    });

    test('a poll nobody answered divides by nothing rather than crashing', () {
      final p = poll();
      expect(p.fractionOf(p.choices.first), 0);
      expect(p.topCount, 0);
    });

    test('hiddenCount is the real remainder, and zero when anonymous', () {
      final named = choice('0', 'a', count: 9, respondents: ['x', 'y']);
      expect(named.hiddenCount, 7);

      // An anonymous poll's list is empty BY DESIGN, so the difference is not a
      // shortfall to render as "+9" — it is simply not something the card says.
      final anon = choice('0', 'a', count: 9);
      expect(anon.hiddenCount, 0);
    });

    test('doneCount counts ticked checklist items', () {
      final list = poll(
        kind: MessageType.checklist,
        choices: [
          choice('0', 'tent', count: 1),
          choice('1', 'food'),
          choice('2', 'map', count: 1),
        ],
      );
      expect(list.doneCount, 2);
      expect(list.choices.length, 3);
    });
  });

  // ── Wire shape ──────────────────────────────────────────────────────────

  group('parsing what the server sends', () {
    test('the shared-permission flags default ON when absent', () {
      // `!= false`, not `== true`. The server writes them only when the author
      // turned one OFF, so an absent field — and a row written before the flags
      // existed — has to mean "shared".
      final it = MessageInteraction.fromJson({
        'messageId': 'm1',
        'kind': 'checklist',
        'createdBy': 'author',
        'createdAt': 0,
        'choices': [],
        'respondentCount': 0,
      });
      expect(it.othersMayCheck, isTrue);
      expect(it.othersMayAdd, isTrue);

      final locked = MessageInteraction.fromJson({
        'messageId': 'm1',
        'kind': 'checklist',
        'createdBy': 'author',
        'createdAt': 0,
        'choices': [],
        'respondentCount': 0,
        'othersMayCheck': false,
      });
      expect(locked.othersMayCheck, isFalse);
      expect(locked.othersMayAdd, isTrue);
    });

    test('a withheld quiz answer parses as null, which is "not due yet"', () {
      final it = MessageInteraction.fromJson({
        'messageId': 'm1',
        'kind': 'poll',
        'createdBy': 'author',
        'createdAt': 0,
        'choices': [],
        'respondentCount': 0,
        'quiz': true,
      });
      expect(it.quiz, isTrue);
      // A quiz always HAS an answer — this null is the server withholding it.
      expect(it.correctChoiceId, isNull);
      expect(it.hasAnswered, isFalse);
    });

    test('pendingChoiceIds is never serialized', () {
      final p = poll(pending: const {'0'});
      expect(p.toJson().containsKey('pendingChoiceIds'), isFalse,
          reason: 'a cache that restored one would show a tap with no request '
              'behind it');
    });

    test('the three wire names round-trip, and unknown falls back to text', () {
      for (final t in [MessageType.poll, MessageType.checklist, MessageType.event]) {
        expect(MessageTypeWire.parse(t.wire), t);
        expect(t.isInteractive, isTrue);
      }
      expect(MessageType.text.isInteractive, isFalse);
      expect(MessageType.location.isInteractive, isFalse);
      // A client too old to know a kind renders the prompt as a plain sentence.
      expect(MessageTypeWire.parse('survey'), MessageType.text);
    });
  });

  // ── What the transcript affords ─────────────────────────────────────────

  group('what a poll affords in the long-press menu', () {
    MessageCapabilities capsFor(MessageType type, {bool isMine = true}) =>
        messageCapabilitiesFor(
          message: pollMessage(type: type),
          isMine: isMine,
          room: RoomCapabilities.dm,
          roomIsEphemeral: false,
          serverNow: DateTime(2026, 3, 1, 12, 5),
        );

    test('EDIT is refused — it would move the question under the answers', () {
      expect(capsFor(MessageType.poll).canEdit, isFalse);
      expect(capsFor(MessageType.checklist).canEdit, isFalse);
      expect(capsFor(MessageType.event).canEdit, isFalse);
      // The control: an ordinary text message the same age still edits.
      expect(capsFor(MessageType.text).canEdit, isTrue);
    });

    test('COPY is refused — the prompt without its result is not the message',
        () {
      expect(capsFor(MessageType.poll).canCopy, isFalse);
      expect(capsFor(MessageType.text).canCopy, isTrue);
    });

    test('FORWARD, PIN, SAVE and REPLY are all offered', () {
      final c = capsFor(MessageType.poll);
      expect(c.canForward, isTrue);
      expect(c.canPin, isTrue);
      expect(c.canSave, isTrue);
      expect(c.canReply, isTrue);
    });
  });

  group('one-line previews', () {
    test('a poll previews as its own prompt, with no kind word in front', () {
      // Every caller of this is one line tall — the pin banner, the reply card.
      // The chat list, which has no tap to explain itself, prefixes instead;
      // that is `roomPreviewFor` server-side.
      expect(messagePreviewLine(pollMessage()), 'pizza or curry?');
      expect(
        messagePreviewLine(pollMessage(type: MessageType.event, content: 'dinner')),
        'dinner',
      );
    });

    test('an empty prompt falls back rather than rendering a blank row', () {
      expect(messagePreviewLine(pollMessage(content: '')), 'poll');
    });
  });

  // ── Dates ───────────────────────────────────────────────────────────────

  group('eventWhenLine', () {
    // Constructible without a widget tree, which is what makes this a plain
    // unit test rather than a pump.
    const l = DefaultMaterialLocalizations();

    test('a start with no end is one date and one time', () {
      final s = eventWhenLine(
        start: DateTime(2026, 8, 26, 20, 0),
        l: l,
        use24Hour: true,
      );
      expect(s, contains('20:00'));
      expect(s, contains('·'));
      expect(s, isNot(contains('–')), reason: 'nothing to range against');
    });

    test('a same-day range prints the date once', () {
      final s = eventWhenLine(
        start: DateTime(2026, 8, 26, 20, 0),
        end: DateTime(2026, 8, 26, 23, 30),
        l: l,
        use24Hour: true,
      );
      expect(s, contains('20:00'));
      expect(s, contains('23:30'));
      final date = l.formatMediumDate(DateTime(2026, 8, 26));
      expect(date.allMatches(s).length, 1);
    });

    test('a cross-day range prints both dates', () {
      final start = DateTime(2026, 8, 26, 20, 0);
      final end = DateTime(2026, 8, 27, 2, 0);
      final s = eventWhenLine(start: start, end: end, l: l, use24Hour: true);
      expect(s, contains(l.formatMediumDate(start)));
      expect(s, contains(l.formatMediumDate(end)));
    });

    test('the clock format follows the device, not the locale', () {
      final start = DateTime(2026, 8, 26, 20, 0);
      expect(eventWhenLine(start: start, l: l, use24Hour: true), contains('20:00'));
      expect(eventWhenLine(start: start, l: l, use24Hour: false), contains('8:00'));
    });
  });

  // ── Rendered states ─────────────────────────────────────────────────────

  group('the states a card can be in', () {
    testWidgets('an anonymous poll shows counts but names nobody',
        (tester) async {
      final anon = poll(
        anonymous: true,
        respondentCount: 3,
        choices: [choice('0', 'pizza', count: 3), choice('1', 'curry')],
      );
      await tester.pumpWidget(host(card(pollMessage(), anon)));
      await tester.pumpAndSettle();

      expect(find.text('ANONYMOUS'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      // No name line under the option, because there are none to draw.
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('a closed poll says so and refuses taps', (tester) async {
      var taps = 0;
      final closed = poll(
        closedAt: DateTime(2026, 3, 1, 12, 20),
        respondentCount: 1,
        choices: [choice('0', 'pizza', count: 1), choice('1', 'curry')],
      );
      await tester.pumpWidget(host(card(
        pollMessage(),
        closed,
        actions: InteractionActions(onRespond: (_, _) => taps++),
      )));
      await tester.pumpAndSettle();

      expect(find.text('CLOSED'), findsOneWidget);
      await tester.tap(find.text('curry'));
      await tester.pumpAndSettle();
      expect(taps, 0, reason: 'a closed poll takes no answers');
    });

    testWidgets('tapping an open option reports the choice id', (tester) async {
      String? got;
      await tester.pumpWidget(host(card(
        pollMessage(),
        poll(),
        actions: InteractionActions(onRespond: (_, choiceId) => got = choiceId),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('curry'));
      await tester.pumpAndSettle();
      expect(got, '1');
    });

    testWidgets('CLOSE is offered to the author and to nobody else',
        (tester) async {
      final mine = poll();
      await tester.pumpWidget(host(card(
        pollMessage(),
        mine,
        actions: InteractionActions(onClose: (_) {}),
        me: 'author',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsOneWidget);

      await tester.pumpWidget(host(card(
        pollMessage(),
        mine,
        actions: InteractionActions(onClose: (_) {}),
        me: 'someone-else',
      )));
      await tester.pumpAndSettle();
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('a quiz reveals its verdict only once answered', (tester) async {
      // Before: the server withheld `correctChoiceId`, so no verdict.
      await tester.pumpWidget(host(card(
        pollMessage(),
        poll(quiz: true, respondentCount: 1),
      )));
      await tester.pumpAndSettle();
      expect(find.text('QUIZ'), findsOneWidget);
      expect(find.text('Correct'), findsNothing);
      expect(find.text('Not quite'), findsNothing);

      // After answering wrong.
      await tester.pumpWidget(host(card(
        pollMessage(),
        poll(
          quiz: true,
          respondentCount: 1,
          myChoiceIds: const ['0'],
          correctChoiceId: '1',
          choices: [choice('0', 'pizza', count: 1), choice('1', 'curry')],
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Not quite'), findsOneWidget);
    });

    testWidgets('a checklist counts progress and offers an add field',
        (tester) async {
      final list = poll(
        kind: MessageType.checklist,
        respondentCount: 1,
        choices: [
          choice('0', 'tent', count: 1, respondents: ['bea']),
          choice('1', 'food'),
        ],
      );
      await tester.pumpWidget(host(card(
        pollMessage(type: MessageType.checklist, content: 'camping'),
        list,
        actions: InteractionActions(onAddItem: (_, _) {}),
      )));
      await tester.pumpAndSettle();

      expect(find.text('CHECKLIST'), findsOneWidget);
      expect(find.text('1 of 2 done'), findsOneWidget);
      expect(find.text('bea'), findsOneWidget);
      // A checklist row draws no percentage — a bar behind one task would read
      // as that task's own progress.
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Add an item'), findsOneWidget);
    });

    testWidgets('an event card shows its when-line and the three RSVPs',
        (tester) async {
      final event = MessageInteraction(
        messageId: 'm1',
        kind: MessageType.event,
        createdBy: 'author',
        createdAt: DateTime(2026, 3, 1, 12, 4),
        choices: [
          choice('going', 'going', count: 2, respondents: ['bea', 'cal']),
          choice('maybe', 'maybe'),
          choice('no', 'no'),
        ],
        respondentCount: 2,
        startsAt: DateTime(2026, 8, 26, 20, 0),
        place: 'the usual',
      );
      await tester.pumpWidget(host(card(
        pollMessage(type: MessageType.event, content: 'dinner'),
        event,
      )));
      await tester.pumpAndSettle();

      expect(find.text('EVENT'), findsOneWidget);
      expect(find.text('dinner'), findsOneWidget);
      expect(find.text('the usual'), findsOneWidget);
      expect(find.text('bea, cal'), findsOneWidget);
      expect(find.text('2 replies'), findsOneWidget);
    });

    testWidgets('a past event says so rather than hiding the line',
        (tester) async {
      final past = MessageInteraction(
        messageId: 'm1',
        kind: MessageType.event,
        createdBy: 'author',
        createdAt: DateTime(2026, 1, 1),
        choices: [choice('going', 'going'), choice('maybe', 'maybe'), choice('no', 'no')],
        respondentCount: 0,
        // The card's injected clock is 2026-03-01 12:30.
        startsAt: DateTime(2026, 2, 1, 20, 0),
      );
      await tester.pumpWidget(host(card(
        pollMessage(type: MessageType.event, content: 'dinner'),
        past,
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('already happened'), findsOneWidget);
    });
  });

  // ── What a render caught that the assertions did not ────────────────────

  group('regressions found by looking at a rendered card', () {
    testWidgets("an event's RSVP buttons are the app's words, not the server's",
        (tester) async {
      // `choice.label` for an event is a server-owned TOKEN — `going`, `maybe`,
      // `no` — not something a person typed. Printing it raw put English on the
      // card in all twelve languages, and every assertion still passed because
      // the tests were written in English too.
      final event = MessageInteraction(
        messageId: 'm1',
        kind: MessageType.event,
        createdBy: 'author',
        createdAt: DateTime(2026, 3, 1),
        choices: [
          choice('going', 'going'),
          choice('maybe', 'maybe'),
          choice('no', 'no'),
        ],
        respondentCount: 0,
        startsAt: DateTime(2026, 8, 26, 20, 0),
      );
      await tester.pumpWidget(host(card(
        pollMessage(type: MessageType.event, content: 'dinner'),
        event,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Going'), findsOneWidget);
      expect(find.text('Maybe'), findsOneWidget);
      expect(find.text("Can't"), findsOneWidget);
      // The raw tokens must not reach the card at all.
      expect(find.text('going'), findsNothing);
      expect(find.text('no'), findsNothing);
    });

    testWidgets('the footer survives every action being live at once',
        (tester) async {
      // RETRACT, CLOSE and SEE WHO ANSWERED are all offered on the author's own
      // open, answered, public poll — more words than 280pt holds beside a
      // count and a stamp. As one `Row` it overflowed by 22 pixels, and a `Row`
      // reports that by painting a stripe rather than by failing layout, so
      // nothing here went red until a card was rendered and looked at.
      final busy = poll(
        respondentCount: 5,
        myChoiceIds: const ['0'],
        choices: [choice('0', 'pizza', count: 5), choice('1', 'curry')],
      );
      await tester.pumpWidget(host(card(
        pollMessage(),
        busy,
        me: 'author',
        actions: InteractionActions(
          onRespond: (_, _) {},
          onRetract: (_) {},
          onClose: (_) {},
          onShowRespondents: (_) {},
        ),
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'the footer must wrap rather than overflow');
      expect(find.text('Retract'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('See who answered'), findsOneWidget);

      // And every one of them is inside the card, not painted past its edge.
      final cardRect = tester.getRect(find.byType(InteractionBubble));
      for (final label in ['Retract', 'Close', 'See who answered']) {
        final r = tester.getRect(find.text(label));
        expect(r.right, lessThanOrEqualTo(cardRect.right + 0.5), reason: label);
        expect(r.bottom, lessThanOrEqualTo(cardRect.bottom + 0.5), reason: label);
      }
    });
  });

  group('the respondents sheet', () {
    testWidgets('survives its own first frame, before the query returns',
        (tester) async {
      // It did not. `visible` was a ternary with a `..sort()` cascade on the
      // end, and the cascade bound to the WHOLE conditional — so the
      // still-loading branch was a `const []` being sorted, which throws.
      // Analyzer-clean, type-correct, and it crashed the sheet every single
      // time it was opened. Nothing here could see it until the sheet was
      // pumped rather than reasoned about.
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: InteractionRespondentsSheet(
              api: ChatApi(ConvexBackend.instance),
              messageId: 'm1',
              currentUserId: 'me',
              interaction: poll(
                respondentCount: 2,
                choices: [choice('0', 'pizza', count: 2), choice('1', 'curry')],
              ),
              resolveUser: (_) => null,
              onOpenProfile: (_) {},
            ),
          ),
        ),
      ));

      // The frame the crash happened in: the request is out, nothing is back.
      expect(tester.takeException(), isNull);
      expect(find.text('WHO VOTED'), findsOneWidget);
      expect(find.text('2 votes'), findsOneWidget);
    });
  });

  // ── Layout ──────────────────────────────────────────────────────────────

  group('geometry', () {
    testWidgets('a long option wraps inside the card rather than overflowing',
        (tester) async {
      final wordy = poll(
        respondentCount: 1,
        choices: [
          choice(
            '0',
            'the one where we all drive out to the coast and nobody agrees '
                'about the parking',
            count: 1,
          ),
          choice('1', 'no'),
        ],
      );
      await tester.pumpWidget(host(card(pollMessage(), wordy)));
      await tester.pumpAndSettle();

      // `Row` hands a non-flexible child unbounded width — the defect the
      // document bubble shipped with. The option text is the one string on this
      // card that must never be truncated to make room for chrome.
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(InteractionBubble));
      expect(rect.width, lessThanOrEqualTo(280.5));
      expect(rect.right, lessThanOrEqualTo(390));
    });

    testWidgets('the percentage stays inside the card at the narrowest width',
        (tester) async {
      final p = poll(
        respondentCount: 3,
        choices: [choice('0', 'pizza', count: 3), choice('1', 'curry')],
      );
      await tester.pumpWidget(host(card(pollMessage(), p)));
      await tester.pumpAndSettle();

      final pct = tester.getRect(find.text('100%'));
      final cardRect = tester.getRect(find.byType(InteractionBubble));
      expect(pct.right, lessThanOrEqualTo(cardRect.right + 0.5));
    });
  });
}
