import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/drop/drop_classifier.dart';
import 'package:monkeyhub/drop/drop_item.dart';
import 'package:monkeyhub/media/file_meta.dart';
import 'package:monkeyhub/models/enums.dart';

/// What this pins: the answer the verdict chip gives BEFORE anything is let go.
///
/// The classifier is the only part of drag-and-drop with a right answer that
/// can be written down. Everything else is a painter or a platform channel;
/// this is a table, and tables drift — the failure mode is silent and lands on
/// the recipient rather than the sender: a `.mkv` claimed as a video plays as
/// a black rectangle in somebody else's transcript, forever, and nothing
/// upstream of them ever knew.
DropCandidate file(String name, {int? size = 1024, String? mime}) =>
    DropCandidate(name: name, size: size, mimeType: mime);

void main() {
  group('what a dragged file becomes', () {
    test('formats every client can draw are pictures', () {
      for (final name in ['a.png', 'b.JPG', 'c.jpeg', 'd.gif', 'e.webp', 'f.bmp']) {
        final a = assess(file(name));
        expect(a.kind, DropKind.photo, reason: name);
        expect(a.messageType, MessageType.image, reason: name);
        expect(a.downgraded, isFalse, reason: name);
        expect(a.fragile, isFalse, reason: name);
      }
    });

    test('HEIC sends as a picture, and says it may not render everywhere', () {
      // The case that decides the whole "fragile" tier. A Mac hands over HEIC
      // whenever a photo is dragged out of Photos; Apple platforms and Android
      // draw it, no browser does. Downgrading it to a document would be the
      // wrong trade for the common case (Mac → phone), so it goes as a picture
      // with a caveat rather than as a file without one.
      final a = assess(file('IMG_4821.HEIC'));
      expect(a.kind, DropKind.photo);
      expect(a.fragile, isTrue);
      expect(a.downgraded, isFalse);
    });

    test('image-shaped formats nothing can draw go as documents, marked', () {
      for (final name in ['art.psd', 'logo.svg', 'shot.cr2', 'icon.ico']) {
        final a = assess(file(name));
        expect(a.kind, DropKind.document, reason: name);
        expect(a.messageType, MessageType.file, reason: name);
        expect(a.downgraded, isTrue, reason: name);
      }
    });

    test('playable containers are videos, the rest are marked documents', () {
      for (final name in ['clip.mp4', 'clip.mov', 'clip.webm', 'clip.m4v']) {
        expect(assess(file(name)).kind, DropKind.video, reason: name);
        expect(assess(file(name)).downgraded, isFalse, reason: name);
      }
      for (final name in ['clip.mkv', 'clip.avi', 'clip.wmv', 'clip.mpg']) {
        final a = assess(file(name));
        expect(a.kind, DropKind.document, reason: name);
        expect(a.downgraded, isTrue, reason: name);
      }
    });

    test('audio splits three ways', () {
      expect(assess(file('song.mp3')).kind, DropKind.audio);
      expect(assess(file('song.mp3')).fragile, isFalse);
      // Plays everywhere except Safari, which on the web build is a real
      // share of the audience.
      expect(assess(file('song.flac')).fragile, isTrue);
      expect(assess(file('song.flac')).kind, DropKind.audio);
      expect(assess(file('voice.wma')).kind, DropKind.document);
      expect(assess(file('voice.wma')).downgraded, isTrue);
    });

    test('an ordinary document is accepted without a caution', () {
      final a = assess(file('Q3.pdf'));
      expect(a.kind, DropKind.document);
      expect(a.downgraded, isFalse);
      expect(a.fragile, isFalse);
      expect(a.accepted, isTrue);
    });
  });

  group('what the platform did not say', () {
    test('a browser hover has no name, so the MIME type decides', () {
      // Every candidate in a web drag looks like this: a type and nothing
      // else. See DropChannel (web) for why.
      expect(
        assess(const DropCandidate(mimeType: 'image/png')).kind,
        DropKind.photo,
      );
      expect(
        assess(const DropCandidate(mimeType: 'video/mp4')).kind,
        DropKind.video,
      );
      expect(
        assess(const DropCandidate(mimeType: 'application/pdf')).kind,
        DropKind.document,
      );
    });

    test('no name and no type is unknown, not a document', () {
      // The distinction the ghost card reads: "file" is a claim, "we do not
      // know yet" is the truth during a browser hover.
      expect(assess(const DropCandidate()).kind, DropKind.unknown);
      expect(assess(const DropCandidate()).messageType, MessageType.file);
    });

    test('an unmeasured file is never pre-refused on size', () {
      // A browser withholds the byte count until the drop. Inventing a
      // refusal for something we have not measured would refuse half of every
      // web drag on a guess.
      expect(assess(const DropCandidate(mimeType: 'image/png')).accepted, isTrue);
    });

    test('a name beats a declared type', () {
      // macOS reports `public.data` and browsers report
      // `application/octet-stream` for plenty of files they have no
      // registration for. Neither beats `.mkv` on the end of the name.
      final a = assess(file('movie.mkv', mime: 'application/octet-stream'));
      expect(a.kind, DropKind.document);
      expect(a.downgraded, isTrue);
    });
  });

  group('refusals', () {
    test('a folder is named, not silently dropped', () {
      final a = assess(const DropCandidate(name: 'Exports', isDirectory: true));
      expect(a.refusal, DropRefusal.folder);
      expect(a.messageType, isNull);
    });

    test('over the cap is refused with the cap as the reason', () {
      final a = assess(file('huge.mov', size: kMaxMediaIntakeBytes + 1));
      expect(a.refusal, DropRefusal.tooLarge);
      expect(
        assess(file('fine.mov', size: kMaxMediaIntakeBytes)).accepted,
        isTrue,
      );
    });

    test('a big video is taken in to be compressed, a big document is not', () {
      // A photo or video is compressed to the upload cap on the way out, so
      // its intake cap is the larger one. A document goes as it is.
      expect(
        assess(file('trip.mov', size: kMaxFileUploadBytes * 3)).accepted,
        isTrue,
      );
      expect(
        assess(file('scan.pdf', size: kMaxFileUploadBytes + 1)).refusal,
        DropRefusal.tooLarge,
      );
    });

    test('an empty file is refused rather than sent as a bubble of nothing', () {
      expect(assess(file('empty.txt', size: 0)).refusal, DropRefusal.empty);
    });

    test('the guardian policy refuses before the file lands', () {
      final a = assess(
        file('photo.png'),
        policy: const DropPolicy(allowFiles: false),
      );
      expect(a.refusal, DropRefusal.notPermitted);
      // The KIND survives the refusal: the card still draws a picture glyph,
      // because what it is is not in question — only whether it may be sent.
      expect(a.kind, DropKind.photo);
    });
  });

  group('the upload content type', () {
    test('comes from the name, as every other send path does', () {
      expect(assess(file('a.pdf')).uploadContentType, 'application/pdf');
      expect(assess(file('a.png')).uploadContentType, 'image/png');
    });

    test('falls back to what the platform sniffed for an unknown extension', () {
      // macOS derives its type from the file's UTI, which is content-sniffed
      // and strictly better than `application/octet-stream`.
      expect(
        assess(file('notes.pages', mime: 'application/x-iwork-pages-sffpages'))
            .uploadContentType,
        'application/x-iwork-pages-sffpages',
      );
    });

    test('never invents a type it has no reason to believe', () {
      expect(
        assess(file('mystery.qqq')).uploadContentType,
        'application/octet-stream',
      );
    });
  });

  group('the plan over a whole drag', () {
    DropPlan planOf(List<DropCandidate> items, {DropPolicy? policy}) => planFor(
          DropSnapshot(items: items, namesKnown: true, sizesKnown: true),
          policy: policy ?? DropPolicy.permissive,
        );

    test('an all-pictures drag routes to the editor or the tray', () {
      expect(planOf([file('a.png')]).isPhotoOnly, isTrue);
      expect(planOf([file('a.png'), file('b.jpg')]).isPhotoOnly, isTrue);
      expect(planOf([file('a.png'), file('c.pdf')]).isPhotoOnly, isFalse);
    });

    test('a refusal beside something sendable is a caution, not a refusal', () {
      final plan = planOf([
        file('a.png'),
        const DropCandidate(name: 'Exports', isDirectory: true),
      ]);
      expect(plan.sendsAnything, isTrue);
      expect(plan.tone, DropTone.caution);
      expect(plan.photoCount, 1);
    });

    test('nothing sendable is a refusal', () {
      final plan = planOf([
        const DropCandidate(name: 'Exports', isDirectory: true),
        const DropCandidate(name: 'More', isDirectory: true),
      ]);
      expect(plan.sendsAnything, isFalse);
      expect(plan.tone, DropTone.refuse);
      expect(plan.soleRefusal, DropRefusal.folder);
    });

    test('a downgrade alone is enough to earn a caution', () {
      final plan = planOf([file('clip.mkv')]);
      expect(plan.tone, DropTone.caution);
      expect(plan.downgradedCount, 1);
    });

    test('a clean drag is accepted outright', () {
      expect(planOf([file('a.png'), file('b.pdf')]).tone, DropTone.accept);
    });

    test('text still counts as something to do', () {
      const snapshot = DropSnapshot(carriesText: true);
      final plan = planFor(snapshot);
      expect(plan.sendsAnything, isTrue);
      expect(plan.tone, DropTone.accept);
      expect(plan.accepted, isEmpty);
    });

    test('a policy that forbids text drops it from the plan', () {
      final plan = planFor(
        const DropSnapshot(carriesText: true),
        policy: const DropPolicy(allowText: false),
      );
      expect(plan.hasText, isFalse);
      expect(plan.sendsAnything, isFalse);
    });

    test('mixed refusals report no sole reason', () {
      final plan = planOf([
        const DropCandidate(name: 'Exports', isDirectory: true),
        file('huge.mov', size: kMaxMediaIntakeBytes + 1),
      ]);
      expect(plan.soleRefusal, isNull);
    });
  });

  group('the batch budget', () {
    DropPlan planOf(List<DropCandidate> items) => planFor(
          DropSnapshot(items: items, namesKnown: true, sizesKnown: true),
        );

    test('a folder full of files is trimmed from the end, not refused', () {
      // The canonical drag: select everything in a Finder window and pull it
      // over. The first twenty go; the rest are named rather than silently
      // dropped or turned into twenty more failed bubbles.
      final plan = planOf([
        for (var i = 0; i < kMaxDropItems + 5; i++) file('f$i.png', size: 1024),
      ]);
      expect(plan.accepted.length, kMaxDropItems);
      expect(plan.refused.length, 5);
      expect(plan.soleRefusal, DropRefusal.batchFull);
      // In drag order: the user arranged the selection, so the ones they were
      // thinking about are at the front.
      expect(plan.accepted.first.candidate.name, 'f0.png');
      expect(plan.items.last.refusal, DropRefusal.batchFull);
    });

    test('the byte budget keeps a drop out of the repository dead end', () {
      // `ChatRepository._maxRetainedUploadBytes` refuses an overflowing send
      // with a bubble that cannot be retried. Refusing here instead names the
      // files while the pointer is still holding them.
      final plan = planOf([
        file('a.mov', size: kMaxFileUploadBytes),
        file('b.mov', size: kMaxFileUploadBytes),
        file('c.mov', size: kMaxFileUploadBytes),
      ]);
      expect(plan.accepted.length, 2);
      expect(plan.items.last.refusal, DropRefusal.batchFull);
    });

    test('a big video spends what it will be compressed to, not its size', () {
      // 100 MB on disk, at most the upload cap once compressed: two of them
      // fit the batch the way two clips at the cap do.
      final plan = planOf([
        file('a.mov', size: kMaxFileUploadBytes * 5),
        file('b.mov', size: kMaxFileUploadBytes * 5),
        file('c.mov', size: kMaxFileUploadBytes * 5),
      ]);
      expect(plan.accepted.length, 2);
      expect(plan.items.last.refusal, DropRefusal.batchFull);
    });

    test('once the budget is gone a later small file does not sneak in', () {
      final plan = planOf([
        file('big1.mov', size: kMaxFileUploadBytes),
        file('big2.mov', size: kMaxFileUploadBytes),
        file('tiny.txt', size: 12),
      ]);
      expect(plan.accepted.length, 2);
      expect(plan.items.last.refusal, DropRefusal.batchFull);
    });

    test('items refused on their own account spend no budget', () {
      // A folder and an oversize video are not going anywhere; counting them
      // would shrink the send for nothing.
      final plan = planOf([
        const DropCandidate(name: 'Exports', isDirectory: true),
        file('huge.mov', size: kMaxMediaIntakeBytes + 1),
        for (var i = 0; i < kMaxDropItems; i++) file('f$i.png', size: 1024),
      ]);
      expect(plan.accepted.length, kMaxDropItems);
      expect(
        plan.refused.map((r) => r.refusal),
        isNot(contains(DropRefusal.batchFull)),
      );
    });

    test('an unmeasured file spends no bytes, only a slot', () {
      // The browser hover, where sizes do not exist yet. The count cap is all
      // that can apply, and it does.
      final plan = planFor(DropSnapshot(
        items: [
          for (var i = 0; i < kMaxDropItems + 2; i++)
            const DropCandidate(mimeType: 'image/png'),
        ],
      ));
      expect(plan.accepted.length, kMaxDropItems);
    });

    test('an ordinary drop is untouched by any of this', () {
      final plan = planOf([file('a.png'), file('b.pdf')]);
      expect(plan.accepted.length, 2);
      expect(plan.tone, DropTone.accept);
    });
  });

  group('a bundle re-planned after it lands', () {
    test('carries the names and sizes the hover did not have', () {
      // The web case. The chip said "3 files"; the bundle is the first moment
      // anything better exists, and the post-drop notice is built from this.
      const bundle = DropBundle(files: [
        DroppedFile(name: 'clip.mkv', mimeType: 'video/x-matroska', size: 900),
      ]);
      final plan = planFor(bundle.toSnapshot());
      expect(plan.namesKnown, isTrue);
      expect(plan.sizesKnown, isTrue);
      expect(plan.downgradedCount, 1);
    });
  });
}
