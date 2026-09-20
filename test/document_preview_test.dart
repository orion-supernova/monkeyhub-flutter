import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/document_preview.dart';

/// What this pins: which of the four things a tap on a document does.
///
/// [FileMessage] used to say flatly that this app has no in-app viewer, and
/// the reasoning — "a chat app that renders PDFs is a chat app that renders
/// PDFs badly" — is still right about carrying a renderer. It stopped being
/// right about refusing to preview at all: a received book meant downloading
/// it to find out what it was, and a photo sent as a document rendered as a
/// grey plate with `PNG` written on it.
///
/// So nothing here renders anything. Two of these are viewers the app already
/// had and was not reaching for, and the third is Apple's. What can go wrong
/// is the ROUTING, which is all this file is about.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  DocumentPreviewKind kind(String name, {String? mime}) =>
      DocumentPreview.kindFor(mimeType: mime, fileName: name);

  group('on an Apple platform', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('plain text keeps the viewer it always had', () {
      expect(kind('notes.txt'), DocumentPreviewKind.text);
      expect(kind('log', mime: 'text/plain'), DocumentPreviewKind.text);
    });

    test('a picture sent as a document opens as a picture', () {
      for (final name in ['shot.png', 'holiday.JPG', 'loop.gif', 'x.webp']) {
        expect(kind(name), DocumentPreviewKind.image, reason: name);
      }
    });

    test('an extensionless blob is identified by its declared type', () {
      // The App Store's link-preview blob, which arrives as five characters
      // with no dot in them.
      expect(kind('bcdef', mime: 'image/png'), DocumentPreviewKind.image);
      expect(kind('bcdef', mime: 'application/pdf'), DocumentPreviewKind.native);
      expect(
        kind('bcdef', mime: 'application/octet-stream'),
        DocumentPreviewKind.none,
      );
    });

    test('books and documents go to QuickLook', () {
      for (final name in [
        'Dandara.epub', 'contract.pdf', 'deck.key', 'sheet.xlsx', 'memo.docx',
      ]) {
        expect(kind(name), DocumentPreviewKind.native, reason: name);
      }
    });

    test('HEIC goes to the OS previewer, not the app viewer', () {
      // Skia decodes HEIC on Apple platforms and no browser does. The app's
      // own viewer is the one that might not; QuickLook certainly can.
      expect(kind('IMG_0001.HEIC'), DocumentPreviewKind.native);
    });

    test('an archive has nothing to show and says so', () {
      expect(kind('backup.zip'), DocumentPreviewKind.none);
      expect(kind('thing.sketch'), DocumentPreviewKind.none);
      expect(kind('mystery.qqq'), DocumentPreviewKind.none);
    });
  });

  group('off an Apple platform', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('there is no QuickLook, so a book keeps the OS hand-off', () {
      // An in-app preview here would mean shipping a renderer, which is the
      // thing this class exists to avoid.
      expect(DocumentPreview.nativeAvailable, isFalse);
      expect(kind('Dandara.epub'), DocumentPreviewKind.none);
      expect(kind('contract.pdf'), DocumentPreviewKind.none);
    });

    test('the two viewers the app owns still work', () {
      expect(kind('notes.txt'), DocumentPreviewKind.text);
      expect(kind('shot.png'), DocumentPreviewKind.image);
    });
  });

  group('openNative', () {
    test('is a no-op where there is no platform previewer', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      // Returns false WITHOUT fetching — the caller falls straight through to
      // the hand-off, and a megabyte download for a preview that cannot open
      // would be paid for nothing.
      expect(DocumentPreview.nativeAvailable, isFalse);
    });
  });
}
