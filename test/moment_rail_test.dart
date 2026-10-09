import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_group.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_rail.dart';
import 'package:monkeyhub/widgets/remote_image.dart';

/// What this pins: **a person's card says what it holds, to everyone.** A
/// screen reader hears who, how many and how many are new in one stop (the
/// stack drawn behind the card is decoration); your own card carries the
/// "+" and the capture tile steps aside for it.
class _Api extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

Moment _m(
  String id,
  String user,
  int h, {
  bool seen = false,
  bool mine = false,
  bool picture = false,
}) =>
    Moment(
      id: id,
      userId: user,
      dayKey: '2026-10-09',
      createdAt: DateTime(2026, 10, 9, h),
      expiresAt: DateTime(2026, 10, 10, h),
      authorName: user,
      authorUsername: user,
      mine: mine,
      seen: seen || mine,
      caption: 'c',
      mediaStorageId: picture ? 'blob_$id' : null,
      mediaKind: picture ? MomentMedia.image : MomentMedia.none,
    );

void main() {
  late int captures;
  late List<String> opened;

  Future<void> pump(WidgetTester tester, List<Moment> moments) async {
    captures = 0;
    opened = [];
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MomentRail(
              groups: MomentGroup.of(moments),
              api: _Api(),
              serverNow: DateTime(2026, 10, 9, 13),
              onCapture: () => captures++,
              onOpen: (m) => opened.add(m.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a card reads who, how many, and how many are new', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, [
      _m('a3', 'Ada', 12),
      _m('a2', 'Ada', 10),
      _m('a1', 'Ada', 8, seen: true),
      _m('c1', 'Cem', 7, seen: true),
    ]);
    expect(find.bySemanticsLabel('Ada, 3 highlights, 2 new'), findsOneWidget);
    // All seen: no "new" clause.
    expect(find.bySemanticsLabel('Cem, 1 highlight'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a tap opens the first unseen item', (tester) async {
    await pump(tester, [
      _m('a2', 'Ada', 10),
      _m('a1', 'Ada', 8, seen: true),
    ]);
    await tester.tap(find.bySemanticsLabel('Ada, 2 highlights, 1 new'));
    await tester.pumpAndSettle();
    expect(opened, ['a2']);
  });

  testWidgets('with nothing of yours up, the capture tile leads', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, [_m('a1', 'Ada', 8)]);
    expect(find.bySemanticsLabel('Capture'), findsOneWidget);
    expect(find.bySemanticsLabel('Add a highlight'), findsNothing);
    handle.dispose();
  });

  testWidgets('your card replaces it, and its + adds another', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, [
      _m('y1', 'Me', 6, mine: true),
      _m('y2', 'Me', 9, mine: true),
      _m('a1', 'Ada', 8),
    ]);
    expect(find.bySemanticsLabel('Capture'), findsNothing);
    expect(find.bySemanticsLabel('You, 2 highlights'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Add a highlight'));
    await tester.pumpAndSettle();
    expect(captures, 1);
    expect(opened, isEmpty, reason: 'the + is not a tap on the card');
    handle.dispose();
  });

  testWidgets('the cards behind show what plays next, never a shimmer', (
    tester,
  ) async {
    await pump(tester, [
      _m('a4', 'Ada', 13, picture: true),
      _m('a3', 'Ada', 12, picture: true),
      _m('a2', 'Ada', 10, picture: true),
      _m('a1', 'Ada', 8, seen: true, picture: true),
    ]);
    final images = tester
        .widgetList<RemoteImage>(find.byType(RemoteImage))
        .toList();
    // The cover is a2 (the first unseen); behind it what plays next, a3
    // then a4. A deck is three cards in all, so a1 is the "+1".
    final behind = [
      for (final r in images)
        if (r.quiet) r.storageId,
    ];
    expect(behind..sort(), ['blob_a3', 'blob_a4']);
    expect(find.text('+1'), findsOneWidget);
    expect(
      images.where((r) => !r.quiet).map((r) => r.storageId),
      ['blob_a2'],
    );
  });

  testWidgets('three items fill the deck, with nothing to count', (
    tester,
  ) async {
    await pump(tester, [
      for (var i = 1; i <= 3; i++) _m('a$i', 'Ada', i, picture: true),
    ]);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('past the deck, the back card counts the rest', (tester) async {
    await pump(tester, [
      for (var i = 1; i <= 6; i++) _m('a$i', 'Ada', i, picture: true),
    ]);
    // Six items: the cover, two behind, and three the deck has no card for.
    expect(
      tester.widgetList<RemoteImage>(find.byType(RemoteImage)).where((r) => r.quiet),
      hasLength(2),
    );
    expect(find.text('+3'), findsOneWidget);
  });
}
