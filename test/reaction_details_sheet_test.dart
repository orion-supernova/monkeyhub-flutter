import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/message_reaction.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/reaction_details_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins: the sheet always says which emoji each row is about.
///
/// It used to say so only via the filter pills, and the pills only rendered
/// when a message carried two or more distinct emoji — a deliberate choice
/// ("redundant inside a single-emoji filter") that had the opposite effect in
/// the one case it was meant to tidy. On a message with a single reaction the
/// pill row was suppressed AND the per-row emoji was suppressed, so the emoji
/// appeared nowhere at all and the sheet was a list of names with no subject.
///
/// The emoji is now badged onto every reactor's avatar regardless of filter, so
/// the two suppressions can no longer combine into nothing.
class _FakeApi extends Fake implements ChatApi {}

/// `findMessageInRoom` returning null is the sheet's documented fallback path —
/// it then reads the reactions the pressed bubble handed it, which is exactly
/// the list these tests want to control.
class _FakeRepo extends ChangeNotifier implements ChatRepository {
  @override
  ChatMessage? findMessageInRoom(String roomId, String id) => null;

  @override
  ChatUser? userById(String id) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final t0 = DateTime(2026, 8, 8, 14, 20);

  MessageReaction reaction(String userId, String emoji, int minute) =>
      MessageReaction(
        id: '$userId-$emoji',
        messageId: 'm1',
        userId: userId,
        emoji: emoji,
        createdAt: t0.add(Duration(minutes: minute)),
      );

  final people = <String, ChatUser>{
    'me': ChatUser(id: 'me', username: 'murat', name: 'Murat'),
    'ada': ChatUser(id: 'ada', username: 'ada', name: 'Ada'),
    'lin': ChatUser(id: 'lin', username: 'lin', name: 'Lin'),
  };

  // ThemeScope wraps MaterialApp rather than sitting inside `home`, matching
  // app.dart and the reaction-picker test next door.
  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  Widget sheet({
    required List<MessageReaction> reactions,
    required String initialEmoji,
    Future<void> Function(String emoji)? onToggle,
  }) =>
      ReactionDetailsSheet(
        repo: _FakeRepo(),
        api: _FakeApi(),
        roomId: 'r1',
        messageId: 'm1',
        fallback: reactions,
        currentUserId: 'me',
        initialEmoji: initialEmoji,
        resolveUser: (id) => people[id],
        onOpenProfile: (_) {},
        onToggle: onToggle,
      );

  testWidgets('a single-emoji message still shows the emoji', (tester) async {
    // The regression. Two reactors, one emoji: no pill row is drawn, so before
    // the redesign this sheet contained the string '😂' exactly zero times.
    await tester.pumpWidget(host(sheet(
      reactions: [reaction('ada', '😂', 0), reaction('lin', '😂', 1)],
      initialEmoji: '😂',
    )));
    await tester.pumpAndSettle();

    // One badge per reactor, plus the summary chip that echoes the reaction
    // chip that was long-pressed to open the sheet.
    expect(find.text('😂'), findsNWidgets(3));
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Lin'), findsOneWidget);

    // No filter to offer when every row is in the same bucket.
    expect(find.text('All'), findsNothing);
  });

