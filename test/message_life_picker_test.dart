import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/haptic_tick.dart';
import 'package:monkeyhub/widgets/message_life_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HapticTick.resetForTest();
    HapticTick.lowPowerProbe = () => true; // landmarks: no channel needed
  });
  tearDown(HapticTick.resetForTest);

  group('options', () {
    test('after seen offers 10s, 1m, 1h; after sent offers five', () {
      expect(messageLifeOptions(MessageClock.seen), const [
        Duration(seconds: 10),
        Duration(minutes: 1),
        Duration(hours: 1),
      ]);
      expect(messageLifeOptions(MessageClock.sent), const [
        Duration(seconds: 10),
        Duration(seconds: 30),
        Duration(minutes: 1),
        Duration(minutes: 5),
        Duration(hours: 1),
      ]);
    });

    test('normalize keeps a valid lifetime and snaps an invalid one', () {
      const keep = (clock: MessageClock.seen, lifetime: Duration(minutes: 1));
      expect(normalizeMessageLife(keep), keep);
      expect(
        normalizeMessageLife(
          (clock: MessageClock.seen, lifetime: const Duration(seconds: 30)),
        ).lifetime,
        const Duration(seconds: 10),
        reason: 'a tie goes to the shorter, safer side',
      );
      expect(
        normalizeMessageLife(
          (clock: MessageClock.seen, lifetime: const Duration(minutes: 5)),
        ).lifetime,
        const Duration(minutes: 1),
      );
      expect(
        normalizeMessageLife(
          (clock: MessageClock.sent, lifetime: const Duration(days: 3)),
        ).lifetime,
        const Duration(hours: 1),
      );
    });

    test('the default is valid for its clock', () {
      expect(normalizeMessageLife(kDefaultMessageLife), kDefaultMessageLife);
    });
  });

  Widget host(ValueNotifier<MessageLife> life, {List<MessageClock>? clocks}) =>
      ThemeScope(
        controller: ThemeController(ThemeController.byId('basic')),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<MessageLife>(
                valueListenable: life,
                builder: (_, v, _) => MessageLifePicker(
                  value: v,
                  onChanged: (n) => life.value = n,
                  clocks: clocks ?? MessageClock.values,
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('shows the clock, the stops and the matching caption', (t) async {
    final life = ValueNotifier<MessageLife>(kDefaultMessageLife);
    await t.pumpWidget(host(life));
    expect(find.text('After seen'), findsOneWidget);
    expect(find.text('After sent'), findsOneWidget);
    expect(find.text("Counts from the moment it's sent."), findsOneWidget);
    // Five stops, and the knob repeats the selected one.
    for (final label in ['10s', '1m', '5m', '1h']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('30s'), findsNWidgets(2));
  });

  testWidgets('switching to after seen resets to a valid value', (t) async {
    final life = ValueNotifier<MessageLife>(
      (clock: MessageClock.sent, lifetime: const Duration(minutes: 5)),
    );
    await t.pumpWidget(host(life));

    await t.tap(find.text('After seen'));
    await t.pumpAndSettle();

    expect(life.value.clock, MessageClock.seen);
    expect(
      messageLifeOptions(MessageClock.seen).contains(life.value.lifetime),
      isTrue,
    );
    expect(life.value.lifetime, const Duration(minutes: 1));
    expect(find.text('Gone within 24 hours at most, seen or not.'),
        findsOneWidget);
    // The ruler now has three stops.
    expect(find.text('30s'), findsNothing);
    expect(find.text('5m'), findsNothing);
  });

  testWidgets('switching back keeps a lifetime both clocks offer', (t) async {
    final life = ValueNotifier<MessageLife>(
      (clock: MessageClock.seen, lifetime: const Duration(hours: 1)),
    );
    await t.pumpWidget(host(life));
    await t.tap(find.text('After sent'));
    await t.pumpAndSettle();
    expect(life.value, (clock: MessageClock.sent, lifetime: const Duration(hours: 1)));
  });

  testWidgets('a tap on the ruler changes the lifetime, not the clock', (t) async {
    final life = ValueNotifier<MessageLife>(
      (clock: MessageClock.sent, lifetime: const Duration(seconds: 10)),
    );
    await t.pumpWidget(host(life));
    // The 1h label sits under its stop; tap just above it on the track.
    final last = t.getCenter(find.text('1h').first);
    await t.tapAt(Offset(last.dx, last.dy - 18));
    await t.pumpAndSettle();
    expect(life.value, (clock: MessageClock.sent, lifetime: const Duration(hours: 1)));
  });

  testWidgets('a single clock hides the switch', (t) async {
    final life = ValueNotifier<MessageLife>(
      (clock: MessageClock.seen, lifetime: const Duration(minutes: 1)),
    );
    await t.pumpWidget(host(life, clocks: const [MessageClock.seen]));
    expect(find.text('After seen'), findsNothing);
    expect(find.text('After sent'), findsNothing);
  });

  testWidgets('an invalid incoming value is shown as its nearest valid one', (t) async {
    final life = ValueNotifier<MessageLife>(
      (clock: MessageClock.seen, lifetime: const Duration(seconds: 30)),
    );
    await t.pumpWidget(host(life));
    expect(find.text('10s'), findsNWidgets(2)); // stop + knob
  });
}
