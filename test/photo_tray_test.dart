import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/photo_tray_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/media_filmstrip.dart';

/// The review screen for a send of several photographs.
///
/// The gallery pick used to hand back exactly one picture, so sending four
/// meant four trips through the attachment sheet, the picker and the editor.
/// What this pins is the part of the fix that is easy to get subtly wrong: the
/// set the user assembled here has to reach the conversation intact, in order,
/// and a photo they took back has to actually be gone.
void main() {
  /// A real PNG, encoded in pure Dart. A `PictureRecorder` round-trip would
  /// hang the suite under the fake-async binding — see camera_editor_chrome_test.
  ///
  /// Deliberately tiny: inside `kSendPhotoMaxEdge`, so the send takes the
  /// pass-through branch and the test does not pay for a full re-encode.
  Uint8List png(int shade) {
    final bitmap = img.Image(width: 8, height: 8);
    img.fill(bitmap, color: img.ColorRgb8(shade, shade, shade));
    return img.encodePng(bitmap);
  }

  /// The scope sits above the app exactly as `MonkeyHubApp` builds it — the
  /// editor route the tray pushes is not under `home`.
  Widget host(List<Uint8List> photos, void Function(PhotoTraySend?) onDone) =>
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => onDone(
                    await PhotoTrayScreen.open(context, photos: photos),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

  /// Opens the tray and lands on it.
  ///
  /// Bounded pumps rather than `pumpAndSettle`: an undecoded `Image.memory`
  /// plus the rail's own 150ms selection tween is a settle loop that can
  /// outlive the route transition it is meant to be waiting on.
  /// The dismiss badges on the rail — NOT the discard X in the top bar, which
  /// is the same glyph and would otherwise be tapped by `.first`.
  Finder badges() => find.descendant(
    of: find.byType(MediaFilmstrip),
    matching: find.byIcon(CupertinoIcons.xmark),
  );

  Future<void> openTray(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('shows every chosen photo on the rail, and says how many', (
    tester,
  ) async {
    await tester.pumpWidget(host([png(10), png(80), png(200)], (_) {}));
    await openTray(tester);

    expect(find.byType(MediaFilmstrip), findsOneWidget);
    // One preview page plus three rail tiles. The backdrop is a fifth Image
    // and is deliberately not one of them — it is the blurred copy of the
    // current picture that fills what a `contain` fit leaves over, so it is
    // excluded by key rather than being allowed to inflate the count.
    expect(
      find.byType(Image).evaluate().length -
          find.byKey(photoTrayBackdropImageKey).evaluate().length,
      4,
    );
    expect(find.byKey(photoTrayBackdropImageKey), findsOneWidget);
    expect(find.text('3 photos'), findsOneWidget);
  });

  testWidgets('the stage sits on a blurred copy of its own photo, not black', (
    tester,
  ) async {
    // A screenshot is the exact shape of the phone it is being sent from, and
    // the stage is a band ~200pt shorter than the screen — so `contain` scales
    // it down and leaves a gutter down both sides. The gutter is unavoidable
    // (the whole frame has to stay visible before a send); reading as dead
    // black is not.
    await tester.pumpWidget(host([png(10), png(80)], (_) {}));
    await openTray(tester);

    expect(find.byKey(photoTrayBackdropImageKey), findsOneWidget);
    final backdrop = tester.widget<Image>(
      find.byKey(photoTrayBackdropImageKey),
    );
    expect(backdrop.fit, BoxFit.cover, reason: 'a backdrop must fill');
  });

  testWidgets('taking one back removes it and updates the count', (
    tester,
  ) async {
    await tester.pumpWidget(host([png(10), png(80), png(200)], (_) {}));
    await openTray(tester);

    expect(badges(), findsNWidgets(3));

    await tester.tap(badges().at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('2 photos'), findsOneWidget);
    expect(badges(), findsNWidgets(2));
  });

  testWidgets('taking the last one back leaves the screen', (tester) async {
    // An empty tray is a screen with nothing on it and a dead SEND button.
    PhotoTraySend? sent;
    var returned = false;
    await tester.pumpWidget(
      host([png(10)], (r) {
        sent = r;
        returned = true;
      }),
    );
    await openTray(tester);

    await tester.tap(badges().first);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(returned, isTrue);
    expect(sent, isNull, reason: 'backing out is not a send');
  });

  testWidgets('SEND hands back every photo, in the order on the rail', (
    tester,
  ) async {
    final photos = [png(10), png(80), png(200)];
    PhotoTraySend? sent;
    await tester.pumpWidget(host(photos, (r) => sent = r));
    await openTray(tester);

    await tester.tap(find.text('Send'));
    // The export reads each photo's header, which is a real image codec — work
    // the fake-async zone never advances on its own. `runAsync` and `pump` have
    // to be interleaved, and kept separate: a pump inside runAsync deadlocks.
    for (var i = 0; i < 40 && sent == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(sent, isNotNull);
    expect(sent!.images.length, 3);
    expect(sent!.dropped, 0);
    expect(sent!.viewOnce, isFalse);
    // Identity, in order. A photo inside the cap goes out as the bytes we were
    // given rather than a re-encode of them, so this pins the ORDER and the
    // pass-through at once — and order is the part a `Future.wait` would lose.
    for (var i = 0; i < photos.length; i++) {
      expect(identical(sent!.images[i].bytes, photos[i]), isTrue, reason: 'photo $i');
    }
  });

  testWidgets('view-once arms the whole send, not one picture', (tester) async {
    PhotoTraySend? sent;
    await tester.pumpWidget(host([png(10), png(80)], (r) => sent = r));
    await openTray(tester);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    for (var i = 0; i < 40 && sent == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(sent!.viewOnce, isTrue);
    expect(sent!.images.length, 2);
  });

  testWidgets('offers a way back to the picker below the cap', (tester) async {
    await tester.pumpWidget(host([png(10), png(80)], (_) {}));
    await openTray(tester);
    expect(find.byIcon(CupertinoIcons.plus), findsOneWidget);
  });

  testWidgets('withdraws it at the cap', (tester) async {
    // A separate test rather than a second `pumpWidget` in the one above: the
    // navigator survives a root swap, so the first tray would still be on top
    // and the button that opens the second one unreachable.
    await tester.pumpWidget(
      host([for (var i = 0; i < kMaxPhotoSelection; i++) png(i * 20)], (_) {}),
    );
    await openTray(tester);
    expect(
      find.byIcon(CupertinoIcons.plus),
      findsNothing,
      reason: 'a + that can only refuse is worse than no +',
    );
  });
}
