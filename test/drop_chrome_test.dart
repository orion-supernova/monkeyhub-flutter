@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/drop/drop_controller.dart';
import 'package:monkeyhub/drop/drop_item.dart';
import 'package:monkeyhub/drop/drop_zone.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/drop/drop_cards.dart';
import 'package:monkeyhub/widgets/drop/drop_chrome.dart';

/// What this pins: that the overlay says the right thing, and that it is
/// genuinely absent when nothing is being dragged.
///
/// The painters themselves are not worth asserting on — a `CustomPainter` has
/// no testable output short of a golden, and goldens on thirteen themes are a
/// maintenance bill this app has deliberately not taken on. What IS worth
/// pinning is the wiring: a drag over a zone has to produce that zone's
/// sentence, a drag over nothing has to produce the hint, and an idle window
/// has to produce nothing at all, because this widget sits over every route in
/// the app and a leak here is a permanent film over the whole product.
void main() {
  late AppLocalizations l10n;
  final drop = DropController.instance;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  tearDown(() => drop.debugLeave());

  /// [calm] goes through `MediaQuery.disableAnimations` rather than through
  /// `SettingsStore`, which is where the app's own override lives: the store
  /// writes to the secure keychain, which has no implementation under
  /// `flutter test`, and the OS flag is the other half of the same `or` that
  /// `MotionScope` resolves.
  Widget host({
    bool withZone = true,
    bool calm = false,
    List<DropBundle> drops = const [],
  }) =>
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: calm),
            child: ThemeScope(
              controller: ThemeController(BasicTheme.midnight()),
              child: Scaffold(
                body: Stack(
                  children: [
                    if (withZone)
                      DropZone(
                        label: 'Alice',
                        onDrop: (bundle) async => drops.add(bundle),
                        child: const SizedBox.expand(),
                      )
                    else
                      const SizedBox.expand(),
                    const DropChrome(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  const photos = DropSnapshot(
    items: [
      DropCandidate(name: 'sunrise.png', size: 2048),
      DropCandidate(name: 'sunset.png', size: 4096),
    ],
    namesKnown: true,
    sizesKnown: true,
  );

  testWidgets('draws nothing at all while nothing is being dragged',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.byType(DropCard), findsNothing);
    expect(find.text(l10n.dropSendPhotos(2)), findsNothing);
  });

  testWidgets('names what will happen, and to whom', (tester) async {
    await tester.pumpWidget(host());
    drop.debugEnter(photos, const Offset(120, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text(l10n.dropSendPhotos(2)), findsOneWidget);
    expect(find.text(l10n.dropTargetTo('Alice')), findsOneWidget);
  });

  testWidgets('shows a card per file, with the names the platform gave',
      (tester) async {
    await tester.pumpWidget(host());
    drop.debugEnter(photos, const Offset(120, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.byType(DropCard), findsNWidgets(2));
    expect(find.text('sunrise.png'), findsOneWidget);
    expect(find.text('sunset.png'), findsOneWidget);
    // The size is the second line, straight off the Finder row the user was
    // just looking at.
    expect(find.text('2.0 KB'), findsOneWidget);
  });

  testWidgets('over nothing, says where to aim instead', (tester) async {
    await tester.pumpWidget(host(withZone: false));
    drop.debugEnter(photos, const Offset(120, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text(l10n.dropHintNoTarget), findsOneWidget);
    expect(find.text(l10n.dropSendPhotos(2)), findsNothing);
  });

  testWidgets('a browser drag counts kinds rather than inventing names',
      (tester) async {
    // The whole web hover: MIME types and a count, no names and no sizes.
    await tester.pumpWidget(host());
    drop.debugEnter(
      const DropSnapshot(
        items: [DropCandidate(mimeType: 'image/png')],
        namesKnown: false,
        sizesKnown: false,
      ),
      const Offset(120, 200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text(l10n.dropSendPhotos(1)), findsOneWidget);
    expect(find.text(l10n.dropKindPhoto), findsWidgets);
  });

  testWidgets('a caution outranks the target name on the one spare line',
      (tester) async {
    await tester.pumpWidget(host());
    drop.debugEnter(
      const DropSnapshot(
        items: [DropCandidate(name: 'clip.mkv', size: 2048)],
        namesKnown: true,
        sizesKnown: true,
      ),
      const Offset(120, 200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text(l10n.dropNoticeAsFile(1)), findsOneWidget);
    expect(find.text(l10n.dropTargetTo('Alice')), findsNothing);
  });

  testWidgets('leaving the window takes the whole overlay away',
      (tester) async {
    await tester.pumpWidget(host());
    drop.debugEnter(photos, const Offset(120, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byType(DropCard), findsNWidgets(2));

    drop.debugLeave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DropCard), findsNothing);
  });

  testWidgets('a drop hands the bundle to the zone under it', (tester) async {
    final delivered = <DropBundle>[];
    await tester.pumpWidget(host(drops: delivered));
    drop.debugEnter(photos, const Offset(120, 200));
    await tester.pump();

    const bundle = DropBundle(files: [
      DroppedFile(
        name: 'sunrise.png',
        mimeType: 'image/png',
        size: 2048,
        path: '/tmp/sunrise.png',
      ),
    ]);
    await drop.debugPerform(bundle, const Offset(120, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(delivered.single, same(bundle));
    expect(find.byType(DropCard), findsNothing);
  });

  testWidgets('calm motion still identifies the target', (tester) async {
    // Reduce Motion drops the trail, the fan and the landing burst — all
    // decoration. What it must not drop is the ANSWER, which is the only
    // thing on screen telling the user where the file is about to go.
    await tester.pumpWidget(host(calm: true));
    drop.debugEnter(photos, const Offset(120, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text(l10n.dropSendPhotos(2)), findsOneWidget);
    expect(find.byType(DropCard), findsNWidgets(2));
  });
}
