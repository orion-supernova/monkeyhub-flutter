import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/widgets/mention_text_controller.dart';

/// The remap rule table for formatting ranges across text edits — the one
/// piece of state in the composer that cannot be re-derived from the text
/// (there is no literal token to find), so every rule here is
/// load-bearing: a wrong shift ships a message whose bold sits on the wrong
/// words.
void main() {
  MentionTextController controller(String text) =>
      MentionTextController(text: text);

  void type(MentionTextController c, String newText, int caret) {
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  List<(int, int, FormattingType)> ranges(MentionTextController c) =>
      [for (final f in c.formatting) (f.start, f.end, f.type)];

  TextSelection sel(int s, int e) =>
      TextSelection(baseOffset: s, extentOffset: e);

  group('toggleFormat', () {
    test('applies over a selection and reads back sorted', () {
      final c = controller('make this bold');
      c.toggleFormat(FormattingType.bold, sel(10, 14));
      expect(ranges(c), [(10, 14, FormattingType.bold)]);
    });

    test('toggling a fully covered selection removes it there', () {
      final c = controller('all bold here');
      c.toggleFormat(FormattingType.bold, sel(0, 13));
      c.toggleFormat(FormattingType.bold, sel(4, 8));
      expect(ranges(c), [
        (0, 4, FormattingType.bold),
        (8, 13, FormattingType.bold),
      ]);
    });

    test('partially covered selection extends instead of removing', () {
      final c = controller('half covered');
      c.toggleFormat(FormattingType.bold, sel(0, 4));
      c.toggleFormat(FormattingType.bold, sel(2, 8));
      expect(ranges(c), [(0, 8, FormattingType.bold)]);
    });

    test('collapsed or invalid selections are no-ops', () {
      final c = controller('words');
      c.toggleFormat(FormattingType.bold, const TextSelection.collapsed(offset: 2));
      c.toggleFormat(FormattingType.bold, sel(3, 3));
      expect(c.formatting, isEmpty);
    });

    test('different types overlap freely', () {
      final c = controller('overlapping styles');
      c.toggleFormat(FormattingType.bold, sel(0, 11));
      c.toggleFormat(FormattingType.italic, sel(5, 18));
      expect(c.formatting, hasLength(2));
    });
  });

  group('remap: insertion', () {
    test('typing before a range shifts it', () {
      final c = controller('bold');
      c.toggleFormat(FormattingType.bold, sel(0, 4));
      type(c, 'xxbold', 2); // insert "xx" at 0
      expect(ranges(c), [(2, 6, FormattingType.bold)]);
      expect(c.text.substring(2, 6), 'bold');
    });

    test('typing strictly inside a range grows it', () {
      final c = controller('bold');
      c.toggleFormat(FormattingType.bold, sel(0, 4));
      type(c, 'boXld', 3); // insert "X" at 2
      expect(ranges(c), [(0, 5, FormattingType.bold)]);
    });

    test('typing at the END boundary stays outside', () {
      final c = controller('bold plain');
      c.toggleFormat(FormattingType.bold, sel(0, 4));
      type(c, 'boldX plain', 5); // insert at offset 4 == range end
      expect(ranges(c), [(0, 4, FormattingType.bold)]);
    });

    test('typing at the START boundary pushes the range right', () {
      final c = controller('bold');
      c.toggleFormat(FormattingType.bold, sel(0, 4));
      type(c, 'Xbold', 1); // insert at offset 0 == range start
      expect(ranges(c), [(1, 5, FormattingType.bold)]);
      expect(c.text.substring(1, 5), 'bold');
    });

    test('typing after a range leaves it alone', () {
      final c = controller('bold tail');
      c.toggleFormat(FormattingType.bold, sel(0, 4));
      type(c, 'bold tailX', 10);
      expect(ranges(c), [(0, 4, FormattingType.bold)]);
    });
  });

  group('remap: deletion', () {
    test('deleting before a range shifts it left', () {
      final c = controller('xxbold');
      c.toggleFormat(FormattingType.bold, sel(2, 6));
      type(c, 'bold', 0); // delete "xx"
      expect(ranges(c), [(0, 4, FormattingType.bold)]);
    });

    test('deleting inside a range shrinks it', () {
      final c = controller('bbooldd');
      c.toggleFormat(FormattingType.bold, sel(0, 7));
      type(c, 'bold', 2); // delete 3 chars inside
      expect(ranges(c), [(0, 4, FormattingType.bold)]);
    });

    test('deleting a range tail truncates it', () {
      final c = controller('boldtail');
      c.toggleFormat(FormattingType.bold, sel(0, 6));
      type(c, 'bol', 3); // delete offsets [3,8)
      expect(ranges(c), [(0, 3, FormattingType.bold)]);
    });

    test('deleting a range head moves its start', () {
      final c = controller('headbold');
      c.toggleFormat(FormattingType.bold, sel(2, 8));
      type(c, 'bold', 0); // delete offsets [0,4)
      expect(ranges(c), [(0, 4, FormattingType.bold)]);
    });

    test('a deletion swallowing the whole range kills it', () {
      final c = controller('pre bold post');
      c.toggleFormat(FormattingType.bold, sel(4, 8));
      type(c, 'pre post', 4); // delete "bold " (offsets [4,9))
      expect(c.formatting, isEmpty);
    });
  });

  group('remap: replacement (paste over selection, autocorrect)', () {
    test('replacing text inside a range keeps the range around it', () {
      final c = controller('the word here');
      c.toggleFormat(FormattingType.bold, sel(0, 13));
      type(c, 'the sword here', 9); // "word" → "sword"
      expect(ranges(c), [(0, 14, FormattingType.bold)]);
    });

    test('replacing a whole bold selection keeps it bold', () {
      final c = controller('bold');
      c.toggleFormat(FormattingType.bold, sel(0, 4));
      type(c, 'chunky', 6); // select-all, paste
      expect(ranges(c), [(0, 6, FormattingType.bold)]);
    });
  });

  group('links', () {
    test('applyLink stores the url and linkAt finds it', () {
      final c = controller('check this out');
      c.applyLink(sel(6, 10), 'https://x.example');
      expect(c.linkAt(sel(7, 7)), 'https://x.example');
      expect(c.formatting.single.url, 'https://x.example');
    });

    test('applyLink over an existing link replaces it', () {
      final c = controller('check this out');
      c.applyLink(sel(6, 10), 'https://a.example');
      c.applyLink(sel(6, 10), 'https://b.example');
      final links = c.formatting
          .where((f) => f.type == FormattingType.link)
          .toList();
      expect(links, hasLength(1));
      expect(links.single.url, 'https://b.example');
    });

    test('removeLink detaches without touching the text', () {
      final c = controller('check this out');
      c.applyLink(sel(6, 10), 'https://x.example');
      c.removeLink(sel(6, 10));
      expect(c.formatting, isEmpty);
      expect(c.text, 'check this out');
    });

    test('adjacent links with different urls never merge', () {
      final c = controller('one two');
      c.applyLink(sel(0, 3), 'https://a.example');
      c.applyLink(sel(3, 7), 'https://b.example');
      expect(c.formatting, hasLength(2));
    });
  });

  group('restore and clear', () {
    test('restoreFormatting round-trips through the entity list', () {
      final c = controller('some styled words');
      c.toggleFormat(FormattingType.italic, sel(5, 11));
      final snapshot = c.formatting;
      c.clearFormatting();
      expect(c.formatting, isEmpty);
      c.restoreFormatting(snapshot);
      expect(ranges(c), [(5, 11, FormattingType.italic)]);
    });

    test('restore clamps ranges that outlive their text', () {
      final c = controller('short');
      c.restoreFormatting(const [
        FormattingEntity(start: 2, end: 40, type: FormattingType.bold),
        FormattingEntity(start: 30, end: 44, type: FormattingType.italic),
      ]);
      expect(ranges(c), [(2, 5, FormattingType.bold)]);
    });
  });

  group('coalescing', () {
    test('touching same-type ranges merge', () {
      final c = controller('abcdef');
      c.toggleFormat(FormattingType.bold, sel(0, 3));
      c.toggleFormat(FormattingType.bold, sel(3, 6));
      expect(ranges(c), [(0, 6, FormattingType.bold)]);
    });
  });
}
