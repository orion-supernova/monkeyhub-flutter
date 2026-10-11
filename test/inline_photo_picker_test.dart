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
