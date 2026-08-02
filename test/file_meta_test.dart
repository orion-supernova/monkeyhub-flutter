import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/file_meta.dart';

/// What this pins: a document is the one attachment whose identity is text.
/// Convex storage keeps no name, no type and no extension for a blob, so if
/// these three functions are wrong the file is not merely mislabelled — it is
/// unopenable, because every platform dispatches on the type we declare here.
///
/// The extension parser is the sharp edge. A name with no extension, a dotfile,
/// and a name whose last dot is inside a directory-ish suffix all have to come
/// back empty rather than producing a confident wrong answer: an
/// `application/octet-stream` prompts a download, while a wrong concrete type
/// hands the bytes to an app that cannot read them.
///
/// Sibling: `message_type_roundtrip_test.dart`, which pins the other half —
/// that the name survives the disk cache at all.
void main() {
  group('fileExtensionOf', () {
    test('reads the last extension, lowercased', () {
      expect(fileExtensionOf('report.PDF'), 'pdf');
      expect(fileExtensionOf('archive.tar.gz'), 'gz');
      expect(fileExtensionOf('a.b.c.docx'), 'docx');
    });

    test('is empty when there is nothing to read', () {
      expect(fileExtensionOf('README'), '', reason: 'no dot at all');
      expect(fileExtensionOf(''), '', reason: 'empty name');
      expect(
        fileExtensionOf('trailing.'),
        '',
        reason: 'a trailing dot names no type',
      );
    });

    test('a dotfile is a name, not a type', () {
      // `.gitignore` has no extension — the OS treats it as extensionless, and
      // reading one here produces a "GITIGNORE" badge on a file that has none.
      expect(fileExtensionOf('.gitignore'), '');
      expect(fileExtensionOf('.env'), '');
    });

    test('rejects a suffix that cannot be an extension', () {
      expect(
        fileExtensionOf('report v2. final'),
        '',
        reason: 'a space means this is prose, not a type',
      );
      expect(
        fileExtensionOf('some.dir/file'),
        '',
        reason: 'the last dot is above the filename',
      );
    });
  });

  group('mimeTypeForFileName', () {
    test('maps the formats a chat actually carries', () {
      expect(mimeTypeForFileName('q3.pdf'), 'application/pdf');
      expect(
        mimeTypeForFileName('notes.docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(
        mimeTypeForFileName('PHOTO.JPEG'),
        'image/jpeg',
        reason: 'case must not matter — Android hands back SHOUTED names',
      );
    });

    test('falls back rather than guessing', () {
      // The honest answer. Every platform reads octet-stream as "download it
      // and let the OS decide", which is right; a confident wrong type is not.
      expect(mimeTypeForFileName('design.sketch'), 'application/octet-stream');
      expect(mimeTypeForFileName('README'), 'application/octet-stream');
      expect(mimeTypeForFileName(''), 'application/octet-stream');
    });
  });

  group('fileTypeBadge', () {
    test('is the extension, upper-cased', () {
      expect(fileTypeBadge('q3.pdf'), 'PDF');
      expect(fileTypeBadge('notes.docx'), 'DOCX');
    });

    test('says FILE when there is no extension', () {
      expect(fileTypeBadge('README'), 'FILE');
      expect(fileTypeBadge('.gitignore'), 'FILE');
    });

    test('is capped so the badge cannot push the name off the row', () {
      expect(fileTypeBadge('theme.sketchpalette'), 'SKET');
      expect(fileTypeBadge('x.sketchpalette').length, lessThanOrEqualTo(4));
    });
  });

  group('formatFileSize', () {
    test('bytes are whole — "1.0 B" is nonsense', () {
      expect(formatFileSize(1), '1 B');
      expect(formatFileSize(842), '842 B');
    });

    test('is non-negative and never blank', () {
      expect(formatFileSize(0), '0 B');
      expect(
        formatFileSize(-5),
        '0 B',
        reason: 'a negative size is a bug upstream, not something to render',
      );
    });

    test('crosses to KB at exactly 1024, binary like every file browser', () {
      expect(formatFileSize(1023), '1023 B');
      expect(formatFileSize(1024), '1.0 KB');
      // Decimal units here would show 24.6 MB as 25.8 MB, so a file the user
      // just saw in Finder would appear to have grown in transit.
      expect(formatFileSize(1024 * 1024), '1.0 MB');
      expect(formatFileSize(1024 * 1024 * 1024), '1.0 GB');
    });

    test('keeps exactly one decimal above a kilobyte, so columns line up', () {
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(13 * 1024 * 1024 + 512 * 1024), '13.5 MB');
    });

    test('the send cap renders as something a user can act on', () {
      expect(formatFileSize(kMaxFileUploadBytes), '20.0 MB');
    });
  });
}
