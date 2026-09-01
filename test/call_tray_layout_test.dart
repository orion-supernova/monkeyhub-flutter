import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

/// The call tray never squashes.
///
/// It used to be one `Row` of `Expanded` buttons: eight controls on a phone
/// left each ~42 pt wide with its label cut short. These pin the rules the
/// shared [CallTray] lays them out by instead — fixed-size controls that
/// wrap onto a second row on a phone and stand in one row on a wide
/// window, labels that fit, the share control's "starting" state, and an
/// estimate of the tray's height the stages can trust.
const _labels = [
  'Mute',
  'Camera',
  'Speaker',
  'Share',
  'Draw',
  'Flip',
  'Options',
  'Hide',
];

List<CallTrayAction> _actions(int n, {bool sharePending = false}) => [
      for (var i = 0; i < n; i++)
        CallTrayAction(
          key: ValueKey('action-$i'),
          icon: Icons.circle,
          label: _labels[i] == 'Share' && sharePending
              ? 'Starting…'
              : _labels[i],
          enabled: !(_labels[i] == 'Share' && sharePending),
          onTap: () {},
        ),
    ];

Widget _host(double width, List<CallTrayAction> actions) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CallTray(
                  actions: actions,
                  endIcon: Icons.call_end,
                  endLabel: 'End',
                  endColor: Colors.red,
                  onEnd: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// The toolbar controls (not the end-call hero), and the rows they stand
/// in, told apart by where their tops are.
Iterable<Element> _controls(WidgetTester tester) => find
    .byType(CallControlButton)
    .evaluate()
    .where((e) => !(e.widget as CallControlButton).large);

int _rowsOf(WidgetTester tester) => _controls(tester)
    .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy.round())
    .toSet()
    .length;

void main() {
  testWidgets('eight controls on a phone wrap onto two rows, none squashed',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(390, _actions(8)));

    expect(_controls(tester), hasLength(8));
    expect(_rowsOf(tester), 2);
    for (final e in _controls(tester)) {
      // The circle itself — the tappable part — is never under 48 pt.
      final circle = find.descendant(
        of: find.byWidget(e.widget),
        matching: find.byType(GestureDetector),
      );
      expect(tester.getSize(circle).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(circle).height, greaterThanOrEqualTo(48));
    }
    // Every control is genuinely tappable.
    for (final e in _controls(tester)) {
      expect(
        find.descendant(
          of: find.byWidget(e.widget),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('the first row keeps the highest-priority controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(390, _actions(8)));

    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    // Mute, camera, speaker and share on the first row; the rest below.
    expect(top('Mute'), top('Share'));
    expect(top('Flip'), top('Hide'));
    expect(top('Mute'), lessThan(top('Flip')));
  });

  testWidgets('rows are balanced — five controls stay on one row, seven '
      'become four and three', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(390, _actions(5)));
    expect(_rowsOf(tester), 1);

    await tester.pumpWidget(_host(390, _actions(7)));
    expect(_rowsOf(tester), 2);
    final tops = _controls(tester)
        .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy.round())
        .toList();
    final first = tops.reduce((a, b) => a < b ? a : b);
    expect(tops.where((t) => t == first).length, 4);
    expect(tops.where((t) => t != first).length, 3);
  });

  testWidgets('a wide window keeps every control on one row',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(900, _actions(8)));

    expect(_controls(tester), hasLength(8));
    expect(_rowsOf(tester), 1);
  });

  testWidgets('labels are one line and are not cut short on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(390, _actions(8)));

    for (final label in _labels) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
  });

  testWidgets('the share control reads "Starting…" and is inert while '
      'the share is being set up', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_host(390, _actions(8, sharePending: true)));

    expect(find.text('Starting…'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
    final share = find.ancestor(
      of: find.text('Starting…'),
      matching: find.byType(CallControlButton),
    );
    expect(share, findsOneWidget);
    expect(
      find.descendant(of: share, matching: find.byType(GestureDetector)),
      findsNothing,
    );
  });

  testWidgets('the height estimate is what the tray actually takes',
      (tester) async {
    for (final (width, count) in const [(390, 8), (390, 5), (320, 6), (900, 8)]) {
      await tester.binding.setSurfaceSize(Size(width.toDouble(), 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(width.toDouble(), _actions(count)));
      final rendered = tester.getSize(find.byType(CallTray)).height;
      final estimate = CallTray.estimateHeight(
        actionCount: count,
        width: width.toDouble(),
      );
      // Never under what is drawn (a stage would sit beneath the tray),
      // and not so far over that the stage loses real room to it.
      expect(estimate, greaterThanOrEqualTo(rendered), reason: '$width/$count');
      expect(estimate - rendered, lessThan(28), reason: '$width/$count');
    }
  });
}
