import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/mention.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';

/// How a sent mention is drawn.
///
/// [LinkifiedText] is on the render path of every text bubble in the app, so
/// the two things it must never lose are pinned here: the plain-`Text` fast
/// path for messages with nothing to enrich, and `trailing` — the invisible
/// span that reserves the timestamp's room — staying the paragraph's last
/// child. A mention span inserted after it would let a full last line run
/// underneath the clock.
void main() {
  const handles = {'u1': 'murat', 'u2': 'maria'};

  Widget host(Widget child) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(body: SizedBox(width: 500, child: child)),
    ),
  );

  LinkifiedText build(
    String text, {
    Map<String, String> mentionHandles = handles,
    bool everyone = false,
    String? selfUserId,
    InlineSpan? trailing,
  }) => LinkifiedText(
    text: text,
    style: const TextStyle(fontSize: 14, color: Color(0xFFFFFFFF)),
    linkStyle: const TextStyle(color: Color(0xFF00FF00)),
    onLinkTap: (_) {},
    trailing: trailing,
    mentionHandles: mentionHandles,
    mentionsEveryone: everyone,
    selfUserId: selfUserId,
    mentionStyle: const TextStyle(color: Color(0xFFFF0000)),
    selfMentionStyle: const TextStyle(color: Color(0xFF0000FF)),
  );

  /// The flattened leaf spans of whatever the widget rendered.
  List<InlineSpan> spansOf(WidgetTester tester) {
    final rich = tester.widget<Text>(find.byType(Text));
    final root = rich.textSpan!;
    final out = <InlineSpan>[];
    root.visitChildren((s) {
      out.add(s);
      return true;
    });
    return out;
  }

  testWidgets('plain text with nothing to enrich stays a plain Text', (
    tester,
  ) async {
    await tester.pumpWidget(host(build('just a message')));
    final text = tester.widget<Text>(find.byType(Text));
    // `data` non-null is what proves the cheap path was taken — the rich path
    // sets `textSpan` instead.
    expect(text.data, 'just a message');
    expect(text.textSpan, isNull);
  });

  testWidgets('a mention becomes its own styled span', (tester) async {
    await tester.pumpWidget(host(build('hey @murat look')));
    final spans = spansOf(tester).whereType<TextSpan>().toList();
    final mention = spans.firstWhere((s) => s.text == '@murat');
    expect(mention.style?.color, const Color(0xFFFF0000));
    expect(mention.recognizer, isNull, reason: 'no onMentionTap was wired');
  });

  testWidgets('a mention of the reader is styled differently from one of '
      'somebody else', (tester) async {
    await tester.pumpWidget(host(build('@murat and @maria', selfUserId: 'u2')));
    final spans = spansOf(tester).whereType<TextSpan>().toList();
    final other = spans.firstWhere((s) => s.text == '@murat');
    final self = spans.firstWhere((s) => s.text == '@maria');
    expect(other.style?.color, const Color(0xFFFF0000));
    expect(self.style?.color, const Color(0xFF0000FF));
  });

  testWidgets('@everyone reads as a mention of the reader, whoever they are', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        build(
          'heads up @everyone',
          mentionHandles: const {},
          everyone: true,
          selfUserId: 'nobody-in-particular',
        ),
      ),
    );
    final spans = spansOf(tester).whereType<TextSpan>().toList();
    final everyone = spans.firstWhere((s) => s.text == '@everyone');
    expect(everyone.style?.color, const Color(0xFF0000FF));
  });

  testWidgets('a handle the message never claimed is left as plain text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(build('hey @murat', mentionHandles: const {})),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, 'hey @murat');
  });

  testWidgets('the trailing stamp span stays last, after both a URL and a '
      'mention', (tester) async {
    const stamp = WidgetSpan(child: SizedBox(width: 40, height: 10));
    await tester.pumpWidget(
      host(build('@murat see https://example.com now', trailing: stamp)),
    );

    final spans = spansOf(tester);
    expect(spans.last, same(stamp));
    // And the URL still got its own span rather than being swallowed.
    expect(
      spans.whereType<TextSpan>().any((s) => s.text == 'https://example.com'),
      isTrue,
    );
  });

  testWidgets('trailing alone still forces the rich path', (tester) async {
    const stamp = WidgetSpan(child: SizedBox(width: 40, height: 10));
    await tester.pumpWidget(
      host(
        build('nothing to enrich', mentionHandles: const {}, trailing: stamp),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.data, isNull);
    expect(text.textSpan, isNotNull);
  });

  testWidgets('a mention inside a URL loses to the URL', (tester) async {
    await tester.pumpWidget(host(build('see https://x.com/@murat ok')));
    final spans = spansOf(tester).whereType<TextSpan>().toList();
    // The whole URL is one span; no separate '@murat' was carved out of it.
    expect(spans.any((s) => s.text == 'https://x.com/@murat'), isTrue);
    expect(spans.any((s) => s.text == '@murat'), isFalse);
  });

  test(
    'MentionDetector and UrlDetector agree on the same coordinate space',
    () {
      // Guards the merge: both must be measured against the string that is
      // actually rendered, or the spans land on the wrong characters.
      const text = '@murat https://x.com';
      final m = MentionDetector.matches(text, usernameById: handles).single;
      expect(text.substring(m.start, m.end), '@murat');
    },
  );
}
