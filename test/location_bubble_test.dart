import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/location_bubble.dart';
import 'package:monkeyhub/widgets/location_map_preview.dart';

/// A location bubble has three states and they are not interchangeable:
///
///  * **fixed** — one position, true forever, no chrome about time;
///  * **live** — a position that moves, with a stated end;
///  * **ended** — a position that used to move, visibly finished.
///
/// The third exists specifically so an expired share never reads as the first.
/// Letting an ended share decay into a plain pin would present a stale position
/// as a current one, which is the single worst thing this feature could do.
///
/// The interesting test is the last one: a share that ends WHILE it is on
/// screen. Nothing pushes that transition — no rebuild from the parent, no
/// message from the server — so it has to fall out of the widget's own clock.
///
/// No test here touches GPS, the network, or a maps app. Positions are literals
/// and the card is drawn.
void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, child: child),
            ),
          ),
        ),
      );

  ChatMessage msg({
    required MessageType type,
    DateTime? expiresAt,
    DateTime? endedAt,
    DateTime? updatedAt,
    double? lat = 41.0138,
    double? lng = 28.9497,
    double? accuracy = 15,
  }) =>
      ChatMessage(
        id: 'm1',
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: '',
        createdAt: DateTime.now(),
        type: type,
        latitude: lat,
        longitude: lng,
        locationAccuracyM: accuracy,
        liveExpiresAt: expiresAt,
        liveUpdatedAt: updatedAt,
        liveEndedAt: endedAt,
      );

  Widget bubble(
    ChatMessage m, {
    Future<void> Function()? onStop,
    bool publishing = false,
    DateTime Function()? clock,
  }) {
    final theme = BasicTheme.midnight();
    return host(
      LocationBubble(
        theme: theme,
        message: m,
        isMine: true,
        width: 260,
        radius: BorderRadius.circular(16),
        onStopSharing: onStop,
        publishing: publishing,
        clock: clock ?? DateTime.now,
      ),
    );
  }

  /// Advances the widget's clock and its timers together, one second at a time.
  ///
  /// Both halves are needed and neither is enough alone: `pump(Duration)` moves
  /// the binding's timers so the bubble's ticker fires, and [advance] moves the
  /// clock the bubble reads so the tick sees a later time. `DateTime.now()` is
  /// untouched by `pump`, which is exactly why `LocationBubble` takes a clock.
  ///
  /// Bounded pumps rather than `pumpAndSettle`: a running share drives a
  /// repeating halo animation that never settles, by design.
  Future<void> tickSeconds(
    WidgetTester tester,
    int n,
    void Function(Duration) advance,
  ) async {
    for (var i = 0; i < n; i++) {
      advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('a fixed location draws a card and no time chrome',
      (tester) async {
    await tester.pumpWidget(bubble(msg(type: MessageType.location)));
    await tester.pump();

    expect(find.byType(LocationMapPreview), findsOneWidget);
    // No badge, because there is no state to report: a static pin is neither
    // running nor finished.
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('ENDED'), findsNothing);
    // The coordinates and the accuracy are the whole caption.
    expect(find.textContaining('41.01380, 28.94970'), findsOneWidget);
    expect(find.textContaining('±15 m'), findsOneWidget);
  });

  testWidgets('a running share says when it stops', (tester) async {
    final until = DateTime.now().add(const Duration(hours: 1));
    await tester.pumpWidget(
      bubble(msg(
        type: MessageType.liveLocation,
        expiresAt: until,
        updatedAt: DateTime.now(),
      )),
    );
    await tester.pump();

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('ENDED'), findsNothing);
    // The deadline in words, not just as a badge. A badge does not survive a
    // screenshot, a screen reader, or a glance.
    final hh = until.hour.toString().padLeft(2, '0');
    final mm = until.minute.toString().padLeft(2, '0');
    expect(find.textContaining('$hh:$mm'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a finished share is visibly finished, not a plain pin',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      bubble(msg(
        type: MessageType.liveLocation,
        expiresAt: now.add(const Duration(hours: 1)),
        endedAt: now.subtract(const Duration(minutes: 2)),
      )),
    );
    await tester.pump();

    expect(find.text('ENDED'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    // Still shows where they were — the position was already delivered to this
    // room while the share ran, so hiding it discloses nothing and only costs
    // the transcript its record.
    expect(find.textContaining('41.01380, 28.94970'), findsOneWidget);
    // And it is drawn as finished, not merely labelled as finished.
    final preview = tester.widget<LocationMapPreview>(
      find.byType(LocationMapPreview),
    );
    expect(preview.dimmed, isTrue);
  });

  testWidgets('a share that expires while you are watching flips to ended',
      (tester) async {
    // THE case. The row still says the share is live — no `liveEndedAt`, and
    // nothing from the server arrives during this test — and the bubble must
    // stop claiming it anyway, on the tick the deadline passes.
    var now = DateTime(2026, 8, 9, 14, 0);
    await tester.pumpWidget(
      bubble(
        msg(
          type: MessageType.liveLocation,
          expiresAt: now.add(const Duration(seconds: 3)),
          updatedAt: now,
        ),
        clock: () => now,
      ),
    );
    await tester.pump();
    expect(find.text('LIVE'), findsOneWidget);

    await tickSeconds(tester, 5, (d) => now = now.add(d));

    expect(find.text('LIVE'), findsNothing);
    expect(find.text('ENDED'), findsOneWidget);
    // And the card itself is redrawn as finished, not merely relabelled — the
    // halo is gone and the grid is dimmed, which is what stops an expired share
    // from reading as a live one at a glance.
    final preview = tester.widget<LocationMapPreview>(
      find.byType(LocationMapPreview),
    );
    expect(preview.dimmed, isTrue);
    expect(preview.pulse, 0);
  });

  testWidgets('a stale running share says so rather than showing a confident dot',
      (tester) async {
    await tester.pumpWidget(
      bubble(msg(
        type: MessageType.liveLocation,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        // Older than three heartbeats: the sharer's device has stopped
        // reporting, which is not the same as the sharer standing still.
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      )),
    );
    await tester.pump();

    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('No recent update'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('STOP appears only on the share this device is publishing',
      (tester) async {
    final live = msg(
      type: MessageType.liveLocation,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      updatedAt: DateTime.now(),
    );

    // Handed a callback but not publishing: this is the sender's OTHER device
    // looking at its own share. It must not offer to stop something it is not
    // feeding.
    await tester.pumpWidget(bubble(live, onStop: () async {}));
    await tester.pump();
    expect(find.text('Stop sharing'), findsNothing);

    await tester.pumpWidget(
      bubble(live, onStop: () async {}, publishing: true),
    );
    await tester.pump();
    expect(find.text('Stop sharing'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an ended share offers no stop button', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      bubble(
        msg(
          type: MessageType.liveLocation,
          expiresAt: now.add(const Duration(hours: 1)),
          endedAt: now,
        ),
        onStop: () async {},
        publishing: true,
      ),
    );
    await tester.pump();
    expect(find.text('Stop sharing'), findsNothing);
  });

  testWidgets('a location with no coordinates degrades to a plate',
      (tester) async {
    // Reachable from a cache written before the coordinates existed, and from
    // a send the server downgraded. An honest plate beats an empty card.
    await tester.pumpWidget(
      bubble(msg(type: MessageType.location, lat: null, lng: null)),
    );
    await tester.pump();

    expect(find.byType(LocationMapPreview), findsNothing);
    expect(find.text('Location unavailable'), findsOneWidget);
  });

  testWidgets('an unknown accuracy draws no ring rather than a flattering one',
      (tester) async {
    await tester.pumpWidget(
      bubble(msg(type: MessageType.location, accuracy: null)),
    );
    await tester.pump();

    final preview = tester.widget<LocationMapPreview>(
      find.byType(LocationMapPreview),
    );
    expect(preview.accuracyM, isNull);
    // And the caption drops the ± clause entirely instead of printing ±0 m.
    expect(find.textContaining('±'), findsNothing);
  });
}
