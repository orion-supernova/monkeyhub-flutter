import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/spoiler_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/widgets/code_chip_underlay.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/spoiler_overlay.dart';

/// How the inline-code chip mounts, and — the part worth guarding — what it
/// does NOT disturb.
///
/// The chip is a `Positioned.fill` sibling below the paragraph, so the two
/// things that could regress are the plain-`Text` fast path that keeps
/// unformatted messages off RichText, and the Stack's sizing child. Both are
/// asserted here rather than left to the layout suite to notice later.
void main() {
  const text = 'run flutter test to check';
  const style = TextStyle(fontSize: 16, color: Color(0xFF000000));

  Widget host({
    List<FormattingEntity> formatting = const [],
    Color? codeBackground = const Color(0xFF3A414D),
    Color? codeBorder = const Color(0xFF5D626C),
    String? spoilerContextId,
    InlineSpan? trailing,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: LinkifiedText(
                text: text,
                style: style,
                linkStyle: const TextStyle(color: Color(0xFF007AFF)),
                onLinkTap: (_) {},
                formatting: formatting,
                codeStyle: style,
                codeBackground: codeBackground,
                codeBorder: codeBorder,
                spoilerContextId: spoilerContextId,
                spoilerCover: const Color(0xFF232B38),
                spoilerDust: const Color(0xFFFFFFFF),
                trailing: trailing,
              ),
            ),
          ),
        ),
      );

  const codeEntity =
      FormattingEntity(start: 4, end: 16, type: FormattingType.code);
  const spoilerEntity =
      FormattingEntity(start: 20, end: 25, type: FormattingType.spoiler);

  setUp(SpoilerStore.instance.clear);

  testWidgets('a code entity mounts the underlay', (tester) async {
    await tester.pumpWidget(host(formatting: const [codeEntity]));
    await tester.pump();
    expect(find.byType(InlineCodeUnderlay), findsOneWidget);
  });

  testWidgets('no chip colour means no underlay', (tester) async {
    // A caller with no theme in reach — a bare test, a system notice.
    await tester.pumpWidget(
      host(formatting: const [codeEntity], codeBackground: null),
    );
    await tester.pump();
    expect(find.byType(InlineCodeUnderlay), findsNothing);
  });

  testWidgets('an unformatted message keeps the plain-Text fast path',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    expect(find.byType(InlineCodeUnderlay), findsNothing);
    // Scoped to this widget — Scaffold brings Stacks of its own.
    expect(
      find.descendant(
        of: find.byType(LinkifiedText),
        matching: find.byType(Stack),
      ),
      findsNothing,
      reason: 'an unformatted message must not pay for a Stack',
    );
  });

  testWidgets('code and a spoiler stack as underlay, text, veil',
      (tester) async {
    await tester.pumpWidget(host(
      formatting: const [codeEntity, spoilerEntity],
      spoilerContextId: 'm1',
    ));
    await tester.pump();
    await tester.pump();

    final stack = tester.widget<Stack>(
      find.ancestor(
        of: find.byType(InlineCodeUnderlay),
        matching: find.byType(Stack),
      ).first,
    );
    expect(stack.children, hasLength(3));
    expect(stack.children[0], isA<Positioned>());
    expect(
      stack.children[1],
      isA<Text>(),
      reason: 'the paragraph must stay the only non-positioned child, or the '
          'Stack stops hugging the text',
    );
    expect(stack.children[2], isA<Positioned>());
    expect(find.byType(SpoilerOverlay), findsOneWidget);
  });

  testWidgets('the chip measures to real geometry', (tester) async {
    await tester.pumpWidget(host(formatting: const [codeEntity]));
    await tester.pump(); // post-frame measurement
    await tester.pump(); // repaint with paths

    final box = tester.renderObject<RenderBox>(
      find.byType(InlineCodeUnderlay),
    );
    expect(box.hasSize, isTrue);
    expect(box.size.width, greaterThan(0));
    expect(box.size.height, greaterThan(0));
  });

  testWidgets('the underlay does not swallow taps meant for the text',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: GestureDetector(
                onTap: () => taps++,
                child: LinkifiedText(
                  text: text,
                  style: style,
                  linkStyle: const TextStyle(color: Color(0xFF007AFF)),
                  onLinkTap: (_) {},
                  formatting: const [codeEntity],
                  codeStyle: style,
                  codeBackground: const Color(0xFF3A414D),
                  codeBorder: const Color(0xFF5D626C),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(InlineCodeUnderlay), warnIfMissed: false);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the stamp spacer stays the paragraph\'s last span',
      (tester) async {
    // The bubble reserves the timestamp's room with a trailing WidgetSpan, and
    // its position is load-bearing for wrapping. The underlay must not have
    // moved it.
    const spacer = WidgetSpan(child: SizedBox(width: 40, height: 12));
    await tester.pumpWidget(
      host(formatting: const [codeEntity], trailing: spacer),
    );
    await tester.pump();

    final paragraph = tester.widget<Text>(find.byType(Text));
    final children = (paragraph.textSpan! as TextSpan).children!;
    expect(children.last, isA<WidgetSpan>());
  });
}
