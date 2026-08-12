import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// The composer's optional buttons.
///
/// `onAttach` and `onCamera` are nullable, and that is load-bearing rather than
/// tidy: `thread_overlay.dart` builds both composers inside a root
/// `OverlayEntry` and passes neither, because both open full-screen routes that
/// would fight the overlay for layering. A camera button that appeared there
/// anyway would look fine in a screenshot and misbehave only when tapped —
/// hence a test.
///
/// Both composers are covered. Which one is built is a call-site decision keyed
/// off the user's chat style, so a change that only reached one of them would
/// ship broken for half the users.
void main() {
  Widget host(Widget composer) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: composer),
      ),
    ),
  );

  final composers = <String, Widget Function({VoidCallback? onCamera})>{
    'classic': ({onCamera}) => ChatComposerClassic(
      controller: TextEditingController(),
      ephemeral: false,
      onSend: () {},
      onAttach: () {},
      onCamera: onCamera,
    ),
    'liquid': ({onCamera}) => ChatComposerLiquid(
      controller: TextEditingController(),
      ephemeral: false,
      onSend: () {},
      onAttach: () {},
      onCamera: onCamera,
    ),
  };

  /// Same two composers, but with text in them — the send button only exists
  /// while `controller.text` is non-empty — and with the scheduling hooks
  /// under test wired up.
  final sendable = <String,
      Widget Function({
    VoidCallback? onSend,
    VoidCallback? onSchedule,
    int scheduledCount,
  })>{
    'classic': ({onSend, onSchedule, scheduledCount = 0}) =>
        ChatComposerClassic(
          controller: TextEditingController(text: 'hi'),
          ephemeral: false,
          onSend: onSend ?? () {},
          onSchedule: onSchedule,
          scheduledCount: scheduledCount,
        ),
    'liquid': ({onSend, onSchedule, scheduledCount = 0}) => ChatComposerLiquid(
          controller: TextEditingController(text: 'hi'),
          ephemeral: false,
          onSend: onSend ?? () {},
          onSchedule: onSchedule,
          scheduledCount: scheduledCount,
        ),
  };

  composers.forEach((name, build) {
    group(name, () {
      testWidgets('shows a camera button when one is wired up', (tester) async {
        var taps = 0;
        await tester.pumpWidget(host(build(onCamera: () => taps++)));
        await tester.pumpAndSettle();

        final camera = find.byIcon(Icons.photo_camera_outlined);
        expect(camera, findsOneWidget);

        await tester.tap(camera);
        await tester.pumpAndSettle();
        expect(taps, 1);
      });

      testWidgets('omits it entirely when there is nowhere to go', (
        tester,
      ) async {
        await tester.pumpWidget(host(build()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
        // The rest of the composer is untouched — this is an absent button, not
        // a broken row.
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });
    });
  });

  /// Hold-to-schedule.
  ///
  /// The gesture shares an arena with the tap that sends, so the two have to be
  /// tested together: a long press that also fired `onSend` would schedule the
  /// message AND send it, which is the one outcome nobody could undo.
  ///
  /// `onSchedule` is nullable for the same load-bearing reason `onCamera` is,
  /// and one step stronger. The hold visibly charges a ring before it fires, so
  /// a host that cannot schedule — the thread overlay, a self-destructing room
  /// — must not animate a promise it will then swallow.
  // The send glyph differs between the two styles, and it is the only reliable
  // handle on the button: the composer row is full of GestureDetectors.
  const sendIcon = {
    'classic': Icons.north_east,
    'liquid': Icons.arrow_upward,
  };

  sendable.forEach((name, build) {
    final send = find.byIcon(sendIcon[name]!);
    group('$name scheduling', () {
      testWidgets('a hold schedules and does not also send', (tester) async {
        var sends = 0;
        var schedules = 0;
        await tester.pumpWidget(host(build(
          onSend: () => sends++,
          onSchedule: () => schedules++,
        )));
        await tester.pumpAndSettle();

        await tester.longPress(send);
        await tester.pumpAndSettle();

        expect(schedules, 1);
        expect(sends, 0, reason: 'the hold must not also send the message');
      });

      testWidgets('a tap still sends', (tester) async {
        var sends = 0;
        var schedules = 0;
        await tester.pumpWidget(host(build(
          onSend: () => sends++,
          onSchedule: () => schedules++,
        )));
        await tester.pumpAndSettle();

        await tester.tap(send);
        await tester.pumpAndSettle();

        expect(sends, 1);
        expect(schedules, 0);
      });

      testWidgets('with no schedule hook the button is exactly as it was', (
        tester,
      ) async {
        var sends = 0;
        await tester.pumpWidget(host(build(onSend: () => sends++)));
        await tester.pumpAndSettle();

        await tester.longPress(send);
        await tester.pumpAndSettle();

        // Pins the OLD behaviour, which this feature must not change for the
        // hosts that opt out. With no schedule hook the button falls back to a
        // plain `GestureDetector(onTap:)`, and a bare TapGestureRecognizer has
        // no deadline — so a press-and-release still sends however long it was
        // held. That is what the thread overlay has always done.
        expect(sends, 1);
      });

      testWidgets('the badge counts what is queued, and caps at 9+', (
        tester,
      ) async {
        await tester.pumpWidget(host(build(onSchedule: () {}, scheduledCount: 3)));
        await tester.pumpAndSettle();
        expect(find.text('3'), findsOneWidget);

        await tester.pumpWidget(host(build(onSchedule: () {}, scheduledCount: 42)));
        await tester.pumpAndSettle();
        expect(find.text('42'), findsNothing);
        expect(find.text('9+'), findsOneWidget);
      });

      testWidgets('no badge when the room has nothing queued', (tester) async {
        await tester.pumpWidget(host(build(onSchedule: () {})));
        await tester.pumpAndSettle();
        expect(find.text('0'), findsNothing);
      });
    });
  });
}
