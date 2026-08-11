import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/mention.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/services/link_preview_service.dart';
import 'package:monkeyhub/widgets/text_runs.dart';

/// The bubble's historical URL-strip, copied VERBATIM from
/// `_LinkAwareBubble._stripUrls` before `DisplayTransform` replaced it. This
/// is the reference implementation the transform must agree with character
/// for character — every text bubble ever sent renders through this path.
String legacyStripUrls(String text) {
  final matches = UrlDetector.matches(text);
  if (matches.isEmpty) return text;
  final buf = StringBuffer();
  var cursor = 0;
  for (final m in matches) {
    if (m.start > cursor) buf.write(text.substring(cursor, m.start));
    cursor = m.end;
  }
  if (cursor < text.length) buf.write(text.substring(cursor));
  return buf
      .toString()
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .trim();
}

FoldedText fold(
  String text, {
  List<FormattingEntity> entities = const [],
  Map<String, String> handles = const {},
  bool everyone = false,
  bool hideAutoUrls = false,
  bool trimRight = false,
}) =>
    foldRuns(
      text: text,
      urls: UrlDetector.matches(text),
      mentions: MentionDetector.matches(
        text,
        usernameById: handles,
        everyone: everyone,
      ),
      entities: entities,
      hideAutoUrls: hideAutoUrls,
      trimRight: trimRight,
    );

FormattingEntity fmt(FormattingType t, int start, int end, {String? url}) =>
    FormattingEntity(start: start, end: end, type: t, url: url);

