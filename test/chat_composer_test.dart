import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// The same two, in a Chamber-of-Secrets room — which is where the longest
  /// hint in the app lives.
  final ephemeral = <String, Widget Function()>{
    'classic': () => ChatComposerClassic(
      controller: TextEditingController(),
      ephemeral: true,
      onSend: () {},
      onAttach: () {},
    ),
    'liquid': () => ChatComposerLiquid(
      controller: TextEditingController(),
      ephemeral: true,
      onSend: () {},
      onAttach: () {},
    ),
  };

  ephemeral.forEach((name, build) {
    testWidgets('$name: an empty ephemeral composer is one line tall', (
      tester,
    ) async {
      // A hint is laid out like any other text and wraps. The ephemeral hint
      // is the longest string either composer ever shows, and it grew the
      // empty field to two rows before anyone had typed anything — pushing
      // the send button down and giving the room a composer twice the height
      // of the one next door. The cap is on the field rather than on the
      // copy, so no translation can undo it.
      await tester.pumpWidget(host(build()));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintMaxLines, 1);

      // And the string itself is short enough that the ellipsis is a
      // safety net rather than the normal case.
      final context = tester.element(find.byType(TextField));
      final hint = AppLocalizations.of(context).deepOceanThemeEphemeralHint;
      expect(hint.length, lessThan(28), reason: 'terse enough to fit: "$hint"');
    });
  });

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

  /// Every haptic the widget plays, by type, until the test ends.
  List<String> recordHaptics(WidgetTester tester) {
    final played = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        played.add('${call.arguments}'.replaceFirst('HapticFeedbackType.', ''));
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return played;
  }

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

      testWidgets('a tap never starts the hold ring', (tester) async {
        // The regression this exists for: `onLongPressDown` fires on
        // POINTER-DOWN, before the recognizer knows whether this is a tap or a
        // hold. Starting the sweep there made every ordinary send flash a stub
        // of arc and then spend up to 400ms reversing it. A lead-in timer, not
        // an opacity threshold — with a threshold the animation is still
        // running and the only question is how much of it you can see.
        await tester.pumpWidget(host(build(onSchedule: () {})));
        await tester.pumpAndSettle();

        // The ring's painter is private, and the liquid button paints its own
        // glass, so this counts CustomPaints rather than naming one: at rest is
        // the baseline, and the ring is the only thing that can add to it.
        int paints() => find.byType(CustomPaint).evaluate().length;
        final atRest = paints();

        final gesture = await tester.startGesture(tester.getCenter(send));
        // A brisk tap: well inside the lead-in.
        await tester.pump(const Duration(milliseconds: 60));
        expect(
          paints(),
          atRest,
          reason: 'the ring must not appear during an ordinary tap',
        );

        await gesture.up();
        await tester.pumpAndSettle();
        expect(paints(), atRest);
      });

      testWidgets('a deliberate hold does show the ring', (tester) async {
        // The other half: the lead-in must not have disabled the affordance.
        await tester.pumpWidget(host(build(onSchedule: () {})));
        await tester.pumpAndSettle();

        int paints() => find.byType(CustomPaint).evaluate().length;
        final atRest = paints();

        final gesture = await tester.startGesture(tester.getCenter(send));
        // Two pumps, not one. The first advances the clock past the lead-in so
        // the timer fires and calls `forward` — but the controller is still at
        // zero for that frame. The second is the tick that actually moves it.
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 60));
        expect(
          paints(),
          greaterThan(atRest),
          reason: 'past the lead-in, a hold has to show it is going somewhere',
        );

        await gesture.up();
        await tester.pumpAndSettle();
        // Withdrawn instantly on release, not reversed over the full duration.
        expect(paints(), atRest);
      });

      testWidgets('a hold vibrates as it charges, then lands one heavy impact', (
        tester,
      ) async {
        final haptics = recordHaptics(tester);
        var schedules = 0;
        await tester.pumpWidget(host(build(onSchedule: () => schedules++)));
        await tester.pumpAndSettle();

        // Frame by frame: `longPress` is one long pump, and the vibration is
        // driven by the ring's frames.
        final gesture = await tester.startGesture(tester.getCenter(send));
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(schedules, 1);
        expect(haptics.last, 'heavyImpact');
        final charge = haptics.sublist(0, haptics.length - 1);
        expect(
          charge.length,
          greaterThanOrEqualTo(8),
          reason: 'close enough together to read as one continuous buzz',
        );
        expect(charge.first, 'selectionClick');
        const strength = ['selectionClick', 'lightImpact', 'mediumImpact'];
        final ranks = charge.map(strength.indexOf).toList();
        expect(ranks, isNot(contains(-1)));
        expect(ranks, [...ranks]..sort(), reason: 'it only ever builds');
      });

      testWidgets('letting go mid-charge silences it at once', (tester) async {
        final haptics = recordHaptics(tester);
        await tester.pumpWidget(host(build(onSchedule: () {})));
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(tester.getCenter(send));
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final played = haptics.length;
        expect(played, greaterThan(0));

        await gesture.up();
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Let go short of the threshold is a tap, so it sends — with the send
        // tick, and not one more tap of the charge.
        expect(haptics.sublist(played), ['lightImpact']);
      });

      testWidgets('a tap is one light tick, never the charge', (tester) async {
        final haptics = recordHaptics(tester);
        await tester.pumpWidget(host(build(onSchedule: () {})));
        await tester.pumpAndSettle();

        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(haptics, ['lightImpact']);
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

  /// The send button has to arrive on the keystroke that earns it.
  ///
  /// Both composers are stateless and pick the trailing button off
  /// `controller.text`, and neither host rebuilds on a keystroke: the room
  /// screen's `setState` runs on a 1Hz ticker and the thread overlay's on repo
  /// traffic. So this pumps the tree ONCE and never hands it a new widget
  /// again — the only thing that can bring the button in is the composer
  /// listening to the controller itself. Without that the button showed up
  /// whenever the host next happened to build, up to a second after the
  /// character, and only then started its 200ms fade.
  final typing = <String, Widget Function(TextEditingController)>{
    'classic': (controller) => ChatComposerClassic(
          controller: controller,
          ephemeral: false,
          onSend: () {},
          onCamera: () {},
        ),
    'liquid': (controller) => ChatComposerLiquid(
          controller: controller,
          ephemeral: false,
          onSend: () {},
          onCamera: () {},
        ),
  };

  typing.forEach((name, build) {
    testWidgets('$name the send button lands on the first character', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final send = find.byIcon(sendIcon[name]!);

      await tester.pumpWidget(host(build(controller)));
      await tester.pumpAndSettle();
      expect(send, findsNothing);

      await tester.enterText(find.byType(TextField), 'h');
      // Frames only — pumpAndSettle finishes the switcher's fade, it does not
      // rebuild the host. That is the whole point of the test.
      await tester.pumpAndSettle();
      expect(send, findsOneWidget, reason: 'one character is enough to send');

      // And it leaves the same way: on the clear, not on whatever rebuild
      // happens to come next.
      controller.clear();
      await tester.pumpAndSettle();
      expect(send, findsNothing);
      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    });
  });
}
