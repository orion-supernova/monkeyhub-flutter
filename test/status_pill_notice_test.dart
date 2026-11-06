import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/labeled_field.dart';
import 'package:monkeyhub/widgets/notice.dart';
import 'package:monkeyhub/widgets/status_pill.dart';

Widget _host(Widget child, {double width = 320}) => MaterialApp(
  home: ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  group('StatusPill', () {
    testWidgets('every tone and fill renders label and glyph', (tester) async {
      for (final fill in StatusFill.values) {
        for (final tone in StatusTone.values) {
          await tester.pumpWidget(
            _host(
              StatusPill(
                label: 'Live',
                icon: CupertinoIcons.circle_fill,
                tone: tone,
                fill: fill,
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Live'), findsOneWidget);
          expect(find.byIcon(CupertinoIcons.circle_fill), findsOneWidget);
        }
      }
    });

    testWidgets('iconOnly drops the words but keeps the semantics label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const StatusPill(
            label: 'Pinned',
            icon: CupertinoIcons.pin_fill,
            iconOnly: true,
          ),
        ),
      );
      expect(find.text('Pinned'), findsNothing);
      expect(find.bySemanticsLabel('Pinned'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a tight slot drops the label when asked to', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusPill(
            label: 'A rather long label',
            icon: CupertinoIcons.lock,
            dropLabelWhenTight: true,
          ),
          width: 60,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('A rather long label'), findsNothing);
    });

    testWidgets('onTap fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          StatusPill(
            label: 'Open',
            icon: CupertinoIcons.info,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      expect(taps, 1);
    });

    testWidgets('explain-on-tap shows the tooltip sentence', (tester) async {
      await tester.pumpWidget(
        _host(
          const StatusPill(
            label: 'Muted',
            icon: CupertinoIcons.bell_slash_fill,
            tooltip: 'Notifications are off',
          ),
        ),
      );
      await tester.tap(find.text('Muted'));
      await tester.pump();
      expect(find.text('Notifications are off'), findsOneWidget);
    });
  });

  group('Notice', () {
    testWidgets('every tone renders its message and a default glyph', (
      tester,
    ) async {
      for (final tone in NoticeTone.values) {
        await tester.pumpWidget(_host(Notice('Hello there', tone: tone)));
        expect(tester.takeException(), isNull);
        expect(find.text('Hello there'), findsOneWidget);
        expect(find.byIcon(Notice.glyphFor(tone)), findsOneWidget);
      }
    });

    testWidgets('title, action and dismiss work', (tester) async {
      var acted = 0;
      var dismissed = 0;
      await tester.pumpWidget(
        _host(
          Notice(
            'Body',
            title: 'Title',
            tone: NoticeTone.error,
            actionLabel: 'Try again',
            onAction: () => acted++,
            onDismiss: () => dismissed++,
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(acted, 1);
      await tester.tap(find.byIcon(CupertinoIcons.xmark));
      expect(dismissed, 1);
    });

    testWidgets('FormErrorBanner is the loud preset', (tester) async {
      await tester.pumpWidget(_host(const FormErrorBanner('Wrong password')));
      expect(find.byType(Notice), findsOneWidget);
      expect(find.text('Wrong password'), findsOneWidget);
    });
  });
}
