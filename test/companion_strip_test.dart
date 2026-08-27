import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/companion.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/companion_strip.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

/// The contract [CompanionStrip] owes its two call sites.
///
/// The strip that reports a download lives above the ROOT navigator and spans
/// the top of every screen in the app, so two of these are not style questions:
/// a hidden strip that still ate taps would be a bug nobody could find, and a
/// strip whose height changed when a download finished would shove the
/// transcript under a reader mid-scroll.
///
/// The opacity test is the one that made this widget exist. Both strips used to
/// paint a 10–12% wash of the theme's accent and set their text in that same
/// accent on top of it, which over a transcript or a themed background layer is
/// whatever contrast the pixels underneath happen to give it.
void main() {
  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 500, child: child),
        ),
      ),
    ),
  );

  CompanionStrip strip({
    bool visible = true,
    double? progress,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onTap,
  }) => CompanionStrip(
    visible: visible,
    companion: Companion.sebastian,
    message: 'Sebastian is translating',
    progress: progress,
    actionLabel: actionLabel,
    onAction: onAction,
    onTap: onTap,
  );

  testWidgets('collapses to zero height and hit-tests nothing when hidden', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(host(strip(visible: false, onTap: () => taps++)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.getSize(find.byType(CompanionStrip)).height, 0);

    // A zero-height box cannot be tapped by the finder, so poke the slot it
    // would have occupied instead. Nothing there means nothing to eat the tap.
    await tester.tapAt(const Offset(250, 10));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('keeps one height whether or not it has progress to report', (
    tester,
  ) async {
    await tester.pumpWidget(host(strip(progress: 0.4)));
    await tester.pump(const Duration(milliseconds: 400));
    final withBar = tester.getSize(find.byType(CompanionStrip)).height;

    await tester.pumpWidget(host(strip()));
    await tester.pump(const Duration(milliseconds: 400));
    final without = tester.getSize(find.byType(CompanionStrip)).height;

    expect(withBar, kCompanionStripHeight);
    expect(
      without,
      withBar,
      reason: 'the track keeps its slot so a finished download does not '
          'change the strip height under a reader',
    );
  });

  testWidgets('paints an opaque fill, not a wash of the accent', (
    tester,
  ) async {
    await tester.pumpWidget(host(strip(progress: 0.4)));
    await tester.pump(const Duration(milliseconds: 400));

    final theme = BasicTheme.midnight();
    final fills = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(CompanionStrip),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.color)
        .whereType<Color>();

    expect(
      fills,
      contains(theme.surfaceRaised),
      reason: 'the strip body must be a surface, not a tint over one',
    );
    expect(
      theme.surfaceRaised.a,
      1.0,
      reason: 'and that surface must be fully opaque',
    );
  });

  testWidgets('the action fires — FocusableTap alone registers nothing', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      host(strip(actionLabel: 'STOP', onAction: () => actions++)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('STOP'));
    await tester.pump();
    expect(actions, 1);
  });

  testWidgets('the action does not also fire the strip-wide tap', (
    tester,
  ) async {
    var actions = 0;
    var opens = 0;
    await tester.pumpWidget(
      host(
        strip(
          actionLabel: 'STOP',
          onAction: () => actions++,
          onTap: () => opens++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('STOP'));
    await tester.pump();

    expect(actions, 1);
    expect(opens, 0, reason: 'STOP must not also open the screen behind it');
  });

  testWidgets('the action target is the full height of the row, not the word', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(strip(actionLabel: 'STOP', onAction: () {})),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final word = tester.getSize(find.text('STOP')).height;
    final target = tester
        .getSize(
          find.ancestor(
            of: find.text('STOP'),
            matching: find.byType(GestureDetector),
          ).first,
        )
        .height;

    expect(target, greaterThan(word * 1.8));
  });

  testWidgets('the glass variant is a gutter-inset pill of the same height', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        CompanionStrip(
          visible: true,
          companion: Companion.sebastian,
          message: 'Sebastian is translating',
          progress: 0.4,
          glass: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LiquidGlass), findsOneWidget);
    // The gutter is INSIDE the strip, so the widget still fills its slot and it
    // is the glass that is inset. Measuring the outer box would pass for a
    // full-bleed ribbon too.
    expect(
      tester.getSize(find.byType(LiquidGlass)).width,
      lessThan(500),
      reason: 'the compact style insets the pill so it floats over the '
          'transcript rather than cutting across it',
    );
    expect(
      tester.getSize(find.byType(CompanionStrip)).height,
      kCompanionStripHeight,
      reason: 'the room reserves exactly this much top padding for it',
    );
  });

  testWidgets('the opaque variant is full bleed', (tester) async {
    await tester.pumpWidget(host(strip(progress: 0.4)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LiquidGlass), findsNothing);
    expect(tester.getSize(find.byType(CompanionStrip)).width, 500);
  });

  testWidgets('renders no ink', (tester) async {
    await tester.pumpWidget(
      host(strip(actionLabel: 'STOP', onAction: () {}, onTap: () {})),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
  });
}
