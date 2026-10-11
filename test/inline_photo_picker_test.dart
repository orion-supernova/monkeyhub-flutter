@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/image_raster.dart' show CroppedImage;
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/widgets/inline_photo_picker.dart';
import 'package:monkeyhub/widgets/send_button.dart';
import 'package:photo_manager/photo_manager.dart';

/// The inline picker's state and the composer's side of it: picks are kept
/// in the order they will be sent, renumber when one is taken back, stop at
/// the album cap, and make the composer sendable on their own.
void main() {
  AssetEntity asset(String id) =>
      AssetEntity(id: id, typeInt: 1, width: 100, height: 100);

  // A 1x1 PNG, so a tile has a picture without the photo library plugin.
  final png = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
    0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
    0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: child)),
        ),
      );

  /// A room [height] tall, the picker over it resting 300 high with a 34pt
  /// home indicator below.
  Widget room(InlinePickerController c, double height) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              child: Stack(children: [
                Positioned.fill(
                  child: InlinePhotoPicker(
                    controller: c,
                    height: 300,
                    bottomPadding: 34,
                  ),
                ),
              ]),
            ),
          ),
        ),
      );

  group('picks', () {
    test('kept in pick order, renumbered when one is taken back', () {
      final c = InlinePickerController();
      final a = asset('a'), b = asset('b'), d = asset('d');
      c.toggle(a);
      c.toggle(b);
      c.toggle(d);
      expect([c.orderOf(a), c.orderOf(b), c.orderOf(d)], [1, 2, 3]);
      c.toggle(b);
      expect([c.orderOf(a), c.orderOf(b), c.orderOf(d)], [1, 0, 2]);
    });

    test('stop at the cap, and take() hands them over', () {
      final c = InlinePickerController(max: 2);
      expect(c.toggle(asset('a')), isTrue);
      expect(c.toggle(asset('b')), isTrue);
      expect(c.toggle(asset('c')), isFalse);
      final taken = c.take();
      expect(taken.map((p) => p.asset.id), ['a', 'b']);
      expect(c.hasPicks, isFalse);
    });
  });

  testWidgets('the strip shows the picks and removes one', (tester) async {
    final c = InlinePickerController();
    final image = CroppedImage(
        bytes: png, contentType: 'image/png', width: 1, height: 1);
    for (final id in ['a', 'b']) {
      c.toggle(asset(id));
    }
    for (final p in c.picks) {
      c.markEdited(p, image);
    }
    final edited = <String>[];
    await tester.pumpWidget(host(PickedMediaStrip(
      controller: c,
      onEdit: (p) => edited.add(p.asset.id),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
    await tester.tap(find.byType(Image).first);
    expect(edited, ['a']);
    await tester.tap(find.byIcon(CupertinoIcons.xmark).first);
    await tester.pumpAndSettle();
    expect(c.picks.map((p) => p.asset.id), ['b']);
  });

  group('the sheet', () {
    // A 400x800 room. Without the photo library plugin the picker shows its
    // "access is off" note, which is enough to see the sheet move.
    Future<InlinePickerController> open(WidgetTester tester,
        {double roomHeight = 800}) async {
      final c = InlinePickerController()..open();
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(room(c, roomHeight));
      await tester.pumpAndSettle();
      return c;
    }

    double sheetTop(WidgetTester tester) =>
        tester.getTopLeft(find.bySemanticsLabel('Recent photos')).dy;

    testWidgets('rests in the keyboard\'s place', (tester) async {
      final c = await open(tester);
      expect(sheetTop(tester), moreOrLessEquals(800 - 300 - 34));
      expect(c.isExpanded, isFalse);
    });

    testWidgets('pulls up to fill the room, and back down', (tester) async {
      final c = await open(tester);
      await tester.drag(find.bySemanticsLabel('Recent photos'),
          const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(c.isExpanded, isTrue);
      expect(sheetTop(tester), moreOrLessEquals(0));
      expect(find.text('Recents'), findsOneWidget);

      await tester.tap(find.byIcon(CupertinoIcons.chevron_down));
      await tester.pumpAndSettle();
      expect(c.isExpanded, isFalse);
      expect(sheetTop(tester), moreOrLessEquals(800 - 300 - 34));
    });

    testWidgets('a short drag falls back to rest', (tester) async {
      final c = await open(tester);
      await tester.timedDrag(find.bySemanticsLabel('Recent photos'),
          const Offset(0, -80), const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(c.isExpanded, isFalse);
      expect(sheetTop(tester), moreOrLessEquals(800 - 300 - 34));
    });

    testWidgets('a flick up opens it, expand() and collapse() drive it',
        (tester) async {
      final c = await open(tester);
      await tester.fling(find.bySemanticsLabel('Recent photos'),
          const Offset(0, -60), 1500);
      await tester.pumpAndSettle();
      expect(c.isExpanded, isTrue);
      c.collapse();
      await tester.pumpAndSettle();
      expect(c.isExpanded, isFalse);
      c.expand();
      await tester.pumpAndSettle();
      expect(c.isExpanded, isTrue);
    });

    testWidgets('picks show in the full bar, and Add brings it down',
        (tester) async {
      final c = await open(tester);
      c.toggle(asset('a'));
      c.toggle(asset('b'));
      c.expand();
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.text('Add (2)'));
      await tester.pumpAndSettle();
      expect(c.isExpanded, isFalse);
      expect(c.picks.length, 2);
    });

    testWidgets('stays at rest when the room changes height under it',
        (tester) async {
      final c = await open(tester, roomHeight: 700);
      // Moved once, so the sheet no longer follows its initial size itself.
      c.expand();
      await tester.pumpAndSettle();
      c.collapse();
      await tester.pumpAndSettle();
      await tester.pumpWidget(room(c, 800));
      await tester.pumpAndSettle();
      expect(sheetTop(tester), moreOrLessEquals(800 - 300 - 34));
      await tester.pumpWidget(room(c, 600));
      await tester.pumpAndSettle();
      expect(sheetTop(tester), moreOrLessEquals(600 - 300 - 34));
    });
  });

  for (final liquid in [false, true]) {
    testWidgets('picks alone make the ${liquid ? 'liquid' : 'classic'} '
        'composer sendable', (tester) async {
      var sent = 0;
      Widget composer(bool picks) => liquid
          ? ChatComposerLiquid(
              controller: TextEditingController(),
              ephemeral: false,
              onSend: () => sent++,
              onAttach: () {},
              hasAttachments: picks,
            )
          : ChatComposerClassic(
              controller: TextEditingController(),
              ephemeral: false,
              onSend: () => sent++,
              onAttach: () {},
              hasAttachments: picks,
            );
      await tester.pumpWidget(host(composer(false)));
      await tester.pumpAndSettle();
      expect(find.byType(SendButton), findsNothing);
      await tester.pumpWidget(host(composer(true)));
      await tester.pumpAndSettle();
      expect(find.byType(SendButton), findsOneWidget);
      await tester.tap(find.byType(SendButton));
      await tester.pump();
      expect(sent, 1);
    });
  }
}