void main() {
  group('DisplayTransform parity with the legacy _stripUrls', () {
    // Messages shaped like the ones people actually send: URLs at every
    // position, mixed whitespace, newlines, the trailing-punctuation quirk
    // (the detector excludes a final "." from the match, so the strip leaves
    // it behind — that behaviour is load-bearing history, not a bug to fix
    // here).
    const corpus = [
      'check this out https://example.com so cool',
      'https://example.com',
      'https://example.com trailing text',
      'leading text https://example.com',
      'two https://a.example.com and https://b.example.com links',
      'see https://example.com. and then some',
      'spaces   https://example.com   collapse',
      'tabs\thttps://example.com\tbecome spaces',
      'line one https://example.com \nline two',
      'a https://example.com\n\nb',
      ' \t leading mess https://example.com trailing mess \t ',
      'urls touching punctuation (https://example.com) here',
      'no urls at all, nothing to strip   double spaces stay',
      'unicode 🐒 before https://example.com after 🍌',
      'newline only\nno url',
      'https://a.example.com https://b.example.com',
      'x https://a.example.com  \n  https://b.example.com y',
    ];

    for (final text in corpus) {
      test('parity: ${text.replaceAll('\n', r'\n')}', () {
        final t = DisplayTransform.of(text, hidden: UrlDetector.matches(text));
        expect(t.text, legacyStripUrls(text));
      });
    }

    test('no hidden ranges is the identity', () {
      const text = 'hello   world \n untouched  ';
      final t = DisplayTransform.of(text);
      expect(t.text, text);
    });

    test('trimRight without hidden ranges only trims the tail', () {
      const text = '  hello world   ';
      final t = DisplayTransform.of(text, trimRight: true);
      expect(t.text, '  hello world');
    });
  });

  group('offset mapping through the strip', () {
    test('an entity after a stripped URL lands on the right characters', () {
      const text = 'check https://example.com out friend';
      final e = fmt(FormattingType.bold, 26, 29); // "out"
      final f = fold(text, entities: [e], hideAutoUrls: true);
      expect(f.displayText, 'check out friend');
      final boldRuns =
          f.runs.where((r) => r.styles.contains(FormattingType.bold));
      final covered = boldRuns
          .map((r) => f.displayText.substring(r.start, r.end))
          .join();
      expect(covered, 'out');
    });

    test('an entity entirely inside a stripped URL vanishes', () {
      const text = 'go https://example.com now';
      final e = fmt(FormattingType.bold, 3, 22); // the URL itself
      final f = fold(text, entities: [e], hideAutoUrls: true);
      expect(
        f.runs.any((r) => r.styles.contains(FormattingType.bold)),
        isFalse,
      );
    });

    test('identity mapping when URLs are shown', () {
      const text = 'check https://example.com out';
      final e = fmt(FormattingType.bold, 0, 5); // "check"
      final f = fold(text, entities: [e]);
      expect(f.displayText, text);
      final r = f.runs.first;
      expect(r.styles, {FormattingType.bold});
      expect(f.displayText.substring(r.start, r.end), 'check');
    });
  });

  group('boundary split + style fold', () {
    test('overlapping bold and italic produce a union run', () {
      //          0123456789
      const text = 'aaabbbccc';
      final f = fold(text, entities: [
        fmt(FormattingType.bold, 0, 6),
        fmt(FormattingType.italic, 3, 9),
      ]);
      String slice(StyledRun r) => text.substring(r.start, r.end);
      expect(f.runs, hasLength(3));
      expect(slice(f.runs[0]), 'aaa');
      expect(f.runs[0].styles, {FormattingType.bold});
      expect(slice(f.runs[1]), 'bbb');
      expect(
          f.runs[1].styles, {FormattingType.bold, FormattingType.italic});
      expect(slice(f.runs[2]), 'ccc');
      expect(f.runs[2].styles, {FormattingType.italic});
    });

    test('runs tile the whole display text', () {
      const text = 'some words with style';
      final f = fold(text, entities: [
        fmt(FormattingType.underline, 5, 10),
        fmt(FormattingType.code, 8, 15),
      ]);
      var cursor = 0;
      for (final r in f.runs) {
        expect(r.start, cursor);
        cursor = r.end;
      }
      expect(cursor, f.displayText.length);
    });

    test('plain is true only when nothing is enriched', () {
      expect(fold('nothing here').plain, isTrue);
      expect(
        fold('bold here', entities: [fmt(FormattingType.bold, 0, 4)]).plain,
        isFalse,
      );
      expect(fold('see https://example.com').plain, isFalse); // auto-URL owner
    });
  });

  group('interactive conflict resolution', () {
    test('a link entity beats the auto-URL it overlaps', () {
      const text = 'go https://example.com now';
      final f = fold(text, entities: [
        fmt(FormattingType.link, 3, 22, url: 'https://other.example.com'),
      ]);
      expect(f.owners, hasLength(1));
      expect(f.owners.single.linkUrl, 'https://other.example.com');
      expect(f.owners.single.autoUrl, isNull);
    });

    test('an auto-URL still beats a mention inside it', () {
      const text = 'see https://example.com/@bob profile';
      final f = fold(text, handles: const {'u1': 'bob'});
      expect(f.owners.where((o) => o.mention != null), isEmpty);
      expect(f.owners.where((o) => o.autoUrl != null), hasLength(1));
    });

    test('a mention inside a link entity is dropped', () {
      const text = 'ask @bob about it';
      final f = fold(
        text,
        handles: const {'u1': 'bob'},
        entities: [fmt(FormattingType.link, 0, 8, url: 'https://x.example')],
      );
      expect(f.owners.where((o) => o.mention != null), isEmpty);
      expect(f.owners.where((o) => o.linkUrl != null), hasLength(1));
    });

    test('a mention outside every owner survives', () {
      const text = 'hey @bob look';
      final f = fold(text, handles: const {'u1': 'bob'});
      expect(f.owners.single.mention?.userId, 'u1');
    });

    test('a link split by a style boundary keeps ONE owner', () {
      const text = 'tap this word please';
      final f = fold(text, entities: [
        fmt(FormattingType.link, 4, 13, url: 'https://x.example'),
        fmt(FormattingType.bold, 9, 13),
      ]);
      final linkRuns = f.runs.where((r) => r.ownerIndex != null).toList();
      expect(linkRuns.length, greaterThan(1));
      expect(linkRuns.map((r) => r.ownerIndex).toSet(), hasLength(1));
    });
  });

  group('spoiler veils', () {
    test('adjacent spoiler entities merge into one veil', () {
      const text = 'the big secret here';
      final f = fold(text, entities: [
        fmt(FormattingType.spoiler, 4, 10),
        fmt(FormattingType.spoiler, 10, 16),
      ]);
      expect(f.spoilerRanges, hasLength(1));
      expect(f.spoilerRanges.single, (start: 4, end: 16));
    });

    test('separated spoilers stay separate veils', () {
      const text = 'aa bb cc dd ee';
      final f = fold(text, entities: [
        fmt(FormattingType.spoiler, 0, 2),
        fmt(FormattingType.spoiler, 6, 8),
      ]);
      expect(f.spoilerRanges, hasLength(2));
    });

    test('spoiler over a styled run keeps both facts', () {
      const text = 'hidden bold';
      final f = fold(text, entities: [
        fmt(FormattingType.spoiler, 0, 11),
        fmt(FormattingType.bold, 7, 11),
      ]);
      final boldRun =
          f.runs.singleWhere((r) => r.styles.contains(FormattingType.bold));
      expect(boldRun.spoiler, isTrue);
    });
  });
}