  testWidgets('every row is badged while a filter is applied', (tester) async {
    // Same suppression, reached the other way: with pills on screen the rows
    // used to drop their emoji as soon as any single pill was selected.
    await tester.pumpWidget(host(sheet(
      reactions: [
        reaction('ada', '😂', 0),
        reaction('lin', '😂', 1),
        reaction('me', '🔥', 2),
      ],
      initialEmoji: '😂',
    )));
    await tester.pumpAndSettle();

    // Two rows + the '😂' pill. '🔥' is filtered out of the list, leaving only
    // its own pill.
    expect(find.text('😂'), findsNWidgets(3));
    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('Lin'), findsOneWidget);
    expect(find.text('Murat'), findsNothing);
  });

  testWidgets('ALL keeps each row on its own emoji', (tester) async {
    await tester.pumpWidget(host(sheet(
      reactions: [
        reaction('ada', '😂', 0),
        reaction('lin', '😂', 1),
        reaction('me', '🔥', 2),
      ],
      initialEmoji: '😂',
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    // Three rows now, and the badge follows the reaction rather than the
    // filter: two 😂 rows + its pill, one 🔥 row + its pill.
    expect(find.text('Murat'), findsOneWidget);
    expect(find.text('😂'), findsNWidgets(3));
    expect(find.text('🔥'), findsNWidgets(2));
  });

  testWidgets('an emoji taken back mid-sheet falls back to ALL',
      (tester) async {
    // The filter can outlive its own group. Opening on an emoji nobody holds
    // must not throw on `groups.firstWhere`.
    await tester.pumpWidget(host(sheet(
      reactions: [reaction('ada', '😂', 0), reaction('me', '🔥', 1)],
      initialEmoji: '🎉',
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Murat'), findsOneWidget);
  });

  testWidgets('the empty state survives losing the last reaction',
      (tester) async {
    await tester.pumpWidget(host(sheet(reactions: [], initialEmoji: '😂')));
    await tester.pumpAndSettle();

    expect(find.text('Nothing here anymore'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it lays out inside an unbounded scroll view', (tester) async {
    // The desktop form of `showAdaptiveSheet` puts the content in a
    // `SingleChildScrollView`, i.e. hands it unbounded height, and this sheet
    // is only ever opened by long-pressing a chip on a phone — so the desktop
    // form is the one nobody looks at. The list is bounded by a plain
    // `ConstrainedBox` over a shrink-wrapped `ListView`, as the other sheets
    // do it. Swapping that for an `Expanded` would throw here ("RenderFlex
    // children have non-zero flex but incoming height constraints are
    // unbounded" fires on a tight fit — see rendering/flex.dart), and nothing
    // on a phone would notice.
    await tester.pumpWidget(host(
      SingleChildScrollView(
        child: sheet(
          reactions: [
            for (var i = 0; i < 12; i++) reaction('u$i', '😂', i),
          ],
          initialEmoji: '😂',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('the toggle adds the emoji you tapped, or takes yours back',
      (tester) async {
    // A chip tap opens this sheet instead of toggling, so the sheet has to
    // be where yours is added and removed.
    final toggled = <String>[];
    Widget build(List<MessageReaction> reactions) => host(sheet(
          reactions: reactions,
          initialEmoji: '😂',
          onToggle: (e) async => toggled.add(e),
        ));

    await tester.pumpWidget(build([reaction('ada', '😂', 0)]));
    await tester.pumpAndSettle();
    expect(find.text('Add yours'), findsOneWidget);
    await tester.tap(find.text('Add yours'));
    expect(toggled, ['😂']);

    // Yours lands: the same control now takes it back, after the burst.
    await tester.pumpWidget(
        build([reaction('ada', '😂', 0), reaction('me', '😂', 1)]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Remove yours'), findsOneWidget);
    await tester.tap(find.text('Remove yours'));
    expect(toggled, ['😂', '😂']);
  });

  testWidgets('the toggle follows the filter, and survives taking back the '
      'last one', (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(host(sheet(
      reactions: [reaction('ada', '😂', 0), reaction('me', '🔥', 1)],
      initialEmoji: '😂',
      onToggle: (e) async => toggled.add(e),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🔥').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove yours'), findsOneWidget);
    await tester.tap(find.text('Remove yours'));
    expect(toggled, ['🔥']);

    // Nobody holds it any more: the list falls back to ALL, but the control
    // stays on 🔥 so the take-back can be undone in place.
    await tester.pumpWidget(host(sheet(
      reactions: [reaction('ada', '😂', 0)],
      initialEmoji: '😂',
      onToggle: (e) async => toggled.add(e),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Add yours'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
  });

  testWidgets('no right to react, no toggle', (tester) async {
    await tester.pumpWidget(host(sheet(
      reactions: [reaction('ada', '😂', 0)],
      initialEmoji: '😂',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Add yours'), findsNothing);
  });
}
